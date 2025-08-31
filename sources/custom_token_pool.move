// // Copyright (c) Mysten Labs, Inc.
// // SPDX-License-Identifier: Apache-2.0

// module merg3::custom_token_pool {
//     use std::string::{String};
//     use std::ascii;
//     use std::type_name;
//     use sui::event;
//     use sui::coin::{Self, Coin};
//     use sui::balance::{Self, Balance};
//     use sui::table::{Self, Table};
//     use sui::clock::{Self, Clock};
//     use sui::object_table::{Self, ObjectTable};
//     use merg3::creature_nft::{Self, CreatureNFT};

//     // ========== Constants ==========
    
//     /// Error codes
//     const EPoolNotFound: u64 = 1;
//     const EPoolNotActive: u64 = 2;
//     const EPoolAlreadyActive: u64 = 3;
//     const EInvalidOwner: u64 = 4;
//     const EInsufficientBalance: u64 = 5;
//     const EPoolEnded: u64 = 6;
//     const EInvalidTimeRange: u64 = 7;
//     const ENoStakedNFTs: u64 = 8;
//     const ERewardsNotReady: u64 = 9;
//     const EElementNotFound: u64 = 11;
//     const EClaimTooSoon: u64 = 12;
//     const ETokenBalanceNotFound: u64 = 13;

//     /// Time constants
//     const MS_PER_HOUR: u64 = 3_600_000;
//     const MS_PER_DAY: u64 = 86_400_000;
//     const REWARD_UPDATE_INTERVAL: u64 = 21_600_000; // 6 hours

//     /// Admin capability for custom token pool management
//     public struct CustomTokenPoolAdminCap has key {
//         id: UID,
//     }

//     /// Main custom token pool system state
//     public struct CustomTokenPoolSystem has key {
//         id: UID,
//         pools: ObjectTable<ID, CustomTokenPool>,
//         pool_counter: u64,
//         global_config: GlobalConfig,
//     }

//     public struct GlobalConfig has store {
//         reward_update_interval: u64,
//     }

//     /// Custom token pool configuration and state
//     public struct CustomTokenPool has key, store {
//         id: UID,
//         pool_id: ID,
//         name: String,
//         description: String,
//         creator: address,
//         image_url: String,
//         token_type: String, // Store token type name for display
        
//         // Pool requirements - array of required element IDs
//         required_elements: vector<u64>,
        
//         // Time management
//         start_time: u64,
//         end_time: u64,
//         is_active: bool,
        
//         // Reward tracking
//         last_reward_update: u64,
//         total_rewards: u64, // Track total rewards added
        
//         // Staking data
//         staked_nfts: ObjectTable<ID, StakedNFT>,
//         user_stakes: Table<address, UserStakeInfo>,
//         total_staked_count: u64,
//         total_weight: u64,
        
//         // Track NFT IDs separately for iteration
//         staked_nft_ids: vector<ID>,
        
//         // Participant tracking
//         unique_participants: Table<address, bool>,
//         participant_count: u64,
//     }

//     /// Typed reward balance for specific token type - stores rewards for a specific pool
//     public struct TokenRewardBalance<phantom T> has key, store {
//         id: UID,
//         pool_id: ID,
//         balance: Balance<T>,
//     }

//     public struct UserStakeInfo has store, drop {
//         nft_count: u64,
//         total_weight: u64,
//         stake_start_time: u64,
//         pending_rewards: u64,
//         last_reward_claim: u64,
//     }

//     /// Information about a staked NFT
//     public struct StakedNFT has key, store {
//         id: UID,
//         nft: CreatureNFT,
//         owner: address,
//         pool_id: ID,
//         stake_time: u64,
//         weight: u64, // calculated based on stake time
//     }

//     // ========== Events ==========

//     public struct CustomTokenPoolCreated has copy, drop {
//         pool_id: ID,
//         name: String,
//         creator: address,
//         token_type: String,
//         start_time: u64,
//         end_time: u64,
//         required_elements: vector<u64>,
//     }

//     public struct CustomTokenPoolStarted has copy, drop {
//         pool_id: ID,
//         start_time: u64,
//     }

//     public struct CustomTokenPoolEnded has copy, drop {
//         pool_id: ID,
//         end_time: u64,
//         total_participants: u64,
//         total_nfts: u64,
//     }

//     public struct NFTStakedInCustomPool has copy, drop {
//         pool_id: ID,
//         nft_id: ID,
//         owner: address,
//         stake_time: u64,
//     }

//     public struct NFTUnstakedFromCustomPool has copy, drop {
//         pool_id: ID,
//         nft_id: ID,
//         owner: address,
//         stake_duration: u64,
//         rewards_forfeited: bool,
//     }

//     public struct CustomTokenRewardsUpdated has copy, drop {
//         pool_id: ID,
//         update_time: u64,
//         total_participants: u64,
//         total_weight: u64,
//     }

//     public struct CustomTokenRewardsClaimed has copy, drop {
//         pool_id: ID,
//         user: address,
//         token_type: String,
//         amount: u64,
//     }

//     public struct CustomTokenRewardsAdded has copy, drop {
//         pool_id: ID,
//         token_type: String,
//         amount: u64,
//     }

//     public struct CustomPoolImageUpdated has copy, drop {
//         pool_id: ID,
//         old_image_url: String,
//         new_image_url: String,
//         updated_by: address,
//     }

//     public struct CustomPoolTimeExtended has copy, drop {
//         pool_id: ID,
//         new_end_time: u64,
//     }


//     public struct CUSTOM_TOKEN_POOL has drop {}

//     // ========== Initialization ==========

//     #[allow(lint(share_owned))]
//     fun init(_: CUSTOM_TOKEN_POOL, ctx: &mut TxContext) {
//         let admin_cap = CustomTokenPoolAdminCap {
//             id: object::new(ctx),
//         };

//         let pool_system = CustomTokenPoolSystem {
//             id: object::new(ctx),
//             pools: object_table::new(ctx),
//             pool_counter: 0,
//             global_config: GlobalConfig {
//                 reward_update_interval: REWARD_UPDATE_INTERVAL,
//             },
//         };

//         transfer::transfer(admin_cap, tx_context::sender(ctx));
//         transfer::share_object(pool_system);
//     }

//     // ========== Pool Management Functions ==========

//     public fun create_custom_token_pool<T>(
//         _: &CustomTokenPoolAdminCap,
//         pool_system: &mut CustomTokenPoolSystem,
//         name: String,
//         description: String,
//         required_elements: vector<u64>,
//         start_time: u64,
//         image_url: String,
//         end_time: u64,
//         clock: &Clock,
//         ctx: &mut TxContext
//     ) {
//         // Validate time range
//         let current_time = clock::timestamp_ms(clock);
//         assert!(end_time > start_time, EInvalidTimeRange);

//         pool_system.pool_counter = pool_system.pool_counter + 1;
        
//         let pool_uid = object::new(ctx);
//         let pool_id = object::uid_to_inner(&pool_uid);
//         let token_type_name = std::string::utf8(ascii::into_bytes(type_name::with_defining_ids<T>().into_string()));

//         let pool = CustomTokenPool {
//             id: pool_uid,
//             pool_id,
//             name,
//             description,
//             creator: tx_context::sender(ctx),
//             image_url,
//             token_type: token_type_name,
//             required_elements,
//             start_time,
//             end_time,
//             is_active: false,
//             last_reward_update: current_time,
//             total_rewards: 0,
//             staked_nfts: object_table::new(ctx),
//             user_stakes: table::new(ctx),
//             total_staked_count: 0,
//             total_weight: 0,
//             staked_nft_ids: vector::empty(),
//             unique_participants: table::new(ctx),
//             participant_count: 0,
//         };

//         event::emit(CustomTokenPoolCreated {
//             pool_id,
//             name: pool.name,
//             creator: pool.creator,
//             token_type: pool.token_type,
//             start_time,
//             end_time,
//             required_elements,
//         });

//         // Add pool to system
//         object_table::add(&mut pool_system.pools, pool_id, pool);
//     }

//     public fun start_custom_pool(
//         _: &CustomTokenPoolAdminCap,
//         pool_system: &mut CustomTokenPoolSystem,
//         pool_id: ID,
//         clock: &Clock,
//         _ctx: &mut TxContext
//     ) {
//         let pool = object_table::borrow_mut(&mut pool_system.pools, pool_id);
//         assert!(!pool.is_active, EPoolAlreadyActive);
        
//         let current_time = clock::timestamp_ms(clock);
        
//         pool.is_active = true;
        
//         event::emit(CustomTokenPoolStarted {
//             pool_id,
//             start_time: current_time,
//         });
//     }

//     public fun end_custom_pool(
//         _: &CustomTokenPoolAdminCap,
//         pool_system: &mut CustomTokenPoolSystem,
//         pool_id: ID,
//         clock: &Clock,
//         _ctx: &mut TxContext
//     ) {
//         let pool = object_table::borrow_mut(&mut pool_system.pools, pool_id);
//         assert!(pool.is_active, EPoolNotActive);
        
//         let current_time = clock::timestamp_ms(clock);
//         pool.is_active = false;
//         pool.end_time = current_time;
        
//         event::emit(CustomTokenPoolEnded {
//             pool_id,
//             end_time: current_time,
//             total_participants: pool.participant_count,
//             total_nfts: pool.total_staked_count,
//         });
//     }

//     public fun extend_custom_pool_time(
//         _: &CustomTokenPoolAdminCap,
//         pool_system: &mut CustomTokenPoolSystem,
//         pool_id: ID,
//         new_end_time: u64,
//         _ctx: &mut TxContext
//     ) {
//         let pool = object_table::borrow_mut(&mut pool_system.pools, pool_id);
//         assert!(pool.is_active, EPoolNotActive);
        
//         pool.end_time = new_end_time;
        
//         event::emit(CustomPoolTimeExtended {
//             pool_id,
//             new_end_time,
//         });
//     }

//     // ========== Token Balance Management ==========

//     public fun create_token_reward_balance<T>(
//         _: &CustomTokenPoolAdminCap,
//         pool_system: &CustomTokenPoolSystem,
//         pool_id: ID,
//         ctx: &mut TxContext
//     ): TokenRewardBalance<T> {
//         // Verify pool exists
//         assert!(object_table::contains(&pool_system.pools, pool_id), EPoolNotFound);
        
//         TokenRewardBalance<T> {
//             id: object::new(ctx),
//             pool_id,
//             balance: balance::zero(),
//         }
//     }

//     // ========== Reward Management ==========

//     public fun add_custom_token_rewards<T>(
//         _: &CustomTokenPoolAdminCap,
//         pool_system: &mut CustomTokenPoolSystem,
//         token_balance: &mut TokenRewardBalance<T>,
//         pool_id: ID,
//         payment: &mut Coin<T>,
//         amount: u64,
//         ctx: &mut TxContext
//     ) {
//         let pool = object_table::borrow_mut(&mut pool_system.pools, pool_id);
//         assert!(coin::value(payment) >= amount, EInsufficientBalance);
//         assert!(token_balance.pool_id == pool_id, ETokenBalanceNotFound);
        
//         let reward_coin = coin::split(payment, amount, ctx);
//         let reward_balance = coin::into_balance(reward_coin);
//         balance::join(&mut token_balance.balance, reward_balance);
        
//         pool.total_rewards = pool.total_rewards + amount;
//         let token_type_name = std::string::utf8(ascii::into_bytes(type_name::with_defining_ids<T>().into_string()));
        
//         event::emit(CustomTokenRewardsAdded {
//             pool_id,
//             token_type: token_type_name,
//             amount,
//         });
//     }

//     public fun add_custom_token_rewards_from_balance<T>(
//         _: &CustomTokenPoolAdminCap,
//         pool_system: &mut CustomTokenPoolSystem,
//         token_balance: &mut TokenRewardBalance<T>,
//         pool_id: ID,
//         reward_coin: Coin<T>,
//     ) {
//         let pool = object_table::borrow_mut(&mut pool_system.pools, pool_id);
//         assert!(token_balance.pool_id == pool_id, ETokenBalanceNotFound);
        
//         let amount = coin::value(&reward_coin);
//         let reward_balance = coin::into_balance(reward_coin);
//         balance::join(&mut token_balance.balance, reward_balance);
        
//         pool.total_rewards = pool.total_rewards + amount;
        
//         let token_type_name = std::string::utf8(ascii::into_bytes(type_name::with_defining_ids<T>().into_string()));
//         event::emit(CustomTokenRewardsAdded {
//             pool_id,
//             token_type: token_type_name,
//             amount,
//         });
//     }

//     // ========== Staking Functions ==========

//     public fun stake_nft_in_custom_pool(
//         pool_system: &mut CustomTokenPoolSystem,
//         pool_id: ID,
//         nft: CreatureNFT,
//         clock: &Clock,
//         ctx: &mut TxContext
//     ) {
//         let pool = object_table::borrow_mut(&mut pool_system.pools, pool_id);
//         assert!(pool.is_active, EPoolNotActive);
        
//         let current_time = clock::timestamp_ms(clock);
//         assert!(current_time < pool.end_time, EPoolEnded);
        
//         // Check if NFT meets pool requirements
//         validate_nft_requirements(pool, &nft);
        
//         let owner = tx_context::sender(ctx);
//         let nft_id = object::id(&nft);
//         let stake_time = current_time;
        
//         // Calculate initial weight (1 for new stake)
//         let weight = 1;
        
//         // Create staked NFT record
//         let staked_nft = StakedNFT {
//             id: object::new(ctx),
//             nft,
//             owner,
//             pool_id,
//             stake_time,
//             weight,
//         };
        
//         // Update pool statistics
//         pool.total_staked_count = pool.total_staked_count + 1;
//         pool.total_weight = pool.total_weight + weight;
        
//         // Update user stake info
//         if (!table::contains(&pool.user_stakes, owner)) {
//             // New participant
//             table::add(&mut pool.unique_participants, owner, true);
//             pool.participant_count = pool.participant_count + 1;
            
//             table::add(&mut pool.user_stakes, owner, UserStakeInfo {
//                 nft_count: 1,
//                 total_weight: weight,
//                 stake_start_time: stake_time,
//                 pending_rewards: 0,
//                 last_reward_claim: stake_time,
//             });
//         } else {
//             // Existing participant
//             let user_info = table::borrow_mut(&mut pool.user_stakes, owner);
//             user_info.nft_count = user_info.nft_count + 1;
//             user_info.total_weight = user_info.total_weight + weight;
//         };
        
//         object_table::add(&mut pool.staked_nfts, nft_id, staked_nft);
        
//         // Add NFT ID to tracking vector
//         vector::push_back(&mut pool.staked_nft_ids, nft_id);
        
//         event::emit(NFTStakedInCustomPool {
//             pool_id,
//             nft_id,
//             owner,
//             stake_time,
//         });
//     }

//     public fun unstake_nft_from_custom_pool(
//         pool_system: &mut CustomTokenPoolSystem,
//         pool_id: ID,
//         nft_id: ID,
//         clock: &Clock,
//         ctx: &mut TxContext
//     ) {
//         let pool = object_table::borrow_mut(&mut pool_system.pools, pool_id);
//         let owner = tx_context::sender(ctx);
        
//         assert!(object_table::contains(&pool.staked_nfts, nft_id), ENoStakedNFTs);
        
//         let staked_nft = object_table::remove(&mut pool.staked_nfts, nft_id);
//         assert!(staked_nft.owner == owner, EInvalidOwner);
        
//         let current_time = clock::timestamp_ms(clock);
//         let stake_duration = current_time - staked_nft.stake_time;
        
//         // Check if unstaking within 6-hour window (forfeit rewards)
//         let time_since_last_update = current_time - pool.last_reward_update;
//         let rewards_forfeited = time_since_last_update < REWARD_UPDATE_INTERVAL;
        
//         // Update pool statistics
//         pool.total_staked_count = pool.total_staked_count - 1;
//         pool.total_weight = pool.total_weight - staked_nft.weight;
        
//         // Update user stake info
//         let user_info = table::borrow_mut(&mut pool.user_stakes, owner);
//         user_info.nft_count = user_info.nft_count - 1;
//         user_info.total_weight = user_info.total_weight - staked_nft.weight;
        
//         // If forfeiting rewards, clear pending rewards
//         if (rewards_forfeited) {
//             user_info.pending_rewards = 0;
//         };
        
//         // Return the NFT
//         let StakedNFT { id, nft, owner: _, pool_id: _, stake_time: _, weight: _ } = staked_nft;
//         object::delete(id);
        
//         // Remove NFT ID from tracking vector
//         let (found, index) = vector::index_of(&pool.staked_nft_ids, &nft_id);
//         if (found) {
//             vector::remove(&mut pool.staked_nft_ids, index);
//         };
        
//         transfer::public_transfer(nft, owner);
        
//         event::emit(NFTUnstakedFromCustomPool {
//             pool_id,
//             nft_id,
//             owner,
//             stake_duration,
//             rewards_forfeited,
//         });
//     }

//     // ========== Reward Calculation and Distribution ==========

//     public fun update_custom_pool_rewards(
//         pool_system: &mut CustomTokenPoolSystem,
//         pool_id: ID,
//         clock: &Clock,
//         _ctx: &mut TxContext
//     ) {
//         let pool = object_table::borrow_mut(&mut pool_system.pools, pool_id);
//         let current_time = clock::timestamp_ms(clock);
        
//         // Check if 6 hours have passed since last update
//         assert!(current_time - pool.last_reward_update >= REWARD_UPDATE_INTERVAL, ERewardsNotReady);
        
//         // Update weights for all staked NFTs based on time
//         update_all_nft_weights(pool, current_time);
        
//         pool.last_reward_update = current_time;
        
//         event::emit(CustomTokenRewardsUpdated {
//             pool_id,
//             update_time: current_time,
//             total_participants: pool.participant_count,
//             total_weight: pool.total_weight,
//         });
//     }

//     public fun claim_custom_token_rewards<T>(
//         pool_system: &mut CustomTokenPoolSystem,
//         token_balance: &mut TokenRewardBalance<T>,
//         pool_id: ID,
//         clock: &Clock,
//         ctx: &mut TxContext
//     ) {
//         let pool = object_table::borrow_mut(&mut pool_system.pools, pool_id);
//         let owner = tx_context::sender(ctx);
        
//         assert!(table::contains(&pool.user_stakes, owner), ENoStakedNFTs);
//         assert!(token_balance.pool_id == pool_id, ETokenBalanceNotFound);
        
//         let current_time = clock::timestamp_ms(clock);
//         let user_info = table::borrow(&pool.user_stakes, owner);
        
//         // Check if user has any NFTs currently staked
//         if (user_info.nft_count == 0) {
//             return
//         };
        
//         // Check if enough time has passed since last claim
//         let time_since_last_claim = current_time - user_info.last_reward_claim;
//         let reclaim_period_ms = 1 * MS_PER_DAY;
//         assert!(time_since_last_claim >= reclaim_period_ms || user_info.last_reward_claim == 0, EClaimTooSoon);
        
//         // Calculate current weights dynamically
//         let user_weight = calculate_user_current_weight(pool, owner, current_time);
//         let total_weight = calculate_total_current_weight(pool, current_time);
        
//         // Calculate reward based on current weight ratio
//         let token_reward = if (total_weight == 0 || user_weight == 0) {
//             0
//         } else {
//             let pool_token_balance = balance::value(&token_balance.balance);
//             (pool_token_balance * user_weight) / total_weight
//         };
        
//         // Transfer rewards if available
//         if (token_reward > 0 && balance::value(&token_balance.balance) >= token_reward) {
//             let user_info = table::borrow_mut(&mut pool.user_stakes, owner);
//             user_info.last_reward_claim = current_time;
            
//             let reward_balance = balance::split(&mut token_balance.balance, token_reward);
//             let reward_coin = coin::from_balance(reward_balance, ctx);
//             transfer::public_transfer(reward_coin, owner);
            
//             let token_type_name = std::string::utf8(ascii::into_bytes(type_name::with_defining_ids<T>().into_string()));
            
//             event::emit(CustomTokenRewardsClaimed {
//                 pool_id,
//                 user: owner,
//                 token_type: token_type_name,
//                 amount: token_reward,
//             });
//         };
//     }

//     // ========== Query Functions ==========

//     public fun get_custom_pool_info(
//         pool_system: &CustomTokenPoolSystem,
//         pool_id: ID
//     ): (String, String, String, bool, u64, u64, u64, u64, vector<u64>) {
//         let pool = object_table::borrow(&pool_system.pools, pool_id);
//         (
//             pool.name,
//             pool.description,
//             pool.token_type,
//             pool.is_active,
//             pool.start_time,
//             pool.end_time,
//             pool.participant_count,
//             pool.total_staked_count,
//             pool.required_elements
//         )
//     }

//     public fun get_custom_pool_rewards_info<T>(
//         pool_system: &CustomTokenPoolSystem,
//         token_balance: &TokenRewardBalance<T>,
//         pool_id: ID
//     ): (u64, u64, u64) {
//         let pool = object_table::borrow(&pool_system.pools, pool_id);
//         assert!(token_balance.pool_id == pool_id, ETokenBalanceNotFound);
        
//         (
//             balance::value(&token_balance.balance),
//             pool.total_rewards,
//             pool.last_reward_update
//         )
//     }

//     public fun get_user_stake_info_custom(
//         pool_system: &CustomTokenPoolSystem,
//         pool_id: ID,
//         user: address
//     ): (u64, u64, u64, u64) {
//         let pool = object_table::borrow(&pool_system.pools, pool_id);
        
//         if (!table::contains(&pool.user_stakes, user)) {
//             return (0, 0, 0, 0)
//         };
        
//         let user_info = table::borrow(&pool.user_stakes, user);
//         (
//             user_info.nft_count,
//             user_info.total_weight,
//             user_info.pending_rewards,
//             user_info.last_reward_claim
//         )
//     }

//     public fun get_user_reward_details_custom<T>(
//         pool_system: &CustomTokenPoolSystem,
//         token_balance: &TokenRewardBalance<T>,
//         pool_id: ID,
//         user: address,
//         clock: &Clock
//     ): (u64, u64, u64, u64, u64, u64) {
//         assert!(object_table::contains(&pool_system.pools, pool_id), EPoolNotFound);
//         assert!(token_balance.pool_id == pool_id, ETokenBalanceNotFound);
        
//         let pool = object_table::borrow(&pool_system.pools, pool_id);
//         let current_time = clock::timestamp_ms(clock);
        
//         if (!table::contains(&pool.user_stakes, user)) {
//             return (0, 0, 0, 0, 0, 0)
//         };
        
//         let user_info = table::borrow(&pool.user_stakes, user);
        
//         // Calculate current weights dynamically
//         let user_weight = calculate_user_current_weight(pool, user, current_time);
//         let total_pool_weight = calculate_total_current_weight(pool, current_time);
        
//         // Calculate potential rewards based on current weight
//         let potential_rewards = if (total_pool_weight > 0 && user_weight > 0) {
//             let pool_balance = balance::value(&token_balance.balance);
//             (pool_balance * user_weight) / total_pool_weight
//         } else {
//             0
//         };
        
//         // Calculate total stake time
//         let stake_duration_ms = current_time - user_info.stake_start_time;
        
//         (
//             user_info.nft_count,        // NFTs staked
//             user_weight,                // Current total weight
//             total_pool_weight,           // Total Pool weight
//             potential_rewards,          // Current claimable rewards
//             stake_duration_ms,          // Total stake time (ms)
//             current_time               // Current timestamp
//         )
//     }

//     // ========== Admin Functions ==========

//     public fun withdraw_custom_pool_funds<T>(
//         _: &CustomTokenPoolAdminCap,
//         pool_system: &mut CustomTokenPoolSystem,
//         token_balance: &mut TokenRewardBalance<T>,
//         pool_id: ID,
//         amount: u64,
//         recipient: address,
//         ctx: &mut TxContext
//     ) {
//         assert!(object_table::contains(&pool_system.pools, pool_id), EPoolNotFound);
//         assert!(token_balance.pool_id == pool_id, ETokenBalanceNotFound);
        

//         assert!(balance::value(&token_balance.balance) >= amount, EInsufficientBalance);
        
//         let withdrawn_balance = balance::split(&mut token_balance.balance, amount);
//         let withdrawn_coin = coin::from_balance(withdrawn_balance, ctx);
//         transfer::public_transfer(withdrawn_coin, recipient);
//     }

//     public fun emergency_withdraw_all_custom<T>(
//         _: &CustomTokenPoolAdminCap,
//         pool_system: &mut CustomTokenPoolSystem,
//         token_balance: &mut TokenRewardBalance<T>,
//         pool_id: ID,
//         recipient: address,
//         ctx: &mut TxContext
//     ) {
//         assert!(object_table::contains(&pool_system.pools, pool_id), EPoolNotFound);
//         assert!(token_balance.pool_id == pool_id, ETokenBalanceNotFound);
        
        
//         let total_balance = balance::value(&token_balance.balance);
//         assert!(total_balance > 0, EInsufficientBalance);
        
//         let all_balance = balance::withdraw_all(&mut token_balance.balance);
//         let all_coins = coin::from_balance(all_balance, ctx);
//         transfer::public_transfer(all_coins, recipient);
//     }

//     public fun update_custom_pool_image_url(
//         _: &CustomTokenPoolAdminCap,
//         pool_system: &mut CustomTokenPoolSystem,
//         pool_id: ID,
//         new_image_url: String,
//         ctx: &mut TxContext
//     ) {
//         assert!(object_table::contains(&pool_system.pools, pool_id), EPoolNotFound);
        
//         let pool = object_table::borrow_mut(&mut pool_system.pools, pool_id);
//         let old_image_url = pool.image_url;
        
//         // Update the image URL
//         pool.image_url = new_image_url;
        
//         // Emit event for the update
//         event::emit(CustomPoolImageUpdated {
//             pool_id,
//             old_image_url,
//             new_image_url: pool.image_url,
//             updated_by: tx_context::sender(ctx),
//         });
//     }

//     // ========== Helper Functions ==========

//     fun validate_nft_requirements(pool: &CustomTokenPool, nft: &CreatureNFT) {
//         // Check if NFT has ALL required elements
//         if (vector::length(&pool.required_elements) > 0) {
//             let nft_has_all_required_elements = check_nft_has_all_required_elements(nft, &pool.required_elements);
//             assert!(nft_has_all_required_elements, EElementNotFound);
//         };
//     }

//     fun check_nft_has_all_required_elements(nft: &CreatureNFT, required_elements: &vector<u64>): bool {
//         // Extract all element IDs from the NFT metadata
//         let nft_element_ids = extract_nft_element_ids(nft);
        
//         // Check if NFT has ALL of the required elements
//         let mut i = 0;
//         let req_len = vector::length(required_elements);
        
//         while (i < req_len) {
//             let required_id = *vector::borrow(required_elements, i);
//             // If NFT doesn't have this required element, return false
//             if (!vector::contains(&nft_element_ids, &required_id)) {
//                 return false
//             };
//             i = i + 1;
//         };
        
//         // NFT has all required elements
//         true
//     }

//     fun extract_nft_element_ids(nft: &CreatureNFT): vector<u64> {
//         // Use the getter function from creature_nft module to extract all item IDs
//         creature_nft::get_all_item_ids(nft)
//     }

//     fun calculate_user_current_weight(pool: &CustomTokenPool, user: address, current_time: u64): u64 {
//         if (!table::contains(&pool.user_stakes, user)) {
//             return 0
//         };

//         let mut total_user_weight = 0;
//         let len = vector::length(&pool.staked_nft_ids);
//         let mut i = 0;
    
//         // Iterate through all staked NFTs to find user's NFTs
//         while (i < len) {
//             let nft_id = *vector::borrow(&pool.staked_nft_ids, i);
            
//             if (object_table::contains(&pool.staked_nfts, nft_id)) {
//                 let staked_nft = object_table::borrow(&pool.staked_nfts, nft_id);
                
//                 // Check if this NFT belongs to the user
//                 if (staked_nft.owner == user) {
//                     let stake_duration_ms = current_time - staked_nft.stake_time;
//                     let stake_hours = stake_duration_ms / MS_PER_HOUR;
//                     let nft_weight = if (stake_hours == 0) { 1 } else { stake_hours };
                    
//                     total_user_weight = total_user_weight + nft_weight;
//                 };
//             };
            
//             i = i + 1;
//         };
        
//         total_user_weight
//     }

//     fun calculate_total_current_weight(pool: &CustomTokenPool, current_time: u64): u64 {
//         let mut total_weight = 0;
//         let len = vector::length(&pool.staked_nft_ids);
//         let mut i = 0;
        
//         // Iterate through all staked NFTs
//         while (i < len) {
//             let nft_id = *vector::borrow(&pool.staked_nft_ids, i);
            
//             if (object_table::contains(&pool.staked_nfts, nft_id)) {
//                 let staked_nft = object_table::borrow(&pool.staked_nfts, nft_id);
                
//                 let stake_duration_ms = current_time - staked_nft.stake_time;
//                 let stake_hours = stake_duration_ms / MS_PER_HOUR;
//                 let nft_weight = if (stake_hours == 0) { 1 } else { stake_hours };
                
//                 total_weight = total_weight + nft_weight;
//             };
            
//             i = i + 1;
//         };
        
//         total_weight
//     }
    
//     fun update_all_nft_weights(pool: &mut CustomTokenPool, current_time: u64) {
//         // Now we can iterate through NFT IDs using our tracking vector
//         let mut new_total_weight = 0;
//         let len = vector::length(&pool.staked_nft_ids);
//         let mut i = 0;
        
//         while (i < len) {
//             let nft_id = *vector::borrow(&pool.staked_nft_ids, i);
            
//             // Only process if NFT still exists in the table
//             if (object_table::contains(&pool.staked_nfts, nft_id)) {
//                 let staked_nft = object_table::borrow_mut(&mut pool.staked_nfts, nft_id);
                
//                 let stake_duration_ms = current_time - staked_nft.stake_time;
//                 let stake_hours = stake_duration_ms / MS_PER_HOUR;
//                 let new_weight = if (stake_hours == 0) { 1 } else { stake_hours };
                
//                 staked_nft.weight = new_weight;
//                 new_total_weight = new_total_weight + new_weight;
//             };
            
//             i = i + 1;
//         };
        
//         pool.total_weight = new_total_weight;
//     }

//     // ========== Test Functions ==========

//     #[test_only]
//     public fun init_for_testing(ctx: &mut TxContext) {
//         let witness = CUSTOM_TOKEN_POOL {};
//         init(witness, ctx);
//     }

//     #[test_only]
//     public fun get_pool_count(pool_system: &CustomTokenPoolSystem): u64 {
//         pool_system.pool_counter
//     }
// }
