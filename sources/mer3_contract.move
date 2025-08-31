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
    use sui::transfer_policy;
    use sui::package;
    

    // ========== Constants ==========
    
    /// Error codes
    const ENameAlreadyExists: u64 = 11;
    const EInvalidName: u64 = 12;

    /// Default values
    const DEFAULT_CREATOR_FEE_BPS: u16 = 250; // 2.5%
    const DEFAULT_DUPLICATE_FEE: u64 = 10_000_000; // 0.01 SUI
    const MAX_FEE_BPS: u16 = 10000; // 100%
    

    // ========== Core Structs ==========

    /// Admin capability for privileged operations
    public struct AdminCap has key {
        id: UID,
    }

    /// Main collection state - simplified without staking/rewards
    public struct Collection has key {
        id: UID,
        minted_count: u64,
        treasury: Balance<SUI>,
        config: CollectionConfig,
        public_recipes: Table<vector<u8>, PublicRecipe>,
        recipe_list: vector<vector<u8>>,
        used_names: Table<String, address>,
        names_list: vector<String>,
        recipes_by_item: Table<u64, vector<vector<u8>>>,
    }

    public struct PublicRecipe has store, copy, drop {
        recipe_hash: vector<u8>,
        creator: address,
        name: String,
        metadata: NFTMetadata,
        creation_time: u64,
        usage_count: u64,
    }

    /// Simplified configuration struct
    public struct CollectionConfig has store {
        creator_fee_bps: u16,
        duplicate_recipe_fee: u64,
        recipes: Table<vector<u8>, address>,
    }

    /// NFT representation with cleaner structure
    public struct CreatureNFT has key, store {
        id: UID,
        metadata: NFTMetadata,
        creator: address,
        created_at: u64,
    }

    public struct ItemInfo has store, copy, drop {
        item_id: u64,
        quantity: u64,
    }

    public struct NFTMetadata has store, drop, copy {
        name: String,
        material_items: vector<ItemInfo>,
        image_uri: String,
        created_at: u64,
        prompt: String,
    }

    // ========== Events ==========

    public struct NFTMinted has copy, drop {
        nft_id: object::ID,
        name: String,
        creator: address,
        is_duplicate_recipe: bool,
    }

    public struct CREATURE_NFT has drop {}

    // ========== Initialization ==========
    #[allow(lint(share_owned))]
    fun init(witness: CREATURE_NFT, ctx: &mut TxContext) {
        let publisher = package::claim(witness, ctx);
        let (policy, cap) = transfer_policy::new<CreatureNFT>(&publisher, ctx);

        let collection = Collection {
            id: object::new(ctx),
            minted_count: 0,
            treasury: balance::zero(),
            config: create_default_config(ctx),
            used_names: table::new(ctx),
            names_list: vector::empty(),
            public_recipes: table::new(ctx),
            recipe_list: vector::empty(),
            recipes_by_item: table::new(ctx),
        };
        
        transfer::public_share_object(policy);
        transfer::transfer(
            AdminCap { id: object::new(ctx) }, 
            tx_context::sender(ctx)
        );
        transfer::public_transfer(cap, tx_context::sender(ctx));
        transfer::public_transfer(publisher, tx_context::sender(ctx));
        transfer::share_object(collection);
    }

    fun create_default_config(ctx: &mut TxContext): CollectionConfig {
        CollectionConfig {
            creator_fee_bps: DEFAULT_CREATOR_FEE_BPS,
            duplicate_recipe_fee: DEFAULT_DUPLICATE_FEE,
            recipes: table::new(ctx),
        }
    }

    public fun is_name_available(collection: &Collection, name: &String): bool {
        !table::contains(&collection.used_names, *name)
    }

    fun reserve_name(collection: &mut Collection, name: String, creator: address) {
        assert!(!table::contains(&collection.used_names, name), ENameAlreadyExists);
        
        table::add(&mut collection.used_names, name, creator);
        vector::push_back(&mut collection.names_list, name);
    }

    // ========== Recipe Management ==========

    public fun calculate_recipe_hash(metadata: &NFTMetadata): vector<u8> {
        let serialized = serialize_recipe_data(metadata);
        hash::sha2_256(serialized)
    }

    fun serialize_recipe_data(
        metadata: &NFTMetadata
    ): vector<u8> {
        let mut serialized = vector::empty<u8>();
        serialize_items(&mut serialized, &metadata.material_items);
        
        serialized
    }

    fun u64_to_bytes(value: u64): vector<u8> {
        let mut bytes = vector::empty<u8>();
        let mut temp = value;
        
        if (temp == 0) {
            vector::push_back(&mut bytes, 0u8);
            return bytes
        };
        
        while (temp > 0) {
            vector::push_back(&mut bytes, ((temp % 256) as u8));
            temp = temp / 256;
        };
        
        // Reverse for big-endian
        vector::reverse(&mut bytes);
        bytes
    }

    fun serialize_items(serialized: &mut vector<u8>, items: &vector<ItemInfo>) {
        let len = vector::length(items);
        let mut i = 0;
        
        while (i < len) {
            let item = vector::borrow(items, i);
            // Convert numbers to bytes and append
            let item_id_bytes = u64_to_bytes(item.item_id);
            let quantity_bytes = u64_to_bytes(item.quantity);
            
            vector::append(serialized, item_id_bytes);
            vector::push_back(serialized, 0u8); // separator
            vector::append(serialized, quantity_bytes);
            vector::push_back(serialized, 0u8); // separator
            
            i = i + 1;
        };
    }

    public fun check_recipe(
        collection: &Collection,
        recipe_hash: &vector<u8>
    ): (bool, address) {
        if (table::contains(&collection.config.recipes, *recipe_hash)) {
            (true, *table::borrow(&collection.config.recipes, *recipe_hash))
        } else {
            (false, @0x0)
        }
    }

    fun increment_recipe_usage(
        collection: &mut Collection,
        recipe_hash: &vector<u8>
    ) {
        if (table::contains(&collection.public_recipes, *recipe_hash)) {
            let public_recipe = table::borrow_mut(&mut collection.public_recipes, *recipe_hash);
            public_recipe.usage_count = public_recipe.usage_count + 1;
        }
    }

    // ========== Admin Functions ==========

    public fun add_treasury_funds(
        _: &AdminCap,
        collection: &mut Collection,
        payment: &mut Coin<SUI>,
        amount: u64,
        ctx: &mut TxContext
    ) {
        let coin_balance = coin::split(payment, amount, ctx);
        balance::join(&mut collection.treasury, coin::into_balance(coin_balance));
    }

    public fun withdraw_treasury(
        _: &AdminCap,
        collection: &mut Collection,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let balance_value = balance::value(&collection.treasury);
        assert!(amount <= balance_value, 1002);
        
        let withdrawn_balance = balance::split(&mut collection.treasury, amount);
        let withdrawn_coin = coin::from_balance(withdrawn_balance, ctx);
        transfer::public_transfer(withdrawn_coin, recipient);
    }

    public fun update_duplicate_recipe_fee(
        _: &AdminCap,
        collection: &mut Collection,
        fee_amount: u64,
    ) {
        collection.config.duplicate_recipe_fee = fee_amount;
    }

    public fun update_creator_fee(
        _: &AdminCap,
        collection: &mut Collection,
        fee_bps: u16,
    ) {
        assert!(fee_bps <= MAX_FEE_BPS, 10);
        collection.config.creator_fee_bps = fee_bps;
    }


    fun build_simple_items(item_ids: vector<u64>, quantities: vector<u64>): vector<ItemInfo> {
        assert!(vector::length(&item_ids) == vector::length(&quantities), 1001);
        
        let mut items = vector::empty<ItemInfo>();
        let len = vector::length(&item_ids);
        
        let mut i = 0;
        while (i < len) {
            let item = ItemInfo {
                item_id: *vector::borrow(&item_ids, i),
                quantity: *vector::borrow(&quantities, i)
            };
            vector::push_back(&mut items, item);
            i = i + 1;
        };
        
        items
    }

    public fun admin_mint_nft(
        _: &AdminCap,
        collection: &mut Collection,
        name: String,
        element_ids: vector<u64>,
        element_quantities: vector<u64>,
        prompt: String,
        image_uri: String,
        payment: &mut Coin<SUI>,
        recipient: address,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(is_name_available(collection, &name), ENameAlreadyExists);
        
        validate_name(&name);
        reserve_name(collection, name, tx_context::sender(ctx));
        
        let material_items = build_simple_items(element_ids, element_quantities);
        
        let prompt_bytes = string::as_bytes(&prompt);
        let prompt_hash = hash::sha2_256(*prompt_bytes);
        
        let prompt_exists = table::contains(&collection.public_recipes, prompt_hash);
        let mut is_duplicate = false;
        
        if (prompt_exists) {
            is_duplicate = true;
            let existing_recipe = table::borrow(&collection.public_recipes, prompt_hash);
            let original_creator = existing_recipe.creator;
            
            let payment_amount = coin::value(payment);
            if (payment_amount > 0) {
                let payment_coin = coin::split(payment, payment_amount, ctx);
                transfer::public_transfer(payment_coin, original_creator);
            };
            
            increment_recipe_usage(collection, &prompt_hash);
        } else {
            let payment_amount = coin::value(payment);
            if (payment_amount > 0) {
                let payment_balance = coin::into_balance(coin::split(payment, payment_amount, ctx));
                balance::join(&mut collection.treasury, payment_balance);
            };
            
            let temp_metadata = NFTMetadata {
                name,
                material_items,
                image_uri,
                prompt,
                created_at: clock::timestamp_ms(clock),
            };
            
            let public_recipe = PublicRecipe {
                recipe_hash: prompt_hash,
                creator: recipient,
                name,
                metadata: temp_metadata,
                creation_time: clock::timestamp_ms(clock),
                usage_count: 1,
            };
            
            table::add(&mut collection.public_recipes, prompt_hash, public_recipe);
            vector::push_back(&mut collection.recipe_list, prompt_hash);
        };
        
        let metadata = NFTMetadata {
            name,
            material_items,
            image_uri,
            created_at: clock::timestamp_ms(clock),
            prompt,
        };
        
        let nft_id = object::new(ctx);
        
        collection.minted_count = collection.minted_count + 1;
        
        event::emit(NFTMinted {
            nft_id: object::uid_to_inner(&nft_id),
            name: metadata.name,
            creator: tx_context::sender(ctx),
            is_duplicate_recipe: is_duplicate,
        });
        
        let nft = CreatureNFT {
            id: nft_id,
            metadata: metadata,
            creator: tx_context::sender(ctx),
            created_at: clock::timestamp_ms(clock),
        };
        
        transfer::public_transfer(nft, recipient);
    }


    fun validate_name(name: &String) {
        let name_bytes = string::as_bytes(name);
        let len = vector::length(name_bytes);
        
        // Name must be between 1 and 50 characters
        assert!(len > 0 && len <= 50, EInvalidName);
        
        // Name cannot be just whitespace
        let mut has_non_whitespace = false;
        let mut i = 0;
        while (i < len) {
            let byte = *vector::borrow(name_bytes, i);
            if (byte != 32u8 && byte != 9u8 && byte != 10u8 && byte != 13u8) { // not space, tab, newline, carriage return
                has_non_whitespace = true;
                break
            };
            i = i + 1;
        };
        
        assert!(has_non_whitespace, EInvalidName);
    }

    // ========== Pool Integration Functions ==========
    // These functions are needed by the pool_rewards module

    /// Extract all unique item IDs from an NFT (for pool validation)
    public fun get_all_item_ids(nft: &CreatureNFT): vector<u64> {
        let mut all_ids = vector::empty<u64>();
        
        // Extract from material_items only (since that's the only item list in metadata)
        extract_ids_from_items(&mut all_ids, &nft.metadata.material_items);
        
        all_ids
    }

    /// Helper function to extract unique item IDs from a vector of ItemInfo
    fun extract_ids_from_items(all_ids: &mut vector<u64>, items: &vector<ItemInfo>) {
        let len = vector::length(items);
        let mut i = 0;
        
        while (i < len) {
            let item = vector::borrow(items, i);
            // Add item_id if not already present
            if (!vector::contains(all_ids, &item.item_id)) {
                vector::push_back(all_ids, item.item_id);
            };
            i = i + 1;
        };
    }

    // ========== View Functions ==========

    public fun get_collection_stats(collection: &Collection): (u64, u64) {
        (
            collection.minted_count,
            balance::value(&collection.treasury)
        )
    }

    public fun get_nft_info(nft: &CreatureNFT): (&String, address, u64) {
        (&nft.metadata.name, nft.creator, nft.created_at)
    }

    // ========== Test Functions ==========

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        let witness = CREATURE_NFT {};
        init(witness, ctx);
    }

    #[test_only]
    public fun get_name(nft: &CreatureNFT): String { 
        nft.metadata.name 
    }

    #[test_only]
    public fun get_creator(nft: &CreatureNFT): address { 
        nft.creator 
    }

    #[test_only]
    public fun get_minted_count(collection: &Collection): u64 { 
        collection.minted_count 
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
