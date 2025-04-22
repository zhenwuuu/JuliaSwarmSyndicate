"""
    mean_reversion_example.jl

Example demonstrating mean reversion trading strategy in JuliaOS.
"""

# Add the parent directory to the load path
push!(LOAD_PATH, joinpath(@__DIR__, ".."))

# Import required modules
using Random
using Statistics
using Dates
using Distributions

# Import JuliaOS modules
include("../julia/src/dex/DEXBase.jl")
include("../julia/src/dex/UniswapDEX.jl")
include("../julia/src/price/PriceFeeds.jl")
include("../julia/src/swarm/SwarmBase.jl")
include("../julia/src/swarm/algorithms/DEPSO.jl")
include("../julia/src/trading/TradingStrategy.jl")

using .DEXBase
using .UniswapDEX
using .PriceFeeds
using .SwarmBase
using .DEPSO
using .TradingStrategy
using .TradingStrategy.RiskManagement
using .TradingStrategy.MeanReversionImpl

# Set random seed for reproducibility
Random.seed!(42)

"""
    run_mean_reversion_example()

Run a mean reversion strategy example.
"""
function run_mean_reversion_example()
    println("Mean Reversion Strategy Example")
    println("===============================")

    # Create a Chainlink price feed
    chainlink_config = PriceFeedConfig(
        name = "Chainlink",
        base_url = "https://api.chain.link/v1"
    )
    chainlink = create_chainlink_feed(chainlink_config)

    # Create a Uniswap DEX
    uniswap_config = DEXConfig(
        name = "Uniswap V2",
        chain_id = 1,  # Ethereum mainnet
        rpc_url = "https://mainnet.infura.io/v3/your-api-key",
        router_address = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
        factory_address = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f"
    )
    uniswap = UniswapV2(uniswap_config)

    # Create risk parameters
    risk_params = RiskParameters(
        max_position_size = 0.1,    # 10% of portfolio
        max_drawdown = 0.2,         # 20% drawdown
        max_daily_loss = 0.05,      # 5% daily loss
        max_trade_loss = 0.02,      # 2% per trade
        stop_loss_pct = 0.05,       # 5% stop loss
        take_profit_pct = 0.1,      # 10% take profit
        risk_reward_ratio = 2.0,    # 2:1 risk-reward
        confidence_level = 0.95,    # 95% confidence
        kelly_fraction = 0.5        # Half Kelly
    )

    # Create a risk manager
    portfolio_value = 10000.0  # $10,000 portfolio

    # Generate historical returns
    n_days = 100
    μ = 0.001  # 0.1% daily return
    σ = 0.02   # 2% daily volatility

    historical_returns = rand(Normal(μ, σ), n_days)

    risk_manager = RiskManager(risk_params, portfolio_value, historical_returns)

    # Create a mean reversion strategy
    strategy = MeanReversionStrategy(
        "WETH",
        "USDT",
        chainlink,
        uniswap;
        lookback_period = 20,
        entry_threshold = 2.0,
        exit_threshold = 0.5,
        trade_amount = 1.0,
        stop_loss_pct = 0.05,
        take_profit_pct = 0.1,
        risk_manager = risk_manager
    )

    # Execute the strategy
    println("Executing strategy...")
    result = TradingStrategy.execute_strategy(strategy)

    # Print results
    println("\nResults:")
    println("  Current price: \$$(round(result["current_price"], digits=2))")
    println("  Z-score: $(round(result["z_score"], digits=2))")
    println("  Mean: \$$(round(result["mean"], digits=2))")
    println("  Standard deviation: \$$(round(result["std_dev"], digits=2))")
    println("  Action: $(result["action"])")

    if result["action"] != "HOLD"
        println("  Order ID: $(result["order"].id)")
        if result["stop_loss"] !== nothing
            println("  Stop loss: \$$(round(result["stop_loss"], digits=2))")
        end
        if result["take_profit"] !== nothing
            println("  Take profit: \$$(round(result["take_profit"], digits=2))")
        end
    end

    # Backtest the strategy
    println("\nBacktesting strategy...")
    backtest_result = backtest_strategy(
        strategy,
        now() - Day(365),  # 1 year ago
        now()
    )

    # Print backtest results
    println("\nBacktest Results:")
    println("  Initial equity: \$$(round(backtest_result["initial_equity"], digits=2))")
    println("  Final equity: \$$(round(backtest_result["final_equity"], digits=2))")
    println("  Total return: $(round(backtest_result["total_return"], digits=2))%")
    println("  Max drawdown: $(round(backtest_result["max_drawdown"], digits=2))%")
    println("  Total trades: $(backtest_result["total_trades"])")
    println("  Win rate: $(round(backtest_result["win_rate"], digits=2))%")

    # Print some sample trades
    println("\nSample trades:")
    for (i, trade) in enumerate(backtest_result["trades"][1:min(5, length(backtest_result["trades"]))])
        println("  Trade $i: $(trade["type"]) at \$$(round(trade["price"], digits=2)) on $(trade["timestamp"])")
        if haskey(trade, "profit")
            println("    Profit: \$$(round(trade["profit"], digits=2))")
        end
    end

    return Dict(
        "strategy" => strategy,
        "result" => result,
        "backtest_result" => backtest_result
    )
end

# Run the example if this file is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    result = run_mean_reversion_example()
end
