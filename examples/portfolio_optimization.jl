"""
Portfolio Optimization Example

This example demonstrates how to use JuliaOS swarm algorithms for portfolio optimization.
"""

# Add the parent directory to the load path
push!(LOAD_PATH, joinpath(@__DIR__, ".."))

# Import required modules
using Pkg
Pkg.add("Statistics")
Pkg.add("LinearAlgebra")
Pkg.add("Plots")
Pkg.add("DataFrames")
Pkg.add("CSV")

using Statistics
using LinearAlgebra
using Plots
using DataFrames
using CSV
using Random
using Dates

# Import JuliaOS modules
using julia.src.swarm.SwarmBase
using julia.src.swarm.Swarms
using julia.src.swarm.algorithms.PSO
using julia.src.swarm.algorithms.DE

# Set random seed for reproducibility
Random.seed!(42)

"""
    load_stock_data(file_path::String)

Load stock price data from a CSV file.

# Arguments
- `file_path::String`: Path to the CSV file

# Returns
- `DataFrame`: Stock price data
"""
function load_stock_data(file_path::String)
    return CSV.read(file_path, DataFrame)
end

"""
    calculate_returns(prices::DataFrame)

Calculate daily returns from price data.

# Arguments
- `prices::DataFrame`: Stock price data

# Returns
- `DataFrame`: Daily returns
"""
function calculate_returns(prices::DataFrame)
    returns = DataFrame()
    
    for col in names(prices)[2:end]  # Skip date column
        returns[!, col] = diff(log.(prices[!, col])) .* 100
    end
    
    returns[!, :Date] = prices[2:end, :Date]
    
    return returns
end

"""
    calculate_portfolio_metrics(weights::Vector{Float64}, returns::Matrix{Float64})

Calculate portfolio metrics (return, risk, Sharpe ratio).

# Arguments
- `weights::Vector{Float64}`: Portfolio weights
- `returns::Matrix{Float64}`: Asset returns

# Returns
- `Tuple`: (expected_return, risk, sharpe_ratio)
"""
function calculate_portfolio_metrics(weights::Vector{Float64}, returns::Matrix{Float64})
    # Normalize weights to sum to 1
    weights = weights ./ sum(weights)
    
    # Calculate expected returns (annualized)
    expected_return = mean(returns, dims=1) * weights * 252
    
    # Calculate covariance matrix (annualized)
    cov_matrix = cov(returns) * 252
    
    # Calculate portfolio variance
    portfolio_variance = weights' * cov_matrix * weights
    
    # Calculate portfolio risk (standard deviation)
    risk = sqrt(portfolio_variance)
    
    # Calculate Sharpe ratio (assuming risk-free rate of 0)
    sharpe_ratio = expected_return[1] / risk
    
    return (expected_return[1], risk, sharpe_ratio)
end

"""
    portfolio_objective(weights::Vector{Float64}, returns::Matrix{Float64}; objective="sharpe")

Portfolio optimization objective function.

# Arguments
- `weights::Vector{Float64}`: Portfolio weights
- `returns::Matrix{Float64}`: Asset returns
- `objective::String`: Optimization objective ("sharpe", "return", "risk")

# Returns
- `Float64`: Objective value
"""
function portfolio_objective(weights::Vector{Float64}, returns::Matrix{Float64}; objective="sharpe")
    # Calculate portfolio metrics
    expected_return, risk, sharpe_ratio = calculate_portfolio_metrics(weights, returns)
    
    # Return objective value based on optimization goal
    if objective == "sharpe"
        # Maximize Sharpe ratio
        return -sharpe_ratio  # Negative because we're minimizing
    elseif objective == "return"
        # Maximize return
        return -expected_return  # Negative because we're minimizing
    elseif objective == "risk"
        # Minimize risk
        return risk
    else
        error("Unknown objective: $objective")
    end
end

"""
    optimize_portfolio(returns::Matrix{Float64}, num_assets::Int; 
                      algorithm="pso", objective="sharpe", constraints=Dict())

Optimize a portfolio using swarm algorithms.

# Arguments
- `returns::Matrix{Float64}`: Asset returns
- `num_assets::Int`: Number of assets
- `algorithm::String`: Optimization algorithm ("pso", "de")
- `objective::String`: Optimization objective ("sharpe", "return", "risk")
- `constraints::Dict`: Additional constraints

# Returns
- `Dict`: Optimization results
"""
function optimize_portfolio(returns::Matrix{Float64}, num_assets::Int; 
                           algorithm="pso", objective="sharpe", constraints=Dict())
    # Create objective function closure
    function obj_func(weights)
        return portfolio_objective(weights, returns; objective=objective)
    end
    
    # Create optimization problem
    problem = OptimizationProblem(
        num_assets,
        [(0.0, 1.0) for _ in 1:num_assets],  # Bounds: weights between 0 and 1
        obj_func;
        is_minimization = true
    )
    
    # Create algorithm
    if algorithm == "pso"
        alg = ParticleSwarmOptimization(
            swarm_size = get(constraints, "swarm_size", 100),
            max_iterations = get(constraints, "max_iterations", 100),
            c1 = get(constraints, "c1", 1.5),
            c2 = get(constraints, "c2", 1.5),
            w = get(constraints, "w", 0.7),
            w_damp = get(constraints, "w_damp", 0.99)
        )
        
        # Run optimization
        result = PSO.optimize(problem, alg)
    elseif algorithm == "de"
        alg = DifferentialEvolution(
            population_size = get(constraints, "population_size", 100),
            max_iterations = get(constraints, "max_iterations", 100),
            F = get(constraints, "F", 0.8),
            CR = get(constraints, "CR", 0.9),
            strategy = get(constraints, "strategy", :rand_1_bin)
        )
        
        # Run optimization
        result = DE.optimize(problem, alg)
    else
        error("Unknown algorithm: $algorithm")
    end
    
    # Normalize weights to sum to 1
    weights = result.best_position ./ sum(result.best_position)
    
    # Calculate final metrics
    expected_return, risk, sharpe_ratio = calculate_portfolio_metrics(weights, returns)
    
    return Dict(
        "weights" => weights,
        "expected_return" => expected_return,
        "risk" => risk,
        "sharpe_ratio" => sharpe_ratio,
        "convergence_curve" => result.convergence_curve,
        "iterations" => length(result.convergence_curve),
        "evaluations" => result.evaluations
    )
end

"""
    plot_efficient_frontier(returns::Matrix{Float64}, num_assets::Int, asset_names::Vector{String})

Plot the efficient frontier using multiple portfolio optimizations.

# Arguments
- `returns::Matrix{Float64}`: Asset returns
- `num_assets::Int`: Number of assets
- `asset_names::Vector{String}`: Asset names

# Returns
- `Plot`: Efficient frontier plot
"""
function plot_efficient_frontier(returns::Matrix{Float64}, num_assets::Int, asset_names::Vector{String})
    # Generate random portfolios
    num_portfolios = 5000
    all_weights = [rand(num_assets) ./ sum(rand(num_assets)) for _ in 1:num_portfolios]
    
    # Calculate metrics for each portfolio
    ret = []
    vol = []
    sharpe = []
    
    for weights in all_weights
        expected_return, risk, sharpe_ratio = calculate_portfolio_metrics(weights, returns)
        push!(ret, expected_return)
        push!(vol, risk)
        push!(sharpe, sharpe_ratio)
    end
    
    # Find minimum volatility portfolio
    min_vol_idx = argmin(vol)
    min_vol_ret = ret[min_vol_idx]
    min_vol_vol = vol[min_vol_idx]
    
    # Find maximum Sharpe ratio portfolio
    max_sharpe_idx = argmax(sharpe)
    max_sharpe_ret = ret[max_sharpe_idx]
    max_sharpe_vol = vol[max_sharpe_idx]
    
    # Optimize using PSO for maximum Sharpe ratio
    pso_result = optimize_portfolio(returns, num_assets; algorithm="pso", objective="sharpe")
    pso_ret = pso_result["expected_return"]
    pso_vol = pso_result["risk"]
    
    # Optimize using DE for maximum Sharpe ratio
    de_result = optimize_portfolio(returns, num_assets; algorithm="de", objective="sharpe")
    de_ret = de_result["expected_return"]
    de_vol = de_result["risk"]
    
    # Create plot
    p = scatter(vol, ret, 
        xlabel="Annualized Volatility (%)", 
        ylabel="Annualized Return (%)",
        title="Efficient Frontier",
        legend=:bottomright,
        markersize=2,
        markerstrokewidth=0,
        markeralpha=0.5,
        label="Random Portfolios"
    )
    
    # Add minimum volatility portfolio
    scatter!([min_vol_vol], [min_vol_ret], 
        markersize=6, 
        markershape=:star, 
        color=:blue, 
        label="Minimum Volatility"
    )
    
    # Add maximum Sharpe ratio portfolio
    scatter!([max_sharpe_vol], [max_sharpe_ret], 
        markersize=6, 
        markershape=:star, 
        color=:green, 
        label="Maximum Sharpe (Random)"
    )
    
    # Add PSO optimized portfolio
    scatter!([pso_vol], [pso_ret], 
        markersize=6, 
        markershape=:star, 
        color=:red, 
        label="PSO Optimized"
    )
    
    # Add DE optimized portfolio
    scatter!([de_vol], [de_ret], 
        markersize=6, 
        markershape=:star, 
        color=:purple, 
        label="DE Optimized"
    )
    
    return p
end

"""
    plot_convergence(pso_result, de_result)

Plot convergence curves for PSO and DE algorithms.

# Arguments
- `pso_result::Dict`: PSO optimization result
- `de_result::Dict`: DE optimization result

# Returns
- `Plot`: Convergence plot
"""
function plot_convergence(pso_result, de_result)
    p = plot(
        1:length(pso_result["convergence_curve"]),
        -pso_result["convergence_curve"],  # Negate because we minimized negative Sharpe
        xlabel="Iteration",
        ylabel="Sharpe Ratio",
        title="Convergence Curves",
        label="PSO",
        linewidth=2
    )
    
    plot!(
        1:length(de_result["convergence_curve"]),
        -de_result["convergence_curve"],  # Negate because we minimized negative Sharpe
        label="DE",
        linewidth=2
    )
    
    return p
end

"""
    plot_weights(weights, asset_names)

Plot portfolio weights.

# Arguments
- `weights::Vector{Float64}`: Portfolio weights
- `asset_names::Vector{String}`: Asset names

# Returns
- `Plot`: Weights plot
"""
function plot_weights(weights, asset_names)
    p = bar(
        asset_names,
        weights,
        xlabel="Asset",
        ylabel="Weight",
        title="Portfolio Weights",
        legend=false,
        rotation=45
    )
    
    return p
end

"""
    run_portfolio_optimization()

Run the portfolio optimization example.
"""
function run_portfolio_optimization()
    println("Portfolio Optimization Example")
    println("==============================")
    
    # Create sample data if no file is provided
    println("Creating sample stock data...")
    
    # Define asset names
    asset_names = ["AAPL", "MSFT", "AMZN", "GOOGL", "META", "TSLA", "NVDA", "JPM", "V", "PG"]
    num_assets = length(asset_names)
    
    # Create sample price data
    days = 252 * 5  # 5 years of daily data
    prices = DataFrame()
    prices[!, :Date] = Date(2018, 1, 1):Day(1):Date(2018, 1, 1) + Day(days - 1)
    
    # Generate random price series with some correlation
    correlation_matrix = 0.5 * ones(num_assets, num_assets) + 0.5 * I
    cholesky_factor = cholesky(correlation_matrix).L
    
    # Generate correlated random walks
    for (i, asset) in enumerate(asset_names)
        # Start with a random price between 50 and 200
        start_price = 50 + rand() * 150
        
        # Generate price series
        price_series = [start_price]
        for _ in 2:days
            # Daily return with drift and volatility
            daily_return = 0.0001 + 0.01 * randn()
            push!(price_series, price_series[end] * (1 + daily_return))
        end
        
        prices[!, asset] = price_series
    end
    
    # Calculate returns
    println("Calculating returns...")
    returns = calculate_returns(prices)
    
    # Convert returns to matrix (excluding date column)
    returns_matrix = Matrix(returns[!, Not(:Date)])
    
    # Optimize portfolio using PSO
    println("Optimizing portfolio using PSO...")
    pso_result = optimize_portfolio(returns_matrix, num_assets; algorithm="pso", objective="sharpe")
    
    println("PSO Results:")
    println("  Expected Return: $(round(pso_result["expected_return"], digits=2))%")
    println("  Risk: $(round(pso_result["risk"], digits=2))%")
    println("  Sharpe Ratio: $(round(pso_result["sharpe_ratio"], digits=2))")
    println("  Iterations: $(pso_result["iterations"])")
    println("  Function Evaluations: $(pso_result["evaluations"])")
    
    # Optimize portfolio using DE
    println("Optimizing portfolio using DE...")
    de_result = optimize_portfolio(returns_matrix, num_assets; algorithm="de", objective="sharpe")
    
    println("DE Results:")
    println("  Expected Return: $(round(de_result["expected_return"], digits=2))%")
    println("  Risk: $(round(de_result["risk"], digits=2))%")
    println("  Sharpe Ratio: $(round(de_result["sharpe_ratio"], digits=2))")
    println("  Iterations: $(de_result["iterations"])")
    println("  Function Evaluations: $(de_result["evaluations"])")
    
    # Plot efficient frontier
    println("Plotting efficient frontier...")
    p1 = plot_efficient_frontier(returns_matrix, num_assets, asset_names)
    
    # Plot convergence curves
    println("Plotting convergence curves...")
    p2 = plot_convergence(pso_result, de_result)
    
    # Plot portfolio weights
    println("Plotting portfolio weights...")
    p3 = plot_weights(pso_result["weights"], asset_names)
    p4 = plot_weights(de_result["weights"], asset_names)
    
    # Save plots
    println("Saving plots...")
    savefig(p1, "efficient_frontier.png")
    savefig(p2, "convergence_curves.png")
    savefig(p3, "pso_weights.png")
    savefig(p4, "de_weights.png")
    
    println("Done! Plots saved to current directory.")
    
    return Dict(
        "pso_result" => pso_result,
        "de_result" => de_result,
        "plots" => Dict(
            "efficient_frontier" => p1,
            "convergence_curves" => p2,
            "pso_weights" => p3,
            "de_weights" => p4
        )
    )
end

# Run the example if this file is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    run_portfolio_optimization()
end
