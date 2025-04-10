using Dates
using Random

# Include the SwarmCoordination module directly
include("src/SwarmManager/SwarmCoordination.jl")

# Use the module
using .SwarmCoordination

println("Testing SwarmCoordination functionality...")

# Create a mock swarm
swarm = Dict{String, Any}(
    "config" => Dict{String, Any}(
        "name" => "test_swarm_$(rand(1:1000))",
        "algorithm" => Dict{String, Any}(
            "coordination_strategy" => "consensus"
        )
    ),
    "decisions" => Dict{String, Any}(),
    "communication_log" => Vector{Dict{String, Any}}(),
    "last_update" => now()
)

# Create mock agents
agents = [
    Dict{String, Any}(
        "id" => "agent_1",
        "position" => [0.5, 0.3, 0.7],
        "fitness" => 2.5,
        "status" => "active"
    ),
    Dict{String, Any}(
        "id" => "agent_2",
        "position" => [0.6, 0.4, 0.8],
        "fitness" => 1.8,
        "status" => "active"
    ),
    Dict{String, Any}(
        "id" => "agent_3",
        "position" => [0.4, 0.2, 0.6],
        "fitness" => 3.2,
        "status" => "active"
    )
]

# Test 1: Get coordination strategy
println("\n--- Test 1: Get coordination strategy ---")
strategy = get_coordination_strategy(swarm)
println("Coordination strategy: $strategy")

# Test 2: Coordinate swarm
println("\n--- Test 2: Coordinate swarm ---")
result = coordinate_swarm!(swarm, agents)
println("Coordination result: $result")

# Test 3: Make swarm decision
println("\n--- Test 3: Make swarm decision ---")
decision = make_swarm_decision(swarm, "test_decision", Dict{String, Any}("param1" => 1, "param2" => 2))
println("Decision: $decision")

# Test 4: Broadcast to swarm
println("\n--- Test 4: Broadcast to swarm ---")
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
result = broadcast_to_swarm(swarm, agents, message)
println("Broadcast result: $result")

println("\nAll tests completed!")
