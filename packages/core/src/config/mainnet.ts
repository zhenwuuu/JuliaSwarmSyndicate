import { ChainId } from '../types';

export const MAINNET_CONFIG = {
  RPC_URLS: {
    [ChainId.ETHEREUM]: process.env.ETHEREUM_RPC_URL || 'https://eth-mainnet.g.alchemy.com/v2/YOUR-API-KEY',
    [ChainId.POLYGON]: process.env.POLYGON_RPC_URL || 'https://polygon-rpc.com',
    [ChainId.ARBITRUM]: process.env.ARBITRUM_RPC_URL || 'https://arb1.arbitrum.io/rpc',
    [ChainId.OPTIMISM]: process.env.OPTIMISM_RPC_URL || 'https://mainnet.optimism.io',
    [ChainId.BASE]: process.env.BASE_RPC_URL || 'https://mainnet.base.org',
    [ChainId.BSC]: process.env.BSC_RPC_URL || 'https://bsc-dataseed.binance.org',
    [ChainId.AVALANCHE]: process.env.AVALANCHE_RPC_URL || 'https://api.avax.network/ext/bc/C/rpc'
  },

  DEX_ROUTERS: {
    [ChainId.ETHEREUM]: '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D', // Uniswap V2
    [ChainId.POLYGON]: '0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff', // QuickSwap
    [ChainId.ARBITRUM]: '0xE592427A0AEce92De3Edee1F18E0157C05861564', // Uniswap V3
    [ChainId.OPTIMISM]: '0xE592427A0AEce92De3Edee1F18E0157C05861564', // Uniswap V3
    [ChainId.BASE]: '0x327Df1E6de05895d2ab08513aaDD9313Fe505F2F', // BaseSwap
    [ChainId.BSC]: '0x10ED43C718714eb63d5aA57B78B54704E256024E', // PancakeSwap
    [ChainId.AVALANCHE]: '0x60aE616a2155Ee3d9A68541Ba4544862310933d4' // TraderJoe
  },

  COMMON_TOKENS: {
    [ChainId.ETHEREUM]: {
      WETH: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
      USDC: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
      USDT: '0xdAC17F958D2ee523a2206206994597C13D831ec7',
      DAI: '0x6B175474E89094C44Da98b954EedeAC495271d0F'
    },
    [ChainId.POLYGON]: {
      WMATIC: '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270',
      USDC: '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174',
      USDT: '0xc2132D05D31c914a87C6611C10748AEb04B58e8F',
      DAI: '0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063'
    }
  }
}; 