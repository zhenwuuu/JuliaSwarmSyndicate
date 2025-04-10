using Dates
using Random

# Include the necessary modules directly
include("src/Blockchain.jl")
include("src/SecurityTypes.jl")
include("src/DEX.jl")
include("src/Storage.jl")
include("src/Bridge.jl")
include("src/MarketData.jl")
include("src/JuliaOS/algorithms/Algorithms.jl")
include("src/SwarmManager.jl")

# Use the modules
using .JuliaOS.Algorithms
using .SwarmManager

println("Testing SwarmManager functionality...")

# Test 1: Create a swarm with PSO algorithm
println("\n--- Test 1: Create a swarm with PSO algorithm ---")
swarm_config = SwarmManager.SwarmManagerConfig(
    "test_swarm_$(rand(1:1000))",
    Dict{String, Any}(
        "type" => "pso",
        "params" => Dict{String, Any}(
            "inertia_weight" => 0.7,
            "cognitive_coef" => 1.5,
            "social_coef" => 1.5
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
catch e
    println("Error creating swarm: $e")
end

println("\nAll tests completed!")
