import { ethers } from 'ethers';
import { UniswapV3Service } from './uniswap';
import { MarketDataService } from './market-data';
import { RiskManager } from './risk';
import { PositionManager } from './position';

export interface ExecutionParams {
  gasLimit: number;
  maxSlippage: number; // Percentage
  minConfirmations: number;
  priorityFee: string; // In Gwei
  maxFeePerGas: string; // In Gwei
}

export interface OrderParams {
  token: string;
  size: string;
  leverage: number;
  stopLoss?: string;
  takeProfit?: string;
}

export class ExecutionManager {
  private params: ExecutionParams;
  private uniswap: UniswapV3Service;
  private marketData: MarketDataService;
  private riskManager: RiskManager;
  private positionManager: PositionManager;
  private provider: ethers.Provider;
  private signer: ethers.Signer;

  constructor(
    params: ExecutionParams,
    uniswap: UniswapV3Service,
    marketData: MarketDataService,
    riskManager: RiskManager,
    positionManager: PositionManager,
    provider: ethers.Provider,
    signer: ethers.Signer
  ) {
    this.params = params;
    this.uniswap = uniswap;
    this.marketData = marketData;
    this.riskManager = riskManager;
    this.positionManager = positionManager;
    this.provider = provider;
    this.signer = signer;
  }

  async executeOrder(params: OrderParams): Promise<{ success: boolean; txHash?: string; error?: string }> {
    try {
      // Check risk parameters
      const riskCheck = await this.riskManager.canOpenPosition(
        params.token,
        params.size,
        params.leverage
      );

      if (!riskCheck.allowed) {
        return { success: false, error: riskCheck.reason };
      }

      // Get current market data
      const marketData = await this.marketData.getMarketData(params.token);
      if (!marketData) {
        return { success: false, error: 'Failed to get market data' };
      }

      // Calculate execution price with slippage
      const executionPrice = this.calculateExecutionPrice(marketData.price, params.size);
      const minPrice = executionPrice * (1 - this.params.maxSlippage / 100);
      const maxPrice = executionPrice * (1 + this.params.maxSlippage / 100);

      // Prepare transaction parameters
      const txParams = {
        gasLimit: this.params.gasLimit,
        maxFeePerGas: ethers.parseUnits(this.params.maxFeePerGas, 'gwei'),
        maxPriorityFeePerGas: ethers.parseUnits(this.params.priorityFee, 'gwei'),
      };

      // Execute the trade
      const tx = await this.uniswap.swapExactTokensForTokens(
        params.token,
        params.size,
        minPrice,
        maxPrice,
        txParams
      );

      // Wait for confirmation
      const receipt = await tx.wait(this.params.minConfirmations);
      if (!receipt) {
        return { success: false, error: 'Transaction failed' };
      }

      // Update position
      await this.positionManager.openPosition({
        token: params.token,
        size: params.size,
        entryPrice: executionPrice,
        leverage: params.leverage,
        stopLoss: params.stopLoss,
        takeProfit: params.takeProfit,
        txHash: receipt.hash,
      });

      return { success: true, txHash: receipt.hash };
    } catch (error) {
      console.error('Order execution failed:', error);
      return { success: false, error: error.message };
    }
  }

  async closePosition(positionId: string): Promise<{ success: boolean; txHash?: string; error?: string }> {
    try {
      const position = this.positionManager.getPosition(positionId);
      if (!position) {
        return { success: false, error: 'Position not found' };
      }

      // Get current market data
      const marketData = await this.marketData.getMarketData(position.token.address);
      if (!marketData) {
        return { success: false, error: 'Failed to get market data' };
      }

      // Calculate execution price with slippage
      const executionPrice = this.calculateExecutionPrice(marketData.price, position.size);
      const minPrice = executionPrice * (1 - this.params.maxSlippage / 100);
      const maxPrice = executionPrice * (1 + this.params.maxSlippage / 100);

      // Prepare transaction parameters
      const txParams = {
        gasLimit: this.params.gasLimit,
        maxFeePerGas: ethers.parseUnits(this.params.maxFeePerGas, 'gwei'),
        maxPriorityFeePerGas: ethers.parseUnits(this.params.priorityFee, 'gwei'),
      };

      // Execute the trade
      const tx = await this.uniswap.swapExactTokensForTokens(
        position.token.address,
        position.size,
        minPrice,
        maxPrice,
        txParams
      );

      // Wait for confirmation
      const receipt = await tx.wait(this.params.minConfirmations);
      if (!receipt) {
        return { success: false, error: 'Transaction failed' };
      }

      // Update position
      await this.positionManager.closePosition(positionId, receipt.hash);

      return { success: true, txHash: receipt.hash };
    } catch (error) {
      console.error('Position close failed:', error);
      return { success: false, error: error.message };
    }
  }

  private calculateExecutionPrice(basePrice: number, size: string): number {
    // Implement price impact calculation based on size and liquidity
    // This is a simplified version - in production, you'd want to use more sophisticated models
    const sizeInUSD = parseFloat(size);
    const priceImpact = sizeInUSD / 1000000; // Assuming 1M USD liquidity
    return basePrice * (1 + priceImpact);
  }

  async getExecutionMetrics(): Promise<{
    averageExecutionTime: number;
    successRate: number;
    averageSlippage: number;
    totalTrades: number;
  }> {
    // Implement execution metrics calculation
    return {
      averageExecutionTime: 0,
      successRate: 0,
      averageSlippage: 0,
      totalTrades: 0,
    };
  }
} 