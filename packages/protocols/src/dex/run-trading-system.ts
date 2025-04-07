import { ethers } from 'ethers';
import { MarketDataService } from './market-data';
import { UniswapV3Service } from './uniswap';
import { TradingSystem } from './trading-system';
import { getConfig } from './config';

async function main() {
  try {
    // Initialize provider and signer
    const provider = new ethers.JsonRpcProvider(process.env.MAINNET_RPC_URL);
    const signer = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

    // Initialize services
    const marketData = new MarketDataService(provider);
    const uniswap = new UniswapV3Service(provider, signer);

    // Get configuration based on network
    const network = process.env.NETWORK as 'testnet' | 'mainnet' || 'mainnet';
    const config = getConfig(network);

    // Initialize trading system
    const tradingSystem = new TradingSystem(
      config,
      marketData,
      uniswap,
      provider,
      signer
    );

    // Start the system
    await tradingSystem.start();

    // Handle shutdown
    process.on('SIGINT', async () => {
      console.log('Shutting down trading system...');
      await tradingSystem.stop();
      process.exit(0);
    });

    // Log system status periodically
    setInterval(() => {
      const status = tradingSystem.getSystemStatus();
      console.log('System Status:', {
        isRunning: status.isRunning,
        openPositions: status.openPositions,
        totalPnL: status.totalPnL,
        alerts: status.alerts,
      });
    }, 60000); // Every minute

    // Log performance report daily
    setInterval(() => {
      const performance = tradingSystem.getPerformanceReport();
      const risk = tradingSystem.getRiskReport();
      console.log('Daily Report:', {
        performance,
        risk,
      });
    }, 24 * 60 * 60 * 1000); // Every 24 hours

  } catch (error) {
    console.error('Failed to start trading system:', error);
    process.exit(1);
  }
}

// Run the script
main().catch((error) => {
  console.error('Unhandled error:', error);
  process.exit(1);
}); 