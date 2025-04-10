import { ethers } from 'ethers';
import { ChainlinkPriceFeed } from '../../core/src/dex/chainlink';
import { Connection } from '@solana/web3.js';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

// Define tokens for testing
const SOL_TOKEN = {
  address: 'So11111111111111111111111111111111111111112',
  symbol: 'SOL',
  decimals: 9,
  name: 'Solana',
  chainId: 1
};

const ETH_TOKEN = {
  address: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2', // WETH
  symbol: 'ETH',
  decimals: 18,
  name: 'Ethereum',
  chainId: 1
};

const USDC_TOKEN = {
  address: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v', // Solana USDC
  symbol: 'USDC',
  decimals: 6,
  name: 'USD Coin',
  chainId: 1
};

async function testChainlinkIntegration() {
  console.log('Testing Chainlink Integration');
  console.log('============================');

  try {
    // Initialize Solana connection
    const rpcUrl = process.env.SOLANA_RPC_URL || 'https://api.mainnet-beta.solana.com';
    console.log(`Connecting to Solana RPC: ${rpcUrl}`);
    const connection = new Connection(rpcUrl, 'confirmed');

    // Initialize Chainlink price feed
    console.log('Initializing Chainlink price feed...');
    const priceFeed = ChainlinkPriceFeed.getInstance(connection);

    // Add feed addresses
    console.log('Adding feed addresses...');
    
    // SOL/USD feed on Solana
    priceFeed.addFeed(
      SOL_TOKEN.address,
      process.env.CHAINLINK_SOL_USD_FEED || '2TfB33aLaneQb5TNVwyDz3jSZXS6jdW2ARw1Dgf84XCG'
    );
    
    // USDC/USD feed on Solana
    priceFeed.addFeed(
      USDC_TOKEN.address,
      process.env.CHAINLINK_USDC_USD_FEED || 'JBu1AL4obBcCMqKBBxhpWCNUt136ijcuMZLFvTP7iWdB'
    );

    // Get SOL/USD price
    console.log('\nFetching SOL/USD price...');
    try {
      const solPrice = await priceFeed.getPrice(SOL_TOKEN);
      console.log(`SOL/USD Price: $${solPrice.price.toFixed(2)}`);
      console.log(`Timestamp: ${new Date(solPrice.timestamp).toLocaleString()}`);
      console.log(`Round ID: ${solPrice.roundId}`);
      console.log(`Confidence: ${(solPrice.confidence * 100).toFixed(1)}%`);
    } catch (error) {
      console.error('Error fetching SOL/USD price:', error);
    }

    // Get USDC/USD price
    console.log('\nFetching USDC/USD price...');
    try {
      const usdcPrice = await priceFeed.getPrice(USDC_TOKEN);
      console.log(`USDC/USD Price: $${usdcPrice.price.toFixed(2)}`);
      console.log(`Timestamp: ${new Date(usdcPrice.timestamp).toLocaleString()}`);
      console.log(`Round ID: ${usdcPrice.roundId}`);
      console.log(`Confidence: ${(usdcPrice.confidence * 100).toFixed(1)}%`);
    } catch (error) {
      console.error('Error fetching USDC/USD price:', error);
    }

    // Get SOL/USDC price
    console.log('\nCalculating SOL/USDC price...');
    try {
      const solUsdcPrice = await priceFeed.getPriceBetweenTokens(SOL_TOKEN, USDC_TOKEN);
      console.log(`SOL/USDC Price: ${solUsdcPrice.toFixed(6)} USDC`);
    } catch (error) {
      console.error('Error calculating SOL/USDC price:', error);
    }

    console.log('\nChainlink integration test completed.');
  } catch (error) {
    console.error('Test failed with error:', error);
  }
}

// Run the test
testChainlinkIntegration().catch(console.error);
