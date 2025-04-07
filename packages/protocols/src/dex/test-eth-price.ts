import { ethers } from 'ethers';
import { MarketDataService, MarketDataConfig } from './market-data';
import { Token } from '../tokens/types';

console.log('Script started...');

// ETH token
const ETH: Token = {
  address: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2', // WETH
  symbol: 'ETH',
  decimals: 18,
  name: 'Ethereum',
  chainId: 1
};

// USDC token for price comparison
const USDC: Token = {
  address: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
  symbol: 'USDC',
  decimals: 6,
  name: 'USD Coin',
  chainId: 1
};

async function testEthPrice() {
  try {
    console.log('Initializing provider...');
    // Initialize provider with Cloudflare's public Ethereum gateway
    const provider = new ethers.JsonRpcProvider('https://cloudflare-eth.com');

    console.log('Configuring market data service...');
    // Configure market data service
    const config: MarketDataConfig = {
      chainlinkFeeds: {
        '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2': '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419', // ETH/USD
      },
      coingeckoApiKey: 'demo',
      updateInterval: 30000,
      minConfidence: 0.8
    };

    console.log('Creating MarketDataService instance...');
    const marketData = new MarketDataService(provider, config);

    console.log('Fetching ETH price...');
    try {
      const data = await marketData.getMarketData(ETH, USDC);
      
      console.log(`\nETH Price Data:`);
      console.log('------------------------');
      console.log(`Price: $${parseFloat(data.price).toFixed(2)}`);
      console.log(`Source: ${data.source}`);
      console.log(`Confidence: ${(data.confidence * 100).toFixed(1)}%`);
      console.log(`24h Volume: $${parseFloat(data.volume24h).toLocaleString()}`);
      console.log(`Liquidity: $${parseFloat(data.liquidity).toLocaleString()}`);
      console.log(`Last Updated: ${new Date(data.timestamp).toLocaleString()}`);
    } catch (error) {
      console.error('Error details:', error);
      if (error instanceof Error) {
        console.error('Failed to fetch ETH price:', error.message);
      } else {
        console.error('Failed to fetch ETH price:', String(error));
      }
    }
  } catch (error) {
    console.error('Test failed with error:', error);
    process.exit(1);
  }
}

console.log('Running test...');
// Run the test
testEthPrice().catch((error: Error) => {
  console.error('Unhandled error:', error);
  process.exit(1);
}); 