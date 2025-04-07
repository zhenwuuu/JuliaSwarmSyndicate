module RiskManagement

using Statistics
using LinearAlgebra
using Distributions
using Random
using StatsBase

export calculate_var, calculate_cvar, calculate_expected_shortfall
export calculate_conditional_drawdown_at_risk, calculate_omega_ratio
export calculate_downside_deviation, calculate_ulcer_index
export optimal_hedge_ratio, monte_carlo_simulation
export stress_test, scenario_analysis
export calculate_impermanent_loss, calculate_slippage_impact
export estimate_smart_contract_risk, analyze_cross_chain_risks
export liquidity_concentration_risk, estimate_mev_exposure
export gas_price_risk_analysis, analyze_protocol_correlation

"""
    calculate_var(weights::Vector{Float64}, 
                returns::Matrix{Float64}; 
                confidence_level::Float64=0.95, 
                method::String="historical")

Calculate Value at Risk (VaR) for a portfolio.
"""
function calculate_var(weights::Vector{Float64}, 
                      returns::Matrix{Float64}; 
                      confidence_level::Float64=0.95, 
                      method::String="historical")
    
    # Calculate historical portfolio returns
    portfolio_returns = returns * weights
    
    if method == "historical"
        # Historical VaR - use empirical quantile
        var = -quantile(portfolio_returns, 1 - confidence_level)
        
    elseif method == "parametric"
        # Parametric VaR - assume normal distribution
        μ = mean(portfolio_returns)
        σ = std(portfolio_returns)
        
        # Calculate z-score for the confidence level
        z = quantile(Normal(), confidence_level)
        
        var = -(μ + z * σ)
        
    elseif method == "monte_carlo"
        # Monte Carlo VaR
        n_samples = 10000
        
        # Estimate parameters from historical returns
        μ = mean(portfolio_returns)
        σ = std(portfolio_returns)
        
        # Generate random returns
        sim_returns = rand(Normal(μ, σ), n_samples)
        
        # Calculate VaR from simulated returns
        var = -quantile(sim_returns, 1 - confidence_level)
        
    else
        error("Unknown VaR method: $method")
    end
    
    return var
end

"""
    calculate_cvar(weights::Vector{Float64}, 
                 returns::Matrix{Float64}; 
                 confidence_level::Float64=0.95, 
                 method::String="historical")

Calculate Conditional Value at Risk (CVaR) or Expected Shortfall.
"""
function calculate_cvar(weights::Vector{Float64}, 
                       returns::Matrix{Float64}; 
                       confidence_level::Float64=0.95, 
                       method::String="historical")
    
    # Calculate VaR first
    var = calculate_var(weights, returns, confidence_level=confidence_level, method=method)
    
    # Calculate historical portfolio returns
    portfolio_returns = returns * weights
    
    if method == "historical"
        # Find returns below VaR
        tail_returns = portfolio_returns[portfolio_returns .<= -var]
        
        # CVaR is the average of tail returns
        if isempty(tail_returns)
            cvar = var  # Fallback if no tail returns
        else
            cvar = -mean(tail_returns)
        end
        
    elseif method == "parametric"
        # For normal distribution, CVaR has a closed form
        μ = mean(portfolio_returns)
        σ = std(portfolio_returns)
        
        # Z-score for the confidence level
        z = quantile(Normal(), confidence_level)
        
        # Formula for CVaR under normal distribution
        pdf_z = pdf(Normal(), z)
        cdf_z = cdf(Normal(), z)
        
        # Calculate CVaR
        cvar = -(μ - σ * pdf_z / (1 - confidence_level))
        
    elseif method == "monte_carlo"
        # Monte Carlo CVaR
        n_samples = 10000
        
        # Estimate parameters from historical returns
        μ = mean(portfolio_returns)
        σ = std(portfolio_returns)
        
        # Generate random returns
        sim_returns = rand(Normal(μ, σ), n_samples)
        
        # Find returns below VaR
        tail_returns = sim_returns[sim_returns .<= -var]
        
        # CVaR is the average of tail returns
        if isempty(tail_returns)
            cvar = var  # Fallback if no tail returns
        else
            cvar = -mean(tail_returns)
        end
        
    else
        error("Unknown CVaR method: $method")
    end
    
    return cvar
end

"""
    calculate_expected_shortfall(weights::Vector{Float64}, 
                               returns::Matrix{Float64}; 
                               confidence_level::Float64=0.95)

Calculate Expected Shortfall (ES) - alias for CVaR.
"""
function calculate_expected_shortfall(weights::Vector{Float64}, 
                                    returns::Matrix{Float64}; 
                                    confidence_level::Float64=0.95)
    
    return calculate_cvar(weights, returns, confidence_level=confidence_level)
end

"""
    calculate_conditional_drawdown_at_risk(equity_curve::Vector{Float64}; 
                                         confidence_level::Float64=0.95)

Calculate Conditional Drawdown at Risk (CDaR).
"""
function calculate_conditional_drawdown_at_risk(equity_curve::Vector{Float64}; 
                                              confidence_level::Float64=0.95)
    
    n = length(equity_curve)
    
    if n <= 1
        return 0.0
    end
    
    # Calculate drawdowns
    drawdowns = zeros(n)
    peak_value = equity_curve[1]
    
    for i in 1:n
        # Update peak if we have a new high
        if equity_curve[i] > peak_value
            peak_value = equity_curve[i]
        end
        
        # Calculate drawdown
        drawdowns[i] = (peak_value - equity_curve[i]) / peak_value
    end
    
    # Calculate Drawdown at Risk (DaR)
    dar = quantile(drawdowns, confidence_level)
    
    # Calculate Conditional Drawdown at Risk (CDaR)
    tail_drawdowns = drawdowns[drawdowns .>= dar]
    
    if isempty(tail_drawdowns)
        cdar = dar  # Fallback if no tail drawdowns
    else
        cdar = mean(tail_drawdowns)
    end
    
    return cdar
end

"""
    calculate_omega_ratio(returns::Vector{Float64}; 
                        threshold::Float64=0.0)

Calculate Omega Ratio for a return series.
"""
function calculate_omega_ratio(returns::Vector{Float64}; 
                             threshold::Float64=0.0)
    
    # Separate returns above and below threshold
    gains = returns[returns .> threshold] .- threshold
    losses = threshold .- returns[returns .< threshold]
    
    # Handle edge cases
    if isempty(losses) || sum(losses) ≈ 0.0
        return Inf  # No downside risk
    elseif isempty(gains)
        return 0.0  # No upside potential
    end
    
    # Calculate Omega ratio
    return sum(gains) / sum(losses)
end

"""
    calculate_downside_deviation(returns::Vector{Float64}; 
                               threshold::Float64=0.0)

Calculate downside deviation of returns.
"""
function calculate_downside_deviation(returns::Vector{Float64}; 
                                    threshold::Float64=0.0)
    
    # Get returns below threshold
    downside_returns = returns[returns .< threshold] .- threshold
    
    if isempty(downside_returns)
        return 0.0  # No downside returns
    end
    
    # Calculate downside deviation
    return sqrt(mean(downside_returns.^2))
end

"""
    calculate_ulcer_index(equity_curve::Vector{Float64})

Calculate Ulcer Index, which measures downside risk.
"""
function calculate_ulcer_index(equity_curve::Vector{Float64})
    n = length(equity_curve)
    
    if n <= 1
        return 0.0
    end
    
    # Calculate percentage drawdowns
    drawdowns = zeros(n)
    peak_value = equity_curve[1]
    
    for i in 1:n
        # Update peak if we have a new high
        if equity_curve[i] > peak_value
            peak_value = equity_curve[i]
        end
        
        # Calculate percentage drawdown
        drawdowns[i] = 100.0 * (peak_value - equity_curve[i]) / peak_value
    end
    
    # Ulcer Index is the square root of the mean of squared drawdowns
    return sqrt(mean(drawdowns.^2))
end

"""
    optimal_hedge_ratio(asset_returns::Vector{Float64}, 
                       hedge_returns::Vector{Float64})

Calculate optimal hedge ratio between an asset and a hedging instrument.
"""
function optimal_hedge_ratio(asset_returns::Vector{Float64}, 
                            hedge_returns::Vector{Float64})
    
    # Calculate covariance between asset and hedge returns
    cov_asset_hedge = cov(asset_returns, hedge_returns)
    
    # Calculate variance of hedge returns
    var_hedge = var(hedge_returns)
    
    # Optimal hedge ratio is the negative of the covariance divided by variance
    if var_hedge ≈ 0.0
        return 0.0  # Avoid division by zero
    end
    
    return -cov_asset_hedge / var_hedge
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
    
    n_assets = size(prices, 2)
    
    # Calculate daily returns
    returns = diff(log.(prices), dims=1)
    
    # Calculate return statistics
    μ = vec(mean(returns, dims=1))  # Expected returns
    Σ = cov(returns)  # Covariance matrix
    
    # Initialize simulation results
    simulated_prices = zeros(n_days, n_assets, n_simulations)
    
    # Set initial prices
    initial_prices = prices[end, :]
    
    for sim in 1:n_simulations
        # Current prices start at last observed prices
        current_prices = copy(initial_prices)
        
        # Store initial prices
        simulated_prices[1, :, sim] = current_prices
        
        if method == "gbm"
            # Geometric Brownian Motion simulation
            
            # Generate correlated random returns
            Z = rand(MvNormal(zeros(n_assets), Σ), n_days)'
            
            for day in 2:n_days
                # Update prices using GBM formula
                for asset in 1:n_assets
                    drift = μ[asset] - 0.5 * Σ[asset, asset]
                    diffusion = Z[day-1, asset]
                    
                    # Calculate new price
                    current_prices[asset] *= exp(drift + diffusion)
                end
                
                # Store simulated prices
                simulated_prices[day, :, sim] = current_prices
            end
            
        elseif method == "bootstrap"
            # Historical bootstrap simulation
            n_historical = size(returns, 1)
            
            for day in 2:n_days
                # Sample a random historical return vector
                sample_idx = rand(1:n_historical)
                sample_returns = returns[sample_idx, :]
                
                # Update prices
                current_prices .*= exp.(sample_returns)
                
                # Store simulated prices
                simulated_prices[day, :, sim] = current_prices
            end
            
        else
            error("Unknown simulation method: $method")
        end
    end
    
    return simulated_prices
end

"""
    stress_test(weights::Vector{Float64}, 
                returns::Matrix{Float64}, 
                scenarios::Dict{String,Vector{Float64}})

Perform stress tests on a portfolio under different scenarios.
"""
function stress_test(weights::Vector{Float64}, 
                    returns::Matrix{Float64}, 
                    scenarios::Dict{String,Vector{Float64}})
    
    n_assets = length(weights)
    
    # Check if scenario vectors match number of assets
    for (name, scenario) in scenarios
        if length(scenario) != n_assets
            error("Scenario '$name' has $(length(scenario)) assets, but weights have $n_assets assets")
        end
    end
    
    # Calculate baseline portfolio metrics
    μ = vec(mean(returns, dims=1))  # Expected returns
    Σ = cov(returns)  # Covariance matrix
    
    baseline_return = dot(weights, μ)
    baseline_risk = sqrt(weights' * Σ * weights)
    
    # Initialize results
    results = Dict{String,Dict{String,Float64}}()
    
    # Calculate portfolio impact for each scenario
    for (name, scenario) in scenarios
        # Calculate scenario return
        scenario_return = dot(weights, scenario)
        
        # Calculate absolute and percentage changes
        abs_change = scenario_return - baseline_return
        pct_change = abs_change / baseline_return * 100.0
        
        # Store results
        results[name] = Dict(
            "scenario_return" => scenario_return,
            "abs_change" => abs_change,
            "pct_change" => pct_change
        )
    end
    
    return results
end

"""
    scenario_analysis(weights::Vector{Float64}, 
                     returns::Matrix{Float64}, 
                     shift_matrix::Matrix{Float64})

Perform scenario analysis on a portfolio with a shift matrix.
"""
function scenario_analysis(weights::Vector{Float64}, 
                          returns::Matrix{Float64}, 
                          shift_matrix::Matrix{Float64})
    
    n_assets = length(weights)
    n_scenarios = size(shift_matrix, 1)
    
    if size(shift_matrix, 2) != n_assets
        error("Shift matrix has $(size(shift_matrix, 2)) assets, but weights have $n_assets assets")
    end
    
    # Calculate baseline portfolio metrics
    μ = vec(mean(returns, dims=1))  # Expected returns
    Σ = cov(returns)  # Covariance matrix
    
    baseline_return = dot(weights, μ)
    baseline_risk = sqrt(weights' * Σ * weights)
    
    # Initialize results
    scenario_returns = zeros(n_scenarios)
    
    # Calculate portfolio return for each scenario
    for i in 1:n_scenarios
        # Apply scenario shift to expected returns
        scenario_μ = μ .+ shift_matrix[i, :]
        
        # Calculate scenario return
        scenario_returns[i] = dot(weights, scenario_μ)
    end
    
    return Dict(
        "baseline_return" => baseline_return,
        "baseline_risk" => baseline_risk,
        "scenario_returns" => scenario_returns,
        "min_return" => minimum(scenario_returns),
        "max_return" => maximum(scenario_returns),
        "mean_return" => mean(scenario_returns),
        "std_return" => std(scenario_returns)
    )
end

# Web3/DeFi Specific Risk Management Functions

"""
    calculate_impermanent_loss(price_ratio::Float64)

Calculate impermanent loss for an AMM liquidity position given the price ratio change.
Price ratio is defined as final_price / initial_price.
"""
function calculate_impermanent_loss(price_ratio::Float64)
    if price_ratio <= 0
        error("Price ratio must be positive")
    end
    
    # Impermanent loss formula: 2*sqrt(price_ratio)/(1+price_ratio) - 1
    il = (2 * sqrt(price_ratio) / (1 + price_ratio)) - 1
    
    # Return as a percentage loss (negative value)
    return il
end

"""
    calculate_slippage_impact(
        trade_size::Float64, 
        pool_size::Float64;
        pool_type::String="constant-product", 
        concentration_factor::Float64=1.0
    )

Calculate expected slippage impact for a trade in a liquidity pool.
"""
function calculate_slippage_impact(
        trade_size::Float64, 
        pool_size::Float64;
        pool_type::String="constant-product", 
        concentration_factor::Float64=1.0
    )
    
    if trade_size <= 0 || pool_size <= 0
        error("Trade size and pool size must be positive")
    end
    
    # Ratio of trade to pool
    ratio = trade_size / pool_size
    
    if pool_type == "constant-product"
        # For Uniswap v2 style pools: k = x * y
        # Slippage increases with square of trade size
        slippage = ratio / (1 - ratio)
        
    elseif pool_type == "concentrated-liquidity"
        # For Uniswap v3 style pools with concentrated liquidity
        # Concentration factor represents how concentrated the liquidity is
        # Higher values = lower slippage for same trade size
        slippage = ratio / (concentration_factor * (1 - ratio))
        
    elseif pool_type == "stable-swap"
        # For Curve-style stable pools
        # Approximation: slippage is much lower for stable pools
        slippage = ratio^3 / 3
        
    else
        error("Unknown pool type: $pool_type")
    end
    
    # Cap slippage at 100%
    return min(slippage, 1.0)
end

"""
    estimate_smart_contract_risk(
        audit_score::Float64,
        code_complexity::Float64,
        time_deployed::Float64;
        hack_history::Int=0,
        tvl::Float64=0.0
    )

Estimate smart contract risk based on multiple factors.
Returns a risk score between 0 (lowest risk) and 1 (highest risk).
"""
function estimate_smart_contract_risk(
        audit_score::Float64,
        code_complexity::Float64,
        time_deployed::Float64;
        hack_history::Int=0,
        tvl::Float64=0.0
    )
    
    # Normalize inputs
    norm_audit = 1 - clamp(audit_score / 10.0, 0.0, 1.0)  # Invert so higher is riskier
    norm_complexity = clamp(code_complexity / 10.0, 0.0, 1.0)
    
    # Time factor (newer contracts are riskier)
    # Assumes time_deployed is in days
    time_factor = exp(-time_deployed / 365.0)  # Exponential decay of risk over time
    
    # Hack history factor
    hack_factor = min(hack_history, 3) / 3.0
    
    # TVL factor (higher TVL = more attack incentive, but also more scrutiny)
    # Assumes TVL in millions USD
    tvl_factor = 0.0
    if tvl > 0
        tvl_log = log10(max(tvl, 0.1))
        tvl_factor = clamp(tvl_log / 3.0, 0.0, 1.0)
    end
    
    # Combine factors with weights
    weights = [0.3, 0.25, 0.2, 0.15, 0.1]  # Must sum to 1.0
    risk_score = dot(weights, [norm_audit, norm_complexity, time_factor, hack_factor, tvl_factor])
    
    return clamp(risk_score, 0.0, 1.0)
end

"""
    analyze_cross_chain_risks(
        bridge_type::String,
        destination_chains::Vector{String};
        bridge_tvl::Vector{Float64}=Float64[],
        message_finality_time::Vector{Float64}=Float64[]
    )

Analyze risks associated with cross-chain operations.
Returns a Dict with risk metrics for each destination chain.
"""
function analyze_cross_chain_risks(
        bridge_type::String,
        destination_chains::Vector{String};
        bridge_tvl::Vector{Float64}=Float64[],
        message_finality_time::Vector{Float64}=Float64[]
    )
    
    n_chains = length(destination_chains)
    
    # Assign base risk scores by bridge type
    base_risk = Dict(
        "optimistic" => 0.5,   # Optimistic rollups
        "zk" => 0.3,           # ZK rollups
        "trusted" => 0.7,      # Trusted/federated bridges
        "hash-lock" => 0.4,    # Hash time-locked contracts
        "liquidity" => 0.6     # Liquidity networks
    )
    
    if !haskey(base_risk, bridge_type)
        error("Unknown bridge type: $bridge_type")
    end
    
    # Check if optional parameters are provided and have correct length
    has_tvl = !isempty(bridge_tvl)
    has_finality = !isempty(message_finality_time)
    
    if has_tvl && length(bridge_tvl) != n_chains
        error("Length of bridge_tvl must match length of destination_chains")
    end
    
    if has_finality && length(message_finality_time) != n_chains
        error("Length of message_finality_time must match length of destination_chains")
    end
    
    # Initialize result dictionary
    result = Dict{String,Dict{String,Any}}()
    
    # Calculate risk for each destination chain
    for i in 1:n_chains
        chain = destination_chains[i]
        chain_risk = base_risk[bridge_type]
        
        # Adjust risk based on TVL (higher TVL = lower risk, but with diminishing returns)
        if has_tvl && bridge_tvl[i] > 0
            tvl_factor = min(log10(bridge_tvl[i]) / 3.0, 1.0)
            chain_risk *= (1.0 - 0.2 * tvl_factor)
        end
        
        # Adjust risk based on finality time (longer finality = higher risk)
        if has_finality && message_finality_time[i] > 0
            finality_factor = min(message_finality_time[i] / 3600.0, 1.0)  # Normalized to hours
            chain_risk *= (1.0 + 0.2 * finality_factor)
        end
        
        # Calculate final risk score (clamped between 0 and 1)
        final_risk = clamp(chain_risk, 0.0, 1.0)
        
        # Store results
        result[chain] = Dict(
            "base_risk" => base_risk[bridge_type],
            "adjusted_risk" => final_risk,
            "risk_category" => risk_category(final_risk)
        )
        
        # Add optional metrics if available
        if has_tvl
            result[chain]["bridge_tvl"] = bridge_tvl[i]
        end
        
        if has_finality
            result[chain]["finality_time"] = message_finality_time[i]
        end
    end
    
    return result
end

"""
    risk_category(risk_score::Float64)

Helper function to convert a risk score to a category.
"""
function risk_category(risk_score::Float64)
    if risk_score < 0.2
        return "Very Low"
    elseif risk_score < 0.4
        return "Low"
    elseif risk_score < 0.6
        return "Medium"
    elseif risk_score < 0.8
        return "High"
    else
        return "Very High"
    end
end

"""
    liquidity_concentration_risk(
        holdings::Vector{Float64}, 
        liquidity_pools::Vector{Float64}
    )

Calculate liquidity concentration risk for a set of assets.
Higher values indicate higher concentration risk.
"""
function liquidity_concentration_risk(
        holdings::Vector{Float64}, 
        liquidity_pools::Vector{Float64}
    )
    
    n_assets = length(holdings)
    
    if length(liquidity_pools) != n_assets
        error("Length of holdings and liquidity_pools must match")
    end
    
    # Calculate concentration metrics
    concentration = zeros(n_assets)
    
    for i in 1:n_assets
        if liquidity_pools[i] > 0
            # Ratio of holdings to available liquidity
            concentration[i] = holdings[i] / liquidity_pools[i]
        elseif holdings[i] > 0
            # If no liquidity but holdings exist, max concentration
            concentration[i] = 1.0
        end
    end
    
    # Use Herfindahl-Hirschman Index (HHI) to measure concentration
    normalized_holdings = holdings ./ sum(holdings)
    hhi = sum(normalized_holdings.^2)
    
    # Calculate weighted average concentration
    weighted_concentration = dot(normalized_holdings, concentration)
    
    return Dict(
        "hhi" => hhi,
        "weighted_concentration" => weighted_concentration,
        "max_concentration" => maximum(concentration),
        "concentration_by_asset" => concentration
    )
end

"""
    estimate_mev_exposure(
        trade_value::Float64,
        gas_price::Float64;
        blockchain::String="ethereum",
        trade_type::String="swap"
    )

Estimate exposure to MEV (Maximal Extractable Value) for a transaction.
Returns estimated value at risk from MEV as a percentage of trade value.
"""
function estimate_mev_exposure(
        trade_value::Float64,
        gas_price::Float64;
        blockchain::String="ethereum",
        trade_type::String="swap"
    )
    
    if trade_value <= 0 || gas_price <= 0
        error("Trade value and gas price must be positive")
    end
    
    # Base MEV rates by blockchain (as percentage of trade value)
    base_mev_rates = Dict(
        "ethereum" => 0.005,    # 0.5%
        "binance" => 0.003,     # 0.3%
        "polygon" => 0.004,     # 0.4%
        "optimism" => 0.002,    # 0.2%
        "arbitrum" => 0.002,    # 0.2%
        "avalanche" => 0.003,   # 0.3%
        "solana" => 0.001       # 0.1%
    )
    
    # Default to Ethereum if blockchain not in list
    base_rate = get(base_mev_rates, lowercase(blockchain), 0.005)
    
    # Adjustments based on trade type
    type_multiplier = 1.0
    if trade_type == "swap"
        type_multiplier = 1.0
    elseif trade_type == "liquidation"
        type_multiplier = 2.0  # Liquidations are higher MEV targets
    elseif trade_type == "arbitrage"
        type_multiplier = 1.5  # Arbitrage opportunities are also targeted
    elseif trade_type == "mint" || trade_type == "redeem"
        type_multiplier = 0.8  # Lower MEV for mints/redeems
    end
    
    # Gas price adjustment (higher gas = higher MEV competition)
    # Normalized relative to "average" gas price (varies by chain)
    avg_gas = Dict(
        "ethereum" => 50.0,   # 50 gwei
        "binance" => 5.0,     # 5 gwei
        "polygon" => 100.0,   # 100 gwei
        "optimism" => 0.1,    # 0.1 gwei
        "arbitrum" => 0.1,    # 0.1 gwei
        "avalanche" => 25.0,  # 25 gwei
        "solana" => 0.0       # Solana doesn't use gwei
    )
    
    chain_avg_gas = get(avg_gas, lowercase(blockchain), 50.0)
    gas_multiplier = 0.0
    
    if chain_avg_gas > 0
        gas_ratio = gas_price / chain_avg_gas
        gas_multiplier = sqrt(gas_ratio)  # Square root to dampen effect
    else
        gas_multiplier = 1.0  # Default for chains not using gwei
    end
    
    # Calculate total MEV exposure
    mev_rate = base_rate * type_multiplier * gas_multiplier
    
    # For very large trades, MEV exposure diminishes (percentage-wise)
    if trade_value > 100000.0  # $100k threshold
        size_factor = log10(trade_value / 10000.0)
        mev_rate /= size_factor
    end
    
    return Dict(
        "mev_rate" => mev_rate,
        "mev_value" => mev_rate * trade_value,
        "base_rate" => base_rate,
        "type_multiplier" => type_multiplier,
        "gas_multiplier" => gas_multiplier
    )
end

"""
    gas_price_risk_analysis(
        historical_gas_prices::Vector{Float64};
        confidence_level::Float64=0.95
    )

Analyze gas price risk based on historical gas prices.
Returns statistics including VaR and expected gas costs.
"""
function gas_price_risk_analysis(
        historical_gas_prices::Vector{Float64};
        confidence_level::Float64=0.95
    )
    
    if isempty(historical_gas_prices)
        error("Historical gas prices vector cannot be empty")
    end
    
    # Basic statistics
    mean_gas = mean(historical_gas_prices)
    median_gas = median(historical_gas_prices)
    std_gas = std(historical_gas_prices)
    min_gas = minimum(historical_gas_prices)
    max_gas = maximum(historical_gas_prices)
    
    # Calculate gas price at risk (GaR)
    gar = quantile(historical_gas_prices, confidence_level)
    
    # Calculate conditional gas at risk (CGaR)
    tail_gas = historical_gas_prices[historical_gas_prices .>= gar]
    
    if isempty(tail_gas)
        cgar = gar
    else
        cgar = mean(tail_gas)
    end
    
    # Gas price volatility
    if length(historical_gas_prices) > 1
        # Calculate daily percentage changes
        pct_changes = diff(historical_gas_prices) ./ historical_gas_prices[1:end-1]
        volatility = std(pct_changes)
    else
        volatility = 0.0
    end
    
    return Dict(
        "mean" => mean_gas,
        "median" => median_gas,
        "std" => std_gas,
        "min" => min_gas,
        "max" => max_gas,
        "gar" => gar,
        "cgar" => cgar,
        "volatility" => volatility
    )
end

"""
    analyze_protocol_correlation(
        protocol_returns::Matrix{Float64};
        method::String="pearson"
    )

Analyze correlation between DeFi protocol returns.
Returns correlation matrix and summary statistics.
"""
function analyze_protocol_correlation(
        protocol_returns::Matrix{Float64};
        method::String="pearson"
    )
    
    n_protocols = size(protocol_returns, 2)
    
    if n_protocols < 2
        error("Need at least two protocols to calculate correlation")
    end
    
    # Calculate correlation matrix
    corr_matrix = zeros(n_protocols, n_protocols)
    
    if method == "pearson"
        corr_matrix = cor(protocol_returns)
    elseif method == "spearman"
        # Convert to ranks and then compute correlation
        ranked_returns = similar(protocol_returns)
        
        for i in 1:n_protocols
            ranked_returns[:, i] = tiedrank(protocol_returns[:, i])
        end
        
        corr_matrix = cor(ranked_returns)
    else
        error("Unknown correlation method: $method")
    end
    
    # Calculate average correlation for each protocol
    avg_corr = mean(corr_matrix, dims=1)[:]
    
    # Remove self-correlation (which is always 1.0)
    for i in 1:n_protocols
        avg_corr[i] = (sum(corr_matrix[i, :]) - 1.0) / (n_protocols - 1)
    end
    
    # Find highest correlated pair
    max_corr = -1.0
    max_pair = (0, 0)
    
    for i in 1:n_protocols
        for j in (i+1):n_protocols
            if corr_matrix[i, j] > max_corr
                max_corr = corr_matrix[i, j]
                max_pair = (i, j)
            end
        end
    end
    
    return Dict(
        "correlation_matrix" => corr_matrix,
        "average_correlation" => avg_corr,
        "max_correlation" => max_corr,
        "max_correlation_pair" => max_pair
    )
end

end # module 