module TestUtils

using Test
using JuliaOS
using JuliaOS.Config
using JuliaOS.SwarmManager
using JuliaOS.MarketData
using JuliaOS.Bridge
using Dates
using Random
using JSON

# Test data generators
function generate_test_market_data(chain::String, pair::String; days::Int=7)
    now = Dates.now()
    data = Dict{String, Any}()
    
    for i in 1:days
        date = now - Day(i)
        data[string(date)] = Dict(
            "price" => rand(1000.0:5000.0),
            "volume" => rand(100000.0:1000000.0),
            "high" => rand(1000.0:5000.0),
            "low" => rand(1000.0:5000.0),
            "open" => rand(1000.0:5000.0),
            "close" => rand(1000.0:5000.0)
        )
    end
    
    return data
end

function generate_test_agent_config(name::String="test_agent")
    return Config.AgentConfig(
        name,
        "Arbitrage Agent",
        "Mean Reversion",
        ["ethereum"],
        Dict(
            "max_position_size" => 0.1,
            "min_profit_threshold" => 0.01,
            "max_gas_price" => 50.0,
            "confidence_threshold" => 0.9
        )
    )
end

function generate_test_swarm_config(name::String="test_swarm")
    return Config.SwarmConfig(
        name,
        10,
        "pso",
        ["ETH/USDC"],
        Dict(
            "inertia_weight" => 0.7,
            "cognitive_coef" => 1.5,
            "social_coef" => 1.5,
            "population_size" => 100,
            "max_iterations" => 1000
        )
    )
end

# Mock implementations
struct MockBridge <: Bridge.AbstractBridge
    is_connected::Bool
    chain_status::Dict{String, Dict{String, Any}}
    token_balances::Dict{String, Dict{String, Float64}}
    
    MockBridge() = new(
        true,
        Dict(
            "ethereum" => Dict(
                "connected" => true,
                "block_height" => 1000000,
                "gas_price" => 50.0
            ),
            "solana" => Dict(
                "connected" => true,
                "block_height" => 500000,
                "gas_price" => 0.00001
            )
        ),
        Dict(
            "ethereum" => Dict(
                "ETH" => 1.0,
                "USDC" => 1000.0
            ),
            "solana" => Dict(
                "SOL" => 10.0,
                "USDC" => 1000.0
            )
        )
    )
end

struct MockMarketData <: MarketData.AbstractMarketData
    prices::Dict{String, Dict{String, Float64}}
    volumes::Dict{String, Dict{String, Float64}}
    
    MockMarketData() = new(
        Dict(
            "ethereum" => Dict(
                "ETH/USDC" => 2000.0,
                "USDC/ETH" => 1/2000.0
            ),
            "solana" => Dict(
                "SOL/USDC" => 100.0,
                "USDC/SOL" => 1/100.0
            )
        ),
        Dict(
            "ethereum" => Dict(
                "ETH/USDC" => 1000000.0,
                "USDC/ETH" => 1000000.0
            ),
            "solana" => Dict(
                "SOL/USDC" => 500000.0,
                "USDC/SOL" => 500000.0
            )
        )
    )
end

# Test assertions
function assert_valid_agent(agent)
    @test agent !== nothing
    @test agent.name != ""
    @test agent.type in ["Arbitrage Agent", "Liquidity Provider"]
    @test !isempty(agent.chains)
    @test !isempty(agent.risk_params)
end

function assert_valid_swarm(swarm)
    @test swarm !== nothing
    @test swarm.name != ""
    @test swarm.algorithm in ["pso", "genetic", "bayesian"]
    @test !isempty(swarm.trading_pairs)
    @test !isempty(swarm.parameters)
end

function assert_valid_market_data(data)
    @test data !== nothing
    @test haskey(data, "price")
    @test haskey(data, "volume")
    @test data["price"] > 0
    @test data["volume"] >= 0
end

# Test setup and teardown
function setup_test_bridge()
    bridge = MockBridge()
    Bridge.set_bridge(bridge)
    return bridge
end

function setup_test_market_data()
    market_data = MockMarketData()
    MarketData.set_market_data(market_data)
    return market_data
end

function setup_test_swarm()
    config = generate_test_swarm_config()
    swarm = SwarmManager.create_swarm(config, "ethereum")
    return swarm
end

# Test cleanup
function cleanup_test_bridge()
    Bridge.set_bridge(nothing)
end

function cleanup_test_market_data()
    MarketData.set_market_data(nothing)
end

function cleanup_test_swarm(swarm)
    if swarm !== nothing
        SwarmManager.stop_swarm(swarm)
    end
end

# Test helpers
function with_test_bridge(f)
    bridge = setup_test_bridge()
    try
        f(bridge)
    finally
        cleanup_test_bridge()
    end
end

function with_test_market_data(f)
    market_data = setup_test_market_data()
    try
        f(market_data)
    finally
        cleanup_test_market_data()
    end
end

function with_test_swarm(f)
    swarm = setup_test_swarm()
    try
        f(swarm)
    finally
        cleanup_test_swarm(swarm)
    end
end

# Export all functions
export generate_test_market_data,
       generate_test_agent_config,
       generate_test_swarm_config,
       assert_valid_agent,
       assert_valid_swarm,
       assert_valid_market_data,
       setup_test_bridge,
       setup_test_market_data,
       setup_test_swarm,
       cleanup_test_bridge,
       cleanup_test_market_data,
       cleanup_test_swarm,
       with_test_bridge,
       with_test_market_data,
       with_test_swarm

end # module 