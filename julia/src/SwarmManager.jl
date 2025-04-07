module SwarmManager

using JSON
using Dates
using Statistics
using Random
using LinearAlgebra
using ..MarketData
using ..Bridge
using ..Algorithms
using ..DEX # Import DEX module
using Logging
using DataFrames
using Base.Threads

# Import OptimizationAlgorithm directly from Algorithms
import ..Algorithms: OptimizationAlgorithm, PSO, GWO, ACO, GA, WOA, DE
# Import specific functions needed from Algorithms
import ..Algorithms: initialize!, evaluate_fitness!, select_leaders!, update_positions!, get_best_position, get_best_fitness, get_convergence_data

export SwarmConfig, create_swarm, start_swarm!, update_swarm!, calculate_fitness, stop_swarm!
export TradingStrategy, execute_trade!, get_portfolio_value, get_trading_history
export create_trading_strategy, backtest_strategy, generate_trading_signals

# Renamed config to avoid conflict with Swarm struct config field
struct SwarmManagerConfig
    name::String
    algorithm::Dict{String, Any} # Store type and params
    num_particles::Int
    num_iterations::Int # Max iterations if run synchronously, or can be used differently for async
    trading_pairs::Vector{String}
    # Add other config fields like market data provider details if needed
end

mutable struct Swarm
    config::SwarmManagerConfig # Use the renamed config struct
    algorithm::OptimizationAlgorithm
    market_data::Vector{MarketData.MarketDataPoint} # Holds current/historical data
    performance_metrics::Dict{String, Any} # Allow Any for flexibility (e.g., history)
    chain::String
    dex::String
    # Runtime state management fields
    is_running::Bool
    task_handle::Union{Task, Nothing}
    last_fitness_update::Union{DateTime, Nothing}
    fitness_history::Dict{DateTime, Float64} # Track fitness over time

    # Constructor
    function Swarm(config::SwarmManagerConfig, algorithm::OptimizationAlgorithm, chain::String, dex::String)
        new(config,
            algorithm,
            Vector{MarketData.MarketDataPoint}(), # Initialize empty market data
            Dict{String, Any}(), # Initialize empty metrics
            chain,
            dex,
            false, # Initially not running
            nothing, # No task handle initially
            nothing, # No fitness update initially
            Dict{DateTime, Float64}() # Initialize empty fitness history
            )
    end
end

# New structure to hold trading strategy details
mutable struct TradingStrategy
    swarm::Swarm
    wallet_address::String
    max_position_size::Float64  # Percentage of portfolio (0.0-1.0)
    active_positions::Dict{String, Dict{String, Any}}  # Pair => position details
    trading_history::Vector{Dict{String, Any}}
    risk_params::Dict{String, Any}
    is_active::Bool
end

# --- Placeholder Symbol-to-Address Map (Needs Improvement!) ---
# TODO: Replace this with a robust lookup mechanism (config file, token registry service)
const SYMBOL_TO_ADDRESS_MAP = Dict(
    # Ethereum Mainnet Examples
    "WETH" => "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    "USDC" => "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    "DAI" => "0x6B175474E89094C44Da98b954EedeAC495271d0F",
    "WBTC" => "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599"
    # Add other common tokens for relevant chains if needed for testing
)

function create_swarm(config::SwarmManagerConfig, chain::String="ethereum", dex::String="uniswap-v3")
    # Create an algorithm instance based on config
    algo_type = get(config.algorithm, "type", "pso")
    algo_params = get(config.algorithm, "params", Dict{String, Any}())

    # Create the algorithm using our factory function
    algorithm = Algorithms.create_algorithm(algo_type, algo_params)

    # Create and return a new swarm using the constructor
    return Swarm(config, algorithm, chain, dex)
end

"""
    start_swarm!(swarm::Swarm)

Initialize the swarm algorithm and start the asynchronous optimization loop.
Assumes initial market data might be needed for the first fitness calculation,
but the loop itself should handle fetching subsequent data.
"""
function start_swarm!(swarm::Swarm)
    if swarm.is_running
        @warn "Swarm '$(swarm.config.name)' is already running."
        return false
    end

    @info "Starting swarm '$(swarm.config.name)'..."

    # --- Initialization ---
    try
        # Define trading dimensions (parameters to optimize)
        # TODO: Make dimension and bounds configurable or derive from strategy
        dimension = 4
        bounds = [
            (0.0, 1.0),    # entry_threshold: 0-1 normalized value
            (0.0, 1.0),    # exit_threshold: 0-1 normalized value
            (0.01, 0.2),   # stop_loss: 1-20%
            (0.01, 0.5)    # take_profit: 1-50%
        ]

        # Initialize the algorithm
        initialize!(swarm.algorithm, swarm.config.num_particles, dimension, bounds)

        # Define fitness function (trading performance)
        # This function needs access to *current* market data when called within the loop
        fitness_function = position -> calculate_fitness(position, swarm)

        # Evaluate initial fitness
        # TODO: Ensure swarm.market_data has *some* initial data before this call
        if isempty(swarm.market_data)
             @warn "Initial market data is empty for swarm '$(swarm.config.name)'. Fetching initial data..."
             # Placeholder: Fetch initial data for all configured pairs
             for pair in swarm.config.trading_pairs
                 initial_data = MarketData.fetch_market_data(swarm.chain, swarm.dex, pair, limit=100) # Fetch 100 points
                 if !isnothing(initial_data)
                     append!(swarm.market_data, initial_data)
                 else
                     @error "Failed to fetch initial market data for pair $pair on $(swarm.chain)/$(swarm.dex)"
                 end
             end
             # Remove duplicates if fetching overlaps
             unique!(md -> (md.pair, md.timestamp), swarm.market_data)
             sort!(swarm.market_data, by = x -> x.timestamp)
             if isempty(swarm.market_data)
                 error("Failed to obtain any initial market data for swarm '$(swarm.config.name)'. Cannot calculate initial fitness.")
             end
        end

        evaluate_fitness!(swarm.algorithm, fitness_function)
        select_leaders!(swarm.algorithm)

        # Store initial metrics
        best_position = get_best_position(swarm.algorithm)
        best_fitness = get_best_fitness(swarm.algorithm)
        swarm.performance_metrics["initial_best_fitness"] = best_fitness
        swarm.performance_metrics["best_fitness"] = best_fitness
        swarm.performance_metrics["best_position"] = best_position # Store the vector
        swarm.performance_metrics["iterations"] = 0
        swarm.fitness_history[now()] = best_fitness
        swarm.last_fitness_update = now()

    catch e
        @error "Error during swarm initialization for '$(swarm.config.name)': $e" stacktrace(catch_backtrace())
        swarm.is_running = false # Ensure it's marked as not running
        return false # Indicate failure
    end

    # --- Asynchronous Loop ---
    swarm.is_running = true
    swarm.task_handle = @async begin
        try
            @info "Asynchronous optimization loop started for swarm '$(swarm.config.name)'."
            iteration = 0
            # Define how many data points to keep in memory (e.g., last 1000)
            max_data_points_per_pair = get(swarm.config.algorithm, "data_window_size", 1000)

            while swarm.is_running
                iteration += 1
                @debug "Swarm '$(swarm.config.name)' - Iteration $iteration starting..."

                # 1. Fetch NEW market data required for this iteration
                new_data_fetched_count = 0
                current_time = now()
                @debug "Fetching new market data for swarm '$(swarm.config.name)' around $current_time..."
                for pair in swarm.config.trading_pairs
                    try
                        # Fetch the latest data point (limit=1)
                        # Adjust timeframe/limit as needed (e.g., "1m", limit=5)
                        new_data = MarketData.fetch_market_data(swarm.chain, swarm.dex, pair, limit=2) # Fetch last 2 to ensure we get latest closed candle

                        if !isnothing(new_data) && !isempty(new_data)
                            # Append only if the data is newer than the last known point for this pair
                            last_ts_for_pair = maximum(dp.timestamp for dp in swarm.market_data if dp.pair == pair; init=DateTime(0))
                            added_count = 0
                            for dp in new_data
                                if dp.timestamp > last_ts_for_pair
                                     push!(swarm.market_data, dp)
                                     new_data_fetched_count += 1
                                     added_count += 1
                                end
                            end
                             @debug "Fetched $added_count new data point(s) for $pair."
                        else
                            @warn "No new market data fetched for pair $pair on $(swarm.chain)/$(swarm.dex) in iteration $iteration."
                        end
                    catch fetch_error
                         @error "Error fetching market data for pair $pair in iteration $iteration: $fetch_error"
                         # Decide whether to continue or stop the loop on fetch error
                         # continue # Continue to next pair
                    end
                end

                if new_data_fetched_count > 0
                     # Sort and prune data (important after adding new points)
                     sort!(swarm.market_data, by = x -> x.timestamp)
                     unique!(md -> (md.pair, md.timestamp), swarm.market_data)

                     # Prune older data to keep memory usage manageable
                     current_length = length(swarm.market_data)
                     # Calculate rough max length based on pairs and window size
                     max_total_points = length(swarm.config.trading_pairs) * max_data_points_per_pair
                     if current_length > max_total_points * 1.1 # Allow some buffer
                         num_to_remove = current_length - max_total_points
                         swarm.market_data = swarm.market_data[num_to_remove + 1:end]
                         @debug "Pruned $(num_to_remove) old data points. New count: $(length(swarm.market_data))."
                     end
                end

                # Ensure we have enough data to proceed (maybe after fetching)
                if isempty(swarm.market_data) || length(swarm.market_data) < 2 # Need at least 2 points for indicators/logic
                    @warn "Not enough market data available for swarm '$(swarm.config.name)' after fetch in iteration $iteration. Skipping update."
                    sleep(5) # Wait before trying again
                    continue
                end

                # 2. Update algorithm positions based on the *latest* data
                update_positions!(swarm.algorithm, fitness_function)

                # 3. Evaluate fitness with the *latest* data
                evaluate_fitness!(swarm.algorithm, fitness_function)

                # 4. Select new leaders
                select_leaders!(swarm.algorithm)

                # 5. Update performance metrics
                current_best_position = get_best_position(swarm.algorithm)
                current_best_fitness = get_best_fitness(swarm.algorithm)
                timestamp = now()

                swarm.performance_metrics["best_fitness"] = current_best_fitness
                swarm.performance_metrics["best_position"] = current_best_position
                swarm.performance_metrics["iterations"] = iteration
                # Store convergence data? Requires get_convergence_data impl in Algorithms
                # swarm.performance_metrics["convergence_history"] = get_convergence_data(swarm.algorithm)
                swarm.last_fitness_update = timestamp
                swarm.fitness_history[timestamp] = current_best_fitness

                @debug "Swarm '$(swarm.config.name)' - Iteration $iteration finished. Best Fitness: $current_best_fitness"

                # 6. Sleep to prevent busy-waiting and allow other tasks
                # TODO: Make sleep duration configurable (e.g., via swarm config)
                sleep_duration = get(swarm.config.algorithm, "iteration_delay_seconds", 5)
                sleep(sleep_duration)

                # Check if max iterations reached (optional, if configured)
                # if swarm.config.num_iterations > 0 && iteration >= swarm.config.num_iterations
                #     @info "Swarm '$(swarm.config.name)' reached configured max iterations ($(swarm.config.num_iterations)). Stopping."
                #     swarm.is_running = false # Signal loop to stop
                # end
            end
            @info "Asynchronous optimization loop stopped for swarm '$(swarm.config.name)'."
        catch e
            @error "Error in async swarm loop for '$(swarm.config.name)': $e" stacktrace(catch_backtrace())
            swarm.is_running = false # Ensure stopped on error
            swarm.performance_metrics["error"] = sprint(showerror, e) # Record error
        finally
             swarm.is_running = false # Ensure is_running is false when loop exits
             swarm.task_handle = nothing # Clear task handle
             @info "Cleaned up task handle for swarm '$(swarm.config.name)'."
        end
    end

    @info "Swarm '$(swarm.config.name)' start sequence initiated. Loop running asynchronously."
    return true # Indicate successful start initiation
end

"""
    stop_swarm!(swarm::Swarm)

Signal the asynchronous optimization loop to stop.
"""
function stop_swarm!(swarm::Swarm)
    if !swarm.is_running
        @warn "Swarm '$(swarm.config.name)' is not currently running."
        return false
    end
    if isnothing(swarm.task_handle)
         @warn "Swarm '$(swarm.config.name)' is marked as running but has no task handle. Setting is_running=false."
         swarm.is_running = false
         return false
     end

    @info "Stopping swarm '$(swarm.config.name)'..."
    swarm.is_running = false # Signal the loop to stop

    # Optional: Wait for the task to finish with a timeout
    # try
    #     @async begin
    #         sleep(10) # Timeout after 10 seconds
    #         if !istaskdone(swarm.task_handle)
    #             @warn "Swarm task for '$(swarm.config.name)' did not finish within timeout. It might be stuck."
    #             # Consider stronger measures if needed, like interrupting the task (use with caution)
    #         end
    #     end
    #     wait(swarm.task_handle)
    #     @info "Swarm task for '$(swarm.config.name)' finished gracefully."
    # catch e
    #      @error "Error waiting for swarm task '$(swarm.config.name)' to stop: $e"
    # end

    # swarm.task_handle = nothing # Handled in the finally block of the task now
    @info "Stop signal sent to swarm '$(swarm.config.name)'. Loop will terminate shortly."
    return true
end

"""
    update_swarm!(swarm::Swarm, new_market_data::Vector{MarketData.MarketDataPoint})

Update the swarm's market data. The async loop should use this updated data.
NOTE: This function's role might change. The async loop should ideally fetch data.
      This could be used to inject specific historical data or override.
"""
function update_swarm!(swarm::Swarm, new_market_data::Vector{MarketData.MarketDataPoint})
     @info "Updating market data for swarm '$(swarm.config.name)'. (Current loop iteration will use new data if implemented)"
    # Append and manage data (ensure time order, handle duplicates)
    append!(swarm.market_data, new_market_data)
    unique!(md -> (md.pair, md.timestamp), swarm.market_data)
    sort!(swarm.market_data, by = x -> x.timestamp)
    # Optional: Limit the size of swarm.market_data to prevent memory issues
    # max_data_points = 10000
    # if length(swarm.market_data) > max_data_points
    #     swarm.market_data = swarm.market_data[end-max_data_points+1:end]
    # end
    return true # Indicate data was received
end

# calculate_fitness needs access to the *current* state of swarm.market_data
function calculate_fitness(position::Vector{Float64}, swarm::Swarm)
    # Check if market data is available
    if isempty(swarm.market_data)
        @warn "Market data is empty for swarm '$(swarm.config.name)' during fitness calculation. Returning default poor fitness."
        return Inf # Return a very poor fitness score
    end

    # Extract trading parameters from position
    entry_threshold = position[1]
    exit_threshold = position[2]
    stop_loss = position[3]
    take_profit = position[4]

    # Initialize trading variables
    portfolio_value = 10000.0  # Initial capital
    in_position = false
    entry_price = 0.0

    # Track performance metrics
    trade_count = 0
    winning_trades = 0
    max_drawdown = 0.0
    peak_value = portfolio_value

    # --- Backtesting Logic --- 
    # Use the market data currently held by the swarm object
    # Group data by pair for individual backtesting if multiple pairs
    data_by_pair = Dict{String, Vector{MarketData.MarketDataPoint}}()
    for dp in swarm.market_data
        if !haskey(data_by_pair, dp.pair)
            data_by_pair[dp.pair] = []
        end
        push!(data_by_pair[dp.pair], dp)
    end

    final_portfolio_value = portfolio_value # Start with initial capital
    total_trades = 0
    total_wins = 0

    # Simulate trading for each pair
    for (pair, pair_data) in data_by_pair
        if length(pair_data) < 2 continue end # Need at least 2 points

        pair_portfolio_value = 10000.0 # Simulate starting capital per pair for simplicity
        pair_in_position = false
        pair_entry_price = 0.0
        pair_trade_count = 0
        pair_winning_trades = 0
        pair_peak_value = pair_portfolio_value
        pair_max_drawdown = 0.0

        for (i, data_point) in enumerate(pair_data)
            if i < 2 continue end

            # Calculate indicators (simplified version)
            # TODO: Ensure indicators are present or calculated for data_point
            rsi = get(data_point.indicators, "rsi", 50.0)
            bb_upper = get(data_point.indicators, "bb_upper", data_point.price * 1.05)
            bb_lower = get(data_point.indicators, "bb_lower", data_point.price * 0.95)
            bb_position = (bb_upper - bb_lower) ≈ 0 ? 0.5 : (data_point.price - bb_lower) / (bb_upper - bb_lower)

            # Trading logic
            if !pair_in_position
                # Entry signal: RSI below threshold and price near lower BB
                if rsi < (entry_threshold * 100) && bb_position < 0.2
                    pair_in_position = true
                    pair_entry_price = data_point.price
                    pair_trade_count += 1
                end
            else
                # Calculate current return
                current_return = (data_point.price - pair_entry_price) / pair_entry_price

                # Exit conditions
                exit_signal = false

                # Exit signal: RSI above threshold or price near upper BB
                if rsi > (exit_threshold * 100) || bb_position > 0.8
                    exit_signal = true
                end
                # Stop loss
                if current_return < -stop_loss
                    exit_signal = true
                end
                # Take profit
                if current_return > take_profit
                    exit_signal = true
                end

                if exit_signal
                    pair_in_position = false
                    pair_portfolio_value *= (1.0 + current_return)

                    if current_return > 0
                        pair_winning_trades += 1
                    end

                    # Update peak value and calculate drawdown for this pair
                    if pair_portfolio_value > pair_peak_value
                         pair_peak_value = pair_portfolio_value
                     else
                         drawdown = (pair_peak_value - pair_portfolio_value) / pair_peak_value
                         if drawdown > pair_max_drawdown
                             pair_max_drawdown = drawdown
                         end
                     end
                end
            end
        end
        # Aggregate results (simple average for now, could be weighted)
         final_portfolio_value += (pair_portfolio_value - 10000.0)
         total_trades += pair_trade_count
         total_wins += pair_winning_trades
         max_drawdown = max(max_drawdown, pair_max_drawdown) # Use max drawdown across pairs
    end

    # Calculate overall performance metrics
    win_rate = total_trades > 0 ? total_wins / total_trades : 0.0
    total_return = (final_portfolio_value - 10000.0) / 10000.0

    # Calculate Sharpe ratio (simplified - needs risk-free rate and std dev of returns)
    # Using drawdown as a proxy for risk
    sharpe_proxy = max_drawdown > 0.01 ? total_return / max_drawdown : total_return * 10 # Penalize zero drawdown slightly less harshly

    # Combine metrics into a single fitness value (objective is to MINIMIZE this value)
    # We penalize poor performance. Higher return, win_rate, sharpe are good.
    # Minimize: -Return + (1 - WinRate) + (1 / (Sharpe + epsilon))
    fitness = -total_return * 0.6 + (1.0 - win_rate) * 0.2 + (1.0 / (sharpe_proxy + 0.1)) * 0.2

    # Handle cases resulting in NaN or Inf
    if isnan(fitness) || isinf(fitness)
        @warn "Fitness calculation resulted in NaN or Inf for swarm '$(swarm.config.name)'. Returning default poor fitness." position=position total_return=total_return win_rate=win_rate sharpe_proxy=sharpe_proxy
        return Inf # Return a very poor fitness score
    end

    return fitness
end

function generate_trading_signals(swarm::Swarm, market_data::MarketData.MarketDataPoint)
    # Get best parameters
    best_position = get_best_position(swarm.algorithm)
    entry_threshold = best_position[1]
    exit_threshold = best_position[2]
    
    # Get indicators
    rsi = get(market_data.indicators, "rsi", 50.0)
    bb_upper = get(market_data.indicators, "bb_upper", market_data.price * 1.05)
    bb_lower = get(market_data.indicators, "bb_lower", market_data.price * 0.95)
    bb_position = (market_data.price - bb_lower) / (bb_upper - bb_lower)
    
    signals = Vector{Dict{String, Any}}()
    
    # Generate buy signal
    if rsi < (entry_threshold * 100) && bb_position < 0.2
        push!(signals, Dict(
            "type" => "buy",
            "price" => market_data.price,
            "timestamp" => market_data.timestamp,
            "indicators" => market_data.indicators
        ))
    end
    
    # Generate sell signal
    if rsi > (exit_threshold * 100) || bb_position >= 0.8
        push!(signals, Dict(
            "type" => "sell",
            "price" => market_data.price,
            "timestamp" => market_data.timestamp,
            "indicators" => market_data.indicators
        ))
    end
    
    return signals
end

# New functions for trading strategy management

"""
    create_trading_strategy(swarm::Swarm, wallet_address::String; 
                           max_position_size::Float64=0.1)

Create a new trading strategy based on a swarm optimization.
"""
function create_trading_strategy(swarm::Swarm, wallet_address::String; 
                                max_position_size::Float64=0.1)
    # Initialize risk parameters
    best_position = get_best_position(swarm.algorithm)
    
    risk_params = Dict{String, Any}(
        "stop_loss" => best_position[3],
        "take_profit" => best_position[4],
        "max_drawdown" => 0.25,  # 25% max drawdown
        "max_open_positions" => 3,
        "position_sizing" => "equal",  # equal, kelly, volatility
        "slippage_tolerance" => 0.005  # 0.5% slippage tolerance
    )
    
    return TradingStrategy(
        swarm,
        wallet_address,
        max_position_size,
        Dict{String, Dict{String, Any}}(),
        Vector{Dict{String, Any}}(),
        risk_params,
        false
    )
end

"""
    backtest_strategy(strategy::TradingStrategy, 
                     historical_data::Vector{MarketData.MarketDataPoint})

Backtest a trading strategy with historical data.
"""
function backtest_strategy(strategy::TradingStrategy, 
                          historical_data::Vector{MarketData.MarketDataPoint})
    
    # Initialize portfolio
    portfolio_value = 10000.0
    current_positions = Dict{String, Dict{String, Any}}()
    trading_history = Vector{Dict{String, Any}}()
    
    # Get best parameters from the swarm
    best_position = get_best_position(strategy.swarm.algorithm)
    entry_threshold = best_position[1]
    exit_threshold = best_position[2]
    stop_loss = best_position[3]
    take_profit = best_position[4]
    
    # Track daily portfolio values for drawdown calculation
    daily_values = [portfolio_value]
    peak_value = portfolio_value
    max_drawdown = 0.0
    
    # Backtest over historical data
    for (i, data_point) in enumerate(historical_data)
        if i < 20
            continue  # Skip initial data points until we have enough for indicators
        end
        
        pair_key = "$(data_point.pair)"
        
        # Check for exit signals on existing positions
        if haskey(current_positions, pair_key)
            position = current_positions[pair_key]
            entry_price = position["entry_price"]
            current_return = (data_point.price - entry_price) / entry_price
            
            # Exit conditions
            exit_signal = false
            exit_reason = ""
            
            # Get indicators
            rsi = get(data_point.indicators, "rsi", 50.0)
            bb_upper = get(data_point.indicators, "bb_upper", data_point.price * 1.05)
            bb_lower = get(data_point.indicators, "bb_lower", data_point.price * 0.95)
            bb_position = (data_point.price - bb_lower) / (bb_upper - bb_lower)
            
            # Technical exit: RSI above threshold or price near upper BB
            if rsi > (exit_threshold * 100) || bb_position > 0.8
                exit_signal = true
                exit_reason = "technical"
            end
            
            # Stop loss
            if current_return < -stop_loss
                exit_signal = true
                exit_reason = "stop_loss"
            end
            
            # Take profit
            if current_return > take_profit
                exit_signal = true
                exit_reason = "take_profit"
            end
            
            if exit_signal
                # Calculate PnL
                position_size = position["size"]
                entry_value = position_size * entry_price
                exit_value = position_size * data_point.price
                pnl = exit_value - entry_value
                
                # Update portfolio value
                portfolio_value += pnl
                
                # Record trade
                trade = Dict(
                    "pair" => data_point.pair,
                    "chain" => data_point.chain,
                    "dex" => data_point.dex,
                    "type" => "sell",
                    "entry_price" => entry_price,
                    "exit_price" => data_point.price,
                    "size" => position_size,
                    "pnl" => pnl,
                    "return" => current_return,
                    "entry_time" => position["entry_time"],
                    "exit_time" => data_point.timestamp,
                    "exit_reason" => exit_reason
                )
                
                push!(trading_history, trade)
                
                # Remove from current positions
                delete!(current_positions, pair_key)
            end
        end
        
        # Check for entry signals
        if !haskey(current_positions, pair_key) && 
           length(current_positions) < strategy.risk_params["max_open_positions"]
            
            # Get indicators
            rsi = get(data_point.indicators, "rsi", 50.0)
            bb_upper = get(data_point.indicators, "bb_upper", data_point.price * 1.05)
            bb_lower = get(data_point.indicators, "bb_lower", data_point.price * 0.95)
            bb_position = (data_point.price - bb_lower) / (bb_upper - bb_lower)
            
            # Entry signal: RSI below threshold and price near lower BB
            if rsi < (entry_threshold * 100) && bb_position < 0.2
                # Calculate position size
                position_value = portfolio_value * strategy.max_position_size
                position_size = position_value / data_point.price
                
                # Record position
                current_positions[pair_key] = Dict(
                    "entry_price" => data_point.price,
                    "size" => position_size,
                    "entry_time" => data_point.timestamp,
                    "value" => position_value
                )
                
                # Record trade
                trade = Dict(
                    "pair" => data_point.pair,
                    "chain" => data_point.chain,
                    "dex" => data_point.dex,
                    "type" => "buy",
                    "price" => data_point.price,
                    "size" => position_size,
                    "value" => position_value,
                    "time" => data_point.timestamp
                )
                
                push!(trading_history, trade)
            end
        end
        
        # Update daily values if this is a new day
        if i == 1 || Dates.day(data_point.timestamp) != Dates.day(historical_data[i-1].timestamp)
            # Calculate current portfolio value including open positions
            current_value = portfolio_value
            for (pair, position) in current_positions
                position_size = position["size"]
                entry_price = position["entry_price"]
                current_price = data_point.price
                position_value = position_size * current_price
                current_value += position_value - (position_size * entry_price)
            end
            
            push!(daily_values, current_value)
            
            # Update peak value and drawdown
            if current_value > peak_value
                peak_value = current_value
            else
                drawdown = (peak_value - current_value) / peak_value
                if drawdown > max_drawdown
                    max_drawdown = drawdown
                end
            end
        end
    end
    
    # Calculate performance metrics
    win_trades = 0
    loss_trades = 0
    total_pnl = 0.0
    
    for trade in trading_history
        if haskey(trade, "pnl")
            total_pnl += trade["pnl"]
            if trade["pnl"] > 0
                win_trades += 1
            else
                loss_trades += 1
            end
        end
    end
    
    total_trades = win_trades + loss_trades
    win_rate = total_trades > 0 ? win_trades / total_trades : 0.0
    total_return = (portfolio_value - 10000.0) / 10000.0
    
    # Calculate Sharpe ratio (simplified)
    sharpe_ratio = 0.0
    if max_drawdown > 0
        sharpe_ratio = total_return / max_drawdown
    end
    
    results = Dict(
        "portfolio_value" => portfolio_value,
        "total_return" => total_return,
        "win_rate" => win_rate,
        "max_drawdown" => max_drawdown,
        "sharpe_ratio" => sharpe_ratio,
        "trade_count" => total_trades,
        "trading_history" => trading_history
    )
    
    return results
end

"""
    execute_trade!(strategy::TradingStrategy, signal::Dict{String,Any})

Execute a trade based on a trading signal.
"""
function execute_trade!(strategy::TradingStrategy, signal::Dict{String,Any})
    if !strategy.is_active
        @warn "Trading strategy is not active"
        return nothing
    end

    # Extract signal details
    signal_type = signal["type"]
    price = signal["price"]
    # Ensure indicators and pair exist
    if !haskey(signal, "indicators") || !haskey(signal["indicators"], "pair")
        @error "Signal is missing required 'indicators' or 'pair' field." signal=signal
        return nothing
    end
    pair = signal["indicators"]["pair"]
    chain = strategy.swarm.chain
    dex = strategy.swarm.dex

    # --- Token Address Resolution (Using Placeholder Map) ---
    tokens = split(pair, '/')
    if length(tokens) != 2
        @error "Invalid trading pair format: $pair"
        return nothing
    end
    token0_sym, token1_sym = tokens[1], tokens[2]

    token0_addr = get(SYMBOL_TO_ADDRESS_MAP, token0_sym, nothing)
    token1_addr = get(SYMBOL_TO_ADDRESS_MAP, token1_sym, nothing)

    if isnothing(token0_addr) || isnothing(token1_addr)
        @error "Token address not found in placeholder map for symbols: $token0_sym, $token1_sym" pair=pair
        @warn "Update the SYMBOL_TO_ADDRESS_MAP in SwarmManager.jl or implement a better lookup method."
        return nothing
    end
    @info "Resolved addresses: $token0_sym -> $token0_addr, $token1_sym -> $token1_addr" pair=pair
    # --- End Address Resolution ---

    # --- Get Token Decimals Dynamically ---
    connection = Blockchain.connect(network=chain)
    if !connection["connected"]
         @error "Failed to connect to $chain to fetch token decimals for trade execution."
         return nothing
     end

    decimals0 = Blockchain.getDecimals(token0_addr, connection)
    decimals1 = Blockchain.getDecimals(token1_addr, connection)

    if isnothing(decimals0)
        @warn "Could not fetch decimals for $token0_sym ($token0_addr) on $chain. Assuming 18."
        decimals0 = 18 # Fallback
    end
    if isnothing(decimals1)
        @warn "Could not fetch decimals for $token1_sym ($token1_addr) on $chain. Assuming 18."
        decimals1 = 18 # Fallback
    end
    @info "Using decimals: $token0_sym -> $decimals0, $token1_sym -> $decimals1"
    # --- End Decimal Fetching ---

    if signal_type == "buy"
        # Assume buying Token1 (e.g., WETH) by spending Token0 (e.g., USDC)
        token_in_addr = token0_addr
        token_out_addr = token1_addr
        decimals_in = decimals0
        decimals_out = decimals1

        # Check if we already have a position
        if haskey(strategy.active_positions, pair)
            @warn "Already have an active position for $pair, skipping buy signal."
            return nothing
        end

        # Fetch balance of the token we're spending (token_in)
        # Note: getTokenBalance internally uses getDecimals now
        balance_result = Bridge.get_wallet_balance(strategy.wallet_address, token_in_addr, chain)
        if !balance_result.success
            @warn "Failed to get balance for $token_in_addr: $(balance_result.error)"
            return nothing
        end
        available_balance = balance_result.data["balance"]

        # Calculate amount to spend based on strategy rules (e.g., max position size)
        position_value = available_balance * strategy.max_position_size
        amount_to_spend_wei = BigInt(floor(position_value * BigInt(10)^decimals_in))

        if amount_to_spend_wei <= 0
             @warn "Calculated amount to spend for $pair is zero or negative. Check balance and max_position_size."
             return nothing
         end

        trade_params = Dict(
            :token_in => token_in_addr,
            :token_out => token_out_addr,
            :amount_in_wei => amount_to_spend_wei,
            :slippage => strategy.risk_params["slippage_tolerance"],
            :wallet_address => strategy.wallet_address
        )

        bridge_result = Bridge.execute_trade(dex, chain, trade_params)

        if !bridge_result.success || !haskey(bridge_result.data, "status")
            @warn "Failed to prepare buy trade via Bridge: $(get(bridge_result.data, "message", bridge_result.error))"
            return nothing
        end

        # Check if unsigned transaction is ready (requires signing)
        if bridge_result.data["status"] == "unsigned_ready"
             @info "Buy transaction prepared by Bridge. Requires signing." unsigned_tx=bridge_result.data["unsigned_transaction"]
             # === TODO: Trigger signing flow ===
             # 1. Send bridge_result.data["unsigned_transaction"] to JS
             # 2. Receive signed_tx_hex back
             # 3. Call a new Bridge function like `send_signed_transaction(signed_tx_hex)`

             # For now, proceed with recording position based on estimates
             trade_data = bridge_result.data["details"] # Get original DEX estimate data
             estimated_amount_out_wei = parse(BigInt, trade_data["estimated_amount_out_wei"])
             size_val = Float64(estimated_amount_out_wei / BigInt(10)^decimals_out) # Use fetched decimals_out
             entry_price_val = size_val > 0 ? position_value / size_val : 0.0
             time_val = try DateTime(trade_data["timestamp"]) catch; now() end

             strategy.active_positions[pair] = Dict(
                 "entry_price" => entry_price_val,
                 "size" => size_val,
                 "entry_time" => time_val,
                 "trade_id" => "prep_"*string(rand(UInt32)), # Mark as prepared
                 "value" => position_value,
                 "status" => "prepared" # New status field
             )

             trade_record = Dict(
                "pair" => pair,
                "chain" => chain,
                "dex" => dex,
                "type" => "buy",
                "price" => entry_price_val,
                "size" => size_val,
                "value" => position_value,
                "time" => time_val,
                "trade_id" => "prep_"*string(rand(UInt32)),
                "tx_hash" => bridge_result.data["mock_tx_hash"], # Use mock hash for now
                "status" => "prepared"
             )
             push!(strategy.trading_history, trade_record)

             @info "Buy trade PREPARED (needs signing):" trade_record=trade_record
             return bridge_result.data # Return the preparation data
        else
             @warn "Unexpected status from Bridge.execute_trade: $(bridge_result.data["status"])"
             return nothing
        end

    elseif signal_type == "sell"
        # Assume selling Token1 (e.g., WETH) to receive Token0 (e.g., USDC)
        token_in_addr = token1_addr
        token_out_addr = token0_addr
        decimals_in = decimals1 # Use fetched decimals1
        decimals_out = decimals0 # Use fetched decimals0

        # Check if we have a position to sell
        if !haskey(strategy.active_positions, pair)
            @warn "No active position found for $pair to sell."
            return nothing
        end

        position = strategy.active_positions[pair]
        # Check if position status allows selling (e.g., it's not just 'prepared')
        if get(position, "status", "unknown") == "prepared"
             @warn "Cannot sell position for pair $pair as it is only prepared and not confirmed."
             return nothing
         end

        amount_to_sell = position["size"] # Amount of Token1 we hold
        amount_to_sell_wei = BigInt(floor(amount_to_sell * BigInt(10)^decimals_in))

        if amount_to_sell_wei <= 0
             @warn "Calculated amount to sell for position $pair is zero or negative."
             return nothing
         end

        trade_params = Dict(
            :token_in => token_in_addr,
            :token_out => token_out_addr,
            :amount_in_wei => amount_to_sell_wei,
            :slippage => strategy.risk_params["slippage_tolerance"],
            :wallet_address => strategy.wallet_address
        )

        bridge_result = Bridge.execute_trade(dex, chain, trade_params)

        if !bridge_result.success || !haskey(bridge_result.data, "status")
            @warn "Failed to prepare sell trade via Bridge: $(get(bridge_result.data, "message", bridge_result.error))"
            return nothing
        end

        # Check if unsigned transaction is ready (requires signing)
        if bridge_result.data["status"] == "unsigned_ready"
            @info "Sell transaction prepared by Bridge. Requires signing." unsigned_tx=bridge_result.data["unsigned_transaction"]
             # === TODO: Trigger signing flow ===

             # For now, calculate PnL based on estimates and record
             trade_data = bridge_result.data["details"]
             estimated_amount_out_wei = parse(BigInt, trade_data["estimated_amount_out_wei"])
             amount_received_float = Float64(estimated_amount_out_wei / BigInt(10)^decimals_out) # Use fetched decimals_out

             entry_price_val = position["entry_price"]
             size_val = position["size"]
             exit_price_val = size_val > 0 ? amount_received_float / size_val : 0.0
             time_val = try DateTime(trade_data["timestamp"]) catch; now() end

             entry_value = size_val * entry_price_val
             pnl = amount_received_float - entry_value
             ret = entry_price_val ≈ 0 ? 0.0 : (exit_price_val - entry_price_val) / entry_price_val

             trade_record = Dict(
                 "pair" => pair,
                 "chain" => chain,
                 "dex" => dex,
                 "type" => "sell",
                 "entry_price" => entry_price_val,
                 "exit_price" => exit_price_val,
                 "size" => size_val,
                 "pnl" => pnl,
                 "return" => ret,
                 "entry_time" => position["entry_time"],
                 "exit_time" => time_val,
                 "trade_id" => "prep_"*string(rand(UInt32)), # Mark as prepared
                 "tx_hash" => bridge_result.data["mock_tx_hash"], # Use mock hash
                 "status" => "prepared"
             )
             push!(strategy.trading_history, trade_record)

            # DO NOT delete the active position yet, only when TX is confirmed
            # delete!(strategy.active_positions, pair)
            @warn "Sell trade PREPARED. Active position NOT removed until TX is confirmed." pair=pair

            @info "Sell trade PREPARED (needs signing):" trade_record=trade_record
            return bridge_result.data # Return preparation data
        else
            @warn "Unexpected status from Bridge.execute_trade: $(bridge_result.data["status"])"
            return nothing
        end
    end

    return nothing # Should not reach here if signal type is valid
end

"""
    get_portfolio_value(strategy::TradingStrategy)

Get the current portfolio value including all active positions.
"""
function get_portfolio_value(strategy::TradingStrategy)
    # Get wallet balance using the new Bridge function
    balance_result = Bridge.get_wallet_balance(strategy.swarm.chain, strategy.wallet_address)
    if !balance_result.success
        @warn "Failed to get wallet balance for portfolio value: $(balance_result.error)"
        # Return a default structure indicating failure but allowing partial calculation
        return Dict(
             "liquid_balance" => 0.0,
             "position_value" => "Error",
             "total_value" => "Error",
             "positions" => length(strategy.active_positions),
             "error" => balance_result.error
         )
    end

    # Calculate current portfolio value including open positions
    liquid_balance = balance_result.data["balance"]
    position_value = 0.0
    position_error = false

    # Calculate value of all active positions
    for (pair, position) in strategy.active_positions
        # Get current price
        # Note: This still fetches market data directly, might need optimization
        market_data = MarketData.fetch_market_data(
            strategy.swarm.chain,
            strategy.swarm.dex,
            pair,
            limit=1 # Fetch only the latest price
        )

        if !isnothing(market_data) && !isempty(market_data)
            try
                 position_size = position["size"]
                 current_price = first(market_data).price # Get price from the first (latest) point
                 position_value += position_size * current_price
             catch conv_err
                 @error "Error converting position data for $pair: $conv_err" position=position
                 position_error = true
             end
        else
            @warn "Could not fetch current market price for $pair to calculate position value."
             position_error = true # Mark error if price unavailable
        end
    end

    total_value_str = position_error ? "Error (partial)" : (liquid_balance + position_value)
    position_value_str = position_error ? "Error (partial)" : position_value

    return Dict(
        "liquid_balance" => liquid_balance,
        "position_value" => position_value_str,
        "total_value" => total_value_str,
        "positions" => length(strategy.active_positions)
    )
end

"""
    get_trading_history(strategy::TradingStrategy; days::Int=30)

Get the trading history for a strategy.
"""
function get_trading_history(strategy::TradingStrategy; days::Int=30)
    if isempty(strategy.trading_history)
        return []
    end
    
    # Filter by date
    cutoff_date = Dates.now() - Dates.Day(days)
    
    recent_trades = filter(trade -> 
        if haskey(trade, "exit_time")
            trade["exit_time"] > cutoff_date
        else
            trade["time"] > cutoff_date
        end,
        strategy.trading_history
    )
    
    # Calculate performance metrics
    win_trades = 0
    loss_trades = 0
    total_pnl = 0.0
    
    for trade in recent_trades
        if haskey(trade, "pnl")
            total_pnl += trade["pnl"]
            if trade["pnl"] > 0
                win_trades += 1
            else
                loss_trades += 1
            end
        end
    end
    
    total_trades = win_trades + loss_trades
    win_rate = total_trades > 0 ? win_trades / total_trades : 0.0
    
    return Dict(
        "trades" => recent_trades,
        "total_trades" => total_trades,
        "win_rate" => win_rate,
        "total_pnl" => total_pnl
    )
end

end # module 