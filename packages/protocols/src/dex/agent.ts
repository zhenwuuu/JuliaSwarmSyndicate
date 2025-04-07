import { ethers } from 'ethers';
import { MarketDataService } from './market-data';
import { TradingService, TradeParams, RiskParams } from './trading';
import { Token } from '../tokens/types';

// Define USDC token
const USDC: Token = {
  symbol: 'USDC',
  name: 'USD Coin',
  address: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
  decimals: 6,
  chainId: 1
};

export interface AgentConfig {
  id: string;
  tradingService: TradingService;
  marketDataService: MarketDataService;
  riskParameters: {
    maxPositionSize: string;
    stopLossPercentage: number;
    takeProfitPercentage: number;
  };
  tradingParameters: {
    entryThreshold: number;
    exitThreshold: number;
    stopLossPercentage: number;
    takeProfitPercentage: number;
  };
  strategy: {
    type: 'momentum' | 'mean-reversion' | 'trend-following';
    parameters: Record<string, number>;
  };
}

export interface AgentMetrics {
  totalTrades: number;
  winningTrades: number;
  losingTrades: number;
  totalPnL: number;
  maxDrawdown: number;
  sharpeRatio: number;
}

export class Agent {
  public readonly id: string;
  private tradingService: TradingService;
  private marketDataService: MarketDataService;
  private riskParameters: AgentConfig['riskParameters'];
  private tradingParameters: AgentConfig['tradingParameters'];
  private strategy: AgentConfig['strategy'];
  private metrics: AgentMetrics;
  private state: any;
  private currentAllocation: number = 0;
  private lastUpdate: number = 0;

  constructor(config: AgentConfig) {
    this.id = config.id;
    this.tradingService = config.tradingService;
    this.marketDataService = config.marketDataService;
    this.riskParameters = config.riskParameters;
    this.tradingParameters = config.tradingParameters;
    this.strategy = config.strategy;
    this.metrics = {
      totalTrades: 0,
      winningTrades: 0,
      losingTrades: 0,
      totalPnL: 0,
      maxDrawdown: 0,
      sharpeRatio: 0
    };
  }

  async update(): Promise<void> {
    const now = Date.now();
    if (now - this.lastUpdate < 60000) { // Update every minute
      return;
    }
    this.lastUpdate = now;

    // Update positions
    await this.tradingService.updatePositions();

    // Analyze market and make trading decisions
    const positions = this.tradingService.getPositions();
    const availableTokens = await this.getAvailableTokens();

    for (const token of availableTokens) {
      const position = positions.find(p => p.token.address === token.address);
      if (position) {
        await this.evaluatePosition(position);
      } else {
        await this.evaluateNewPosition(token);
      }
    }

    // Update metrics
    await this.updateMetrics();
  }

  private async evaluatePosition(position: any): Promise<void> {
    const marketData = await this.marketDataService.getMarketData(position.token, USDC);
    if (!marketData) return;

    const currentPrice = parseFloat(marketData.price);
    const entryPrice = parseFloat(position.entryPrice);
    const priceChange = (currentPrice - entryPrice) / entryPrice * 100;

    // Check stop loss
    if (priceChange <= -this.tradingParameters.stopLossPercentage) {
      await this.tradingService.closePosition(position.token.address);
      this.metrics.losingTrades++;
      return;
    }

    // Check take profit
    if (priceChange >= this.tradingParameters.takeProfitPercentage) {
      await this.tradingService.closePosition(position.token.address);
      this.metrics.winningTrades++;
      return;
    }

    // Strategy-specific evaluation
    const shouldClose = await this.evaluateStrategy(position, marketData);
    if (shouldClose) {
      await this.tradingService.closePosition(position.token.address);
      this.metrics.winningTrades++;
    }
  }

  private async evaluateNewPosition(token: Token): Promise<void> {
    const marketData = await this.marketDataService.getMarketData(token, USDC);
    if (!marketData || marketData.confidence < this.tradingParameters.entryThreshold) {
      return;
    }

    const signal = await this.generateTradingSignal(token, marketData);
    if (!signal.shouldTrade) return;

    const tradeParams: TradeParams = {
      token,
      amount: signal.amount,
      slippageTolerance: this.tradingParameters.exitThreshold,
      stopLoss: (parseFloat(marketData.price) * (1 - this.tradingParameters.stopLossPercentage / 100)).toString(),
      takeProfit: (parseFloat(marketData.price) * (1 + this.tradingParameters.takeProfitPercentage / 100)).toString()
    };

    try {
      await this.tradingService.openPosition(tradeParams);
      this.metrics.totalTrades++;
    } catch (error) {
      console.error(`Failed to open position for ${token.symbol}:`, error);
    }
  }

  private async generateTradingSignal(token: Token, marketData: any): Promise<{ shouldTrade: boolean; amount: string }> {
    switch (this.strategy.type) {
      case 'momentum':
        return this.generateMomentumSignal(token, marketData);
      case 'mean-reversion':
        return this.generateMeanReversionSignal(token, marketData);
      case 'trend-following':
        return this.generateTrendFollowingSignal(token, marketData);
      default:
        return { shouldTrade: false, amount: '0' };
    }
  }

  private async generateMomentumSignal(token: Token, marketData: any): Promise<{ shouldTrade: boolean; amount: string }> {
    // Implement momentum strategy
    const priceChange = marketData.priceChange24h || 0;
    const volumeChange = marketData.volumeChange24h || 0;

    if (priceChange > this.strategy.parameters.momentumThreshold && 
        volumeChange > this.strategy.parameters.volumeThreshold) {
      return {
        shouldTrade: true,
        amount: this.calculatePositionSize(token, marketData)
      };
    }

    return { shouldTrade: false, amount: '0' };
  }

  private async generateMeanReversionSignal(token: Token, marketData: any): Promise<{ shouldTrade: boolean; amount: string }> {
    // Implement mean reversion strategy
    const price = parseFloat(marketData.price);
    const movingAverage = await this.calculateMovingAverage(token, 20);

    if (Math.abs(price - movingAverage) / movingAverage > this.strategy.parameters.deviationThreshold) {
      return {
        shouldTrade: true,
        amount: this.calculatePositionSize(token, marketData)
      };
    }

    return { shouldTrade: false, amount: '0' };
  }

  private async generateTrendFollowingSignal(token: Token, marketData: any): Promise<{ shouldTrade: boolean; amount: string }> {
    // Implement trend following strategy
    const shortMA = await this.calculateMovingAverage(token, 20);
    const longMA = await this.calculateMovingAverage(token, 50);

    if (shortMA > longMA && marketData.priceChange24h > 0) {
      return {
        shouldTrade: true,
        amount: this.calculatePositionSize(token, marketData)
      };
    }

    return { shouldTrade: false, amount: '0' };
  }

  private async calculateMovingAverage(token: Token, period: number): Promise<number> {
    // Mock implementation for testing
    return 100;
  }

  private calculatePositionSize(token: Token, marketData: any): string {
    // Implement position sizing based on risk parameters
    const maxPositionValue = parseFloat(this.riskParameters.maxPositionSize);
    const currentPrice = parseFloat(marketData.price);
    return (maxPositionValue / currentPrice).toString();
  }

  private async getAvailableTokens(): Promise<Token[]> {
    // Implement token selection logic
    // This is a placeholder - you would need to implement actual token filtering
    return [];
  }

  private async updateMetrics(): Promise<void> {
    const positions = this.tradingService.getPositions();
    let totalPnL = 0;
    let maxDrawdown = 0;

    for (const position of positions) {
      const marketData = await this.marketDataService.getMarketData(position.token, USDC);
      if (!marketData) continue;

      const entryValue = parseFloat(position.amount) * parseFloat(position.entryPrice);
      const currentValue = parseFloat(position.amount) * parseFloat(marketData.price);
      const pnl = (currentValue - entryValue) / entryValue * 100;
      totalPnL += pnl;

      if (pnl < maxDrawdown) {
        maxDrawdown = pnl;
      }
    }

    this.metrics.totalPnL = totalPnL;
    this.metrics.maxDrawdown = maxDrawdown;
    this.metrics.sharpeRatio = await this.calculateSharpeRatio();
  }

  private async calculateSharpeRatio(): Promise<number> {
    // Implement Sharpe ratio calculation
    // This is a placeholder - you would need to implement actual returns calculation
    return 0;
  }

  private async evaluateStrategy(position: any, marketData: any): Promise<boolean> {
    switch (this.strategy.type) {
      case 'momentum':
        return this.evaluateMomentumStrategy(position, marketData);
      case 'mean-reversion':
        return this.evaluateMeanReversionStrategy(position, marketData);
      case 'trend-following':
        return this.evaluateTrendFollowingStrategy(position, marketData);
      default:
        return false;
    }
  }

  private async evaluateMomentumStrategy(position: any, marketData: any): Promise<boolean> {
    const priceChange = marketData.priceChange24h || 0;
    const volumeChange = marketData.volumeChange24h || 0;

    return priceChange > this.strategy.parameters.momentumThreshold && 
           volumeChange > this.strategy.parameters.volumeThreshold;
  }

  private async evaluateMeanReversionStrategy(position: any, marketData: any): Promise<boolean> {
    const price = parseFloat(marketData.price);
    const movingAverage = await this.calculateMovingAverage(position.token, 20);

    return Math.abs(price - movingAverage) / movingAverage > this.strategy.parameters.deviationThreshold;
  }

  private async evaluateTrendFollowingStrategy(position: any, marketData: any): Promise<boolean> {
    const shortMA = await this.calculateMovingAverage(position.token, 20);
    const longMA = await this.calculateMovingAverage(position.token, 50);
    return shortMA > longMA;
  }

  getMetrics(): AgentMetrics {
    return this.metrics;
  }

  getConfig(): AgentConfig {
    return {
      id: this.id,
      tradingService: this.tradingService,
      marketDataService: this.marketDataService,
      riskParameters: this.riskParameters,
      tradingParameters: this.tradingParameters,
      strategy: this.strategy
    };
  }

  getState(): any {
    return this.state;
  }

  async saveState(state: any): Promise<void> {
    this.state = state;
  }

  async loadState(): Promise<any> {
    return this.state;
  }

  async updateAllocation(allocation: number): Promise<void> {
    this.currentAllocation = allocation;
    // Update trading parameters based on new allocation
    this.riskParameters.maxPositionSize = allocation.toString();
  }
} 