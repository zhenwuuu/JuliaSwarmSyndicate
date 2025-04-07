"""
    Algorithms

Module that provides swarm intelligence algorithms for JuliaOS.
Focus on the top 5 algorithms most relevant for DeFi trading applications.
"""
module Algorithms

using Random
using Statistics
using LinearAlgebra

# Include the base algorithm interface
include("BaseAlgorithm.jl")
using .BaseAlgorithm

# Include algorithm implementations (our top 5 for trading)
include("PSO.jl")         # Particle Swarm Optimization - widely used in trading systems
include("GWO.jl")         # Grey Wolf Optimizer - good for capturing market regimes
include("WOA.jl")         # Whale Optimization - handles market volatility well
include("GeneticAlgorithm.jl") # Genetic Algorithms - excellent for complex trading rules
include("ACO.jl")         # Ant Colony Optimization - good for path-dependent strategies
include("DE.jl")          # Differential Evolution - excellent for optimizing trading strategies

# Re-export the base algorithm types and functions
export AbstractSwarmAlgorithm, initialize!, update_positions!, evaluate_fitness!, select_leaders!
export get_best_position, get_best_fitness, get_convergence_data

# Export the algorithm implementations
export PSO, PSOAlgorithm
export GWO, GWOAlgorithm
export WOA, WOAAlgorithm
export GeneticAlgorithm, GAPopulation
export ACO, ACOAlgorithm
export DE, DEAlgorithm

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
    
    if algorithm_type == "pso"
        return PSO.PSOAlgorithm(
            get(params, "inertia_weight", 0.7),
            get(params, "cognitive_coef", 1.5),
            get(params, "social_coef", 1.5),
            get(params, "max_velocity", 1.0)
        )
    elseif algorithm_type == "gwo"
        return GWO.GWOAlgorithm(
            get(params, "alpha_param", 2.0),
            get(params, "decay_rate", 0.01)
        )
    elseif algorithm_type == "woa"
        return WOA.WOAAlgorithm(
            get(params, "a_decrease_factor", 2.0),
            get(params, "spiral_constant", 1.0)
        )
    elseif algorithm_type == "genetic" || algorithm_type == "ga"
        return GeneticAlgorithm.GAPopulation(
            get(params, "crossover_rate", 0.8),
            get(params, "mutation_rate", 0.1),
            get(params, "elitism_count", 2),
            get(params, "tournament_size", 3)
        )
    elseif algorithm_type == "aco"
        return ACO.ACOAlgorithm(
            get(params, "evaporation_rate", 0.1),
            get(params, "alpha", 1.0),          # Pheromone importance
            get(params, "beta", 2.0)            # Heuristic importance
        )
    elseif algorithm_type == "de"
        return DE.DEAlgorithm(
            get(params, "crossover_rate", 0.7),
            get(params, "differential_weight", 0.8),
            get(params, "strategy", "DE/rand/1/bin")
        )
    else
        error("Unknown algorithm type: $algorithm_type")
    end
end

end # module 