# JuliaOS Framework

The JuliaOS Framework is a comprehensive suite of Julia modules for building blockchain-powered AI agent and swarm applications. This framework provides the building blocks to create, manage, and deploy intelligent agents that can operate across multiple blockchain networks.

## Framework Modules

The framework consists of the following modules:

- **Agents**: Create and manage AI agents for various tasks
- **Swarms**: Build and coordinate swarms of agents with advanced algorithms
- **Bridge**: Communicate with the JuliaOS backend server
- **Wallet**: Connect to blockchain wallets across different networks
- **Blockchain**: Interact with blockchain networks and smart contracts
- **Core**: Common utilities and shared functionality
- **Utils**: Helper functions and utilities

## Installation

To use the entire framework in your Julia project:

```julia
import Pkg
Pkg.add(url="https://github.com/juliaos/framework")
```

Or install individual modules:

```julia
# Install just the Agents module
Pkg.add(url="https://github.com/juliaos/framework", subdir="packages/framework/agents")

# Install just the Wallet module
Pkg.add(url="https://github.com/juliaos/framework", subdir="packages/framework/wallet")
```

## Quick Start

```julia
# Use the JuliaOS Framework
using JuliaOS.Agents
using JuliaOS.Swarms
using JuliaOS.Wallet
using JuliaOS.Bridge

# Connect to the JuliaOS backend
bridge_config = BridgeConfig(host="localhost", port=8052)
connected = connect(bridge_config)

if connected
    # Create an agent
    agent_config = AgentConfig(
        "arbitrage_agent",
        "Arbitrage",
        ["price_monitoring", "cross_chain_transfers"],
        ["Ethereum", "Polygon"],
        Dict("min_profit_threshold" => 0.02)
    )
    agent = createAgent(agent_config)
    
    # Create a swarm
    swarm_config = SwarmConfig(
        "arbitrage_swarm",
        PSO(particles=30),
        "maximize_profit",
        Dict("risk_tolerance" => 0.5)
    )
    swarm = createSwarm(swarm_config)
    
    # Add agent to swarm
    addAgentToSwarm(swarm.id, agent.id)
    
    # Connect wallet
    wallet = connectWallet("0x742d35Cc6634C0532925a3b844Bc454e4438f44e", ETHEREUM)
    
    # Start swarm
    startSwarm(swarm.id)
end
```

## Prerequisites

1. **Julia**: Version 1.8 or higher
2. **JuliaOS Backend**: Running on your local machine or a remote server

To start the JuliaOS backend:

```bash
cd julia
./start.sh
```

## Module Overview

### Agents

The Agents module allows you to create and manage AI agents:

```julia
using JuliaOS.Agents

# Create an agent
agent = createAgent(AgentConfig("arbitrage_agent", "Arbitrage", [], [], Dict()))

# Start the agent
startAgent(agent.id)

# Check agent status
status = getAgentStatus(agent.id)
```

### Swarms

The Swarms module enables agent coordination using swarm intelligence algorithms:

```julia
using JuliaOS.Swarms

# Create a swarm using Particle Swarm Optimization
swarm = createSwarm(SwarmConfig(
    "trading_swarm",
    PSO(particles=50),
    "maximize_profit",
    Dict()
))

# Start the swarm
startSwarm(swarm.id)
```

### Bridge

The Bridge module facilitates communication with the JuliaOS backend:

```julia
using JuliaOS.Bridge

# Connect to the backend
connect(BridgeConfig(host="localhost", port=8052))

# Execute a function on the backend
response = execute("AgentSystem.getStatus", Dict("id" => "agent_123"))
```

### Wallet

The Wallet module provides blockchain wallet management:

```julia
using JuliaOS.Wallet

# Connect to an Ethereum wallet
wallet = connectWallet("0x742d35Cc6634C0532925a3b844Bc454e4438f44e", ETHEREUM)

# Check balance
balances = getWalletBalance(wallet.address)

# Send transaction (requires private key)
sendTransaction(wallet.address, "0x...", 0.1, "ETH")
```

## Examples

Each module includes examples in its respective `examples/` directory:

- `agents/examples/`: Agent creation and management examples
- `swarms/examples/`: Swarm algorithm examples
- `bridge/examples/`: Backend communication examples
- `wallet/examples/`: Blockchain wallet interaction examples

## Documentation

For more detailed documentation on each module, refer to the README files in the respective module directories.

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. 