import { ethers } from 'ethers';
import { Connection } from '@solana/web3.js';
import { ETHEREUM_CONFIG, BASE_CONFIG, SOLANA_CONFIG } from './chains/config';

async function testEthereumConnection() {
  try {
    console.log('\nTesting Ethereum connection...');
    const provider = new ethers.JsonRpcProvider(ETHEREUM_CONFIG.rpcUrl);
    
    const blockNumber = await provider.getBlockNumber();
    console.log('Current block number:', blockNumber);
    
    const gasPrice = await provider.getFeeData();
    console.log('Current gas price:', ethers.formatUnits(gasPrice.gasPrice || 0, 'gwei'), 'gwei');
    
    const network = await provider.getNetwork();
    console.log('Connected to network:', network.name);
    
    return true;
  } catch (error) {
    console.error('Ethereum connection failed:', error);
    return false;
  }
}

async function testBaseConnection() {
  try {
    console.log('\nTesting Base connection...');
    const provider = new ethers.JsonRpcProvider(BASE_CONFIG.rpcUrl);
    
    const blockNumber = await provider.getBlockNumber();
    console.log('Current block number:', blockNumber);
    
    const gasPrice = await provider.getFeeData();
    console.log('Current gas price:', ethers.formatUnits(gasPrice.gasPrice || 0, 'gwei'), 'gwei');
    
    const network = await provider.getNetwork();
    console.log('Connected to network:', network.name);
    
    return true;
  } catch (error) {
    console.error('Base connection failed:', error);
    return false;
  }
}

async function testSolanaConnection() {
  try {
    console.log('\nTesting Solana connection...');
    const connection = new Connection(SOLANA_CONFIG.rpcUrl, 'confirmed');
    
    const blockHeight = await connection.getBlockHeight();
    console.log('Current block height:', blockHeight);
    
    const slot = await connection.getSlot();
    console.log('Current slot:', slot);
    
    const recentBlockhash = await connection.getLatestBlockhash();
    console.log('Recent blockhash:', recentBlockhash.blockhash);
    
    return true;
  } catch (error) {
    console.error('Solana connection failed:', error);
    return false;
  }
}

async function main() {
  console.log('Starting comprehensive connection tests...\n');
  
  const results = {
    ethereum: await testEthereumConnection(),
    base: await testBaseConnection(),
    solana: await testSolanaConnection()
  };
  
  console.log('\nConnection Test Results:');
  console.log('------------------------');
  console.log('Ethereum:', results.ethereum ? '✅ Connected' : '❌ Failed');
  console.log('Base:', results.base ? '✅ Connected' : '❌ Failed');
  console.log('Solana:', results.solana ? '✅ Connected' : '❌ Failed');
  
  const allConnected = Object.values(results).every(result => result);
  console.log('\nOverall Status:', allConnected ? '✅ All chains connected' : '❌ Some chains failed');
  
  if (!allConnected) {
    process.exit(1);
  }
}

// Run the tests
main().catch((error) => {
  console.error('Unhandled error:', error);
  process.exit(1);
}); 