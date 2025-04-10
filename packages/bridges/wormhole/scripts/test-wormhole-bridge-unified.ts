import { WormholeBridge, loadConfig } from '../src/wormhole-bridge-unified';
import { ethers } from 'ethers';
import dotenv from 'dotenv';
import path from 'path';

// Load environment variables
dotenv.config({ path: path.resolve(__dirname, '../.env') });

async function testWormholeBridge() {
  console.log('Testing Wormhole Bridge...');
  
  // Load configuration
  const config = loadConfig();
  
  // Initialize Wormhole Bridge
  const wormholeBridge = new WormholeBridge(config);
  
  try {
    // Test 1: Get available chains
    console.log('\n--- Test 1: Get Available Chains ---');
    const chains = await wormholeBridge.getAvailableChains();
    console.log('Available chains:', chains);
    
    if (chains.length === 0) {
      console.error('No chains available. Check your configuration.');
      return;
    }
    
    // Test 2: Get available tokens for a chain
    console.log('\n--- Test 2: Get Available Tokens ---');
    const sourceChain = chains[0]; // Use the first available chain
    const tokens = await wormholeBridge.getAvailableTokens(sourceChain);
    console.log(`Available tokens on ${sourceChain}:`, tokens);
    
    // Test 3: Get wrapped asset info
    console.log('\n--- Test 3: Get Wrapped Asset Info ---');
    if (chains.includes('ethereum') && chains.includes('solana')) {
      // USDC on Ethereum
      const usdcAddress = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48';
      const wrappedInfo = await wormholeBridge.getWrappedAssetInfo('ethereum', usdcAddress, 'solana');
      console.log('Wrapped USDC info on Solana:', wrappedInfo);
    } else {
      console.log('Skipping wrapped asset test - need both Ethereum and Solana chains');
    }
    
    // Test 4: Bridge tokens (simulation only)
    console.log('\n--- Test 4: Bridge Tokens Simulation ---');
    
    // Check if we have the necessary chains and private keys
    if (!process.env.ETHEREUM_PRIVATE_KEY) {
      console.log('Skipping bridge test - ETHEREUM_PRIVATE_KEY not set');
      return;
    }
    
    // Define bridge parameters
    const sourceChain = 'ethereum';
    const targetChain = 'solana';
    const token = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'; // USDC on Ethereum
    const amount = ethers.parseUnits('0.1', 6); // 0.1 USDC (6 decimals)
    const recipient = process.env.SOLANA_RECIPIENT_ADDRESS || ''; // Solana recipient address
    
    if (!recipient) {
      console.log('Skipping bridge test - SOLANA_RECIPIENT_ADDRESS not set');
      return;
    }
    
    console.log(`Simulating bridge of ${ethers.formatUnits(amount, 6)} USDC from ${sourceChain} to ${targetChain}`);
    console.log(`Recipient: ${recipient}`);
    
    // In a real test, we would call:
    // const result = await wormholeBridge.bridgeTokens({
    //   sourceChain,
    //   targetChain,
    //   token,
    //   amount,
    //   recipient,
    //   privateKey: process.env.ETHEREUM_PRIVATE_KEY
    // });
    // console.log('Bridge result:', result);
    
    console.log('Simulation complete - not executing actual bridge transaction');
    
  } catch (error) {
    console.error('Error testing Wormhole Bridge:', error);
  }
}

testWormholeBridge().catch(console.error);
