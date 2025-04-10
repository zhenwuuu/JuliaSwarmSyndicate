using Dates
using Random

println("Testing SwarmManager fix...")

# Step 1: Create the AlgorithmFactory module
println("\n--- Step 1: Creating AlgorithmFactory module ---")

algorithm_factory_path = "src/SwarmManager/AlgorithmFactory.jl"
algorithm_factory_content = """
module AlgorithmFactory

export create_algorithm

using Random
using Statistics
using LinearAlgebra

# Import from both possible algorithm modules to ensure compatibility
try
    using ..JuliaOS.Algorithms: PSOAlgorithm, GWOAlgorithm, WOAAlgorithm, GAPopulation, ACOAlgorithm, DEAlgorithm
catch e
    @warn "Could not import from JuliaOS.Algorithms: \$e"
end

try
    using ..Algorithms: PSO, GWO, ACO, GA, WOA, DE
catch e
    @warn "Could not import from Algorithms: \$e"
end

\"\"\"
    create_algorithm(algorithm_type::String, params::Dict{String, Any})

Factory function to create algorithm instances based on the algorithm type.

# Arguments
- `algorithm_type::String`: The type of algorithm to create (e.g., "pso", "gwo")
- `params::Dict{String, Any}`: Algorithm-specific parameters

# Returns
- An instance of the specified algorithm with the given parameters
\"\"\"
function create_algorithm(algorithm_type::String, params::Dict{String, Any})
    algorithm_type = lowercase(algorithm_type)
    
    # Try to create algorithm using JuliaOS.Algorithms if available
    try
        if algorithm_type == "pso"
            return PSOAlgorithm(
                get(params, "inertia_weight", 0.7),
                get(params, "cognitive_coef", 1.5),
                get(params, "social_coef", 1.5),
                get(params, "max_velocity", 1.0)
            )
        elseif algorithm_type == "gwo"
            return GWOAlgorithm(
                get(params, "alpha_param", 2.0),
                get(params, "decay_rate", 0.01)
            )
        elseif algorithm_type == "woa"
            return WOAAlgorithm(
                get(params, "a_decrease_factor", 2.0),
                get(params, "spiral_constant", 1.0)
            )
        elseif algorithm_type == "genetic" || algorithm_type == "ga"
            return GAPopulation(
                get(params, "crossover_rate", 0.8),
                get(params, "mutation_rate", 0.1),
                get(params, "elitism_count", 2),
                get(params, "tournament_size", 3)
            )
        elseif algorithm_type == "aco"
            return ACOAlgorithm(
                get(params, "evaporation_rate", 0.1),
                get(params, "alpha", 1.0),
                get(params, "beta", 2.0)
            )
        elseif algorithm_type == "de"
            return DEAlgorithm(
                get(params, "crossover_rate", 0.7),
                get(params, "differential_weight", 0.8),
                get(params, "strategy", "DE/rand/1/bin")
            )
        end
    catch e
        @warn "Failed to create algorithm using JuliaOS.Algorithms: \$e"
    end
    
    # Fall back to using Algorithms module
    try
        if algorithm_type == "pso"
            return PSO(10, 30, 
                c1=get(params, "cognitive_coef", 1.5),
                c2=get(params, "social_coef", 1.5),
                w=get(params, "inertia_weight", 0.7)
            )
        elseif algorithm_type == "gwo"
            return GWO(10, 30,
                alpha_decrease=get(params, "alpha_param", 0.01)
            )
        elseif algorithm_type == "aco"
            return ACO(10, 30,
                evaporation_rate=get(params, "evaporation_rate", 0.1),
                alpha=get(params, "alpha", 1.0),
                beta=get(params, "beta", 2.0)
            )
        elseif algorithm_type == "ga"
            return GA(10, 50,
                crossover_rate=get(params, "crossover_rate", 0.8),
                mutation_rate=get(params, "mutation_rate", 0.1)
            )
        elseif algorithm_type == "woa"
            return WOA(10, 30,
                b=get(params, "spiral_constant", 1.0)
            )
        elseif algorithm_type == "de"
            return DE(10, 50,
                F=get(params, "differential_weight", 0.8),
                CR=get(params, "crossover_rate", 0.7)
            )
        end
    catch e
        @warn "Failed to create algorithm using Algorithms: \$e"
    end
    
    error("Could not create algorithm of type '\$algorithm_type'. Check that the required modules are available.")
end

end # module AlgorithmFactory
"""

# Create the directory if it doesn't exist
mkpath(dirname(algorithm_factory_path))

# Write the AlgorithmFactory module
open(algorithm_factory_path, "w") do f
    write(f, algorithm_factory_content)
end
println("Created AlgorithmFactory module at $algorithm_factory_path")

# Step 2: Update the SwarmManager.jl file to use the AlgorithmFactory
println("\n--- Step 2: Updating SwarmManager.jl ---")

# First, let's check if the file exists
if isfile("src/SwarmManager.jl")
    # Read the current content
    swarm_manager_content = read("src/SwarmManager.jl", String)
    
    # Add the AlgorithmFactory include
    if !occursin("include(\"SwarmManager/AlgorithmFactory.jl\")", swarm_manager_content)
        swarm_manager_content = replace(swarm_manager_content, 
            "# Include the SwarmCoordination module\n# include(\"SwarmManager/SwarmCoordination.jl\")\n# using .SwarmCoordination" => 
            "# Include the SwarmCoordination module\ninclude(\"SwarmManager/SwarmCoordination.jl\")\nusing .SwarmCoordination\n\n# Include the AlgorithmFactory module\ninclude(\"SwarmManager/AlgorithmFactory.jl\")\nusing .AlgorithmFactory")
        
        # Write the updated content
        open("src/SwarmManager.jl", "w") do f
            write(f, swarm_manager_content)
        end
        println("Updated SwarmManager.jl to use AlgorithmFactory")
    else
        println("SwarmManager.jl already includes AlgorithmFactory")
    end
else
    println("SwarmManager.jl not found, skipping update")
end

# Step 3: Create a test for the AlgorithmFactory
println("\n--- Step 3: Creating test for AlgorithmFactory ---")

test_algorithm_path = "test_algorithm_factory.jl"
test_algorithm_content = """
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
println("\\n--- Test 1: Create a PSO algorithm ---")
pso_params = Dict{String, Any}(
    "w" => 0.7,
    "c1" => 1.5,
    "c2" => 1.5
)

try
    pso = create_algorithm("pso", pso_params)
    println("PSO algorithm created: \$(typeof(pso))")
catch e
    println("Error creating PSO algorithm: \$e")
end

# Test 2: Create a DE algorithm
println("\\n--- Test 2: Create a DE algorithm ---")
de_params = Dict{String, Any}(
    "crossover_rate" => 0.8,
    "differential_weight" => 0.7
)

try
    de = create_algorithm("de", de_params)
    println("DE algorithm created: \$(typeof(de))")
catch e
    println("Error creating DE algorithm: \$e")
end

println("\\nAll tests completed!")
"""

# Write the test file
open(test_algorithm_path, "w") do f
    write(f, test_algorithm_content)
end
println("Created test for AlgorithmFactory at $test_algorithm_path")

println("\nAll fixes completed!")
println("\nTo test the AlgorithmFactory, run: julia test_algorithm_factory.jl")
