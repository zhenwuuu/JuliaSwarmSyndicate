using JuliaOS
using JuliaOS.UserModules
using Dates

# Ensure the user module is loaded
load_user_modules("examples/user_modules")

# Get the CustomTrading module
trading_module = get_user_module("CustomTrading")

# Create a configuration for optimization
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
println("Starting trading strategy optimization...")
results = trading_module.optimize_strategy(config)

# Display results
println("\nOptimization Results:")
println("Optimized Parameters:")
for (i, param) in enumerate(results["optimized_parameters"])
    param_name = ["SMA Period", "EMA Period", "RSI Threshold Factor", "RSI Period", "Stop Loss"][i]
    println("  $param_name: $param")
end

println("\nValidation Performance:")
validation = results["validation_performance"]
println("  Total Trades: $(validation["total_trades"])")
println("  Win Rate: $(round(validation["win_rate"] * 100, digits=2))%")
println("  Profit Factor: $(round(validation["profit_factor"], digits=2))")
println("  Max Drawdown: $(round(validation["max_drawdown"] * 100, digits=2))%")
println("  Sharpe Ratio: $(round(validation["sharpe_ratio"], digits=2))")
println("  Final Equity: \$$(round(validation["final_equity"], digits=2))")

println("\nTrade Examples:")
for symbol in keys(validation["trade_history"])
    trades = validation["trade_history"][symbol]
    if length(trades) > 0
        println("  $symbol: $(length(trades)) trades")
        if length(trades) > 3
            for i in 1:3  # Show first 3 trades
                trade = trades[i]
                println("    Trade $(i): $(trade["position"] > 0 ? "LONG" : "SHORT") | PnL: $(round(trade["pnl_pct"] * 100, digits=2))%")
            end
            println("    ...")
        else
            for (i, trade) in enumerate(trades)
                println("    Trade $(i): $(trade["position"] > 0 ? "LONG" : "SHORT") | PnL: $(round(trade["pnl_pct"] * 100, digits=2))%")
            end
        end
    end
end

println("\nOptimization completed successfully!") 