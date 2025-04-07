module Portfolio

using Statistics
using LinearAlgebra
using Optim
using DataFrames
using Dates

export optimize_portfolio, calculate_portfolio_return, calculate_portfolio_risk
export calculate_sharpe_ratio, calculate_sortino_ratio, calculate_max_drawdown
export efficient_frontier, back_test_strategy, rebalance_portfolio

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
    
    n_assets = size(returns, 2)
    μ = vec(mean(returns, dims=1))  # Expected returns
    Σ = cov(returns)  # Covariance matrix
    
    if method == "markowitz"
        # Markowitz Mean-Variance Optimization
        
        if target_return !== nothing
            # Efficient frontier with target return
            
            # Define objective function (portfolio variance)
            function objective(w)
                return w' * Σ * w
            end
            
            # Constraints: weights sum to 1, target return is achieved
            function constraint(w)
                return [sum(w) - 1.0, dot(w, μ) - target_return]
            end
            
            # Initial guess (equal weights)
            initial_weights = fill(1.0/n_assets, n_assets)
            
            # Optimize
            result = optimize(
                objective,
                constraint,
                initial_weights,
                Newton(),
                Optim.Options(iterations=1000)
            )
            
            # Extract solution
            weights = Optim.minimizer(result)
            
        elseif max_risk !== nothing
            # Maximum return subject to risk constraint
            
            # Define objective function (negative portfolio return)
            function objective(w)
                return -dot(w, μ)
            end
            
            # Constraints: weights sum to 1, risk is limited
            function constraint(w)
                return [sum(w) - 1.0, sqrt(w' * Σ * w) - max_risk]
            end
            
            # Initial guess (equal weights)
            initial_weights = fill(1.0/n_assets, n_assets)
            
            # Optimize
            result = optimize(
                objective,
                constraint,
                initial_weights,
                Newton(),
                Optim.Options(iterations=1000)
            )
            
            # Extract solution
            weights = Optim.minimizer(result)
            
        else
            # Maximize Sharpe ratio
            
            # Define objective function (negative Sharpe ratio)
            function objective(w)
                portfolio_return = dot(w, μ)
                portfolio_risk = sqrt(w' * Σ * w)
                return -(portfolio_return - risk_free_rate) / portfolio_risk
            end
            
            # Constraint: weights sum to 1
            function constraint(w)
                return sum(w) - 1.0
            end
            
            # Initial guess (equal weights)
            initial_weights = fill(1.0/n_assets, n_assets)
            
            # Optimize
            result = optimize(
                objective,
                constraint,
                initial_weights,
                Newton(),
                Optim.Options(iterations=1000)
            )
            
            # Extract solution
            weights = Optim.minimizer(result)
        end
        
    elseif method == "min_variance"
        # Minimum Variance Portfolio
        
        # Define objective function (portfolio variance)
        function objective(w)
            return w' * Σ * w
        end
        
        # Constraint: weights sum to 1
        function constraint(w)
            return sum(w) - 1.0
        end
        
        # Initial guess (equal weights)
        initial_weights = fill(1.0/n_assets, n_assets)
        
        # Optimize
        result = optimize(
            objective,
            constraint,
            initial_weights,
            Newton(),
            Optim.Options(iterations=1000)
        )
        
        # Extract solution
        weights = Optim.minimizer(result)
        
    elseif method == "risk_parity"
        # Risk Parity Portfolio
        
        # Define objective function for risk parity
        function objective(w)
            σ = sqrt.(diag(Σ))  # Asset volatilities
            w_scaled = w ./ σ   # Scale weights by volatility
            
            # Measure deviation from equal risk contribution
            risk_contrib = w .* (Σ * w)
            target_contrib = sum(risk_contrib) / n_assets
            
            return sum((risk_contrib .- target_contrib).^2)
        end
        
        # Constraint: weights sum to 1
        function constraint(w)
            return sum(w) - 1.0
        end
        
        # Initial guess (equal weights)
        initial_weights = fill(1.0/n_assets, n_assets)
        
        # Optimize
        result = optimize(
            objective,
            constraint,
            initial_weights,
            Newton(),
            Optim.Options(iterations=1000)
        )
        
        # Extract solution
        weights = Optim.minimizer(result)
        
    elseif method == "equal_weight"
        # Equal Weight Portfolio
        weights = fill(1.0/n_assets, n_assets)
        
    elseif method == "max_diversification"
        # Maximum Diversification Portfolio
        
        # Define objective function (negative diversification ratio)
        function objective(w)
            σ = sqrt.(diag(Σ))  # Asset volatilities
            portfolio_vol = sqrt(w' * Σ * w)
            weighted_asset_vol = dot(w, σ)
            
            return -weighted_asset_vol / portfolio_vol
        end
        
        # Constraint: weights sum to 1
        function constraint(w)
            return sum(w) - 1.0
        end
        
        # Initial guess (equal weights)
        initial_weights = fill(1.0/n_assets, n_assets)
        
        # Optimize
        result = optimize(
            objective,
            constraint,
            initial_weights,
            Newton(),
            Optim.Options(iterations=1000)
        )
        
        # Extract solution
        weights = Optim.minimizer(result)
        
    else
        error("Unknown portfolio optimization method: $method")
    end
    
    # Normalize weights to ensure they sum to 1
    weights = weights ./ sum(weights)
    
    return weights
end

"""
    calculate_portfolio_return(weights::Vector{Float64}, returns::Matrix{Float64})

Calculate expected portfolio return based on historical returns.
"""
function calculate_portfolio_return(weights::Vector{Float64}, returns::Matrix{Float64})
    μ = vec(mean(returns, dims=1))  # Expected returns
    return dot(weights, μ)
end

"""
    calculate_portfolio_risk(weights::Vector{Float64}, returns::Matrix{Float64})

Calculate portfolio risk (standard deviation) based on historical returns.
"""
function calculate_portfolio_risk(weights::Vector{Float64}, returns::Matrix{Float64})
    Σ = cov(returns)  # Covariance matrix
    return sqrt(weights' * Σ * weights)
end

"""
    calculate_sharpe_ratio(weights::Vector{Float64}, returns::Matrix{Float64}; 
                         risk_free_rate::Float64=0.0)

Calculate Sharpe ratio for a portfolio.
"""
function calculate_sharpe_ratio(weights::Vector{Float64}, returns::Matrix{Float64}; 
                               risk_free_rate::Float64=0.0)
    
    portfolio_return = calculate_portfolio_return(weights, returns)
    portfolio_risk = calculate_portfolio_risk(weights, returns)
    
    # Avoid division by zero
    if portfolio_risk ≈ 0.0
        return 0.0
    end
    
    return (portfolio_return - risk_free_rate) / portfolio_risk
end

"""
    calculate_sortino_ratio(weights::Vector{Float64}, returns::Matrix{Float64}; 
                          risk_free_rate::Float64=0.0)

Calculate Sortino ratio for a portfolio (using downside deviation).
"""
function calculate_sortino_ratio(weights::Vector{Float64}, returns::Matrix{Float64}; 
                                risk_free_rate::Float64=0.0)
    
    portfolio_return = calculate_portfolio_return(weights, returns)
    
    # Calculate portfolio historical returns
    portfolio_returns = returns * weights
    
    # Calculate downside deviation
    negative_returns = min.(portfolio_returns .- risk_free_rate, 0.0)
    downside_deviation = sqrt(mean(negative_returns.^2))
    
    # Avoid division by zero
    if downside_deviation ≈ 0.0
        return 0.0
    end
    
    return (portfolio_return - risk_free_rate) / downside_deviation
end

"""
    calculate_max_drawdown(equity_curve::Vector{Float64})

Calculate maximum drawdown from an equity curve.
"""
function calculate_max_drawdown(equity_curve::Vector{Float64})
    n = length(equity_curve)
    
    if n <= 1
        return 0.0
    end
    
    max_drawdown = 0.0
    peak_value = equity_curve[1]
    
    for i in 2:n
        # Update peak if we have a new high
        if equity_curve[i] > peak_value
            peak_value = equity_curve[i]
        end
        
        # Calculate drawdown
        drawdown = (peak_value - equity_curve[i]) / peak_value
        
        # Update max drawdown
        if drawdown > max_drawdown
            max_drawdown = drawdown
        end
    end
    
    return max_drawdown
end

"""
    efficient_frontier(returns::Matrix{Float64}, 
                      n_portfolios::Int=20; 
                      risk_free_rate::Float64=0.0)

Calculate the efficient frontier for a set of assets.
"""
function efficient_frontier(returns::Matrix{Float64}, 
                           n_portfolios::Int=20; 
                           risk_free_rate::Float64=0.0)
    
    n_assets = size(returns, 2)
    μ = vec(mean(returns, dims=1))  # Expected returns
    Σ = cov(returns)  # Covariance matrix
    
    # Calculate minimum variance portfolio
    min_var_weights = optimize_portfolio(returns, "min_variance")
    min_var_return = calculate_portfolio_return(min_var_weights, returns)
    min_var_risk = calculate_portfolio_risk(min_var_weights, returns)
    
    # Calculate maximum return portfolio (100% in asset with highest return)
    max_return_idx = argmax(μ)
    max_return_weights = zeros(n_assets)
    max_return_weights[max_return_idx] = 1.0
    max_return = calculate_portfolio_return(max_return_weights, returns)
    max_return_risk = calculate_portfolio_risk(max_return_weights, returns)
    
    # Generate target returns between min and max
    target_returns = range(min_var_return, stop=max_return, length=n_portfolios)
    
    # Calculate efficient frontier
    frontier_weights = zeros(n_portfolios, n_assets)
    frontier_risks = zeros(n_portfolios)
    frontier_returns = zeros(n_portfolios)
    frontier_sharpe = zeros(n_portfolios)
    
    for i in 1:n_portfolios
        # Optimize for target return
        weights = optimize_portfolio(returns, "markowitz", risk_free_rate=risk_free_rate, target_return=target_returns[i])
        
        # Calculate risk and store results
        frontier_weights[i, :] = weights
        frontier_risks[i] = calculate_portfolio_risk(weights, returns)
        frontier_returns[i] = calculate_portfolio_return(weights, returns)
        frontier_sharpe[i] = calculate_sharpe_ratio(weights, returns, risk_free_rate=risk_free_rate)
    end
    
    # Calculate tangency portfolio (maximum Sharpe ratio)
    tangency_weights = optimize_portfolio(returns, "markowitz", risk_free_rate=risk_free_rate)
    tangency_risk = calculate_portfolio_risk(tangency_weights, returns)
    tangency_return = calculate_portfolio_return(tangency_weights, returns)
    
    return Dict(
        "frontier_weights" => frontier_weights,
        "frontier_risks" => frontier_risks,
        "frontier_returns" => frontier_returns,
        "frontier_sharpe" => frontier_sharpe,
        "tangency_weights" => tangency_weights,
        "tangency_risk" => tangency_risk,
        "tangency_return" => tangency_return,
        "min_var_weights" => min_var_weights,
        "min_var_risk" => min_var_risk,
        "min_var_return" => min_var_return
    )
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
    
    # Extract dates and symbols
    dates = prices.Date
    price_cols = filter(col -> col != :Date, names(prices))
    n_assets = length(price_cols)
    n_periods = nrow(prices)
    
    # Initialize portfolio
    capital = initial_capital
    cash = capital
    positions = zeros(n_assets)
    position_values = zeros(n_assets)
    
    # Initialize results
    equity_curve = zeros(n_periods)
    position_history = zeros(n_periods, n_assets)
    trade_history = []
    
    # Run backtest
    for t in 1:n_periods
        # Get current prices
        current_prices = [prices[t, col] for col in price_cols]
        
        # Update position values
        position_values = positions .* current_prices
        
        # Calculate total equity
        equity = cash + sum(position_values)
        equity_curve[t] = equity
        
        # Run strategy to get target positions
        target_weights = strategy(prices[1:t, :], t)
        target_positions = target_weights .* equity ./ current_prices
        
        # Calculate trades needed
        trades = target_positions - positions
        
        # Execute trades
        for (i, trade) in enumerate(trades)
            if trade != 0
                # Calculate trade cost
                trade_price = current_prices[i]
                trade_value = abs(trade) * trade_price
                trade_cost = trade_value * commission
                
                # Update positions and cash
                positions[i] += trade
                cash -= trade * trade_price + trade_cost
                
                # Record trade
                push!(trade_history, Dict(
                    "date" => dates[t],
                    "symbol" => price_cols[i],
                    "price" => trade_price,
                    "quantity" => trade,
                    "value" => trade_value,
                    "cost" => trade_cost
                ))
            end
        end
        
        # Record positions
        position_history[t, :] = positions
    end
    
    # Calculate performance metrics
    returns = diff(equity_curve) ./ equity_curve[1:end-1]
    sharpe_ratio = mean(returns) / std(returns) * sqrt(252)  # Annualized
    max_drawdown = calculate_max_drawdown(equity_curve)
    
    return Dict(
        "equity_curve" => equity_curve,
        "position_history" => position_history,
        "trade_history" => trade_history,
        "final_equity" => equity_curve[end],
        "total_return" => (equity_curve[end] - initial_capital) / initial_capital,
        "sharpe_ratio" => sharpe_ratio,
        "max_drawdown" => max_drawdown
    )
end

"""
    rebalance_portfolio(current_weights::Vector{Float64}, 
                       target_weights::Vector{Float64}; 
                       threshold::Float64=0.01)

Determine trades needed to rebalance a portfolio to target weights.
"""
function rebalance_portfolio(current_weights::Vector{Float64}, 
                            target_weights::Vector{Float64}; 
                            threshold::Float64=0.01)
    
    n_assets = length(current_weights)
    
    if length(target_weights) != n_assets
        error("Current and target weight vectors must have same length")
    end
    
    # Calculate weight differences
    weight_diff = target_weights - current_weights
    
    # Only trade if difference exceeds threshold
    trades = zeros(n_assets)
    
    for i in 1:n_assets
        if abs(weight_diff[i]) > threshold
            trades[i] = weight_diff[i]
        end
    end
    
    return trades
end

end # module 