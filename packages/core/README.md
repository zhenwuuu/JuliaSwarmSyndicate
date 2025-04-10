# JuliaOS Core

Core package for the JuliaOS framework, providing the foundation for AI-powered agents and swarms with optimization algorithms.

## Features

- Agent System for creating and managing AI agents
- Swarm Intelligence for coordinated agent behavior
- Julia Bridge for optimization algorithms
- Cross-chain support for blockchain interactions
- Real-time market data integration with Chainlink
- Differential Evolution algorithm implementation

## Installation

```bash
# Clone the repository
git clone https://github.com/Juliaoscode/JuliaOS.git
cd JuliaOS

# Install dependencies
npm install
```

## Usage

```javascript
const { JuliaBridge } = require('./packages/julia-bridge');
const { AgentManager } = require('./packages/framework/agents');
const { SwarmManager } = require('./packages/framework/swarms');

// Initialize the Julia bridge
const juliaBridge = new JuliaBridge({
  host: 'localhost',
  port: 8052
});

// Connect to the JuliaOS backend
juliaBridge.connect().then(async (connected) => {
  if (connected) {
    // Create an agent manager
    const agentManager = new AgentManager(juliaBridge);

    // Create a swarm manager
    const swarmManager = new SwarmManager(juliaBridge);

    // Create a portfolio optimization agent
    const agent = await agentManager.createAgent({
      name: 'portfolio_agent',
      type: 'PortfolioOptimization',
      skills: ['market_analysis', 'risk_management'],
      chains: ['Ethereum', 'Solana'],
      config: {
        assets: ['ETH', 'SOL', 'USDC'],
        risk_tolerance: 0.5,
        rebalance_interval: 86400 // 1 day in seconds
      }
    });

    // Create a swarm using Differential Evolution
    const swarm = await swarmManager.createSwarm({
      name: 'portfolio_swarm',
      algorithm: 'DifferentialEvolution',
      objective: 'maximize_sharpe_ratio',
      config: {
        population_size: 30,
        crossover_rate: 0.7,
        mutation_factor: 0.8,
        max_generations: 100
      }
    });

    // Add agent to swarm
    await swarmManager.addAgentToSwarm(swarm.id, agent.id);

    // Start swarm
    await swarmManager.startSwarm(swarm.id);
  }
});
```

## Documentation

For more detailed documentation, refer to the README files in the respective module directories:

- [Framework README](../framework/README.md)
- [Julia Bridge README](../julia-bridge/README.md)
- [Agents README](../framework/agents/README.md)
- [Swarms README](../framework/swarms/README.md)

## License

MIT License