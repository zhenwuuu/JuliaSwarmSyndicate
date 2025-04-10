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

# Include the algorithm factory
include("src/SwarmManager/AlgorithmFactory.jl")

# Use the modules
using .Algorithms
using .AlgorithmFactory

println("Testing Algorithm Factory...")

# Test 1: Create a PSO algorithm
println("\n--- Test 1: Create a PSO algorithm ---")
pso_params = Dict{String, Any}(
    "w" => 0.7,
    "c1" => 1.5,
    "c2" => 1.5
)

try
    pso = create_algorithm("pso", pso_params)
    println("PSO algorithm created: $(typeof(pso))")
catch e
    println("Error creating PSO algorithm: $e")
end

# Test 2: Create a DE algorithm
println("\n--- Test 2: Create a DE algorithm ---")
de_params = Dict{String, Any}(
    "crossover_rate" => 0.8,
    "differential_weight" => 0.7
)

try
    de = create_algorithm("de", de_params)
    println("DE algorithm created: $(typeof(de))")
catch e
    println("Error creating DE algorithm: $e")
end

println("\nAll tests completed!")
