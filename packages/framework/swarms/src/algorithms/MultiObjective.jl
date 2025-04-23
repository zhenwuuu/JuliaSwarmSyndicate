"""
    MultiObjective.jl - Multi-Objective Optimization Support

This module provides support for multi-objective optimization using various approaches
including weighted sum, epsilon-constraint, and Pareto-based methods.
"""
module MultiObjective

export optimize, ParetoFront, WeightedSum, EpsilonConstraint, NSGA2Config

using Random
using LinearAlgebra
using Statistics

"""
    AbstractMOOMethod

Abstract type for multi-objective optimization methods
"""
abstract type AbstractMOOMethod end

"""
    WeightedSum <: AbstractMOOMethod

Weighted sum approach for multi-objective optimization.

# Fields
- `weights::Vector{Float64}`: Weights for each objective
"""
struct WeightedSum <: AbstractMOOMethod
    weights::Vector{Float64}
    
    function WeightedSum(weights::Vector{Float64})
        # Normalize weights
        normalized = weights ./ sum(weights)
        new(normalized)
    end
    
    # Constructor with equal weights
    WeightedSum(num_objectives::Int) = new(ones(num_objectives) ./ num_objectives)
end

"""
    EpsilonConstraint <: AbstractMOOMethod

Epsilon-constraint method for multi-objective optimization.

# Fields
- `primary_objective::Int`: Index of the primary objective to optimize
- `constraints::Vector{Float64}`: Constraint values for other objectives
"""
struct EpsilonConstraint <: AbstractMOOMethod
    primary_objective::Int
    constraints::Vector{Float64}
    
    function EpsilonConstraint(primary_objective::Int, constraints::Vector{Float64})
        new(primary_objective, constraints)
    end
end

"""
    NSGA2Config <: AbstractMOOMethod

Configuration for NSGA-II algorithm for multi-objective optimization.

# Fields
- `population_size::Int`: Size of the population
- `max_generations::Int`: Maximum number of generations
- `crossover_probability::Float64`: Probability of crossover
- `mutation_probability::Float64`: Probability of mutation
- `tournament_size::Int`: Size of tournament for selection
"""
struct NSGA2Config <: AbstractMOOMethod
    population_size::Int
    max_generations::Int
    crossover_probability::Float64
    mutation_probability::Float64
    tournament_size::Int
    
    function NSGA2Config(;
        population_size=100,
        max_generations=100,
        crossover_probability=0.9,
        mutation_probability=0.1,
        tournament_size=2
    )
        new(population_size, max_generations, crossover_probability, 
            mutation_probability, tournament_size)
    end
end

"""
    ParetoFront

Represents a Pareto front of non-dominated solutions.

# Fields
- `solutions::Matrix{Float64}`: Matrix of solutions, each row is a solution
- `objective_values::Matrix{Float64}`: Matrix of objective values, each row corresponds to a solution
"""
struct ParetoFront
    solutions::Matrix{Float64}
    objective_values::Matrix{Float64}
end

"""
    is_dominated(a::Vector{Float64}, b::Vector{Float64})

Check if solution a is dominated by solution b.
For minimization problems, b dominates a if:
1. b is at least as good as a in all objectives
2. b is strictly better than a in at least one objective

# Arguments
- `a::Vector{Float64}`: Objective values for solution a
- `b::Vector{Float64}`: Objective values for solution b

# Returns
- `Bool`: true if a is dominated by b, false otherwise
"""
function is_dominated(a::Vector{Float64}, b::Vector{Float64})
    # Check if b dominates a (for minimization)
    all_better_or_equal = true
    any_strictly_better = false
    
    for i in 1:length(a)
        if b[i] > a[i]
            all_better_or_equal = false
            break
        elseif b[i] < a[i]
            any_strictly_better = true
        end
    end
    
    return all_better_or_equal && any_strictly_better
end

"""
    find_non_dominated(objective_values::Matrix{Float64})

Find the indices of non-dominated solutions in the population.

# Arguments
- `objective_values::Matrix{Float64}`: Matrix of objective values, each row is a solution

# Returns
- `Vector{Int}`: Indices of non-dominated solutions
"""
function find_non_dominated(objective_values::Matrix{Float64})
    n = size(objective_values, 1)
    is_non_dominated = trues(n)
    
    for i in 1:n
        for j in 1:n
            if i != j && is_non_dominated[i] && is_non_dominated[j]
                if is_dominated(objective_values[i, :], objective_values[j, :])
                    is_non_dominated[i] = false
                    break
                end
            end
        end
    end
    
    return findall(is_non_dominated)
end

"""
    weighted_sum_aggregate(objective_values::Matrix{Float64}, weights::Vector{Float64})

Aggregate multiple objectives using weighted sum approach.

# Arguments
- `objective_values::Matrix{Float64}`: Matrix of objective values
- `weights::Vector{Float64}`: Weights for each objective

# Returns
- `Vector{Float64}`: Aggregated values for each solution
"""
function weighted_sum_aggregate(objective_values::Matrix{Float64}, weights::Vector{Float64})
    return objective_values * weights
end

"""
    epsilon_constraint_aggregate(objective_values::Matrix{Float64}, primary::Int, constraints::Vector{Float64})

Aggregate multiple objectives using epsilon-constraint approach.

# Arguments
- `objective_values::Matrix{Float64}`: Matrix of objective values
- `primary::Int`: Index of primary objective
- `constraints::Vector{Float64}`: Constraint values for other objectives

# Returns
- `Vector{Float64}`: Aggregated values with penalties for constraint violations
"""
function epsilon_constraint_aggregate(objective_values::Matrix{Float64}, primary::Int, constraints::Vector{Float64})
    n = size(objective_values, 1)
    m = size(objective_values, 2)
    
    result = copy(objective_values[:, primary])
    
    # Add penalties for constraint violations
    for i in 1:n
        for j in 1:m
            if j != primary
                constraint_idx = j > primary ? j - 1 : j
                if objective_values[i, j] > constraints[constraint_idx]
                    # Add penalty proportional to violation
                    result[i] += 1000.0 * (objective_values[i, j] - constraints[constraint_idx])^2
                end
            end
        end
    end
    
    return result
end

"""
    optimize(objective_functions, method::AbstractMOOMethod, algorithm, bounds::Matrix{Float64})

Optimize multiple objective functions using the specified method and algorithm.

# Arguments
- `objective_functions`: Array of objective functions
- `method::AbstractMOOMethod`: Multi-objective optimization method
- `algorithm`: Optimization algorithm to use
- `bounds::Matrix{Float64}`: Bounds for decision variables

# Returns
- `ParetoFront`: Pareto front of non-dominated solutions
"""
function optimize(objective_functions, method::WeightedSum, algorithm, bounds::Matrix{Float64})
    # Create aggregated objective function
    function aggregated_objective(x)
        values = [objective_functions[i](x) for i in 1:length(objective_functions)]
        return sum(method.weights .* values)
    end
    
    # Run the optimization algorithm
    result = algorithm.optimize(aggregated_objective, bounds)
    
    # Extract solutions and calculate objective values
    solutions = result["final_population"]
    n = size(solutions, 1)
    m = length(objective_functions)
    
    objective_values = zeros(n, m)
    for i in 1:n
        for j in 1:m
            objective_values[i, j] = objective_functions[j](solutions[i, :])
        end
    end
    
    # Find non-dominated solutions
    non_dominated_indices = find_non_dominated(objective_values)
    
    # Create Pareto front
    pareto_solutions = solutions[non_dominated_indices, :]
    pareto_values = objective_values[non_dominated_indices, :]
    
    return ParetoFront(pareto_solutions, pareto_values)
end

function optimize(objective_functions, method::EpsilonConstraint, algorithm, bounds::Matrix{Float64})
    # Create aggregated objective function with constraints
    function aggregated_objective(x)
        values = [objective_functions[i](x) for i in 1:length(objective_functions)]
        
        # Primary objective
        primary_value = values[method.primary_objective]
        
        # Check constraints
        for i in 1:length(values)
            if i != method.primary_objective
                constraint_idx = i > method.primary_objective ? i - 1 : i
                if values[i] > method.constraints[constraint_idx]
                    # Add penalty for constraint violation
                    primary_value += 1000.0 * (values[i] - method.constraints[constraint_idx])^2
                end
            end
        end
        
        return primary_value
    end
    
    # Run the optimization algorithm
    result = algorithm.optimize(aggregated_objective, bounds)
    
    # Extract solutions and calculate objective values
    solutions = result["final_population"]
    n = size(solutions, 1)
    m = length(objective_functions)
    
    objective_values = zeros(n, m)
    for i in 1:n
        for j in 1:m
            objective_values[i, j] = objective_functions[j](solutions[i, :])
        end
    end
    
    # Find non-dominated solutions
    non_dominated_indices = find_non_dominated(objective_values)
    
    # Create Pareto front
    pareto_solutions = solutions[non_dominated_indices, :]
    pareto_values = objective_values[non_dominated_indices, :]
    
    return ParetoFront(pareto_solutions, pareto_values)
end

"""
    nsga2(objective_functions, config::NSGA2Config, bounds::Matrix{Float64})

NSGA-II algorithm for multi-objective optimization.

# Arguments
- `objective_functions`: Array of objective functions
- `config::NSGA2Config`: Configuration for NSGA-II
- `bounds::Matrix{Float64}`: Bounds for decision variables

# Returns
- `ParetoFront`: Pareto front of non-dominated solutions
"""
function nsga2(objective_functions, config::NSGA2Config, bounds::Matrix{Float64})
    num_objectives = length(objective_functions)
    num_variables = size(bounds, 1)
    
    # Initialize population
    population = rand(config.population_size, num_variables)
    
    # Scale to bounds
    for i in 1:num_variables
        min_val, max_val = bounds[i, 1], bounds[i, 2]
        population[:, i] = min_val .+ population[:, i] .* (max_val - min_val)
    end
    
    # Evaluate initial population
    objective_values = zeros(config.population_size, num_objectives)
    for i in 1:config.population_size
        for j in 1:num_objectives
            objective_values[i, j] = objective_functions[j](population[i, :])
        end
    end
    
    # Main loop
    for generation in 1:config.max_generations
        # Non-dominated sorting
        fronts = non_dominated_sort(objective_values)
        
        # Calculate crowding distance
        crowding_distances = calculate_crowding_distance(objective_values, fronts)
        
        # Create new population through selection, crossover, and mutation
        offspring = create_offspring(population, objective_values, fronts, crowding_distances, config, bounds)
        
        # Evaluate offspring
        offspring_values = zeros(size(offspring, 1), num_objectives)
        for i in 1:size(offspring, 1)
            for j in 1:num_objectives
                offspring_values[i, j] = objective_functions[j](offspring[i, :])
            end
        end
        
        # Combine parent and offspring populations
        combined_population = vcat(population, offspring)
        combined_values = vcat(objective_values, offspring_values)
        
        # Select the next generation
        next_indices = select_next_generation(combined_values, config.population_size)
        
        # Update population
        population = combined_population[next_indices, :]
        objective_values = combined_values[next_indices, :]
    end
    
    # Find final non-dominated solutions
    non_dominated_indices = find_non_dominated(objective_values)
    
    # Create Pareto front
    pareto_solutions = population[non_dominated_indices, :]
    pareto_values = objective_values[non_dominated_indices, :]
    
    return ParetoFront(pareto_solutions, pareto_values)
end

"""
    non_dominated_sort(objective_values::Matrix{Float64})

Perform non-dominated sorting to divide the population into fronts.

# Arguments
- `objective_values::Matrix{Float64}`: Matrix of objective values

# Returns
- `Vector{Vector{Int}}`: Vector of fronts, each front is a vector of indices
"""
function non_dominated_sort(objective_values::Matrix{Float64})
    n = size(objective_values, 1)
    
    # Initialize domination counters and dominated sets
    domination_count = zeros(Int, n)
    dominated_solutions = [Int[] for _ in 1:n]
    
    # First front
    first_front = Int[]
    
    # Calculate domination relationships
    for p in 1:n
        for q in 1:n
            if p != q
                if is_dominated(objective_values[q, :], objective_values[p, :])
                    # p dominates q
                    push!(dominated_solutions[p], q)
                elseif is_dominated(objective_values[p, :], objective_values[q, :])
                    # q dominates p
                    domination_count[p] += 1
                end
            end
        end
        
        # If p is not dominated by any other solution, it belongs to the first front
        if domination_count[p] == 0
            push!(first_front, p)
        end
    end
    
    # Initialize fronts
    fronts = [first_front]
    
    # Find the remaining fronts
    current_front = 1
    while !isempty(fronts[current_front])
        next_front = Int[]
        
        for p in fronts[current_front]
            for q in dominated_solutions[p]
                domination_count[q] -= 1
                
                if domination_count[q] == 0
                    push!(next_front, q)
                end
            end
        end
        
        current_front += 1
        push!(fronts, next_front)
    end
    
    # Remove the empty last front
    pop!(fronts)
    
    return fronts
end

"""
    calculate_crowding_distance(objective_values::Matrix{Float64}, fronts::Vector{Vector{Int}})

Calculate crowding distance for each solution.

# Arguments
- `objective_values::Matrix{Float64}`: Matrix of objective values
- `fronts::Vector{Vector{Int}}`: Vector of fronts

# Returns
- `Vector{Float64}`: Crowding distance for each solution
"""
function calculate_crowding_distance(objective_values::Matrix{Float64}, fronts::Vector{Vector{Int}})
    n = size(objective_values, 1)
    m = size(objective_values, 2)
    
    crowding_distance = zeros(n)
    
    for front in fronts
        front_size = length(front)
        
        # Skip if front has only one solution
        if front_size <= 1
            continue
        end
        
        # For each objective
        for obj in 1:m
            # Sort front by objective value
            sorted_front = sort(front, by=i -> objective_values[i, obj])
            
            # Set boundary points to infinity
            crowding_distance[sorted_front[1]] = Inf
            crowding_distance[sorted_front[end]] = Inf
            
            # Calculate crowding distance for intermediate points
            obj_range = objective_values[sorted_front[end], obj] - objective_values[sorted_front[1], obj]
            
            # Skip if range is zero
            if obj_range == 0
                continue
            end
            
            for i in 2:(front_size-1)
                crowding_distance[sorted_front[i]] += (
                    objective_values[sorted_front[i+1], obj] - 
                    objective_values[sorted_front[i-1], obj]
                ) / obj_range
            end
        end
    end
    
    return crowding_distance
end

"""
    create_offspring(population::Matrix{Float64}, objective_values::Matrix{Float64}, 
                    fronts::Vector{Vector{Int}}, crowding_distance::Vector{Float64}, 
                    config::NSGA2Config, bounds::Matrix{Float64})

Create offspring through selection, crossover, and mutation.

# Arguments
- `population::Matrix{Float64}`: Current population
- `objective_values::Matrix{Float64}`: Objective values for current population
- `fronts::Vector{Vector{Int}}`: Non-dominated fronts
- `crowding_distance::Vector{Float64}`: Crowding distance for each solution
- `config::NSGA2Config`: NSGA-II configuration
- `bounds::Matrix{Float64}`: Bounds for decision variables

# Returns
- `Matrix{Float64}`: Offspring population
"""
function create_offspring(population::Matrix{Float64}, objective_values::Matrix{Float64}, 
                         fronts::Vector{Vector{Int}}, crowding_distance::Vector{Float64}, 
                         config::NSGA2Config, bounds::Matrix{Float64})
    n = size(population, 1)
    d = size(population, 2)
    
    # Initialize offspring
    offspring = zeros(n, d)
    
    # Create offspring
    for i in 1:2:n
        # Select parents using tournament selection
        parent1_idx = tournament_selection(fronts, crowding_distance, config.tournament_size)
        parent2_idx = tournament_selection(fronts, crowding_distance, config.tournament_size)
        
        # Ensure different parents
        while parent2_idx == parent1_idx
            parent2_idx = tournament_selection(fronts, crowding_distance, config.tournament_size)
        end
        
        parent1 = population[parent1_idx, :]
        parent2 = population[parent2_idx, :]
        
        # Crossover
        if rand() < config.crossover_probability
            child1, child2 = simulated_binary_crossover(parent1, parent2)
        else
            child1, child2 = parent1, parent2
        end
        
        # Mutation
        child1 = polynomial_mutation(child1, config.mutation_probability, bounds)
        child2 = polynomial_mutation(child2, config.mutation_probability, bounds)
        
        # Add to offspring
        if i < n
            offspring[i, :] = child1
            offspring[i+1, :] = child2
        else
            offspring[i, :] = child1
        end
    end
    
    return offspring
end

"""
    tournament_selection(fronts::Vector{Vector{Int}}, crowding_distance::Vector{Float64}, tournament_size::Int)

Tournament selection based on non-dominated rank and crowding distance.

# Arguments
- `fronts::Vector{Vector{Int}}`: Non-dominated fronts
- `crowding_distance::Vector{Float64}`: Crowding distance for each solution
- `tournament_size::Int`: Number of solutions in each tournament

# Returns
- `Int`: Index of selected solution
"""
function tournament_selection(fronts::Vector{Vector{Int}}, crowding_distance::Vector{Float64}, tournament_size::Int)
    # Get all indices
    all_indices = vcat(fronts...)
    
    # Select random indices for tournament
    tournament_indices = rand(all_indices, tournament_size)
    
    # Find the front rank for each solution
    front_rank = zeros(Int, tournament_size)
    for (rank, front) in enumerate(fronts)
        for i in 1:tournament_size
            if tournament_indices[i] in front
                front_rank[i] = rank
            end
        end
    end
    
    # Find the best solution in the tournament
    best_idx = 1
    for i in 2:tournament_size
        # Compare based on front rank first
        if front_rank[i] < front_rank[best_idx]
            best_idx = i
        elseif front_rank[i] == front_rank[best_idx]
            # If same front, compare based on crowding distance
            if crowding_distance[tournament_indices[i]] > crowding_distance[tournament_indices[best_idx]]
                best_idx = i
            end
        end
    end
    
    return tournament_indices[best_idx]
end

"""
    simulated_binary_crossover(parent1::Vector{Float64}, parent2::Vector{Float64})

Simulated binary crossover operator.

# Arguments
- `parent1::Vector{Float64}`: First parent
- `parent2::Vector{Float64}`: Second parent

# Returns
- `Tuple{Vector{Float64}, Vector{Float64}}`: Two offspring
"""
function simulated_binary_crossover(parent1::Vector{Float64}, parent2::Vector{Float64})
    η = 15.0  # Distribution index
    d = length(parent1)
    
    child1 = copy(parent1)
    child2 = copy(parent2)
    
    # For each decision variable
    for i in 1:d
        # Skip if parents are identical
        if abs(parent1[i] - parent2[i]) <= 1e-10
            continue
        end
        
        # Ensure parent1 < parent2
        if parent1[i] > parent2[i]
            parent1[i], parent2[i] = parent2[i], parent1[i]
        end
        
        # Calculate beta
        if rand() <= 0.5
            β = 2.0 * rand()
            β = β^(1.0 / (η + 1.0))
        else
            β = 1.0 / (2.0 * (1.0 - rand()))
            β = β^(1.0 / (η + 1.0))
        end
        
        # Create children
        child1[i] = 0.5 * ((1.0 + β) * parent1[i] + (1.0 - β) * parent2[i])
        child2[i] = 0.5 * ((1.0 - β) * parent1[i] + (1.0 + β) * parent2[i])
    end
    
    return child1, child2
end

"""
    polynomial_mutation(solution::Vector{Float64}, mutation_probability::Float64, bounds::Matrix{Float64})

Polynomial mutation operator.

# Arguments
- `solution::Vector{Float64}`: Solution to mutate
- `mutation_probability::Float64`: Probability of mutation for each variable
- `bounds::Matrix{Float64}`: Bounds for decision variables

# Returns
- `Vector{Float64}`: Mutated solution
"""
function polynomial_mutation(solution::Vector{Float64}, mutation_probability::Float64, bounds::Matrix{Float64})
    η = 20.0  # Distribution index
    d = length(solution)
    
    mutated = copy(solution)
    
    for i in 1:d
        # Apply mutation with given probability
        if rand() < mutation_probability
            lb, ub = bounds[i, 1], bounds[i, 2]
            
            # Skip if bounds are equal
            if abs(ub - lb) <= 1e-10
                continue
            end
            
            # Calculate delta
            if rand() < 0.5
                δ = (2.0 * rand())^(1.0 / (η + 1.0)) - 1.0
            else
                δ = 1.0 - (2.0 * (1.0 - rand()))^(1.0 / (η + 1.0))
            end
            
            # Apply mutation
            mutated[i] += δ * (ub - lb)
            
            # Ensure bounds
            mutated[i] = clamp(mutated[i], lb, ub)
        end
    end
    
    return mutated
end

"""
    select_next_generation(objective_values::Matrix{Float64}, population_size::Int)

Select the next generation based on non-dominated sorting and crowding distance.

# Arguments
- `objective_values::Matrix{Float64}`: Objective values for combined population
- `population_size::Int`: Size of the next generation

# Returns
- `Vector{Int}`: Indices of selected solutions
"""
function select_next_generation(objective_values::Matrix{Float64}, population_size::Int)
    # Perform non-dominated sorting
    fronts = non_dominated_sort(objective_values)
    
    # Calculate crowding distance
    crowding_distance = calculate_crowding_distance(objective_values, fronts)
    
    # Select solutions for the next generation
    next_generation = Int[]
    
    # Add complete fronts as long as possible
    front_idx = 1
    while length(next_generation) + length(fronts[front_idx]) <= population_size
        append!(next_generation, fronts[front_idx])
        front_idx += 1
        
        # If all fronts are added but population is not filled
        if front_idx > length(fronts)
            break
        end
    end
    
    # If we need to select a subset of the next front
    if length(next_generation) < population_size && front_idx <= length(fronts)
        # Sort the current front by crowding distance
        last_front = fronts[front_idx]
        sorted_front = sort(last_front, by=i -> -crowding_distance[i])  # Descending order
        
        # Add solutions from the sorted front until population is filled
        remaining = population_size - length(next_generation)
        append!(next_generation, sorted_front[1:remaining])
    end
    
    return next_generation
end

"""
    optimize(objective_functions, method::NSGA2Config, bounds::Matrix{Float64})

Optimize multiple objective functions using NSGA-II algorithm.

# Arguments
- `objective_functions`: Array of objective functions
- `method::NSGA2Config`: NSGA-II configuration
- `bounds::Matrix{Float64}`: Bounds for decision variables

# Returns
- `ParetoFront`: Pareto front of non-dominated solutions
"""
function optimize(objective_functions, method::NSGA2Config, bounds::Matrix{Float64})
    return nsga2(objective_functions, method, bounds)
end

end # module
