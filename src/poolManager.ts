import { getFullnodeUrl, SuiClient } from "@mysten/sui/client";
import { Ed25519Keypair } from "@mysten/sui/keypairs/ed25519";
import { Transaction } from "@mysten/sui/transactions";
import { fromB64 } from "@mysten/sui/utils";
import * as dotenv from "dotenv";

dotenv.config();

export interface PoolConfig {
  packageId: string;
  module: string;
  adminCap: string;
  poolState: string;
  name: string;
  description: string;
  metadata: string[];
  startTime: number;
  imageUrl: string;
  endTime: number;
  clock: string;
}

export interface RewardConfig {
  packageId: string;
  module: string;
  adminCap: string;
  poolState: string;
  poolId: string;
  coinObjectId: string;
}

export class PoolManager {
  private client: SuiClient;
  private keypair: Ed25519Keypair;

  constructor(
    network: "mainnet" | "testnet" | "devnet" = "testnet",
    privateKey?: string
  ) {
    this.client = new SuiClient({ url: getFullnodeUrl(network) });

    if (privateKey) {
      this.keypair = Ed25519Keypair.fromSecretKey(fromB64(privateKey));
    } else if (process.env.SUI_PRIVATE_KEY) {
      this.keypair = Ed25519Keypair.fromSecretKey(
        fromB64(process.env.SUI_PRIVATE_KEY)
      );
    } else {
      throw new Error(
        "Private key not provided. Set SUI_PRIVATE_KEY environment variable or pass it as parameter."
      );
    }
  }

  async createPool(config: PoolConfig): Promise<string> {
    const tx = new Transaction();

    tx.moveCall({
      target: `${config.packageId}::${config.module}::create_pool`,
      arguments: [
        tx.object(config.adminCap),
        tx.object(config.poolState),
        tx.pure.string(config.name),
        tx.pure.string(config.description),
        tx.pure.vector("string", config.metadata),
        tx.pure.u64(config.startTime),
        tx.pure.string(config.imageUrl),
        tx.pure.u64(config.endTime),
        tx.object(config.clock),
      ],
    });

    const result = await this.client.signAndExecuteTransaction({
      signer: this.keypair,
      transaction: tx,
      options: {
        showEffects: true,
        showObjectChanges: true,
      },
    });

    console.log("Pool created successfully!");
    console.log("Transaction digest:", result.digest);

    const poolObject = result.objectChanges?.find(
      (change) =>
        change.type === "created" && change.objectType?.includes("Pool")
    );

    if (poolObject && "objectId" in poolObject) {
      console.log("Pool ID:", poolObject.objectId);
      return poolObject.objectId;
    }

    return result.digest;
  }

  async startPool(
    packageId: string,
    module: string,
    adminCap: string,
    poolState: string,
    poolId: string,
    clock: string
  ): Promise<string> {
    const tx = new Transaction();

    tx.moveCall({
      target: `${packageId}::${module}::start_pool`,
      arguments: [
        tx.object(adminCap),
        tx.object(poolState),
        tx.object(poolId),
        tx.object(clock),
      ],
    });

    const result = await this.client.signAndExecuteTransaction({
      signer: this.keypair,
      transaction: tx,
      options: {
        showEffects: true,
      },
    });

    console.log("Pool started successfully!");
    console.log("Transaction digest:", result.digest);
    return result.digest;
  }

  async endPool(
    packageId: string,
    module: string,
    adminCap: string,
    poolState: string,
    poolId: string,
    clock: string
  ): Promise<string> {
    const tx = new Transaction();

    tx.moveCall({
      target: `${packageId}::${module}::end_pool`,
      arguments: [
        tx.object(adminCap),
        tx.object(poolState),
        tx.object(poolId),
        tx.object(clock),
      ],
    });

    const result = await this.client.signAndExecuteTransaction({
      signer: this.keypair,
      transaction: tx,
      options: {
        showEffects: true,
      },
    });

    console.log("Pool ended successfully!");
    console.log("Transaction digest:", result.digest);
    return result.digest;
  }

  async addSuiRewards(config: RewardConfig): Promise<string> {
    const tx = new Transaction();

    tx.moveCall({
      target: `${config.packageId}::${config.module}::add_sui_rewards_from_balance`,
      arguments: [
        tx.object(config.adminCap),
        tx.object(config.poolState),
        tx.object(config.poolId),
        tx.object(config.coinObjectId),
      ],
    });

    const result = await this.client.signAndExecuteTransaction({
      signer: this.keypair,
      transaction: tx,
      options: {
        showEffects: true,
      },
    });

    console.log("SUI rewards added successfully!");
    console.log("Transaction digest:", result.digest);
    return result.digest;
  }

  async paySui(
    inputCoins: string[],
    amounts: number[],
    recipients: string[]
  ): Promise<string> {
    const tx = new Transaction();

    const coins = tx.splitCoins(
      tx.object(inputCoins[0]),
      amounts.map((amount) => tx.pure.u64(amount))
    );

    recipients.forEach((recipient, index) => {
      tx.transferObjects([coins[index]], recipient);
    });

    const result = await this.client.signAndExecuteTransaction({
      signer: this.keypair,
      transaction: tx,
      options: {
        showEffects: true,
      },
    });

    console.log("SUI payment successful!");
    console.log("Transaction digest:", result.digest);
    return result.digest;
  }

  async getPoolInfo(poolId: string): Promise<any> {
    try {
      const pool = await this.client.getObject({
        id: poolId,
        options: {
          showContent: true,
          showType: true,
        },
      });

      return pool;
    } catch (error) {
      console.error("Error fetching pool info:", error);
      throw error;
    }
  }
}

if (require.main === module) {
  const command = process.argv[2];
  const manager = new PoolManager("testnet");

  switch (command) {
    case "create-pool":
      const poolConfig: PoolConfig = {
        packageId:
          "0x1f246b075220ec5f49435224ca862fa60c254b9c544c8961764b1bfe77bf8728",
        module: "pool_rewards",
        adminCap:
          "0x417e3cdaaeb94175612918c7a8078453dcdf654440bbb0098e1764f5917bb848",
        poolState:
          "0x41fce698233d9163d93754e76c8dc1c6c7c4b04231491f632aead72b5c0d2e01",
        name: "Empty Element Pool 2",
        description: "Empty elements 2",
        metadata: [],
        startTime: 1749379144000,
        imageUrl: "https://app.merg3.xyz/images/sui.svg",
        endTime: 1755247014000,
        clock: "0x6",
      };

      manager
        .createPool(poolConfig)
        .then((result) => console.log("Pool created with result:", result))
        .catch((error) => console.error("Error:", error));
      break;

    case "add-rewards":
      const rewardConfig: RewardConfig = {
        packageId:
          "0x417ec8eec0c63303256299861a14804ff0a5bedf5ac1cbaf3c73eae0d0118f1b",
        module: "pool_rewards",
        adminCap:
          "0x417e3cdaaeb94175612918c7a8078453dcdf654440bbb0098e1764f5917bb848",
        poolState:
          "0x41fce698233d9163d93754e76c8dc1c6c7c4b04231491f632aead72b5c0d2e01",
        poolId:
          "0x7d54581fec5049a58ad534ce5a39669ac00ef15dd565f1ee5a983a8172e0dba4",
        coinObjectId:
          "0x0972fd214e552b455f65c50c04103dfdc202577f0890c217be3ec2afe2c7ef42",
      };

      manager
        .addSuiRewards(rewardConfig)
        .then((result) => console.log("Rewards added with result:", result))
        .catch((error) => console.error("Error:", error));
      break;

    default:
      console.log("Usage: ts-node poolManager.ts [create-pool|add-rewards]");
  }
}
