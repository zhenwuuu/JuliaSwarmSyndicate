# Quick Start Guide - JuliaOS DeFi Framework

This guide will help you get started with the JuliaOS DeFi Framework quickly, from installation to running your first DeFi agent.

## Prerequisites

1. **System Requirements**:
   - Julia 1.8 or later
   - Git
   - At least 4GB RAM
   - Stable internet connection

2. **Blockchain Access**:
   - RPC endpoints for your target chains
   - API keys for data providers (optional)

## Installation

1. **Clone the Repository**:
```bash
git clone https://github.com/yourusername/JuliaOS.git
cd JuliaOS
```

2. **Install Dependencies**:
```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

3. **Set Up Environment**:
```bash
# Create necessary directories
mkdir -p logs config

# Copy example environment file
cp .env.example .env

# Edit .env with your RPC endpoints
nano .env
```

## Running Your First Agent

### 1. Start the CLI
```bash
./bin/defi-cli.jl
```

### 2. Create a Simple Arbitrage Configuration

1. Select option 1 (Create new swarm configuration)
2. Enter basic details:
```
Enter swarm name: my_first_swarm
Select coordination type: 1 (Independent)
Enter number of agents: 1
```

3. Configure the agent:
```
Select Agent Type: 1 (Arbitrage Agent)
Select Strategy: 1 (Momentum)
Select Chains: [x] Ethereum [x] Polygon
```

4. Set conservative risk parameters:
```
Enter max position size (as % of portfolio): 5
Enter minimum profit threshold (%): 2
Enter maximum gas price to consider: 50
Enter minimum confidence threshold (0-1): 0.9
```

5. Save the configuration:
```
Enter filename to save configuration: my_first_swarm.json
```

### 3. Run the Swarm

1. When prompted, enter your RPC endpoints:
```
Enter RPC URL for ethereum: https://eth-mainnet.alchemyapi.io/v2/your-api-key
Enter RPC URL for polygon: https://polygon-mainnet.g.alchemy.com/v2/your-api-key
```

2. Enter bridge contract addresses:
```
Enter bridge contract address for ethereum: 0x...
Enter bridge contract address for polygon: 0x...
```

3. Monitor the output:
```
Swarm Status:
- Agent Status: Active
- Current Positions: 0
- Total Exposure: 0%
- Last Trade: None
```

## Common Use Cases

### 1. Cross-Chain Arbitrage

**Configuration Example**:
```json
{
  "name": "eth_arbitrage",
  "coordination_type": "independent",
  "agents": [{
    "name": "eth_arb_agent",
    "type": "arbitrage",
    "strategy": "momentum",
    "chains": ["ethereum", "polygon", "arbitrum"],
    "risk_params": {
      "max_position_size": 0.05,
      "min_profit_threshold": 0.02,
      "max_gas_price": 50.0,
      "confidence_threshold": 0.9
    }
  }]
}
```

### 2. Liquidity Provision

**Configuration Example**:
```json
{
  "name": "eth_usdc_lp",
  "coordination_type": "independent",
  "agents": [{
    "name": "eth_usdc_lp_agent",
    "type": "liquidity",
    "strategy": "concentrated",
    "chains": ["ethereum"],
    "risk_params": {
      "max_position_size": 0.1,
      "min_liquidity_depth": 100000.0,
      "max_il_threshold": 0.05,
      "min_apy_threshold": 0.1
    }
  }]
}
```

## Monitoring and Management

### 1. Check Agent Status
```bash
# View logs
tail -f logs/arbitrage_agent_1.log

# Monitor performance
julia --project=. -e 'using JuliaOS; JuliaOS.monitor_agent("my_first_swarm")'
```

### 2. Emergency Stop
```bash
# Press Ctrl+C in the CLI
# Or use the emergency stop command
julia --project=. -e 'using JuliaOS; JuliaOS.emergency_stop("my_first_swarm")'
```

## Troubleshooting

### Common Issues and Solutions

1. **RPC Connection Issues**
   - Verify your RPC endpoints
   - Check network connectivity
   - Ensure API keys are valid

2. **High Gas Costs**
   - Adjust `max_gas_price` parameter
   - Consider using alternative chains
   - Monitor gas prices before trading

3. **No Trades Executed**
   - Check profit thresholds
   - Verify market data access
   - Review confidence thresholds

## Next Steps

1. **Explore Advanced Features**:
   - Try different coordination types
   - Experiment with various strategies
   - Implement custom risk management

2. **Optimize Performance**:
   - Fine-tune parameters
   - Monitor gas efficiency
   - Analyze trade patterns

3. **Join the Community**:
   - Visit our [Discord](https://discord.gg/your-server)
   - Check [GitHub Issues](https://github.com/yourusername/JuliaOS/issues)
   - Read the [Wiki](https://github.com/yourusername/JuliaOS/wiki)

## Support

Need help? Check out:
- [Full Documentation](cli.md)
- [API Reference](api.md)
- [Community Forum](https://discord.gg/your-server)
- [GitHub Issues](https://github.com/yourusername/JuliaOS/issues) 