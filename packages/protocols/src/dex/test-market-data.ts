import { ethers } from 'ethers';
import { MarketDataService, MarketDataConfig } from './market-data';
import { Token } from '../tokens/types';
import { TOP_TOKENS, USDC } from '../tokens/index';

// Define tokens
const TOP_TOKENS: Token[] = [
  {
    symbol: 'ETH',
    address: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2', // WETH
    decimals: 18,
    chainlinkFeed: '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419'
  },
  {
    symbol: 'BTC',
    address: '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599', // WBTC
    decimals: 8,
    chainlinkFeed: '0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c'
  },
  {
    symbol: 'LINK',
    address: '0x514910771AF9Ca656af840dff83E8264EcF986CA',
    decimals: 18,
    chainlinkFeed: '0x2c1d072e8f67ecc50ac3b96108f983b5d0e450bf'
  },
  {
    symbol: 'UNI',
    address: '0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984',
    decimals: 18,
    chainlinkFeed: '0x553303d460EE0afB37EdFf9bE42922D8FF63220e'
  },
  {
    symbol: 'MATIC',
    address: '0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0',
    decimals: 18,
    chainlinkFeed: '0x7bAC85A8a13A4BcD8abb3eB7d6b4d632c5a57676'
  },
  {
    symbol: 'SOL',
    address: '0xD31a59c85aE9D8edeFeC411D448f90841571b89C',
    decimals: 9,
    chainlinkFeed: '0x4ffC43a60e009B55185A93d1B8E91e6D2B6c7B2E'
  },
  {
    symbol: 'XRP',
    address: '0x1D2F0da169ceB9fC7B3144628dB156f3F6c60dBE',
    decimals: 6,
    chainlinkFeed: '0xc3E76f41CAbA4aB38F00c7255d4df663DA02A024'
  },
  {
    symbol: 'ADA',
    address: '0x3EE2200Efb3400fAbB9AacF31297cBdD1d435D47',
    decimals: 6,
    chainlinkFeed: '0xAE48c91dF1fE419994FFDa27da09D5aC69c30f55'
  },
  {
    symbol: 'AVAX',
    address: '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7',
    decimals: 18,
    chainlinkFeed: '0xFF3EEb22A5a3D59A5c47B23da81eF19464B8b886'
  },
  {
    symbol: 'DOGE',
    address: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2', // Using WETH as placeholder
    decimals: 18,
    chainlinkFeed: '0x2465CefD3b488BE410b941b1d4b2767083e2AB95'
  }
];

const USDC: Token = {
  symbol: 'USDC',
  address: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
  decimals: 6,
  chainlinkFeed: '0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6'
};

async function testMarketData() {
  // Initialize provider
  const provider = new ethers.JsonRpcProvider('https://eth.llamarpc.com');
  
  // Wait for provider to be ready
  let retries = 5;
  while (retries > 0) {
    try {
      await provider.getNetwork();
      break;
    } catch (error) {
      console.log('Waiting for provider...');
      await new Promise(resolve => setTimeout(resolve, 1000));
      retries--;
    }
  }

  if (retries === 0) {
    throw new Error('Provider not ready');
  }

  const marketDataConfig: MarketDataConfig = {
    chainlinkFeeds: {
      [TOP_TOKENS[0].address]: '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419', // ETH/USD
      [TOP_TOKENS[1].address]: '0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c', // BTC/USD
      [TOP_TOKENS[2].address]: '0x2c1D072e8f67ECc50Ac3B96108F983B5d0E450bF', // LINK/USD
      [TOP_TOKENS[3].address]: '0x553303d460EE0afB37EdFf9bE42922D8FF63220e', // UNI/USD
      [TOP_TOKENS[4].address]: '0x7bAC85A8a13A4BcD8abb3eB7d6b4d632c5a57676', // MATIC/USD
      [TOP_TOKENS[5].address]: '0x4ffC43a60e009B55185A93d1B8E91e6D2B6c7B2e', // SOL/USD
      [TOP_TOKENS[6].address]: '0xc3E76f41CAbA4aB38F00c7255d4df663DA02A024', // XRP/USD
      [TOP_TOKENS[7].address]: '0xAE48c91dF1fE419994FFDa27da09D5aC69c30f55', // ADA/USD
      [TOP_TOKENS[8].address]: '0xFF3EEb22B5E3dE6e705b44749C2559d704923FD7', // AVAX/USD
      [TOP_TOKENS[9].address]: '0x2465CefD3b488BE410b941b1d4b2767083e2AB95', // DOGE/USD
    },
    updateInterval: 60000,
    minConfidence: 0.8,
    coingeckoApiKey: process.env.COINGECKO_API_KEY,
    defillamaApiKey: process.env.DEFILLAMA_API_KEY,
  };

  // Configure market data service
  const marketDataService = new MarketDataService(provider, marketDataConfig);

  // Test market data for each token
  for (const token of TOP_TOKENS) {
    console.log(`\nFetching market data for ${token.symbol}...`);
    try {
      const data = await marketDataService.getMarketData(token, USDC);
      console.log('Market Data:', {
        price: data.price,
        source: data.source,
        confidence: data.confidence,
        volume24h: data.volume24h,
        liquidity: data.liquidity,
        timestamp: new Date(data.timestamp).toLocaleString()
      });
    } catch (error) {
      console.error(`Error fetching market data for ${token.symbol}:`, error);
    }
  }
}

testMarketData().catch(console.error); 