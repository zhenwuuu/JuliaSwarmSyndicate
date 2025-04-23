#!/usr/bin/env julia

# Add the Agents package to the environment if it's not already there
import Pkg
if !haskey(Pkg.project().dependencies, "Agents")
    Pkg.develop(path="../")
end

using Agents
using Dates

println("JuliaOS Agents Example - Trading Agent Creation")
println("-----------------------------------------------")

# Define trading strategies
strategies = [
    "MeanReversion",
    "BreakoutTrading",
    "TrendFollowing",
    "GridTrading"
]

# Define timeframes
timeframes = [
    "1m", "5m", "15m", "1h", "4h", "1d"
]

# Create agent configuration
println("Creating a new trading agent configuration...")
config = AgentConfig(
    "eth_usdc_trader",                        # name
    "Trading",                                # type
    ["price_monitoring", "order_execution"],  # abilities
    ["Ethereum"],                             # chains
    Dict(                                     # parameters
        "trading_pair" => "ETH/USDC",
        "strategy" => "TrendFollowing",
        "timeframe" => "15m", 
        "max_position_size" => 0.5,           # ETH
        "take_profit" => 0.03,                # 3%
        "stop_loss" => 0.02,                  # 2%
        "dex" => "Uniswap",
        "auto_rebalance" => true
    )
)

# Create the agent
println("Creating agent...")
agent = createAgent(config)
println("✓ Created agent: $(agent.id) ($(agent.name))")
println("  Type: $(agent.type)")
println("  Status: $(agent.status)")
println("  Created: $(agent.created)")

# Start the agent
println("\nStarting agent...")
success = startAgent(agent.id)
if success
    println("✓ Agent started successfully")
else
    println("✗ Failed to start agent")
end

# Check agent status
println("\nChecking agent status...")
status = getAgentStatus(agent.id)
println("✓ Agent status: $(status["status"])")
println("  Uptime: $(status["uptime"]) seconds")
println("  Tasks completed: $(status["tasks_completed"])")
println("  CPU usage: $(status["cpu_usage"])%")
println("  Memory usage: $(status["memory_usage"])MB")

# Simulate waiting for agent to do some work
println("\nWaiting for agent to execute trades (simulated)...")
sleep(3)
println("✓ Agent has executed trades")

# Stop the agent
println("\nStopping agent...")
stopAgent(agent.id)
println("✓ Agent stopped")

println("\n-----------------------------------------------")
println("Trading agent example completed") 