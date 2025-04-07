module SwarmManager

using JSON
using Dates
using Statistics
using Random
using LinearAlgebra
using ..MarketData
using ..Bridge
using ..Algorithms

export SwarmConfig, create_swarm, start_swarm!, update_swarm!, calculate_fitness
export TradingStrategy, execute_trade!, get_portfolio_value, get_trading_history
export create_trading_strategy, backtest_strategy, generate_trading_signals

struct SwarmConfig
    name::String
    size::Int
    algorithm::String
    trading_pairs::Vector{String}
    parameters::Dict{String, Any}
end

mutable struct Swarm
    config::SwarmConfig
    algorithm::AbstractSwarmAlgorithm
    market_data::Vector{MarketData.MarketDataPoint}
    performance_metrics::Dict{String, Float64}
    chain::String
    dex::String
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

function create_swarm(config::SwarmConfig, chain::String="ethereum", dex::String="uniswap-v3")
    # Create an algorithm instance based on config
    algorithm_params = Dict{String, Any}(
        string(k) => v for (k, v) in config.parameters
    )
    
    # Create the algorithm using our factory function
    algorithm = create_algorithm(config.algorithm, algorithm_params)
    
    # Create and return a new swarm
    return Swarm(
        config,
        algorithm,
        Vector{MarketData.MarketDataPoint}(),
        Dict{String, Float64}(),
        chain,
        dex
    )
end

function start_swarm!(swarm::Swarm, initial_market_data::Vector{MarketData.MarketDataPoint})
    # Store market data
    swarm.market_data = initial_market_data
    
    # Define trading dimensions (parameters to optimize)
    # e.g., [entry_threshold, exit_threshold, stop_loss, take_profit]
    dimension = 4
    
    # Define bounds for each dimension
    bounds = [
        (0.0, 1.0),    # entry_threshold: 0-1 normalized value
        (0.0, 1.0),    # exit_threshold: 0-1 normalized value
        (0.01, 0.2),   # stop_loss: 1-20%
        (0.01, 0.5)    # take_profit: 1-50%
    ]
    
    # Initialize the algorithm with appropriate dimensions
    initialize!(swarm.algorithm, swarm.config.size, dimension, bounds)
    
    # Define fitness function (trading performance)
    fitness_function = position -> calculate_fitness(position, swarm)
    
    # Evaluate initial fitness
    evaluate_fitness!(swarm.algorithm, fitness_function)
    select_leaders!(swarm.algorithm)
    
    # Update performance metrics
    best_position = get_best_position(swarm.algorithm)
    best_fitness = get_best_fitness(swarm.algorithm)
    
    swarm.performance_metrics["best_fitness"] = best_fitness
    swarm.performance_metrics["entry_threshold"] = best_position[1]
    swarm.performance_metrics["exit_threshold"] = best_position[2]
    swarm.performance_metrics["stop_loss"] = best_position[3]
    swarm.performance_metrics["take_profit"] = best_position[4]
    
    return swarm
end

function update_swarm!(swarm::Swarm, new_market_data::Vector{MarketData.MarketDataPoint})
    # Update market data
    append!(swarm.market_data, new_market_data)
    
    # Define fitness function (trading performance)
    fitness_function = position -> calculate_fitness(position, swarm)
    
    # Update algorithm positions
    update_positions!(swarm.algorithm, fitness_function)
    
    # Update performance metrics
    best_position = get_best_position(swarm.algorithm)
    best_fitness = get_best_fitness(swarm.algorithm)
    
    swarm.performance_metrics["best_fitness"] = best_fitness
    swarm.performance_metrics["entry_threshold"] = best_position[1]
    swarm.performance_metrics["exit_threshold"] = best_position[2]
    swarm.performance_metrics["stop_loss"] = best_position[3]
    swarm.performance_metrics["take_profit"] = best_position[4]
    
    # Get convergence data for visualization
    convergence_data = get_convergence_data(swarm.algorithm)
    swarm.performance_metrics["convergence"] = convergence_data[end]
    
    return swarm
end

function calculate_fitness(position::Vector{Float64}, swarm::Swarm)
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
    
    # Historical backtesting over market data
    for (i, data_point) in enumerate(swarm.market_data)
        if i < 2
            continue  # Skip first point as we need previous data
        end
        
        prev_data = swarm.market_data[i-1]
        
        # Calculate indicators (simplified version)
        rsi = get(data_point.indicators, "rsi", 50.0)
        bb_upper = get(data_point.indicators, "bb_upper", data_point.price * 1.05)
        bb_lower = get(data_point.indicators, "bb_lower", data_point.price * 0.95)
        bb_position = (data_point.price - bb_lower) / (bb_upper - bb_lower)
        
        # Trading logic
        if !in_position
            # Entry signal: RSI below threshold and price near lower BB
            if rsi < (entry_threshold * 100) && bb_position < 0.2
                in_position = true
                entry_price = data_point.price
                trade_count += 1
            end
        else
            # Calculate current return
            current_return = (data_point.price - entry_price) / entry_price
            
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
                in_position = false
                portfolio_value *= (1.0 + current_return)
                
                if current_return > 0
                    winning_trades += 1
                end
                
                # Update peak value and calculate drawdown
                if portfolio_value > peak_value
                    peak_value = portfolio_value
                else
                    drawdown = (peak_value - portfolio_value) / peak_value
                    if drawdown > max_drawdown
                        max_drawdown = drawdown
                    end
                end
            end
        end
    end
    
    # Calculate performance metrics
    win_rate = trade_count > 0 ? winning_trades / trade_count : 0.0
    total_return = (portfolio_value - 10000.0) / 10000.0
    
    # Calculate Sharpe ratio (simplified)
    sharpe_ratio = 0.0
    if max_drawdown > 0
        sharpe_ratio = total_return / max_drawdown
    end
    
    # Combine metrics into a single fitness value (to minimize)
    # We negate positive metrics since we want to minimize the fitness function
    fitness = -total_return * 0.5 - win_rate * 0.3 - sharpe_ratio * 0.2
    
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
    
    if !Bridge.CONNECTION.is_connected
        @warn "Bridge not connected. Attempting to connect..."
        if !Bridge.start_bridge()
            error("Failed to connect to bridge for trade execution")
        end
    end
    
    # Extract signal details
    signal_type = signal["type"]
    price = signal["price"]
    pair = signal["indicators"]["pair"]
    chain = strategy.swarm.chain
    dex = strategy.swarm.dex
    
    # Check if we're buying or selling
    if signal_type == "buy"
        # Check if we already have a position
        if haskey(strategy.active_positions, pair)
            @warn "Already have a position for $pair"
            return nothing
        end
        
        # Check if we have too many open positions
        if length(strategy.active_positions) >= strategy.risk_params["max_open_positions"]
            @warn "Maximum number of open positions reached"
            return nothing
        end
        
        # Get wallet balance
        wallet_response = Bridge.get_wallet_balance(chain, strategy.wallet_address)
        if wallet_response === nothing || !haskey(wallet_response, "success") || !wallet_response["success"]
            @warn "Failed to get wallet balance"
            return nothing
        end
        
        # Calculate position size
        available_balance = parse(Float64, wallet_response["data"]["balance"])
        position_value = available_balance * strategy.max_position_size
        
        # Execute buy trade
        trade_params = Dict{String, Any}(
            "pair" => pair,
            "side" => "buy",
            "amount" => position_value,
            "price" => price,
            "wallet" => strategy.wallet_address,
            "slippage" => strategy.risk_params["slippage_tolerance"]
        )
        
        trade_response = Bridge.execute_trade(dex, chain, trade_params)
        
        if trade_response === nothing || !haskey(trade_response, "success") || !trade_response["success"]
            @warn "Failed to execute buy trade"
            return nothing
        end
        
        # Record the position
        trade_data = trade_response["data"]
        strategy.active_positions[pair] = Dict(
            "entry_price" => parse(Float64, trade_data["execution_price"]),
            "size" => parse(Float64, trade_data["size"]),
            "entry_time" => DateTime(trade_data["timestamp"], "yyyy-mm-ddTHH:MM:SS.sssZ"),
            "trade_id" => trade_data["trade_id"],
            "value" => parse(Float64, trade_data["value"])
        )
        
        # Record trade in history
        trade_record = Dict(
            "pair" => pair,
            "chain" => chain,
            "dex" => dex,
            "type" => "buy",
            "price" => parse(Float64, trade_data["execution_price"]),
            "size" => parse(Float64, trade_data["size"]),
            "value" => parse(Float64, trade_data["value"]),
            "time" => DateTime(trade_data["timestamp"], "yyyy-mm-ddTHH:MM:SS.sssZ"),
            "trade_id" => trade_data["trade_id"],
            "tx_hash" => trade_data["tx_hash"]
        )
        
        push!(strategy.trading_history, trade_record)
        
        return trade_response
        
    elseif signal_type == "sell"
        # Check if we have a position to sell
        if !haskey(strategy.active_positions, pair)
            @warn "No position for $pair to sell"
            return nothing
        end
        
        position = strategy.active_positions[pair]
        
        # Execute sell trade
        trade_params = Dict{String, Any}(
            "pair" => pair,
            "side" => "sell",
            "size" => position["size"],
            "price" => price,
            "wallet" => strategy.wallet_address,
            "slippage" => strategy.risk_params["slippage_tolerance"]
        )
        
        trade_response = Bridge.execute_trade(dex, chain, trade_params)
        
        if trade_response === nothing || !haskey(trade_response, "success") || !trade_response["success"]
            @warn "Failed to execute sell trade"
            return nothing
        end
        
        # Calculate PnL
        trade_data = trade_response["data"]
        exit_price = parse(Float64, trade_data["execution_price"])
        entry_price = position["entry_price"]
        size = position["size"]
        
        entry_value = size * entry_price
        exit_value = size * exit_price
        pnl = exit_value - entry_value
        ret = (exit_price - entry_price) / entry_price
        
        # Record trade in history
        trade_record = Dict(
            "pair" => pair,
            "chain" => chain,
            "dex" => dex,
            "type" => "sell",
            "entry_price" => entry_price,
            "exit_price" => exit_price,
            "size" => size,
            "pnl" => pnl,
            "return" => ret,
            "entry_time" => position["entry_time"],
            "exit_time" => DateTime(trade_data["timestamp"], "yyyy-mm-ddTHH:MM:SS.sssZ"),
            "trade_id" => trade_data["trade_id"],
            "tx_hash" => trade_data["tx_hash"]
        )
        
        push!(strategy.trading_history, trade_record)
        
        # Remove position
        delete!(strategy.active_positions, pair)
        
        return trade_response
    else
        @warn "Unknown signal type: $signal_type"
        return nothing
    end
end

"""
    get_portfolio_value(strategy::TradingStrategy)

Get the current portfolio value including all active positions.
"""
function get_portfolio_value(strategy::TradingStrategy)
    if !Bridge.CONNECTION.is_connected
        @warn "Bridge not connected. Attempting to connect..."
        if !Bridge.start_bridge()
            error("Failed to connect to bridge for portfolio value")
        end
    end
    
    # Get wallet balance
    wallet_response = Bridge.get_wallet_balance(strategy.swarm.chain, strategy.wallet_address)
    if wallet_response === nothing || !haskey(wallet_response, "success") || !wallet_response["success"]
        @warn "Failed to get wallet balance"
        return nothing
    end
    
    # Calculate current portfolio value including open positions
    liquid_balance = parse(Float64, wallet_response["data"]["balance"])
    position_value = 0.0
    
    # Calculate value of all active positions
    for (pair, position) in strategy.active_positions
        # Get current price
        market_data = MarketData.fetch_market_data(
            strategy.swarm.chain, 
            strategy.swarm.dex, 
            pair
        )
        
        if market_data !== nothing
            position_size = position["size"]
            current_price = market_data.price
            position_value += position_size * current_price
        end
    end
    
    total_value = liquid_balance + position_value
    
    return Dict(
        "liquid_balance" => liquid_balance,
        "position_value" => position_value,
        "total_value" => total_value,
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