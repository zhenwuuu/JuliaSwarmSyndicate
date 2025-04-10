using Dates
using Random

# Include the necessary modules directly
include("src/Blockchain.jl")
include("src/SecurityTypes.jl")
include("src/DEX.jl")
include("src/Storage.jl")
include("src/Bridge.jl")
include("src/MarketData.jl")
include("src/algorithms/Algorithms.jl")
include("src/SwarmManager.jl")

# Use the modules
using .Algorithms
using .SwarmManager

println("Testing SwarmManager integration...")

# Test 1: Create a swarm with PSO algorithm
println("\n--- Test 1: Create a swarm with PSO algorithm ---")
swarm_config = SwarmManager.SwarmManagerConfig(
    "test_swarm_$(rand(1:1000))",
    Dict{String, Any}(
        "type" => "pso",
        "params" => Dict{String, Any}(
            "w" => 0.7,
            "c1" => 1.5,
            "c2" => 1.5
        )
    ),
    10, # num_particles
    100, # num_iterations
    ["ETH/USDC", "BTC/USDC"]
)

try
    swarm = SwarmManager.create_swarm(swarm_config)
    println("Swarm created: $(swarm.config.name)")
    println("Algorithm type: $(typeof(swarm.algorithm))")
    
    # Test 2: Add agents to the swarm
    println("\n--- Test 2: Add agents to the swarm ---")
    for i in 1:3
        agent_id = "agent_$(i)_$(rand(1:1000))"
        agent_type = "cross_chain_optimizer"
        capabilities = ["cross_chain", "optimization"]
        
        result = SwarmManager.add_agent_to_swarm!(swarm, agent_id, agent_type, capabilities)
        println("Added agent $agent_id: $result")
    end
    
    println("Number of agents in swarm: $(length(swarm.agents))")
    
    # Test 3: Coordinate agents
    println("\n--- Test 3: Coordinate agents ---")
    result = SwarmManager.coordinate_agents!(swarm)
    println("Agent coordination result: $result")
    
    # Test 4: Broadcast a message
    println("\n--- Test 4: Broadcast a message ---")
    message = Dict{String, Any}(
        "type" => "command",
        "action" => "optimize",
        "parameters" => Dict{String, Any}(
            "source_chain" => "ethereum",
            "target_chain" => "solana",
            "token" => "USDC",
            "amount" => 100.0
        )
    )
    
    result = SwarmManager.broadcast_message_to_agents!(swarm, message)
    println("Message broadcast result: $result")
    println("Communication log entries: $(length(swarm.communication_log))")
    
catch e
    println("Error: $e")
end

println("\nAll tests completed!")
