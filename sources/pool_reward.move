// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module merg3::pool_rewards {
    use std::string::{String};
    use sui::event;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::table::{Self, Table};
    use sui::clock::{Self, Clock};
    use sui::object_table::{Self, ObjectTable};
    use merg3::creature_nft::{Self, CreatureNFT};

    // ========== Constants ==========
    
    /// Error codes
    const EPoolNotFound: u64 = 1;
    const EPoolNotActive: u64 = 2;
    const EPoolAlreadyActive: u64 = 3;
    const EInvalidOwner: u64 = 4;
    const EInsufficientBalance: u64 = 5;
    const EPoolEnded: u64 = 6;
    const EInvalidTimeRange: u64 = 7;
    const ENoStakedNFTs: u64 = 8;
    const ERewardsNotReady: u64 = 9;
    const EElementNotFound: u64 = 11;

    /// Time constants
    const MS_PER_HOUR: u64 = 3_600_000;
    const REWARD_UPDATE_INTERVAL: u64 = 21_600_000; // 6 hours

    /// Admin capability for pool management
    public struct PoolAdminCap has key {
        id: UID,
    }

    /// Main pool system state
    public struct PoolSystem has key {
        id: UID,
        pools: ObjectTable<ID, Pool>,
        pool_counter: u64,
        global_config: GlobalConfig,
    }

    public struct GlobalConfig has store {
        reward_update_interval: u64,
    }

    /// Individual pool configuration and state
    public struct Pool has key, store {
        id: UID,
        pool_id: ID,
        name: String,
        description: String,
        creator: address,
        image_url: String,
        
        // Pool requirements - array of required element IDs
        required_elements: vector<u64>, // e.g., [1, 5, 12] for specific element IDs
        
        // Time management
        start_time: u64,
        end_time: u64,
        is_active: bool,
        
        // Current rewards state - only SUI rewards
        sui_reward_pool: Balance<SUI>,
        last_reward_update: u64,
        
        // Staking data
        staked_nfts: ObjectTable<ID, StakedNFT>,
        user_stakes: Table<address, UserStakeInfo>,
        total_staked_count: u64,
        total_weight: u64,
        
        // NEW: Track NFT IDs separately for iteration
        staked_nft_ids: vector<ID>,
        
        // Participant tracking
        unique_participants: Table<address, bool>,
        participant_count: u64,
    }

    public struct UserStakeInfo has store {
        nft_count: u64,
        total_weight: u64,
        stake_start_time: u64,
        pending_sui_rewards: u64,
        last_reward_claim: u64,
    }

    /// Information about a staked NFT
    public struct StakedNFT has key, store {
        id: UID,
        nft: CreatureNFT,
        owner: address,
        pool_id: ID,
        stake_time: u64,
        weight: u64, // calculated based on stake time
    }

    // ========== Events ==========

    public struct PoolCreated has copy, drop {
        pool_id: ID,
        name: String,
        creator: address,
        start_time: u64,
        end_time: u64,
        required_elements: vector<u64>,
    }

    public struct PoolStarted has copy, drop {
        pool_id: ID,
        start_time: u64,
    }

    public struct PoolEnded has copy, drop {
        pool_id: ID,
        end_time: u64,
        total_participants: u64,
        total_nfts: u64,
    }

    public struct NFTStaked has copy, drop {
        pool_id: ID,
        nft_id: ID,
        owner: address,
        stake_time: u64,
    }

    public struct NFTUnstaked has copy, drop {
        pool_id: ID,
        nft_id: ID,
        owner: address,
        stake_duration: u64,
        rewards_forfeited: bool,
    }

    public struct RewardsUpdated has copy, drop {
        pool_id: ID,
        update_time: u64,
        total_participants: u64,
        total_weight: u64,
    }

    public struct RewardsClaimed has copy, drop {
        pool_id: ID,
        user: address,
        sui_amount: u64,
    }

    public struct SuiRewardsAdded has copy, drop {
        pool_id: ID,
        sui_amount: u64,
    }

    public struct PoolImageUpdated has copy, drop {
        pool_id: ID,
        old_image_url: String,
        new_image_url: String,
        updated_by: address,
    }    

    public struct PoolTimeExtended has copy, drop {
        pool_id: ID,
        new_end_time: u64,
    }

    public struct POOL_REWARDS has drop {}

    // ========== Initialization ==========

    #[allow(lint(share_owned))]
    fun init(_: POOL_REWARDS, ctx: &mut TxContext) {
        let admin_cap = PoolAdminCap {
            id: object::new(ctx),
        };

        let pool_system = PoolSystem {
            id: object::new(ctx),
            pools: object_table::new(ctx),
            pool_counter: 0,
            global_config: GlobalConfig {
                reward_update_interval: REWARD_UPDATE_INTERVAL,
            },
        };

        transfer::transfer(admin_cap, tx_context::sender(ctx));
        transfer::share_object(pool_system);
    }

    // ========== Pool Management Functions ==========

    public entry fun create_pool(
        _: &PoolAdminCap,
        pool_system: &mut PoolSystem,
        name: String,
        description: String,
        required_elements: vector<u64>,
        start_time: u64,
        image_url: String,
        end_time: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Validate time range
        let current_time = clock::timestamp_ms(clock);
        assert!(end_time > start_time, EInvalidTimeRange);

        pool_system.pool_counter = pool_system.pool_counter + 1;
        
        let pool_uid = object::new(ctx);
        let pool_id = object::uid_to_inner(&pool_uid);

        let pool = Pool {
            id: pool_uid,
            pool_id,
            name,
            description,
            creator: tx_context::sender(ctx),
            image_url,
            required_elements,
            start_time,
            end_time,
            is_active: false,
            sui_reward_pool: balance::zero(),
            last_reward_update: current_time,
            staked_nfts: object_table::new(ctx),
            user_stakes: table::new(ctx),
            total_staked_count: 0,
            total_weight: 0,
            staked_nft_ids: vector::empty(),
            unique_participants: table::new(ctx),
            participant_count: 0,
        };

        event::emit(PoolCreated {
            pool_id,
            name: pool.name,
            creator: pool.creator,
            start_time,
            end_time,
            required_elements,
        });

        object_table::add(&mut pool_system.pools, pool_id, pool);
    }

    public entry fun start_pool(
        _: &PoolAdminCap,
        pool_system: &mut PoolSystem,
        pool_id: ID,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        let pool = object_table::borrow_mut(&mut pool_system.pools, pool_id);
        assert!(!pool.is_active, EPoolAlreadyActive);
        
        let current_time = clock::timestamp_ms(clock);
        
        pool.is_active = true;
        
        event::emit(PoolStarted {
            pool_id,
            start_time: current_time,
        });
    }

    public entry fun end_pool(
        _: &PoolAdminCap,
        pool_system: &mut PoolSystem,
        pool_id: ID,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        let pool = object_table::borrow_mut(&mut pool_system.pools, pool_id);
        assert!(pool.is_active, EPoolNotActive);
        
        let current_time = clock::timestamp_ms(clock);
        pool.is_active = false;
        pool.end_time = current_time;
        
        event::emit(PoolEnded {
            pool_id,
            end_time: current_time,
            total_participants: pool.participant_count,
            total_nfts: pool.total_staked_count,
        });
    }

    public entry fun extend_pool_time(
        _: &PoolAdminCap,
        pool_system: &mut PoolSystem,
        pool_id: ID,
        new_end_time: u64,
        _ctx: &mut TxContext
    ) {
        let pool = object_table::borrow_mut(&mut pool_system.pools, pool_id);
        assert!(pool.is_active, EPoolNotActive);
        
        pool.end_time = new_end_time;
        
        event::emit(PoolTimeExtended {
            pool_id,
            new_end_time,
        });
    }

    // ========== Reward Management ==========

    public entry fun add_sui_rewards(
        _: &PoolAdminCap,
        pool_system: &mut PoolSystem,
        pool_id: ID,
        payment: &mut Coin<SUI>,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let pool = object_table::borrow_mut(&mut pool_system.pools, pool_id);
        assert!(coin::value(payment) >= amount, EInsufficientBalance);
        
        let reward_coin = coin::split(payment, amount, ctx);
        let reward_balance = coin::into_balance(reward_coin);
        balance::join(&mut pool.sui_reward_pool, reward_balance);
        
        event::emit(SuiRewardsAdded {
            pool_id,
            sui_amount: amount,
        });
    }

    // ========== Staking Functions ==========

    public entry fun stake_nft(
        pool_system: &mut PoolSystem,
        pool_id: ID,
        nft: CreatureNFT,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let pool = object_table::borrow_mut(&mut pool_system.pools, pool_id);
        assert!(pool.is_active, EPoolNotActive);
        
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time < pool.end_time, EPoolEnded);
        
        // Check if NFT meets pool requirements
        validate_nft_requirements(pool, &nft);
        
        let owner = tx_context::sender(ctx);
        let nft_id = object::id(&nft);
        let stake_time = current_time;
        
        // Calculate initial weight (1 for new stake)
        let weight = 1;
        
        // Create staked NFT record
        let staked_nft = StakedNFT {
            id: object::new(ctx),
            nft,
            owner,
            pool_id,
            stake_time,
            weight,
        };
        
        // Update pool statistics
        pool.total_staked_count = pool.total_staked_count + 1;
        pool.total_weight = pool.total_weight + weight;
        
        // Update user stake info
        if (!table::contains(&pool.user_stakes, owner)) {
            // New participant
            table::add(&mut pool.unique_participants, owner, true);
            pool.participant_count = pool.participant_count + 1;
            
            table::add(&mut pool.user_stakes, owner, UserStakeInfo {
                nft_count: 1,
                total_weight: weight,
                stake_start_time: stake_time,
                pending_sui_rewards: 0,
                last_reward_claim: stake_time,
            });
        } else {
            // Existing participant
            let user_info = table::borrow_mut(&mut pool.user_stakes, owner);
            user_info.nft_count = user_info.nft_count + 1;
            user_info.total_weight = user_info.total_weight + weight;
        };
        
        object_table::add(&mut pool.staked_nfts, nft_id, staked_nft);
        
        // Add NFT ID to tracking vector
        vector::push_back(&mut pool.staked_nft_ids, nft_id);
        
        event::emit(NFTStaked {
            pool_id,
            nft_id,
            owner,
            stake_time,
        });
    }

    public entry fun unstake_nft(
        pool_system: &mut PoolSystem,
        pool_id: ID,
        nft_id: ID,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let pool = object_table::borrow_mut(&mut pool_system.pools, pool_id);
        let owner = tx_context::sender(ctx);
        
        assert!(object_table::contains(&pool.staked_nfts, nft_id), ENoStakedNFTs);
        
        let staked_nft = object_table::remove(&mut pool.staked_nfts, nft_id);
        assert!(staked_nft.owner == owner, EInvalidOwner);
        
        let current_time = clock::timestamp_ms(clock);
        let stake_duration = current_time - staked_nft.stake_time;
        
        // Check if unstaking within 6-hour window (forfeit rewards)
        let time_since_last_update = current_time - pool.last_reward_update;
        let rewards_forfeited = time_since_last_update < REWARD_UPDATE_INTERVAL;
        
        // Update pool statistics
        pool.total_staked_count = pool.total_staked_count - 1;
        pool.total_weight = pool.total_weight - staked_nft.weight;
        
        // Update user stake info
        let user_info = table::borrow_mut(&mut pool.user_stakes, owner);
        user_info.nft_count = user_info.nft_count - 1;
        user_info.total_weight = user_info.total_weight - staked_nft.weight;
        
        // If forfeiting rewards, clear pending rewards
        if (rewards_forfeited) {
            user_info.pending_sui_rewards = 0;
        };
        
        // Return the NFT
        let StakedNFT { id, nft, owner: _, pool_id: _, stake_time: _, weight: _ } = staked_nft;
        object::delete(id);
        
        // Remove NFT ID from tracking vector
        let (found, index) = vector::index_of(&pool.staked_nft_ids, &nft_id);
        if (found) {
            vector::remove(&mut pool.staked_nft_ids, index);
        };
        
        transfer::public_transfer(nft, owner);
        
        event::emit(NFTUnstaked {
            pool_id,
            nft_id,
            owner,
            stake_duration,
            rewards_forfeited,
        });
    }

    // ========== Reward Calculation and Distribution ==========

    public entry fun update_pool_rewards(
        pool_system: &mut PoolSystem,
        pool_id: ID,
        clock: &Clock,
        _ctx: &mut TxContext
    ) {
        let pool = object_table::borrow_mut(&mut pool_system.pools, pool_id);
        let current_time = clock::timestamp_ms(clock);
        
        // Check if 6 hours have passed since last update
        assert!(current_time - pool.last_reward_update >= REWARD_UPDATE_INTERVAL, ERewardsNotReady);
        
        // Update weights for all staked NFTs based on time
        update_all_nft_weights(pool, current_time);
        
        pool.last_reward_update = current_time;
        
        event::emit(RewardsUpdated {
            pool_id,
            update_time: current_time,
            total_participants: pool.participant_count,
            total_weight: pool.total_weight,
        });
    }

    public entry fun claim_rewards(
        pool_system: &mut PoolSystem,
        pool_id: ID,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let pool = object_table::borrow_mut(&mut pool_system.pools, pool_id);
        let owner = tx_context::sender(ctx);
        
        assert!(table::contains(&pool.user_stakes, owner), ENoStakedNFTs);
        
        let current_time = clock::timestamp_ms(clock);
        
        // Calculate reward amounts based on user weight ratio
        let user_info = table::borrow_mut(&mut pool.user_stakes, owner);
        
        // Get values we need before calling calculate function
        let user_weight = user_info.total_weight;
        let pool_total_weight = pool.total_weight;
        let pool_sui_balance = balance::value(&pool.sui_reward_pool);
        
        // Calculate rewards using local values (not borrowing pool)
        let sui_reward = if (pool_total_weight == 0 || user_weight == 0) {
            0
        } else {
            (pool_sui_balance * user_weight) / pool_total_weight
        };
        
        // Add to pending rewards
        user_info.pending_sui_rewards = user_info.pending_sui_rewards + sui_reward;
        
        // Transfer SUI rewards if available
        if (user_info.pending_sui_rewards > 0 && 
            pool_sui_balance >= user_info.pending_sui_rewards) {
            
            let claimed_sui = user_info.pending_sui_rewards;
            user_info.pending_sui_rewards = 0;
            user_info.last_reward_claim = current_time;
            
            // Now we can borrow pool mutably for the balance split
            let reward_balance = balance::split(&mut pool.sui_reward_pool, claimed_sui);
            let reward_coin = coin::from_balance(reward_balance, ctx);
            transfer::public_transfer(reward_coin, owner);
            
            event::emit(RewardsClaimed {
                pool_id,
                user: owner,
                sui_amount: claimed_sui,
            });
        };
    }

        // ========== Admin Treasury Management ==========

    public entry fun withdraw_pool_funds(
        _: &PoolAdminCap,
        pool_system: &mut PoolSystem,
        pool_id: ID,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        assert!(object_table::contains(&pool_system.pools, pool_id), EPoolNotFound);
        
        let pool = object_table::borrow_mut(&mut pool_system.pools, pool_id);
        
        // Check if pool has sufficient balance
        assert!(balance::value(&pool.sui_reward_pool) >= amount, EInsufficientBalance);
        
        let withdrawn_balance = balance::split(&mut pool.sui_reward_pool, amount);
        let withdrawn_coin = coin::from_balance(withdrawn_balance, ctx);
        transfer::public_transfer(withdrawn_coin, recipient);
    }

    public entry fun emergency_withdraw_all(
        _: &PoolAdminCap,
        pool_system: &mut PoolSystem,
        pool_id: ID,
        recipient: address,
        ctx: &mut TxContext
    ) {
        assert!(object_table::contains(&pool_system.pools, pool_id), EPoolNotFound);
        
        let pool = object_table::borrow_mut(&mut pool_system.pools, pool_id);
        
        let total_balance = balance::value(&pool.sui_reward_pool);
        assert!(total_balance > 0, EInsufficientBalance);
        
        let all_balance = balance::withdraw_all(&mut pool.sui_reward_pool);
        let all_coins = coin::from_balance(all_balance, ctx);
        transfer::public_transfer(all_coins, recipient);
    }

    // ========== Helper Functions ==========

    fun validate_nft_requirements(pool: &Pool, nft: &CreatureNFT) {
        // Check if NFT has any of the required elements
        if (vector::length(&pool.required_elements) > 0) {
            let nft_has_required_element = check_nft_has_required_elements(nft, &pool.required_elements);
            assert!(nft_has_required_element, EElementNotFound);
        };
    }

    fun check_nft_has_required_elements(nft: &CreatureNFT, required_elements: &vector<u64>): bool {
        // Extract all element IDs from the NFT metadata
        let nft_element_ids = extract_nft_element_ids(nft);
        
        // Check if NFT has any of the required elements
        let mut i = 0;
        let req_len = vector::length(required_elements);
        
        while (i < req_len) {
            let required_id = *vector::borrow(required_elements, i);
            if (vector::contains(&nft_element_ids, &required_id)) {
                return true
            };
            i = i + 1;
        };
        
        false
    }

    fun extract_nft_element_ids(nft: &CreatureNFT): vector<u64> {
        // Use the getter function from creature_nft module to extract all item IDs
        creature_nft::get_all_item_ids(nft)
    }
    
    // Helper function to extract item IDs from a category
    // This function is no longer needed since we use creature_nft::get_all_item_ids()
    // Removed to avoid field access issues

    fun update_all_nft_weights(pool: &mut Pool, current_time: u64) {
        // Now we can iterate through NFT IDs using our tracking vector
        let mut new_total_weight = 0;
        let len = vector::length(&pool.staked_nft_ids);
        let mut i = 0;
        
        while (i < len) {
            let nft_id = *vector::borrow(&pool.staked_nft_ids, i);
            
            // Only process if NFT still exists in the table
            if (object_table::contains(&pool.staked_nfts, nft_id)) {
                let staked_nft = object_table::borrow_mut(&mut pool.staked_nfts, nft_id);
                
                let stake_duration_ms = current_time - staked_nft.stake_time;
                let stake_hours = stake_duration_ms / MS_PER_HOUR;
                let new_weight = if (stake_hours == 0) { 1 } else { stake_hours };
                
                staked_nft.weight = new_weight;
                new_total_weight = new_total_weight + new_weight;
            };
            
            i = i + 1;
        };
        
        pool.total_weight = new_total_weight;
    }

    public fun calculate_user_sui_rewards(
        pool: &Pool,
        user_weight: u64
    ): u64 {
        if (pool.total_weight == 0 || user_weight == 0) {
            return 0
        };
        
        // Calculate user's share as: user_weight / total_weight
        let user_share_sui = (balance::value(&pool.sui_reward_pool) * user_weight) / pool.total_weight;
        
        user_share_sui
    }


    public fun get_pool_info(
        pool_system: &PoolSystem,
        pool_id: ID
    ): (String, String, bool, u64, u64, u64, u64, vector<u64>) {
        let pool = object_table::borrow(&pool_system.pools, pool_id);
        (
            pool.name,
            pool.description,
            pool.is_active,
            pool.start_time,
            pool.end_time,
            pool.participant_count,
            pool.total_staked_count,
            pool.required_elements
        )
    }

    public fun get_pool_rewards_info(
        pool_system: &PoolSystem,
        pool_id: ID
    ): (u64, u64) {
        let pool = object_table::borrow(&pool_system.pools, pool_id);
        (
            balance::value(&pool.sui_reward_pool),
            pool.last_reward_update
        )
    }

    public fun get_user_stake_info(
        pool_system: &PoolSystem,
        pool_id: ID,
        user: address
    ): (u64, u64, u64, u64) {
        let pool = object_table::borrow(&pool_system.pools, pool_id);
        
        if (!table::contains(&pool.user_stakes, user)) {
            return (0, 0, 0, 0)
        };
        
        let user_info = table::borrow(&pool.user_stakes, user);
        (
            user_info.nft_count,
            user_info.total_weight,
            user_info.pending_sui_rewards,
            user_info.last_reward_claim
        )
    }

    public fun get_pool_overview(
        pool_system: &PoolSystem,
        pool_id: ID,
        clock: &Clock
    ): (u64, u64, u64, u64, u64, bool) {
        assert!(object_table::contains(&pool_system.pools, pool_id), EPoolNotFound);
        
        let pool = object_table::borrow(&pool_system.pools, pool_id);
        let current_time = clock::timestamp_ms(clock);
        
        let total_prize = balance::value(&pool.sui_reward_pool);
        let time_remaining_ms = if (current_time < pool.end_time) {
            pool.end_time - current_time
        } else {
            0
        };
        let days_remaining = time_remaining_ms / (MS_PER_HOUR * 24);
        let hours_remaining = (time_remaining_ms % (MS_PER_HOUR * 24)) / MS_PER_HOUR;
        
        (
            total_prize, 
            days_remaining,
            hours_remaining, 
            pool.participant_count,
            pool.total_staked_count,
            pool.is_active
        )
    }

    public fun get_user_reward_details(
        pool_system: &PoolSystem,
        pool_id: ID,
        user: address,
        clock: &Clock
    ): (u64, u64, u64, u64, bool, u64, u64) {
        assert!(object_table::contains(&pool_system.pools, pool_id), EPoolNotFound);
        
        let pool = object_table::borrow(&pool_system.pools, pool_id);
        let current_time = clock::timestamp_ms(clock);
        
        if (!table::contains(&pool.user_stakes, user)) {
            return (0, 0, 0, 0, false, 0, 0)
        };
        
        let user_info = table::borrow(&pool.user_stakes, user);
        
        // Calculate current weight based on stake time
        let stake_duration_ms = current_time - user_info.stake_start_time;
        let stake_hours = stake_duration_ms / MS_PER_HOUR;
        let current_weight = if (stake_hours == 0) { 
            user_info.nft_count 
        } else { 
            user_info.nft_count * stake_hours 
        };
        
        // Calculate potential rewards based on current weight
        let potential_rewards = if (pool.total_weight > 0) {
            (balance::value(&pool.sui_reward_pool) * current_weight) / pool.total_weight
        } else {
            0
        };
        
        // Check if can claim
        let time_since_last_claim = current_time - user_info.last_reward_claim;
        let can_claim = time_since_last_claim >= REWARD_UPDATE_INTERVAL;
        
        (
            user_info.nft_count,                    // NFTs staked
            current_weight,                         // Current weight
            user_info.pending_sui_rewards,          // Pending rewards
            potential_rewards,                      // Potential new rewards
            can_claim,                             // Can claim now?
            stake_duration_ms,                     // Total stake time (ms)
            time_since_last_claim                  // Time since last claim (ms)
        )
    }

    public fun can_claim_rewards(
        pool_system: &PoolSystem,
        pool_id: ID,
        user: address,
        clock: &Clock
    ): bool {
        let pool = object_table::borrow(&pool_system.pools, pool_id);
        let current_time = clock::timestamp_ms(clock);
        
        if (!table::contains(&pool.user_stakes, user)) {
            return false
        };
        
        let user_info = table::borrow(&pool.user_stakes, user);
        let time_since_last_claim = current_time - user_info.last_reward_claim;
        
        // Can claim if it's been at least 6 hours since last reward update
        time_since_last_claim >= REWARD_UPDATE_INTERVAL
    }

    public fun time_until_next_reward_update(
        pool_system: &PoolSystem,
        pool_id: ID,
        clock: &Clock
    ): u64 {
        let pool = object_table::borrow(&pool_system.pools, pool_id);
        let current_time = clock::timestamp_ms(clock);
        let time_since_update = current_time - pool.last_reward_update;
        
        if (time_since_update >= REWARD_UPDATE_INTERVAL) {
            0
        } else {
            REWARD_UPDATE_INTERVAL - time_since_update
        }
    }

    public entry fun update_pool_image_url(
        _: &PoolAdminCap,
        pool_system: &mut PoolSystem,
        pool_id: ID,
        new_image_url: String,
        ctx: &mut TxContext
    ) {
        assert!(object_table::contains(&pool_system.pools, pool_id), EPoolNotFound);
        
        let pool = object_table::borrow_mut(&mut pool_system.pools, pool_id);
        let old_image_url = pool.image_url;
        
        // Update the image URL
        pool.image_url = new_image_url;
        
        // Emit event for the update
        event::emit(PoolImageUpdated {
            pool_id,
            old_image_url,
            new_image_url: pool.image_url,
            updated_by: tx_context::sender(ctx),
        });
    }

    // ========== Test Functions ==========

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        let witness = POOL_REWARDS {};
        init(witness, ctx);
    }

    #[test_only]
    public fun get_pool_count(pool_system: &PoolSystem): u64 {
        pool_system.pool_counter
    }
}
