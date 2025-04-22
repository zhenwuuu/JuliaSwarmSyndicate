"""
    price_feed_example.jl

Example demonstrating price feed integration and trading strategies in JuliaOS.
"""

# Add the parent directory to the load path
push!(LOAD_PATH, joinpath(@__DIR__, ".."))

# Import required modules
using Random
using Statistics
using Dates

# Import JuliaOS modules
include("../julia/src/dex/DEXBase.jl")
include("../julia/src/dex/UniswapDEX.jl")
include("../julia/src/price/PriceFeeds.jl")
include("../julia/src/swarm/SwarmBase.jl")
include("../julia/src/swarm/algorithms/DEPSO.jl")

# Note: PriceFeeds must be included before TradingStrategy
include("../julia/src/trading/TradingStrategy.jl")
# MovingAverageStrategy is included in TradingStrategy

using .DEXBase
using .UniswapDEX
using .PriceFeeds
using .SwarmBase
using .DEPSO
using .TradingStrategy
# MovingAverageStrategy is re-exported by TradingStrategy

# Set random seed for reproducibility
Random.seed!(42)

"""
    run_price_feed_example()

Run a price feed example using Chainlink.
"""
function run_price_feed_example()
    println("Price Feed Example")
    println("=================")

    # Create a Chainlink price feed configuration
    chainlink_config = PriceFeedConfig(
        name = "Chainlink",
        base_url = "https://api.chain.link/v1"
    )

    # Create a Chainlink price feed
    chainlink = create_chainlink_feed(chainlink_config)

    # Get information about the price feed
    info = PriceFeeds.get_price_feed_info(chainlink)

    println("Price feed: $(info["name"])")
    println("Supported pairs: $(length(info["supported_pairs"]))")

    # List some supported pairs
    println("\nSupported pairs:")
    for pair in info["supported_pairs"][1:min(5, length(info["supported_pairs"]))]
        println("  $pair")
    end

    # Get the latest price for ETH/USD
    latest_price = PriceFeeds.get_latest_price(chainlink, "ETH", "USD")

    println("\nLatest ETH/USD price:")
    println("  Price: \$$(latest_price.price)")
    println("  Timestamp: $(latest_price.timestamp)")

    # Get historical prices for ETH/USD
    historical_prices = PriceFeeds.get_historical_prices(
        chainlink,
        "ETH",
        "USD";
        interval = "1d",
        limit = 30
    )

    println("\nHistorical ETH/USD prices (last 30 days):")
    println("  Number of data points: $(length(historical_prices.points))")
    println("  First data point: \$$(historical_prices.points[1].price) at $(historical_prices.points[1].timestamp)")
    println("  Last data point: \$$(historical_prices.points[end].price) at $(historical_prices.points[end].timestamp)")

    # Calculate some statistics
    prices = [point.price for point in historical_prices.points]
    avg_price = mean(prices)
    min_price = minimum(prices)
    max_price = maximum(prices)

    println("\nETH/USD price statistics:")
    println("  Average price: \$$(round(avg_price, digits=2))")
    println("  Minimum price: \$$(round(min_price, digits=2))")
    println("  Maximum price: \$$(round(max_price, digits=2))")
    println("  Volatility: $(round(std(prices) / avg_price * 100, digits=2))%")

    return Dict(
        "feed" => chainlink,
        "latest_price" => latest_price,
        "historical_prices" => historical_prices
    )
end

"""
    run_moving_average_strategy_example()

Run a moving average crossover strategy example.
"""
function run_moving_average_strategy_example()
    println("\nMoving Average Crossover Strategy Example")
    println("========================================")

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

    # Create a moving average crossover strategy
    # Note: Using WETH/USDT instead of ETH/USD since that's what Uniswap has
    strategy = MovingAverageCrossoverStrategy(
        "WETH",
        "USDT",
        chainlink,
        uniswap;
        short_window = 10,
        long_window = 30,
        trade_amount = 1.0,
        stop_loss_pct = 5.0,
        take_profit_pct = 10.0
    )

    # Execute the strategy
    println("Executing strategy...")
    result = TradingStrategy.execute_strategy(strategy)

    # Print results
    println("\nResults:")
    println("  Current price: \$$(round(result["current_price"], digits=2))")
    println("  Short MA ($(strategy.short_window) days): \$$(round(result["short_ma"], digits=2))")
    println("  Long MA ($(strategy.long_window) days): \$$(round(result["long_ma"], digits=2))")
    println("  Action: $(result["action"])")

    if result["action"] != "HOLD"
        println("  Order ID: $(result["order"].id)")
        println("  Stop loss: \$$(round(result["stop_loss"], digits=2))")
        println("  Take profit: \$$(round(result["take_profit"], digits=2))")
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

    return Dict(
        "strategy" => strategy,
        "result" => result,
        "backtest_result" => backtest_result
    )
end

# Run all examples if this file is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    price_feed_result = run_price_feed_example()
    moving_average_result = run_moving_average_strategy_example()
end
