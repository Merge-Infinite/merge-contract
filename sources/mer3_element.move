// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module merg3::creative_element_nft {
    use std::string::{Self, String};
    use sui::event;
    use sui::sui::SUI;
    use sui::balance::{Self, Balance};
    use sui::table::{Self, Table};
    use sui::clock::{Self, Clock};
    use sui::display;
    use sui::package;
    use sui::transfer_policy;

    

    
    /// Default values
    const DEFAULT_CREATOR_FEE_BPS: u16 = 250; // 2.5%

    
    // ========== Core Structs ==========

    /// One-time witness for the package
    public struct CREATIVE_ELEMENT_NFT has drop {}

    /// Admin capability for privileged operations
    public struct AdminCap has key, store {
        id: UID,
    }

    /// Main collection state
    public struct ElementCollection has key {
        id: UID,
        minted_count: u64,
        treasury: Balance<SUI>,
        config: CollectionConfig,
        pending_rewards: Table<object::ID, u64>
    }

    public struct CollectionConfig has store {
        creator_fee_bps: u16,
    }


    /// Creative Element NFT with enhanced metadata and image support
    public struct CreativeElementNFT has key, store {
        id: UID,
        /// Basic element information
        element_name: String,
        amount: u64,
        emoji: String,
        item_id: String,
        creator: address,
        created_at: u64,
        /// Generated image data
        image_url: String,
    }

    public struct CreativeElementMinted has copy, drop {
        nft_id: object::ID,
        element_name: String,
        amount: u64,
        creator: address,
    }

    // ========== Initialization ==========

    fun init(witness: CREATIVE_ELEMENT_NFT, ctx: &mut TxContext) {
        let publisher = package::claim(witness, ctx);
        let (policy, cap) = transfer_policy::new<CreativeElementNFT>(&publisher, ctx);
        transfer::public_share_object(policy);

        // Create display for the NFT
        let mut display = display::new<CreativeElementNFT>(&publisher, ctx);
        
        // Set display fields
        display::add(&mut display, string::utf8(b"name"), string::utf8(b"{metadata.name}"));
        display::add(&mut display, string::utf8(b"element_name"), string::utf8(b"{element_name}"));
        display::add(&mut display, string::utf8(b"emoji"), string::utf8(b"{emoji}"));
        display::add(&mut display, string::utf8(b"amount"), string::utf8(b"{amount}"));
        display::add(&mut display, string::utf8(b"item_id"), string::utf8(b"{item_id}"));
        display::add(&mut display, string::utf8(b"image_url"), string::utf8(b"{image_url}"));
        display::add(&mut display, string::utf8(b"creator"), string::utf8(b"{creator}"));
        
        display::update_version(&mut display);

        // Create admin capability
        let admin_cap = AdminCap {
            id: object::new(ctx)
        };

        // Create collection
        let collection = ElementCollection {
            id: object::new(ctx),
            minted_count: 0,
            treasury: balance::zero(),
            config: CollectionConfig {
                creator_fee_bps: DEFAULT_CREATOR_FEE_BPS,
            },
            pending_rewards: table::new(ctx)
        };

        // Transfer objects
        transfer::public_transfer(display, tx_context::sender(ctx));
        transfer::public_transfer(publisher, tx_context::sender(ctx));
        transfer::public_transfer(cap, tx_context::sender(ctx));
        transfer::public_transfer(admin_cap, tx_context::sender(ctx));
        transfer::share_object(collection);
    }


    // ========== Admin Mint Function ==========

    public entry fun mint_with_admin(
        _admin: &AdminCap,
        collection: &mut ElementCollection,
        element_name: String,
        amount: u64,
        emoji: String,
        item_id: String,
        image_url: String,
        recipient: address,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        mint_creative_element(
            collection,
            element_name,
            amount,
            emoji,
            item_id,
            image_url,
            recipient,
            clock,
            ctx
        );
    }

    public entry fun mint_creative_element(
        collection: &mut ElementCollection,
        element_name: String,
        amount: u64,
        emoji: String,
        item_id: String,
        image_url: String,
        recipient: address,
        clock: &Clock,
        ctx: &mut TxContext
    ) {

        let nft = mint_creative_element_nft(
            collection,
            element_name,
            amount,
            emoji,
            item_id,
            image_url,
            clock,
            ctx
        );

        transfer::public_transfer(nft, recipient);
    }

    public fun mint_creative_element_nft(
        collection: &mut ElementCollection,
        element_name: String,
        amount: u64,
        emoji: String,
        item_id: String,
        image_url: String,
        clock: &Clock,
        ctx: &mut TxContext
    ): CreativeElementNFT {
        
    
        let nft = CreativeElementNFT {
            id: object::new(ctx),
            element_name,
            amount,
            emoji,
            item_id,
            creator: tx_context::sender(ctx),
            created_at: clock::timestamp_ms(clock),
            image_url,
        };

        collection.minted_count = collection.minted_count + 1;
        
        event::emit(CreativeElementMinted {
            nft_id: object::id(&nft),
            element_name: nft.element_name,
            amount: nft.amount,
            creator: nft.creator,
        });
        
        nft
    }

    /// Burns a CreativeElementNFT
    public entry fun burn(nft: CreativeElementNFT, _: &mut TxContext) {
        let CreativeElementNFT { 
            id, 
            element_name: _, 
            amount: _, 
            emoji: _, 
            item_id: _, 
            creator: _, 
            created_at: _,
            image_url: _
        } = nft;
        object::delete(id);
    }

    // ========== View Functions ==========

    public fun get_element_name(nft: &CreativeElementNFT): String {
        nft.element_name
    }
    
    public fun get_amount(nft: &CreativeElementNFT): u64 {
        nft.amount
    }
    
    public fun get_emoji(nft: &CreativeElementNFT): String {
        nft.emoji
    }
    
    public fun get_item_id(nft: &CreativeElementNFT): String {
        nft.item_id
    }

    public fun get_creator(nft: &CreativeElementNFT): address {
        nft.creator
    }

    public fun get_created_at(nft: &CreativeElementNFT): u64 {
        nft.created_at
    }

    public fun get_image_url(nft: &CreativeElementNFT): String {
        nft.image_url
    }


    // ========== Test Functions ==========

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        let witness = CREATIVE_ELEMENT_NFT {};
        init(witness, ctx);
    }
}
