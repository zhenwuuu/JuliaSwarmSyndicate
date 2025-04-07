/**
 * Supported blockchain networks
 */
export enum ChainId {
  ETHEREUM = 1,
  ARBITRUM = 42161,
  OPTIMISM = 10,
  BASE = 8453,
  POLYGON = 137,
  SOLANA = 999999999 // Custom identifier for Solana
}

/**
 * Cross-chain token information
 */
export interface TokenInfo {
  symbol: string;
  name: string;
  decimals: number;
  address: string; // Contract address (or mint address for Solana)
  chainId: ChainId;
  logoURI?: string;
  isNative?: boolean;
}

/**
 * Liquidity source information
 */
export interface LiquiditySource {
  id: string;
  name: string;
  chainId: ChainId;
  type: 'dex' | 'lending' | 'bridge' | 'aggregator';
  routerAddress?: string;
  factoryAddress?: string;
  fees?: {
    fixed?: number;
    percentage?: number;
  };
}

/**
 * Bridge information
 */
export interface BridgeInfo {
  id: string;
  name: string;
  sourceChainId: ChainId;
  targetChainId: ChainId;
  tokenAddresses: {
    [ChainId.ETHEREUM]?: string;
    [ChainId.ARBITRUM]?: string;
    [ChainId.OPTIMISM]?: string;
    [ChainId.BASE]?: string;
    [ChainId.POLYGON]?: string;
    [ChainId.SOLANA]?: string;
  };
  estimatedTime: number; // In seconds
  fees: {
    fixed?: number;
    percentage?: number;
  };
}

/**
 * Route segment (part of a cross-chain route)
 */
export interface RouteSegment {
  type: 'swap' | 'bridge' | 'transfer';
  sourceChainId: ChainId;
  targetChainId: ChainId;
  sourceToken: TokenInfo;
  targetToken: TokenInfo;
  liquiditySource?: LiquiditySource;
  bridge?: BridgeInfo;
  estimatedGas?: number;
  estimatedTime?: number; // In seconds
  estimatedValue?: {
    inputAmount: string;
    outputAmount: string;
  };
  priceImpact?: number; // As percentage (0-100)
}

/**
 * Complete cross-chain route
 */
export interface CrossChainRoute {
  id: string;
  sourceChainId: ChainId;
  targetChainId: ChainId;
  sourceToken: TokenInfo;
  targetToken: TokenInfo;
  segments: RouteSegment[];
  totalGasEstimate: number;
  totalTimeEstimate: number; // In seconds
  totalFees: {
    fixed: number;
    percentage: number;
  };
  totalValue: {
    inputAmount: string;
    outputAmount: string;
    priceImpact: number; // As percentage (0-100)
  };
}

/**
 * Router configuration options
 */
export interface RouterConfig {
  preferredBridges?: string[]; // Bridge IDs in order of preference
  preferredDexes?: string[]; // DEX IDs in order of preference
  maxHops?: number; // Maximum number of hops in a route
  maxBridges?: number; // Maximum number of bridges in a route
  minLiquidity?: number; // Minimum liquidity requirement in USD
  gasTokens?: TokenInfo[]; // Tokens to use for gas on different chains
  slippageTolerance?: number; // In percentage (0-100)
  timeout?: number; // In milliseconds
}

/**
 * Route quote request
 */
export interface RouteQuoteRequest {
  sourceChainId: ChainId;
  targetChainId: ChainId;
  sourceToken: string; // Token address or symbol
  targetToken: string; // Token address or symbol
  amount: string; // Amount in source token's smallest unit
  sender?: string; // Sender wallet address
  recipient?: string; // Recipient wallet address
  config?: RouterConfig;
}

/**
 * Route quote response
 */
export interface RouteQuoteResponse {
  routes: CrossChainRoute[];
  bestRoute: CrossChainRoute;
  alternativeRoutes: CrossChainRoute[];
  timestamp: number;
}

/**
 * Route execution request
 */
export interface RouteExecutionRequest {
  routeId: string;
  sender: string; // Sender wallet address
  recipient: string; // Recipient wallet address
  slippage?: number; // Override default slippage tolerance
  deadline?: number; // Unix timestamp for deadline
}

/**
 * Route execution status
 */
export enum RouteExecutionStatus {
  PENDING = 'pending',
  IN_PROGRESS = 'in_progress',
  COMPLETED = 'completed',
  FAILED = 'failed'
}

/**
 * Route execution response
 */
export interface RouteExecutionResponse {
  routeId: string;
  status: RouteExecutionStatus;
  txHashes: string[]; // Transaction hashes for each step
  currentStep: number;
  totalSteps: number;
  error?: string;
  completedTime?: number; // Unix timestamp
}

/**
 * Price data for a token pair
 */
export interface TokenPriceData {
  baseToken: TokenInfo;
  quoteToken: TokenInfo;
  price: string; // Price of base token in quote token
  liquidity: string; // Liquidity in USD
  volume24h: string; // 24-hour volume in USD
  source: LiquiditySource;
  timestamp: number;
}

/**
 * Gas price data
 */
export interface GasPriceData {
  chainId: ChainId;
  standard: string; // Gas price for standard transactions
  fast: string; // Gas price for fast transactions
  instant: string; // Gas price for instant transactions
  baseFee?: string; // For EIP-1559 chains
  priorityFee?: {
    low: string;
    medium: string;
    high: string;
  };
  timestamp: number;
}

/**
 * AI Agent path optimization parameters
 */
export interface PathOptimizationParams {
  optimizeFor: 'speed' | 'cost' | 'value' | 'balanced';
  maxRoutes: number; 
  useSwarm: boolean;
  swarmSize?: number;
  learningRate?: number;
  maxIterations?: number;
}

/**
 * Swarm intelligence optimization result
 */
export interface SwarmOptimizationResult {
  optimizedRoutes: CrossChainRoute[];
  iterations: number;
  convergenceSpeed: number;
  improvementPercentage: number;
}

/**
 * Real-time route monitoring
 */
export interface RouteMonitoring {
  routeId: string;
  status: RouteExecutionStatus;
  progress: number; // 0-100
  currentSegment: RouteSegment;
  executionTime: number; // Time taken so far in seconds
  remainingTime: number; // Estimated remaining time in seconds
  alerts: string[]; // Any issues or warnings
} 