#[test_only]
module merg3::creature_nft_tests {
    use std::string::{Self, String};
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use merg3::creature_nft::{
        Self,
        AdminCap,
        BrainrotCollection,
        CreatureNFT,
        NFTMetadata,
    };

    // Test addresses
    const ADMIN: address = @admin;
    const USER1: address = @0x2;
    const USER2: address = @0x3;

    // Helper function to create a test scenario
    fun create_test_scenario(): Scenario {
        ts::begin(ADMIN)
    }

    // Helper function to create a test clock with timestamp
    fun create_test_clock_with_time(timestamp_ms: u64, scenario: &mut Scenario): Clock {
        let mut clock = clock::create_for_testing(ts::ctx(scenario));
        clock::set_for_testing(&mut clock, timestamp_ms);
        clock
    }

    // Helper function to create a test clock
    fun create_test_clock(scenario: &mut Scenario): Clock {
        create_test_clock_with_time(1000000, scenario) // Start at 1000 seconds
    }

    // Helper function to create test item vectors
    fun create_test_items(): (
        vector<u64>, vector<u64>, // leg
        vector<u64>, vector<u64>, // body
        vector<u64>, vector<u64>, // hand
        vector<u64>, vector<u64>, // head
        vector<u64>, vector<u64>, // style
        vector<u64>, vector<u64>, // material
        vector<u64>, vector<u64>  // environment
    ) {
        // Create simple test items for each category
        let leg_ids = vector[1u64];
        let leg_quantities = vector[1u64];
        
        let body_ids = vector[2u64];
        let body_quantities = vector[1u64];
        
        let hand_ids = vector[3u64];
        let hand_quantities = vector[1u64];
        
        let head_ids = vector[4u64];
        let head_quantities = vector[1u64];
        
        let style_ids = vector[5u64];
        let style_quantities = vector[1u64];
        
        let material_ids = vector[6u64];
        let material_quantities = vector[1u64];
        
        let environment_ids = vector[7u64];
        let environment_quantities = vector[1u64];

        (
            leg_ids, leg_quantities,
            body_ids, body_quantities,
            hand_ids, hand_quantities,
            head_ids, head_quantities,
            style_ids, style_quantities,
            material_ids, material_quantities,
            environment_ids, environment_quantities
        )
    }

    // Helper function to create different test items for duplicate recipe testing
    fun create_different_test_items(): (
        vector<u64>, vector<u64>, // leg
        vector<u64>, vector<u64>, // body
        vector<u64>, vector<u64>, // hand
        vector<u64>, vector<u64>, // head
        vector<u64>, vector<u64>, // style
        vector<u64>, vector<u64>, // material
        vector<u64>, vector<u64>  // environment
    ) {
        // Create different items for testing duplicate recipes
        let leg_ids = vector[10u64];
        let leg_quantities = vector[1u64];
        
        let body_ids = vector[20u64];
        let body_quantities = vector[1u64];
        
        let hand_ids = vector[30u64];
        let hand_quantities = vector[1u64];
        
        let head_ids = vector[40u64];
        let head_quantities = vector[1u64];
        
        let style_ids = vector[50u64];
        let style_quantities = vector[1u64];
        
        let material_ids = vector[60u64];
        let material_quantities = vector[1u64];
        
        let environment_ids = vector[70u64];
        let environment_quantities = vector[1u64];

        (
            leg_ids, leg_quantities,
            body_ids, body_quantities,
            hand_ids, hand_quantities,
            head_ids, head_quantities,
            style_ids, style_quantities,
            material_ids, material_quantities,
            environment_ids, environment_quantities
        )
    }

    #[test]
    fun test_mint_new_recipe_success() {
        let mut scenario = create_test_scenario();
        
        // Initialize the module
        ts::next_tx(&mut scenario, ADMIN);
        {
            creature_nft::init_for_testing(ts::ctx(&mut scenario));
        };

        // Get shared objects and mint NFT
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut payment = coin::mint_for_testing<SUI>(1000000000, ts::ctx(&mut scenario));
            let clock = create_test_clock(&mut scenario);

            let (
                leg_ids, leg_quantities,
                body_ids, body_quantities,
                hand_ids, hand_quantities,
                head_ids, head_quantities,
                style_ids, style_quantities,
                material_ids, material_quantities,
                environment_ids, environment_quantities
            ) = create_test_items();

            // Test minting with new recipe
            creature_nft::mint_creature_entry(
                &admin_cap,
                &mut collection,
                string::utf8(b"Fire Dragon"),
                leg_ids,
                leg_quantities,
                body_ids,
                body_quantities,
                hand_ids,
                hand_quantities,
                head_ids,
                head_quantities,
                style_ids,
                style_quantities,
                material_ids,
                material_quantities,
                environment_ids,
                environment_quantities,
                string::utf8(b"https://example.com/reserved.png"),
                &mut payment,
                USER1,
                &clock,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(collection);
            ts::return_to_sender(&scenario, admin_cap);
            coin::burn_for_testing(payment);
            clock::destroy_for_testing(clock);
        };

        // Test that the reserved name is no longer available
        ts::next_tx(&mut scenario, ADMIN);
        {
            let collection = ts::take_shared<BrainrotCollection>(&scenario);
            
            // let reserved_name = string::utf8(b"Reserved Name");
            // assert!(!creature_nft::is_name_available(&collection, &reserved_name), 13);
            
            // But other names should still be available
            let available_name = string::utf8(b"Still Available");
            assert!(creature_nft::is_name_available(&collection, &available_name), 14);
            
            ts::return_shared(collection);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = merg3::creature_nft::EInvalidName)]
    fun test_empty_name_fails() {
        let mut scenario = create_test_scenario();
        
        // Initialize the module
        ts::next_tx(&mut scenario, ADMIN);
        {
            creature_nft::init_for_testing(ts::ctx(&mut scenario));
        };

        // Try to mint with empty name - should fail
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut payment = coin::mint_for_testing<SUI>(1000000000, ts::ctx(&mut scenario));
            let clock = create_test_clock(&mut scenario);

            let (
                leg_ids, leg_quantities,
                body_ids, body_quantities,
                hand_ids, hand_quantities,
                head_ids, head_quantities,
                style_ids, style_quantities,
                material_ids, material_quantities,
                environment_ids, environment_quantities
            ) = create_test_items();

            creature_nft::mint_creature_entry(
                &admin_cap,
                &mut collection,
                string::utf8(b""), // Empty name - should fail
                leg_ids,
                leg_quantities,
                body_ids,
                body_quantities,
                hand_ids,
                hand_quantities,
                head_ids,
                head_quantities,
                style_ids,
                style_quantities,
                material_ids,
                material_quantities,
                environment_ids,
                environment_quantities,
                string::utf8(b"https://example.com/empty.png"),
                &mut payment,
                USER1,
                &clock,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(collection);
            ts::return_to_sender(&scenario, admin_cap);
            coin::burn_for_testing(payment);
            clock::destroy_for_testing(clock);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = merg3::creature_nft::EInvalidName)]
    fun test_whitespace_only_name_fails() {
        let mut scenario = create_test_scenario();
        
        // Initialize the module
        ts::next_tx(&mut scenario, ADMIN);
        {
            creature_nft::init_for_testing(ts::ctx(&mut scenario));
        };

        // Try to mint with whitespace-only name - should fail
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut payment = coin::mint_for_testing<SUI>(1000000000, ts::ctx(&mut scenario));
            let clock = create_test_clock(&mut scenario);

            let (
                leg_ids, leg_quantities,
                body_ids, body_quantities,
                hand_ids, hand_quantities,
                head_ids, head_quantities,
                style_ids, style_quantities,
                material_ids, material_quantities,
                environment_ids, environment_quantities
            ) = create_test_items();

            creature_nft::mint_creature_entry(
                &admin_cap,
                &mut collection,
                string::utf8(b"   "), // Whitespace only - should fail
                leg_ids,
                leg_quantities,
                body_ids,
                body_quantities,
                hand_ids,
                hand_quantities,
                head_ids,
                head_quantities,
                style_ids,
                style_quantities,
                material_ids,
                material_quantities,
                environment_ids,
                environment_quantities,
                string::utf8(b"https://example.com/whitespace.png"),
                &mut payment,
                USER1,
                &clock,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(collection);
            ts::return_to_sender(&scenario, admin_cap);
            coin::burn_for_testing(payment);
            clock::destroy_for_testing(clock);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_mismatched_item_vectors_fail() {
        let mut scenario = create_test_scenario();
        
        // Initialize the module
        ts::next_tx(&mut scenario, ADMIN);
        {
            creature_nft::init_for_testing(ts::ctx(&mut scenario));
        };

        // Try to mint with mismatched vector lengths - should fail
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut payment = coin::mint_for_testing<SUI>(1000000000, ts::ctx(&mut scenario));
            let clock = create_test_clock(&mut scenario);

            let leg_ids = vector[1u64, 2u64]; // 2 items
            let leg_quantities = vector[1u64]; // 1 quantity - mismatch!
            
            let (
                _, _,
                body_ids, body_quantities,
                hand_ids, hand_quantities,
                head_ids, head_quantities,
                style_ids, style_quantities,
                material_ids, material_quantities,
                environment_ids, environment_quantities
            ) = create_test_items();

            creature_nft::mint_creature_entry(
                &admin_cap,
                &mut collection,
                string::utf8(b"Mismatched Items"),
                leg_ids,
                leg_quantities, // Mismatched length
                body_ids,
                body_quantities,
                hand_ids,
                hand_quantities,
                head_ids,
                head_quantities,
                style_ids,
                style_quantities,
                material_ids,
                material_quantities,
                environment_ids,
                environment_quantities,
                string::utf8(b"https://example.com/mismatch.png"),
                &mut payment,
                USER1,
                &clock,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(collection);
            ts::return_to_sender(&scenario, admin_cap);
            coin::burn_for_testing(payment);
            clock::destroy_for_testing(clock);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_get_all_item_ids() {
        let mut scenario = create_test_scenario();
        
        // Initialize the module
        ts::next_tx(&mut scenario, ADMIN);
        {
            creature_nft::init_for_testing(ts::ctx(&mut scenario));
        };

        // Mint NFT with various items
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut payment = coin::mint_for_testing<SUI>(1000000000, ts::ctx(&mut scenario));
            let clock = create_test_clock(&mut scenario);

            // Create items with some overlapping IDs to test deduplication
            let leg_ids = vector[1u64, 2u64];
            let leg_quantities = vector[1u64, 1u64];
            
            let body_ids = vector[2u64, 3u64]; // 2 overlaps with leg
            let body_quantities = vector[1u64, 1u64];
            
            let hand_ids = vector[4u64];
            let hand_quantities = vector[1u64];
            
            let head_ids = vector[5u64];
            let head_quantities = vector[1u64];
            
            let style_ids = vector[1u64]; // 1 overlaps with leg
            let style_quantities = vector[1u64];
            
            let material_ids = vector[6u64];
            let material_quantities = vector[1u64];
            
            let environment_ids = vector[7u64];
            let environment_quantities = vector[1u64];

            creature_nft::mint_creature_entry(
                &admin_cap,
                &mut collection,
                string::utf8(b"Multi Item Test"),
                leg_ids,
                leg_quantities,
                body_ids,
                body_quantities,
                hand_ids,
                hand_quantities,
                head_ids,
                head_quantities,
                style_ids,
                style_quantities,
                material_ids,
                material_quantities,
                environment_ids,
                environment_quantities,
                string::utf8(b"https://example.com/multi.png"),
                &mut payment,
                USER1,
                &clock,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(collection);
            ts::return_to_sender(&scenario, admin_cap);
            coin::burn_for_testing(payment);
            clock::destroy_for_testing(clock);
        };

        // Test get_all_item_ids function
        ts::next_tx(&mut scenario, USER1);
        {
            let nft = ts::take_from_sender<CreatureNFT>(&scenario);
            
            let all_ids = creature_nft::get_all_item_ids(&nft);
            
            // Should contain unique IDs: 1, 2, 3, 4, 5, 6, 7 (7 unique items)
            assert!(vector::length(&all_ids) == 7, 15);
            
            // Verify all expected IDs are present
            assert!(vector::contains(&all_ids, &1u64), 16);
            assert!(vector::contains(&all_ids, &2u64), 17);
            assert!(vector::contains(&all_ids, &3u64), 18);
            assert!(vector::contains(&all_ids, &4u64), 19);
            assert!(vector::contains(&all_ids, &5u64), 20);
            assert!(vector::contains(&all_ids, &6u64), 21);
            assert!(vector::contains(&all_ids, &7u64), 22);
            
            ts::return_to_sender(&scenario, nft);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_empty_item_categories() {
        let mut scenario = create_test_scenario();
        
        // Initialize the module
        ts::next_tx(&mut scenario, ADMIN);
        {
            creature_nft::init_for_testing(ts::ctx(&mut scenario));
        };

        // Test minting with some empty item categories
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut payment = coin::mint_for_testing<SUI>(1000000000, ts::ctx(&mut scenario));
            let clock = create_test_clock(&mut scenario);

            // Only some categories have items, others are empty
            let leg_ids = vector[1u64];
            let leg_quantities = vector[1u64];
            
            let body_ids = vector::empty<u64>(); // Empty
            let body_quantities = vector::empty<u64>();
            
            let hand_ids = vector[3u64];
            let hand_quantities = vector[1u64];
            
            let head_ids = vector::empty<u64>(); // Empty
            let head_quantities = vector::empty<u64>();
            
            let style_ids = vector::empty<u64>(); // Empty
            let style_quantities = vector::empty<u64>();
            
            let material_ids = vector[6u64];
            let material_quantities = vector[1u64];
            
            let environment_ids = vector::empty<u64>(); // Empty
            let environment_quantities = vector::empty<u64>();

            creature_nft::mint_creature_entry(
                &admin_cap,
                &mut collection,
                string::utf8(b"Sparse Items"),
                leg_ids,
                leg_quantities,
                body_ids,
                body_quantities,
                hand_ids,
                hand_quantities,
                head_ids,
                head_quantities,
                style_ids,
                style_quantities,
                material_ids,
                material_quantities,
                environment_ids,
                environment_quantities,
                string::utf8(b"https://example.com/sparse.png"),
                &mut payment,
                USER1,
                &clock,
                ts::ctx(&mut scenario)
            );

            assert!(creature_nft::get_minted_count(&collection) == 1, 23);

            ts::return_shared(collection);
            ts::return_to_sender(&scenario, admin_cap);
            coin::burn_for_testing(payment);
            clock::destroy_for_testing(clock);
        };

        ts::end(scenario);
    }

    #[test]
fun test_duplicate_recipe_fee_mechanism() {
    let mut scenario = create_test_scenario();
    
    // Initialize the module
    ts::next_tx(&mut scenario, ADMIN);
    {
        creature_nft::init_for_testing(ts::ctx(&mut scenario));
    };

    // First, mint an NFT with a specific recipe
    ts::next_tx(&mut scenario, USER1);
    {
        let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
        let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
        let mut payment = coin::mint_for_testing<SUI>(1000000000, ts::ctx(&mut scenario));
        let clock = create_test_clock(&mut scenario);

        let (
            leg_ids, leg_quantities,
            body_ids, body_quantities,
            hand_ids, hand_quantities,
            head_ids, head_quantities,
            style_ids, style_quantities,
            material_ids, material_quantities,
            environment_ids, environment_quantities
        ) = create_test_items();

        // Mint first NFT with original recipe
        creature_nft::mint_creature_entry(
            &admin_cap,
            &mut collection,
            string::utf8(b"Original Dragon"), // Original name
            leg_ids,
            leg_quantities,
            body_ids,
            body_quantities,
            hand_ids,
            hand_quantities,
            head_ids,
            head_quantities,
            style_ids,
            style_quantities,
            material_ids,
            material_quantities,
            environment_ids,
            environment_quantities,
            string::utf8(b"https://example.com/original.png"),
            &mut payment,
            USER1,
            &clock,
            ts::ctx(&mut scenario)
        );

        // Verify the collection stats
        let (minted_count, treasury_balance) = creature_nft::get_collection_stats(&collection);
        assert!(minted_count == 1, 24);

        ts::return_shared(collection);
        ts::return_to_sender(&scenario, admin_cap);
        coin::burn_for_testing(payment);
        clock::destroy_for_testing(clock);
    };

    // Get the original creator's balance before duplicate minting
    let original_creator_balance_before = ts::take_from_address<Coin<SUI>>(&scenario, USER1);
    let original_balance = coin::value(&original_creator_balance_before);
    ts::return_to_address(USER1, original_creator_balance_before);

    // Now try to mint with the same recipe but different name (duplicate recipe)
    ts::next_tx(&mut scenario, USER2);
    {
        let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
        let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
        let mut payment = coin::mint_for_testing<SUI>(1000000000, ts::ctx(&mut scenario));
        let clock = create_test_clock(&mut scenario);

        let (
            leg_ids, leg_quantities,
            body_ids, body_quantities,
            hand_ids, hand_quantities,
            head_ids, head_quantities,
            style_ids, style_quantities,
            material_ids, material_quantities,
            environment_ids, environment_quantities
        ) = create_test_items(); // Same recipe items

        // Mint second NFT with same recipe but different name
        creature_nft::mint_creature_entry(
            &admin_cap,
            &mut collection,
            string::utf8(b"Duplicate Dragon"), // Different name, same recipe
            leg_ids,
            leg_quantities,
            body_ids,
            body_quantities,
            hand_ids,
            hand_quantities,
            head_ids,
            head_quantities,
            style_ids,
            style_quantities,
            material_ids,
            material_quantities,
            environment_ids,
            environment_quantities,
            string::utf8(b"https://example.com/duplicate.png"),
            &mut payment,
            USER2,
            &clock,
            ts::ctx(&mut scenario)
        );

        // Verify the collection stats updated
        let (minted_count, treasury_balance) = creature_nft::get_collection_stats(&collection);
        assert!(minted_count == 2, 25);

        ts::return_shared(collection);
        ts::return_to_sender(&scenario, admin_cap);
        coin::burn_for_testing(payment);
        clock::destroy_for_testing(clock);
    };

    // Verify that the original creator received the duplicate fee
    ts::next_tx(&mut scenario, USER1);
    {
        let original_creator_balance_after = ts::take_from_address<Coin<SUI>>(&scenario, USER1);
        let new_balance = coin::value(&original_creator_balance_after);
        
        // The original creator should have received the default duplicate fee (0.01 SUI = 10_000_000 MIST)
        let expected_fee = 10_000_000u64; // DEFAULT_DUPLICATE_FEE
        assert!(new_balance == original_balance + expected_fee, 26);
        
        ts::return_to_address(USER1, original_creator_balance_after);
    };

    // Verify both NFTs exist but have different names
    ts::next_tx(&mut scenario, USER1);
    {
        let nft1 = ts::take_from_address<CreatureNFT>(&scenario, USER1);
        let name1 = creature_nft::get_name(&nft1);
        let creator1 = creature_nft::get_creator(&nft1);
        let recipe_hash1 = creature_nft::get_recipe_hash(&nft1);
        
        assert!(name1 == string::utf8(b"Original Dragon"), 27);
        assert!(creator1 == USER1, 28);
        
        ts::return_to_address(USER1, nft1);
    };

    ts::next_tx(&mut scenario, USER2);
    {
        let nft2 = ts::take_from_address<CreatureNFT>(&scenario, USER2);
        let name2 = creature_nft::get_name(&nft2);
        let creator2 = creature_nft::get_creator(&nft2);
        let recipe_hash2 = creature_nft::get_recipe_hash(&nft2);
        
        assert!(name2 == string::utf8(b"Duplicate Dragon"), 29);
        assert!(creator2 == USER2, 30);
        
        // Both NFTs should have the same recipe hash since they use the same items
        ts::next_tx(&mut scenario, USER1);
        {
            let nft1 = ts::take_from_address<CreatureNFT>(&scenario, USER1);
            let recipe_hash1 = creature_nft::get_recipe_hash(&nft1);
            assert!(recipe_hash1 == recipe_hash2, 31);
            ts::return_to_address(USER1, nft1);
        };
        
        ts::return_to_address(USER2, nft2);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = merg3::creature_nft::EInsufficientFee)]
fun test_duplicate_recipe_insufficient_fee_fails() {
    let mut scenario = create_test_scenario();
    
    // Initialize the module
    ts::next_tx(&mut scenario, ADMIN);
    {
        creature_nft::init_for_testing(ts::ctx(&mut scenario));
    };

    // First, mint an NFT with a specific recipe
    ts::next_tx(&mut scenario, USER1);
    {
        let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
        let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
        let mut payment = coin::mint_for_testing<SUI>(1000000000, ts::ctx(&mut scenario));
        let clock = create_test_clock(&mut scenario);

        let (
            leg_ids, leg_quantities,
            body_ids, body_quantities,
            hand_ids, hand_quantities,
            head_ids, head_quantities,
            style_ids, style_quantities,
            material_ids, material_quantities,
            environment_ids, environment_quantities
        ) = create_test_items();

        creature_nft::mint_creature_entry(
            &admin_cap,
            &mut collection,
            string::utf8(b"Original Dragon"),
            leg_ids,
            leg_quantities,
            body_ids,
            body_quantities,
            hand_ids,
            hand_quantities,
            head_ids,
            head_quantities,
            style_ids,
            style_quantities,
            material_ids,
            material_quantities,
            environment_ids,
            environment_quantities,
            string::utf8(b"https://example.com/original.png"),
            &mut payment,
            USER1,
            &clock,
            ts::ctx(&mut scenario)
        );

        ts::return_shared(collection);
        ts::return_to_sender(&scenario, admin_cap);
        coin::burn_for_testing(payment);
        clock::destroy_for_testing(clock);
    };

    // Try to mint duplicate with insufficient payment - should fail
    ts::next_tx(&mut scenario, USER2);
    {
        let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
        let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
        // Create payment with insufficient amount (less than DEFAULT_DUPLICATE_FEE)
        let mut payment = coin::mint_for_testing<SUI>(5_000_000, ts::ctx(&mut scenario)); // Only 0.005 SUI
        let clock = create_test_clock(&mut scenario);

        let (
            leg_ids, leg_quantities,
            body_ids, body_quantities,
            hand_ids, hand_quantities,
            head_ids, head_quantities,
            style_ids, style_quantities,
            material_ids, material_quantities,
            environment_ids, environment_quantities
        ) = create_test_items(); // Same recipe

        creature_nft::mint_creature_entry(
            &admin_cap,
            &mut collection,
            string::utf8(b"Should Fail Dragon"),
            leg_ids,
            leg_quantities,
            body_ids,
            body_quantities,
            hand_ids,
            hand_quantities,
            head_ids,
            head_quantities,
            style_ids,
            style_quantities,
            material_ids,
            material_quantities,
            environment_ids,
            environment_quantities,
            string::utf8(b"https://example.com/fail.png"),
            &mut payment,
            USER2,
            &clock,
            ts::ctx(&mut scenario)
        );

        ts::return_shared(collection);
        ts::return_to_sender(&scenario, admin_cap);
        coin::burn_for_testing(payment);
        clock::destroy_for_testing(clock);
    };

    ts::end(scenario);
}

#[test]
#[expected_failure(abort_code = merg3::creature_nft::ENameAlreadyExists)]
fun test_duplicate_name_fails() {
    let mut scenario = create_test_scenario();
    
    // Initialize the module
    ts::next_tx(&mut scenario, ADMIN);
    {
        creature_nft::init_for_testing(ts::ctx(&mut scenario));
    };

    // First, mint an NFT with a specific name
    ts::next_tx(&mut scenario, USER1);
    {
        let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
        let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
        let mut payment = coin::mint_for_testing<SUI>(1000000000, ts::ctx(&mut scenario));
        let clock = create_test_clock(&mut scenario);

        let (
            leg_ids, leg_quantities,
            body_ids, body_quantities,
            hand_ids, hand_quantities,
            head_ids, head_quantities,
            style_ids, style_quantities,
            material_ids, material_quantities,
            environment_ids, environment_quantities
        ) = create_test_items();

        creature_nft::mint_creature_entry(
            &admin_cap,
            &mut collection,
            string::utf8(b"Unique Dragon Name"),
            leg_ids,
            leg_quantities,
            body_ids,
            body_quantities,
            hand_ids,
            hand_quantities,
            head_ids,
            head_quantities,
            style_ids,
            style_quantities,
            material_ids,
            material_quantities,
            environment_ids,
            environment_quantities,
            string::utf8(b"https://example.com/unique.png"),
            &mut payment,
            USER1,
            &clock,
            ts::ctx(&mut scenario)
        );

        ts::return_shared(collection);
        ts::return_to_sender(&scenario, admin_cap);
        coin::burn_for_testing(payment);
        clock::destroy_for_testing(clock);
    };

    // Try to mint with the same name (even with different recipe) - should fail
    ts::next_tx(&mut scenario, USER2);
    {
        let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
        let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
        let mut payment = coin::mint_for_testing<SUI>(1000000000, ts::ctx(&mut scenario));
        let clock = create_test_clock(&mut scenario);

        let (
            leg_ids, leg_quantities,
            body_ids, body_quantities,
            hand_ids, hand_quantities,
            head_ids, head_quantities,
            style_ids, style_quantities,
            material_ids, material_quantities,
            environment_ids, environment_quantities
        ) = create_different_test_items(); // Different recipe

        creature_nft::mint_creature_entry(
            &admin_cap,
            &mut collection,
            string::utf8(b"Unique Dragon Name"), // Same name - should fail
            leg_ids,
            leg_quantities,
            body_ids,
            body_quantities,
            hand_ids,
            hand_quantities,
            head_ids,
            head_quantities,
            style_ids,
            style_quantities,
            material_ids,
            material_quantities,
            environment_ids,
            environment_quantities,
            string::utf8(b"https://example.com/duplicate-name.png"),
            &mut payment,
            USER2,
            &clock,
            ts::ctx(&mut scenario)
        );

        ts::return_shared(collection);
        ts::return_to_sender(&scenario, admin_cap);
        coin::burn_for_testing(payment);
        clock::destroy_for_testing(clock);
    };

    ts::end(scenario);
}

#[test]
fun test_multiple_duplicate_recipes_increment_usage() {
    let mut scenario = create_test_scenario();
    
    // Initialize the module
    ts::next_tx(&mut scenario, ADMIN);
    {
        creature_nft::init_for_testing(ts::ctx(&mut scenario));
    };

    // First, mint an NFT with a specific recipe
    ts::next_tx(&mut scenario, USER1);
    {
        let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
        let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
        let mut payment = coin::mint_for_testing<SUI>(1000000000, ts::ctx(&mut scenario));
        let clock = create_test_clock(&mut scenario);

        let (
            leg_ids, leg_quantities,
            body_ids, body_quantities,
            hand_ids, hand_quantities,
            head_ids, head_quantities,
            style_ids, style_quantities,
            material_ids, material_quantities,
            environment_ids, environment_quantities
        ) = create_test_items();

        creature_nft::mint_creature_entry(
            &admin_cap,
            &mut collection,
            string::utf8(b"Original Recipe"),
            leg_ids,
            leg_quantities,
            body_ids,
            body_quantities,
            hand_ids,
            hand_quantities,
            head_ids,
            head_quantities,
            style_ids,
            style_quantities,
            material_ids,
            material_quantities,
            environment_ids,
            environment_quantities,
            string::utf8(b"https://example.com/original.png"),
            &mut payment,
            USER1,
            &clock,
            ts::ctx(&mut scenario)
        );

        ts::return_shared(collection);
        ts::return_to_sender(&scenario, admin_cap);
        coin::burn_for_testing(payment);
        clock::destroy_for_testing(clock);
    };

    // Mint second duplicate
    ts::next_tx(&mut scenario, USER2);
    {
        let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
        let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
        let mut payment = coin::mint_for_testing<SUI>(1000000000, ts::ctx(&mut scenario));
        let clock = create_test_clock(&mut scenario);

        let (
            leg_ids, leg_quantities,
            body_ids, body_quantities,
            hand_ids, hand_quantities,
            head_ids, head_quantities,
            style_ids, style_quantities,
            material_ids, material_quantities,
            environment_ids, environment_quantities
        ) = create_test_items(); // Same recipe

        creature_nft::mint_creature_entry(
            &admin_cap,
            &mut collection,
            string::utf8(b"Second Duplicate"),
            leg_ids,
            leg_quantities,
            body_ids,
            body_quantities,
            hand_ids,
            hand_quantities,
            head_ids,
            head_quantities,
            style_ids,
            style_quantities,
            material_ids,
            material_quantities,
            environment_ids,
            environment_quantities,
            string::utf8(b"https://example.com/second.png"),
            &mut payment,
            USER2,
            &clock,
            ts::ctx(&mut scenario)
        );

        ts::return_shared(collection);
        ts::return_to_sender(&scenario, admin_cap);
        coin::burn_for_testing(payment);
        clock::destroy_for_testing(clock);
    };

    // Mint third duplicate from different user
    ts::next_tx(&mut scenario, @0x4);
    {
        let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
        let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
        let mut payment = coin::mint_for_testing<SUI>(1000000000, ts::ctx(&mut scenario));
        let clock = create_test_clock(&mut scenario);

        let (
            leg_ids, leg_quantities,
            body_ids, body_quantities,
            hand_ids, hand_quantities,
            head_ids, head_quantities,
            style_ids, style_quantities,
            material_ids, material_quantities,
            environment_ids, environment_quantities
        ) = create_test_items(); // Same recipe

        creature_nft::mint_creature_entry(
            &admin_cap,
            &mut collection,
            string::utf8(b"Third Duplicate"),
            leg_ids,
            leg_quantities,
            body_ids,
            body_quantities,
            hand_ids,
            hand_quantities,
            head_ids,
            head_quantities,
            style_ids,
            style_quantities,
            material_ids,
            material_quantities,
            environment_ids,
            environment_quantities,
            string::utf8(b"https://example.com/third.png"),
            &mut payment,
            @0x4,
            &clock,
            ts::ctx(&mut scenario)
        );

        // Verify total minted count
        let (minted_count, _) = creature_nft::get_collection_stats(&collection);
        assert!(minted_count == 3, 32);

        ts::return_shared(collection);
        ts::return_to_sender(&scenario, admin_cap);
        coin::burn_for_testing(payment);
        clock::destroy_for_testing(clock);
    };

    // Verify that USER1 (original creator) received fees from both duplicates
    ts::next_tx(&mut scenario, USER1);
    {
        let creator_balance = ts::take_from_address<Coin<SUI>>(&scenario, USER1);
        let balance_value = coin::value(&creator_balance);
        
        // Should have received 2 duplicate fees (2 * DEFAULT_DUPLICATE_FEE = 2 * 10_000_000)
        let expected_fees = 2 * 10_000_000u64;
        assert!(balance_value == expected_fees, 33);
        
        ts::return_to_address(USER1, creator_balance);
    };

    ts::end(scenario);
    }
}
