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
include("src/AgentSystem.jl")

# Use the modules
using .SwarmManager
using .AgentSystem
using .Algorithms

println("Testing SwarmManager functionality...")

# Test 1: Create a swarm
println("\n--- Test 1: Create a swarm ---")
swarm_config = SwarmManager.SwarmManagerConfig(
    "test_swarm_$(rand(1:1000))",
    Dict{String, Any}(
        "type" => "pso",
        "params" => Dict{String, Any}(
            "inertia_weight" => 0.7,
            "cognitive_coefficient" => 1.5,
            "social_coefficient" => 1.5
        ),
        "coordination_strategy" => "consensus"
    ),
    10, # num_particles
    100, # num_iterations
    ["ETH/USDC", "BTC/USDC"]
)

swarm = SwarmManager.create_swarm(swarm_config)
println("Swarm created: $(swarm.config.name)")

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

# Test 3: Test agent coordination
println("\n--- Test 3: Test agent coordination ---")
try
    result = SwarmManager.coordinate_agents!(swarm)
    println("Agent coordination result: $result")
    
    # Print agent statuses
    for (i, agent) in enumerate(swarm.agents)
        println("Agent $(i): $(agent["id"]) - Status: $(agent["status"])")
    end
catch e
    println("Error during agent coordination: $e")
end

# Test 4: Test broadcasting a message
println("\n--- Test 4: Test broadcasting a message ---")
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

try
    result = SwarmManager.broadcast_message_to_agents!(swarm, message)
    println("Message broadcast result: $result")
    println("Communication log entries: $(length(swarm.communication_log))")
catch e
    println("Error during message broadcast: $e")
end

# Test 5: Test OpenAI Swarm (if API key is available)
println("\n--- Test 5: Test OpenAI Swarm ---")
if !isempty(get(ENV, "OPENAI_API_KEY", ""))
    println("OPENAI_API_KEY is set, testing OpenAI Swarm...")
    
    openai_config = Dict{String, Any}(
        "name" => "test_openai_swarm",
        "agents" => [
            Dict{String, Any}(
                "name" => "cross_chain_agent",
                "instructions" => "You are a cross-chain optimization agent. Your task is to find the most efficient way to transfer tokens between different blockchain networks.",
                "model" => "gpt-4o"
            )
        ]
    )
    
    try
        result = SwarmManager.create_openai_swarm(openai_config)
        println("OpenAI Swarm creation result: $(result["success"])")
        
        if result["success"]
            println("Swarm ID: $(result["swarm_id"])")
        else
            println("Error: $(result["error"])")
        end
    catch e
        println("Error creating OpenAI Swarm: $e")
    end
else
    println("OPENAI_API_KEY not set, skipping OpenAI Swarm test")
end

println("\nAll tests completed!")
