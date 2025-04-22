"""
TradingStrategy.jl - Trading strategies for DeFi

This module provides trading strategies for DeFi using swarm optimization algorithms.
"""
module TradingStrategy

export AbstractStrategy, OptimalPortfolioStrategy, ArbitrageStrategy, MovingAverageCrossoverStrategy, MeanReversionStrategy
export optimize_portfolio, find_arbitrage_opportunities, execute_strategy, backtest_strategy
# Export from RiskManagement
export RiskParameters, PositionSizer, StopLossManager, RiskManager
export calculate_position_size, set_stop_loss, set_take_profit, check_risk_limits
export calculate_value_at_risk, calculate_expected_shortfall, calculate_kelly_criterion

using ..DEXBase
using ..SwarmBase
using ..DEPSO
using ..PriceFeeds
using Statistics  # For mean, cov functions

"""
    AbstractStrategy

Abstract type for trading strategies.
"""
abstract type AbstractStrategy end

"""
    OptimalPortfolioStrategy <: AbstractStrategy

Strategy for optimizing a portfolio of tokens.

# Fields
- `tokens::Vector{DEXToken}`: The tokens in the portfolio
- `initial_weights::Vector{Float64}`: The initial weights of the tokens
- `risk_tolerance::Float64`: The risk tolerance (0-1)
- `max_iterations::Int`: Maximum number of iterations for optimization
- `population_size::Int`: Population size for the swarm algorithm
"""
struct OptimalPortfolioStrategy <: AbstractStrategy
    tokens::Vector{DEXToken}
    initial_weights::Vector{Float64}
    risk_tolerance::Float64
    max_iterations::Int
    population_size::Int

    function OptimalPortfolioStrategy(
        tokens::Vector{DEXToken},
        initial_weights::Vector{Float64} = Float64[];
        risk_tolerance::Float64 = 0.5,
        max_iterations::Int = 100,
        population_size::Int = 50
    )
        # Validate inputs
        if !isempty(initial_weights) && length(tokens) != length(initial_weights)
            error("Number of tokens must match number of weights")
        end

        if !isempty(initial_weights) && !isapprox(sum(initial_weights), 1.0, atol=1e-6)
            error("Weights must sum to 1.0")
        end

        if risk_tolerance < 0.0 || risk_tolerance > 1.0
            error("Risk tolerance must be between 0 and 1")
        end

        # If no initial weights provided, use equal weights
        if isempty(initial_weights)
            initial_weights = fill(1.0 / length(tokens), length(tokens))
        end

        new(tokens, initial_weights, risk_tolerance, max_iterations, population_size)
    end
end

"""
    ArbitrageStrategy <: AbstractStrategy

Strategy for finding and executing arbitrage opportunities.

# Fields
- `dexes::Vector{AbstractDEX}`: The DEXes to search for arbitrage
- `tokens::Vector{DEXToken}`: The tokens to consider for arbitrage
- `min_profit_threshold::Float64`: Minimum profit threshold (percentage)
- `max_iterations::Int`: Maximum number of iterations for optimization
- `population_size::Int`: Population size for the swarm algorithm
"""
struct ArbitrageStrategy <: AbstractStrategy
    dexes::Vector{AbstractDEX}
    tokens::Vector{DEXToken}
    min_profit_threshold::Float64
    max_iterations::Int
    population_size::Int

    function ArbitrageStrategy(
        dexes::Vector{AbstractDEX},
        tokens::Vector{DEXToken};
        min_profit_threshold::Float64 = 0.5,
        max_iterations::Int = 100,
        population_size::Int = 50
    )
        # Validate inputs
        if isempty(dexes)
            error("At least one DEX must be provided")
        end

        if length(tokens) < 2
            error("At least two tokens must be provided")
        end

        if min_profit_threshold < 0.0
            error("Minimum profit threshold must be non-negative")
        end

        new(dexes, tokens, min_profit_threshold, max_iterations, population_size)
    end
end

# ===== Portfolio Optimization =====

"""
    calculate_expected_return(weights::Vector{Float64}, historical_returns::Vector{Float64})

Calculate the expected return of a portfolio.

# Arguments
- `weights::Vector{Float64}`: The weights of the tokens
- `historical_returns::Vector{Float64}`: The historical returns of the tokens

# Returns
- `Float64`: The expected return
"""
function calculate_expected_return(weights::Vector{Float64}, historical_returns::Vector{Float64})
    return sum(weights .* historical_returns)
end

"""
    calculate_portfolio_variance(weights::Vector{Float64}, covariance_matrix::Matrix{Float64})

Calculate the variance of a portfolio.

# Arguments
- `weights::Vector{Float64}`: The weights of the tokens
- `covariance_matrix::Matrix{Float64}`: The covariance matrix of the tokens

# Returns
- `Float64`: The portfolio variance
"""
function calculate_portfolio_variance(weights::Vector{Float64}, covariance_matrix::Matrix{Float64})
    return weights' * covariance_matrix * weights
end

"""
    calculate_sharpe_ratio(weights::Vector{Float64}, historical_returns::Vector{Float64},
                         covariance_matrix::Matrix{Float64}, risk_free_rate::Float64=0.0)

Calculate the Sharpe ratio of a portfolio.

# Arguments
- `weights::Vector{Float64}`: The weights of the tokens
- `historical_returns::Vector{Float64}`: The historical returns of the tokens
- `covariance_matrix::Matrix{Float64}`: The covariance matrix of the tokens
- `risk_free_rate::Float64`: The risk-free rate

# Returns
- `Float64`: The Sharpe ratio
"""
function calculate_sharpe_ratio(weights::Vector{Float64}, historical_returns::Vector{Float64},
                              covariance_matrix::Matrix{Float64}, risk_free_rate::Float64=0.0)
    expected_return = calculate_expected_return(weights, historical_returns)
    portfolio_variance = calculate_portfolio_variance(weights, covariance_matrix)

    if portfolio_variance == 0.0
        return 0.0
    end

    return (expected_return - risk_free_rate) / sqrt(portfolio_variance)
end

"""
    optimize_portfolio(strategy::OptimalPortfolioStrategy, historical_prices::Matrix{Float64})

Optimize a portfolio using the DEPSO algorithm.

# Arguments
- `strategy::OptimalPortfolioStrategy`: The portfolio optimization strategy
- `historical_prices::Matrix{Float64}`: The historical prices of the tokens (rows = time, cols = tokens)

# Returns
- `Tuple{Vector{Float64}, Float64, Float64}`: The optimal weights, expected return, and risk
"""
function optimize_portfolio(strategy::OptimalPortfolioStrategy, historical_prices::Matrix{Float64})
    # Calculate historical returns
    n_periods, n_tokens = size(historical_prices)

    if n_tokens != length(strategy.tokens)
        error("Number of tokens in historical prices must match number of tokens in strategy")
    end

    if n_periods < 2
        error("At least two periods of historical prices are required")
    end

    # Calculate daily returns
    returns = zeros(n_periods - 1, n_tokens)
    for i in 1:n_periods-1
        for j in 1:n_tokens
            returns[i, j] = (historical_prices[i+1, j] - historical_prices[i, j]) / historical_prices[i, j]
        end
    end

    # Calculate mean returns and covariance matrix
    mean_returns = vec(mean(returns, dims=1))
    covariance_matrix = cov(returns)

    # Define the objective function (negative Sharpe ratio)
    function objective(weights::Vector{Float64})
        # Ensure weights sum to 1
        weights = weights ./ sum(weights)

        # Calculate Sharpe ratio
        sharpe = calculate_sharpe_ratio(weights, mean_returns, covariance_matrix)

        # Return negative Sharpe ratio (we want to maximize Sharpe ratio)
        return -sharpe
    end

    # Define the optimization problem
    problem = OptimizationProblem(
        n_tokens,
        [(0.0, 1.0) for _ in 1:n_tokens],  # Bounds: weights between 0 and 1
        objective;
        is_minimization = true
    )

    # Define the DEPSO algorithm
    algorithm = HybridDEPSO(
        population_size = strategy.population_size,
        max_iterations = strategy.max_iterations,
        F = 0.8,
        CR = 0.9,
        w = 0.7,
        c1 = 1.5,
        c2 = 1.5,
        hybrid_ratio = 0.5,
        adaptive = true
    )

    # Run the optimization
    result = DEPSO.optimize(problem, algorithm)

    # Normalize weights to sum to 1
    optimal_weights = result.best_position ./ sum(result.best_position)

    # Calculate expected return and risk
    expected_return = calculate_expected_return(optimal_weights, mean_returns)
    risk = sqrt(calculate_portfolio_variance(optimal_weights, covariance_matrix))

    return (optimal_weights, expected_return, risk)
end

# ===== Arbitrage Opportunities =====

"""
    find_arbitrage_opportunities(strategy::ArbitrageStrategy)

Find arbitrage opportunities across DEXes.

# Arguments
- `strategy::ArbitrageStrategy`: The arbitrage strategy

# Returns
- `Vector{Dict{String, Any}}`: The arbitrage opportunities
"""
function find_arbitrage_opportunities(strategy::ArbitrageStrategy)
    opportunities = Dict{String, Any}[]

    # For each pair of tokens
    for i in 1:length(strategy.tokens)-1
        for j in i+1:length(strategy.tokens)
            token_a = strategy.tokens[i]
            token_b = strategy.tokens[j]

            # Get prices across DEXes
            prices = Dict{String, Float64}()

            for dex in strategy.dexes
                # Find the pair for these tokens
                pairs = DEXBase.get_pairs(dex)

                for pair in pairs
                    if (pair.token0.address == token_a.address && pair.token1.address == token_b.address) ||
                       (pair.token0.address == token_b.address && pair.token1.address == token_a.address)
                        # Get the price
                        price = DEXBase.get_price(dex, pair)

                        # Adjust the price if the pair is reversed
                        if pair.token0.address == token_b.address
                            price = 1.0 / price
                        end

                        prices[dex.config.name] = price
                        break
                    end
                end
            end

            # Check for arbitrage opportunities
            if length(prices) >= 2
                # Find the best buy and sell prices
                best_buy_price = Inf
                best_buy_dex = ""
                best_sell_price = 0.0
                best_sell_dex = ""

                for (dex_name, price) in prices
                    if price < best_buy_price
                        best_buy_price = price
                        best_buy_dex = dex_name
                    end

                    if price > best_sell_price
                        best_sell_price = price
                        best_sell_dex = dex_name
                    end
                end

                # Calculate the profit percentage
                profit_percentage = (best_sell_price - best_buy_price) / best_buy_price * 100.0

                # If the profit is above the threshold, add it to the opportunities
                if profit_percentage >= strategy.min_profit_threshold
                    push!(opportunities, Dict(
                        "token_a" => token_a,
                        "token_b" => token_b,
                        "buy_dex" => best_buy_dex,
                        "buy_price" => best_buy_price,
                        "sell_dex" => best_sell_dex,
                        "sell_price" => best_sell_price,
                        "profit_percentage" => profit_percentage
                    ))
                end
            end
        end
    end

    # Sort opportunities by profit percentage (descending)
    sort!(opportunities, by = x -> x["profit_percentage"], rev = true)

    return opportunities
end

"""
    execute_strategy(strategy::AbstractStrategy, args...)

Execute a trading strategy.

# Arguments
- `strategy::AbstractStrategy`: The trading strategy
- `args...`: Additional arguments specific to the strategy

# Returns
- `Dict{String, Any}`: The result of the strategy execution
"""
function execute_strategy(strategy::OptimalPortfolioStrategy, historical_prices::Matrix{Float64})
    # Optimize the portfolio
    optimal_weights, expected_return, risk = optimize_portfolio(strategy, historical_prices)

    # Return the result
    return Dict(
        "strategy_type" => "OptimalPortfolioStrategy",
        "tokens" => strategy.tokens,
        "optimal_weights" => optimal_weights,
        "expected_return" => expected_return,
        "risk" => risk,
        "sharpe_ratio" => expected_return / risk
    )
end

function execute_strategy(strategy::ArbitrageStrategy)
    # Find arbitrage opportunities
    opportunities = find_arbitrage_opportunities(strategy)

    # Return the result
    return Dict(
        "strategy_type" => "ArbitrageStrategy",
        "opportunities" => opportunities,
        "num_opportunities" => length(opportunities)
    )
end

# Include additional strategy modules
include("MovingAverageStrategy.jl")
include("RiskManagement.jl")
include("MeanReversionImpl.jl")

# Re-export from submodules
using .MovingAverageStrategy
using .RiskManagement
using .MeanReversionImpl

end # module
