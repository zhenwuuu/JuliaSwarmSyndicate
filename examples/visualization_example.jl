"""
    visualization_example.jl

Example demonstrating visualization tools in JuliaOS.
"""

# Add the parent directory to the load path
push!(LOAD_PATH, joinpath(@__DIR__, ".."))

# Import required modules
using Random
using Statistics
using Dates
using Distributions
using Plots

# Import JuliaOS modules
include("../julia/src/dex/DEXBase.jl")
include("../julia/src/dex/UniswapDEX.jl")
include("../julia/src/price/PriceFeeds.jl")
include("../julia/src/swarm/SwarmBase.jl")
include("../julia/src/swarm/algorithms/DEPSO.jl")
include("../julia/src/trading/TradingStrategy.jl")
include("../julia/src/visualization/Visualization.jl")

using .DEXBase
using .UniswapDEX
using .PriceFeeds
using .SwarmBase
using .DEPSO
using .TradingStrategy
using .TradingStrategy.RiskManagement
using .TradingStrategy.MeanReversionImpl
using .Visualization

# Set random seed for reproducibility
Random.seed!(42)

"""
    generate_price_data(n_days::Int, μ::Float64, σ::Float64, start_price::Float64)

Generate synthetic price data.

# Arguments
- `n_days::Int`: Number of days
- `μ::Float64`: Mean daily return
- `σ::Float64`: Standard deviation of daily returns
- `start_price::Float64`: Starting price

# Returns
- `Tuple{Vector{DateTime}, Vector{Float64}}`: Timestamps and prices
"""
function generate_price_data(n_days::Int, μ::Float64, σ::Float64, start_price::Float64)
    # Generate timestamps
    end_date = now()
    start_date = end_date - Day(n_days)
    timestamps = [start_date + Day(i) for i in 0:n_days]
    
    # Generate returns
    returns = rand(Normal(μ, σ), n_days)
    
    # Calculate prices
    prices = zeros(n_days + 1)
    prices[1] = start_price
    
    for i in 1:n_days
        prices[i+1] = prices[i] * (1 + returns[i])
    end
    
    return timestamps, prices
end

"""
    calculate_moving_averages(prices::Vector{Float64}, short_window::Int, long_window::Int)

Calculate moving averages.

# Arguments
- `prices::Vector{Float64}`: The prices
- `short_window::Int`: The short window size
- `long_window::Int`: The long window size

# Returns
- `Tuple{Vector{Float64}, Vector{Float64}}`: Short and long moving averages
"""
function calculate_moving_averages(prices::Vector{Float64}, short_window::Int, long_window::Int)
    n = length(prices)
    short_ma = zeros(n)
    long_ma = zeros(n)
    
    for i in 1:n
        if i >= short_window
            short_ma[i] = mean(prices[i-short_window+1:i])
        else
            short_ma[i] = NaN
        end
        
        if i >= long_window
            long_ma[i] = mean(prices[i-long_window+1:i])
        else
            long_ma[i] = NaN
        end
    end
    
    return short_ma, long_ma
end

"""
    calculate_mean_reversion_bands(prices::Vector{Float64}, lookback_period::Int, threshold::Float64)

Calculate mean reversion bands.

# Arguments
- `prices::Vector{Float64}`: The prices
- `lookback_period::Int`: The lookback period
- `threshold::Float64`: The threshold in standard deviations

# Returns
- `Tuple{Vector{Float64}, Vector{Float64}, Vector{Float64}}`: Mean, upper band, and lower band
"""
function calculate_mean_reversion_bands(prices::Vector{Float64}, lookback_period::Int, threshold::Float64)
    n = length(prices)
    mean_prices = zeros(n)
    upper_band = zeros(n)
    lower_band = zeros(n)
    
    for i in 1:n
        if i > lookback_period
            window = prices[i-lookback_period:i-1]
            μ = mean(window)
            σ = std(window)
            
            mean_prices[i] = μ
            upper_band[i] = μ + threshold * σ
            lower_band[i] = μ - threshold * σ
        else
            mean_prices[i] = NaN
            upper_band[i] = NaN
            lower_band[i] = NaN
        end
    end
    
    return mean_prices, upper_band, lower_band
end

"""
    run_visualization_example()

Run a visualization example.
"""
function run_visualization_example()
    println("Visualization Example")
    println("=====================")
    
    # Generate synthetic price data
    n_days = 100
    μ = 0.001  # 0.1% daily return
    σ = 0.02   # 2% daily volatility
    start_price = 1800.0  # Starting price
    
    timestamps, prices = generate_price_data(n_days, μ, σ, start_price)
    
    # Plot price data
    println("Plotting price data...")
    p1 = plot_price_data(timestamps, prices, title="ETH/USD Price", ylabel="Price (USD)")
    savefig(p1, "price_chart.png")
    display(p1)
    
    # Calculate and plot moving averages
    println("Plotting moving averages...")
    short_window = 10
    long_window = 30
    short_ma, long_ma = calculate_moving_averages(prices, short_window, long_window)
    
    p2 = plot_moving_averages(timestamps, prices, short_ma, long_ma, title="ETH/USD Moving Average Crossover")
    savefig(p2, "moving_averages.png")
    display(p2)
    
    # Calculate and plot mean reversion bands
    println("Plotting mean reversion bands...")
    lookback_period = 20
    threshold = 2.0
    mean_prices, upper_band, lower_band = calculate_mean_reversion_bands(prices, lookback_period, threshold)
    
    p3 = plot_mean_reversion(timestamps, prices, mean_prices, upper_band, lower_band, title="ETH/USD Mean Reversion")
    savefig(p3, "mean_reversion.png")
    display(p3)
    
    # Generate backtest results
    println("Generating backtest results...")
    
    # Create a price feed
    chainlink_config = PriceFeedConfig(
        name = "Chainlink",
        base_url = "https://api.chain.link/v1"
    )
    chainlink = create_chainlink_feed(chainlink_config)
    
    # Create a DEX
    uniswap_config = DEXConfig(
        name = "Uniswap V2",
        chain_id = 1,
        rpc_url = "https://mainnet.infura.io/v3/your-api-key",
        router_address = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
        factory_address = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f"
    )
    uniswap = UniswapV2(uniswap_config)
    
    # Create a mean reversion strategy
    strategy = MeanReversionStrategy(
        "WETH",
        "USDT",
        chainlink,
        uniswap;
        lookback_period = lookback_period,
        entry_threshold = threshold,
        exit_threshold = 0.5,
        trade_amount = 1.0,
        stop_loss_pct = 0.05,
        take_profit_pct = 0.1
    )
    
    # Backtest the strategy
    backtest_result = backtest_strategy(
        strategy,
        now() - Day(365),
        now()
    )
    
    # Plot backtest results
    println("Plotting backtest results...")
    p4 = plot_backtest_results(backtest_result, title="Mean Reversion Strategy Backtest")
    savefig(p4, "backtest_results.png")
    display(p4)
    
    # Extract equity values from backtest results
    trades = backtest_result["trades"]
    
    if !isempty(trades)
        # Extract timestamps and equity values
        trade_timestamps = []
        equity_values = []
        
        # Start with initial equity
        initial_equity = backtest_result["initial_equity"]
        push!(trade_timestamps, trades[1]["timestamp"] - Day(1))
        push!(equity_values, initial_equity)
        
        # Add equity after each trade
        current_equity = initial_equity
        for trade in trades
            if haskey(trade, "profit")
                current_equity += trade["profit"]
                push!(trade_timestamps, trade["timestamp"])
                push!(equity_values, current_equity)
            end
        end
        
        # Plot equity curve
        println("Plotting equity curve...")
        p5 = plot_equity_curve(trade_timestamps, equity_values, title="Equity Curve")
        savefig(p5, "equity_curve.png")
        display(p5)
        
        # Plot drawdown curve
        println("Plotting drawdown curve...")
        p6 = plot_drawdown_curve(trade_timestamps, equity_values, title="Drawdown Curve")
        savefig(p6, "drawdown_curve.png")
        display(p6)
        
        # Plot trade distribution
        println("Plotting trade distribution...")
        p7 = plot_trade_distribution(trades, title="Trade Distribution")
        savefig(p7, "trade_distribution.png")
        display(p7)
        
        # Calculate and plot returns distribution
        println("Plotting returns distribution...")
        returns = []
        for trade in trades
            if haskey(trade, "profit")
                push!(returns, trade["profit"] / trade["value"])
            end
        end
        
        if !isempty(returns)
            p8 = plot_returns_distribution(returns, title="Returns Distribution")
            savefig(p8, "returns_distribution.png")
            display(p8)
        end
    end
    
    println("\nVisualization example completed. Check the current directory for saved plots.")
    
    return Dict(
        "price_chart" => p1,
        "moving_averages" => p2,
        "mean_reversion" => p3,
        "backtest_results" => p4
    )
end

# Run the example if this file is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    result = run_visualization_example()
end
