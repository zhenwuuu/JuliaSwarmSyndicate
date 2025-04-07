using JuliaOS
using JuliaOS.MarketData
using JuliaOS.SwarmManager
using JuliaOS.SwarmManager.Algorithms
using Plots
using Random
using Statistics
using LinearAlgebra
using Dates

# Set a random seed for reproducibility
Random.seed!(42)

"""
    generate_synthetic_market_data(days::Int, volatility::Float64=0.02)

Generate synthetic market data for testing optimization algorithms.
"""
function generate_synthetic_market_data(days::Int, volatility::Float64=0.02)
    market_data = Vector{MarketData.MarketDataPoint}()
    
    # Initial price
    price = 100.0
    
    # Generate price data with a slight upward trend
    for day in 1:days
        # Add some random walk with a slight bias
        price *= (1.0 + randn() * volatility + 0.0002)
        
        # Volume varies too
        volume = 10000 * (1.0 + rand() * 0.5)
        
        # Calculate some indicators
        indicators = Dict{String, Float64}()
        
        # Simple MA indicators (we'll calculate these properly)
        if day > 20
            indicators["sma_20"] = mean([market_data[i].price for i in (day-20):(day-1)])
        else
            indicators["sma_20"] = price
        end
        
        if day > 50
            indicators["sma_50"] = mean([market_data[i].price for i in (day-50):(day-1)])
        else
            indicators["sma_50"] = price
        end
        
        # RSI calculation (simplified)
        if day > 14
            price_changes = [market_data[i].price - market_data[i-1].price for i in (day-13):(day-1)]
            gains = [max(0, change) for change in price_changes]
            losses = [max(0, -change) for change in price_changes]
            
            avg_gain = mean(gains)
            avg_loss = mean(losses)
            
            if avg_loss == 0
                indicators["rsi"] = 100.0
            else
                rs = avg_gain / avg_loss
                indicators["rsi"] = 100.0 - (100.0 / (1.0 + rs))
            end
        else
            indicators["rsi"] = 50.0
        end
        
        # Bollinger Bands
        if day > 20
            prices = [market_data[i].price for i in (day-20):(day-1)]
            sma = mean(prices)
            std_dev = std(prices)
            
            indicators["bb_upper"] = sma + 2 * std_dev
            indicators["bb_middle"] = sma
            indicators["bb_lower"] = sma - 2 * std_dev
        else
            indicators["bb_upper"] = price * 1.05
            indicators["bb_middle"] = price
            indicators["bb_lower"] = price * 0.95
        end
        
        # Create MarketDataPoint
        data_point = MarketData.MarketDataPoint(
            now() + Day(day),  # Timestamp
            price,
            volume,
            volume * price,   # Liquidity
            indicators
        )
        
        push!(market_data, data_point)
    end
    
    return market_data
end

"""
    backtest_strategy(market_data, strategy_params)

Backtest a trading strategy with the given parameters.
Returns performance metrics including total return, Sharpe ratio, etc.
"""
function backtest_strategy(market_data, strategy_params)
    # Extract strategy parameters
    entry_threshold = strategy_params[1]  # RSI threshold for entry (0-1 scale, will multiply by 100)
    exit_threshold = strategy_params[2]   # RSI threshold for exit (0-1 scale, will multiply by 100)
    stop_loss = strategy_params[3]        # Stop loss percentage
    take_profit = strategy_params[4]      # Take profit percentage
    
    # Initialize
    portfolio_value = 10000.0  # Initial capital
    position_size = 0.0
    in_position = false
    entry_price = 0.0
    
    # Performance tracking
    returns = Float64[]
    equity_curve = [portfolio_value]
    trade_count = 0
    winning_trades = 0
    
    # Loop through market data
    for i in 2:length(market_data)
        data = market_data[i]
        prev_data = market_data[i-1]
        
        # Get indicators
        rsi = get(data.indicators, "rsi", 50.0)
        bb_upper = get(data.indicators, "bb_upper", data.price * 1.05)
        bb_lower = get(data.indicators, "bb_lower", data.price * 0.95)
        bb_position = (data.price - bb_lower) / (bb_upper - bb_lower)
        
        # Strategy logic
        if !in_position
            # Entry signal: RSI < threshold and price near lower BB
            if rsi < (entry_threshold * 100) && bb_position < 0.2
                # Enter position
                entry_price = data.price
                position_size = portfolio_value / entry_price
                in_position = true
                trade_count += 1
            end
        else
            # Calculate current return
            current_return = (data.price - entry_price) / entry_price
            
            # Check exit conditions
            exit_signal = false
            
            # 1. Technical exit: RSI > threshold or price near upper BB
            if rsi > (exit_threshold * 100) || bb_position > 0.8
                exit_signal = true
            end
            
            # 2. Stop loss
            if current_return <= -stop_loss
                exit_signal = true
            end
            
            # 3. Take profit
            if current_return >= take_profit
                exit_signal = true
            end
            
            # Execute exit if signal triggered
            if exit_signal
                # Close position
                portfolio_value = position_size * data.price
                push!(returns, current_return)
                push!(equity_curve, portfolio_value)
                
                # Update statistics
                if current_return > 0
                    winning_trades += 1
                end
                
                # Reset position
                in_position = false
                position_size = 0.0
            end
        end
    end
    
    # Calculate performance metrics
    if isempty(returns)
        return Dict(
            "total_return" => 0.0,
            "sharpe_ratio" => 0.0,
            "max_drawdown" => 0.0,
            "win_rate" => 0.0
        )
    end
    
    # Total return
    total_return = (portfolio_value - 10000.0) / 10000.0
    
    # Sharpe ratio (simplified, assuming 0 risk-free rate)
    sharpe_ratio = length(returns) > 1 ? mean(returns) / std(returns) * sqrt(252) : 0.0
    
    # Maximum drawdown
    peak = equity_curve[1]
    max_drawdown = 0.0
    
    for value in equity_curve
        if value > peak
            peak = value
        else
            drawdown = (peak - value) / peak
            max_drawdown = max(max_drawdown, drawdown)
        end
    end
    
    # Win rate
    win_rate = trade_count > 0 ? winning_trades / trade_count : 0.0
    
    return Dict(
        "total_return" => total_return,
        "sharpe_ratio" => sharpe_ratio,
        "max_drawdown" => max_drawdown,
        "win_rate" => win_rate
    )
end

"""
    optimize_trading_strategy(market_data, algorithm_type, params, iterations)

Optimize trading strategy parameters using the specified algorithm.
"""
function optimize_trading_strategy(market_data, algorithm_type, params, iterations)
    # Trading strategy params to optimize:
    # 1. Entry RSI threshold (normalized 0-1)
    # 2. Exit RSI threshold (normalized 0-1)
    # 3. Stop loss percentage (0.01-0.20)
    # 4. Take profit percentage (0.01-0.50)
    dimension = 4
    bounds = [
        (0.0, 1.0),    # Entry RSI (will be multiplied by 100)
        (0.0, 1.0),    # Exit RSI (will be multiplied by 100)
        (0.01, 0.20),  # Stop loss 1%-20%
        (0.01, 0.50)   # Take profit 1%-50%
    ]
    
    # Define fitness function (negative of portfolio performance)
    function fitness_function(position)
        metrics = backtest_strategy(market_data, position)
        
        # Combine metrics into a single value to minimize
        # We use negative values since we want to maximize returns and Sharpe
        fitness = -(
            metrics["total_return"] * 0.5 +  # 50% weight on returns
            metrics["sharpe_ratio"] * 0.3 +  # 30% weight on risk-adjusted returns
            metrics["win_rate"] * 0.1 -      # 10% weight on win rate
            metrics["max_drawdown"] * 0.1    # 10% penalty on drawdown
        )
        
        return fitness
    end
    
    # Create and initialize algorithm
    algorithm = create_algorithm(algorithm_type, params)
    initialize!(algorithm, 30, dimension, bounds)
    
    # Track progress
    convergence = Float64[]
    
    # Run optimization
    for i in 1:iterations
        # Update algorithm
        update_positions!(algorithm, fitness_function)
        
        # Track progress
        best_fitness = get_best_fitness(algorithm)
        push!(convergence, best_fitness)
        
        if i % 5 == 0
            println("$algorithm_type - Iteration $i: Best fitness = $best_fitness")
        end
    end
    
    # Get best solution
    best_position = get_best_position(algorithm)
    best_metrics = backtest_strategy(market_data, best_position)
    
    return Dict(
        "algorithm" => algorithm_type,
        "best_position" => best_position,
        "metrics" => best_metrics,
        "convergence" => convergence
    )
end

"""
    plot_equity_curve(market_data, strategy_params)

Plot the equity curve for a strategy with the given parameters.
"""
function plot_equity_curve(market_data, strategy_params)
    # Run backtest
    portfolio_value = 10000.0
    position_size = 0.0
    in_position = false
    entry_price = 0.0
    equity_curve = [portfolio_value]
    trade_dates = [market_data[1].timestamp]
    
    # Extract parameters
    entry_threshold = strategy_params[1]
    exit_threshold = strategy_params[2]
    stop_loss = strategy_params[3]
    take_profit = strategy_params[4]
    
    # Loop through market data
    for i in 2:length(market_data)
        data = market_data[i]
        prev_data = market_data[i-1]
        
        # Get indicators
        rsi = get(data.indicators, "rsi", 50.0)
        bb_upper = get(data.indicators, "bb_upper", data.price * 1.05)
        bb_lower = get(data.indicators, "bb_lower", data.price * 0.95)
        bb_position = (data.price - bb_lower) / (bb_upper - bb_lower)
        
        # Strategy logic
        if !in_position
            # Entry signal
            if rsi < (entry_threshold * 100) && bb_position < 0.2
                entry_price = data.price
                position_size = portfolio_value / entry_price
                in_position = true
            end
        else
            # Calculate current return
            current_return = (data.price - entry_price) / entry_price
            
            # Check exit conditions
            exit_signal = false
            
            # Technical exit
            if rsi > (exit_threshold * 100) || bb_position > 0.8
                exit_signal = true
            end
            
            # Stop loss
            if current_return <= -stop_loss
                exit_signal = true
            end
            
            # Take profit
            if current_return >= take_profit
                exit_signal = true
            end
            
            # Execute exit
            if exit_signal
                portfolio_value = position_size * data.price
                in_position = false
                position_size = 0.0
            end
        end
        
        # Update equity curve
        current_value = in_position ? position_size * data.price : portfolio_value
        push!(equity_curve, current_value)
        push!(trade_dates, data.timestamp)
    end
    
    # Create plot
    p = plot(title="Trading Strategy Equity Curve", xlabel="Trading Days", ylabel="Account Value ($)")
    plot!(p, 1:length(equity_curve), equity_curve, label="Equity", linewidth=2)
    
    return p
end

"""
    plot_convergence_comparison(results)

Plot convergence comparison for multiple algorithms.
"""
function plot_convergence_comparison(results)
    p = plot(title="Algorithm Convergence Comparison", xlabel="Iteration", ylabel="Fitness", legend=:topright)
    
    for result in results
        # Convert to positive values for better visualization
        convergence = -result["convergence"]
        algo_name = result["algorithm"]
        
        plot!(p, convergence, label=algo_name, linewidth=2)
    end
    
    return p
end

"""
    main()

Main function to run the trading optimization example.
"""
function main()
    println("Starting trading strategy optimization...")
    
    # Generate synthetic market data
    println("Generating synthetic market data...")
    days = 365
    market_data = generate_synthetic_market_data(days)
    println("Generated $(length(market_data)) days of market data")
    
    # Define algorithms to compare
    algorithms = [
        ("pso", Dict("inertia_weight" => 0.7, "cognitive_coef" => 1.5, "social_coef" => 1.5)),
        ("gwo", Dict("alpha_param" => 2.0, "decay_rate" => 0.01)),
        ("woa", Dict("a_decrease_factor" => 2.0, "spiral_constant" => 1.0)),
        ("genetic", Dict("crossover_rate" => 0.8, "mutation_rate" => 0.1)),
        ("aco", Dict("evaporation_rate" => 0.1, "alpha" => 1.0, "beta" => 2.0))
    ]
    
    # Optimize with each algorithm
    iterations = 50
    results = []
    
    for (algo_type, params) in algorithms
        println("\nRunning optimization with $algo_type...")
        result = optimize_trading_strategy(market_data, algo_type, params, iterations)
        
        # Print results
        best_params = result["best_position"]
        metrics = result["metrics"]
        
        println("Best parameters found:")
        println("  Entry RSI threshold: $(round(best_params[1] * 100, digits=1))")
        println("  Exit RSI threshold: $(round(best_params[2] * 100, digits=1))")
        println("  Stop loss: $(round(best_params[3] * 100, digits=1))%")
        println("  Take profit: $(round(best_params[4] * 100, digits=1))%")
        println("Performance metrics:")
        println("  Total return: $(round(metrics["total_return"] * 100, digits=2))%")
        println("  Sharpe ratio: $(round(metrics["sharpe_ratio"], digits=2))")
        println("  Max drawdown: $(round(metrics["max_drawdown"] * 100, digits=2))%")
        println("  Win rate: $(round(metrics["win_rate"] * 100, digits=2))%")
        
        push!(results, result)
    end
    
    # Compare and find the best algorithm
    best_algo_idx = argmax([r["metrics"]["total_return"] for r in results])
    best_result = results[best_algo_idx]
    best_algo = best_result["algorithm"]
    
    println("\n=== Best Performing Algorithm: $best_algo ===")
    
    # Plot equity curve for the best algorithm
    best_params = best_result["best_position"]
    p_equity = plot_equity_curve(market_data, best_params)
    
    # Plot convergence comparison
    p_convergence = plot_convergence_comparison(results)
    
    # Save plots
    savefig(p_equity, "best_strategy_equity.png")
    savefig(p_convergence, "algorithm_convergence.png")
    
    # Combined plot
    plot(p_equity, p_convergence, layout=(2,1), size=(800, 800))
    savefig("trading_optimization_results.png")
    
    println("\nOptimization completed. Results saved to current directory.")
end

# Run the main function
main() 