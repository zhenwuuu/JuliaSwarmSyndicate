"""
    defi_trading_example.jl

Example demonstrating DeFi trading using JuliaOS.
"""

# Add the parent directory to the load path
push!(LOAD_PATH, joinpath(@__DIR__, ".."))

# Import required modules
using Random
using Statistics
using LinearAlgebra
using Dates

# Import JuliaOS modules
include("../julia/src/dex/DEXBase.jl")
include("../julia/src/dex/UniswapDEX.jl")
include("../julia/src/dex/SushiswapDEX.jl")
include("../julia/src/swarm/SwarmBase.jl")
include("../julia/src/swarm/algorithms/DEPSO.jl")
include("../julia/src/trading/TradingStrategy.jl")

using .DEXBase
using .UniswapDEX
using .SushiswapDEX
using .SwarmBase
using .DEPSO
using .TradingStrategy

# Set random seed for reproducibility
Random.seed!(42)

"""
    run_portfolio_optimization_example()

Run a portfolio optimization example using DEPSO.
"""
function run_portfolio_optimization_example()
    println("Portfolio Optimization Example")
    println("==============================")

    # Create DEX configurations
    uniswap_config = DEXConfig(
        name = "Uniswap V2",
        chain_id = 1,  # Ethereum mainnet
        rpc_url = "https://mainnet.infura.io/v3/your-api-key",
        router_address = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
        factory_address = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f"
    )

    # Create DEX instances
    uniswap = UniswapV2(uniswap_config)

    # Get tokens from Uniswap
    tokens = DEXBase.get_tokens(uniswap)

    # Select a subset of tokens for the portfolio
    n_tokens_to_select = min(4, length(tokens))
    selected_tokens = tokens[1:n_tokens_to_select]  # First few tokens

    println("Selected tokens for portfolio:")
    for (i, token) in enumerate(selected_tokens)
        println("  $i. $(token.symbol) ($(token.name))")
    end

    # Generate mock historical prices
    n_days = 100
    n_tokens = length(selected_tokens)
    historical_prices = zeros(n_days, n_tokens)

    # Initial prices
    initial_prices = [1800.0, 1.0, 1.0, 300.0]  # Example initial prices

    # Generate random price movements
    for i in 1:n_tokens
        historical_prices[1, i] = initial_prices[i]
        for j in 2:n_days
            # Random daily return between -5% and +5%
            daily_return = 1.0 + (rand() * 0.1 - 0.05)
            historical_prices[j, i] = historical_prices[j-1, i] * daily_return
        end
    end

    # Create portfolio optimization strategy
    strategy = OptimalPortfolioStrategy(
        selected_tokens;
        risk_tolerance = 0.7,
        max_iterations = 50,
        population_size = 30
    )

    # Execute the strategy
    println("\nOptimizing portfolio...")
    result = execute_strategy(strategy, historical_prices)

    # Print results
    println("\nResults:")
    println("  Optimal weights:")
    for (i, (token, weight)) in enumerate(zip(selected_tokens, result["optimal_weights"]))
        println("    $(token.symbol): $(round(weight * 100, digits=2))%")
    end
    println("  Expected return: $(round(result["expected_return"] * 100, digits=2))%")
    println("  Risk: $(round(result["risk"] * 100, digits=2))%")
    println("  Sharpe ratio: $(round(result["sharpe_ratio"], digits=2))")

    return result
end

"""
    run_arbitrage_example()

Run an arbitrage example across multiple DEXes.
"""
function run_arbitrage_example()
    println("\nArbitrage Example")
    println("=================")

    # Create DEX configurations
    uniswap_config = DEXConfig(
        name = "Uniswap V2",
        chain_id = 1,  # Ethereum mainnet
        rpc_url = "https://mainnet.infura.io/v3/your-api-key",
        router_address = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
        factory_address = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f"
    )

    sushiswap_config = DEXConfig(
        name = "Sushiswap",
        chain_id = 1,  # Ethereum mainnet
        rpc_url = "https://mainnet.infura.io/v3/your-api-key",
        router_address = "0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F",
        factory_address = "0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac"
    )

    # Create DEX instances
    uniswap = UniswapV2(uniswap_config)
    sushiswap = create_sushiswap(sushiswap_config)

    # Get tokens from both DEXes
    uniswap_tokens = DEXBase.get_tokens(uniswap)
    sushiswap_tokens = DEXBase.get_tokens(sushiswap)

    # Find common tokens
    common_tokens = DEXToken[]
    for uniswap_token in uniswap_tokens
        for sushiswap_token in sushiswap_tokens
            if uniswap_token.address == sushiswap_token.address
                push!(common_tokens, uniswap_token)
                break
            end
        end
    end

    println("Found $(length(common_tokens)) common tokens across DEXes:")
    for (i, token) in enumerate(common_tokens)
        println("  $i. $(token.symbol) ($(token.name))")
    end

    # Create arbitrage strategy
    strategy = ArbitrageStrategy(
        [uniswap, sushiswap],
        common_tokens;
        min_profit_threshold = 0.5,  # 0.5% minimum profit
        max_iterations = 50,
        population_size = 30
    )

    # Execute the strategy
    println("\nFinding arbitrage opportunities...")
    result = execute_strategy(strategy)

    # Print results
    println("\nResults:")
    println("  Found $(result["num_opportunities"]) arbitrage opportunities")

    if result["num_opportunities"] > 0
        println("\nTop opportunities:")
        for (i, opportunity) in enumerate(result["opportunities"])
            if i > 3  # Show only top 3
                break
            end

            token_a = opportunity["token_a"]
            token_b = opportunity["token_b"]

            println("  $i. $(token_a.symbol) <-> $(token_b.symbol)")
            println("     Buy on: $(opportunity["buy_dex"]) at price: $(round(opportunity["buy_price"], digits=6))")
            println("     Sell on: $(opportunity["sell_dex"]) at price: $(round(opportunity["sell_price"], digits=6))")
            println("     Profit: $(round(opportunity["profit_percentage"], digits=2))%")
        end
    end

    return result
end

"""
    run_trading_simulation()

Run a simple trading simulation.
"""
function run_trading_simulation()
    println("\nTrading Simulation")
    println("==================")

    # Create DEX configuration
    uniswap_config = DEXConfig(
        name = "Uniswap V2",
        chain_id = 1,  # Ethereum mainnet
        rpc_url = "https://mainnet.infura.io/v3/your-api-key",
        router_address = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D",
        factory_address = "0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f"
    )

    # Create DEX instance
    uniswap = UniswapV2(uniswap_config)

    # Get tokens and pairs
    tokens = DEXBase.get_tokens(uniswap)
    pairs = DEXBase.get_pairs(uniswap)

    # Select a trading pair
    selected_pair = pairs[1]  # First pair

    println("Selected trading pair: $(selected_pair.token0.symbol)/$(selected_pair.token1.symbol)")

    # Get current price and liquidity
    price = DEXBase.get_price(uniswap, selected_pair)
    liquidity = DEXBase.get_liquidity(uniswap, selected_pair)

    println("Current price: $price")
    println("Current liquidity: $(liquidity[1]) $(selected_pair.token0.symbol), $(liquidity[2]) $(selected_pair.token1.symbol)")

    # Simulate a trade
    println("\nSimulating a trade...")

    # Create a market buy order
    order_amount = 1.0  # Buy 1 unit of the base token
    order = DEXBase.create_order(
        uniswap,
        selected_pair,
        DEXBase.MARKET,  # Use the enum value directly
        DEXBase.BUY,     # Use the enum value directly
        order_amount
    )

    println("Created order: ID=$(order.id), Type=$(order.order_type), Side=$(order.side), Amount=$(order.amount)")

    # Wait for the order to be filled (in a real implementation, this would be asynchronous)
    println("Waiting for order to be filled...")
    sleep(1)

    # Get the order status
    updated_order = DEXBase.get_order_status(uniswap, order.id)

    println("Order status: $(updated_order.status)")

    # Get recent trades
    trades = DEXBase.get_trades(uniswap, selected_pair, limit=5)

    println("\nRecent trades:")
    for (i, trade) in enumerate(trades)
        println("  $i. ID=$(trade.id), Side=$(trade.side), Amount=$(trade.amount), Price=$(trade.price)")
    end

    return Dict(
        "pair" => selected_pair,
        "price" => price,
        "liquidity" => liquidity,
        "order" => order,
        "trades" => trades
    )
end

# Run all examples if this file is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    portfolio_result = run_portfolio_optimization_example()
    arbitrage_result = run_arbitrage_example()
    trading_result = run_trading_simulation()
end
