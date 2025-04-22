module DE

export DifferentialEvolution, optimize

using Random
using Statistics
using ..SwarmBase

"""
    DifferentialEvolution <: AbstractSwarmAlgorithm

Differential Evolution optimizer.

# Fields
- `population_size::Int`: Size of the population
- `max_iterations::Int`: Maximum number of iterations
- `F::Float64`: Differential weight
- `CR::Float64`: Crossover probability
- `strategy::Symbol`: Mutation strategy
"""
struct DifferentialEvolution <: AbstractSwarmAlgorithm
    population_size::Int
    max_iterations::Int
    F::Float64
    CR::Float64
    strategy::Symbol

    function DifferentialEvolution(;
        population_size::Int = 50,
        max_iterations::Int = 100,
        F::Float64 = 0.8,
        CR::Float64 = 0.9,
        strategy::Symbol = :rand_1_bin
    )
        # Parameter validation
        population_size > 0 || throw(ArgumentError("Population size must be positive"))
        max_iterations > 0 || throw(ArgumentError("Maximum iterations must be positive"))
        0.0 < F <= 2.0 || throw(ArgumentError("F must be in (0, 2]"))
        0.0 <= CR <= 1.0 || throw(ArgumentError("CR must be in [0, 1]"))
        strategy in [:rand_1_bin, :best_1_bin, :rand_2_bin, :best_2_bin] ||
            throw(ArgumentError("Unknown strategy: $strategy"))

        new(population_size, max_iterations, F, CR, strategy)
    end
end

"""
    optimize(problem::OptimizationProblem, algorithm::DifferentialEvolution)

Optimize the given problem using Differential Evolution.

# Arguments
- `problem::OptimizationProblem`: The optimization problem to solve
- `algorithm::DifferentialEvolution`: The DE algorithm configuration

# Returns
- `OptimizationResult`: The optimization result containing the best solution found
"""
function optimize(problem::OptimizationProblem, algorithm::DifferentialEvolution; callback=nothing)
    # Initialize parameters
    pop_size = algorithm.population_size
    max_iter = algorithm.max_iterations
    F = algorithm.F
    CR = algorithm.CR
    strategy = algorithm.strategy
    dim = problem.dimensions
    bounds = problem.bounds
    obj_func = problem.objective_function
    is_min = problem.is_minimization

    # Initialize population
    population = zeros(pop_size, dim)
    fitness = fill(is_min ? Inf : -Inf, pop_size)

    # Initialize best solution
    best_idx = 1
    best_position = zeros(dim)
    best_fitness = is_min ? Inf : -Inf

    # Initialize convergence curve
    convergence_curve = zeros(max_iter)

    # Function evaluation counter
    evaluations = 0

    # Initialize population with random positions
    for i in 1:pop_size
        for j in 1:dim
            min_val, max_val = bounds[j]
            population[i, j] = min_val + rand() * (max_val - min_val)
        end

        # Evaluate fitness
        fitness[i] = obj_func(population[i, :])
        evaluations += 1

        # Update best solution if needed
        if (is_min && fitness[i] < best_fitness) || (!is_min && fitness[i] > best_fitness)
            best_fitness = fitness[i]
            best_position = population[i, :]
            best_idx = i
        end
    end

    # Main DE loop
    for iter in 1:max_iter
        for i in 1:pop_size
            # Create trial vector based on strategy
            trial = create_trial_vector(population, i, best_idx, F, strategy, dim)

            # Perform crossover
            candidate = perform_crossover(population[i, :], trial, CR, dim)

            # Apply bounds
            for j in 1:dim
                min_val, max_val = bounds[j]
                candidate[j] = clamp(candidate[j], min_val, max_val)
            end

            # Evaluate candidate
            candidate_fitness = obj_func(candidate)
            evaluations += 1

            # Selection (replace if better)
            if (is_min && candidate_fitness < fitness[i]) || (!is_min && candidate_fitness > fitness[i])
                population[i, :] = candidate
                fitness[i] = candidate_fitness

                # Update best solution if needed
                if (is_min && candidate_fitness < best_fitness) || (!is_min && candidate_fitness > best_fitness)
                    best_fitness = candidate_fitness
                    best_position = candidate
                    best_idx = i
                end
            end
        end

        # Store best fitness for convergence curve
        convergence_curve[iter] = best_fitness

        # Call callback if provided
        if callback !== nothing
            callback_result = callback(iter, best_position, best_fitness, population)
            if callback_result === false
                # Early termination if callback returns false
                convergence_curve = convergence_curve[1:iter]
                break
            end
        end
    end

    return OptimizationResult(
        best_position,
        best_fitness,
        convergence_curve,
        max_iter,
        evaluations,
        "Differential Evolution",
        success = true,
        message = "Optimization completed successfully"
    )
end

"""
    create_trial_vector(population, i, best_idx, F, strategy, dim)

Create a trial vector using the specified mutation strategy.

# Arguments
- `population`: The current population
- `i`: Index of the current individual
- `best_idx`: Index of the best individual
- `F`: Differential weight
- `strategy`: Mutation strategy
- `dim`: Problem dimensions

# Returns
- Trial vector after mutation
"""
function create_trial_vector(population, i, best_idx, F, strategy, dim)
    pop_size = size(population, 1)
    trial = zeros(dim)

    if strategy == :rand_1_bin
        # Select three random individuals, different from i
        r = randperm(pop_size)
        r = filter(x -> x != i, r)[1:3]  # Get 3 indices != i

        # DE/rand/1 strategy: x_r1 + F * (x_r2 - x_r3)
        trial = population[r[1], :] + F * (population[r[2], :] - population[r[3], :])
    elseif strategy == :best_1_bin
        # Select two random individuals, different from i and best_idx
        r = randperm(pop_size)
        r = filter(x -> x != i && x != best_idx, r)[1:2]  # Get 2 indices != i and != best_idx

        # DE/best/1 strategy: x_best + F * (x_r1 - x_r2)
        trial = population[best_idx, :] + F * (population[r[1], :] - population[r[2], :])
    elseif strategy == :rand_2_bin
        # Select five random individuals, different from i
        r = randperm(pop_size)
        r = filter(x -> x != i, r)[1:5]  # Get 5 indices != i

        # DE/rand/2 strategy: x_r1 + F * (x_r2 - x_r3) + F * (x_r4 - x_r5)
        trial = population[r[1], :] + F * (population[r[2], :] - population[r[3], :]) +
                                      F * (population[r[4], :] - population[r[5], :])
    elseif strategy == :best_2_bin
        # Select four random individuals, different from i and best_idx
        r = randperm(pop_size)
        r = filter(x -> x != i && x != best_idx, r)[1:4]  # Get 4 indices != i and != best_idx

        # DE/best/2 strategy: x_best + F * (x_r1 - x_r2) + F * (x_r3 - x_r4)
        trial = population[best_idx, :] + F * (population[r[1], :] - population[r[2], :]) +
                                         F * (population[r[3], :] - population[r[4], :])
    end

    return trial
end

"""
    perform_crossover(target, trial, CR, dim)

Perform binomial crossover between target and trial vectors.

# Arguments
- `target`: The target vector
- `trial`: The trial vector
- `CR`: Crossover probability
- `dim`: Problem dimensions

# Returns
- Candidate vector after crossover
"""
function perform_crossover(target, trial, CR, dim)
    candidate = copy(target)
    j_rand = rand(1:dim)  # Ensure at least one component from trial

    for j in 1:dim
        if rand() <= CR || j == j_rand
            candidate[j] = trial[j]
        end
    end

    return candidate
end

end # module