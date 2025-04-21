"""
SwarmBase module for JuliaOS

This module provides the base types and interfaces for swarm optimization algorithms.
"""
module SwarmBase

export AbstractSwarmAlgorithm, OptimizationProblem, OptimizationResult

"""
    AbstractSwarmAlgorithm

Abstract type for all swarm optimization algorithms.
"""
abstract type AbstractSwarmAlgorithm end

"""
    OptimizationProblem

Structure representing an optimization problem.

# Fields
- `dimensions::Int`: Number of dimensions in the search space
- `bounds::Vector{Tuple{Float64, Float64}}`: Bounds for each dimension (min, max)
- `objective_function::Function`: The function to optimize
- `constraints::Vector{Function}`: Optional constraint functions
- `is_minimization::Bool`: Whether the problem is a minimization (true) or maximization (false)
"""
struct OptimizationProblem
    dimensions::Int
    bounds::Vector{Tuple{Float64, Float64}}
    objective_function::Function
    constraints::Vector{Function}
    is_minimization::Bool
    
    function OptimizationProblem(
        dimensions::Int,
        bounds::Vector{Tuple{Float64, Float64}},
        objective_function::Function;
        constraints::Vector{Function} = Function[],
        is_minimization::Bool = true
    )
        # Validate dimensions and bounds
        if length(bounds) != dimensions
            throw(ArgumentError("Number of bounds must match dimensions"))
        end
        
        # Validate bounds
        for (min_val, max_val) in bounds
            if min_val >= max_val
                throw(ArgumentError("Lower bound must be less than upper bound"))
            end
        end
        
        new(dimensions, bounds, objective_function, constraints, is_minimization)
    end
end

"""
    OptimizationResult

Structure representing the result of an optimization.

# Fields
- `best_position::Vector{Float64}`: The best solution found
- `best_fitness::Float64`: The fitness value of the best solution
- `convergence_curve::Vector{Float64}`: History of best fitness values
- `iterations::Int`: Number of iterations performed
- `evaluations::Int`: Number of function evaluations
- `algorithm_name::String`: Name of the algorithm used
- `success::Bool`: Whether the optimization was successful
- `message::String`: Additional information about the result
"""
struct OptimizationResult
    best_position::Vector{Float64}
    best_fitness::Float64
    convergence_curve::Vector{Float64}
    iterations::Int
    evaluations::Int
    algorithm_name::String
    success::Bool
    message::String
    
    function OptimizationResult(
        best_position::Vector{Float64},
        best_fitness::Float64,
        convergence_curve::Vector{Float64},
        iterations::Int,
        evaluations::Int,
        algorithm_name::String;
        success::Bool = true,
        message::String = ""
    )
        new(best_position, best_fitness, convergence_curve, iterations, evaluations, algorithm_name, success, message)
    end
end

end # module
