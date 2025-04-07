import { ethers } from 'ethers';
import { Token } from '../tokens/types';

export interface MarketData {
  price: string;
  volume24h: string;
  liquidity: string;
  timestamp: number;
  source: string;
  confidence: number;
  marketCap?: string;
  priceChange24h?: string;
}

export interface MarketDataConfig {
  chainlinkFeeds?: Record<string, string>;
  coingeckoApiKey?: string;
  updateInterval?: number;
  minConfidence?: number;
  maxStaleTime?: number;
  defillamaApiKey?: string;
}

export class MarketDataService {
  private provider: ethers.Provider;
  private config: MarketDataConfig;
  private cache: Map<string, MarketData>;
  private chainlinkABI = [
    'function decimals() external view returns (uint8)',
    'function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)'
  ];
  private uniswapV3PoolABI = [
    'function slot0() external view returns (uint160 sqrtPriceX96, int24 tick, uint16 observationIndex, uint16 observationCardinality, uint16 observationCardinalityNext, uint8 feeProtocol, bool unlocked)',
    'function liquidity() external view returns (uint128)',
    'function token0() external view returns (address)',
    'function token1() external view returns (address)'
  ];
  private uniswapV3FactoryAddress = '0x1F98431c8aD98523631AE4a59f267346ea31F984';
  private uniswapV3FactoryABI = [
    'function getPool(address tokenA, address tokenB, uint24 fee) external view returns (address pool)'
  ];
  private priceCache: Map<string, { price: string; timestamp: number }>;
  private mockPrices: Record<string, number>;
  private mockVolumes: Record<string, number>;

  constructor(provider: ethers.Provider, config: MarketDataConfig = {}) {
    this.provider = provider;
    this.config = {
      updateInterval: 60000, // 1 minute
      minConfidence: 0.95,
      maxStaleTime: 3600, // 1 hour
      ...config,
    };
    this.cache = new Map();
    this.priceCache = new Map();
    
    // Initialize mock data for testing
    this.mockPrices = {
      'SOL': 25.75,
      'ETH': 1832.20,
      'BTC': 26543.80,
      'AVAX': 12.45,
      'OP': 3.05,
      'ARB': 0.85,
    };
    
    this.mockVolumes = {
      'SOL': 1500000,
      'ETH': 5000000,
      'BTC': 12000000,
      'AVAX': 800000,
      'OP': 450000,
      'ARB': 350000,
    };
  }

  async initialize(): Promise<void> {
    console.log('Market data service initialized');
    // In a real implementation, would connect to various data sources
  }

  private async getTokenDecimals(tokenAddress: string): Promise<number> {
    const tokenABI = ['function decimals() external view returns (uint8)'];
    const token = new ethers.Contract(tokenAddress, tokenABI, this.provider);
    return token.decimals();
  }

  private async getUniswapV3Pool(tokenA: Token, tokenB: Token): Promise<string> {
    const factory = new ethers.Contract(
      this.uniswapV3FactoryAddress,
      this.uniswapV3FactoryABI,
      this.provider
    );

    // Try different fee tiers
    const feeTiers = [100, 500, 3000, 10000];
    for (const fee of feeTiers) {
      const pool = await factory.getPool(tokenA.address, tokenB.address, fee);
      if (pool !== ethers.ZeroAddress) {
        return pool;
      }
    }

    return ethers.ZeroAddress;
  }

  private calculatePrice(
    price: bigint,
    decimals: number,
    baseDecimals: number = 6
  ): string {
    const priceInDecimals = Number(price) / Math.pow(10, decimals);
    const baseInDecimals = Math.pow(10, baseDecimals);
    return (priceInDecimals * baseInDecimals).toString();
  }

  async getPrice(token: Token, quoteToken?: Token): Promise<string> {
    if (this.mockPrices[token.symbol]) {
      // Add some random noise to the price (±5%)
      const basePrice = this.mockPrices[token.symbol];
      const noise = (Math.random() - 0.5) * 0.1 * basePrice;
      const price = basePrice + noise;
      return price.toFixed(2);
    }
    
    // For unknown tokens, return a random price between 0.1 and 100
    return (Math.random() * 99.9 + 0.1).toFixed(2);
  }

  async getVolume(token: Token): Promise<string> {
    if (this.mockVolumes[token.symbol]) {
      // Add some random noise to the volume (±20%)
      const baseVolume = this.mockVolumes[token.symbol];
      const noise = (Math.random() - 0.5) * 0.4 * baseVolume;
      const volume = baseVolume + noise;
      return volume.toFixed(0);
    }
    
    // For unknown tokens, return a random volume between 10,000 and 1,000,000
    return (Math.random() * 990000 + 10000).toFixed(0);
  }

  async getLiquidity(tokenAddress: string): Promise<string> {
    // Generate a reasonable liquidity value (proportional to volume)
    const token = { symbol: this.getSymbolFromAddress(tokenAddress) } as Token;
    const volumeStr = await this.getVolume(token);
    const volume = parseFloat(volumeStr);
    
    // Liquidity is typically 5-10x the daily volume
    const multiplier = 5 + Math.random() * 5;
    return (volume * multiplier).toFixed(0);
  }

  async getMarketData(token: Token, quoteToken?: Token): Promise<any> {
    const cacheKey = this.getCacheKey(token, quoteToken);
    const cachedData = this.priceCache.get(cacheKey);
    
    // Check if we have fresh cached data
    if (cachedData && (Date.now() - cachedData.timestamp) < this.config.updateInterval!) {
      return {
        price: cachedData.price,
        confidence: 0.98,
        timestamp: cachedData.timestamp,
      };
    }
    
    // Get fresh price
    const price = await this.getPrice(token, quoteToken);
    const volume = await this.getVolume(token);
    const timestamp = Date.now();
    
    // Cache the data
    this.priceCache.set(cacheKey, { price, timestamp });
    
    // Generate some mock metrics
    const priceChange24h = ((Math.random() - 0.4) * 10).toFixed(2); // Slightly biased towards positive
    const volumeChange24h = ((Math.random() - 0.3) * 20).toFixed(2); // Slightly biased towards positive
    
    return {
      price,
      volume,
      priceChange24h,
      volumeChange24h,
      confidence: 0.98,
      timestamp,
    };
  }

  async getTopTokens(chainId: string): Promise<Token[]> {
    // Return mock top tokens based on chain
    const tokens: Token[] = [];
    
    switch (chainId) {
      case 'solana':
        tokens.push(
          { symbol: 'SOL', name: 'Solana', address: 'sol_address', decimals: 9, chainId: 1 },
          { symbol: 'JUP', name: 'Jupiter', address: 'jup_address', decimals: 6, chainId: 1 },
          { symbol: 'RAY', name: 'Raydium', address: 'ray_address', decimals: 6, chainId: 1 },
        );
        break;
      case 'ethereum':
        tokens.push(
          { symbol: 'ETH', name: 'Ethereum', address: 'eth_address', decimals: 18, chainId: 1 },
          { symbol: 'UNI', name: 'Uniswap', address: 'uni_address', decimals: 18, chainId: 1 },
          { symbol: 'LINK', name: 'Chainlink', address: 'link_address', decimals: 18, chainId: 1 },
        );
        break;
      case 'base':
        tokens.push(
          { symbol: 'ETH', name: 'Ethereum', address: 'eth_address', decimals: 18, chainId: 8453 },
          { symbol: 'OP', name: 'Optimism', address: 'op_address', decimals: 18, chainId: 8453 },
          { symbol: 'ARB', name: 'Arbitrum', address: 'arb_address', decimals: 18, chainId: 8453 },
        );
        break;
      default:
        tokens.push(
          { symbol: 'BTC', name: 'Bitcoin', address: 'btc_address', decimals: 8, chainId: 1 },
          { symbol: 'ETH', name: 'Ethereum', address: 'eth_address', decimals: 18, chainId: 1 },
          { symbol: 'SOL', name: 'Solana', address: 'sol_address', decimals: 9, chainId: 1 },
        );
    }
    
    return tokens;
  }

  private getCacheKey(token: Token, quoteToken?: Token): string {
    if (quoteToken) {
      return `${token.symbol}_${quoteToken.symbol}`;
    }
    return token.symbol;
  }

  private getSymbolFromAddress(address: string): string {
    // In a real implementation, this would lookup the token from address
    // For mock implementation, we'll return a random top token
    const symbols = ['SOL', 'ETH', 'BTC', 'AVAX', 'OP', 'ARB'];
    
    // Use a deterministic approach based on the address to always return the same symbol
    const sum = address.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0);
    return symbols[sum % symbols.length];
  }
} 