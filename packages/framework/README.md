# JuliaOS Framework

The JuliaOS Framework is a comprehensive suite of modules for building blockchain-powered AI agent and swarm applications. This framework provides the building blocks to create, manage, and deploy intelligent agents that can operate across multiple blockchain networks.

The framework is available in both JavaScript and Julia implementations, allowing developers to choose the language that best fits their needs.

## Framework Modules

The framework consists of the following modules:

- **Agents**: Create and manage AI agents for various tasks
- **Swarms**: Build and coordinate swarms of agents with advanced algorithms
- **Bridge**: Communicate with the JuliaOS backend server
- **Wallet**: Connect to blockchain wallets across different networks
- **Blockchain**: Interact with blockchain networks and smart contracts
- **Utils**: Helper functions and utilities

## Installation

To use the entire framework in your project:

```bash
# Clone the repository
git clone https://github.com/Juliaoscode/JuliaOS.git
cd JuliaOS

# Install dependencies
npm install
```

Or use the framework modules directly:

```javascript
// Import the framework modules
const { agents } = require('./packages/framework/agents');
const { wallet } = require('./packages/framework/wallet');
```

## Quick Start

```javascript
// Import required modules
const { JuliaBridge } = require('./packages/julia-bridge');
const { AgentManager } = require('./packages/framework/agents');
const { SwarmManager } = require('./packages/framework/swarms');
const { WalletManager } = require('./packages/framework/wallet');

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

    // Create a wallet manager
    const walletManager = new WalletManager();

    // Create an agent
    const agent = await agentManager.createAgent({
      name: 'arbitrage_agent',
      type: 'Arbitrage',
      skills: ['price_monitoring', 'cross_chain_transfers'],
      chains: ['Ethereum', 'Polygon'],
      config: { min_profit_threshold: 0.02 }
    });

    // Create a swarm
    const swarm = await swarmManager.createSwarm({
      name: 'arbitrage_swarm',
      algorithm: 'PSO',
      objective: 'maximize_profit',
      config: { risk_tolerance: 0.5, particles: 30 }
    });

    // Add agent to swarm
    await swarmManager.addAgentToSwarm(swarm.id, agent.id);

    // Connect wallet
    const wallet = await walletManager.connectWallet('0x742d35Cc6634C0532925a3b844Bc454e4438f44e', 'ETHEREUM');

    // Start swarm
    await swarmManager.startSwarm(swarm.id);
  }
});
```

## Prerequisites

1. **Node.js**: Version 16 or higher
2. **npm**: Version 7 or higher
3. **Julia**: Version 1.8 or higher
4. **JuliaOS Backend**: Running on your local machine or a remote server

To start the JuliaOS backend:

```bash
cd scripts/server
./run-server.sh
```

## Module Overview

### Agents

The Agents module allows you to create and manage AI agents:

```javascript
const { AgentManager } = require('./packages/framework/agents');

// Initialize the agent manager
const agentManager = new AgentManager(juliaBridge);

// Create an agent
const agent = await agentManager.createAgent({
  name: 'arbitrage_agent',
  type: 'Arbitrage',
  skills: [],
  chains: [],
  config: {}
});

// Start the agent
await agentManager.startAgent(agent.id);

// Check agent status
const status = await agentManager.getAgentStatus(agent.id);
```

### Swarms

The Swarms module enables agent coordination using swarm intelligence algorithms:

```javascript
const { SwarmManager } = require('./packages/framework/swarms');

// Initialize the swarm manager
const swarmManager = new SwarmManager(juliaBridge);

// Create a swarm using Particle Swarm Optimization
const swarm = await swarmManager.createSwarm({
  name: 'trading_swarm',
  algorithm: 'PSO',
  objective: 'maximize_profit',
  config: { particles: 50 }
});

// Start the swarm
await swarmManager.startSwarm(swarm.id);
```

### Bridge

The Bridge module facilitates communication with the JuliaOS backend:

```javascript
const { JuliaBridge } = require('./packages/julia-bridge');

// Initialize the Julia bridge
const juliaBridge = new JuliaBridge({
  host: 'localhost',
  port: 8052
});

// Connect to the backend
const connected = await juliaBridge.connect();

// Execute a function on the backend
const response = await juliaBridge.execute('AgentSystem.getStatus', { id: 'agent_123' });
```

### Wallet

The Wallet module provides blockchain wallet management:

```javascript
const { WalletManager } = require('./packages/framework/wallet');

// Initialize the wallet manager
const walletManager = new WalletManager();

// Connect to an Ethereum wallet
const wallet = await walletManager.connectWallet('0x742d35Cc6634C0532925a3b844Bc454e4438f44e', 'ETHEREUM');

// Check balance
const balances = await walletManager.getWalletBalance(wallet.address);

// Send transaction (requires private key)
await walletManager.sendTransaction(wallet.address, '0x...', 0.1, 'ETH');
```

## Julia Implementation

The JuliaOS Framework is also available as a native Julia package, providing the same functionality with the performance benefits of Julia.

### Julia Installation

```julia
using Pkg
Pkg.add(url="https://github.com/yourusername/JuliaOS.jl")
```

### Julia Quick Start

```julia
using JuliaOS

# Connect to the JuliaOS backend
JuliaOS.Bridge.connect()

# Create a trading agent
trading_config = JuliaOS.TradingAgent.TradingAgentConfig(
    "My Trading Agent",
    risk_level="medium",
    trading_pairs=["ETH/USDC", "BTC/USDC"]
)
agent = JuliaOS.TradingAgent.createTradingAgent(trading_config)

# Create a swarm
swarm_config = JuliaOS.Swarms.SwarmConfig(
    "My Swarm",
    JuliaOS.Swarms.PSO(),
    "minimize",
    Dict("dimensions" => 10)
)
swarm = JuliaOS.Swarms.createSwarm(swarm_config)

# Add the agent to the swarm
JuliaOS.Swarms.addAgentToSwarm(swarm.id, agent.id)

# Execute a task with the agent
task = Dict{String, Any}(
    "action" => "analyze_market",
    "market" => "crypto",
    "timeframe" => "1d"
)
result = JuliaOS.Agents.executeAgentTask(agent.id, task)
```

### Julia Specialized Agent Types

The Julia implementation includes specialized agent types for specific use cases:

- **TradingAgent**: Agents specialized in trading and financial operations
- **ResearchAgent**: Agents specialized in research and data analysis
- **DevAgent**: Agents specialized in software development

## Examples

Each module includes examples in its respective directory:

- `packages/framework/agents/`: Agent creation and management examples
- `packages/framework/swarms/`: Swarm algorithm examples
- `packages/julia-bridge/`: Backend communication examples
- `packages/framework/wallet/`: Blockchain wallet interaction examples

## Documentation

For more detailed documentation on each module, refer to the README files in the respective module directories:

- [Agents README](./agents/README.md)
- [Swarms README](./swarms/README.md)
- [Bridge README](./bridge/README.md)
- [Wallet README](./wallet/README.md)
- [Blockchain README](./blockchain/README.md)

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.