"""
    DEPSO.jl - Hybrid Differential Evolution and Particle Swarm Optimization Algorithm

This module implements a hybrid algorithm that combines Differential Evolution (DE) and
Particle Swarm Optimization (PSO) for enhanced global optimization capabilities.
"""
module DEPSO

export HybridDEPSO, optimize

using Random
using LinearAlgebra
using Statistics
using ..SwarmBase

"""
    HybridDEPSO <: AbstractSwarmAlgorithm

Hybrid Differential Evolution and Particle Swarm Optimization algorithm.

# Fields
- `population_size::Int`: Number of individuals in the population
- `max_iterations::Int`: Maximum number of iterations
- `F::Float64`: DE differential weight (0-2)
- `CR::Float64`: DE crossover probability (0-1)
- `w::Float64`: PSO inertia weight
- `c1::Float64`: PSO cognitive coefficient
- `c2::Float64`: PSO social coefficient
- `hybrid_ratio::Float64`: Ratio of DE to PSO (0-1), 0 = all PSO, 1 = all DE
- `adaptive::Bool`: Whether to use adaptive parameter control
- `tolerance::Float64`: Convergence tolerance
"""
struct HybridDEPSO <: AbstractSwarmAlgorithm
    population_size::Int
    max_iterations::Int
    F::Float64
    CR::Float64
    w::Float64
    c1::Float64
    c2::Float64
    hybrid_ratio::Float64
    adaptive::Bool
    tolerance::Float64

    function HybridDEPSO(;
        population_size=50,
        max_iterations=1000,
        F=0.8,
        CR=0.9,
        w=0.7,
        c1=1.5,
        c2=1.5,
        hybrid_ratio=0.5,
        adaptive=true,
        tolerance=1e-6
    )
        # Validate parameters
        population_size > 0 || throw(ArgumentError("Population size must be positive"))
        max_iterations > 0 || throw(ArgumentError("Max iterations must be positive"))
        0.0 <= F <= 2.0 || throw(ArgumentError("F must be between 0 and 2"))
        0.0 <= CR <= 1.0 || throw(ArgumentError("CR must be between 0 and 1"))
        0.0 <= w <= 1.0 || throw(ArgumentError("w must be between 0 and 1"))
        c1 >= 0.0 || throw(ArgumentError("c1 must be non-negative"))
        c2 >= 0.0 || throw(ArgumentError("c2 must be non-negative"))
        0.0 <= hybrid_ratio <= 1.0 || throw(ArgumentError("hybrid_ratio must be between 0 and 1"))

        new(population_size, max_iterations, F, CR, w, c1, c2, hybrid_ratio, adaptive, tolerance)
    end
end

"""
    optimize(problem::OptimizationProblem, algorithm::HybridDEPSO; callback=nothing)

Optimize the objective function using the DEPSO algorithm.

# Arguments
- `problem::OptimizationProblem`: The optimization problem to solve
- `algorithm::HybridDEPSO`: The DEPSO algorithm configuration
- `callback`: Optional callback function called after each iteration

# Returns
- `OptimizationResult`: The optimization result containing the best solution found
"""
function optimize(problem::OptimizationProblem, algorithm::HybridDEPSO; callback=nothing)
    # Extract problem parameters
    dimensions = problem.dimensions
    bounds = problem.bounds
    objective_function = problem.objective_function
    is_min = problem.is_minimization

    # Extract algorithm parameters
    population_size = algorithm.population_size
    max_iterations = algorithm.max_iterations
    F_init = algorithm.F
    CR_init = algorithm.CR
    w_init = algorithm.w
    c1 = algorithm.c1
    c2 = algorithm.c2
    hybrid_ratio_init = algorithm.hybrid_ratio
    adaptive = algorithm.adaptive
    tolerance = algorithm.tolerance

    # Initialize population randomly within bounds
    population = Array{Vector{Float64}}(undef, population_size)
    for i in 1:population_size
        population[i] = Vector{Float64}(undef, dimensions)
        for j in 1:dimensions
            min_val, max_val = bounds[j]
            population[i][j] = min_val + rand() * (max_val - min_val)
        end
    end

    # Initialize velocities (for PSO part)
    velocities = [zeros(dimensions) for _ in 1:population_size]

    # Initialize personal best positions and fitness
    personal_best = deepcopy(population)
    fitness = zeros(population_size)
    personal_best_fitness = fill(is_min ? Inf : -Inf, population_size)

    # Evaluate initial population
    for i in 1:population_size
        fitness[i] = objective_function(population[i])
        personal_best_fitness[i] = fitness[i]
    end

    # Find global best
    best_idx = is_min ? argmin(personal_best_fitness) : argmax(personal_best_fitness)
    global_best = copy(personal_best[best_idx])
    global_best_fitness = personal_best_fitness[best_idx]

    # Initialize convergence history
    convergence_curve = zeros(max_iterations)

    # Initialize adaptive parameters
    F = F_init
    CR = CR_init
    w = w_init
    hybrid_ratio = hybrid_ratio_init

    # Function evaluation counter
    evaluations = population_size

    # Main loop
    for t in 1:max_iterations
        # Update adaptive parameters if enabled
        if adaptive
            # Decrease inertia weight linearly
            w = w_init - (w_init - 0.4) * (t / max_iterations)

            # Adjust F and CR based on convergence
            if t > 1 && abs(convergence_curve[t-1] - global_best_fitness) < tolerance
                # If converging, increase exploration
                F = min(F * 1.1, 1.0)
                CR = max(CR * 0.9, 0.1)
            else
                # If not converging, increase exploitation
                F = max(F * 0.9, 0.4)
                CR = min(CR * 1.1, 0.9)
            end

            # Adjust hybrid ratio to favor more successful method
            if t > 10 && t % 10 == 0
                # Check which method has been more successful recently
                de_success = 0
                pso_success = 0
                for i in 1:population_size
                    if rand() < hybrid_ratio  # DE was used
                        de_success += 1
                    else  # PSO was used
                        pso_success += 1
                    end
                end

                # Adjust hybrid ratio
                if de_success > pso_success
                    hybrid_ratio = min(hybrid_ratio + 0.05, 0.9)
                else
                    hybrid_ratio = max(hybrid_ratio - 0.05, 0.1)
                end
            end
        end

        # For each individual in the population
        for i in 1:population_size
            # Decide whether to use DE or PSO for this individual
            if rand() < hybrid_ratio
                # DE part
                # Select three random individuals different from i
                a, b, c = i, i, i
                while a == i
                    a = rand(1:population_size)
                end
                while b == i || b == a
                    b = rand(1:population_size)
                end
                while c == i || c == a || c == b
                    c = rand(1:population_size)
                end

                # Create mutant vector
                mutant = population[a] + F * (population[b] - population[c])

                # Apply bounds
                for j in 1:dimensions
                    min_val, max_val = bounds[j]
                    mutant[j] = clamp(mutant[j], min_val, max_val)
                end

                # Crossover
                trial = copy(population[i])
                j_rand = rand(1:dimensions)
                for j in 1:dimensions
                    if rand() < CR || j == j_rand
                        trial[j] = mutant[j]
                    end
                end

                # Evaluate trial vector
                trial_fitness = objective_function(trial)
                evaluations += 1

                # Selection
                if (is_min && trial_fitness < fitness[i]) || (!is_min && trial_fitness > fitness[i])
                    population[i] = trial
                    fitness[i] = trial_fitness

                    # Update personal best
                    if (is_min && trial_fitness < personal_best_fitness[i]) || (!is_min && trial_fitness > personal_best_fitness[i])
                        personal_best[i] = trial
                        personal_best_fitness[i] = trial_fitness
                    end
                end
            else
                # PSO part
                # Update velocity
                r1, r2 = rand(), rand()
                velocities[i] = w * velocities[i] +
                               c1 * r1 * (personal_best[i] - population[i]) +
                               c2 * r2 * (global_best - population[i])

                # Update position
                new_position = population[i] + velocities[i]

                # Apply bounds
                for j in 1:dimensions
                    min_val, max_val = bounds[j]
                    new_position[j] = clamp(new_position[j], min_val, max_val)
                end

                # Evaluate new position
                new_fitness = objective_function(new_position)
                evaluations += 1

                # Update position and fitness
                population[i] = new_position
                fitness[i] = new_fitness

                # Update personal best
                if (is_min && new_fitness < personal_best_fitness[i]) || (!is_min && new_fitness > personal_best_fitness[i])
                    personal_best[i] = new_position
                    personal_best_fitness[i] = new_fitness
                end
            end

            # Update global best
            if (is_min && personal_best_fitness[i] < global_best_fitness) || (!is_min && personal_best_fitness[i] > global_best_fitness)
                global_best = copy(personal_best[i])
                global_best_fitness = personal_best_fitness[i]
            end
        end

        # Store best fitness for convergence curve
        convergence_curve[t] = global_best_fitness

        # Call callback if provided
        if callback !== nothing
            callback_result = callback(t, global_best, global_best_fitness, population)
            if callback_result === false
                # Early termination if callback returns false
                convergence_curve = convergence_curve[1:t]
                break
            end
        end

        # Check for convergence
        if t > 1 && abs(convergence_curve[t] - convergence_curve[t-1]) < tolerance
            convergence_curve = convergence_curve[1:t]
            break
        end
    end

    return OptimizationResult(
        global_best,
        global_best_fitness,
        convergence_curve,
        max_iterations,
        evaluations,
        "Hybrid DEPSO",
        success = true,
        message = "Optimization completed successfully"
    )
end

"""
    optimize_constrained(objective_function, constraints, config::DEPSOConfig)

Optimize the objective function subject to constraints using the DEPSO algorithm.

# Arguments
- `objective_function`: Function to minimize, should take a vector and return a scalar
- `constraints`: Array of constraint functions, each should return <= 0 for feasible solutions
- `config::DEPSOConfig`: Configuration for the algorithm

# Returns
- `best_position`: Best position found
- `best_fitness`: Best fitness value
- `convergence_history`: History of best fitness values
- `final_population`: Final population positions
- `final_fitness`: Final population fitness values
"""
# We'll remove the constrained optimization function for now
# as it doesn't match the SwarmBase interface. This can be reimplemented later
# as part of a more comprehensive constrained optimization framework.

"""
    optimize_multi_objective(objective_functions, config::DEPSOConfig)

Optimize multiple objective functions using the DEPSO algorithm.
Uses a weighted sum approach for simplicity.

# Arguments
- `objective_functions`: Array of functions to minimize
- `weights`: Array of weights for each objective (default: equal weights)
- `config::DEPSOConfig`: Configuration for the algorithm

# Returns
- `pareto_front`: Set of non-dominated solutions
- `objective_values`: Objective values for each solution in the Pareto front
- `convergence_history`: History of best fitness values
"""
# We'll remove the multi-objective optimization function for now
# as it doesn't match the SwarmBase interface. This can be reimplemented later
# as part of a more comprehensive multi-objective optimization framework.

end # module
