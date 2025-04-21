"""
Genetic Algorithm (GA) implementation.

Genetic Algorithm is a metaheuristic inspired by the process of natural selection.
It is commonly used to generate high-quality solutions to optimization and search problems
by relying on biologically inspired operators such as mutation, crossover, and selection.

This implementation focuses on continuous domain optimization.

References:
- Holland, J. H. (1992). Adaptation in natural and artificial systems: an introductory
  analysis with applications to biology, control, and artificial intelligence.
  MIT press.
"""
module GA

export GeneticAlgorithm, optimize

using Random
using Statistics
using ..SwarmBase

"""
    GeneticAlgorithm

Genetic Algorithm configuration.

# Fields
- `population_size::Int`: Number of individuals in the population
- `max_generations::Int`: Maximum number of generations
- `crossover_rate::Float64`: Probability of crossover
- `mutation_rate::Float64`: Probability of mutation
- `selection_pressure::Float64`: Selection pressure (tournament size as fraction of population)
- `elitism_count::Int`: Number of best individuals to preserve in each generation
"""
struct GeneticAlgorithm <: AbstractSwarmAlgorithm
    population_size::Int
    max_generations::Int
    crossover_rate::Float64
    mutation_rate::Float64
    selection_pressure::Float64
    elitism_count::Int

    function GeneticAlgorithm(;
        population_size::Int = 100,
        max_generations::Int = 100,
        crossover_rate::Float64 = 0.8,
        mutation_rate::Float64 = 0.1,
        selection_pressure::Float64 = 0.2,
        elitism_count::Int = 2
    )
        # Parameter validation
        population_size > 0 || throw(ArgumentError("Population size must be positive"))
        max_generations > 0 || throw(ArgumentError("Maximum generations must be positive"))
        0 <= crossover_rate <= 1 || throw(ArgumentError("Crossover rate must be between 0 and 1"))
        0 <= mutation_rate <= 1 || throw(ArgumentError("Mutation rate must be between 0 and 1"))
        0 < selection_pressure <= 1 || throw(ArgumentError("Selection pressure must be between 0 and 1"))
        0 <= elitism_count < population_size || throw(ArgumentError("Elitism count must be less than population size"))

        new(population_size, max_generations, crossover_rate, mutation_rate, selection_pressure, elitism_count)
    end
end

"""
    optimize(problem::OptimizationProblem, algorithm::GeneticAlgorithm)

Optimize the given problem using the Genetic Algorithm.

# Arguments
- `problem::OptimizationProblem`: The optimization problem to solve
- `algorithm::GeneticAlgorithm`: The GA algorithm configuration

# Returns
- `OptimizationResult`: The optimization result containing the best solution found
"""
function optimize(problem::OptimizationProblem, algorithm::GeneticAlgorithm)
    # Extract problem parameters
    dimensions = problem.dimensions
    bounds = problem.bounds
    objective_function = problem.objective_function

    # Extract algorithm parameters
    population_size = algorithm.population_size
    max_generations = algorithm.max_generations
    crossover_rate = algorithm.crossover_rate
    mutation_rate = algorithm.mutation_rate
    selection_pressure = algorithm.selection_pressure
    elitism_count = algorithm.elitism_count

    # Initialize the population
    population = initialize_population(population_size, dimensions, bounds)

    # Evaluate the fitness of each individual
    fitness = [objective_function(individual) for individual in population]

    # Initialize generation counter and evaluations
    generation = 1
    evaluations = population_size

    # Initialize best solution tracking
    best_idx = argmin(fitness)
    best_individual = copy(population[best_idx])
    best_fitness = fitness[best_idx]

    # Initialize convergence tracking
    convergence_curve = zeros(max_generations)

    # Calculate tournament size
    tournament_size = max(2, round(Int, selection_pressure * population_size))

    # Start the main loop
    while generation <= max_generations
        # Create new population
        new_population = similar(population)

        # Elitism: Copy the best individuals to the new population
        sorted_indices = sortperm(fitness)
        for i in 1:elitism_count
            new_population[i] = copy(population[sorted_indices[i]])
        end

        # Fill the rest of the new population
        for i in (elitism_count+1):population_size
            # Selection
            parent1_idx = tournament_selection(fitness, tournament_size)
            parent2_idx = tournament_selection(fitness, tournament_size)

            # Ensure different parents
            while parent2_idx == parent1_idx
                parent2_idx = tournament_selection(fitness, tournament_size)
            end

            parent1 = population[parent1_idx]
            parent2 = population[parent2_idx]

            # Crossover
            child = if rand() < crossover_rate
                crossover(parent1, parent2)
            else
                copy(rand() < 0.5 ? parent1 : parent2)
            end

            # Mutation
            mutate!(child, mutation_rate, bounds)

            # Add to new population
            new_population[i] = child
        end

        # Replace old population with new population
        population = new_population

        # Evaluate fitness of new population
        for i in 1:population_size
            fitness[i] = objective_function(population[i])
            evaluations += 1

            # Update best solution if needed
            if fitness[i] < best_fitness
                best_individual = copy(population[i])
                best_fitness = fitness[i]
            end
        end

        # Record the best fitness for this generation
        convergence_curve[generation] = best_fitness

        # Increment generation counter
        generation += 1
    end

    # Return the optimization result
    return OptimizationResult(
        best_individual,       # best_position
        best_fitness,          # best_fitness
        convergence_curve,     # convergence_curve
        max_generations,       # iterations
        evaluations,           # evaluations
        "Genetic Algorithm"    # algorithm_name
    )
end

"""
    initialize_population(population_size, dimensions, bounds)

Initialize the population with random individuals within the bounds.

# Arguments
- `population_size::Int`: Number of individuals in the population
- `dimensions::Int`: Number of dimensions in the search space
- `bounds::Vector{Tuple{Float64, Float64}}`: Bounds for each dimension

# Returns
- `Vector{Vector{Float64}}`: Initial population
"""
function initialize_population(population_size, dimensions, bounds)
    population = Vector{Vector{Float64}}(undef, population_size)

    for i in 1:population_size
        individual = Vector{Float64}(undef, dimensions)

        for j in 1:dimensions
            lower_bound, upper_bound = bounds[j]
            individual[j] = lower_bound + rand() * (upper_bound - lower_bound)
        end

        population[i] = individual
    end

    return population
end

"""
    tournament_selection(fitness, tournament_size)

Select an individual using tournament selection.

# Arguments
- `fitness::Vector{Float64}`: Fitness values for each individual
- `tournament_size::Int`: Number of individuals in each tournament

# Returns
- `Int`: Index of the selected individual
"""
function tournament_selection(fitness, tournament_size)
    population_size = length(fitness)

    # Randomly select tournament_size individuals
    tournament_indices = rand(1:population_size, tournament_size)

    # Find the best individual in the tournament
    best_idx = tournament_indices[1]
    best_fitness = fitness[best_idx]

    for idx in tournament_indices[2:end]
        if fitness[idx] < best_fitness
            best_idx = idx
            best_fitness = fitness[idx]
        end
    end

    return best_idx
end

"""
    crossover(parent1, parent2)

Perform crossover between two parents to create a child.

# Arguments
- `parent1::Vector{Float64}`: First parent
- `parent2::Vector{Float64}`: Second parent

# Returns
- `Vector{Float64}`: Child created from the parents
"""
function crossover(parent1, parent2)
    dimensions = length(parent1)
    child = Vector{Float64}(undef, dimensions)

    # Simulated binary crossover (SBX)
    eta = 15.0  # Distribution index

    for j in 1:dimensions
        # Check if the parents are different
        if abs(parent1[j] - parent2[j]) > 1e-10
            # Ensure parent1 < parent2 for simplicity
            if parent1[j] > parent2[j]
                parent1[j], parent2[j] = parent2[j], parent1[j]
            end

            # Calculate child value using SBX
            y1, y2 = parent1[j], parent2[j]
            r = rand()

            if r <= 0.5
                beta = (2.0 * r)^(1.0 / (eta + 1.0))
            else
                beta = (1.0 / (2.0 * (1.0 - r)))^(1.0 / (eta + 1.0))
            end

            # Create child
            child[j] = 0.5 * ((1.0 + beta) * y1 + (1.0 - beta) * y2)
        else
            # If parents are the same, child is the same
            child[j] = parent1[j]
        end
    end

    return child
end

"""
    mutate!(individual, mutation_rate, bounds)

Mutate an individual in place.

# Arguments
- `individual::Vector{Float64}`: Individual to mutate
- `mutation_rate::Float64`: Probability of mutation for each gene
- `bounds::Vector{Tuple{Float64, Float64}}`: Bounds for each dimension

# Returns
- `Vector{Float64}`: Mutated individual (same as input, modified in place)
"""
function mutate!(individual, mutation_rate, bounds)
    dimensions = length(individual)

    for j in 1:dimensions
        # Decide whether to mutate this gene
        if rand() < mutation_rate
            # Polynomial mutation
            eta_m = 20.0  # Distribution index
            lower_bound, upper_bound = bounds[j]

            # Calculate delta
            r = rand()
            delta = if r < 0.5
                (2.0 * r)^(1.0 / (eta_m + 1.0)) - 1.0
            else
                1.0 - (2.0 * (1.0 - r))^(1.0 / (eta_m + 1.0))
            end

            # Apply mutation
            individual[j] += delta * (upper_bound - lower_bound)

            # Apply bounds
            individual[j] = clamp(individual[j], lower_bound, upper_bound)
        end
    end

    return individual
end

end # module GA
