module QuantFinance

using Statistics
using LinearAlgebra
using DataFrames
using Distributions
using Dates
using Random
using Optim

# Submodules
include("quantfinance/Portfolio.jl")
include("quantfinance/RiskManagement.jl")
include("quantfinance/Derivatives.jl")
include("quantfinance/MarketData.jl")

# Export main functions
export optimize_portfolio, calculate_portfolio_return, calculate_portfolio_risk
export calculate_var, calculate_cvar, calculate_sharpe_ratio
export optimal_hedge_ratio, back_test_strategy, monte_carlo_simulation
export calculate_option_price, calculate_implied_volatility
export handle_market_data, calculate_technical_indicators
export build_trading_strategy, execute_trade, simulate_market_impact

"""
    optimize_portfolio(returns::Matrix{Float64}, 
                      method::String="markowitz"; 
                      risk_free_rate::Float64=0.0, 
                      target_return::Union{Nothing,Float64}=nothing, 
                      max_risk::Union{Nothing,Float64}=nothing)

Optimize a portfolio using various methods: Markowitz, Minimum Variance, Risk Parity, etc.
"""
function optimize_portfolio(returns::Matrix{Float64}, 
                           method::String="markowitz"; 
                           risk_free_rate::Float64=0.0, 
                           target_return::Union{Nothing,Float64}=nothing, 
                           max_risk::Union{Nothing,Float64}=nothing)
    
    # Delegate to the appropriate submodule function
    return Portfolio.optimize_portfolio(returns, method, 
                                      risk_free_rate=risk_free_rate, 
                                      target_return=target_return, 
                                      max_risk=max_risk)
end

"""
    calculate_portfolio_return(weights::Vector{Float64}, returns::Matrix{Float64})

Calculate expected portfolio return based on historical returns.
"""
function calculate_portfolio_return(weights::Vector{Float64}, returns::Matrix{Float64})
    return Portfolio.calculate_portfolio_return(weights, returns)
end

"""
    calculate_portfolio_risk(weights::Vector{Float64}, returns::Matrix{Float64})

Calculate portfolio risk (standard deviation) based on historical returns.
"""
function calculate_portfolio_risk(weights::Vector{Float64}, returns::Matrix{Float64})
    return Portfolio.calculate_portfolio_risk(weights, returns)
end

"""
    calculate_var(weights::Vector{Float64}, returns::Matrix{Float64}; 
                confidence_level::Float64=0.95, 
                method::String="historical")

Calculate Value at Risk for a portfolio.
"""
function calculate_var(weights::Vector{Float64}, returns::Matrix{Float64}; 
                      confidence_level::Float64=0.95, 
                      method::String="historical")
    
    return RiskManagement.calculate_var(weights, returns, 
                                      confidence_level=confidence_level, 
                                      method=method)
end

"""
    calculate_cvar(weights::Vector{Float64}, returns::Matrix{Float64}; 
                 confidence_level::Float64=0.95, 
                 method::String="historical")

Calculate Conditional Value at Risk (Expected Shortfall) for a portfolio.
"""
function calculate_cvar(weights::Vector{Float64}, returns::Matrix{Float64}; 
                       confidence_level::Float64=0.95, 
                       method::String="historical")
    
    return RiskManagement.calculate_cvar(weights, returns, 
                                       confidence_level=confidence_level, 
                                       method=method)
end

"""
    calculate_sharpe_ratio(weights::Vector{Float64}, returns::Matrix{Float64}; 
                         risk_free_rate::Float64=0.0)

Calculate Sharpe ratio for a portfolio.
"""
function calculate_sharpe_ratio(weights::Vector{Float64}, returns::Matrix{Float64}; 
                               risk_free_rate::Float64=0.0)
    
    return Portfolio.calculate_sharpe_ratio(weights, returns, 
                                          risk_free_rate=risk_free_rate)
end

"""
    optimal_hedge_ratio(asset_returns::Vector{Float64}, hedge_returns::Vector{Float64})

Calculate optimal hedge ratio between an asset and a hedging instrument.
"""
function optimal_hedge_ratio(asset_returns::Vector{Float64}, hedge_returns::Vector{Float64})
    return RiskManagement.optimal_hedge_ratio(asset_returns, hedge_returns)
end

"""
    back_test_strategy(strategy::Function, 
                      prices::DataFrame, 
                      initial_capital::Float64; 
                      commission::Float64=0.0)

Back-test a trading strategy on historical price data.
"""
function back_test_strategy(strategy::Function, 
                           prices::DataFrame, 
                           initial_capital::Float64; 
                           commission::Float64=0.0)
    
    return Portfolio.back_test_strategy(strategy, prices, initial_capital, 
                                      commission=commission)
end

"""
    monte_carlo_simulation(prices::Matrix{Float64}, 
                          n_simulations::Int=1000, 
                          n_days::Int=252; 
                          method::String="gbm")

Perform Monte Carlo simulation of asset price paths.
"""
function monte_carlo_simulation(prices::Matrix{Float64}, 
                               n_simulations::Int=1000, 
                               n_days::Int=252; 
                               method::String="gbm")
    
    return RiskManagement.monte_carlo_simulation(prices, n_simulations, n_days, 
                                               method=method)
end

"""
    calculate_option_price(spot::Float64, 
                          strike::Float64, 
                          time_to_expiry::Float64, 
                          risk_free_rate::Float64, 
                          volatility::Float64, 
                          option_type::String="call"; 
                          model::String="black_scholes")

Calculate option price using various pricing models.
"""
function calculate_option_price(spot::Float64, 
                               strike::Float64, 
                               time_to_expiry::Float64, 
                               risk_free_rate::Float64, 
                               volatility::Float64, 
                               option_type::String="call"; 
                               model::String="black_scholes")
    
    return Derivatives.calculate_option_price(spot, strike, time_to_expiry, 
                                            risk_free_rate, volatility, option_type, 
                                            model=model)
end

"""
    calculate_implied_volatility(option_price::Float64, 
                                spot::Float64, 
                                strike::Float64, 
                                time_to_expiry::Float64, 
                                risk_free_rate::Float64, 
                                option_type::String="call")

Calculate implied volatility from option price.
"""
function calculate_implied_volatility(option_price::Float64, 
                                     spot::Float64, 
                                     strike::Float64, 
                                     time_to_expiry::Float64, 
                                     risk_free_rate::Float64, 
                                     option_type::String="call")
    
    return Derivatives.calculate_implied_volatility(option_price, spot, strike, 
                                                  time_to_expiry, risk_free_rate, 
                                                  option_type)
end

"""
    handle_market_data(data::DataFrame, 
                     operations::Vector{String}=["clean", "normalize"])

Process market data with various operations.
"""
function handle_market_data(data::DataFrame, 
                          operations::Vector{String}=["clean", "normalize"])
    
    return MarketData.handle_market_data(data, operations)
end

"""
    calculate_technical_indicators(prices::DataFrame, 
                                 indicators::Vector{String}=["sma", "rsi"])

Calculate technical indicators for a price series.
"""
function calculate_technical_indicators(prices::DataFrame, 
                                      indicators::Vector{String}=["sma", "rsi"])
    
    return MarketData.calculate_technical_indicators(prices, indicators)
end

"""
    build_trading_strategy(indicators::DataFrame, 
                         rules::Dict{String,Any})

Build a trading strategy based on technical indicators and rules.
"""
function build_trading_strategy(indicators::DataFrame, 
                              rules::Dict{String,Any})
    
    return MarketData.build_trading_strategy(indicators, rules)
end

"""
    execute_trade(asset::String, 
                quantity::Float64, 
                price::Float64, 
                action::String="buy"; 
                slippage::Float64=0.0, 
                commission::Float64=0.0)

Simulate trade execution with slippage and commission.
"""
function execute_trade(asset::String, 
                      quantity::Float64, 
                      price::Float64, 
                      action::String="buy"; 
                      slippage::Float64=0.0, 
                      commission::Float64=0.0)
    
    return MarketData.execute_trade(asset, quantity, price, action, 
                                  slippage=slippage, commission=commission)
end

"""
    simulate_market_impact(quantity::Float64, 
                         avg_daily_volume::Float64, 
                         volatility::Float64)

Simulate market impact of a trade based on size and volume.
"""
function simulate_market_impact(quantity::Float64, 
                              avg_daily_volume::Float64, 
                              volatility::Float64)
    
    return MarketData.simulate_market_impact(quantity, avg_daily_volume, volatility)
end

end # module 