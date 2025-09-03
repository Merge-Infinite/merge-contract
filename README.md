# Mer3 Contract TypeScript CLI

TypeScript implementation for managing Mer3 pools and rewards on the Sui blockchain.
upgrade_cap = "0xafbe2cd1caeb4828aca585e763754d16028ef8d1328215f54b3847f33b10f1b9"

## Setup

1. Install dependencies:

```bash
pnpm install
```

2. Configure environment:

```bash
cp .env.example .env
# Edit .env with your private key and contract addresses
```

## Usage

### Using the CLI

```bash
# Create a new pool
pnpm run dev create-pool --name "My Pool" --description "Pool description"

# Start a pool
pnpm run dev start-pool --pool-id 0x...

# End a pool
pnpm run dev end-pool --pool-id 0x...

# Add rewards to a pool
pnpm run dev add-rewards --pool-id 0x... --coin-id 0x...

# Create pool rewards (combine create and add rewards)
pnpm  create-pool-rewards --coin 0x5ae5b7937ef8824ce02f46d559e1b52d8b0d9cd6098e18c5568f24d385bd1430 --amount 1000000000 --name "Final Test" --description "Final Test" --image "https://app.merg3.xyz/images/sui.svg"
# Get pool information
pnpm run dev pool-info --pool-id 0x...

# Execute full flow (create, start, add rewards)
pnpm run dev full-flow --name "Test Pool" --coin-id 0x...
```

### Using as a library

```typescript
import { PoolManager, PoolConfig } from "./poolManager";

const manager = new PoolManager("testnet", "your-private-key");

// Create a pool
const poolConfig: PoolConfig = {
  packageId: "0x...",
  module: "pool_rewards",
  adminCap: "0x...",
  poolState: "0x...",
  name: "My Pool",
  description: "Pool description",
  metadata: [],
  startTime: Date.now(),
  imageUrl: "https://example.com/image.png",
  endTime: Date.now() + 30 * 24 * 60 * 60 * 1000,
  clock: "0x6",
};

const poolId = await manager.createPool(poolConfig);

// Add rewards
await manager.addSuiRewards({
  packageId: "0x...",
  module: "pool_rewards",
  adminCap: "0x...",
  poolState: "0x...",
  poolId: poolId,
  coinObjectId: "0x...",
});
```

## Build

```bash
pnpm run build
```

## Commands Reference

All commands support the following options:

- `-n, --network <network>`: Network to use (mainnet, testnet, devnet). Default: testnet

### Available Commands:

- `create-pool`: Create a new reward pool
- `start-pool`: Start an existing pool
- `end-pool`: End an active pool
- `add-rewards`: Add SUI rewards to a pool
- `pay-sui`: Send SUI to recipients
- `pool-info`: Get pool information
- `full-flow`: Execute complete flow (create, start, add rewards)
