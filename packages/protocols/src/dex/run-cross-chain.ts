import { ethers } from 'ethers';
import { CrossChainService } from './chains/cross-chain';
import { MarketDataService } from './market-data';
import { CrossChainSwarm, CrossChainSwarmParams } from './swarms/cross-chain-swarm';

async function main() {
  try {
    // Initialize cross-chain service
    const crossChainService = new CrossChainService();
    
    // Initialize chains
    await crossChainService.initializeChain('ethereum');
    await crossChainService.initializeChain('base');
    await crossChainService.initializeChain('solana');

    // Initialize market data service
    const marketData = new MarketDataService();

    // Define swarm parameters
    const swarmParams: CrossChainSwarmParams = {
      name: 'CrossChainTradingSwarm',
      coordinationStrategy: 'coordinated',
      chains: ['solana', 'ethereum', 'base'], // Solana first
      maxTotalExposure: '1000000', // $1M
      maxDrawdown: 10, // 10%
      maxDailyLoss: '50000', // $50K
      agents: [
        {
          name: 'SolanaMomentumAgent',
          strategy: 'momentum',
          chains: ['solana'], // Solana-only
          maxPositionSize: '200000', // $200K
          maxTotalExposure: '500000', // $500K
          stopLoss: 5, // 5%
          takeProfit: 10, // 10%
          leverage: 2,
        },
        {
          name: 'SolanaMeanReversionAgent',
          strategy: 'mean-reversion',
          chains: ['solana'], // Solana-only
          maxPositionSize: '100000', // $100K
          maxTotalExposure: '300000', // $300K
          stopLoss: 3, // 3%
          takeProfit: 6, // 6%
          leverage: 1.5,
        },
        {
          name: 'CrossChainTrendAgent',
          strategy: 'trend-following',
          chains: ['solana', 'ethereum', 'base'], // Cross-chain but Solana-first
          maxPositionSize: '150000', // $150K
          maxTotalExposure: '200000', // $200K
          stopLoss: 7, // 7%
          takeProfit: 15, // 15%
          leverage: 3,
        },
      ],
    };

    // Initialize and start swarm
    const swarm = new CrossChainSwarm(
      swarmParams,
      crossChainService,
      marketData
    );

    await swarm.initialize();
    await swarm.start();

    // Handle shutdown
    process.on('SIGINT', async () => {
      console.log('Shutting down cross-chain trading system...');
      await swarm.stop();
      process.exit(0);
    });

    // Log system status periodically
    setInterval(() => {
      const metrics = swarm.getMetrics();
      const agentMetrics = swarm.getAgentMetrics();
      
      console.log('System Status:', {
        totalPnL: metrics.totalPnL,
        totalExposure: metrics.totalExposure,
        drawdown: metrics.drawdown,
        dailyPnL: metrics.dailyPnL,
        agents: agentMetrics.map(agent => ({
          name: agent.name,
          positions: agent.positions.length,
        })),
      });
    }, 60000); // Every minute

  } catch (error) {
    console.error('Failed to start cross-chain trading system:', error);
    process.exit(1);
  }
}

// Run the script
main().catch((error) => {
  console.error('Unhandled error:', error);
  process.exit(1);
}); 