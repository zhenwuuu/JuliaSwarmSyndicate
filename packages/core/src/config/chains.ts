import { ChainId } from '../types';

export interface ChainConfig {
  RPC_URLS: Record<ChainId, string>;
  DEX_ROUTERS: Record<ChainId, {
    JUPITER: string;
  }>;
  COMMON_TOKENS: Record<ChainId, {
    SOL: string;
    USDC: string;
    USDT: string;
    BONK: string;
  }>;
  EXPLORER_URLS: Record<ChainId, string>;
}

export const CHAIN_CONFIG: ChainConfig = {
  RPC_URLS: {
    [ChainId.SOLANA]: process.env.SOLANA_RPC_URL || 'https://api.mainnet-beta.solana.com',
  },
  DEX_ROUTERS: {
    [ChainId.SOLANA]: {
      JUPITER: 'JUP4Fb2cqiRUcaTHdrPC8h2gNsA2ETXiPDD33WcGuJB', // Jupiter v6 Program ID
    },
  },
  COMMON_TOKENS: {
    [ChainId.SOLANA]: {
      SOL: 'So11111111111111111111111111111111111111112', // Native SOL
      USDC: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v', // USDC
      USDT: 'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB', // USDT
      BONK: 'DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263', // BONK
    },
  },
  EXPLORER_URLS: {
    [ChainId.SOLANA]: 'https://solscan.io',
  },
}; 