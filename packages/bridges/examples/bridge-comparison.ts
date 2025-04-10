import { ethers } from 'ethers';
import { WormholeBridge, loadConfig as loadWormholeConfig } from '../wormhole/src';
import dotenv from 'dotenv';

dotenv.config();

/**
 * This example demonstrates how to use both the relay bridge and the Wormhole bridge
 * for cross-chain token transfers, comparing their features and usage.
 */
async function main() {
  console.log('JuliaOS Bridge Comparison Example');
  console.log('=================================');
  
  // Example parameters
  const sourceChain = 'ethereum';
  const targetChain = 'solana';
  const tokenAddress = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'; // USDC on Ethereum
  const amount = ethers.parseUnits('1.0', 6); // 1 USDC
  const recipient = process.env.SOLANA_RECIPIENT_ADDRESS || '';
  
  if (!recipient) {
    console.error('Please set SOLANA_RECIPIENT_ADDRESS in .env file');
    process.exit(1);
  }
  
  console.log(`\nBridge Parameters:`);
  console.log(`- Source Chain: ${sourceChain}`);
  console.log(`- Target Chain: ${targetChain}`);
  console.log(`- Token: ${tokenAddress} (USDC)`);
  console.log(`- Amount: ${ethers.formatUnits(amount, 6)} USDC`);
  console.log(`- Recipient: ${recipient}`);
  
  // ==========================================
  // Example 1: Using the Wormhole Bridge
  // ==========================================
  console.log('\n1. Using Wormhole Bridge');
  console.log('------------------------');
  
  try {
    // Initialize Wormhole Bridge
    const wormholeConfig = loadWormholeConfig();
    const wormholeBridge = new WormholeBridge(wormholeConfig);
    
    console.log('Wormhole Bridge Features:');
    console.log('- Direct integration with Wormhole protocol');
    console.log('- Support for multiple chains (Ethereum, Solana, BSC, Avalanche, Fantom, Arbitrum, Base)');
    console.log('- Automatic VAA handling');
    console.log('- Token wrapping and unwrapping');
    
    console.log('\nInitiating Wormhole bridge transfer...');
    
    // Bridge tokens using Wormhole
    const wormholeResult = await wormholeBridge.bridgeTokens({
      sourceChain,
      targetChain,
      token: tokenAddress,
      amount,
      recipient
    });
    
    console.log('Wormhole bridge result:', wormholeResult);
    
    if (wormholeResult.status === 'pending' && wormholeResult.sequence && wormholeResult.emitterAddress) {
      console.log('\nWormhole bridge transfer initiated!');
      console.log('In a production environment, you would:');
      console.log('1. Wait for the VAA to be generated');
      console.log('2. Retrieve the VAA using getVAA()');
      console.log('3. Redeem the tokens on the target chain using redeemTokens()');
      
      console.log(`\nSequence: ${wormholeResult.sequence}`);
      console.log(`Emitter Address: ${wormholeResult.emitterAddress}`);
    }
  } catch (error) {
    console.error('Error using Wormhole bridge:', error);
  }
  
  // ==========================================
  // Example 2: Using the Relay Bridge
  // ==========================================
  console.log('\n2. Using Relay Bridge');
  console.log('--------------------');
  
  try {
    // For demonstration purposes, we'll just describe the relay bridge
    // In a real implementation, you would initialize and use the relay bridge
    
    console.log('Relay Bridge Features:');
    console.log('- Custom implementation specific to JuliaOS');
    console.log('- Currently supports Base Sepolia and Solana');
    console.log('- Uses a relay service to monitor events and complete transfers');
    console.log('- Simpler interface but less chain support');
    
    console.log('\nTo use the relay bridge:');
    console.log('1. Initialize the JuliaBridge contract');
    console.log('2. Approve token spending');
    console.log('3. Call bridge() function with token, amount, recipient, and targetChainId');
    console.log('4. The relay service will automatically complete the transfer');
    
    // Code example (not executed)
    console.log('\nCode example:');
    console.log(`
    // Get contracts
    const bridge = await ethers.getContractAt("JuliaBridge", bridgeAddress);
    const token = await ethers.getContractAt("IERC20", tokenAddress);
    
    // Approve token spending
    await token.approve(bridgeAddress, amount);
    
    // Bridge the tokens
    const bridgeTx = await bridge.bridge(
      tokenAddress,
      amount,
      recipient,
      targetChainId
    );
    
    console.log("Transaction sent:", bridgeTx.hash);
    await bridgeTx.wait();
    `);
  } catch (error) {
    console.error('Error in relay bridge example:', error);
  }
  
  // ==========================================
  // Comparison
  // ==========================================
  console.log('\nBridge Comparison:');
  console.log('=================');
  
  console.log('\nWormhole Bridge:');
  console.log('+ Supports multiple chains');
  console.log('+ Direct integration with Wormhole protocol');
  console.log('+ More secure with VAA verification');
  console.log('+ Better for production use');
  console.log('- More complex to use');
  console.log('- Requires manual VAA handling');
  
  console.log('\nRelay Bridge:');
  console.log('+ Simpler interface');
  console.log('+ Automatic completion via relay service');
  console.log('+ Easier to understand and use');
  console.log('- Limited chain support');
  console.log('- Custom implementation');
  console.log('- Relies on centralized relay service');
  
  console.log('\nRecommendation:');
  console.log('- Use Wormhole Bridge for production applications requiring multiple chain support');
  console.log('- Use Relay Bridge for simpler applications or testing');
}

main().catch(console.error);
