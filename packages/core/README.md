# @juliaos/core

Core package for the JuliaOS framework, providing the foundation for AI-powered DeFi trading with swarm optimization.

## Features

- DeFi Trading Skill with risk management
- Swarm Agent for distributed decision making
- Julia Bridge for optimization algorithms
- Cross-chain support
- Real-time market data integration

## Installation

```bash
npm install @juliaos/core
```

## Usage

```typescript
import { SwarmAgent } from '@juliaos/core/agents';
import { DeFiTradingSkill } from '@juliaos/core/skills';
import { JuliaBridge } from '@juliaos/core/bridge';

// Initialize components
const juliaBridge = new JuliaBridge({
  juliaPath: 'julia',
  scriptPath: './julia/src',
  port: 8000
});

const swarmAgent = new SwarmAgent({
  name: 'trading-swarm',
  type: 'trading',
  platforms: [],
  skills: [],
  swarmConfig: {
    size: 10,
    communicationProtocol: 'gossip',
    consensusThreshold: 0.7,
    updateInterval: 5000
  }
});

const tradingSkill = new DeFiTradingSkill(swarmAgent, {
  tradingPairs: ['ETH/USDC', 'WBTC/USDC'],
  swarmSize: 10,
  algorithm: 'pso',
  riskParameters: {
    maxPositionSize: 1,
    stopLoss: 0.02,
    takeProfit: 0.05,
    maxDrawdown: 0.1
  },
  provider: 'YOUR_RPC_URL',
  wallet: 'YOUR_PRIVATE_KEY'
});

// Start trading
await juliaBridge.initialize();
await swarmAgent.initialize();
await tradingSkill.initialize();
await tradingSkill.execute();
```

## Documentation

For detailed documentation, visit our [documentation site](https://docs.juliaos.ai).

## License

MIT 