"""
    DEPSO.jl - Hybrid Differential Evolution and Particle Swarm Optimization Algorithm

This module implements a hybrid algorithm that combines Differential Evolution (DE) and
Particle Swarm Optimization (PSO) for enhanced global optimization capabilities.
"""
module DEPSO

export optimize, DEPSOConfig

using Random
using LinearAlgebra
using Statistics
using ..SwarmBase

"""
    DEPSOConfig

Configuration for the DEPSO algorithm.

# Fields
- `population_size::Int`: Number of individuals in the population
- `max_iterations::Int`: Maximum number of iterations
- `dimensions::Int`: Number of dimensions in the search space
- `bounds::Matrix{Float64}`: Bounds for each dimension, shape (dimensions, 2)
- `F::Float64`: DE differential weight (0-2)
- `CR::Float64`: DE crossover probability (0-1)
- `w::Float64`: PSO inertia weight
- `c1::Float64`: PSO cognitive coefficient
- `c2::Float64`: PSO social coefficient
- `hybrid_ratio::Float64`: Ratio of DE to PSO (0-1), 0 = all PSO, 1 = all DE
- `adaptive::Bool`: Whether to use adaptive parameter control
- `tolerance::Float64`: Convergence tolerance
"""
struct DEPSOConfig
    population_size::Int
    max_iterations::Int
    dimensions::Int
    bounds::Matrix{Float64}
    F::Float64
    CR::Float64
    w::Float64
    c1::Float64
    c2::Float64
    hybrid_ratio::Float64
    adaptive::Bool
    tolerance::Float64

    function DEPSOConfig(;
        population_size=50,
        max_iterations=1000,
        dimensions=10,
        bounds=ones(dimensions, 2) .* [-100 100],
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
        @assert population_size > 0 "Population size must be positive"
        @assert max_iterations > 0 "Max iterations must be positive"
        @assert dimensions > 0 "Dimensions must be positive"
        @assert size(bounds, 1) == dimensions "Bounds must match dimensions"
        @assert 0.0 <= F <= 2.0 "F must be between 0 and 2"
        @assert 0.0 <= CR <= 1.0 "CR must be between 0 and 1"
        @assert 0.0 <= w <= 1.0 "w must be between 0 and 1"
        @assert c1 >= 0.0 "c1 must be non-negative"
        @assert c2 >= 0.0 "c2 must be non-negative"
        @assert 0.0 <= hybrid_ratio <= 1.0 "hybrid_ratio must be between 0 and 1"

        new(population_size, max_iterations, dimensions, bounds,
            F, CR, w, c1, c2, hybrid_ratio, adaptive, tolerance)
    end
end

"""
    optimize(objective_function, config::DEPSOConfig)

Optimize the objective function using the DEPSO algorithm.

# Arguments
- `objective_function`: Function to minimize, should take a vector and return a scalar
- `config::DEPSOConfig`: Configuration for the algorithm

# Returns
- `best_position`: Best position found
- `best_fitness`: Best fitness value
- `convergence_history`: History of best fitness values
- `final_population`: Final population positions
- `final_fitness`: Final population fitness values
"""
function optimize(objective_function, config::DEPSOConfig)
    # Initialize population randomly within bounds
    population = rand(config.population_size, config.dimensions)

    # Scale to bounds
    for i in 1:config.dimensions
        min_val, max_val = config.bounds[i, 1], config.bounds[i, 2]
        population[:, i] = min_val .+ population[:, i] .* (max_val - min_val)
    end

    # Initialize velocities (for PSO part)
    velocities = zeros(config.population_size, config.dimensions)

    # Initialize personal best positions and fitness
    personal_best = copy(population)
    fitness = zeros(config.population_size)
    personal_best_fitness = fill(Inf, config.population_size)

    # Evaluate initial population
    for i in 1:config.population_size
        fitness[i] = objective_function(population[i, :])
        personal_best_fitness[i] = fitness[i]
    end

    # Find global best
    best_idx = argmin(personal_best_fitness)
    global_best = personal_best[best_idx, :]
    global_best_fitness = personal_best_fitness[best_idx]

    # Initialize convergence history
    convergence_history = zeros(config.max_iterations)

    # Initialize adaptive parameters
    F = config.F
    CR = config.CR
    w = config.w
    c1 = config.c1
    c2 = config.c2
    hybrid_ratio = config.hybrid_ratio

    # Main loop
    for t in 1:config.max_iterations
        # Update adaptive parameters if enabled
        if config.adaptive
            # Decrease inertia weight linearly
            w = config.w - (config.w - 0.4) * (t / config.max_iterations)

            # Adjust F and CR based on convergence
            if t > 1 && abs(convergence_history[t-1] - global_best_fitness) < config.tolerance
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
                for i in 1:config.population_size
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
        for i in 1:config.population_size
            # Decide whether to use DE or PSO for this individual
            if rand() < hybrid_ratio
                # DE part
                # Select three random individuals different from i
                a, b, c = i, i, i
                while a == i
                    a = rand(1:config.population_size)
                end
                while b == i || b == a
                    b = rand(1:config.population_size)
                end
                while c == i || c == a || c == b
                    c = rand(1:config.population_size)
                end

                # Create mutant vector
                mutant = population[a, :] + F * (population[b, :] - population[c, :])

                # Apply bounds
                for j in 1:config.dimensions
                    mutant[j] = clamp(mutant[j], config.bounds[j, 1], config.bounds[j, 2])
                end

                # Crossover
                trial = copy(population[i, :])
                j_rand = rand(1:config.dimensions)
                for j in 1:config.dimensions
                    if rand() < CR || j == j_rand
                        trial[j] = mutant[j]
                    end
                end

                # Evaluate trial vector
                trial_fitness = objective_function(trial)

                # Selection
                if trial_fitness < fitness[i]
                    population[i, :] = trial
                    fitness[i] = trial_fitness

                    # Update personal best
                    if trial_fitness < personal_best_fitness[i]
                        personal_best[i, :] = trial
                        personal_best_fitness[i] = trial_fitness
                    end
                end
            else
                # PSO part
                # Update velocity
                r1, r2 = rand(), rand()
                velocities[i, :] = w * velocities[i, :] +
                                  c1 * r1 * (personal_best[i, :] - population[i, :]) +
                                  c2 * r2 * (global_best - population[i, :])

                # Update position
                new_position = population[i, :] + velocities[i, :]

                # Apply bounds
                for j in 1:config.dimensions
                    new_position[j] = clamp(new_position[j], config.bounds[j, 1], config.bounds[j, 2])
                end

                # Evaluate new position
                new_fitness = objective_function(new_position)

                # Update position and fitness
                population[i, :] = new_position
                fitness[i] = new_fitness

                # Update personal best
                if new_fitness < personal_best_fitness[i]
                    personal_best[i, :] = new_position
                    personal_best_fitness[i] = new_fitness
                end
            end

            # Update global best
            if personal_best_fitness[i] < global_best_fitness
                global_best = personal_best[i, :]
                global_best_fitness = personal_best_fitness[i]
            end
        end

        # Store best fitness for convergence history
        convergence_history[t] = global_best_fitness

        # Check for convergence
        if t > 1 && abs(convergence_history[t] - convergence_history[t-1]) < config.tolerance
            convergence_history = convergence_history[1:t]
            break
        end
    end

    return Dict(
        "best_position" => global_best,
        "best_fitness" => global_best_fitness,
        "convergence_history" => convergence_history,
        "final_population" => population,
        "final_fitness" => fitness,
        "iterations" => length(convergence_history)
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
function optimize_constrained(objective_function, constraints, config::DEPSOConfig)
    # Define penalty function to handle constraints
    function penalty_function(x)
        base_fitness = objective_function(x)
        penalty = 0.0

        for constraint in constraints
            violation = constraint(x)
            if violation > 0
                penalty += 1000.0 * violation^2  # Quadratic penalty
            end
        end

        return base_fitness + penalty
    end

    # Use the standard optimize function with the penalty function
    return optimize(penalty_function, config)
end

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
function optimize_multi_objective(objective_functions, config::DEPSOConfig; weights=nothing)
    num_objectives = length(objective_functions)

    # Set equal weights if not provided
    if isnothing(weights)
        weights = ones(num_objectives) ./ num_objectives
    end

    # Normalize weights
    weights = weights ./ sum(weights)

    # Define aggregated objective function
    function aggregated_objective(x)
        values = [objective_functions[i](x) for i in 1:num_objectives]
        return sum(weights .* values)
    end

    # Run standard optimization
    result = optimize(aggregated_objective, config)

    # Extract Pareto front from final population
    population = result["final_population"]

    # Calculate objective values for each solution
    objective_values = zeros(config.population_size, num_objectives)
    for i in 1:config.population_size
        for j in 1:num_objectives
            objective_values[i, j] = objective_functions[j](population[i, :])
        end
    end

    # Find non-dominated solutions (simple approach)
    is_dominated = falses(config.population_size)
    for i in 1:config.population_size
        for j in 1:config.population_size
            if i != j
                # Check if j dominates i
                if all(objective_values[j, :] .<= objective_values[i, :]) &&
                   any(objective_values[j, :] .< objective_values[i, :])
                    is_dominated[i] = true
                    break
                end
            end
        end
    end

    # Extract Pareto front
    pareto_indices = findall(.!is_dominated)
    pareto_front = population[pareto_indices, :]
    pareto_objective_values = objective_values[pareto_indices, :]

    return Dict(
        "pareto_front" => pareto_front,
        "objective_values" => pareto_objective_values,
        "aggregated_best" => result["best_position"],
        "aggregated_best_fitness" => result["best_fitness"],
        "convergence_history" => result["convergence_history"],
        "iterations" => result["iterations"]
    )
end

end # module
