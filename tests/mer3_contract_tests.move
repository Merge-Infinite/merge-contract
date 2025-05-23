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
    };

    // Test addresses
    const ADMIN: address = @admin;
    const USER1: address = @0x2;
    const USER2: address = @0x3;
    const ORIGINAL_CREATOR: address = @0x4;

    // Helper function to create a test scenario
    fun create_test_scenario(): Scenario {
        ts::begin(ADMIN)
    }

    // Helper function to create a test coin with specific amount
    fun create_test_coin(amount: u64, scenario: &mut Scenario): Coin<SUI> {
        coin::mint_for_testing<SUI>(amount, ts::ctx(scenario))
    }

    // Helper function to create a test clock
    fun create_test_clock(scenario: &mut Scenario): Clock {
        clock::create_for_testing(ts::ctx(scenario))
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

            // Test minting with new recipe
            let name = string::utf8(b"Fire Dragon");
            let style = string::utf8(b"Mystical");
            let image_uri = string::utf8(b"https://example.com/dragon.png");

            creature_nft::mint_creature_entry(
                &admin_cap,
                &mut collection,
                name,
                style,
                string::utf8(b"Dragon Head"),
                string::utf8(b"Crown"),
                string::utf8(b"Scaled Body"),
                string::utf8(b"Clawed Hand"),
                string::utf8(b"Powerful Leg"),
                string::utf8(b"Fire"),
                image_uri,
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
            assert!(creature_nft::get_name(&nft) == string::utf8(b"Fire Dragon"), 2);
            assert!(creature_nft::get_style(&nft) == string::utf8(b"Mystical"), 3);
            assert!(creature_nft::get_creator(&nft) == ADMIN, 4);
            
            ts::return_to_sender(&scenario, nft);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_mint_duplicate_recipe() {
        let mut scenario = create_test_scenario();
        
        // Initialize the module
        ts::next_tx(&mut scenario, ADMIN);
        {
            creature_nft::init_for_testing(ts::ctx(&mut scenario));
        };

        // First mint - new recipe
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

        // Second mint - duplicate recipe (should charge fee)
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
            assert!(creature_nft::get_minted_count(&collection) == 2, 5);

            ts::return_shared(collection);
            ts::return_to_address(ADMIN, admin_cap);
            coin::burn_for_testing(payment);
            clock::destroy_for_testing(clock);
        };

        ts::end(scenario);
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
                0, // ENVIRONMENT_UNIVERSE
                &clock,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(collection);
            clock::destroy_for_testing(clock);
        };

        // Verify stake info was created
        ts::next_tx(&mut scenario, USER1);
        {
            assert!(ts::has_most_recent_for_sender<StakeInfo>(&scenario), 6);
            let stake_info = ts::take_from_sender<StakeInfo>(&scenario);
            
            // Verify stake info
            let (nft_id, owner, environment, stake_time, last_reward_time) = creature_nft::get_stake_info(&stake_info);
            assert!(owner == USER1, 7);
            assert!(environment == 0, 8);
            assert!(stake_time == last_reward_time, 9);
            
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

            ts::return_shared(collection);
            clock::destroy_for_testing(clock);
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
                0, // ENVIRONMENT_UNIVERSE
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
                0, // ENVIRONMENT_UNIVERSE
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
            assert!(treasury_balance == 500000000, 10);

            ts::return_shared(collection);
            ts::return_to_sender(&scenario, admin_cap);
            coin::burn_for_testing(payment);
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
            
            assert!(minted_count == 0, 11);
            assert!(staked_universe == 0, 12);
            assert!(staked_sky == 0, 13);
            assert!(staked_seabed == 0, 14);
            assert!(treasury_balance == 0, 15);

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
                0, // ENVIRONMENT_UNIVERSE
                800000000 // 0.8 SUI per day
            );

            ts::return_shared(collection);
            ts::return_to_sender(&scenario, admin_cap);
        };

        ts::end(scenario);
    }
}
