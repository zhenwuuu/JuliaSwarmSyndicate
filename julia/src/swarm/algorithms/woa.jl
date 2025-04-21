"""
Whale Optimization Algorithm (WOA) implementation.

The Whale Optimization Algorithm is a nature-inspired meta-heuristic optimization algorithm
that mimics the hunting behavior of humpback whales. The algorithm simulates the bubble-net
hunting strategy and the search for prey.

References:
- Mirjalili, S., & Lewis, A. (2016). The whale optimization algorithm.
  Advances in engineering software, 95, 51-67.
"""
module WOA

export WhaleOptimizer, optimize

using Random
using Statistics
using ..SwarmBase

"""
    WhaleOptimizer

Whale Optimization Algorithm configuration.

# Fields
- `population_size::Int`: Number of whales in the population
- `max_iterations::Int`: Maximum number of iterations
- `b::Float64`: Spiral shape constant
- `a_decrease_factor::Float64`: Factor controlling the decrease of parameter a over iterations
"""
struct WhaleOptimizer <: AbstractSwarmAlgorithm
    population_size::Int
    max_iterations::Int
    b::Float64
    a_decrease_factor::Float64

    function WhaleOptimizer(;
        population_size::Int = 30,
        max_iterations::Int = 100,
        b::Float64 = 1.0,
        a_decrease_factor::Float64 = 2.0
    )
        # Parameter validation
        population_size > 0 || throw(ArgumentError("Population size must be positive"))
        max_iterations > 0 || throw(ArgumentError("Maximum iterations must be positive"))
        b > 0 || throw(ArgumentError("b must be positive"))
        a_decrease_factor > 0 || throw(ArgumentError("a decrease factor must be positive"))

        new(population_size, max_iterations, b, a_decrease_factor)
    end
end

"""
    optimize(problem::OptimizationProblem, algorithm::WhaleOptimizer)

Optimize the given problem using the Whale Optimization Algorithm.

# Arguments
- `problem::OptimizationProblem`: The optimization problem to solve
- `algorithm::WhaleOptimizer`: The WOA algorithm configuration

# Returns
- `OptimizationResult`: The optimization result containing the best solution found
"""
function optimize(problem::OptimizationProblem, algorithm::WhaleOptimizer)
    # Extract problem parameters
    dimensions = problem.dimensions
    bounds = problem.bounds
    objective_function = problem.objective_function

    # Extract algorithm parameters
    population_size = algorithm.population_size
    max_iterations = algorithm.max_iterations
    b = algorithm.b
    a_decrease_factor = algorithm.a_decrease_factor

    # Initialize the whale population
    population = initialize_population(population_size, dimensions, bounds)

    # Evaluate the fitness of each whale
    fitness = [objective_function(whale) for whale in population]

    # Initialize iteration counter and evaluations
    iteration = 1
    evaluations = population_size

    # Initialize best solution tracking
    best_idx = argmin(fitness)
    best_whale = copy(population[best_idx])
    best_fitness = fitness[best_idx]

    # Initialize convergence tracking
    convergence_curve = zeros(max_iterations)

    # Start the main loop
    while iteration <= max_iterations
        # Update the parameter a
        a = a_decrease_factor * (1 - iteration / max_iterations)

        # Update each whale's position
        for i in 1:population_size
            # Update the position of the current whale
            r = rand()

            # Exploitation phase (bubble-net attacking)
            if r < 0.5
                # Shrinking encircling mechanism or spiral model
                p = rand()

                if p < 0.5
                    # Shrinking encircling mechanism
                    r1 = rand()
                    r2 = rand()
                    A = 2 * a * r1 - a
                    C = 2 * r2

                    # Calculate distance to best whale
                    D = abs.(C .* best_whale .- population[i])

                    # Update position
                    population[i] = best_whale .- A .* D
                else
                    # Spiral model
                    D = abs.(best_whale .- population[i])
                    l = rand() * 2 - 1  # Random number in [-1, 1]

                    # Update position using spiral equation
                    population[i] = D .* exp(b * l) .* cos(2π * l) .+ best_whale
                end
            else
                # Exploration phase (searching for prey)
                r1 = rand()
                r2 = rand()
                A = 2 * a * r1 - a
                C = 2 * r2

                # Select a random whale
                rand_idx = rand(1:population_size)
                rand_whale = population[rand_idx]

                # Calculate distance to random whale
                D = abs.(C .* rand_whale .- population[i])

                # Update position
                population[i] = rand_whale .- A .* D
            end

            # Apply bounds
            for j in 1:dimensions
                lower_bound, upper_bound = bounds[j]
                population[i][j] = clamp(population[i][j], lower_bound, upper_bound)
            end

            # Evaluate the fitness of the updated position
            fitness[i] = objective_function(population[i])
            evaluations += 1

            # Update best solution if needed
            if fitness[i] < best_fitness
                best_whale = copy(population[i])
                best_fitness = fitness[i]
            end
        end

        # Record the best fitness for this iteration
        convergence_curve[iteration] = best_fitness

        # Increment iteration counter
        iteration += 1
    end

    # Return the optimization result
    return OptimizationResult(
        best_whale,              # best_position
        best_fitness,            # best_fitness
        convergence_curve,       # convergence_curve
        max_iterations,          # iterations
        evaluations,             # evaluations
        "Whale Optimization Algorithm"  # algorithm_name
    )
end

"""
    initialize_population(population_size, dimensions, bounds)

Initialize the whale population with random positions within the bounds.

# Arguments
- `population_size::Int`: Number of whales in the population
- `dimensions::Int`: Number of dimensions in the search space
- `bounds::Vector{Tuple{Float64, Float64}}`: Bounds for each dimension

# Returns
- `Vector{Vector{Float64}}`: Initial positions of the whales
"""
function initialize_population(population_size, dimensions, bounds)
    population = Vector{Vector{Float64}}(undef, population_size)

    for i in 1:population_size
        whale = Vector{Float64}(undef, dimensions)

        for j in 1:dimensions
            lower_bound, upper_bound = bounds[j]
            whale[j] = lower_bound + rand() * (upper_bound - lower_bound)
        end

        population[i] = whale
    end

    return population
end

end # module WOA
