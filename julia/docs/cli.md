# JuliaOS DeFi CLI Documentation

## Overview

The JuliaOS DeFi CLI provides an interactive command-line interface for managing DeFi agents and swarms. It allows users to create, configure, and run various types of DeFi agents with different strategies and coordination patterns.

## Command Structure

### Main Menu
```
Welcome to JuliaOS DeFi CLI
==========================

Options:
1. Create new swarm configuration
2. Load existing configuration
3. Exit
```

### Agent Types
1. **Arbitrage Agent**
   - Executes cross-chain arbitrage strategies
   - Supports multiple chains
   - Configurable risk parameters

2. **Liquidity Provider Agent**
   - Provides liquidity to DEX pools
   - Multiple strategy options
   - Risk management controls

### Coordination Types
1. **Independent**
   - Each agent operates autonomously
   - No inter-agent communication
   - Suitable for simple strategies

2. **Coordinated**
   - Agents share information
   - Collaborative decision making
   - Enhanced risk management

3. **Hierarchical**
   - Lead agent makes decisions
   - Delegates tasks to other agents
   - Centralized control

## Configuration

### Agent Configuration

#### Risk Parameters
- **Arbitrage Agent**:
  ```julia
  Dict(
      "max_position_size" => 0.1,      # 10% of portfolio
      "min_profit_threshold" => 0.02,   # 2% minimum profit
      "max_gas_price" => 100.0,         # Maximum gas price
      "confidence_threshold" => 0.8      # Minimum confidence
  )
  ```

- **Liquidity Provider Agent**:
  ```julia
  Dict(
      "max_position_size" => 0.2,           # 20% per pool
      "min_liquidity_depth" => 100000.0,    # Minimum TVL
      "max_il_threshold" => 0.05,           # 5% max IL
      "min_apy_threshold" => 0.1,           # 10% minimum APY
      "rebalance_threshold" => 0.1          # 10% rebalance trigger
  )
  ```

#### Strategy Parameters
- **Arbitrage Strategies**:
  - Momentum
  - Mean Reversion
  - Trend Following

- **LP Strategies**:
  - Concentrated
  - Full Range
  - Dynamic Range

### Swarm Configuration

#### Shared Risk Parameters
```julia
Dict(
    "max_total_exposure" => 0.5,    # 50% maximum exposure
    "max_drawdown" => 0.1,          # 10% maximum drawdown
    "max_daily_loss" => 0.05        # 5% maximum daily loss
)
```

## Usage Examples

### Creating a New Swarm

1. Start the CLI:
```bash
./bin/defi-cli.jl
```

2. Select option 1 (Create new swarm configuration)

3. Enter swarm details:
```
Enter swarm name: eth_arbitrage_swarm
Select coordination type:
1. Independent
2. Coordinated
3. Hierarchical
Enter number of agents: 2
```

4. Configure each agent:
```
Configuring Agent 1:
Select Agent Type:
1. Arbitrage Agent
2. Liquidity Provider Agent
Select Strategy:
1. Momentum
2. Mean Reversion
3. Trend Following
Select Chains:
[ ] Ethereum
[ ] Polygon
[ ] Arbitrum
[ ] Optimism
[ ] Base
```

5. Set risk parameters:
```
Enter max position size (as % of portfolio): 10
Enter minimum profit threshold (%): 2
Enter maximum gas price to consider: 100
Enter minimum confidence threshold (0-1): 0.8
```

6. Save configuration:
```
Enter filename to save configuration: eth_arbitrage_config.json
```

### Loading Existing Configuration

1. Start the CLI:
```bash
./bin/defi-cli.jl
```

2. Select option 2 (Load existing configuration)

3. Enter configuration file:
```
Enter configuration filename: eth_arbitrage_config.json
```

4. Review configuration:
```
Swarm Configuration:
Name: eth_arbitrage_swarm
Coordination Type: coordinated
Number of Agents: 2
...
```

5. Run the swarm:
```
Run swarm now? (y/n): y
```

## Advanced Features

### Environment Variables
The CLI supports environment variables for sensitive information:
```bash
export JULIAOS_RPC_URL_ETH=https://eth-mainnet.alchemyapi.io/v2/your-api-key
export JULIAOS_RPC_URL_POLYGON=https://polygon-mainnet.g.alchemy.com/v2/your-api-key
```

### Logging
Logs are stored in the `logs` directory:
```
logs/
├── arbitrage_agent_1.log
├── lp_agent_1.log
└── swarm_coordinator.log
```

### Monitoring
The CLI provides real-time monitoring capabilities:
```
Current Status:
- Active Agents: 2
- Total Positions: 5
- Total Exposure: 30%
- Daily PnL: +2.5%
- Gas Efficiency: 85%
```

## Error Handling

### Common Errors
1. **Configuration Errors**
   - Invalid parameter values
   - Missing required fields
   - Incompatible strategy combinations

2. **Runtime Errors**
   - RPC connection issues
   - Transaction failures
   - Gas price spikes

### Error Recovery
- Automatic retry for failed transactions
- Graceful degradation under high load
- Emergency stop capability

## Best Practices

1. **Risk Management**
   - Start with small position sizes
   - Monitor gas prices closely
   - Set appropriate stop-loss levels

2. **Performance Optimization**
   - Use appropriate RPC endpoints
   - Monitor network congestion
   - Adjust strategy parameters based on market conditions

3. **Security**
   - Use secure RPC endpoints
   - Implement proper access controls
   - Regular security audits

## Troubleshooting

### Common Issues
1. **High Gas Costs**
   - Adjust gas price parameters
   - Consider alternative chains
   - Optimize transaction timing

2. **Poor Performance**
   - Check RPC latency
   - Review strategy parameters
   - Monitor market conditions

3. **Connection Issues**
   - Verify RPC endpoints
   - Check network connectivity
   - Review firewall settings

## Support

For additional support:
- Check the [GitHub Issues](https://github.com/yourusername/JuliaOS/issues)
- Join the [Discord Community](https://discord.gg/your-server)
- Review the [Wiki](https://github.com/yourusername/JuliaOS/wiki) 