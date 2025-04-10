using Dates
using Random

# Include the necessary modules directly
include("julia/src/Blockchain.jl")
include("julia/src/SecurityTypes.jl")
include("julia/src/DEX.jl")
include("julia/src/Storage.jl")
include("julia/src/Bridge.jl")
include("julia/src/MarketData.jl")
include("julia/src/algorithms/Algorithms.jl")
include("julia/src/SwarmManager.jl")

# Use the modules
using .SwarmManager

println("Testing SwarmManager implementation...")

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
        ),
        "coordination_strategy" => "consensus"
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

    # Test 4: Make a swarm decision
    println("\n--- Test 4: Make a swarm decision ---")
    decision_type = "cross_chain_transfer"
    parameters = Dict{String, Any}(
        "source_chain" => "ethereum",
        "target_chain" => "solana",
        "token" => "USDC",
        "amount" => 100.0
    )

    decision = SwarmManager.make_swarm_decision(swarm, decision_type, parameters)
    println("Decision made: $(decision["decision_type"])")

    # Test 5: Broadcast a message
    println("\n--- Test 5: Broadcast a message ---")
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

    # Test 6: Create a DE algorithm swarm
    println("\n--- Test 6: Create a DE algorithm swarm ---")
    de_swarm_config = SwarmManager.SwarmManagerConfig(
        "de_swarm_$(rand(1:1000))",
        Dict{String, Any}(
            "type" => "de",
            "params" => Dict{String, Any}(
                "crossover_rate" => 0.7,
                "differential_weight" => 0.8,
                "strategy" => "DE/rand/1/bin"
            ),
            "coordination_strategy" => "hierarchical"
        ),
        20, # num_particles
        200, # num_iterations
        ["ETH/USDC", "BTC/USDC", "SOL/USDC"]
    )

    de_swarm = SwarmManager.create_swarm(de_swarm_config)
    println("DE Swarm created: $(de_swarm.config.name)")
    println("DE Algorithm type: $(typeof(de_swarm.algorithm))")

    # Test 7: Create an OpenAI swarm
    println("\n--- Test 7: Create an OpenAI swarm ---")
    openai_config = Dict{String, Any}(
        "name" => "openai_swarm_$(rand(1:1000))",
        "agents" => [
            Dict{String, Any}(
                "name" => "cross_chain_agent",
                "instructions" => "You are a cross-chain optimization agent.",
                "model" => "gpt-4o"
            ),
            Dict{String, Any}(
                "name" => "trading_agent",
                "instructions" => "You are a trading agent.",
                "model" => "gpt-4o"
            )
        ]
    )

    # Note: This will only work if OPENAI_API_KEY is set
    # We'll catch the error if it's not
    try
        openai_result = SwarmManager.create_openai_swarm(openai_config)
        if get(openai_result, "success", false)
            println("OpenAI Swarm created: $(openai_result["name"])")
            println("OpenAI Swarm ID: $(openai_result["swarm_id"])")
            println("Agents created: $(length(openai_result["agents_created"]))")
        else
            println("OpenAI Swarm creation failed: $(get(openai_result, "error", "Unknown error"))")
        end
    catch e
        println("OpenAI Swarm creation error: $e")
    end

catch e
    println("Error: $e")
end

println("\nAll tests completed!")
