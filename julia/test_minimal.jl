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

# Use the modules
using .Algorithms

println("Testing Algorithms functionality...")

# Test 1: Create a PSO algorithm
println("\n--- Test 1: Create a PSO algorithm ---")
pso_params = Dict{String, Any}(
    "c1" => 1.5,
    "c2" => 1.5,
    "w" => 0.7
)

# Create a PSO algorithm
pso = PSO(10, 30, c1=1.5, c2=1.5, w=0.7)
println("PSO algorithm created: $(typeof(pso))")

# Test 2: Create a DE algorithm
println("\n--- Test 2: Create a DE algorithm ---")
de = DE(10, 30, F=0.8, CR=0.9)
println("DE algorithm created: $(typeof(de))")

# Test 3: Initialize the PSO algorithm
println("\n--- Test 3: Initialize the PSO algorithm ---")
bounds = [(0.0, 1.0) for _ in 1:10]
particles = initialize(pso, bounds)
println("PSO initialized with $(length(particles)) particles")

println("\nAll tests completed!")
