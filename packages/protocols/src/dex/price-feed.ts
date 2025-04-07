import { ethers } from 'ethers';
import { Token } from '../tokens/types';

export interface PriceData {
  price: string;
  timestamp: number;
  source: string;
  confidence: number;
}

export interface PriceFeedConfig {
  updateInterval: number; // milliseconds
  maxPriceDeviation: number; // percentage
  minConfidence: number;
  sources: string[];
}

export class PriceFeed {
  private prices: Map<string, PriceData[]>;
  private config: PriceFeedConfig;
  private lastUpdate: number;

  constructor(config: PriceFeedConfig) {
    this.prices = new Map();
    this.config = config;
    this.lastUpdate = Date.now();
  }

  public async validatePrice(
    tokenA: Token,
    tokenB: Token,
    price: string
  ): Promise<boolean> {
    const pairKey = this.getPairKey(tokenA, tokenB);
    const priceData = this.prices.get(pairKey) || [];
    
    // Check if we have enough price data
    if (priceData.length < 2) {
      return false;
    }

    // Get latest price from our feeds
    const latestPrice = priceData[priceData.length - 1];
    const priceBN = BigInt(price);
    const latestPriceBN = BigInt(latestPrice.price);

    // Calculate price deviation
    const deviation = Math.abs(
      Number(priceBN - latestPriceBN) / Number(latestPriceBN) * 100
    );

    // Check if price is within acceptable deviation
    if (deviation > this.config.maxPriceDeviation) {
      return false;
    }

    // Check price confidence
    if (latestPrice.confidence < this.config.minConfidence) {
      return false;
    }

    // Check if price is stale
    if (Date.now() - latestPrice.timestamp > this.config.updateInterval) {
      return false;
    }

    return true;
  }

  public async updatePrice(
    tokenA: Token,
    tokenB: Token,
    price: string,
    source: string,
    confidence: number
  ): Promise<void> {
    const pairKey = this.getPairKey(tokenA, tokenB);
    const priceData = this.prices.get(pairKey) || [];

    // Add new price data
    priceData.push({
      price,
      timestamp: Date.now(),
      source,
      confidence
    });

    // Keep only recent price data
    const cutoffTime = Date.now() - this.config.updateInterval * 2;
    const recentPrices = priceData.filter(p => p.timestamp > cutoffTime);
    
    this.prices.set(pairKey, recentPrices);
    this.lastUpdate = Date.now();
  }

  public getLatestPrice(
    tokenA: Token,
    tokenB: Token
  ): PriceData | undefined {
    const pairKey = this.getPairKey(tokenA, tokenB);
    const priceData = this.prices.get(pairKey) || [];
    return priceData[priceData.length - 1];
  }

  public getPriceHistory(
    tokenA: Token,
    tokenB: Token,
    limit: number = 100
  ): PriceData[] {
    const pairKey = this.getPairKey(tokenA, tokenB);
    const priceData = this.prices.get(pairKey) || [];
    return priceData.slice(-limit);
  }

  public isStale(): boolean {
    return Date.now() - this.lastUpdate > this.config.updateInterval;
  }

  private getPairKey(tokenA: Token, tokenB: Token): string {
    const [addrA, addrB] = [tokenA.address, tokenB.address].sort();
    return `${addrA}-${addrB}`;
  }
} 