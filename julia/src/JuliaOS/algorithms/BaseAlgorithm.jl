"""
    BaseAlgorithm

Abstract module defining the interface for all swarm intelligence algorithms.
Each algorithm implementation must provide these core functions.
"""
module BaseAlgorithm

export AbstractSwarmAlgorithm, initialize!, update_positions!, evaluate_fitness!, select_leaders!

"""
    AbstractSwarmAlgorithm

Abstract type that all swarm algorithm implementations should inherit from.
"""
abstract type AbstractSwarmAlgorithm end

"""
    initialize!(algorithm::AbstractSwarmAlgorithm, swarm_size::Int, dimension::Int, bounds::Vector{Tuple{Float64, Float64}})

Initialize the algorithm with the given parameters.
- `swarm_size`: Number of agents/particles in the swarm
- `dimension`: Dimensionality of the search space
- `bounds`: Min and max values for each dimension [(min_1, max_1), (min_2, max_2), ...]
"""
function initialize!(algorithm::AbstractSwarmAlgorithm, swarm_size::Int, dimension::Int, bounds::Vector{Tuple{Float64, Float64}})
    error("initialize! not implemented for $(typeof(algorithm))")
end

"""
    update_positions!(algorithm::AbstractSwarmAlgorithm, fitness_function::Function)

Update the positions of all agents based on the algorithm's rules.
- `fitness_function`: Function that evaluates the fitness of a position
"""
function update_positions!(algorithm::AbstractSwarmAlgorithm, fitness_function::Function)
    error("update_positions! not implemented for $(typeof(algorithm))")
end

"""
    evaluate_fitness!(algorithm::AbstractSwarmAlgorithm, fitness_function::Function)

Evaluate the fitness of all agents using the provided fitness function.
- `fitness_function`: Function that evaluates the fitness of a position
"""
function evaluate_fitness!(algorithm::AbstractSwarmAlgorithm, fitness_function::Function)
    error("evaluate_fitness! not implemented for $(typeof(algorithm))")
end

"""
    select_leaders!(algorithm::AbstractSwarmAlgorithm)

Select the leading agents (global best, alpha, beta, etc.) based on fitness.
"""
function select_leaders!(algorithm::AbstractSwarmAlgorithm)
    error("select_leaders! not implemented for $(typeof(algorithm))")
end

"""
    get_best_position(algorithm::AbstractSwarmAlgorithm)

Get the best position found by the algorithm so far.
"""
function get_best_position(algorithm::AbstractSwarmAlgorithm)
    error("get_best_position not implemented for $(typeof(algorithm))")
end

"""
    get_best_fitness(algorithm::AbstractSwarmAlgorithm)

Get the best fitness value found by the algorithm so far.
"""
function get_best_fitness(algorithm::AbstractSwarmAlgorithm)
    error("get_best_fitness not implemented for $(typeof(algorithm))")
end

"""
    get_convergence_data(algorithm::AbstractSwarmAlgorithm)

Get convergence history data for analysis.
"""
function get_convergence_data(algorithm::AbstractSwarmAlgorithm)
    error("get_convergence_data not implemented for $(typeof(algorithm))")
end

end # module 