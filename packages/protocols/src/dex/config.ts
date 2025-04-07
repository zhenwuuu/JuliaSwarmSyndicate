import { TradingSystemParams } from './trading-system';

export const DEFAULT_CONFIG: TradingSystemParams = {
  // Risk parameters
  maxPositionSize: '10000', // $10,000
  maxTotalExposure: '100000', // $100,000
  maxDrawdown: 10, // 10%
  maxDailyLoss: '5000', // $5,000
  maxOpenPositions: 5,
  minLiquidity: '1000000', // $1,000,000
  slippageTolerance: 0.5, // 0.5%

  // Execution parameters
  gasLimit: 300000,
  maxSlippage: 1, // 1%
  minConfirmations: 2,
  priorityFee: '2', // 2 Gwei
  maxFeePerGas: '100', // 100 Gwei

  // Monitoring parameters
  updateInterval: 60000, // 1 minute
  metricsRetention: 30, // 30 days
  alertThresholds: {
    drawdown: 5, // 5%
    slippage: 2, // 2%
    executionTime: 30000, // 30 seconds
    errorRate: 5, // 5%
  },
};

export const TESTNET_CONFIG: TradingSystemParams = {
  ...DEFAULT_CONFIG,
  maxPositionSize: '1000', // $1,000
  maxTotalExposure: '10000', // $10,000
  maxDailyLoss: '500', // $500
  maxOpenPositions: 3,
  minLiquidity: '100000', // $100,000
  slippageTolerance: 1, // 1%
  maxSlippage: 2, // 2%
  alertThresholds: {
    ...DEFAULT_CONFIG.alertThresholds,
    errorRate: 10, // 10%
  },
};

export const MAINNET_CONFIG: TradingSystemParams = {
  ...DEFAULT_CONFIG,
  maxPositionSize: '50000', // $50,000
  maxTotalExposure: '500000', // $500,000
  maxDailyLoss: '25000', // $25,000
  maxOpenPositions: 10,
  minLiquidity: '5000000', // $5,000,000
  slippageTolerance: 0.3, // 0.3%
  maxSlippage: 0.5, // 0.5%
  alertThresholds: {
    ...DEFAULT_CONFIG.alertThresholds,
    errorRate: 2, // 2%
  },
};

export const getConfig = (network: 'testnet' | 'mainnet'): TradingSystemParams => {
  switch (network) {
    case 'testnet':
      return TESTNET_CONFIG;
    case 'mainnet':
      return MAINNET_CONFIG;
    default:
      return DEFAULT_CONFIG;
  }
}; 