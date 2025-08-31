import { PoolManager, PoolConfig, RewardConfig } from './poolManager';
import { Command } from 'commander';
import * as dotenv from 'dotenv';

dotenv.config();

const program = new Command();

program
  .name('mer3-pool-cli')
  .description('CLI for managing Mer3 pools and rewards')
  .version('1.0.0');

program
  .command('create-pool')
  .description('Create a new pool')
  .option('-n, --network <network>', 'Network to use (mainnet, testnet, devnet)', 'testnet')
  .option('--name <name>', 'Pool name', 'Empty Element Pool 2')
  .option('--description <description>', 'Pool description', 'Empty elements 2')
  .option('--start-time <startTime>', 'Start time in milliseconds', '1749379144000')
  .option('--end-time <endTime>', 'End time in milliseconds', '1755247014000')
  .option('--image-url <imageUrl>', 'Image URL', 'https://app.merg3.xyz/images/sui.svg')
  .action(async (options) => {
    try {
      const manager = new PoolManager(options.network);
      
      const poolConfig: PoolConfig = {
        packageId: process.env.PACKAGE_ID || '0x1f246b075220ec5f49435224ca862fa60c254b9c544c8961764b1bfe77bf8728',
        module: 'pool_rewards',
        adminCap: process.env.ADMIN_CAP || '0x417e3cdaaeb94175612918c7a8078453dcdf654440bbb0098e1764f5917bb848',
        poolState: process.env.POOL_STATE || '0x41fce698233d9163d93754e76c8dc1c6c7c4b04231491f632aead72b5c0d2e01',
        name: options.name,
        description: options.description,
        metadata: [],
        startTime: parseInt(options.startTime),
        imageUrl: options.imageUrl,
        endTime: parseInt(options.endTime),
        clock: '0x6',
      };
      
      const result = await manager.createPool(poolConfig);
      console.log('✅ Pool created successfully!');
      console.log('Pool ID/Transaction:', result);
    } catch (error) {
      console.error('❌ Error creating pool:', error);
      process.exit(1);
    }
  });

program
  .command('start-pool')
  .description('Start an existing pool')
  .option('-n, --network <network>', 'Network to use', 'testnet')
  .requiredOption('--pool-id <poolId>', 'Pool ID to start')
  .action(async (options) => {
    try {
      const manager = new PoolManager(options.network);
      
      const result = await manager.startPool(
        process.env.PACKAGE_ID || '0x1f246b075220ec5f49435224ca862fa60c254b9c544c8961764b1bfe77bf8728',
        'pool_rewards',
        process.env.ADMIN_CAP || '0x417e3cdaaeb94175612918c7a8078453dcdf654440bbb0098e1764f5917bb848',
        process.env.POOL_STATE || '0x41fce698233d9163d93754e76c8dc1c6c7c4b04231491f632aead72b5c0d2e01',
        options.poolId,
        '0x6'
      );
      
      console.log('✅ Pool started successfully!');
      console.log('Transaction:', result);
    } catch (error) {
      console.error('❌ Error starting pool:', error);
      process.exit(1);
    }
  });

program
  .command('end-pool')
  .description('End an existing pool')
  .option('-n, --network <network>', 'Network to use', 'testnet')
  .requiredOption('--pool-id <poolId>', 'Pool ID to end')
  .action(async (options) => {
    try {
      const manager = new PoolManager(options.network);
      
      const result = await manager.endPool(
        process.env.END_PACKAGE_ID || '0xbdf701160b02d873841fc5ed20484dc2592de627422b3f50f0a244455edda20a',
        'pool_rewards',
        process.env.END_ADMIN_CAP || '0x74a21ae4b05105d003d35b51faea9905abed2668074b75862156fbf6349fcb74',
        process.env.END_POOL_STATE || '0xcd698cd0dba0f42fbbddf94cb3c578a7512aaf96d3d151264ab2879f120dd2ff',
        options.poolId,
        '0x6'
      );
      
      console.log('✅ Pool ended successfully!');
      console.log('Transaction:', result);
    } catch (error) {
      console.error('❌ Error ending pool:', error);
      process.exit(1);
    }
  });

program
  .command('add-rewards')
  .description('Add SUI rewards to a pool')
  .option('-n, --network <network>', 'Network to use', 'testnet')
  .requiredOption('--pool-id <poolId>', 'Pool ID to add rewards to')
  .requiredOption('--coin-id <coinId>', 'Coin object ID to use for rewards')
  .action(async (options) => {
    try {
      const manager = new PoolManager(options.network);
      
      const rewardConfig: RewardConfig = {
        packageId: process.env.REWARD_PACKAGE_ID || '0x417ec8eec0c63303256299861a14804ff0a5bedf5ac1cbaf3c73eae0d0118f1b',
        module: 'pool_rewards',
        adminCap: process.env.ADMIN_CAP || '0x417e3cdaaeb94175612918c7a8078453dcdf654440bbb0098e1764f5917bb848',
        poolState: process.env.POOL_STATE || '0x41fce698233d9163d93754e76c8dc1c6c7c4b04231491f632aead72b5c0d2e01',
        poolId: options.poolId,
        coinObjectId: options.coinId,
      };
      
      const result = await manager.addSuiRewards(rewardConfig);
      console.log('✅ Rewards added successfully!');
      console.log('Transaction:', result);
    } catch (error) {
      console.error('❌ Error adding rewards:', error);
      process.exit(1);
    }
  });

program
  .command('pay-sui')
  .description('Send SUI to recipients')
  .option('-n, --network <network>', 'Network to use', 'testnet')
  .requiredOption('--coin <coin>', 'Input coin object ID')
  .requiredOption('--amount <amount>', 'Amount to send (in MIST)')
  .requiredOption('--recipient <recipient>', 'Recipient address')
  .action(async (options) => {
    try {
      const manager = new PoolManager(options.network);
      
      const result = await manager.paySui(
        [options.coin],
        [parseInt(options.amount)],
        [options.recipient]
      );
      
      console.log('✅ Payment sent successfully!');
      console.log('Transaction:', result);
    } catch (error) {
      console.error('❌ Error sending payment:', error);
      process.exit(1);
    }
  });

program
  .command('pool-info')
  .description('Get information about a pool')
  .option('-n, --network <network>', 'Network to use', 'testnet')
  .requiredOption('--pool-id <poolId>', 'Pool ID to query')
  .action(async (options) => {
    try {
      const manager = new PoolManager(options.network);
      const info = await manager.getPoolInfo(options.poolId);
      
      console.log('Pool Information:');
      console.log(JSON.stringify(info, null, 2));
    } catch (error) {
      console.error('❌ Error fetching pool info:', error);
      process.exit(1);
    }
  });

program
  .command('full-flow')
  .description('Execute the complete flow: create pool, start it, and add rewards')
  .option('-n, --network <network>', 'Network to use', 'testnet')
  .option('--name <name>', 'Pool name', 'Test Pool')
  .option('--coin-id <coinId>', 'Coin object ID for rewards')
  .action(async (options) => {
    try {
      const manager = new PoolManager(options.network);
      
      console.log('📝 Step 1: Creating pool...');
      const poolConfig: PoolConfig = {
        packageId: process.env.PACKAGE_ID || '0x1f246b075220ec5f49435224ca862fa60c254b9c544c8961764b1bfe77bf8728',
        module: 'pool_rewards',
        adminCap: process.env.ADMIN_CAP || '0x417e3cdaaeb94175612918c7a8078453dcdf654440bbb0098e1764f5917bb848',
        poolState: process.env.POOL_STATE || '0x41fce698233d9163d93754e76c8dc1c6c7c4b04231491f632aead72b5c0d2e01',
        name: options.name,
        description: `${options.name} description`,
        metadata: [],
        startTime: Date.now(),
        imageUrl: 'https://app.merg3.xyz/images/sui.svg',
        endTime: Date.now() + (30 * 24 * 60 * 60 * 1000),
        clock: '0x6',
      };
      
      const poolId = await manager.createPool(poolConfig);
      console.log('✅ Pool created with ID:', poolId);
      
      console.log('⏱️ Step 2: Starting pool...');
      await manager.startPool(
        poolConfig.packageId,
        poolConfig.module,
        poolConfig.adminCap,
        poolConfig.poolState,
        poolId,
        poolConfig.clock
      );
      console.log('✅ Pool started');
      
      if (options.coinId) {
        console.log('💰 Step 3: Adding rewards...');
        const rewardConfig: RewardConfig = {
          packageId: process.env.REWARD_PACKAGE_ID || '0x417ec8eec0c63303256299861a14804ff0a5bedf5ac1cbaf3c73eae0d0118f1b',
          module: 'pool_rewards',
          adminCap: poolConfig.adminCap,
          poolState: poolConfig.poolState,
          poolId: poolId,
          coinObjectId: options.coinId,
        };
        
        await manager.addSuiRewards(rewardConfig);
        console.log('✅ Rewards added');
      }
      
      console.log('🎉 Full flow completed successfully!');
    } catch (error) {
      console.error('❌ Error in full flow:', error);
      process.exit(1);
    }
  });

program.parse();