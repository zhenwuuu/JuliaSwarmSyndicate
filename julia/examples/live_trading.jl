using JuliaOS
using JuliaOS.Bridge
using JuliaOS.MarketData
using JuliaOS.SwarmManager
using JuliaOS.SwarmManager.Algorithms
using Dates
using JSON

# Configuration
const CONFIG_PATH = joinpath(@__DIR__, "../config/trading_config.json")
const LOG_PATH = joinpath(@__DIR__, "../logs/trading_$(Dates.format(now(), "yyyy-mm-dd")).log")

# Initialize logging
function init_logging()
    # Ensure directory exists
    log_dir = dirname(LOG_PATH)
    if !isdir(log_dir)
        mkpath(log_dir)
    end
    
    # Set up logging format
    log_io = open(LOG_PATH, "a+")
    
    # Return logging function
    return (msg, level="INFO") -> begin
        timestamp = Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
        log_line = "$timestamp [$level] $msg"
        println(log_io, log_line)
        flush(log_io)
        
        # Print to console too if it's an important message
        if level == "ERROR" || level == "WARN"
            println(log_line)
        end
    end
end

# Load configuration
function load_config()
    if !isfile(CONFIG_PATH)
        # Create default config if none exists
        default_config = Dict(
            "chain" => "ethereum",
            "dex" => "uniswap-v3",
            "trading_pairs" => ["ETH/USDC", "WBTC/USDC"],
            "wallet_address" => "0x...",  # Replace with your wallet address
            "max_position_size" => 0.05,  # 5% of portfolio per position
            "trading_algorithm" => "pso", # Particle Swarm Optimization
            "algorithm_params" => Dict(
                "inertia_weight" => 0.7,
                "cognitive_coef" => 1.5,
                "social_coef" => 1.5
            ),
            "bridge_config" => Dict(
                "endpoint" => "http://localhost:3000/julia-bridge",
                "ws_endpoint" => "ws://localhost:3000/julia-bridge-ws"
            ),
            "market_data" => Dict(
                "historical_days" => 30,
                "interval" => "1h"
            )
        )
        
        # Write default config
        open(CONFIG_PATH, "w") do io
            JSON.print(io, default_config, 4)
        end
        
        println("Created default config at: $CONFIG_PATH")
        println("Please edit this file with your settings before running again.")
        exit(0)
    end
    
    # Load config
    return JSON.parsefile(CONFIG_PATH)
end

# Setup trading system
function setup_trading_system(config, log)
    log("Setting up trading system")
    
    # Start bridge connection to JS/TS
    if !Bridge.start_bridge()
        log("Failed to connect to bridge", "ERROR")
        error("Bridge connection failed")
    end
    
    log("Bridge connected successfully")
    
    # Define our swarm configuration
    swarm_config = SwarmConfig(
        "trading_swarm",
        100,  # swarm size (100 particles)
        config["trading_algorithm"],
        config["trading_pairs"],
        config["algorithm_params"]
    )
    
    # Create the swarm
    swarm = create_swarm(swarm_config, config["chain"], config["dex"])
    log("Created swarm: $(swarm_config.name)")
    
    # Get historical market data for training
    all_historical_data = Vector{MarketData.MarketDataPoint}()
    
    for pair in config["trading_pairs"]
        log("Fetching historical data for: $pair")
        
        historical_data = fetch_historical(
            config["chain"],
            config["dex"],
            pair;
            days=config["market_data"]["historical_days"],
            interval=config["market_data"]["interval"]
        )
        
        if isempty(historical_data)
            log("No historical data for $pair", "WARN")
            continue
        end
        
        log("Fetched $(length(historical_data)) data points for $pair")
        append!(all_historical_data, historical_data)
    end
    
    # Start the swarm with historical data
    log("Starting swarm with $(length(all_historical_data)) historical data points")
    start_swarm!(swarm, all_historical_data)
    
    # Create trading strategy
    log("Creating trading strategy")
    strategy = create_trading_strategy(
        swarm, 
        config["wallet_address"], 
        max_position_size=config["max_position_size"]
    )
    
    # Backtest the strategy
    log("Backtesting strategy with historical data")
    backtest_results = backtest_strategy(strategy, all_historical_data)
    
    log("Backtest results:")
    log("  Portfolio Value: \$$(round(backtest_results["portfolio_value"], digits=2))")
    log("  Total Return: $(round(backtest_results["total_return"] * 100, digits=2))%")
    log("  Win Rate: $(round(backtest_results["win_rate"] * 100, digits=2))%")
    log("  Max Drawdown: $(round(backtest_results["max_drawdown"] * 100, digits=2))%")
    log("  Sharpe Ratio: $(round(backtest_results["sharpe_ratio"], digits=2))")
    log("  Trade Count: $(backtest_results["trade_count"])")
    
    return strategy
end

# Monitor market data and execute trades
function run_trading_system(strategy, config, log)
    # Activate the strategy
    strategy.is_active = true
    log("Trading strategy activated")
    
    # Setup market data subscriptions
    for pair in config["trading_pairs"]
        log("Setting up price subscription for: $pair")
        
        # Define callback function to handle price updates
        function price_callback(market_data)
            # Generate trading signals
            signals = generate_trading_signals(strategy.swarm, market_data)
            
            if !isempty(signals)
                for signal in signals
                    signal_type = signal["type"]
                    price = signal["price"]
                    
                    # Add pair information to signal
                    signal["indicators"]["pair"] = market_data.pair
                    
                    log("Generated $(uppercase(signal_type)) signal for $(market_data.pair) at \$$(round(price, digits=2))")
                    
                    # Execute the trade
                    result = execute_trade!(strategy, signal)
                    
                    if result !== nothing && haskey(result, "success") && result["success"]
                        trade_data = result["data"]
                        log("Executed $(uppercase(signal_type)) trade for $(market_data.pair):")
                        log("  Price: \$$(trade_data["execution_price"])")
                        log("  Amount: $(trade_data["size"])")
                        log("  Value: \$$(trade_data["value"])")
                        log("  TX Hash: $(trade_data["tx_hash"])")
                    else
                        log("Failed to execute $(uppercase(signal_type)) trade for $(market_data.pair)", "WARN")
                    end
                end
            end
        end
        
        # Subscribe to price updates
        subscribe_to_price_updates(
            config["chain"],
            config["dex"],
            pair,
            price_callback
        )
    end
    
    # Main trading loop
    try
        log("Trading system running. Press Ctrl+C to stop.")
        
        # Keep the script running
        while true
            # Update strategy with new market data every hour
            sleep(3600)  # 1 hour
            
            # Fetch latest market data for all pairs
            all_market_data = Vector{MarketData.MarketDataPoint}()
            
            for pair in config["trading_pairs"]
                market_data = fetch_market_data(
                    config["chain"],
                    config["dex"],
                    pair
                )
                
                if market_data !== nothing
                    push!(all_market_data, market_data)
                end
            end
            
            # Update the swarm
            if !isempty(all_market_data)
                log("Updating swarm with $(length(all_market_data)) new data points")
                update_swarm!(strategy.swarm, all_market_data)
                
                # Get portfolio value
                portfolio = get_portfolio_value(strategy)
                if portfolio !== nothing
                    log("Portfolio Update:")
                    log("  Total Value: \$$(round(portfolio["total_value"], digits=2))")
                    log("  Liquid Balance: \$$(round(portfolio["liquid_balance"], digits=2))")
                    log("  Position Value: \$$(round(portfolio["position_value"], digits=2))")
                    log("  Open Positions: $(portfolio["positions"])")
                end
                
                # Get trading history
                history = get_trading_history(strategy, days=1)  # Last 24 hours
                if !isempty(history["trades"])
                    log("Last 24 Hours Trading Summary:")
                    log("  Trades: $(history["total_trades"])")
                    log("  Win Rate: $(round(history["win_rate"] * 100, digits=2))%")
                    log("  Total PnL: \$$(round(history["total_pnl"], digits=2))")
                end
            end
        end
    catch e
        if isa(e, InterruptException)
            log("Trading system stopped by user", "INFO")
        else
            log("Error in trading system: $e", "ERROR")
        end
    finally
        # Deactivate strategy
        strategy.is_active = false
        log("Trading strategy deactivated")
        
        # Stop bridge connection
        Bridge.stop_bridge()
        log("Bridge connection closed")
    end
end

# Main entry point
function main()
    # Initialize
    log = init_logging()
    log("Starting JuliaOS DeFi Trading System")
    
    # Load configuration
    config = load_config()
    log("Configuration loaded from: $CONFIG_PATH")
    
    # Setup trading system
    strategy = setup_trading_system(config, log)
    
    # Run trading system
    run_trading_system(strategy, config, log)
    
    log("JuliaOS DeFi Trading System Shutdown")
end

# Run the main function
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end 