#[test_only]
module merg3::mer3_contract_tests {
    use std::string;
    use sui::test_scenario::{Self as ts};
    use sui::coin;
    use sui::sui::SUI;
    use sui::clock;

    use merg3::creature_nft::{Self, AdminCap, Collection, CreatureNFT};
    use merg3::pool_rewards::{Self, PoolAdminCap, PoolSystem};

    // Test addresses
    const ADMIN: address = @admin;
    const USER1: address = @0x2;
    const USER2: address = @0x3;

    // Test constants
    const PAYMENT_AMOUNT: u64 = 50_000_000_000; // 50 SUI


    // Test pool system initialization
    #[test]
    fun test_pool_system_initialization() {
        let mut scenario = ts::begin(ADMIN);
        
        // Initialize modules
        ts::next_tx(&mut scenario, ADMIN);
        {
            creature_nft::init_for_testing(ts::ctx(&mut scenario));
            pool_rewards::init_for_testing(ts::ctx(&mut scenario));
        };
        
        // Verify pool admin cap exists
        ts::next_tx(&mut scenario, ADMIN);
        {
            assert!(ts::has_most_recent_for_sender<PoolAdminCap>(&scenario), 0);
            assert!(ts::has_most_recent_for_sender<AdminCap>(&scenario), 1);
        };
        
        ts::end(scenario);
    }

    // Test NFT minting
    #[test]
    fun test_nft_minting() {
        let mut scenario = ts::begin(ADMIN);
        
        // Initialize modules
        ts::next_tx(&mut scenario, ADMIN);
        {
            creature_nft::init_for_testing(ts::ctx(&mut scenario));
        };

        // Mint NFT
        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut collection = ts::take_shared<Collection>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 1000000);
            
            // Mint NFT with required elements for USER1
            let mut payment_coin = coin::mint_for_testing<SUI>(0, ts::ctx(&mut scenario));
            
            creature_nft::admin_mint_nft(
                &admin_cap,
                &mut collection,
                string::utf8(b"Test NFT"),
                vector[1u64, 2u64], // Element IDs
                vector[1u64, 1u64], // Element quantities
                string::utf8(b"test prompt"),
                string::utf8(b"test_image.png"),
                &mut payment_coin,
                USER1,
                &clock,
                ts::ctx(&mut scenario)
            );
            
            coin::destroy_zero(payment_coin);
            clock::destroy_for_testing(clock);
            
            // Verify collection stats
            let (minted_count, _) = creature_nft::get_collection_stats(&collection);
            assert!(minted_count == 1, 2);
            
            ts::return_to_sender(&scenario, admin_cap);
            ts::return_shared(collection);
        };

        // Verify NFT was minted to USER1
        ts::next_tx(&mut scenario, USER1);
        {
            assert!(ts::has_most_recent_for_sender<CreatureNFT>(&scenario), 3);
        };
        
        ts::end(scenario);
    }

    // Test NFT item extraction functionality (needed for pool validation)
    #[test]
    fun test_nft_item_extraction() {
        let mut scenario = ts::begin(ADMIN);
        
        // Initialize and mint NFT
        ts::next_tx(&mut scenario, ADMIN);
        {
            creature_nft::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut collection = ts::take_shared<Collection>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 1000000);
            
            let mut payment_coin = coin::mint_for_testing<SUI>(0, ts::ctx(&mut scenario));
            
            creature_nft::admin_mint_nft(
                &admin_cap,
                &mut collection,
                string::utf8(b"Element NFT"),
                vector[1u64, 5u64, 10u64], // Multiple element IDs
                vector[2u64, 1u64, 3u64], // Different quantities
                string::utf8(b"element prompt"),
                string::utf8(b"element.png"),
                &mut payment_coin,
                USER1,
                &clock,
                ts::ctx(&mut scenario)
            );
            
            coin::destroy_zero(payment_coin);
            clock::destroy_for_testing(clock);
            
            ts::return_to_sender(&scenario, admin_cap);
            ts::return_shared(collection);
        };

        // Test item ID extraction
        ts::next_tx(&mut scenario, USER1);
        {
            let nft = ts::take_from_sender<CreatureNFT>(&scenario);
            
            // Extract all item IDs from the NFT
            let item_ids = creature_nft::get_all_item_ids(&nft);
            
            // Should have 3 unique item IDs: 1, 5, 10
            assert!(vector::length(&item_ids) == 3, 4);
            assert!(vector::contains(&item_ids, &1u64), 5);
            assert!(vector::contains(&item_ids, &5u64), 6);
            assert!(vector::contains(&item_ids, &10u64), 7);
            
            ts::return_to_sender(&scenario, nft);
        };
        
        ts::end(scenario);
    }

    // Test collection statistics
    #[test]
    fun test_collection_stats() {
        let mut scenario = ts::begin(ADMIN);
        
        ts::next_tx(&mut scenario, ADMIN);
        {
            creature_nft::init_for_testing(ts::ctx(&mut scenario));
        };

        // Check initial stats
        ts::next_tx(&mut scenario, ADMIN);
        {
            let collection = ts::take_shared<Collection>(&scenario);
            let (minted_count, treasury_balance) = creature_nft::get_collection_stats(&collection);
            
            assert!(minted_count == 0, 8);
            assert!(treasury_balance == 0, 9);
            
            ts::return_shared(collection);
        };

        // Mint multiple NFTs
        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut collection = ts::take_shared<Collection>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 1000000);
            
            // Mint first NFT
            let mut payment_coin1 = coin::mint_for_testing<SUI>(0, ts::ctx(&mut scenario));
            creature_nft::admin_mint_nft(
                &admin_cap, &mut collection, string::utf8(b"NFT 1"),
                vector[1u64], vector[1u64], string::utf8(b"prompt1"), 
                string::utf8(b"nft1.png"), &mut payment_coin1, USER1, &clock, ts::ctx(&mut scenario)
            );
            coin::destroy_zero(payment_coin1);
            
            // Mint second NFT
            let mut payment_coin2 = coin::mint_for_testing<SUI>(0, ts::ctx(&mut scenario));
            creature_nft::admin_mint_nft(
                &admin_cap, &mut collection, string::utf8(b"NFT 2"),
                vector[2u64], vector[1u64], string::utf8(b"prompt2"), 
                string::utf8(b"nft2.png"), &mut payment_coin2, USER2, &clock, ts::ctx(&mut scenario)
            );
            coin::destroy_zero(payment_coin2);
            
            clock::destroy_for_testing(clock);
            
            // Check updated stats
            let (minted_count, _) = creature_nft::get_collection_stats(&collection);
            assert!(minted_count == 2, 10);
            
            ts::return_to_sender(&scenario, admin_cap);
            ts::return_shared(collection);
        };
        
        ts::end(scenario);
    }

    // Test NFT info getters
    #[test]
    fun test_nft_info_getters() {
        let mut scenario = ts::begin(ADMIN);
        
        ts::next_tx(&mut scenario, ADMIN);
        {
            creature_nft::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut collection = ts::take_shared<Collection>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 1000000);
            
            let mut payment_coin = coin::mint_for_testing<SUI>(0, ts::ctx(&mut scenario));
            creature_nft::admin_mint_nft(
                &admin_cap, &mut collection, string::utf8(b"Info NFT"),
                vector[42u64], vector[1u64], string::utf8(b"info prompt"), 
                string::utf8(b"info.png"), &mut payment_coin, USER1, &clock, ts::ctx(&mut scenario)
            );
            coin::destroy_zero(payment_coin);
            clock::destroy_for_testing(clock);
            
            ts::return_to_sender(&scenario, admin_cap);
            ts::return_shared(collection);
        };

        ts::next_tx(&mut scenario, USER1);
        {
            let nft = ts::take_from_sender<CreatureNFT>(&scenario);
            
            // Test info getters
            let (name, creator, created_at) = creature_nft::get_nft_info(&nft);
            
            assert!(*name == string::utf8(b"Info NFT"), 11);
            assert!(creator == ADMIN, 12);
            assert!(created_at == 1000000, 13);
            
            ts::return_to_sender(&scenario, nft);
        };
        
        ts::end(scenario);
    }

    // Test name availability system
    #[test]
    fun test_name_availability() {
        let mut scenario = ts::begin(ADMIN);
        
        ts::next_tx(&mut scenario, ADMIN);
        {
            creature_nft::init_for_testing(ts::ctx(&mut scenario));
        };

        // Test name availability before minting
        ts::next_tx(&mut scenario, ADMIN);
        {
            let collection = ts::take_shared<Collection>(&scenario);
            
            let test_name = string::utf8(b"Unique Name");
            assert!(creature_nft::is_name_available(&collection, &test_name), 14);
            
            ts::return_shared(collection);
        };

        // Mint NFT with a specific name
        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut collection = ts::take_shared<Collection>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 1000000);
            
            let mut payment_coin = coin::mint_for_testing<SUI>(0, ts::ctx(&mut scenario));
            creature_nft::admin_mint_nft(
                &admin_cap, &mut collection, string::utf8(b"Unique Name"),
                vector[1u64], vector[1u64], string::utf8(b"unique prompt"), 
                string::utf8(b"unique.png"), &mut payment_coin, USER1, &clock, ts::ctx(&mut scenario)
            );
            coin::destroy_zero(payment_coin);
            clock::destroy_for_testing(clock);
            
            ts::return_to_sender(&scenario, admin_cap);
            ts::return_shared(collection);
        };

        // Test name availability after minting (should be taken)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let collection = ts::take_shared<Collection>(&scenario);
            
            let test_name = string::utf8(b"Unique Name");
            assert!(!creature_nft::is_name_available(&collection, &test_name), 15);
            
            // Different name should still be available
            let different_name = string::utf8(b"Different Name");
            assert!(creature_nft::is_name_available(&collection, &different_name), 16);
            
            ts::return_shared(collection);
        };
        
        ts::end(scenario);
    }

    // Test basic pool system functionality
    #[test]
    fun test_basic_pool_system() {
        let mut scenario = ts::begin(ADMIN);
        
        // Initialize pool system
        ts::next_tx(&mut scenario, ADMIN);
        {
            pool_rewards::init_for_testing(ts::ctx(&mut scenario));
        };

        // Check initial pool count
        ts::next_tx(&mut scenario, ADMIN);
        {
            let pool_system = ts::take_shared<PoolSystem>(&scenario);
            assert!(pool_rewards::get_pool_count(&pool_system) == 0, 17);
            ts::return_shared(pool_system);
        };
        
        ts::end(scenario);
    }

    // Test duplicate prompt payment system - Original recipe creator receives payment for duplicate prompts
    // In this test: ADMIN creates original recipe, then when duplicate prompt is used, ADMIN receives payment
    #[test]
    fun test_duplicate_prompt_payment() {
        let mut scenario = ts::begin(ADMIN);
        
        ts::next_tx(&mut scenario, ADMIN);
        {
            creature_nft::init_for_testing(ts::ctx(&mut scenario));
        };

        // USER1 creates first NFT with original prompt
        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut collection = ts::take_shared<Collection>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 1000000);
            
            let mut payment_coin = coin::mint_for_testing<SUI>(0, ts::ctx(&mut scenario));
            creature_nft::admin_mint_nft(
                &admin_cap, 
                &mut collection, 
                string::utf8(b"Original NFT"),
                vector[1u64], 
                vector[1u64], 
                string::utf8(b"unique creative prompt"), // Original prompt
                string::utf8(b"original.png"), 
                &mut payment_coin, 
                USER1, 
                &clock, 
                ts::ctx(&mut scenario)
            );
            coin::destroy_zero(payment_coin);
            clock::destroy_for_testing(clock);
            
            ts::return_to_sender(&scenario, admin_cap);
            ts::return_shared(collection);
        };

        // USER2 creates NFT with same prompt - should pay USER1
        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut collection = ts::take_shared<Collection>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 2000000);
            
            // USER2 provides payment that should go to USER1
            let mut payment_coin = coin::mint_for_testing<SUI>(PAYMENT_AMOUNT, ts::ctx(&mut scenario));
            creature_nft::admin_mint_nft(
                &admin_cap, 
                &mut collection, 
                string::utf8(b"Duplicate NFT"), // Different name
                vector[2u64], 
                vector[1u64], 
                string::utf8(b"unique creative prompt"), // Same prompt as USER1
                string::utf8(b"duplicate.png"), 
                &mut payment_coin, 
                USER2, 
                &clock, 
                ts::ctx(&mut scenario)
            );
            coin::destroy_zero(payment_coin);
            clock::destroy_for_testing(clock);
            
            ts::return_to_sender(&scenario, admin_cap);
            ts::return_shared(collection);
        };

        // Verify ADMIN received the payment (since ADMIN was the original recipe creator)
        ts::next_tx(&mut scenario, ADMIN);
        {
            // ADMIN should have received a SUI coin with the payment amount since ADMIN created original recipe
            assert!(ts::has_most_recent_for_sender<coin::Coin<SUI>>(&scenario), 18);
            let payment_received = ts::take_from_sender<coin::Coin<SUI>>(&scenario);
            assert!(coin::value(&payment_received) == PAYMENT_AMOUNT, 19);
            ts::return_to_sender(&scenario, payment_received);
        };

        // Verify both users received their NFTs
        ts::next_tx(&mut scenario, USER1);
        {
            assert!(ts::has_most_recent_for_sender<CreatureNFT>(&scenario), 20);
        };

        ts::next_tx(&mut scenario, USER2);
        {
            assert!(ts::has_most_recent_for_sender<CreatureNFT>(&scenario), 21);
        };
        
        ts::end(scenario);
    }

    // Test that recipe usage count increases for duplicate prompts
    #[test]
    fun test_recipe_usage_tracking() {
        let mut scenario = ts::begin(ADMIN);
        
        ts::next_tx(&mut scenario, ADMIN);
        {
            creature_nft::init_for_testing(ts::ctx(&mut scenario));
        };

        // Create first NFT (establishes the recipe)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut collection = ts::take_shared<Collection>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 1000000);
            
            let mut payment_coin = coin::mint_for_testing<SUI>(0, ts::ctx(&mut scenario));
            creature_nft::admin_mint_nft(
                &admin_cap, 
                &mut collection, 
                string::utf8(b"Recipe NFT 1"),
                vector[5u64], 
                vector[1u64], 
                string::utf8(b"tracked recipe prompt"),
                string::utf8(b"recipe1.png"), 
                &mut payment_coin, 
                USER1, 
                &clock, 
                ts::ctx(&mut scenario)
            );
            coin::destroy_zero(payment_coin);
            
            // Check collection stats after first mint
            let (minted_count, _) = creature_nft::get_collection_stats(&collection);
            assert!(minted_count == 1, 22);
            
            clock::destroy_for_testing(clock);
            ts::return_to_sender(&scenario, admin_cap);
            ts::return_shared(collection);
        };

        // Create second NFT with same prompt (should increment usage)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut collection = ts::take_shared<Collection>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 2000000);
            
            let mut payment_coin = coin::mint_for_testing<SUI>(10_000_000_000, ts::ctx(&mut scenario)); // 10 SUI
            creature_nft::admin_mint_nft(
                &admin_cap, 
                &mut collection, 
                string::utf8(b"Recipe NFT 2"),
                vector[6u64], 
                vector[1u64], 
                string::utf8(b"tracked recipe prompt"), // Same prompt
                string::utf8(b"recipe2.png"), 
                &mut payment_coin, 
                USER2, 
                &clock, 
                ts::ctx(&mut scenario)
            );
            coin::destroy_zero(payment_coin);
            
            // Check collection stats after second mint
            let (minted_count, _) = creature_nft::get_collection_stats(&collection);
            assert!(minted_count == 2, 23);
            
            clock::destroy_for_testing(clock);
            ts::return_to_sender(&scenario, admin_cap);
            ts::return_shared(collection);
        };
        
        ts::end(scenario);
    }

    // Test error handling with invalid name
    #[test]
    #[expected_failure(abort_code = merg3::creature_nft::ENameAlreadyExists)]
    fun test_duplicate_name_error() {
        let mut scenario = ts::begin(ADMIN);
        
        ts::next_tx(&mut scenario, ADMIN);
        {
            creature_nft::init_for_testing(ts::ctx(&mut scenario));
        };

        // Mint first NFT
        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut collection = ts::take_shared<Collection>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 1000000);
            
            let mut payment_coin = coin::mint_for_testing<SUI>(0, ts::ctx(&mut scenario));
            creature_nft::admin_mint_nft(
                &admin_cap, &mut collection, string::utf8(b"Duplicate Name"),
                vector[1u64], vector[1u64], string::utf8(b"first prompt"), 
                string::utf8(b"first.png"), &mut payment_coin, USER1, &clock, ts::ctx(&mut scenario)
            );
            coin::destroy_zero(payment_coin);
            clock::destroy_for_testing(clock);
            
            ts::return_to_sender(&scenario, admin_cap);
            ts::return_shared(collection);
        };

        // Try to mint second NFT with same name - should fail
        ts::next_tx(&mut scenario, ADMIN);
        {
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut collection = ts::take_shared<Collection>(&scenario);
            let mut clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::set_for_testing(&mut clock, 2000000);
            
            let mut payment_coin = coin::mint_for_testing<SUI>(0, ts::ctx(&mut scenario));
            creature_nft::admin_mint_nft(
                &admin_cap, &mut collection, string::utf8(b"Duplicate Name"), // Same name
                vector[2u64], vector[1u64], string::utf8(b"second prompt"), 
                string::utf8(b"second.png"), &mut payment_coin, USER2, &clock, ts::ctx(&mut scenario)
            );
            coin::destroy_zero(payment_coin);
            clock::destroy_for_testing(clock);
            
            ts::return_to_sender(&scenario, admin_cap);
            ts::return_shared(collection);
        };
        
        ts::end(scenario);
    }
}
