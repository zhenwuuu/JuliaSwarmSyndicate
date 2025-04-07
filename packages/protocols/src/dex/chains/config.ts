import { ChainConfig } from './types';

export const ETHEREUM_CONFIG: ChainConfig = {
  chainId: 'ethereum',
  rpcUrl: process.env.ETHEREUM_RPC_URL || 'https://eth-mainnet.g.alchemy.com/v2/q1hfvN-A9HSUh7e1hYFLsu__IfsAN9Wp',
  nativeCurrency: {
    name: 'Ether',
    symbol: 'ETH',
    decimals: 18,
  },
  blockTime: 12,
  confirmations: 2,
  gasLimit: 300000,
  priorityFee: '2',
  maxFeePerGas: '100',
};

export const BASE_CONFIG: ChainConfig = {
  chainId: 'base',
  rpcUrl: process.env.BASE_RPC_URL || 'https://mainnet.base.org',
  nativeCurrency: {
    name: 'Ether',
    symbol: 'ETH',
    decimals: 18,
  },
  blockTime: 2,
  confirmations: 1,
  gasLimit: 300000,
  priorityFee: '0.1',
  maxFeePerGas: '10',
};

export const SOLANA_CONFIG: ChainConfig = {
  chainId: 'solana',
  rpcUrl: process.env.SOLANA_RPC_URL || 'https://api.mainnet-beta.solana.com',
  nativeCurrency: {
    name: 'Solana',
    symbol: 'SOL',
    decimals: 9,
  },
  blockTime: 0.4,
  confirmations: 32,
  gasLimit: 0,
  priorityFee: '0',
  maxFeePerGas: '0',
  commitment: 'confirmed',
  maxRetries: 3,
  preflightCommitment: 'confirmed',
  wsEndpoint: process.env.SOLANA_WS_ENDPOINT || 'wss://api.mainnet-beta.solana.com',
};

export function getChainConfig(chainId: string): ChainConfig {
  switch (chainId) {
    case 'ethereum':
      return ETHEREUM_CONFIG;
    case 'base':
      return BASE_CONFIG;
    case 'solana':
      return SOLANA_CONFIG;
    default:
      throw new Error(`Unsupported chain: ${chainId}`);
  }
} 