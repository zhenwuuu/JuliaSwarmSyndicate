import { Connection, PublicKey } from '@solana/web3.js';
import { Token } from '../types';
import { logger } from '../utils/logger';

interface ChainlinkPriceData {
  price: number;
  timestamp: number;
  roundId: number;
  confidence: number;
}

export class ChainlinkPriceFeed {
  private static instance: ChainlinkPriceFeed;
  private connection: Connection;
  private feeds: Map<string, PublicKey>;
  private cache: Map<string, ChainlinkPriceData>;
  private cacheTimeout: number = 30000; // 30 seconds

  private constructor(connection: Connection) {
    this.connection = connection;
    this.feeds = new Map();
    this.cache = new Map();
  }

  static getInstance(connection: Connection): ChainlinkPriceFeed {
    if (!ChainlinkPriceFeed.instance) {
      ChainlinkPriceFeed.instance = new ChainlinkPriceFeed(connection);
    }
    return ChainlinkPriceFeed.instance;
  }

  addFeed(tokenAddress: string, feedAddress: string): void {
    this.feeds.set(tokenAddress, new PublicKey(feedAddress));
  }

  async getPrice(token: Token): Promise<ChainlinkPriceData> {
    const feedAddress = this.feeds.get(token.address);
    if (!feedAddress) {
      throw new Error(`No Chainlink feed found for token ${token.address}`);
    }

    // Check cache first
    const cachedData = this.cache.get(token.address);
    if (cachedData && Date.now() - cachedData.timestamp < this.cacheTimeout) {
      return cachedData;
    }

    try {
      // In a real implementation, we would:
      // 1. Call the Chainlink feed program
      // 2. Get the latest round data
      // 3. Calculate the price with proper decimals
      // 4. Validate the price confidence
      // 5. Apply circuit breakers if needed

      // For now, return mock data
      const mockData: ChainlinkPriceData = {
        price: 100.50, // Mock SOL/USD price
        timestamp: Date.now(),
        roundId: Math.floor(Math.random() * 1000000),
        confidence: 0.95
      };

      this.cache.set(token.address, mockData);
      return mockData;
    } catch (error) {
      logger.error(`Error fetching Chainlink price for ${token.address}: ${error}`);
      throw error;
    }
  }

  async getPriceBetweenTokens(
    tokenIn: Token,
    tokenOut: Token
  ): Promise<number> {
    try {
      const priceIn = await this.getPrice(tokenIn);
      const priceOut = await this.getPrice(tokenOut);

      // Calculate the price ratio
      return priceIn.price / priceOut.price;
    } catch (error) {
      logger.error(`Error calculating price between tokens: ${error}`);
      throw error;
    }
  }
} 