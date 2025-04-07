import { ethers } from 'ethers';

export type ChainId = 'ethereum' | 'base' | 'solana';

export interface Currency {
  name: string;
  symbol: string;
  decimals: number;
}

export interface ChainConfig {
  chainId: ChainId;
  rpcUrl: string;
  nativeCurrency: Currency;
  blockTime: number;
  confirmations: number;
  gasLimit: number;
  priorityFee: string;
  maxFeePerGas: string;
  // Solana-specific properties
  commitment?: 'confirmed' | 'finalized' | 'processed';
  maxRetries?: number;
  preflightCommitment?: 'confirmed' | 'finalized' | 'processed';
  wsEndpoint?: string;
}

export interface ChainService {
  getChainId(): ChainId;
  getRPCUrl(): string;
  sendTransaction(tx: any): Promise<string>;
  getBlockNumber(): Promise<number>;
  getGasPrice(): Promise<string>;
}

export interface DEXService {
  chainId: ChainId;
  getPrice(token: string): Promise<string>;
  getLiquidity(token: string): Promise<string>;
  swapExactTokensForTokens(
    tokenIn: string,
    tokenOut: string,
    amountIn: string,
    minAmountOut: string,
    maxAmountOut: string,
    options: any
  ): Promise<string>;
  addLiquidity(token: string, amount: string): Promise<string>;
  removeLiquidity(token: string, amount: string): Promise<string>;
} 