"""
Multi-Objective Hybrid DEPSO Algorithm

This module implements a multi-objective version of the Hybrid DEPSO algorithm,
combining Differential Evolution and Particle Swarm Optimization for solving
multi-objective optimization problems.
"""
module MultiObjectiveDEPSO

export MultiObjectiveHybridDEPSO, optimize, ParetoFront, WeightedSum, EpsilonConstraint

using ..SwarmBase
using ..DEPSO

"""
    MultiObjectiveHybridDEPSO <: AbstractSwarmAlgorithm

Multi-objective version of the Hybrid DEPSO algorithm.

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
- `archive_size::Int`: Size of the non-dominated solutions archive
- `leader_selection_pressure::Float64`: Pressure for leader selection (0-1)
- `crowding_distance_weight::Float64`: Weight for crowding distance in leader selection
"""
struct MultiObjectiveHybridDEPSO <: AbstractSwarmAlgorithm
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
    archive_size::Int
    leader_selection_pressure::Float64
    crowding_distance_weight::Float64

    function MultiObjectiveHybridDEPSO(;
        population_size=100,
        max_iterations=200,
        F=0.8,
        CR=0.9,
        w=0.7,
        c1=1.5,
        c2=1.5,
        hybrid_ratio=0.5,
        adaptive=true,
        tolerance=1e-6,
        archive_size=100,
        leader_selection_pressure=0.7,
        crowding_distance_weight=0.5
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
        archive_size > 0 || throw(ArgumentError("Archive size must be positive"))
        0.0 <= leader_selection_pressure <= 1.0 || throw(ArgumentError("Leader selection pressure must be between 0 and 1"))
        0.0 <= crowding_distance_weight <= 1.0 || throw(ArgumentError("Crowding distance weight must be between 0 and 1"))

        new(population_size, max_iterations, F, CR, w, c1, c2, hybrid_ratio, adaptive, tolerance,
            archive_size, leader_selection_pressure, crowding_distance_weight)
    end
end

"""
    ParetoFront

Structure representing a Pareto front of non-dominated solutions.

# Fields
- `solutions::Vector{Vector{Float64}}`: Solutions in the Pareto front
- `objective_values::Vector{Vector{Float64}}`: Objective values for each solution
- `crowding_distances::Vector{Float64}`: Crowding distances for each solution
"""
struct ParetoFront
    solutions::Vector{Vector{Float64}}
    objective_values::Vector{Vector{Float64}}
    crowding_distances::Vector{Float64}
end

"""
    WeightedSum

Weighted sum scalarization method for multi-objective optimization.

# Fields
- `weights::Vector{Float64}`: Weights for each objective
"""
struct WeightedSum
    weights::Vector{Float64}
    
    function WeightedSum(weights::Vector{Float64})
        all(weights .>= 0) || throw(ArgumentError("All weights must be non-negative"))
        sum(weights) > 0 || throw(ArgumentError("Sum of weights must be positive"))
        new(weights ./ sum(weights))  # Normalize weights
    end
end

"""
    EpsilonConstraint

Epsilon constraint method for multi-objective optimization.

# Fields
- `primary_objective::Int`: Index of the primary objective to optimize
- `constraints::Vector{Float64}`: Constraint values for other objectives
"""
struct EpsilonConstraint
    primary_objective::Int
    constraints::Vector{Float64}
    
    function EpsilonConstraint(primary_objective::Int, constraints::Vector{Float64})
        primary_objective > 0 || throw(ArgumentError("Primary objective index must be positive"))
        new(primary_objective, constraints)
    end
end

"""
    dominates(a::Vector{Float64}, b::Vector{Float64}, minimize::Vector{Bool})

Check if solution a dominates solution b.

# Arguments
- `a::Vector{Float64}`: Objective values of solution a
- `b::Vector{Float64}`: Objective values of solution b
- `minimize::Vector{Bool}`: Whether each objective should be minimized

# Returns
- `Bool`: True if a dominates b, false otherwise
"""
function dominates(a::Vector{Float64}, b::Vector{Float64}, minimize::Vector{Bool})
    # Check if a is at least as good as b in all objectives
    at_least_as_good = true
    for i in 1:length(a)
        if minimize[i]
            if a[i] > b[i]
                at_least_as_good = false
                break
            end
        else
            if a[i] < b[i]
                at_least_as_good = false
                break
            end
        end
    end
    
    if !at_least_as_good
        return false
    end
    
    # Check if a is strictly better than b in at least one objective
    strictly_better = false
    for i in 1:length(a)
        if minimize[i]
            if a[i] < b[i]
                strictly_better = true
                break
            end
        else
            if a[i] > b[i]
                strictly_better = true
                break
            end
        end
    end
    
    return strictly_better
end

"""
    calculate_crowding_distances(objective_values::Vector{Vector{Float64}}, minimize::Vector{Bool})

Calculate crowding distances for solutions in objective space.

# Arguments
- `objective_values::Vector{Vector{Float64}}`: Objective values for each solution
- `minimize::Vector{Bool}`: Whether each objective should be minimized

# Returns
- `Vector{Float64}`: Crowding distances for each solution
"""
function calculate_crowding_distances(objective_values::Vector{Vector{Float64}}, minimize::Vector{Bool})
    n_solutions = length(objective_values)
    n_objectives = length(objective_values[1])
    
    # Initialize crowding distances
    crowding_distances = zeros(n_solutions)
    
    # For each objective
    for m in 1:n_objectives
        # Extract values for this objective
        values = [objective_values[i][m] for i in 1:n_solutions]
        
        # Sort solutions by this objective
        sorted_indices = sortperm(values)
        
        # Set boundary points to infinity
        crowding_distances[sorted_indices[1]] = Inf
        crowding_distances[sorted_indices[end]] = Inf
        
        # Calculate crowding distances
        f_min = values[sorted_indices[1]]
        f_max = values[sorted_indices[end]]
        
        # Skip if all values are the same
        if f_max ≈ f_min
            continue
        end
        
        # Calculate crowding distances for intermediate points
        for i in 2:n_solutions-1
            idx = sorted_indices[i]
            prev_idx = sorted_indices[i-1]
            next_idx = sorted_indices[i+1]
            
            # Add contribution of this objective to crowding distance
            crowding_distances[idx] += (values[next_idx] - values[prev_idx]) / (f_max - f_min)
        end
    end
    
    return crowding_distances
end

"""
    update_archive(archive::ParetoFront, new_solution::Vector{Float64}, 
                  new_objective_values::Vector{Float64}, minimize::Vector{Bool}, max_size::Int)

Update the archive of non-dominated solutions.

# Arguments
- `archive::ParetoFront`: Current archive
- `new_solution::Vector{Float64}`: New solution to consider
- `new_objective_values::Vector{Float64}`: Objective values of the new solution
- `minimize::Vector{Bool}`: Whether each objective should be minimized
- `max_size::Int`: Maximum archive size

# Returns
- `ParetoFront`: Updated archive
"""
function update_archive(archive::ParetoFront, new_solution::Vector{Float64}, 
                       new_objective_values::Vector{Float64}, minimize::Vector{Bool}, max_size::Int)
    # Check if new solution is dominated by any solution in the archive
    for i in 1:length(archive.solutions)
        if dominates(archive.objective_values[i], new_objective_values, minimize)
            # New solution is dominated, don't add it
            return archive
        end
    end
    
    # Remove solutions that are dominated by the new solution
    non_dominated_indices = Int[]
    for i in 1:length(archive.solutions)
        if !dominates(new_objective_values, archive.objective_values[i], minimize)
            push!(non_dominated_indices, i)
        end
    end
    
    # Create new archive with non-dominated solutions and the new solution
    new_solutions = vcat([archive.solutions[i] for i in non_dominated_indices], [new_solution])
    new_objective_values = vcat([archive.objective_values[i] for i in non_dominated_indices], [new_objective_values])
    
    # If archive is too large, remove solutions based on crowding distance
    if length(new_solutions) > max_size
        # Calculate crowding distances
        crowding_distances = calculate_crowding_distances(new_objective_values, minimize)
        
        # Sort by crowding distance (descending)
        sorted_indices = sortperm(crowding_distances, rev=true)
        
        # Keep only the top max_size solutions
        new_solutions = new_solutions[sorted_indices[1:max_size]]
        new_objective_values = new_objective_values[sorted_indices[1:max_size]]
        crowding_distances = crowding_distances[sorted_indices[1:max_size]]
    else
        # Calculate crowding distances for all solutions
        crowding_distances = calculate_crowding_distances(new_objective_values, minimize)
    end
    
    return ParetoFront(new_solutions, new_objective_values, crowding_distances)
end

"""
    select_leader(archive::ParetoFront, selection_pressure::Float64, crowding_distance_weight::Float64)

Select a leader from the archive using binary tournament selection.

# Arguments
- `archive::ParetoFront`: Archive of non-dominated solutions
- `selection_pressure::Float64`: Pressure for leader selection (0-1)
- `crowding_distance_weight::Float64`: Weight for crowding distance in leader selection

# Returns
- `Vector{Float64}`: Selected leader
"""
function select_leader(archive::ParetoFront, selection_pressure::Float64, crowding_distance_weight::Float64)
    n = length(archive.solutions)
    
    if n == 0
        error("Archive is empty")
    elseif n == 1
        return archive.solutions[1]
    end
    
    # Binary tournament selection
    idx1 = rand(1:n)
    idx2 = rand(1:n)
    
    # Select based on crowding distance with probability crowding_distance_weight
    if rand() < crowding_distance_weight
        if archive.crowding_distances[idx1] > archive.crowding_distances[idx2]
            return archive.solutions[idx1]
        else
            return archive.solutions[idx2]
        end
    else
        # Select randomly with bias towards better rank
        if rand() < selection_pressure
            return archive.solutions[idx1]
        else
            return archive.solutions[idx2]
        end
    end
end

"""
    scalarize(objective_values::Vector{Float64}, method::WeightedSum, minimize::Vector{Bool})

Scalarize multiple objectives using the weighted sum method.

# Arguments
- `objective_values::Vector{Float64}`: Objective values
- `method::WeightedSum`: Weighted sum method
- `minimize::Vector{Bool}`: Whether each objective should be minimized

# Returns
- `Float64`: Scalarized value
"""
function scalarize(objective_values::Vector{Float64}, method::WeightedSum, minimize::Vector{Bool})
    # For maximization objectives, negate the values
    adjusted_values = copy(objective_values)
    for i in 1:length(objective_values)
        if !minimize[i]
            adjusted_values[i] = -adjusted_values[i]
        end
    end
    
    # Calculate weighted sum
    return sum(method.weights .* adjusted_values)
end

"""
    scalarize(objective_values::Vector{Float64}, method::EpsilonConstraint, minimize::Vector{Bool})

Scalarize multiple objectives using the epsilon constraint method.

# Arguments
- `objective_values::Vector{Float64}`: Objective values
- `method::EpsilonConstraint`: Epsilon constraint method
- `minimize::Vector{Bool}`: Whether each objective should be minimized

# Returns
- `Float64`: Scalarized value
"""
function scalarize(objective_values::Vector{Float64}, method::EpsilonConstraint, minimize::Vector{Bool})
    # Check if constraints are satisfied
    for i in 1:length(objective_values)
        if i != method.primary_objective
            constraint_idx = i < method.primary_objective ? i : i - 1
            
            if minimize[i]
                if objective_values[i] > method.constraints[constraint_idx]
                    # Constraint violated, return a large value
                    return Inf
                end
            else
                if objective_values[i] < method.constraints[constraint_idx]
                    # Constraint violated, return a large value
                    return Inf
                end
            end
        end
    end
    
    # Return the primary objective value
    return minimize[method.primary_objective] ? 
           objective_values[method.primary_objective] : 
           -objective_values[method.primary_objective]
end

"""
    optimize(problem::MultiObjectiveProblem, algorithm::MultiObjectiveHybridDEPSO; 
            scalarization_method=nothing, callback=nothing)

Optimize a multi-objective problem using the Multi-Objective Hybrid DEPSO algorithm.

# Arguments
- `problem::MultiObjectiveProblem`: The multi-objective optimization problem
- `algorithm::MultiObjectiveHybridDEPSO`: The algorithm configuration
- `scalarization_method`: Optional scalarization method (WeightedSum or EpsilonConstraint)
- `callback`: Optional callback function called after each iteration

# Returns
- `ParetoFront`: The Pareto front of non-dominated solutions
"""
function optimize(problem::MultiObjectiveProblem, algorithm::MultiObjectiveHybridDEPSO; 
                 scalarization_method=nothing, callback=nothing)
    # Extract problem parameters
    dimensions = problem.dimensions
    bounds = problem.bounds
    objective_functions = problem.objective_functions
    minimize = problem.minimize
    
    n_objectives = length(objective_functions)
    
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
    archive_size = algorithm.archive_size
    leader_selection_pressure = algorithm.leader_selection_pressure
    crowding_distance_weight = algorithm.crowding_distance_weight
    
    # If scalarization method is provided, convert to single-objective problem
    if scalarization_method !== nothing
        # Create a single objective function using scalarization
        function scalarized_objective(x)
            # Evaluate all objective functions
            values = [objective_functions[i](x) for i in 1:n_objectives]
            
            # Scalarize the values
            return scalarize(values, scalarization_method, minimize)
        end
        
        # Create a single-objective problem
        single_obj_problem = OptimizationProblem(
            dimensions,
            bounds,
            scalarized_objective;
            is_minimization = true
        )
        
        # Convert to standard DEPSO algorithm
        single_obj_algorithm = HybridDEPSO(
            population_size = population_size,
            max_iterations = max_iterations,
            F = F_init,
            CR = CR_init,
            w = w_init,
            c1 = c1,
            c2 = c2,
            hybrid_ratio = hybrid_ratio_init,
            adaptive = adaptive,
            tolerance = tolerance
        )
        
        # Run standard DEPSO
        result = DEPSO.optimize(single_obj_problem, single_obj_algorithm; callback=callback)
        
        # Evaluate all objectives for the best solution
        best_objective_values = [objective_functions[i](result.best_position) for i in 1:n_objectives]
        
        # Create a Pareto front with a single solution
        return ParetoFront(
            [result.best_position],
            [best_objective_values],
            [0.0]
        )
    end
    
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
    objective_values = [zeros(n_objectives) for _ in 1:population_size]
    personal_best_objective_values = [zeros(n_objectives) for _ in 1:population_size]
    
    # Evaluate initial population
    for i in 1:population_size
        for j in 1:n_objectives
            objective_values[i][j] = objective_functions[j](population[i])
            personal_best_objective_values[i][j] = objective_values[i][j]
        end
    end
    
    # Initialize archive with non-dominated solutions
    archive_solutions = Vector{Float64}[]
    archive_objective_values = Vector{Float64}[]
    
    for i in 1:population_size
        # Check if solution i is non-dominated
        is_non_dominated = true
        for j in 1:population_size
            if i != j && dominates(objective_values[j], objective_values[i], minimize)
                is_non_dominated = false
                break
            end
        end
        
        if is_non_dominated
            push!(archive_solutions, copy(population[i]))
            push!(archive_objective_values, copy(objective_values[i]))
        end
    end
    
    # Calculate crowding distances for initial archive
    archive_crowding_distances = calculate_crowding_distances(archive_objective_values, minimize)
    
    # Create initial archive
    archive = ParetoFront(archive_solutions, archive_objective_values, archive_crowding_distances)
    
    # Initialize adaptive parameters
    F = F_init
    CR = CR_init
    w = w_init
    hybrid_ratio = hybrid_ratio_init
    
    # Function evaluation counter
    evaluations = population_size * n_objectives
    
    # Main loop
    for t in 1:max_iterations
        # Update adaptive parameters if enabled
        if adaptive
            # Decrease inertia weight linearly
            w = w_init - (w_init - 0.4) * (t / max_iterations)
            
            # Adjust hybrid ratio based on archive size
            if t > 10 && t % 10 == 0
                # If archive is growing too fast, increase exploration
                if length(archive.solutions) > archive_size * 0.8
                    hybrid_ratio = min(hybrid_ratio + 0.05, 0.9)
                else
                    # Otherwise, increase exploitation
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
                trial_objective_values = [objective_functions[j](trial) for j in 1:n_objectives]
                evaluations += n_objectives
                
                # Selection based on dominance
                if dominates(trial_objective_values, objective_values[i], minimize)
                    # Trial dominates current solution
                    population[i] = trial
                    objective_values[i] = trial_objective_values
                    
                    # Update personal best
                    personal_best[i] = trial
                    personal_best_objective_values[i] = trial_objective_values
                    
                    # Update archive
                    archive = update_archive(archive, trial, trial_objective_values, minimize, archive_size)
                elseif !dominates(objective_values[i], trial_objective_values, minimize)
                    # Neither dominates the other (they are non-dominated)
                    # Keep current solution but add trial to archive if it's non-dominated
                    archive = update_archive(archive, trial, trial_objective_values, minimize, archive_size)
                end
            else
                # PSO part
                # Select a leader from the archive
                leader = select_leader(archive, leader_selection_pressure, crowding_distance_weight)
                
                # Update velocity
                r1, r2 = rand(), rand()
                velocities[i] = w * velocities[i] +
                               c1 * r1 * (personal_best[i] - population[i]) +
                               c2 * r2 * (leader - population[i])
                
                # Update position
                new_position = population[i] + velocities[i]
                
                # Apply bounds
                for j in 1:dimensions
                    min_val, max_val = bounds[j]
                    new_position[j] = clamp(new_position[j], min_val, max_val)
                end
                
                # Evaluate new position
                new_objective_values = [objective_functions[j](new_position) for j in 1:n_objectives]
                evaluations += n_objectives
                
                # Update position and objective values
                population[i] = new_position
                objective_values[i] = new_objective_values
                
                # Update personal best based on dominance
                if dominates(new_objective_values, personal_best_objective_values[i], minimize)
                    personal_best[i] = new_position
                    personal_best_objective_values[i] = new_objective_values
                elseif !dominates(personal_best_objective_values[i], new_objective_values, minimize)
                    # They are non-dominated, keep both
                    # In this case, we could randomly choose one or keep the old one
                    # Here we keep the old one for stability
                end
                
                # Update archive
                archive = update_archive(archive, new_position, new_objective_values, minimize, archive_size)
            end
        end
        
        # Call callback if provided
        if callback !== nothing
            # Create a representative solution for callback
            # Here we use the solution with the best crowding distance
            best_idx = argmax(archive.crowding_distances)
            best_position = archive.solutions[best_idx]
            best_objective_values = archive.objective_values[best_idx]
            
            callback_result = callback(t, best_position, best_objective_values, population)
            if callback_result === false
                # Early termination if callback returns false
                break
            end
        end
        
        # Check for convergence based on archive size
        if t > 1 && length(archive.solutions) == archive_size && 
           all(archive.solutions .== prev_archive_solutions)
            # Archive hasn't changed, we've converged
            break
        end
        
        # Store current archive for convergence check
        prev_archive_solutions = deepcopy(archive.solutions)
    end
    
    return archive
end

end # module
