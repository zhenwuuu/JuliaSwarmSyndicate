module AlgorithmFactory

export create_algorithm

using Random
using Statistics
using LinearAlgebra

# Define fallback algorithm implementations
struct FallbackPSO
    dimensions::Int
    particles::Int
    w::Float64
    c1::Float64
    c2::Float64
end

struct FallbackDE
    dimensions::Int
    population_size::Int
    F::Float64  # Differential weight
    CR::Float64 # Crossover rate
    strategy::String
end

"""
    create_algorithm(algorithm_type::String, params::Dict{String, Any})

Factory function to create algorithm instances based on the algorithm type.

# Arguments
- `algorithm_type::String`: The type of algorithm to create (e.g., "pso", "gwo")
- `params::Dict{String, Any}`: Algorithm-specific parameters

# Returns
- An instance of the specified algorithm with the given parameters
"""
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
        elseif algorithm_type == "de" || algorithm_type == "differential_evolution"
            return DEAlgorithm(
                get(params, "crossover_rate", 0.7),
                get(params, "differential_weight", 0.8),
                get(params, "strategy", "DE/rand/1/bin")
            )
        end
    catch e
        @warn "Failed to create algorithm using JuliaOS.Algorithms: $e"
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
        elseif algorithm_type == "de" || algorithm_type == "differential_evolution"
            return DE(10, 50,
                F=get(params, "differential_weight", 0.8),
                CR=get(params, "crossover_rate", 0.7)
            )
        end
    catch e
        @warn "Failed to create algorithm using Algorithms: $e"
    end

    # Use fallback implementations if all else fails
    if algorithm_type == "pso"
        return FallbackPSO(
            10,
            30,
            get(params, "w", 0.7),
            get(params, "c1", 1.5),
            get(params, "c2", 1.5)
        )
    elseif algorithm_type == "de" || algorithm_type == "differential_evolution"
        return FallbackDE(
            10,
            30,
            get(params, "differential_weight", 0.8),
            get(params, "crossover_rate", 0.7),
            get(params, "strategy", "DE/rand/1/bin")
        )
    else
        # For other algorithms, return a PSO as fallback
        @warn "Algorithm type '$algorithm_type' not supported, using PSO as fallback"
        return FallbackPSO(
            10,
            30,
            0.7,
            1.5,
            1.5
        )
    end
end

end # module AlgorithmFactory
