"""
Ant Colony Optimization (ACO) implementation.

Ant Colony Optimization is a probabilistic technique for solving computational problems
which can be reduced to finding good paths through graphs. It is inspired by the behavior
of ants seeking a path between their colony and a source of food.

This implementation focuses on continuous domain optimization rather than the traditional
discrete domain applications of ACO.

References:
- Socha, K., & Dorigo, M. (2008). Ant colony optimization for continuous domains.
  European journal of operational research, 185(3), 1155-1173.
"""
module ACO

export AntColonyOptimizer, optimize

using Random
using Statistics
using Distributions
using LinearAlgebra
using ..SwarmBase

"""
    AntColonyOptimizer

Ant Colony Optimizer for continuous domains.

# Fields
- `colony_size::Int`: Number of ants in the colony
- `max_iterations::Int`: Maximum number of iterations
- `archive_size::Int`: Size of the solution archive
- `q::Float64`: Locality of search (small q focuses search around best solutions)
- `xi::Float64`: Pheromone evaporation rate
"""
struct AntColonyOptimizer <: AbstractSwarmAlgorithm
    colony_size::Int
    max_iterations::Int
    archive_size::Int
    q::Float64
    xi::Float64

    function AntColonyOptimizer(;
        colony_size::Int = 50,
        max_iterations::Int = 100,
        archive_size::Int = 30,
        q::Float64 = 0.5,
        xi::Float64 = 0.7
    )
        # Parameter validation
        colony_size > 0 || throw(ArgumentError("Colony size must be positive"))
        max_iterations > 0 || throw(ArgumentError("Maximum iterations must be positive"))
        archive_size > 0 || throw(ArgumentError("Archive size must be positive"))
        q > 0 || throw(ArgumentError("q must be positive"))
        xi >= 0 && xi <= 1 || throw(ArgumentError("xi must be between 0 and 1"))

        new(colony_size, max_iterations, archive_size, q, xi)
    end
end

"""
    optimize(problem::OptimizationProblem, algorithm::AntColonyOptimizer)

Optimize the given problem using the Ant Colony Optimization algorithm.

# Arguments
- `problem::OptimizationProblem`: The optimization problem to solve
- `algorithm::AntColonyOptimizer`: The ACO algorithm configuration

# Returns
- `OptimizationResult`: The optimization result containing the best solution found
"""
function optimize(problem::OptimizationProblem, algorithm::AntColonyOptimizer)
    # Extract problem parameters
    dimensions = problem.dimensions
    bounds = problem.bounds
    objective_function = problem.objective_function

    # Extract algorithm parameters
    colony_size = algorithm.colony_size
    max_iterations = algorithm.max_iterations
    archive_size = algorithm.archive_size
    q = algorithm.q
    xi = algorithm.xi

    # Initialize the solution archive
    archive = initialize_archive(archive_size, dimensions, bounds, objective_function)

    # Sort the archive by fitness
    sort!(archive, by = x -> x.fitness)

    # Initialize iteration counter and evaluations
    iteration = 1
    evaluations = archive_size

    # Initialize best solution tracking
    best_solution = copy(archive[1].position)
    best_fitness = archive[1].fitness

    # Initialize convergence tracking
    convergence_curve = zeros(max_iterations)

    # Calculate weights for each solution in the archive
    weights = calculate_weights(archive_size, q)

    # Start the main loop
    while iteration <= max_iterations
        # Generate new solutions using the archive
        for i in 1:colony_size
            # Generate a new solution
            new_solution = generate_solution(archive, weights, dimensions, bounds)

            # Evaluate the fitness of the new solution
            new_fitness = objective_function(new_solution)
            evaluations += 1

            # Update the archive if the new solution is better than the worst in the archive
            if new_fitness < archive[end].fitness
                archive[end] = (position = new_solution, fitness = new_fitness)

                # Re-sort the archive
                sort!(archive, by = x -> x.fitness)

                # Update best solution if needed
                if new_fitness < best_fitness
                    best_solution = copy(new_solution)
                    best_fitness = new_fitness
                end
            end
        end

        # Record the best fitness for this iteration
        convergence_curve[iteration] = best_fitness

        # Apply pheromone evaporation (implicit in the algorithm)

        # Increment iteration counter
        iteration += 1
    end

    # Return the optimization result
    return OptimizationResult(
        best_solution,           # best_position
        best_fitness,            # best_fitness
        convergence_curve,       # convergence_curve
        max_iterations,          # iterations
        evaluations,             # evaluations
        "Ant Colony Optimizer"   # algorithm_name
    )
end

"""
    initialize_archive(archive_size, dimensions, bounds, objective_function)

Initialize the solution archive with random solutions.

# Arguments
- `archive_size::Int`: Size of the solution archive
- `dimensions::Int`: Number of dimensions in the search space
- `bounds::Vector{Tuple{Float64, Float64}}`: Bounds for each dimension
- `objective_function::Function`: The objective function to minimize

# Returns
- `Vector{NamedTuple{(:position, :fitness), Tuple{Vector{Float64}, Float64}}}`: Initial solution archive
"""
function initialize_archive(archive_size, dimensions, bounds, objective_function)
    archive = Vector{NamedTuple{(:position, :fitness), Tuple{Vector{Float64}, Float64}}}(undef, archive_size)

    for i in 1:archive_size
        # Generate random position within bounds
        position = Vector{Float64}(undef, dimensions)

        for j in 1:dimensions
            lower_bound, upper_bound = bounds[j]
            position[j] = lower_bound + rand() * (upper_bound - lower_bound)
        end

        # Evaluate fitness
        fitness = objective_function(position)

        # Add to archive
        archive[i] = (position = position, fitness = fitness)
    end

    return archive
end

"""
    calculate_weights(archive_size, q)

Calculate the weights for each solution in the archive.

# Arguments
- `archive_size::Int`: Size of the solution archive
- `q::Float64`: Locality of search parameter

# Returns
- `Vector{Float64}`: Weights for each solution in the archive
"""
function calculate_weights(archive_size, q)
    weights = Vector{Float64}(undef, archive_size)

    for i in 1:archive_size
        weights[i] = (1 / (q * archive_size * sqrt(2π))) *
                     exp(-(i - 1)^2 / (2 * (q * archive_size)^2))
    end

    return weights
end

"""
    generate_solution(archive, weights, dimensions, bounds)

Generate a new solution using the archive and weights.

# Arguments
- `archive::Vector{NamedTuple}`: The solution archive
- `weights::Vector{Float64}`: Weights for each solution in the archive
- `dimensions::Int`: Number of dimensions in the search space
- `bounds::Vector{Tuple{Float64, Float64}}`: Bounds for each dimension

# Returns
- `Vector{Float64}`: A new solution
"""
function generate_solution(archive, weights, dimensions, bounds)
    archive_size = length(archive)
    new_solution = Vector{Float64}(undef, dimensions)

    for j in 1:dimensions
        # Choose a solution from the archive based on weights
        selected_idx = sample_index(weights)
        selected_solution = archive[selected_idx].position

        # Calculate standard deviation for this dimension
        sigma = calculate_standard_deviation(archive, j, selected_idx, archive_size)

        # Generate new value using Gaussian distribution
        dist = Normal(selected_solution[j], sigma)
        new_value = rand(dist)

        # Apply bounds
        lower_bound, upper_bound = bounds[j]
        new_solution[j] = clamp(new_value, lower_bound, upper_bound)
    end

    return new_solution
end

"""
    sample_index(weights)

Sample an index based on the given weights.

# Arguments
- `weights::Vector{Float64}`: Weights for each solution

# Returns
- `Int`: Sampled index
"""
function sample_index(weights)
    # Normalize weights to probabilities
    total_weight = sum(weights)
    probabilities = weights ./ total_weight

    # Sample based on probabilities
    r = rand()
    cumulative_prob = 0.0

    for i in 1:length(probabilities)
        cumulative_prob += probabilities[i]
        if r <= cumulative_prob
            return i
        end
    end

    # Fallback (should rarely happen due to floating-point precision)
    return length(probabilities)
end

"""
    calculate_standard_deviation(archive, dimension, selected_idx, archive_size)

Calculate the standard deviation for a specific dimension.

# Arguments
- `archive::Vector{NamedTuple}`: The solution archive
- `dimension::Int`: The dimension to calculate standard deviation for
- `selected_idx::Int`: Index of the selected solution
- `archive_size::Int`: Size of the archive

# Returns
- `Float64`: Standard deviation
"""
function calculate_standard_deviation(archive, dimension, selected_idx, archive_size)
    # Calculate the sum of distances to other solutions
    sum_distances = 0.0

    for i in 1:archive_size
        if i != selected_idx
            sum_distances += abs(archive[selected_idx].position[dimension] -
                                archive[i].position[dimension])
        end
    end

    # Calculate standard deviation using a fixed xi value
    # This should ideally come from the algorithm parameters
    xi_value = 0.7
    sigma = xi_value * sum_distances / (archive_size - 1)

    return max(sigma, 1e-10)  # Ensure minimum standard deviation
end

end # module ACO
