import { ethers } from 'ethers';
import { ETHEREUM_CONFIG } from './chains/config';

async function testConnection() {
  try {
    console.log('Testing Ethereum connection...');
    
    // Create provider with Alchemy
    const provider = new ethers.JsonRpcProvider(ETHEREUM_CONFIG.rpcUrl);
    
    // Test basic connection
    const blockNumber = await provider.getBlockNumber();
    console.log('Current block number:', blockNumber);
    
    // Test gas price
    const gasPrice = await provider.getFeeData();
    console.log('Current gas price:', ethers.formatUnits(gasPrice.gasPrice || 0, 'gwei'), 'gwei');
    
    // Test network
    const network = await provider.getNetwork();
    console.log('Connected to network:', network.name);
    
    // Test some recent blocks
    const recentBlocks = await Promise.all([
      provider.getBlock(blockNumber - 1),
      provider.getBlock(blockNumber - 2),
      provider.getBlock(blockNumber - 3)
    ]);
    
    console.log('\nRecent blocks:');
    recentBlocks.forEach((block, index) => {
      console.log(`Block ${blockNumber - (index + 1)}:`, {
        timestamp: new Date(Number(block?.timestamp) * 1000).toISOString(),
        transactions: block?.transactions.length,
        gasUsed: block?.gasUsed.toString(),
      });
    });
    
    console.log('\nConnection test successful!');
    
  } catch (error) {
    console.error('Connection test failed:', error);
    process.exit(1);
  }
}

// Run the test
testConnection().catch((error) => {
  console.error('Unhandled error:', error);
  process.exit(1);
}); 