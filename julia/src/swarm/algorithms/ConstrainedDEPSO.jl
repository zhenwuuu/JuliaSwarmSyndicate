"""
Constrained Hybrid DEPSO Algorithm

This module implements a constrained version of the Hybrid DEPSO algorithm,
combining Differential Evolution and Particle Swarm Optimization for solving
constrained optimization problems.
"""
module ConstrainedDEPSO

export ConstrainedHybridDEPSO, optimize, ConstraintHandlingMethod, PenaltyMethod, FeasibilityRules

using ..SwarmBase
using ..DEPSO

"""
    ConstraintHandlingMethod

Abstract type for constraint handling methods.
"""
abstract type ConstraintHandlingMethod end

"""
    PenaltyMethod <: ConstraintHandlingMethod

Penalty method for handling constraints.

# Fields
- `penalty_factor::Float64`: Factor for penalty calculation
- `adaptive::Bool`: Whether to use adaptive penalty factors
- `exponent::Float64`: Exponent for penalty calculation
"""
struct PenaltyMethod <: ConstraintHandlingMethod
    penalty_factor::Float64
    adaptive::Bool
    exponent::Float64
    
    function PenaltyMethod(; penalty_factor=1000.0, adaptive=true, exponent=2.0)
        penalty_factor > 0 || throw(ArgumentError("Penalty factor must be positive"))
        exponent > 0 || throw(ArgumentError("Exponent must be positive"))
        new(penalty_factor, adaptive, exponent)
    end
end

"""
    FeasibilityRules <: ConstraintHandlingMethod

Feasibility rules method for handling constraints.

1. Feasible solutions are preferred over infeasible ones
2. Between two feasible solutions, the one with better objective value is preferred
3. Between two infeasible solutions, the one with smaller constraint violation is preferred
"""
struct FeasibilityRules <: ConstraintHandlingMethod end

"""
    ConstrainedHybridDEPSO <: AbstractSwarmAlgorithm

Constrained version of the Hybrid DEPSO algorithm.

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
- `constraint_handling::ConstraintHandlingMethod`: Method for handling constraints
"""
struct ConstrainedHybridDEPSO <: AbstractSwarmAlgorithm
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
    constraint_handling::ConstraintHandlingMethod

    function ConstrainedHybridDEPSO(;
        population_size=50,
        max_iterations=100,
        F=0.8,
        CR=0.9,
        w=0.7,
        c1=1.5,
        c2=1.5,
        hybrid_ratio=0.5,
        adaptive=true,
        tolerance=1e-6,
        constraint_handling=FeasibilityRules()
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

        new(population_size, max_iterations, F, CR, w, c1, c2, hybrid_ratio, adaptive, tolerance,
            constraint_handling)
    end
end

"""
    calculate_constraint_violation(constraints::Vector{Function}, x::Vector{Float64})

Calculate the total constraint violation for a solution.

# Arguments
- `constraints::Vector{Function}`: Constraint functions (should return <= 0 for feasible solutions)
- `x::Vector{Float64}`: Solution to evaluate

# Returns
- `Float64`: Total constraint violation (0 if all constraints are satisfied)
"""
function calculate_constraint_violation(constraints::Vector{Function}, x::Vector{Float64})
    violation = 0.0
    
    for constraint in constraints
        value = constraint(x)
        if value > 0
            violation += value
        end
    end
    
    return violation
end

"""
    is_feasible(constraints::Vector{Function}, x::Vector{Float64})

Check if a solution is feasible.

# Arguments
- `constraints::Vector{Function}`: Constraint functions (should return <= 0 for feasible solutions)
- `x::Vector{Float64}`: Solution to evaluate

# Returns
- `Bool`: True if the solution is feasible, false otherwise
"""
function is_feasible(constraints::Vector{Function}, x::Vector{Float64})
    for constraint in constraints
        if constraint(x) > 0
            return false
        end
    end
    
    return true
end

"""
    compare_solutions(f1::Float64, cv1::Float64, f2::Float64, cv2::Float64, 
                     method::PenaltyMethod, is_min::Bool, iteration::Int, max_iterations::Int)

Compare two solutions using the penalty method.

# Arguments
- `f1::Float64`: Objective value of solution 1
- `cv1::Float64`: Constraint violation of solution 1
- `f2::Float64`: Objective value of solution 2
- `cv2::Float64`: Constraint violation of solution 2
- `method::PenaltyMethod`: Penalty method
- `is_min::Bool`: Whether the problem is a minimization problem
- `iteration::Int`: Current iteration
- `max_iterations::Int`: Maximum number of iterations

# Returns
- `Bool`: True if solution 1 is better than solution 2, false otherwise
"""
function compare_solutions(f1::Float64, cv1::Float64, f2::Float64, cv2::Float64, 
                          method::PenaltyMethod, is_min::Bool, iteration::Int, max_iterations::Int)
    # Calculate penalty factor
    penalty_factor = method.penalty_factor
    
    if method.adaptive
        # Increase penalty factor as iterations progress
        penalty_factor *= (1.0 + iteration / max_iterations)
    end
    
    # Calculate penalized objective values
    p1 = f1 + penalty_factor * cv1^method.exponent
    p2 = f2 + penalty_factor * cv2^method.exponent
    
    # Compare penalized values
    if is_min
        return p1 < p2
    else
        return p1 > p2
    end
end

"""
    compare_solutions(f1::Float64, cv1::Float64, f2::Float64, cv2::Float64, 
                     method::FeasibilityRules, is_min::Bool, iteration::Int, max_iterations::Int)

Compare two solutions using feasibility rules.

# Arguments
- `f1::Float64`: Objective value of solution 1
- `cv1::Float64`: Constraint violation of solution 1
- `f2::Float64`: Objective value of solution 2
- `cv2::Float64`: Constraint violation of solution 2
- `method::FeasibilityRules`: Feasibility rules method
- `is_min::Bool`: Whether the problem is a minimization problem
- `iteration::Int`: Current iteration
- `max_iterations::Int`: Maximum number of iterations

# Returns
- `Bool`: True if solution 1 is better than solution 2, false otherwise
"""
function compare_solutions(f1::Float64, cv1::Float64, f2::Float64, cv2::Float64, 
                          method::FeasibilityRules, is_min::Bool, iteration::Int, max_iterations::Int)
    # Rule 1: Feasible solutions are preferred over infeasible ones
    if cv1 == 0 && cv2 > 0
        return true
    elseif cv1 > 0 && cv2 == 0
        return false
    end
    
    # Rule 2: Between two feasible solutions, the one with better objective value is preferred
    if cv1 == 0 && cv2 == 0
        if is_min
            return f1 < f2
        else
            return f1 > f2
        end
    end
    
    # Rule 3: Between two infeasible solutions, the one with smaller constraint violation is preferred
    return cv1 < cv2
end

"""
    optimize(problem::ConstrainedOptimizationProblem, algorithm::ConstrainedHybridDEPSO; callback=nothing)

Optimize a constrained problem using the Constrained Hybrid DEPSO algorithm.

# Arguments
- `problem::ConstrainedOptimizationProblem`: The constrained optimization problem
- `algorithm::ConstrainedHybridDEPSO`: The algorithm configuration
- `callback`: Optional callback function called after each iteration

# Returns
- `OptimizationResult`: The optimization result
"""
function optimize(problem::ConstrainedOptimizationProblem, algorithm::ConstrainedHybridDEPSO; callback=nothing)
    # Extract problem parameters
    dimensions = problem.dimensions
    bounds = problem.bounds
    objective_function = problem.objective_function
    constraints = problem.constraints
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
    constraint_handling = algorithm.constraint_handling
    
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
    
    # Initialize constraint violations
    constraint_violations = zeros(population_size)
    personal_best_violations = zeros(population_size)
    
    # Evaluate initial population
    for i in 1:population_size
        fitness[i] = objective_function(population[i])
        constraint_violations[i] = calculate_constraint_violation(constraints, population[i])
        
        personal_best_fitness[i] = fitness[i]
        personal_best_violations[i] = constraint_violations[i]
    end
    
    # Find global best
    global_best_idx = 0
    global_best = zeros(dimensions)
    global_best_fitness = is_min ? Inf : -Inf
    global_best_violation = Inf
    
    for i in 1:population_size
        is_better = compare_solutions(
            fitness[i], constraint_violations[i],
            global_best_fitness, global_best_violation,
            constraint_handling, is_min, 1, max_iterations
        )
        
        if global_best_idx == 0 || is_better
            global_best_idx = i
            global_best = copy(population[i])
            global_best_fitness = fitness[i]
            global_best_violation = constraint_violations[i]
        end
    end
    
    # Initialize convergence curve
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
            
            # Adjust hybrid ratio based on feasibility
            if t > 10 && t % 10 == 0
                # Count feasible solutions
                feasible_count = count(v -> v == 0, constraint_violations)
                feasible_ratio = feasible_count / population_size
                
                if feasible_ratio < 0.2
                    # Few feasible solutions, increase exploration
                    hybrid_ratio = max(hybrid_ratio - 0.05, 0.1)
                elseif feasible_ratio > 0.8
                    # Many feasible solutions, increase exploitation
                    hybrid_ratio = min(hybrid_ratio + 0.05, 0.9)
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
                trial_violation = calculate_constraint_violation(constraints, trial)
                evaluations += 1
                
                # Selection based on constraint handling method
                is_better = compare_solutions(
                    trial_fitness, trial_violation,
                    fitness[i], constraint_violations[i],
                    constraint_handling, is_min, t, max_iterations
                )
                
                if is_better
                    population[i] = trial
                    fitness[i] = trial_fitness
                    constraint_violations[i] = trial_violation
                    
                    # Update personal best
                    is_better_than_personal_best = compare_solutions(
                        trial_fitness, trial_violation,
                        personal_best_fitness[i], personal_best_violations[i],
                        constraint_handling, is_min, t, max_iterations
                    )
                    
                    if is_better_than_personal_best
                        personal_best[i] = trial
                        personal_best_fitness[i] = trial_fitness
                        personal_best_violations[i] = trial_violation
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
                new_violation = calculate_constraint_violation(constraints, new_position)
                evaluations += 1
                
                # Update position and fitness
                population[i] = new_position
                fitness[i] = new_fitness
                constraint_violations[i] = new_violation
                
                # Update personal best
                is_better_than_personal_best = compare_solutions(
                    new_fitness, new_violation,
                    personal_best_fitness[i], personal_best_violations[i],
                    constraint_handling, is_min, t, max_iterations
                )
                
                if is_better_than_personal_best
                    personal_best[i] = new_position
                    personal_best_fitness[i] = new_fitness
                    personal_best_violations[i] = new_violation
                end
            end
            
            # Update global best
            is_better_than_global = compare_solutions(
                personal_best_fitness[i], personal_best_violations[i],
                global_best_fitness, global_best_violation,
                constraint_handling, is_min, t, max_iterations
            )
            
            if is_better_than_global
                global_best = copy(personal_best[i])
                global_best_fitness = personal_best_fitness[i]
                global_best_violation = personal_best_violations[i]
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
        if t > 1 && abs(convergence_curve[t] - convergence_curve[t-1]) < tolerance && 
           global_best_violation == 0
            convergence_curve = convergence_curve[1:t]
            break
        end
    end
    
    # Check if a feasible solution was found
    success = global_best_violation == 0
    message = success ? "Optimization completed successfully" : "No feasible solution found"
    
    return OptimizationResult(
        global_best,
        global_best_fitness,
        convergence_curve,
        max_iterations,
        evaluations,
        "Constrained Hybrid DEPSO",
        success = success,
        message = message,
        constraint_violation = global_best_violation
    )
end

end # module
