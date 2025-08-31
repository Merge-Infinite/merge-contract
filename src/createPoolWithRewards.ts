import { getFullnodeUrl, SuiClient } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { Transaction } from "@mysten/sui/transactions";
import * as dotenv from "dotenv";

dotenv.config();

interface PoolCreationConfig {
  poolName: string;
  poolDescription: string;
  imageUrl: string;
  rewardAmount: number; // Amount of SUI to add as rewards (in MIST)
  inputCoinId: string; // Source coin to split from
  privateKey?: string;
}

const CONTRACT_ADDRESSES = {
  createPool: {
    packageId:
      "0x17aa7d1e8f59d5a869847b308837e7bdee73ee19b11b970dba0f2a8435bec549",
    module: "pool_rewards",
    adminCap:
      "0xcf2ec72ccd0ef48d55178162915c9ebaf40c9d1c553afd19afe7d60fd84a90ec",
    poolState:
      "0x95bb3b15405d31b39d33c3e9f4861fe3c47e4a695332c70cd464a856b2b8bb12",
  },
  addRewards: {
    module: "pool_rewards",
  },
  clock: "0x6",
};

async function createPoolWithRewards(config: PoolCreationConfig) {
  try {
    console.log("🚀 Starting pool creation with rewards...\n");

    const client = new SuiClient({ url: getFullnodeUrl("mainnet") });

    const privateKey = process.env.SUI_PRIVATE_KEY;
    if (!privateKey) {
      throw new Error(
        "Private key not provided. Set SUI_PRIVATE_KEY in .env file"
      );
    }

    const keypair = Ed25519Keypair.fromSecretKey(privateKey);
    const address = keypair.getPublicKey().toSuiAddress();
    console.log(`📍 Using address: ${address}`);

    // Calculate timestamps
    const now = Date.now();
    const endTime = now + 1 * 60 * 60 * 1000;

    console.log(`📅 Pool Timeline:`);
    console.log(
      `   Start: ${new Date(now).toLocaleString()} (7 days from now)`
    );
    console.log(
      `   End:   ${new Date(endTime).toLocaleString()} (37 days from now)\n`
    );

    // Step 1: Create the pool
    console.log("📝 Step 1: Creating pool...");

    const createTx = new Transaction();

    createTx.moveCall({
      target: `${CONTRACT_ADDRESSES.createPool.packageId}::${CONTRACT_ADDRESSES.createPool.module}::create_pool`,
      arguments: [
        createTx.object(CONTRACT_ADDRESSES.createPool.adminCap),
        createTx.object(CONTRACT_ADDRESSES.createPool.poolState),
        createTx.pure.string(config.poolName),
        createTx.pure.string(config.poolDescription),
        createTx.pure.vector("string", []), // Empty metadata array
        createTx.pure.u64(now),
        createTx.pure.string(config.imageUrl),
        createTx.pure.u64(endTime),
        createTx.object(CONTRACT_ADDRESSES.clock),
      ],
    });

    const createResult = await client.signAndExecuteTransaction({
      signer: keypair,
      transaction: createTx,
      options: {
        showEffects: true,
        showObjectChanges: true,
      },
    });

    console.log(`✅ Pool created!`);
    console.log(`   Transaction: ${createResult.digest}`);

    // Wait 5 seconds before next step
    console.log("⏳ Waiting 2 seconds...");
    await new Promise((resolve) => setTimeout(resolve, 2000));

    // Extract pool ID from the transaction result
    const poolObject = createResult.objectChanges?.find(
      (change) =>
        change.type === "created" && change.objectType?.includes("Pool")
    );

    if (!poolObject || !("objectId" in poolObject)) {
      throw new Error("Could not find pool ID in transaction result");
    }

    const poolId = poolObject.objectId;
    console.log(`   Pool ID: ${poolId}\n`);

    // Step 2: Start the pool
    console.log("⏱️  Step 2: Starting pool...");
    const startTx = new Transaction();

    startTx.moveCall({
      target: `${CONTRACT_ADDRESSES.createPool.packageId}::${CONTRACT_ADDRESSES.createPool.module}::start_pool`,
      arguments: [
        startTx.object(CONTRACT_ADDRESSES.createPool.adminCap),
        startTx.object(CONTRACT_ADDRESSES.createPool.poolState),
        startTx.object(poolId),
        startTx.object(CONTRACT_ADDRESSES.clock),
      ],
    });

    const startResult = await client.signAndExecuteTransaction({
      signer: keypair,
      transaction: startTx,
      options: {
        showEffects: true,
      },
    });

    console.log(`✅ Pool started!`);
    console.log(`   Transaction: ${startResult.digest}\n`);

    // Wait 5 seconds before next step
    console.log("⏳ Waiting 2 seconds...");
    await new Promise((resolve) => setTimeout(resolve, 2000));

    // Step 3: Create coin object with reward amount
    console.log("💰 Step 3: Creating coin object for rewards...");
    console.log(
      `   Amount: ${config.rewardAmount} MIST (${
        config.rewardAmount / 1_000_000_000
      } SUI)`
    );

    // Check if the input coin exists and has enough balance
    try {
      const coinInfo = await client.getObject({
        id: config.inputCoinId,
        options: { showContent: true },
      });

      if (!coinInfo.data) {
        throw new Error(`Coin object ${config.inputCoinId} not found`);
      }

      console.log(`   Input coin: ${config.inputCoinId}`);
    } catch (error: any) {
      throw new Error(`Failed to verify input coin: ${error.message}`);
    }

    const splitTx = new Transaction();

    // Split coins to create a new coin object with the exact reward amount
    const [coin] = splitTx.splitCoins(splitTx.gas, [
      splitTx.pure.u64(config.rewardAmount),
    ]);

    // Transfer the split coin to the pool's address (temporary holder)
    splitTx.transferObjects([coin], address);

    const splitResult = await client.signAndExecuteTransaction({
      signer: keypair,
      transaction: splitTx,
      options: {
        showEffects: true,
        showObjectChanges: true,
      },
    });

    console.log(`✅ Coin object created!`);
    console.log(`   Transaction: ${splitResult.digest}`);

    // Wait 5 seconds before next step
    console.log("⏳ Waiting 2 seconds...");
    await new Promise((resolve) => setTimeout(resolve, 2000));

    // Find the created coin object
    const coinObject = splitResult.objectChanges?.find(
      (change) =>
        change.type === "created" &&
        change.objectType?.includes("0x2::coin::Coin")
    );

    if (!coinObject || !("objectId" in coinObject)) {
      throw new Error("Could not find coin object ID in transaction result");
    }

    const rewardCoinId = coinObject.objectId;
    console.log(`   Reward Coin ID: ${rewardCoinId}\n`);

    // Step 4: Add rewards to the pool
    console.log("💎 Step 4: Adding rewards to pool...");
    const rewardsTx = new Transaction();

    rewardsTx.moveCall({
      target: `${CONTRACT_ADDRESSES.createPool.packageId}::${CONTRACT_ADDRESSES.addRewards.module}::add_sui_rewards_from_balance`,
      arguments: [
        rewardsTx.object(CONTRACT_ADDRESSES.createPool.adminCap),
        rewardsTx.object(CONTRACT_ADDRESSES.createPool.poolState),
        rewardsTx.object(poolId),
        rewardsTx.object(rewardCoinId),
      ],
    });

    const rewardsResult = await client.signAndExecuteTransaction({
      signer: keypair,
      transaction: rewardsTx,
      options: {
        showEffects: true,
      },
    });

    console.log(`✅ Rewards added to pool!`);
    console.log(`   Transaction: ${rewardsResult.digest}\n`);

    // Summary
    console.log("🎉 Pool creation with rewards completed successfully!\n");
    console.log("📊 Summary:");
    console.log(`   Pool Name: ${config.poolName}`);
    console.log(`   Pool ID: ${poolId}`);
    console.log(`   Start Time: ${new Date(now).toLocaleString()}`);
    console.log(`   End Time: ${new Date(endTime).toLocaleString()}`);
    console.log(
      `   Reward Amount: ${config.rewardAmount} MIST (${
        config.rewardAmount / 1_000_000_000
      } SUI)`
    );
    console.log(`   Reward Coin ID: ${rewardCoinId}`);

    return {
      poolId,
      createTx: createResult.digest,
      startTx: startResult.digest,
      splitTx: splitResult.digest,
      rewardsTx: rewardsResult.digest,
      rewardCoinId,
      startTime: now,
      endTime: endTime,
    };
  } catch (error) {
    console.error("❌ Error:", error);
    throw error;
  }
}

// Main execution
async function main() {
  // Parse command line arguments
  const args = process.argv.slice(2);

  // Default configuration
  const config: PoolCreationConfig = {
    poolName: "Empty Element Pool",
    poolDescription: "Empty elements reward pool",
    imageUrl: "https://app.merg3.xyz/images/sui.svg",
    rewardAmount: 30000000, // Default 0.03 SUI (30 million MIST)
    inputCoinId: "", // Must be provided
  };

  // Parse arguments
  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case "--name":
        config.poolName = args[++i];
        break;
      case "--description":
        config.poolDescription = args[++i];
        break;
      case "--coin":
        config.inputCoinId = args[++i];
        break;
      case "--amount":
        config.rewardAmount = parseInt(args[++i]);
        break;
      case "--image":
        config.imageUrl = args[++i];
        break;

      case "--help":
        console.log(`
Usage: pnpm run create-pool-rewards --coin <INPUT_COIN_ID> --amount <REWARD_AMOUNT> [options]

Required:
  --coin <id>          Input coin object ID (source of funds)
  --amount <mist>      Reward amount in MIST (1 SUI = 1,000,000,000 MIST)

Options:
  --name <name>        Pool name (default: "Empty Element Pool")
  --description <desc> Pool description (default: "Empty elements reward pool")
  --image <url>        Image URL (default: "https://app.merg3.xyz/images/sui.svg")
  --network <network>  Network: mainnet, testnet, or devnet (default: testnet)
  --help              Show this help message

Environment:
  SUI_PRIVATE_KEY     Your Sui private key (base64 encoded)

Example:
  # Add 0.03 SUI as rewards
  pnpm run create-pool-rewards --coin 0x060b4c5d10ccc962143f56c1e353b95a99a8a346c0bfddf715e1ff48356b66d3 --amount 30000000 --name "My Pool"
  
  # Add 1 SUI as rewards
  pnpm run create-pool-rewards --coin 0x123... --amount 1000000000 --name "Big Rewards Pool"
        `);
        process.exit(0);
    }
  }

  // Validate required parameters
  if (!config.inputCoinId) {
    console.error("❌ Error: --coin parameter is required");
    console.log("Run with --help for usage information");
    process.exit(1);
  }

  if (!config.rewardAmount || config.rewardAmount <= 0) {
    console.error(
      "❌ Error: --amount parameter is required and must be positive"
    );
    console.log("Run with --help for usage information");
    process.exit(1);
  }

  // Execute
  await createPoolWithRewards(config);
}

// Run if executed directly
if (require.main === module) {
  main().catch((error) => {
    console.error("Fatal error:", error);
    process.exit(1);
  });
}

export { createPoolWithRewards, PoolCreationConfig };
