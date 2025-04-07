module PortfolioOptimization

using JuliaOS
using JuMP
using Ipopt
using Plots
using Statistics
using LinearAlgebra
using Distributions
using Random
using Dates
using DataFrames
using StatsBase

export Asset, Portfolio, backtest_portfolio, optimize_portfolio
export simulate_market, plot_efficient_frontier, calculate_metrics, demo

"""
    Asset

Represents a financial asset.
"""
struct Asset
    ticker::String
    name::String
    sector::String
    asset_class::String  # "equity", "bond", "crypto", "commodity", "cash"
    currency::String
    historical_returns::Vector{Float64}
    historical_dates::Vector{Date}
    expected_return::Float64
    volatility::Float64
    skewness::Float64  # Measure of the asymmetry of the return distribution
    kurtosis::Float64  # Measure of the "tailedness" of the return distribution
end

"""
    Portfolio

Represents a portfolio of financial assets.
"""
struct Portfolio
    assets::Vector{Asset}
    weights::Vector{Float64}
    rebalance_frequency::String  # "daily", "weekly", "monthly", "quarterly", "annually"
    benchmark::String  # Ticker of benchmark index
    constraints::Dict{String, Any}  # Additional constraints (sector limits, etc.)
end

"""
    generate_correlated_returns(means, cov_matrix, n_samples)

Generate correlated returns for assets based on a covariance matrix.
"""
function generate_correlated_returns(means, cov_matrix, n_samples)
    n_assets = length(means)
    # Create a multivariate normal distribution
    dist = MvNormal(means, cov_matrix)
    
    # Generate random returns
    returns = rand(dist, n_samples)'
    
    return returns
end

"""
    estimate_covariance_matrix(returns)

Estimate the covariance matrix from historical returns.
"""
function estimate_covariance_matrix(returns)
    # Simple sample covariance
    n_samples = size(returns, 1)
    cov_matrix = cov(returns)
    
    return cov_matrix
end

"""
    adjust_for_fama_french(returns, factors; market_beta=true, size=true, value=true, momentum=false)

Adjust asset returns based on Fama-French factors.
"""
function adjust_for_fama_french(returns, factors; market_beta=true, size=true, value=true, momentum=false)
    n_assets = size(returns, 2)
    n_samples = size(returns, 1)
    
    # Extract factors
    mkt_rf = factors[:, 1]
    smb = factors[:, 2]
    hml = factors[:, 3]
    mom = size(factors, 2) >= 4 ? factors[:, 4] : zeros(n_samples)
    
    # Prepare design matrix with intercept
    X = ones(n_samples, 1)
    if market_beta
        X = [X mkt_rf]
    end
    if size
        X = [X smb]
    end
    if value
        X = [X hml]
    end
    if momentum
        X = [X mom]
    end
    
    # Fit model for each asset
    alphas = zeros(n_assets)
    residuals = zeros(n_samples, n_assets)
    
    for i in 1:n_assets
        y = returns[:, i]
        # Linear regression using least squares
        beta = (X' * X) \ (X' * y)
        
        # Calculate intercept (alpha) and residuals
        predicted = X * beta
        alphas[i] = beta[1]  # First coefficient is the intercept (alpha)
        residuals[:, i] = y - predicted
    end
    
    return alphas, residuals
end

"""
    calculate_metrics(returns, weights, risk_free_rate)

Calculate portfolio metrics like Sharpe ratio, Sortino ratio, maximum drawdown.
"""
function calculate_metrics(returns, weights, risk_free_rate=0.0)
    # Calculate portfolio returns
    portfolio_returns = returns * weights
    
    # Calculate basic statistics
    mean_return = mean(portfolio_returns)
    volatility = std(portfolio_returns)
    
    # Sharpe ratio
    sharpe_ratio = (mean_return - risk_free_rate) / volatility
    
    # Sortino ratio (only considers downside volatility)
    downside_returns = portfolio_returns[portfolio_returns .< risk_free_rate] .- risk_free_rate
    downside_volatility = isempty(downside_returns) ? 0.0 : std(downside_returns)
    sortino_ratio = downside_volatility == 0.0 ? Inf : (mean_return - risk_free_rate) / downside_volatility
    
    # Maximum drawdown
    cumulative_returns = cumprod(1 .+ portfolio_returns) .- 1
    running_max = accumulate(max, cumulative_returns)
    drawdowns = (running_max .- cumulative_returns) ./ (running_max .+ 1)
    max_drawdown = maximum(drawdowns)
    
    # Value at Risk (VaR) at 95% confidence
    var_95 = quantile(portfolio_returns, 0.05)
    
    # Conditional Value at Risk (CVaR) / Expected Shortfall
    cvar_95 = mean(portfolio_returns[portfolio_returns .<= var_95])
    
    # Information ratio (assuming mean_return is excess return over benchmark)
    # In a real implementation, you would compare to a benchmark
    information_ratio = mean_return / volatility
    
    # Calculate skewness and kurtosis
    skew = skewness(portfolio_returns)
    kurt = kurtosis(portfolio_returns)
    
    # Calculate beta (assuming first column of returns is market returns)
    # In a real implementation, you would use actual market returns
    beta = cov(portfolio_returns, returns[:, 1])[1, 2] / var(returns[:, 1])
    
    # Calmar ratio
    calmar_ratio = abs(max_drawdown) < 1e-10 ? Inf : mean_return / abs(max_drawdown)
    
    metrics = Dict(
        "mean_return" => mean_return,
        "volatility" => volatility,
        "sharpe_ratio" => sharpe_ratio,
        "sortino_ratio" => sortino_ratio,
        "max_drawdown" => max_drawdown,
        "var_95" => var_95,
        "cvar_95" => cvar_95,
        "information_ratio" => information_ratio,
        "skewness" => skew,
        "kurtosis" => kurt,
        "beta" => beta,
        "calmar_ratio" => calmar_ratio
    )
    
    return metrics
end

"""
    optimize_portfolio(assets; objective="sharpe", risk_free_rate=0.0, constraints=Dict())

Optimize a portfolio based on different objectives.
"""
function optimize_portfolio(assets; objective="sharpe", risk_free_rate=0.0, constraints=Dict())
    n_assets = length(assets)
    
    # Extract expected returns and covariance matrix
    expected_returns = [asset.expected_return for asset in assets]
    
    # Extract historical returns matrix
    returns_matrix = hcat([asset.historical_returns for asset in assets]...)
    
    # Estimate covariance matrix
    cov_matrix = estimate_covariance_matrix(returns_matrix)
    
    # Create optimization model
    model = Model(Ipopt.Optimizer)
    set_silent(model)  # Suppress solver output
    
    # Define variables: portfolio weights
    @variable(model, 0 <= w[1:n_assets] <= 1)
    
    # Basic constraint: weights sum to 1
    @constraint(model, sum(w) == 1)
    
    # Apply additional constraints
    if haskey(constraints, "max_weight")
        max_weight = constraints["max_weight"]
        for i in 1:n_assets
            @constraint(model, w[i] <= max_weight)
        end
    end
    
    if haskey(constraints, "min_weight")
        min_weight = constraints["min_weight"]
        for i in 1:n_assets
            @constraint(model, w[i] >= min_weight)
        end
    end
    
    # Sector constraints
    if haskey(constraints, "sector_limits")
        sector_limits = constraints["sector_limits"]
        sectors = unique([asset.sector for asset in assets])
        
        for sector in sectors
            if haskey(sector_limits, sector)
                sector_assets = findall(asset -> asset.sector == sector, assets)
                @constraint(model, sum(w[i] for i in sector_assets) <= sector_limits[sector])
            end
        end
    end
    
    # Asset class constraints
    if haskey(constraints, "asset_class_limits")
        asset_class_limits = constraints["asset_class_limits"]
        asset_classes = unique([asset.asset_class for asset in assets])
        
        for asset_class in asset_classes
            if haskey(asset_class_limits, asset_class)
                class_assets = findall(asset -> asset.asset_class == asset_class, assets)
                @constraint(model, sum(w[i] for i in class_assets) <= asset_class_limits[asset_class])
            end
        end
    end
    
    # Portfolio expected return and variance
    portfolio_return = @expression(model, sum(w[i] * expected_returns[i] for i in 1:n_assets))
    portfolio_variance = @expression(model, sum(w[i] * w[j] * cov_matrix[i, j] for i in 1:n_assets, j in 1:n_assets))
    
    # Set objective based on specified goal
    if objective == "sharpe"
        # Maximize Sharpe ratio: need to use a nonlinear approach
        @NLobjective(model, Max, (portfolio_return - risk_free_rate) / sqrt(portfolio_variance))
    elseif objective == "return"
        # Maximize expected return
        @objective(model, Max, portfolio_return)
    elseif objective == "risk"
        # Minimize portfolio risk (variance)
        @objective(model, Min, portfolio_variance)
    elseif objective == "min_variance"
        # Minimum variance portfolio
        @objective(model, Min, portfolio_variance)
    elseif objective == "efficient_return" && haskey(constraints, "target_return")
        # Minimize risk for a given target return
        target_return = constraints["target_return"]
        @constraint(model, portfolio_return >= target_return)
        @objective(model, Min, portfolio_variance)
    elseif objective == "efficient_risk" && haskey(constraints, "target_risk")
        # Maximize return for a given target risk
        target_risk = constraints["target_risk"]
        @constraint(model, sqrt(portfolio_variance) <= target_risk)
        @objective(model, Max, portfolio_return)
    else
        error("Unknown objective or missing required constraints")
    end
    
    # Solve the optimization problem
    optimize!(model)
    
    # Check if the optimization was successful
    if termination_status(model) != MOI.OPTIMAL && termination_status(model) != MOI.LOCALLY_SOLVED
        @warn "Optimization did not find an optimal solution. Status: $(termination_status(model))"
    end
    
    # Extract the optimal weights
    optimal_weights = value.(w)
    
    # Calculate portfolio metrics
    metrics = calculate_metrics(returns_matrix, optimal_weights, risk_free_rate)
    
    # Return results
    result = Dict(
        "weights" => optimal_weights,
        "expected_return" => metrics["mean_return"],
        "volatility" => metrics["volatility"],
        "sharpe_ratio" => metrics["sharpe_ratio"],
        "metrics" => metrics
    )
    
    return result
end

"""
    plot_efficient_frontier(assets; points=50, risk_free_rate=0.0, constraints=Dict())

Plot the efficient frontier for a set of assets.
"""
function plot_efficient_frontier(assets; points=50, risk_free_rate=0.0, constraints=Dict())
    n_assets = length(assets)
    
    # Minimum variance portfolio
    min_var_result = optimize_portfolio(assets, objective="min_variance", risk_free_rate=risk_free_rate, constraints=constraints)
    min_var_return = min_var_result["expected_return"]
    min_var_risk = min_var_result["volatility"]
    
    # Maximum return portfolio
    max_return_result = optimize_portfolio(assets, objective="return", risk_free_rate=risk_free_rate, constraints=constraints)
    max_return = max_return_result["expected_return"]
    
    # Generate efficient frontier points
    returns = collect(range(min_var_return, max_return, length=points))
    risks = zeros(points)
    sharpe_ratios = zeros(points)
    
    for i in 1:points
        target_return = returns[i]
        constraints_with_target = deepcopy(constraints)
        constraints_with_target["target_return"] = target_return
        
        result = optimize_portfolio(assets, objective="efficient_return", risk_free_rate=risk_free_rate, constraints=constraints_with_target)
        risks[i] = result["volatility"]
        sharpe_ratios[i] = result["sharpe_ratio"]
    end
    
    # Find tangency portfolio (maximum Sharpe ratio)
    tangency_result = optimize_portfolio(assets, objective="sharpe", risk_free_rate=risk_free_rate, constraints=constraints)
    tangency_return = tangency_result["expected_return"]
    tangency_risk = tangency_result["volatility"]
    
    # Create plot
    p = plot(
        risks, returns,
        title="Efficient Frontier",
        xlabel="Portfolio Volatility",
        ylabel="Expected Return",
        label="Efficient Frontier",
        color=:blue,
        linewidth=2,
        legend=:bottomright,
        grid=true
    )
    
    # Plot capital market line
    cml_x = [0, tangency_risk * 2]
    cml_y = [risk_free_rate, risk_free_rate + (tangency_return - risk_free_rate) * 2]
    plot!(p, cml_x, cml_y, label="Capital Market Line", color=:red, linestyle=:dash)
    
    # Plot tangency portfolio
    scatter!(p, [tangency_risk], [tangency_return], label="Tangency Portfolio", color=:green, markersize=8)
    
    # Plot minimum variance portfolio
    scatter!(p, [min_var_risk], [min_var_return], label="Minimum Variance", color=:orange, markersize=8)
    
    # Plot individual assets
    individual_returns = [asset.expected_return for asset in assets]
    individual_risks = [asset.volatility for asset in assets]
    asset_labels = [asset.ticker for asset in assets]
    
    for i in 1:n_assets
        annotate!(p, individual_risks[i], individual_returns[i], text(asset_labels[i], :black, :right, 6))
    end
    
    scatter!(p, individual_risks, individual_returns, label="Individual Assets", color=:black, markersize=4)
    
    return p
end

"""
    simulate_market(n_assets=20, n_days=252, seed=nothing)

Simulate a market with various assets and their historical returns.
"""
function simulate_market(n_assets=20, n_days=252, seed=nothing)
    if seed !== nothing
        Random.seed!(seed)
    end
    
    # Parameters for simulation
    start_date = Date(2020, 1, 1)
    dates = [start_date + Day(i) for i in 0:(n_days-1)]
    
    # Asset classes and their parameters
    asset_classes = ["equity", "bond", "crypto", "commodity", "cash"]
    class_weights = [0.5, 0.3, 0.05, 0.1, 0.05]  # Probability distribution
    
    # Sectors for equities
    equity_sectors = ["Technology", "Healthcare", "Financials", "Consumer", "Energy", "Industrials", "Utilities"]
    
    # Parameters for return distributions
    class_params = Dict(
        "equity" => (0.08, 0.18, 0.0, 3.0),  # mean, std, skew, kurt
        "bond" => (0.03, 0.05, -0.1, 3.5),
        "crypto" => (0.15, 0.50, 0.3, 5.0),
        "commodity" => (0.04, 0.16, 0.2, 4.0),
        "cash" => (0.01, 0.005, 0.0, 3.0)
    )
    
    # Generate correlation matrix (more correlated within same class)
    base_correlation = 0.2
    correlation_matrix = ones(n_assets, n_assets)
    
    # We'll assign asset classes first
    selected_classes = sample(asset_classes, Weights(class_weights), n_assets)
    selected_sectors = [class == "equity" ? rand(equity_sectors) : class for class in selected_classes]
    
    # Create the correlation matrix
    for i in 1:n_assets
        for j in (i+1):n_assets
            # Higher correlation for same asset class
            if selected_classes[i] == selected_classes[j]
                # Even higher for same sector within equity
                if selected_classes[i] == "equity" && selected_sectors[i] == selected_sectors[j]
                    correlation_matrix[i, j] = 0.7 + 0.2 * rand()
                else
                    correlation_matrix[i, j] = 0.5 + 0.2 * rand()
                end
            else
                correlation_matrix[i, j] = base_correlation + 0.2 * rand()
            end
            correlation_matrix[j, i] = correlation_matrix[i, j]
        end
    end
    
    # Generate tickers
    tickers = ["ASSET$(lpad(i, 2, '0'))" for i in 1:n_assets]
    
    # Generate expected returns and volatilities based on asset class
    expected_returns = zeros(n_assets)
    volatilities = zeros(n_assets)
    skewness_values = zeros(n_assets)
    kurtosis_values = zeros(n_assets)
    
    for i in 1:n_assets
        class = selected_classes[i]
        params = class_params[class]
        
        # Add some random variation to parameters
        expected_returns[i] = params[1] + 0.02 * randn()
        volatilities[i] = params[2] + 0.02 * abs(randn())
        skewness_values[i] = params[3] + 0.1 * randn()
        kurtosis_values[i] = params[4] + 0.5 * abs(randn())
    end
    
    # Create covariance matrix from correlation and volatilities
    cov_matrix = diagm(volatilities) * correlation_matrix * diagm(volatilities)
    
    # Generate correlated daily returns
    daily_returns = generate_correlated_returns(zeros(n_assets), cov_matrix, n_days)
    
    # Add drift (expected return) and non-normal characteristics
    for i in 1:n_assets
        # Add expected return (drift)
        daily_drift = expected_returns[i] / 252  # Assuming 252 trading days in a year
        daily_returns[:, i] .+= daily_drift
        
        # Add non-normal characteristics using a skew-t distribution simulation
        # This is a simplified approach
        if abs(skewness_values[i]) > 0.1 || abs(kurtosis_values[i] - 3.0) > 0.5
            # Generate random shocks with the desired skewness and kurtosis
            # For simplicity, we'll just add some outliers based on the target characteristics
            n_outliers = Int(round(n_days * 0.05))  # 5% outliers
            outlier_indices = sample(1:n_days, n_outliers, replace=false)
            
            for idx in outlier_indices
                # Direction and magnitude of outlier based on skewness
                sign_factor = rand() < 0.5 + skewness_values[i] * 0.1 ? 1 : -1
                # Magnitude based on kurtosis (higher kurtosis = fatter tails)
                magnitude = volatilities[i] * (1.0 + (kurtosis_values[i] - 3.0) * 0.2) * (2 + rand(Exponential(1.0)))
                daily_returns[idx, i] += sign_factor * magnitude
            end
        end
    end
    
    # Create Asset objects
    assets = Vector{Asset}(undef, n_assets)
    
    currencies = ["USD", "EUR", "GBP", "JPY", "CHF"]
    
    for i in 1:n_assets
        assets[i] = Asset(
            tickers[i],
            "Asset $i",
            selected_sectors[i],
            selected_classes[i],
            rand(currencies),
            daily_returns[:, i],
            dates,
            expected_returns[i],
            volatilities[i],
            skewness_values[i],
            kurtosis_values[i]
        )
    end
    
    return assets
end

"""
    backtest_portfolio(portfolio, start_date, end_date; rebalance=true)

Backtest a portfolio over a given time period.
"""
function backtest_portfolio(portfolio, start_date, end_date; rebalance=true)
    assets = portfolio.assets
    weights = portfolio.weights
    n_assets = length(assets)
    
    # Find common date range for all assets
    common_dates = assets[1].historical_dates
    for i in 2:n_assets
        common_dates = intersect(common_dates, assets[i].historical_dates)
    end
    
    # Filter dates within the backtest period
    backtest_dates = filter(d -> start_date <= d <= end_date, common_dates)
    
    if isempty(backtest_dates)
        error("No common dates found in the specified date range")
    end
    
    # Create a returns matrix with all assets over the backtest period
    n_dates = length(backtest_dates)
    returns_matrix = zeros(n_dates, n_assets)
    
    for i in 1:n_assets
        asset = assets[i]
        for (j, date) in enumerate(backtest_dates)
            idx = findfirst(d -> d == date, asset.historical_dates)
            if idx !== nothing
                returns_matrix[j, i] = asset.historical_returns[idx]
            end
        end
    end
    
    # Calculate portfolio evolution
    portfolio_value = 10000.0  # Start with $10,000
    portfolio_values = zeros(n_dates)
    portfolio_returns = zeros(n_dates)
    current_weights = copy(weights)
    asset_values = zeros(n_assets)
    
    # Initialize asset values
    for i in 1:n_assets
        asset_values[i] = portfolio_value * weights[i]
    end
    
    # Loop through each date
    for t in 1:n_dates
        # Update portfolio value based on returns
        if t > 1
            for i in 1:n_assets
                asset_values[i] *= (1 + returns_matrix[t, i])
            end
            
            # Calculate new portfolio value and return
            new_portfolio_value = sum(asset_values)
            portfolio_returns[t] = (new_portfolio_value - portfolio_value) / portfolio_value
            portfolio_value = new_portfolio_value
            
            # Update current weights
            current_weights = asset_values / portfolio_value
            
            # Rebalance if needed
            if rebalance
                rebalance_frequency = portfolio.rebalance_frequency
                date = backtest_dates[t]
                prev_date = backtest_dates[t-1]
                
                should_rebalance = false
                
                if rebalance_frequency == "daily"
                    should_rebalance = true
                elseif rebalance_frequency == "weekly" && dayofweek(date) == 1 && dayofweek(prev_date) != 1
                    should_rebalance = true
                elseif rebalance_frequency == "monthly" && day(date) == 1 && day(prev_date) != 1
                    should_rebalance = true
                elseif rebalance_frequency == "quarterly" && day(date) == 1 && month(date) in [1, 4, 7, 10] && 
                       (day(prev_date) != 1 || !(month(prev_date) in [1, 4, 7, 10]))
                    should_rebalance = true
                elseif rebalance_frequency == "annually" && day(date) == 1 && month(date) == 1 && 
                       (day(prev_date) != 1 || month(prev_date) != 1)
                    should_rebalance = true
                end
                
                if should_rebalance
                    for i in 1:n_assets
                        asset_values[i] = portfolio_value * weights[i]
                    end
                    current_weights = copy(weights)
                end
            end
        end
        
        portfolio_values[t] = portfolio_value
    end
    
    # Calculate cumulative returns
    cumulative_returns = cumprod(1 .+ portfolio_returns) .- 1
    
    # Calculate metrics
    metrics = calculate_metrics(returns_matrix, weights)
    
    # Create results dictionary
    results = Dict(
        "dates" => backtest_dates,
        "portfolio_values" => portfolio_values,
        "portfolio_returns" => portfolio_returns,
        "cumulative_returns" => cumulative_returns,
        "final_weights" => current_weights,
        "metrics" => metrics
    )
    
    return results
end

"""
    demo()

Run a demonstration of portfolio optimization.
"""
function demo()
    println("Simulating market assets...")
    assets = simulate_market(20, 504, 42)  # 20 assets, 2 years of daily data, seed 42
    
    println("Asset classes:")
    for (i, asset) in enumerate(assets)
        println("  $(asset.ticker): $(asset.asset_class) ($(asset.sector)), Expected Return: $(round(asset.expected_return*100, digits=2))%, Volatility: $(round(asset.volatility*100, digits=2))%")
    end
    
    println("\nOptimizing portfolio for maximum Sharpe ratio...")
    # Add constraints: maximum weight per asset and minimum allocation to bonds
    constraints = Dict(
        "max_weight" => 0.25,  # Max 25% in any single asset
        "sector_limits" => Dict("Technology" => 0.40),  # Max 40% in Technology
        "asset_class_limits" => Dict("equity" => 0.70, "bond" => 0.20)  # 70% max equity, 20% min bonds
    )
    
    result = optimize_portfolio(assets, objective="sharpe", risk_free_rate=0.01, constraints=constraints)
    
    println("\nOptimal portfolio:")
    println("  Expected Return: $(round(result["expected_return"]*100, digits=2))%")
    println("  Volatility: $(round(result["volatility"]*100, digits=2))%")
    println("  Sharpe Ratio: $(round(result["sharpe_ratio"], digits=3))")
    println("  Max Drawdown: $(round(result["metrics"]["max_drawdown"]*100, digits=2))%")
    
    println("\nOptimal asset allocation:")
    for (i, asset) in enumerate(assets)
        if result["weights"][i] > 0.005  # Only show assets with significant allocation
            println("  $(asset.ticker) ($(asset.asset_class)): $(round(result["weights"][i]*100, digits=2))%")
        end
    end
    
    println("\nGenerating efficient frontier...")
    p1 = plot_efficient_frontier(assets, points=30, risk_free_rate=0.01, constraints=constraints)
    
    # Create a portfolio with the optimal weights
    portfolio = Portfolio(
        assets,
        result["weights"],
        "monthly",  # Rebalance monthly
        "SPY",  # S&P 500 as benchmark
        constraints
    )
    
    println("\nBacktesting portfolio...")
    backtest_results = backtest_portfolio(
        portfolio,
        assets[1].historical_dates[1],  # Start date
        assets[1].historical_dates[end],  # End date
        rebalance=true
    )
    
    # Plot performance
    p2 = plot(
        backtest_results["dates"],
        backtest_results["cumulative_returns"],
        title="Portfolio Performance",
        xlabel="Date",
        ylabel="Cumulative Return",
        label="Optimized Portfolio",
        color=:blue,
        linewidth=2,
        legend=:bottomright,
        grid=true
    )
    
    p = plot(p1, p2, layout=(2, 1), size=(800, 800))
    savefig(p, "portfolio_optimization.png")
    display(p)
    
    return assets, result, backtest_results, p
end

end # module 