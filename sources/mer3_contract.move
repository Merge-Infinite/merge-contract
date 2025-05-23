// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module merg3::creature_nft {
    use std::hash;
    use std::string::{Self, String};
    use sui::event;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::table::{Self, Table};
    use sui::clock::{Self, Clock};
    use sui::vec_map::{Self, VecMap};

    // ========== Constants ==========
    
    /// Error codes
    const EInsufficientFee: u64 = 1;
    const EInvalidOwner: u64 = 2;
    const ENoRewardAvailable: u64 = 6;
    const EEventNotActive: u64 = 7;
    const EEventAlreadyActive: u64 = 8;
    const EInvalidEnvironment: u64 = 9;
    const EInvalidFeeRate: u64 = 10;

    /// Environment types
    const ENVIRONMENT_UNIVERSE: u8 = 0;
    const ENVIRONMENT_SKY: u8 = 1;
    const ENVIRONMENT_SEABED: u8 = 2;

    /// Time constants
    const MS_PER_DAY: u64 = 86_400_000;
    
    /// Default values
    const DEFAULT_CREATOR_FEE_BPS: u16 = 250; // 2.5%
    const DEFAULT_DUPLICATE_FEE: u64 = 10_000_000; // 0.01 SUI
    const DEFAULT_UNIVERSE_RATE: u64 = 600_000_000; // 0.6 SUI per day
    const DEFAULT_SKY_RATE: u64 = 200_000_000; // 0.2 SUI per day
    const DEFAULT_SEABED_RATE: u64 = 100_000_000; // 0.1 SUI per day
    const MAX_FEE_BPS: u16 = 10000; // 100%
    
    const ADMIN_ADDRESS: address = @admin;

    // ========== Core Structs ==========

    /// Admin capability for privileged operations
    public struct AdminCap has key {
        id: UID,
    }

    /// Main collection state - refactored for better organization
    public struct BrainrotCollection has key {
        id: UID,
        minted_count: u64,
        staking_stats: StakingStats,
        treasury: Balance<SUI>,
        config: CollectionConfig,
        events: EnvironmentEvents,
        pending_rewards: Table<object::ID, u64>
    }

    /// Consolidated configuration struct
    public struct CollectionConfig has store {
        creator_fee_bps: u16,
        duplicate_recipe_fee: u64,
        recipes: Table<vector<u8>, address>,
    }

    /// Staking statistics per environment
    public struct StakingStats has store {
        staked_universe: u64,
        staked_sky: u64,
        staked_seabed: u64,
    }

    /// Environment-specific events
    public struct EnvironmentEvents has store {
        universe_event: EventStatus,
        sky_event: EventStatus,
        seabed_event: EventStatus,
    }

    /// Event configuration and status
    public struct EventStatus has store, copy, drop {
        active: bool,
        start_time: u64,
        duration: u64,
        reward_rate: u64
    }

    /// NFT representation with cleaner structure
    public struct CreatureNFT has key, store {
        id: UID,
        metadata: NFTMetadata,
        recipe_hash: vector<u8>,
        creator: address,
        created_at: u64,
    }

    /// Separated NFT metadata for better organization
    public struct NFTMetadata has store {
        name: String,
        style: String,
        elements: VecMap<String, String>,
        image_uri: String,
    }

    /// Staking information
    public struct StakeInfo has key, store {
        id: UID,
        nft: CreatureNFT,
        owner: address,
        environment: u8,
        stake_time: u64,
        last_reward_time: u64,
    }

    // ========== Events ==========

    public struct NFTMinted has copy, drop {
        nft_id: object::ID,
        name: String,
        creator: address,
    }

    public struct NFTStaked has copy, drop {
        nft_id: object::ID,
        owner: address,
        environment: u8,
        stake_time: u64,
    }

    public struct NFTUnstaked has copy, drop {
        nft_id: object::ID,
        owner: address,
        environment: u8,
        total_staked_time: u64,
    }

    public struct RewardClaimed has copy, drop {
        owner: address,
        nft_id: object::ID,
        amount: u64,
    }

    public struct EventStarted has copy, drop {
        environment: u8,
        start_time: u64,
        duration: u64,
        reward_rate: u64,
    }

    public struct EventEnded has copy, drop {
        environment: u8,
        total_duration: u64,
    }

    // ========== Initialization ==========

    fun init(ctx: &mut TxContext) {
        transfer::transfer(
            AdminCap { id: object::new(ctx) }, 
            tx_context::sender(ctx)
        );

        let collection = BrainrotCollection {
            id: object::new(ctx),
            minted_count: 0,
            staking_stats: create_default_staking_stats(),
            treasury: balance::zero(),
            config: create_default_config(ctx),
            events: create_default_events(),
            pending_rewards: table::new(ctx)
        };
        transfer::share_object(collection);
    }

    fun create_default_staking_stats(): StakingStats {
        StakingStats {
            staked_universe: 0,
            staked_sky: 0,
            staked_seabed: 0,
        }
    }

    fun create_default_config(ctx: &mut TxContext): CollectionConfig {
        CollectionConfig {
            creator_fee_bps: DEFAULT_CREATOR_FEE_BPS,
            duplicate_recipe_fee: DEFAULT_DUPLICATE_FEE,
            recipes: table::new(ctx),
        }
    }

    fun create_default_events(): EnvironmentEvents {
        EnvironmentEvents {
            universe_event: create_default_event_status(DEFAULT_UNIVERSE_RATE),
            sky_event: create_default_event_status(DEFAULT_SKY_RATE),
            seabed_event: create_default_event_status(DEFAULT_SEABED_RATE),
        }
    }

    fun create_default_event_status(reward_rate: u64): EventStatus {
        EventStatus {
            active: false,
            start_time: 0,
            duration: 0,
            reward_rate
        }
    }

    // ========== Recipe Management ==========

    public fun calculate_recipe_hash(metadata: &NFTMetadata): vector<u8> {
        let serialized = serialize_recipe_data(&metadata.name, &metadata.style, &metadata.elements);
        hash::sha2_256(serialized)
    }

    fun serialize_recipe_data(
        name: &String, 
        style: &String,
        elements: &VecMap<String, String>
    ): vector<u8> {
        let mut serialized = vector::empty<u8>();
        
        append_with_separator(&mut serialized, string::as_bytes(name));
        append_with_separator(&mut serialized, string::as_bytes(style));
        
        // Serialize elements in consistent order
        let keys = vec_map::keys(elements);
        let mut i = 0;
        let keys_len = vector::length(&keys);
        
        while (i < keys_len) {
            let key = vector::borrow(&keys, i);
            let value = vec_map::get(elements, key);
            
            append_with_separator(&mut serialized, string::as_bytes(key));
            append_with_separator(&mut serialized, string::as_bytes(value));
            
            i = i + 1;
        };
        
        serialized
    }

    fun append_with_separator(serialized: &mut vector<u8>, data: &vector<u8>) {
        vector::append(serialized, *data);
        vector::push_back(serialized, 0u8); // null byte separator
    }

    public fun check_recipe(
        collection: &BrainrotCollection,
        recipe_hash: &vector<u8>
    ): (bool, address) {
        if (table::contains(&collection.config.recipes, *recipe_hash)) {
            (true, *table::borrow(&collection.config.recipes, *recipe_hash))
        } else {
            (false, @0x0)
        }
    }

    fun store_recipe(collection: &mut BrainrotCollection, recipe_hash: vector<u8>, creator: address) {
        table::add(&mut collection.config.recipes, recipe_hash, creator);
    }

    // ========== Environment Management ==========

    public fun validate_environment(environment: u8) {
        assert!(
            environment == ENVIRONMENT_UNIVERSE || 
            environment == ENVIRONMENT_SKY || 
            environment == ENVIRONMENT_SEABED, 
            EInvalidEnvironment
        );
    }

    fun get_event_status(collection: &BrainrotCollection, environment: u8): &EventStatus {
        match (environment) {
            ENVIRONMENT_UNIVERSE => &collection.events.universe_event,
            ENVIRONMENT_SKY => &collection.events.sky_event,
            ENVIRONMENT_SEABED => &collection.events.seabed_event,
            _ => abort EInvalidEnvironment
        }
    }

    fun get_event_status_mut(collection: &mut BrainrotCollection, environment: u8): &mut EventStatus {
        match (environment) {
            ENVIRONMENT_UNIVERSE => &mut collection.events.universe_event,
            ENVIRONMENT_SKY => &mut collection.events.sky_event,
            ENVIRONMENT_SEABED => &mut collection.events.seabed_event,
            _ => abort EInvalidEnvironment
        }
    }

    fun update_staking_count(stats: &mut StakingStats, environment: u8, increment: bool) {
        match (environment) {
            ENVIRONMENT_UNIVERSE => {
                if (increment) {
                    stats.staked_universe = stats.staked_universe + 1;
                } else {
                    stats.staked_universe = stats.staked_universe - 1;
                }
            },
            ENVIRONMENT_SKY => {
                if (increment) {
                    stats.staked_sky = stats.staked_sky + 1;
                } else {
                    stats.staked_sky = stats.staked_sky - 1;
                }
            },
            ENVIRONMENT_SEABED => {
                if (increment) {
                    stats.staked_seabed = stats.staked_seabed + 1;
                } else {
                    stats.staked_seabed = stats.staked_seabed - 1;
                }
            },
            _ => abort EInvalidEnvironment
        }
    }

    // ========== Reward System ==========

    public struct RewardCalculation has drop {
        amount: u64,
        valid: bool,
    }

    fun calculate_rewards(
        collection: &BrainrotCollection,
        last_reward_time: u64,
        environment: u8,
        current_time: u64
    ): RewardCalculation {
        if (current_time <= last_reward_time) {
            return RewardCalculation { amount: 0, valid: false }
        };
        
        let event_status = get_event_status(collection, environment);
        if (!event_status.active) {
            return RewardCalculation { amount: 0, valid: false }
        };
        
        let reward_amount = calculate_reward_amount(
            event_status,
            last_reward_time,
            current_time
        );
        
        RewardCalculation { amount: reward_amount, valid: true }
    }

    fun calculate_reward_amount(
        event_status: &EventStatus,
        last_reward_time: u64,
        current_time: u64
    ): u64 {
        let event_end = event_status.start_time + event_status.duration;
        let effective_start = max(last_reward_time, event_status.start_time);
        let effective_end = min(current_time, event_end);
        
        if (effective_end <= effective_start) {
            return 0
        };
        
        let time_diff_ms = effective_end - effective_start;
        let whole_days = time_diff_ms / MS_PER_DAY;
        let partial_day_ms = time_diff_ms % MS_PER_DAY;
        
        let mut reward_amount = event_status.reward_rate * whole_days;
        
        if (partial_day_ms > 0) {
            let partial_day_reward = (event_status.reward_rate * partial_day_ms) / MS_PER_DAY;
            reward_amount = reward_amount + partial_day_reward;
        };
        
        reward_amount
    }

    fun update_pending_rewards(
        pending_rewards: &mut Table<object::ID, u64>,
        stake_id: object::ID,
        reward_amount: u64
    ) {
        if (table::contains(pending_rewards, stake_id)) {
            let current_reward = table::borrow_mut(pending_rewards, stake_id);
            *current_reward = *current_reward + reward_amount;
        } else {
            table::add(pending_rewards, stake_id, reward_amount);
        }
    }

    // ========== NFT Operations ==========

    public fun mint_creature_nft(
        collection: &mut BrainrotCollection,
        metadata: NFTMetadata,
        payment: &mut Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ): CreatureNFT {
        let recipe_hash = calculate_recipe_hash(&metadata);
        let (exists, original_creator) = check_recipe(collection, &recipe_hash);
        
        handle_minting_payment(collection, payment, exists, original_creator, ctx);
        
        if (!exists) {
            store_recipe(collection, recipe_hash, tx_context::sender(ctx));
        };

        let nft = CreatureNFT {
            id: object::new(ctx),
            metadata,
            recipe_hash,
            creator: tx_context::sender(ctx),
            created_at: clock::timestamp_ms(clock),
        };

        collection.minted_count = collection.minted_count + 1;
        
        event::emit(NFTMinted {
            nft_id: object::id(&nft),
            name: nft.metadata.name,
            creator: nft.creator,
        });
        
        nft
    }

    fun handle_minting_payment(
        collection: &BrainrotCollection,
        payment: &mut Coin<SUI>,
        recipe_exists: bool,
        original_creator: address,
        ctx: &mut TxContext
    ) {
        let payment_amount = if (recipe_exists) {
            collection.config.duplicate_recipe_fee
        } else {
            0 // Free for new recipes
        };

        if (payment_amount > 0) {
            assert!(coin::value(payment) >= payment_amount, EInsufficientFee);
            let total_payment = coin::split(payment, payment_amount, ctx);
            let recipient = if (recipe_exists) { original_creator } else { ADMIN_ADDRESS };
            transfer::public_transfer(total_payment, recipient);
        }
    }

    public fun stake_nft(
        collection: &mut BrainrotCollection,
        nft: CreatureNFT,
        environment: u8,
        clock: &Clock,
        ctx: &mut TxContext
    ): StakeInfo {
        validate_environment(environment);
        
        let nft_id = object::id(&nft);
        let stake_time = clock::timestamp_ms(clock);
        
        let stake_info = StakeInfo {
            id: object::new(ctx),
            nft,
            owner: tx_context::sender(ctx),
            environment,
            stake_time,
            last_reward_time: stake_time,
        };
        
        update_staking_count(&mut collection.staking_stats, environment, true);
        
        event::emit(NFTStaked {
            nft_id,
            owner: tx_context::sender(ctx),
            environment,
            stake_time,
        });
        
        stake_info
    }

    public fun unstake_nft(
        collection: &mut BrainrotCollection,
        stake_info: StakeInfo,
        clock: &Clock,
        ctx: &TxContext
    ): CreatureNFT {
        assert!(stake_info.owner == tx_context::sender(ctx), EInvalidOwner);
                
        let nft_id = object::id(&stake_info.nft);
        let environment = stake_info.environment;
        let stake_time = stake_info.stake_time;
        let current_time = clock::timestamp_ms(clock);
        
        update_staking_count(&mut collection.staking_stats, environment, false);
        
        // Calculate and store final rewards
        let reward_calc = calculate_rewards(
            collection, 
            stake_info.last_reward_time, 
            environment, 
            current_time
        );
        
        if (reward_calc.valid && reward_calc.amount > 0) {
            let stake_id = object::id(&stake_info);
            update_pending_rewards(&mut collection.pending_rewards, stake_id, reward_calc.amount);
        };
        
        let total_staked_time = current_time - stake_time;
        
        event::emit(NFTUnstaked {
            nft_id,
            owner: tx_context::sender(ctx),
            environment,
            total_staked_time,
        });

        // Clean up stake info
        let StakeInfo { id, nft, owner: _, environment: _, stake_time: _, last_reward_time: _} = stake_info;
        id.delete();
        
        // Return the unfrozen NFT
        nft
    }

    public fun claim_rewards(
        collection: &mut BrainrotCollection,
        stake_info: &mut StakeInfo,
        clock: &Clock,
        ctx: &mut TxContext
    ): Coin<SUI> {
        assert!(stake_info.owner == tx_context::sender(ctx), EInvalidOwner);
        
        let stake_id = object::id(stake_info);
        let current_time = clock::timestamp_ms(clock);
        
        // Calculate new rewards
        let reward_calc = calculate_rewards(
            collection, 
            stake_info.last_reward_time, 
            stake_info.environment, 
            current_time
        );
        
        if (reward_calc.valid && reward_calc.amount > 0) {
            update_pending_rewards(&mut collection.pending_rewards, stake_id, reward_calc.amount);
        };
        
        stake_info.last_reward_time = current_time;
        
        let reward_amount = extract_pending_reward(&mut collection.pending_rewards, stake_id);
        validate_reward_claim(&collection.treasury, reward_amount);
        
        let reward_balance = balance::split(&mut collection.treasury, reward_amount);
        let reward_coin = coin::from_balance(reward_balance, ctx);
        
        event::emit(RewardClaimed {
            owner: stake_info.owner,
            nft_id: object::id(&stake_info.nft),
            amount: reward_amount,
        });
        
        reward_coin
    }

    fun extract_pending_reward(
        pending_rewards: &mut Table<object::ID, u64>,
        stake_id: object::ID
    ): u64 {
        if (table::contains(pending_rewards, stake_id)) {
            table::remove(pending_rewards, stake_id)
        } else {
            0
        }
    }

    fun validate_reward_claim(treasury: &Balance<SUI>, reward_amount: u64) {
        assert!(reward_amount > 0, ENoRewardAvailable);
        assert!(balance::value(treasury) >= reward_amount, EInsufficientFee);
    }

    // ========== Admin Functions ==========

    public entry fun start_event(
        _: &AdminCap,
        collection: &mut BrainrotCollection,
        environment: u8,
        duration_days: u64,
        reward_rate: u64,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        validate_environment(environment);
        
        let event_status = get_event_status_mut(collection, environment);
        assert!(!event_status.active, EEventAlreadyActive);
        
        let start_time = clock::timestamp_ms(clock);
        let duration_ms = duration_days * MS_PER_DAY;
        
        *event_status = EventStatus {
            active: true,
            start_time,
            duration: duration_ms,
            reward_rate,
        };
        
        event::emit(EventStarted {
            environment,
            start_time,
            duration: duration_ms,
            reward_rate,
        });
    }

    public entry fun end_event(
        _: &AdminCap,
        collection: &mut BrainrotCollection,
        environment: u8,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        validate_environment(environment);
        
        let event_status = get_event_status_mut(collection, environment);
        assert!(event_status.active, EEventNotActive);
        
        let current_time = clock::timestamp_ms(clock);
        let actual_duration = current_time - event_status.start_time;
        
        event_status.duration = actual_duration;
        event_status.active = false;
        
        event::emit(EventEnded {
            environment,
            total_duration: actual_duration,
        });
    }

    public entry fun add_treasury_funds(
        _: &AdminCap,
        collection: &mut BrainrotCollection,
        payment: &mut Coin<SUI>,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let coin_balance = coin::split(payment, amount, ctx);
        balance::join(&mut collection.treasury, coin::into_balance(coin_balance));
    }

    public entry fun update_reward_rate(
        _: &AdminCap,
        collection: &mut BrainrotCollection,
        environment: u8,
        reward_rate: u64,
    ) {
        validate_environment(environment);
        let event_status = get_event_status_mut(collection, environment);
        event_status.reward_rate = reward_rate;
    }

    public entry fun update_duplicate_recipe_fee(
        _: &AdminCap,
        collection: &mut BrainrotCollection,
        fee_amount: u64,
    ) {
        collection.config.duplicate_recipe_fee = fee_amount;
    }

    public entry fun update_creator_fee(
        _: &AdminCap,
        collection: &mut BrainrotCollection,
        fee_bps: u16,
    ) {
        assert!(fee_bps <= MAX_FEE_BPS, EInvalidFeeRate);
        collection.config.creator_fee_bps = fee_bps;
    }

    // ========== Utility Functions ==========

    fun max(a: u64, b: u64): u64 {
        if (a > b) { a } else { b }
    }

    fun min(a: u64, b: u64): u64 {
        if (a < b) { a } else { b }
    }

    public fun create_nft_metadata(
        name: String,
        style: String,
        elements: VecMap<String, String>,
        image_uri: String
    ): NFTMetadata {
        NFTMetadata {
            name,
            style,
            elements,
            image_uri,
        }
    }

    // ========== Public Entry Functions ==========

    public entry fun mint_creature_entry(
        _: &AdminCap,
        collection: &mut BrainrotCollection,
        name: String,
        style: String,
        head: String,
        head_accessory: String,
        body: String,
        hand: String,
        leg: String,
        environment: String,
        image_uri: String,
        payment: &mut Coin<SUI>,
        recipient: address,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let elements = build_elements_map(head, head_accessory, body, hand, leg, environment);
        let metadata = create_nft_metadata(name, style, elements, image_uri);
        
        let nft = mint_creature_nft(collection, metadata, payment, clock, ctx);
        transfer::public_transfer(nft, recipient);
    }

    fun build_elements_map(
        head: String,
        head_accessory: String,
        body: String,
        hand: String,
        leg: String,
        environment: String
    ): VecMap<String, String> {
        let mut elements = vec_map::empty<String, String>();
        
        add_element_if_non_empty(&mut elements, string::utf8(b"head"), head);
        add_element_if_non_empty(&mut elements, string::utf8(b"head_accessory"), head_accessory);
        add_element_if_non_empty(&mut elements, string::utf8(b"body"), body);
        add_element_if_non_empty(&mut elements, string::utf8(b"hand"), hand);
        add_element_if_non_empty(&mut elements, string::utf8(b"leg"), leg);
        add_element_if_non_empty(&mut elements, string::utf8(b"environment"), environment);
        
        elements
    }

    fun add_element_if_non_empty(
        elements: &mut VecMap<String, String>,
        key: String,
        value: String
    ) {
        if (string::length(&value) > 0) {
            vec_map::insert(elements, key, value);
        }
    }

    public entry fun stake_creature_entry(
        collection: &mut BrainrotCollection,
        nft: CreatureNFT,
        environment_code: u8,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let stake_info = stake_nft(collection, nft, environment_code, clock, ctx);
        transfer::public_transfer(stake_info, tx_context::sender(ctx));
    }

    public entry fun unstake_creature_entry(
        collection: &mut BrainrotCollection,
        stake_info: StakeInfo,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let nft = unstake_nft(collection, stake_info, clock, ctx);
        transfer::public_transfer(nft, tx_context::sender(ctx));
    }

    public entry fun claim_staking_rewards_entry(
        collection: &mut BrainrotCollection,
        stake_info: &mut StakeInfo,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let reward = claim_rewards(collection, stake_info, clock, ctx);
        transfer::public_transfer(reward, tx_context::sender(ctx));
    }

    // ========== View Functions ==========

    public fun get_collection_stats(collection: &BrainrotCollection): (u64, u64, u64, u64, u64) {
        (
            collection.minted_count,
            collection.staking_stats.staked_universe,
            collection.staking_stats.staked_sky,
            collection.staking_stats.staked_seabed,
            balance::value(&collection.treasury)
        )
    }

    public fun get_nft_info(nft: &CreatureNFT): (&String, &String, address, u64) {
        (&nft.metadata.name, &nft.metadata.style, nft.creator, nft.created_at)
    }

    public fun get_stake_info(stake: &StakeInfo): (object::ID, address, u8, u64, u64) {
        (object::id(&stake.nft), stake.owner, stake.environment, stake.stake_time, stake.last_reward_time)
    }

    // ========== Test Functions ==========

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }

    #[test_only]
    public fun get_name(nft: &CreatureNFT): String { 
        nft.metadata.name 
    }

    #[test_only]
    public fun get_style(nft: &CreatureNFT): String { 
        nft.metadata.style 
    }

    #[test_only]
    public fun get_creator(nft: &CreatureNFT): address { 
        nft.creator 
    }

    #[test_only]
    public fun get_minted_count(collection: &BrainrotCollection): u64 { 
        collection.minted_count 
    }

    #[test_only]
    public fun get_recipe_hash(nft: &CreatureNFT): vector<u8> {
        nft.recipe_hash
    }

    #[test_only]
    public fun get_image_uri(nft: &CreatureNFT): String {
        nft.metadata.image_uri
    }

    #[test_only]
    public fun get_created_at(nft: &CreatureNFT): u64 {
        nft.created_at
    }
}
