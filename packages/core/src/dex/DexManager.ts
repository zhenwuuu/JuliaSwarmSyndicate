import { Connection } from '@solana/web3.js';
import { ChainId, TokenAmount } from '../types';
import { logger } from '../utils/logger';
import { JupiterDex } from './jupiter';
import { ChainlinkPriceFeed } from './chainlink';

export interface SwapReceipt {
  signature: string;
  status: 'pending' | 'confirmed' | 'failed';
}

export class DexManager {
  private static instance: DexManager;
  private connection: Connection | null = null;
  private jupiter: JupiterDex | null = null;
  private chainlink: ChainlinkPriceFeed | null = null;

  private constructor() {}

  static getInstance(): DexManager {
    if (!DexManager.instance) {
      DexManager.instance = new DexManager();
    }
    return DexManager.instance;
  }

  async initializeRouter(chainId: ChainId, routerAddress: string, connection: Connection): Promise<void> {
    this.connection = connection;
    
    // Initialize Jupiter DEX
    this.jupiter = JupiterDex.getInstance(connection, routerAddress);
    
    // Initialize Chainlink price feeds
    this.chainlink = ChainlinkPriceFeed.getInstance(connection);
    
    logger.info(`Initialized DEX router for chain ${chainId}`);
  }

  async getAmountOut(
    chainId: ChainId,
    amountIn: TokenAmount,
    tokens: string[]
  ): Promise<TokenAmount> {
    if (!this.jupiter) {
      throw new Error('DEX router not initialized');
    }

    try {
      const quote = await this.jupiter.getQuote(
        tokens[0],
        tokens[1],
        amountIn
      );

      return TokenAmount.fromRaw(quote.amount, 6); // USDC has 6 decimals
    } catch (error) {
      logger.error(`Error getting amount out: ${error}`);
      throw error;
    }
  }

  async swapExactTokensForTokens(
    chainId: ChainId,
    amountIn: TokenAmount,
    amountOutMin: TokenAmount,
    tokens: string[],
    deadline: number
  ): Promise<SwapReceipt> {
    if (!this.jupiter || !this.connection) {
      throw new Error('DEX router not initialized');
    }

    try {
      // Get quote from Jupiter
      const quote = await this.jupiter.getQuote(
        tokens[0],
        tokens[1],
        amountIn
      );

      // Get swap transaction
      const swapResponse = await this.jupiter.getSwapTransaction(
        quote,
        this.connection.rpcEndpoint
      );

      // Execute swap
      const signature = await this.jupiter.executeSwap(
        swapResponse,
        this.connection
      );

      return {
        signature,
        status: 'pending'
      };
    } catch (error) {
      logger.error(`Error executing swap: ${error}`);
      throw error;
    }
  }

  async getPrice(tokenIn: string, tokenOut: string): Promise<number> {
    if (!this.chainlink) {
      throw new Error('Price feeds not initialized');
    }

    try {
      return await this.chainlink.getPriceBetweenTokens(
        { address: tokenIn, decimals: 9, symbol: 'SOL' },
        { address: tokenOut, decimals: 6, symbol: 'USDC' }
      );
    } catch (error) {
      logger.error(`Error getting price: ${error}`);
      throw error;
    }
  }
} 