#[test_only]
module merg3::creature_nft_tests {
    use std::string::{Self, String};
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use sui::vec_map;
    use merg3::creature_nft::{
        Self,
        AdminCap,
        BrainrotCollection,
        CreatureNFT,
        StakeInfo,
        NFTMetadata,
    };

    // Test addresses
    const ADMIN: address = @admin;
    const USER1: address = @0x2;
    const USER2: address = @0x3;

    // Environment constants for testing
    const ENVIRONMENT_UNIVERSE: u8 = 0;
    const ENVIRONMENT_SKY: u8 = 1;
    const ENVIRONMENT_SEABED: u8 = 2;

    // Helper function to create a test scenario
    fun create_test_scenario(): Scenario {
        ts::begin(ADMIN)
    }

    // Helper function to create a test coin with specific amount
    #[allow(unused_function)]
    fun create_test_coin(amount: u64, scenario: &mut Scenario): Coin<SUI> {
        coin::mint_for_testing<SUI>(amount, ts::ctx(scenario))
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

    // Helper function to create test NFT metadata
    fun create_test_metadata(): NFTMetadata {
        let mut elements = vec_map::empty<String, String>();
        vec_map::insert(&mut elements, string::utf8(b"head"), string::utf8(b"Dragon Head"));
        vec_map::insert(&mut elements, string::utf8(b"head_accessory"), string::utf8(b"Crown"));
        vec_map::insert(&mut elements, string::utf8(b"body"), string::utf8(b"Scaled Body"));
        vec_map::insert(&mut elements, string::utf8(b"hand"), string::utf8(b"Clawed Hand"));
        vec_map::insert(&mut elements, string::utf8(b"leg"), string::utf8(b"Powerful Leg"));
        vec_map::insert(&mut elements, string::utf8(b"environment"), string::utf8(b"Fire"));

        creature_nft::create_nft_metadata(
            string::utf8(b"Fire Dragon"),
            string::utf8(b"Mystical"),
            elements,
            string::utf8(b"https://example.com/dragon.png")
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

            // Test minting with new recipe - should be free for new recipes
            creature_nft::mint_creature_entry(
                &admin_cap,
                &mut collection,
                string::utf8(b"Fire Dragon"),
                string::utf8(b"Mystical"),
                string::utf8(b"Dragon Head"),
                string::utf8(b"Crown"),
                string::utf8(b"Scaled Body"),
                string::utf8(b"Clawed Hand"),
                string::utf8(b"Powerful Leg"),
                string::utf8(b"Fire"),
                string::utf8(b"https://example.com/dragon.png"),
                &mut payment,
                USER1,
                &clock,
                ts::ctx(&mut scenario)
            );

            // Verify collection state
            assert!(creature_nft::get_minted_count(&collection) == 1, 0);

            // Clean up
            ts::return_shared(collection);
            ts::return_to_sender(&scenario, admin_cap);
            coin::burn_for_testing(payment);
            clock::destroy_for_testing(clock);
        };

        // Verify NFT was transferred to USER1
        ts::next_tx(&mut scenario, USER1);
        {
            assert!(ts::has_most_recent_for_sender<CreatureNFT>(&scenario), 1);
            let nft = ts::take_from_sender<CreatureNFT>(&scenario);
            
            // Verify NFT properties
            let (name, style, creator, created_at) = creature_nft::get_nft_info(&nft);
            assert!(*name == string::utf8(b"Fire Dragon"), 2);
            assert!(*style == string::utf8(b"Mystical"), 3);
            assert!(creator == ADMIN, 4);
            assert!(created_at > 0, 5);
            
            ts::return_to_sender(&scenario, nft);
        };

        let _ = ts::end(scenario);
    }

    #[test]
    fun test_mint_duplicate_recipe_with_fee() {
        let mut scenario = create_test_scenario();
        
        // Initialize the module
        ts::next_tx(&mut scenario, ADMIN);
        {
            creature_nft::init_for_testing(ts::ctx(&mut scenario));
        };

        // First mint - new recipe (free)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut payment = coin::mint_for_testing<SUI>(1000000000, ts::ctx(&mut scenario));
            let clock = create_test_clock(&mut scenario);

            creature_nft::mint_creature_entry(
                &admin_cap,
                &mut collection,
                string::utf8(b"Fire Dragon"),
                string::utf8(b"Mystical"),
                string::utf8(b"Dragon Head"),
                string::utf8(b"Crown"),
                string::utf8(b"Scaled Body"),
                string::utf8(b"Clawed Hand"),
                string::utf8(b"Powerful Leg"),
                string::utf8(b"Fire"),
                string::utf8(b"https://example.com/dragon.png"),
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

        // Second mint - duplicate recipe (should charge fee to original creator)
        ts::next_tx(&mut scenario, USER2);
        {
            let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
            let admin_cap = ts::take_from_address<AdminCap>(&scenario, ADMIN);
            let mut payment = coin::mint_for_testing<SUI>(1000000000, ts::ctx(&mut scenario));
            let clock = create_test_clock(&mut scenario);

            creature_nft::mint_creature_entry(
                &admin_cap,
                &mut collection,
                string::utf8(b"Fire Dragon"),
                string::utf8(b"Mystical"),
                string::utf8(b"Dragon Head"),
                string::utf8(b"Crown"),
                string::utf8(b"Scaled Body"),
                string::utf8(b"Clawed Hand"),
                string::utf8(b"Powerful Leg"),
                string::utf8(b"Fire"),
                string::utf8(b"https://example.com/dragon.png"),
                &mut payment,
                USER2,
                &clock,
                ts::ctx(&mut scenario)
            );

            // Verify both NFTs were minted
            assert!(creature_nft::get_minted_count(&collection) == 2, 6);

            ts::return_shared(collection);
            ts::return_to_address(ADMIN, admin_cap);
            coin::burn_for_testing(payment);
            clock::destroy_for_testing(clock);
        };

        let _ = ts::end(scenario);
    }

    #[test]
    fun test_staking_and_unstaking() {
        let mut scenario = create_test_scenario();
        
        // Initialize and mint NFT
        ts::next_tx(&mut scenario, ADMIN);
        {
            creature_nft::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut payment = coin::mint_for_testing<SUI>(1000000000, ts::ctx(&mut scenario));
            let clock = create_test_clock(&mut scenario);

            creature_nft::mint_creature_entry(
                &admin_cap,
                &mut collection,
                string::utf8(b"Test NFT"),
                string::utf8(b"Test Style"),
                string::utf8(b"Head"),
                string::utf8(b""),
                string::utf8(b"Body"),
                string::utf8(b"Hand"),
                string::utf8(b"Leg"),
                string::utf8(b"Universe"),
                string::utf8(b"https://example.com/test.png"),
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

        // User stakes the NFT
        ts::next_tx(&mut scenario, USER1);
        {
            let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
            let nft = ts::take_from_sender<CreatureNFT>(&scenario);
            let clock = create_test_clock(&mut scenario);

            creature_nft::stake_creature_entry(
                &mut collection,
                nft,
                ENVIRONMENT_UNIVERSE,
                &clock,
                ts::ctx(&mut scenario)
            );

            // Verify staking stats updated
            let (_, staked_universe, _staked_sky, _staked_seabed, _) = creature_nft::get_collection_stats(&collection);
            assert!(staked_universe == 1, 7);
            // Other environments should still be 0

            ts::return_shared(collection);
            clock::destroy_for_testing(clock);
        };

        // Verify stake info was created
        ts::next_tx(&mut scenario, USER1);
        {
            assert!(ts::has_most_recent_for_sender<StakeInfo>(&scenario), 10);
            let stake_info = ts::take_from_sender<StakeInfo>(&scenario);
            
            // Verify stake info
            let (_nft_id, owner, environment, stake_time, last_reward_time) = creature_nft::get_stake_info(&stake_info);
            assert!(owner == USER1, 11);
            assert!(environment == ENVIRONMENT_UNIVERSE, 12);
            assert!(stake_time == last_reward_time, 13);
            
            ts::return_to_sender(&scenario, stake_info);
        };

        // User unstakes the NFT
        ts::next_tx(&mut scenario, USER1);
        {
            let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
            let stake_info = ts::take_from_sender<StakeInfo>(&scenario);
            let clock = create_test_clock(&mut scenario);

            creature_nft::unstake_creature_entry(
                &mut collection,
                stake_info,
                &clock,
                ts::ctx(&mut scenario)
            );

            // Verify staking stats updated
            let (_, staked_universe, _staked_sky, _staked_seabed, _) = creature_nft::get_collection_stats(&collection);
            assert!(staked_universe == 0, 14);

            ts::return_shared(collection);
            clock::destroy_for_testing(clock);
        };

        // Verify NFT was returned
        ts::next_tx(&mut scenario, USER1);
        {
            assert!(ts::has_most_recent_for_sender<CreatureNFT>(&scenario), 15);
            let nft = ts::take_from_sender<CreatureNFT>(&scenario);
            ts::return_to_sender(&scenario, nft);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_event_management() {
        let mut scenario = create_test_scenario();
        
        // Initialize the module
        ts::next_tx(&mut scenario, ADMIN);
        {
            creature_nft::init_for_testing(ts::ctx(&mut scenario));
        };

        // Start an event
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let clock = create_test_clock(&mut scenario);

            creature_nft::start_event(
                &admin_cap,
                &mut collection,
                ENVIRONMENT_UNIVERSE,
                7, // 7 days
                1000000000, // 1 SUI per day
                &clock,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(collection);
            ts::return_to_sender(&scenario, admin_cap);
            clock::destroy_for_testing(clock);
        };

        // End the event
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let clock = create_test_clock(&mut scenario);

            creature_nft::end_event(
                &admin_cap,
                &mut collection,
                ENVIRONMENT_UNIVERSE,
                &clock,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(collection);
            ts::return_to_sender(&scenario, admin_cap);
            clock::destroy_for_testing(clock);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_treasury_funding() {
        let mut scenario = create_test_scenario();
        
        // Initialize the module
        ts::next_tx(&mut scenario, ADMIN);
        {
            creature_nft::init_for_testing(ts::ctx(&mut scenario));
        };

        // Add funds to treasury
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut payment = coin::mint_for_testing<SUI>(1000000000, ts::ctx(&mut scenario));

            creature_nft::add_treasury_funds(
                &admin_cap,
                &mut collection,
                &mut payment,
                500000000, // 0.5 SUI
                ts::ctx(&mut scenario)
            );

            // Verify treasury balance increased
            let (_, _, _, _, treasury_balance) = creature_nft::get_collection_stats(&collection);
            assert!(treasury_balance == 500000000, 16);

            ts::return_shared(collection);
            ts::return_to_sender(&scenario, admin_cap);
            coin::burn_for_testing(payment);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_reward_claiming() {
        let mut scenario = create_test_scenario();
        
        // Initialize and setup
        ts::next_tx(&mut scenario, ADMIN);
        {
            creature_nft::init_for_testing(ts::ctx(&mut scenario));
        };

        // Add treasury funds and start event
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut payment = coin::mint_for_testing<SUI>(10000000000, ts::ctx(&mut scenario)); // 10 SUI
            let clock = create_test_clock(&mut scenario);

            // Fund treasury
            creature_nft::add_treasury_funds(
                &admin_cap,
                &mut collection,
                &mut payment,
                5000000000, // 5 SUI
                ts::ctx(&mut scenario)
            );

            // Start universe event
            creature_nft::start_event(
                &admin_cap,
                &mut collection,
                ENVIRONMENT_UNIVERSE,
                30, // 30 days
                600000000, // 0.6 SUI per day (default rate)
                &clock,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(collection);
            ts::return_to_sender(&scenario, admin_cap);
            coin::burn_for_testing(payment);
            clock::destroy_for_testing(clock);
        };

        // Mint and stake NFT
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            let mut payment = coin::mint_for_testing<SUI>(1000000000, ts::ctx(&mut scenario));
            let clock = create_test_clock(&mut scenario);

            creature_nft::mint_creature_entry(
                &admin_cap,
                &mut collection,
                string::utf8(b"Reward NFT"),
                string::utf8(b"Test Style"),
                string::utf8(b"Head"),
                string::utf8(b""),
                string::utf8(b"Body"),
                string::utf8(b"Hand"),
                string::utf8(b"Leg"),
                string::utf8(b"Universe"),
                string::utf8(b"https://example.com/reward.png"),
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

        // User stakes NFT
        ts::next_tx(&mut scenario, USER1);
        {
            let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
            let nft = ts::take_from_sender<CreatureNFT>(&scenario);
            let clock = create_test_clock(&mut scenario);

            creature_nft::stake_creature_entry(
                &mut collection,
                nft,
                ENVIRONMENT_UNIVERSE,
                &clock,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(collection);
            clock::destroy_for_testing(clock);
        };

        // Simulate time passing and claim rewards
        ts::next_tx(&mut scenario, USER1);
        {
            let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
            let mut stake_info = ts::take_from_sender<StakeInfo>(&scenario);
            let clock = create_test_clock_with_time(87400000, &mut scenario); // 1 day + 1000 seconds later

            creature_nft::claim_staking_rewards_entry(
                &mut collection,
                &mut stake_info,
                &clock,
                ts::ctx(&mut scenario)
            );

            // The entry function automatically transfers rewards to the caller
            // We're mainly testing that the function executes without error

            ts::return_shared(collection);
            ts::return_to_sender(&scenario, stake_info);
            clock::destroy_for_testing(clock);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_view_functions() {
        let mut scenario = create_test_scenario();
        
        // Initialize the module
        ts::next_tx(&mut scenario, ADMIN);
        {
            creature_nft::init_for_testing(ts::ctx(&mut scenario));
        };

        // Test collection stats
        ts::next_tx(&mut scenario, ADMIN);
        {
            let collection = ts::take_shared<BrainrotCollection>(&scenario);
            
            let (minted_count, staked_universe, staked_sky, staked_seabed, treasury_balance) = 
                creature_nft::get_collection_stats(&collection);
            
            assert!(minted_count == 0, 17);
            assert!(staked_universe == 0, 18);
            assert!(staked_sky == 0, 19);
            assert!(staked_seabed == 0, 20);
            assert!(treasury_balance == 0, 21);

            ts::return_shared(collection);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_configuration_updates() {
        let mut scenario = create_test_scenario();
        
        // Initialize the module
        ts::next_tx(&mut scenario, ADMIN);
        {
            creature_nft::init_for_testing(ts::ctx(&mut scenario));
        };

        // Update duplicate recipe fee
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);

            creature_nft::update_duplicate_recipe_fee(
                &admin_cap,
                &mut collection,
                20000000 // 0.02 SUI
            );

            ts::return_shared(collection);
            ts::return_to_sender(&scenario, admin_cap);
        };

        // Update creator fee
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);

            creature_nft::update_creator_fee(
                &admin_cap,
                &mut collection,
                500 // 5%
            );

            ts::return_shared(collection);
            ts::return_to_sender(&scenario, admin_cap);
        };

        // Update reward rate
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);

            creature_nft::update_reward_rate(
                &admin_cap,
                &mut collection,
                ENVIRONMENT_UNIVERSE,
                800000000 // 0.8 SUI per day
            );

            ts::return_shared(collection);
            ts::return_to_sender(&scenario, admin_cap);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_recipe_hash_consistency() {
        let mut scenario = create_test_scenario();
        
        // Initialize
        ts::next_tx(&mut scenario, ADMIN);
        {
            creature_nft::init_for_testing(ts::ctx(&mut scenario));
        };

        // Create two identical metadata objects
        ts::next_tx(&mut scenario, ADMIN);
        {
            let metadata1 = create_test_metadata();
            let metadata2 = create_test_metadata();
            
            // Both should produce the same hash
            let hash1 = creature_nft::calculate_recipe_hash(&metadata1);
            let hash2 = creature_nft::calculate_recipe_hash(&metadata2);
            
            assert!(hash1 == hash2, 22);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_multiple_environment_staking() {
        let mut scenario = create_test_scenario();
        
        // Initialize and mint multiple NFTs
        ts::next_tx(&mut scenario, ADMIN);
        {
            creature_nft::init_for_testing(ts::ctx(&mut scenario));
        };

        // Mint 3 NFTs for different environments
        let mut i = 0;
        while (i < 3) {
            ts::next_tx(&mut scenario, ADMIN);
            {
                let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
                let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
                let mut payment = coin::mint_for_testing<SUI>(1000000000, ts::ctx(&mut scenario));
                let clock = create_test_clock(&mut scenario);

                creature_nft::mint_creature_entry(
                    &admin_cap,
                    &mut collection,
                    string::utf8(b"Multi NFT"),
                    string::utf8(b"Test Style"),
                    string::utf8(b"Head"),
                    string::utf8(b""),
                    string::utf8(b"Body"),
                    string::utf8(b"Hand"),
                    string::utf8(b"Leg"),
                    string::utf8(b"Test"),
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
            i = i + 1;
        };

        // Stake NFTs in different environments
        let environments = vector[ENVIRONMENT_UNIVERSE, ENVIRONMENT_SKY, ENVIRONMENT_SEABED];
        i = 0;
        while (i < 3) {
            ts::next_tx(&mut scenario, USER1);
            {
                let mut collection = ts::take_shared<BrainrotCollection>(&scenario);
                let nft = ts::take_from_sender<CreatureNFT>(&scenario);
                let clock = create_test_clock(&mut scenario);

                creature_nft::stake_creature_entry(
                    &mut collection,
                    nft,
                    *vector::borrow(&environments, i),
                    &clock,
                    ts::ctx(&mut scenario)
                );

                ts::return_shared(collection);
                clock::destroy_for_testing(clock);
            };
            i = i + 1;
        };

        // Verify staking stats
        ts::next_tx(&mut scenario, USER1);
        {
            let collection = ts::take_shared<BrainrotCollection>(&scenario);
            let (_, staked_universe, staked_sky, staked_seabed, _) = creature_nft::get_collection_stats(&collection);
            
            assert!(staked_universe == 1, 23);
            assert!(staked_sky == 1, 24);
            assert!(staked_seabed == 1, 25);

            ts::return_shared(collection);
        };

        ts::end(scenario);
    }
}
