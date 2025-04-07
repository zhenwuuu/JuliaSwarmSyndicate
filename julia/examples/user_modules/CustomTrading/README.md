# CustomTrading Module

An example user module for JuliaOS that demonstrates how to create a custom trading strategy optimization module.

## Features

- Trading strategy optimization using swarm intelligence algorithms
- Strategy backtesting on historical market data
- Performance analysis and visualization
- Support for multiple trading pairs and timeframes
- Risk management with configurable stop-loss

## Usage

```julia
using JuliaOS
using JuliaOS.UserModules

# Load user modules
load_user_modules("examples/user_modules")

# Get the CustomTrading module
trading_module = get_user_module("CustomTrading")

# Create a configuration
config = trading_module.TradingConfig(
    "pso",                                  # algorithm
    Dict(                                   # algorithm parameters
        "inertia_weight" => 0.7,
        "cognitive_coef" => 1.5,
        "social_coef" => 1.5
    ),
    30,                                     # swarm_size
    5,                                      # dimension (5 parameters to optimize)
    ["BTC/USDT", "ETH/USDT"],              # symbols
    "1h",                                   # timeframe
    (DateTime(2022, 1, 1), DateTime(2022, 6, 30)),    # optimization_period
    (DateTime(2022, 7, 1), DateTime(2022, 12, 31)),   # validation_period
    0.02                                    # risk_per_trade (2% risk per trade)
)

# Run the optimization
results = trading_module.optimize_strategy(config)

# You can also backtest a specific set of parameters
parameters = [50.0, 20.0, 1.5, 14.0, 0.02]  # Your custom parameters
backtest_results = trading_module.backtest_strategy(parameters, market_data, config)
```

## Strategy Implementation

This module implements a simple trading strategy based on:

1. Trend determination using SMA and EMA crossovers
2. Entry signals using RSI overbought/oversold conditions
3. Risk management with configurable stop-loss

The strategy is designed to be a starting point that you can modify and extend according to your needs.

## Examples

Check out the example scripts in this directory:

- `optimize_trading_strategy.jl`: Demonstrates how to optimize a trading strategy
- `backtest_example.jl`: Shows how to backtest a specific set of parameters

## Customization

To customize this module for your own needs:

1. Modify the `generate_signals` function to implement your own strategy logic
2. Adjust the parameter bounds in the `optimize_strategy` function
3. Add additional indicators or analysis in the helper functions
4. Extend the `backtest_strategy` function with additional performance metrics

## Dependencies

- JuliaOS core modules
- Statistics
- Dates
- JSON
- DataFrames

## License

This example module is provided as part of the JuliaOS framework and is available under the same license terms. 