"""
Grey Wolf Optimizer (GWO) implementation.

The Grey Wolf Optimizer is a meta-heuristic algorithm inspired by the social hierarchy
and hunting behavior of grey wolves. The algorithm categorizes wolves into four types:
alpha, beta, delta, and omega, representing the hierarchy of grey wolves.

References:
- Mirjalili, S., Mirjalili, S. M., & Lewis, A. (2014). Grey wolf optimizer.
  Advances in engineering software, 69, 46-61.
"""
module GWO

export GreyWolfOptimizer, optimize

using Random
using Statistics
using ..SwarmBase

"""
    GreyWolfOptimizer

Grey Wolf Optimizer algorithm configuration.

# Fields
- `population_size::Int`: Number of wolves in the pack
- `max_iterations::Int`: Maximum number of iterations
- `a_decrease_factor::Float64`: Factor controlling the decrease of parameter a over iterations
"""
struct GreyWolfOptimizer <: AbstractSwarmAlgorithm
    population_size::Int
    max_iterations::Int
    a_decrease_factor::Float64

    function GreyWolfOptimizer(;
        population_size::Int = 30,
        max_iterations::Int = 100,
        a_decrease_factor::Float64 = 2.0
    )
        # Parameter validation
        population_size > 0 || throw(ArgumentError("Population size must be positive"))
        max_iterations > 0 || throw(ArgumentError("Maximum iterations must be positive"))
        a_decrease_factor > 0 || throw(ArgumentError("a decrease factor must be positive"))

        new(population_size, max_iterations, a_decrease_factor)
    end
end

"""
    optimize(problem::OptimizationProblem, algorithm::GreyWolfOptimizer)

Optimize the given problem using the Grey Wolf Optimizer algorithm.

# Arguments
- `problem::OptimizationProblem`: The optimization problem to solve
- `algorithm::GreyWolfOptimizer`: The GWO algorithm configuration

# Returns
- `OptimizationResult`: The optimization result containing the best solution found
"""
function optimize(problem::OptimizationProblem, algorithm::GreyWolfOptimizer)
    # Extract problem parameters
    dimensions = problem.dimensions
    bounds = problem.bounds
    objective_function = problem.objective_function

    # Extract algorithm parameters
    population_size = algorithm.population_size
    max_iterations = algorithm.max_iterations
    a_decrease_factor = algorithm.a_decrease_factor

    # Initialize the wolf pack (population)
    population = initialize_population(population_size, dimensions, bounds)

    # Evaluate the fitness of each wolf
    fitness = [objective_function(wolf) for wolf in population]

    # Initialize iteration counter and best solution tracking
    iteration = 1
    evaluations = population_size

    # Initialize alpha, beta, and delta wolves
    alpha_pos, beta_pos, delta_pos = initialize_leaders(population, fitness)
    alpha_score = minimum(fitness)
    beta_score = alpha_score
    delta_score = alpha_score

    # Initialize convergence tracking
    convergence_curve = zeros(max_iterations)

    # Start the main loop
    while iteration <= max_iterations
        # Update the parameter a
        a = a_decrease_factor * (1 - iteration / max_iterations)

        # Update each wolf's position
        for i in 1:population_size
            # Update the position of the current wolf
            population[i] = update_position(
                population[i],
                alpha_pos,
                beta_pos,
                delta_pos,
                a,
                bounds
            )

            # Evaluate the fitness of the updated position
            fitness[i] = objective_function(population[i])
            evaluations += 1

            # Update alpha, beta, and delta wolves if needed
            if fitness[i] < alpha_score
                delta_pos = beta_pos
                delta_score = beta_score
                beta_pos = alpha_pos
                beta_score = alpha_score
                alpha_pos = population[i]
                alpha_score = fitness[i]
            elseif fitness[i] < beta_score
                delta_pos = beta_pos
                delta_score = beta_score
                beta_pos = population[i]
                beta_score = fitness[i]
            elseif fitness[i] < delta_score
                delta_pos = population[i]
                delta_score = fitness[i]
            end
        end

        # Record the best fitness for this iteration
        convergence_curve[iteration] = alpha_score

        # Increment iteration counter
        iteration += 1
    end

    # Return the optimization result
    return OptimizationResult(
        alpha_pos,                # best_position
        alpha_score,              # best_fitness
        convergence_curve,        # convergence_curve
        max_iterations,           # iterations
        evaluations,              # evaluations
        "Grey Wolf Optimizer"     # algorithm_name
    )
end

"""
    initialize_population(population_size, dimensions, bounds)

Initialize the wolf pack with random positions within the bounds.

# Arguments
- `population_size::Int`: Number of wolves in the pack
- `dimensions::Int`: Number of dimensions in the search space
- `bounds::Vector{Tuple{Float64, Float64}}`: Bounds for each dimension

# Returns
- `Vector{Vector{Float64}}`: Initial positions of the wolves
"""
function initialize_population(population_size, dimensions, bounds)
    population = Vector{Vector{Float64}}(undef, population_size)

    for i in 1:population_size
        wolf = Vector{Float64}(undef, dimensions)

        for j in 1:dimensions
            lower_bound, upper_bound = bounds[j]
            wolf[j] = lower_bound + rand() * (upper_bound - lower_bound)
        end

        population[i] = wolf
    end

    return population
end

"""
    initialize_leaders(population, fitness)

Initialize the alpha, beta, and delta wolves based on fitness values.

# Arguments
- `population::Vector{Vector{Float64}}`: The wolf pack
- `fitness::Vector{Float64}`: Fitness values for each wolf

# Returns
- `Tuple{Vector{Float64}, Vector{Float64}, Vector{Float64}}`: Positions of alpha, beta, and delta wolves
"""
function initialize_leaders(population, fitness)
    # Create indices sorted by fitness (ascending)
    sorted_indices = sortperm(fitness)

    # Select the top three wolves as alpha, beta, and delta
    alpha_pos = copy(population[sorted_indices[1]])
    beta_pos = copy(population[sorted_indices[2]])
    delta_pos = copy(population[sorted_indices[3]])

    return alpha_pos, beta_pos, delta_pos
end

"""
    update_position(wolf, alpha_pos, beta_pos, delta_pos, a, bounds)

Update the position of a wolf based on the positions of alpha, beta, and delta wolves.

# Arguments
- `wolf::Vector{Float64}`: Current position of the wolf
- `alpha_pos::Vector{Float64}`: Position of the alpha wolf
- `beta_pos::Vector{Float64}`: Position of the beta wolf
- `delta_pos::Vector{Float64}`: Position of the delta wolf
- `a::Float64`: Parameter controlling the exploration/exploitation balance
- `bounds::Vector{Tuple{Float64, Float64}}`: Bounds for each dimension

# Returns
- `Vector{Float64}`: Updated position of the wolf
"""
function update_position(wolf, alpha_pos, beta_pos, delta_pos, a, bounds)
    dimensions = length(wolf)
    new_position = zeros(dimensions)

    for j in 1:dimensions
        # Calculate r1 and r2 (random vectors)
        r1 = rand()
        r2 = rand()

        # Calculate A and C for alpha
        A1 = 2 * a * r1 - a
        C1 = 2 * r2

        # Calculate distance from alpha
        D_alpha = abs(C1 * alpha_pos[j] - wolf[j])
        X1 = alpha_pos[j] - A1 * D_alpha

        # Calculate r1 and r2 for beta
        r1 = rand()
        r2 = rand()

        # Calculate A and C for beta
        A2 = 2 * a * r1 - a
        C2 = 2 * r2

        # Calculate distance from beta
        D_beta = abs(C2 * beta_pos[j] - wolf[j])
        X2 = beta_pos[j] - A2 * D_beta

        # Calculate r1 and r2 for delta
        r1 = rand()
        r2 = rand()

        # Calculate A and C for delta
        A3 = 2 * a * r1 - a
        C3 = 2 * r2

        # Calculate distance from delta
        D_delta = abs(C3 * delta_pos[j] - wolf[j])
        X3 = delta_pos[j] - A3 * D_delta

        # Update position based on alpha, beta, and delta
        new_position[j] = (X1 + X2 + X3) / 3

        # Apply bounds
        lower_bound, upper_bound = bounds[j]
        new_position[j] = clamp(new_position[j], lower_bound, upper_bound)
    end

    return new_position
end

end # module GWO
