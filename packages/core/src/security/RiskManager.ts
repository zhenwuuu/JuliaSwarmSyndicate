import { ChainId, TokenAmount } from '../types';
import { logger } from '../utils/logger';

export interface RiskConfig {
  maxTransactionValue: TokenAmount;
  maxDailyVolume: TokenAmount;
  maxSlippage: number;
  minLiquidity: TokenAmount;
  maxGasPrice: TokenAmount;
  circuitBreakerThreshold: number;
}

export class RiskManager {
  private static instance: RiskManager;
  private configs: Map<ChainId, RiskConfig>;
  private dailyVolumes: Map<ChainId, TokenAmount>;
  private isCircuitBreakerActive: boolean;

  private constructor() {
    this.configs = new Map();
    this.dailyVolumes = new Map();
    this.isCircuitBreakerActive = false;
  }

  public static getInstance(): RiskManager {
    if (!RiskManager.instance) {
      RiskManager.instance = new RiskManager();
    }
    return RiskManager.instance;
  }

  public setConfig(chainId: ChainId, config: RiskConfig): void {
    this.configs.set(chainId, config);
    logger.info(`Updated risk config for chain ${chainId}`);
  }

  public async validateTransaction(
    chainId: ChainId,
    amount: TokenAmount,
    gasPrice: TokenAmount,
    slippage: number
  ): Promise<boolean> {
    const config = this.configs.get(chainId);
    if (!config) {
      logger.error(`No risk config found for chain ${chainId}`);
      return false;
    }

    // Check circuit breaker
    if (this.isCircuitBreakerActive) {
      logger.warn('Circuit breaker is active, transaction rejected');
      return false;
    }

    // Check transaction value
    if (amount.gt(config.maxTransactionValue)) {
      logger.warn(`Transaction value ${amount.toString()} exceeds maximum ${config.maxTransactionValue.toString()}`);
      return false;
    }

    // Check daily volume
    const dailyVolume = this.dailyVolumes.get(chainId) || TokenAmount.zero();
    if (dailyVolume.add(amount).gt(config.maxDailyVolume)) {
      logger.warn(`Daily volume limit exceeded`);
      return false;
    }

    // Check slippage
    if (slippage > config.maxSlippage) {
      logger.warn(`Slippage ${slippage}% exceeds maximum ${config.maxSlippage}%`);
      return false;
    }

    // Check gas price
    if (gasPrice.gt(config.maxGasPrice)) {
      logger.warn(`Gas price ${gasPrice.toString()} exceeds maximum ${config.maxGasPrice.toString()}`);
      return false;
    }

    return true;
  }

  public updateDailyVolume(chainId: ChainId, amount: TokenAmount): void {
    const currentVolume = this.dailyVolumes.get(chainId) || TokenAmount.zero();
    this.dailyVolumes.set(chainId, currentVolume.add(amount));
  }

  public activateCircuitBreaker(): void {
    this.isCircuitBreakerActive = true;
    logger.warn('Circuit breaker activated');
  }

  public deactivateCircuitBreaker(): void {
    this.isCircuitBreakerActive = false;
    logger.info('Circuit breaker deactivated');
  }

  public resetDailyVolumes(): void {
    this.dailyVolumes.clear();
    logger.info('Daily volumes reset');
  }
} 