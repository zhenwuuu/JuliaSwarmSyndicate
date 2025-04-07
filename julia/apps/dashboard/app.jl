module DeFiDashboard

using GenieFramework
using JuliaOS
using JuliaOS.SwarmManager
using JuliaOS.MarketData
using JuliaOS.Bridge
using Dates
using Plots
using PlotlyJS
using JSON
using DataFrames
using Printf
using Statistics

# Export main entry points
export run_dashboard, start_dashboard, stop_dashboard

# Initialize Genie app
@genietools

# Main app model
@app begin
    # State variables
    @in chain = "ethereum"
    @in dex = "uniswap-v3"
    @in pair = "ETH/USDC"
    @in algorithm = "pso"
    @in swarm_size = 100
    @in historical_days = 30
    @in max_position_size = 0.1
    @in wallet_address = ""
    @in api_key = ""
    
    # Trading parameters
    @in backtest_only = true
    @in is_live_trading = false
    
    # Algorithm parameters
    @in inertia_weight = 0.7
    @in cognitive_coef = 1.5
    @in social_coef = 1.5
    
    # Outputs
    @out supported_chains = ["ethereum", "solana", "avalanche", "polygon"]
    @out supported_dexes = ["uniswap-v3", "sushiswap", "raydium", "traderjoe"]
    @out supported_pairs = ["ETH/USDC", "WBTC/USDC"]
    @out supported_algorithms = ["pso", "gwo", "woa", "genetic", "aco"]
    @out chart_data = nothing
    @out performance_metrics = Dict{String, Any}()
    @out is_running = false
    @out status_message = "Ready"
    @out trade_history = []
    @out portfolio_value = Dict{String, Any}()
    
    # Actions
    @onchange chain begin
        # Update supported DEXes based on selected chain
        if chain == "ethereum"
            supported_dexes = ["uniswap-v3", "sushiswap", "balancer", "curve"]
        elseif chain == "solana"
            supported_dexes = ["raydium", "orca", "mango"]
        elseif chain == "avalanche"
            supported_dexes = ["traderjoe", "pangolin"]
        elseif chain == "polygon"
            supported_dexes = ["quickswap", "sushiswap", "balancer"]
        end
        status_message = "Selected chain: $chain"
    end
    
    @onchange dex begin
        status_message = "Loading pairs for $dex..."
        # Load supported pairs for selected DEX
        if !isempty(api_key) && !backtest_only
            try
                if !Bridge.CONNECTION.is_connected
                    Bridge.start_bridge()
                end
                pairs_response = MarketData.get_supported_pairs(chain, dex)
                if !isempty(pairs_response)
                    # Update pairs dropdown
                    supported_pairs = pairs_response
                    pair = supported_pairs[1]
                    status_message = "Loaded $(length(supported_pairs)) pairs for $dex"
                end
            catch e
                status_message = "Error loading pairs: $e"
                supported_pairs = ["ETH/USDC", "WBTC/USDC"]
            end
        else
            # Default pairs for demo
            supported_pairs = ["ETH/USDC", "WBTC/USDC", "SOL/USDC", "AVAX/USDC"]
            status_message = "Using demo pairs. Enter API key for real data."
        end
    end
    
    @onchange api_key begin
        if !isempty(api_key)
            status_message = "API key set. Ready to connect."
        end
    end
    
    @onbutton run_backtest begin
        is_running = true
        status_message = "Running backtest..."
        
        # Run in background to keep UI responsive
        @async begin
            try
                # Create swarm configuration
                algo_params = Dict{String, Any}(
                    "inertia_weight" => inertia_weight,
                    "cognitive_coef" => cognitive_coef,
                    "social_coef" => social_coef
                )
                
                swarm_config = SwarmConfig(
                    "backtest_swarm",
                    swarm_size,
                    algorithm,
                    [pair],
                    algo_params
                )
                
                # Initialize bridge if needed and API key is provided
                if !isempty(api_key) && !Bridge.CONNECTION.is_connected && !backtest_only
                    Bridge.start_bridge()
                    status_message = "Connected to bridge"
                end
                
                # Get historical data
                status_message = "Fetching historical data..."
                
                if backtest_only || isempty(api_key)
                    # Generate synthetic data for demo
                    status_message = "Generating synthetic data for demo..."
                    historical_data = generate_synthetic_data(pair, historical_days)
                else
                    # Get real data from the bridge
                    historical_data = MarketData.fetch_historical(
                        chain, dex, pair;
                        days=historical_days, interval="1h"
                    )
                end
                
                status_message = "Creating swarm with $(length(historical_data)) data points..."
                
                # Create and initialize swarm
                swarm = SwarmManager.create_swarm(swarm_config, chain, dex)
                SwarmManager.start_swarm!(swarm, historical_data)
                
                status_message = "Swarm initialized. Running backtest..."
                
                # Create strategy for backtesting
                strategy = SwarmManager.create_trading_strategy(
                    swarm, 
                    wallet_address, 
                    max_position_size=max_position_size
                )
                
                # Run backtest
                backtest_results = SwarmManager.backtest_strategy(
                    strategy, historical_data
                )
                
                status_message = "Backtest complete. Generating results..."
                
                # Extract data for charting
                prices = [point.price for point in historical_data]
                timestamps = [point.timestamp for point in historical_data]
                
                # Extract trades for overlaying on chart
                buy_points_x = Int[]
                buy_points_y = Float64[]
                sell_points_x = Int[]
                sell_points_y = Float64[]
                
                for (i, trade) in enumerate(backtest_results["trading_history"])
                    if trade["type"] == "buy"
                        # Find the index of the timestamp
                        idx = findfirst(t -> t >= trade["time"], timestamps)
                        if idx !== nothing
                            push!(buy_points_x, idx)
                            push!(buy_points_y, trade["price"])
                        end
                    elseif trade["type"] == "sell" && haskey(trade, "exit_time")
                        idx = findfirst(t -> t >= trade["exit_time"], timestamps)
                        if idx !== nothing
                            push!(sell_points_x, idx)
                            push!(sell_points_y, trade["exit_price"])
                        end
                    end
                end
                
                # Generate chart using PlotlyJS
                price_trace = scatter(
                    x=1:length(prices), 
                    y=prices,
                    mode="lines",
                    name="Price"
                )
                
                buy_trace = scatter(
                    x=buy_points_x,
                    y=buy_points_y,
                    mode="markers",
                    marker=attr(color="green", size=10, symbol="circle"),
                    name="Buy"
                )
                
                sell_trace = scatter(
                    x=sell_points_x,
                    y=sell_points_y,
                    mode="markers",
                    marker=attr(color="red", size=10, symbol="circle"),
                    name="Sell"
                )
                
                layout = Layout(
                    title="$pair Trading Backtest",
                    xaxis=attr(title="Time"),
                    yaxis=attr(title="Price"),
                    legend=attr(orientation="h")
                )
                
                chart_data = PlotlyJS.Plot([price_trace, buy_trace, sell_trace], layout)
                
                # Format trading history for display
                formatted_history = []
                for trade in backtest_results["trading_history"]
                    if trade["type"] == "buy"
                        push!(formatted_history, Dict(
                            "type" => "BUY",
                            "pair" => trade["pair"],
                            "price" => round(trade["price"], digits=2),
                            "size" => round(trade["size"], digits=4),
                            "value" => round(trade["value"], digits=2),
                            "time" => Dates.format(trade["time"], "yyyy-mm-dd HH:MM")
                        ))
                    elseif trade["type"] == "sell"
                        push!(formatted_history, Dict(
                            "type" => "SELL",
                            "pair" => trade["pair"],
                            "entry_price" => round(trade["entry_price"], digits=2),
                            "exit_price" => round(trade["exit_price"], digits=2),
                            "size" => round(trade["size"], digits=4),
                            "pnl" => round(trade["pnl"], digits=2),
                            "return" => round(trade["return"] * 100, digits=2),
                            "time" => Dates.format(trade["exit_time"], "yyyy-mm-dd HH:MM")
                        ))
                    end
                end
                
                # Update UI
                performance_metrics = Dict(
                    "Portfolio Value" => "\$$(round(backtest_results["portfolio_value"], digits=2))",
                    "Total Return" => "$(round(backtest_results["total_return"] * 100, digits=2))%",
                    "Win Rate" => "$(round(backtest_results["win_rate"] * 100, digits=2))%",
                    "Max Drawdown" => "$(round(backtest_results["max_drawdown"] * 100, digits=2))%",
                    "Sharpe Ratio" => "$(round(backtest_results["sharpe_ratio"], digits=2))",
                    "Trade Count" => "$(backtest_results["trade_count"])"
                )
                
                trade_history = formatted_history
                
                # Show algorithm's best parameters
                best_position = get_best_position(swarm.algorithm)
                status_message = "Backtest complete. Optimized parameters: entry=$(round(best_position[1], digits=2)), exit=$(round(best_position[2], digits=2)), stop_loss=$(round(best_position[3]*100, digits=2))%, take_profit=$(round(best_position[4]*100, digits=2))%"
                
                # Start live trading if requested
                if is_live_trading && !isempty(api_key) && !isempty(wallet_address) && !backtest_only
                    start_live_trading(strategy)
                end
                
            catch e
                status_message = "Error in backtest: $e"
            finally
                is_running = false
            end
        end
    end
    
    @onbutton toggle_live_trading begin
        if is_live_trading
            is_live_trading = false
            status_message = "Live trading stopped"
        else
            if isempty(wallet_address)
                status_message = "Please enter a wallet address for live trading"
            elseif isempty(api_key)
                status_message = "Please enter an API key for live trading"
            else
                is_live_trading = true
                backtest_only = false
                status_message = "Live trading enabled. Run backtest first to initialize the strategy."
            end
        end
    end
end

# Helper function to generate synthetic data for demo
function generate_synthetic_data(pair::String, days::Int)
    market_data = Vector{MarketData.MarketDataPoint}()
    
    # Base price and volatility based on the pair
    base_price = if occursin("ETH", pair)
        3000.0
    elseif occursin("BTC", pair) || occursin("WBTC", pair)
        50000.0
    elseif occursin("SOL", pair)
        100.0
    elseif occursin("AVAX", pair)
        30.0
    else
        100.0
    end
    
    volatility = 0.02  # 2% daily volatility
    
    # Generate price data with a slight upward trend
    price = base_price
    for day in 1:days
        for hour in 1:24
            # Add some random walk with a slight bias
            price *= (1.0 + randn() * volatility + 0.0002)
            
            # Volume varies too
            volume = base_price * 100 * (1.0 + rand() * 0.5)
            
            # Create timestamp
            timestamp = now() - Day(days - day) - Hour(24 - hour)
            
            # Calculate indicators
            indicators = Dict{String, Float64}()
            
            # Initialize with some basic indicators
            indicators["rsi"] = 30.0 + rand() * 40.0  # Random RSI between 30-70
            indicators["bb_upper"] = price * 1.05
            indicators["bb_middle"] = price
            indicators["bb_lower"] = price * 0.95
            
            # Create MarketDataPoint with chain/dex info
            chain_name, dex_name = split(pair, "/")[1] == "ETH" ? ("ethereum", "uniswap-v3") : 
                                   split(pair, "/")[1] == "SOL" ? ("solana", "raydium") :
                                   split(pair, "/")[1] == "AVAX" ? ("avalanche", "traderjoe") :
                                   ("ethereum", "uniswap-v3")
            
            data_point = MarketData.MarketDataPoint(
                timestamp,
                chain_name,
                dex_name,
                pair,
                price,
                volume,
                volume * price,   # Liquidity
                indicators
            )
            
            push!(market_data, data_point)
        end
    end
    
    # Calculate additional indicators
    if !isempty(market_data)
        prices = [point.price for point in market_data]
        volumes = [point.volume for point in market_data]
        
        for i in 50:length(market_data)
            window_start = max(1, i-50+1)
            window_prices = prices[window_start:i]
            window_volumes = volumes[window_start:i]
            
            indicators = MarketData.calculate_indicators(window_prices, window_volumes)
            
            for (key, value) in indicators
                market_data[i].indicators[key] = value
            end
        end
    end
    
    return market_data
end

# Function to start live trading
function start_live_trading(strategy)
    strategy.is_active = true
    
    @async begin
        try
            while strategy.is_active
                # Fetch latest market data
                market_data = MarketData.fetch_market_data(
                    strategy.swarm.chain,
                    strategy.swarm.dex,
                    strategy.swarm.config.trading_pairs[1]
                )
                
                if market_data !== nothing
                    # Generate trading signals
                    signals = SwarmManager.generate_trading_signals(strategy.swarm, market_data)
                    
                    for signal in signals
                        # Add pair information to signal
                        signal["indicators"]["pair"] = market_data.pair
                        
                        # Execute the trade
                        result = SwarmManager.execute_trade!(strategy, signal)
                        
                        if result !== nothing
                            @info "Executed trade: $(result["data"]["tx_hash"])"
                        end
                    end
                    
                    # Update portfolio value
                    portfolio = SwarmManager.get_portfolio_value(strategy)
                    if portfolio !== nothing
                        portfolio_value = portfolio
                    end
                end
                
                # Wait before next update
                sleep(60)  # Check every minute
            end
        catch e
            @error "Error in live trading: $e"
            strategy.is_active = false
        end
    end
end

# UI components (sidebar for inputs)
function sidebar()
    [
        h2("DeFi Trading Strategy")
        
        card(class="q-mb-md", [
            h5("Market Selection")
            select("Chain", :chain, :supported_chains)
            select("DEX", :dex, :supported_dexes)
            select("Trading Pair", :pair, :supported_pairs)
        ])
        
        card(class="q-mb-md", [
            h5("Strategy Parameters")
            select("Algorithm", :algorithm, :supported_algorithms)
            slider("Swarm Size", :swarm_size, 10:10:200, label=true)
            slider("Historical Days", :historical_days, 7:30, label=true)
            slider("Max Position Size", :max_position_size, 0.01:0.01:0.5, label=true)
        ])
        
        card(class="q-mb-md", [
            h5("Algorithm Parameters")
            slider("Inertia Weight", :inertia_weight, 0.1:0.1:1.0, label=true)
            slider("Cognitive Coefficient", :cognitive_coef, 0.5:0.1:2.5, label=true)
            slider("Social Coefficient", :social_coef, 0.5:0.1:2.5, label=true)
        ])
        
        card(class="q-mb-md", [
            h5("Live Trading Setup")
            textfield("API Key", :api_key; type="password")
            textfield("Wallet Address", :wallet_address)
            toggle("Demo Mode (no real trades)", :backtest_only)
            btn("Toggle Live Trading", @click(:toggle_live_trading), 
                color=:is_live_trading ? "negative" : "positive",
                :label=:is_live_trading ? "Stop Live Trading" : "Enable Live Trading",
                class="q-my-md full-width")
        ])
        
        btn("Run Backtest", @click(:run_backtest), color="primary", 
            loading=:is_running, loadingLabel="Running...",
            class="full-width")
    ]
end

# Results panel
function results_panel()
    [
        h3("Trading Strategy Dashboard")
        
        card(class="q-mb-md", [
            div(class="text-body1", :status_message)
        ])
        
        row([
            card(class="col-12", [
                plot(:chart_data, style="width:100%;height:400px;")
            ])
        ])
        
        row([
            card(class="col-6 q-pa-md", [
                h5("Performance Metrics")
                table(
                    :performance_metrics, 
                    pagination=false,
                    style="width:100%",
                    dense=true,
                    flat=true,
                    rows_per_page=10,
                    columns=[
                        Dict("name" => "metric", "label" => "Metric", "field" => "key", "align" => "left"),
                        Dict("name" => "value", "label" => "Value", "field" => "value", "align" => "right")
                    ]
                )
            ])
            
            card(class="col-6 q-pa-md", [
                h5("Trading History")
                table(
                    :trade_history, 
                    pagination=true, 
                    flat=true,
                    dense=true,
                    rows_per_page=5
                )
            ])
        ])
    ]
end

# Page layout
@page("/", 
    layout = [
        row([
            column(class="col-3", [sidebar()])
            column(class="col-9", [results_panel()])
        ])
    ],
    title = "JuliaOS DeFi Trading Strategy Dashboard"
)

# Main function to start the dashboard as a standalone app
function run_dashboard(; host="0.0.0.0", port=8000)
    Genie.AppServer.startup(host=host, port=port)
end

# Function to start the dashboard in the background
function start_dashboard(; host="0.0.0.0", port=8000)
    @async Genie.AppServer.startup(host=host, port=port)
    return "Dashboard started at http://$host:$port"
end

# Function to stop the dashboard
function stop_dashboard()
    Genie.AppServer.shutdown()
    return "Dashboard stopped"
end

# Dashboard state
mutable struct DashboardState
    active_agents::Vector{Dict{String, Any}}
    market_data::Dict{String, Any}
    bridge_status::Dict{String, Any}
    performance_metrics::Dict{String, Any}
    alerts::Vector{Dict{String, Any}}
end

const DASHBOARD_STATE = DashboardState(
    Vector{Dict{String, Any}}(),
    Dict{String, Any}(),
    Dict{String, Any}(),
    Dict{String, Any}(),
    Vector{Dict{String, Any}}()
)

# UI Components
function create_agent_card(agent::Dict{String, Any})
    status_color = agent["status"] == "Running" ? "success" :
                  agent["status"] == "Warning" ? "warning" : "error"
    
    return [
        card([
            h3(agent["name"]),
            p("Type: $(agent["type"])"),
            p("Strategy: $(agent["strategy"])"),
            p("Status: $(agent["status"])", class="text-$(status_color)"),
            p("Performance: $(agent["performance"])%"),
            p("Last Update: $(agent["last_update"])")
        ])
    ]
end

function create_market_data_card(pair::String, data::Dict{String, Any})
    return [
        card([
            h3(pair),
            p("Price: \$$(data["price"])"),
            p("24h Change: $(data["change_24h"])%"),
            p("Volume: \$$(data["volume"])"),
            p("Liquidity: \$$(data["liquidity"])")
        ])
    ]
end

function create_bridge_status_card(status::Dict{String, Any})
    return [
        card([
            h3("Bridge Status"),
            p("Status: $(status["status"])"),
            p("Active Chains: $(join(status["active_chains"], ", "))"),
            p("Pending Transactions: $(status["pending_txs"])"),
            p("Last Update: $(status["last_update"])")
        ])
    ]
end

function create_performance_metrics_card(metrics::Dict{String, Any})
    return [
        card([
            h3("Performance Metrics"),
            p("Total Return: $(metrics["total_return"])%"),
            p("Win Rate: $(metrics["win_rate"])%"),
            p("Max Drawdown: $(metrics["max_drawdown"])%"),
            p("Sharpe Ratio: $(metrics["sharpe_ratio"])")
        ])
    ]
end

function create_alerts_card(alerts::Vector{Dict{String, Any}})
    return [
        card([
            h3("Alerts"),
            ul(map(alert -> li(alert["message"]), alerts))
        ])
    ]
end

# Dashboard layout
function dashboard_layout()
    return [
        row([
            cell([
                h1("JuliaOS DeFi Dashboard"),
                p("Real-time monitoring and control")
            ])
        ]),
        row([
            cell([
                h2("Active Agents"),
                grid(map(agent -> create_agent_card(agent), DASHBOARD_STATE.active_agents)...)
            ])
        ]),
        row([
            cell([
                h2("Market Data"),
                grid(map(pair -> create_market_data_card(pair, DASHBOARD_STATE.market_data[pair]), 
                    collect(keys(DASHBOARD_STATE.market_data)))...)
            ])
        ]),
        row([
            cell([
                h2("Bridge Status"),
                grid(create_bridge_status_card(DASHBOARD_STATE.bridge_status)...)
            ])
        ]),
        row([
            cell([
                h2("Performance Metrics"),
                grid(create_performance_metrics_card(DASHBOARD_STATE.performance_metrics)...)
            ])
        ]),
        row([
            cell([
                h2("Alerts"),
                grid(create_alerts_card(DASHBOARD_STATE.alerts)...)
            ])
        ])
    ]
end

# Update functions
function update_agent_status()
    agents = get_active_agents()
    DASHBOARD_STATE.active_agents = map(agent -> Dict(
        "name" => agent.name,
        "type" => agent.type,
        "strategy" => agent.strategy,
        "status" => get_agent_status(agent),
        "performance" => agent.performance,
        "last_update" => agent.last_update
    ), agents)
end

function update_market_data()
    pairs = get_available_pairs()
    for pair in pairs
        data = get_market_data(pair)
        DASHBOARD_STATE.market_data[pair] = data
    end
end

function update_bridge_status()
    if !Bridge.CONNECTION.is_connected
        Bridge.start_bridge()
    end
    
    DASHBOARD_STATE.bridge_status = Dict(
        "status" => Bridge.CONNECTION.status,
        "active_chains" => Bridge.CONNECTION.active_chains,
        "pending_txs" => length(Bridge.CONNECTION.pending_transactions),
        "last_update" => Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
    )
end

function update_performance_metrics()
    metrics = calculate_performance_metrics()
    DASHBOARD_STATE.performance_metrics = metrics
end

function check_alerts()
    new_alerts = Vector{Dict{String, Any}}()
    
    # Check agent alerts
    for agent in DASHBOARD_STATE.active_agents
        if agent["status"] == "Warning"
            push!(new_alerts, Dict(
                "message" => "Agent $(agent["name"]) is in warning state",
                "level" => "warning"
            ))
        elseif agent["status"] == "Error"
            push!(new_alerts, Dict(
                "message" => "Agent $(agent["name"]) is in error state",
                "level" => "error"
            ))
        end
    end
    
    # Check market alerts
    for (pair, data) in DASHBOARD_STATE.market_data
        if abs(data["change_24h"]) > 10
            push!(new_alerts, Dict(
                "message" => "High volatility detected for $pair: $(data["change_24h"])%",
                "level" => "warning"
            ))
        end
    end
    
    # Check bridge alerts
    if DASHBOARD_STATE.bridge_status["pending_txs"] > 5
        push!(new_alerts, Dict(
            "message" => "High number of pending bridge transactions",
            "level" => "warning"
        ))
    end
    
    DASHBOARD_STATE.alerts = new_alerts
end

# Dashboard initialization
function init_dashboard()
    update_agent_status()
    update_market_data()
    update_bridge_status()
    update_performance_metrics()
    check_alerts()
end

# Dashboard update loop
function update_dashboard()
    while true
        update_agent_status()
        update_market_data()
        update_bridge_status()
        update_performance_metrics()
        check_alerts()
        sleep(5)  # Update every 5 seconds
    end
end

# Main dashboard function
function run_dashboard(; host="127.0.0.1", port=8000)
    # Initialize dashboard
    init_dashboard()
    
    # Start update loop in background
    @async update_dashboard()
    
    # Configure Genie
    Genie.config.run_as_server = true
    Genie.config.server_host = host
    Genie.config.server_port = port
    
    # Define routes
    route("/") do
        html(dashboard_layout())
    end
    
    # Start server
    Genie.AppServer.startup()
end

end # module 