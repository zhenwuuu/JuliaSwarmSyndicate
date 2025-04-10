import { WormholeBridge, loadConfig } from '../src';
import { ethers } from 'ethers';
import dotenv from 'dotenv';

dotenv.config();

async function main() {
  console.log('Testing Wormhole Bridge Integration');
  console.log('==================================');
  
  // Load configuration
  const config = loadConfig();
  
  // Initialize Wormhole Bridge
  const wormholeBridge = new WormholeBridge(config);
  
  // Source and target chains
  const sourceChain = 'ethereum';
  const targetChain = 'solana';
  
  // Token to bridge (USDC on Ethereum)
  const token = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48';
  
  // Amount to bridge (1 USDC with 6 decimals)
  const amount = ethers.parseUnits('1.0', 6);
  
  // Recipient address on Solana
  const recipient = process.env.SOLANA_RECIPIENT_ADDRESS || '';
  
  if (!recipient) {
    console.error('Please set SOLANA_RECIPIENT_ADDRESS in .env file');
    process.exit(1);
  }
  
  console.log(`Bridging ${ethers.formatUnits(amount, 6)} USDC from ${sourceChain} to ${targetChain}`);
  console.log(`Recipient: ${recipient}`);
  
  try {
    // Bridge tokens
    const result = await wormholeBridge.bridgeTokens({
      sourceChain,
      targetChain,
      token,
      amount,
      recipient
    });
    
    console.log('Bridge result:', result);
    
    if (result.status === 'pending' && result.sequence && result.emitterAddress) {
      console.log('Waiting for VAA...');
      
      // Wait for VAA (in production, this would be a separate process)
      setTimeout(async () => {
        try {
          const vaa = await wormholeBridge.getVAA(
            sourceChain,
            result.emitterAddress!,
            result.sequence!
          );
          
          console.log('VAA received:', vaa);
          
          // Redeem tokens on target chain
          const redeemResult = await wormholeBridge.redeemTokens(vaa, targetChain);
          
          console.log('Redeem result:', redeemResult);
          
          if (redeemResult.status === 'completed') {
            console.log('Bridge transfer completed successfully!');
          } else {
            console.error('Bridge transfer failed:', redeemResult.message);
          }
        } catch (error) {
          console.error('Error getting VAA or redeeming tokens:', error);
        }
      }, 60000); // Wait 1 minute for VAA
    }
  } catch (error) {
    console.error('Error bridging tokens:', error);
  }
}

main().catch(console.error);
