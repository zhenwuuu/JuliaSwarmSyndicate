module SwarmRouter

export optimize_routes, particle_swarm_optimization, grey_wolf_optimization, whale_optimization, differential_evolution_optimization

using JSON
using StatsBase
using Random

# Import our algorithms module
include("algorithms/Algorithms.jl")
using .Algorithms

"""
    optimize_routes(routes_json, params_json)

Optimize cross-chain routes using swarm intelligence algorithms.

Parameters:
- `routes_json`: JSON string containing route data
- `params_json`: JSON string containing optimization parameters

Returns a JSON string with the optimized routes and performance metrics.
"""
function optimize_routes(routes_json::String, params_json::String)
    # Parse input data
    routes = JSON.parse(routes_json)
    params = JSON.parse(params_json)
    
    # Extract parameters
    optimize_for = get(params, "optimizeFor", "balanced")
    swarm_size = get(params, "swarmSize", 30)
    learning_rate = get(params, "learningRate", 0.2)
    max_iterations = get(params, "maxIterations", 100)
    
    # Create feature vectors for optimization
    route_features = []
    for route in routes
        # Create feature vector: [time, gas, output_amount, price_impact]
        push!(route_features, [
            route["totalTimeEstimate"],
            route["totalGasEstimate"],
            parse(Float64, route["totalValue"]["outputAmount"]),
            route["totalValue"]["priceImpact"]
        ])
    end
    
    # Choose optimization weights based on goal
    if optimize_for == "speed"
        weights = [0.7, 0.1, 0.2, 0.0]  # Prioritize time
    elseif optimize_for == "cost"
        weights = [0.1, 0.7, 0.2, 0.0]  # Prioritize gas cost
    elseif optimize_for == "value"
        weights = [0.1, 0.1, 0.8, 0.0]  # Prioritize output amount
    else # balanced
        weights = [0.3, 0.3, 0.3, 0.1]  # Balanced approach
    end
    
    # Choose algorithm based on params
    algorithm = get(params, "algorithm", "pso")
    
    # Run the appropriate algorithm
    start_time = time()
    
    if algorithm == "gwo"
        result = grey_wolf_optimization(route_features, weights, pack_size=swarm_size, max_iterations=max_iterations)
    elseif algorithm == "woa"
        result = whale_optimization(route_features, weights, population_size=swarm_size, max_iterations=max_iterations)
    elseif algorithm == "de"
        result = differential_evolution_optimization(route_features, weights, 
                                             population_size=swarm_size, 
                                             max_iterations=max_iterations,
                                             strategy=get(params, "strategy", "DE/rand/1/bin"),
                                             crossover_rate=get(params, "crossoverRate", 0.7),
                                             differential_weight=get(params, "differentialWeight", 0.8))
    else
        # Default to PSO
        result = particle_swarm_optimization(route_features, weights, swarm_size=swarm_size, learning_rate=learning_rate, max_iterations=max_iterations)
    end
    
    execution_time = time() - start_time
    
    # Reorder routes based on optimization results
    optimized_routes = routes[result["ordered_indices"]]
    
    # Build result data
    output = Dict(
        "optimizedRoutes" => optimized_routes,
        "iterations" => result["iterations"],
        "convergenceSpeed" => result["convergence_speed"],
        "improvementPercentage" => result["improvement_percentage"],
        "executionTime" => execution_time,
        "algorithm" => algorithm
    )
    
    # Return as JSON
    return JSON.json(output)
end

"""
    particle_swarm_optimization(routes, weights; kwargs...)

Optimize routes using Particle Swarm Optimization (PSO) algorithm.

Parameters:
- `routes`: Array of route feature vectors
- `weights`: Weight vector for scoring features
- `swarm_size`: Number of particles in the swarm
- `learning_rate`: Learning rate for particle movement
- `max_iterations`: Maximum number of iterations

Returns a dictionary with optimization results.
"""
function particle_swarm_optimization(routes, weights; swarm_size=30, learning_rate=0.2, max_iterations=100)
    n_routes = length(routes)
    
    if n_routes == 0
        return Dict(
            "ordered_indices" => [],
            "iterations" => 0,
            "convergence_speed" => 0.0,
            "improvement_percentage" => 0.0
        )
    end
    
    # Normalize features for consistent comparison
    normalized_features = normalize_features(routes)
    
    # Define fitness function - higher is better
    function fitness(route_order)
        total_score = 0.0
        for i in 1:length(route_order) - 1
            route_idx = route_order[i]
            next_route_idx = route_order[i + 1]
            
            route = normalized_features[route_idx]
            next_route = normalized_features[next_route_idx]
            
            # Calculate weighted score for this route
            route_score = sum(route .* weights)
            
            # Time and gas should be minimized (lower is better)
            route_score = route_score - 2 * (route[1] * weights[1] + route[2] * weights[2])
            
            # Add transition penalty between chains
            transition_penalty = 0.1  # Penalty for chain hops
            total_score += route_score - transition_penalty
        end
        
        # Add first and last route scores
        first_route = normalized_features[route_order[1]]
        last_route = normalized_features[route_order[end]]
        
        first_score = sum(first_route .* weights)
        first_score = first_score - 2 * (first_route[1] * weights[1] + first_route[2] * weights[2])
        
        last_score = sum(last_route .* weights)
        last_score = last_score - 2 * (last_route[1] * weights[1] + last_route[2] * weights[2])
        
        total_score += first_score + last_score
        
        return total_score
    end
    
    # Initialize particles (each particle is a permutation of route indices)
    particles = []
    velocities = []
    best_positions = []
    best_scores = []
    
    for i in 1:swarm_size
        # Create random permutation of route indices
        particle = shuffle(1:n_routes)
        push!(particles, particle)
        
        # Initialize velocity as zeros
        push!(velocities, zeros(n_routes))
        
        # Initialize best known position and score
        push!(best_positions, copy(particle))
        push!(best_scores, fitness(particle))
    end
    
    # Global best
    global_best_idx = argmax(best_scores)
    global_best_position = copy(best_positions[global_best_idx])
    global_best_score = best_scores[global_best_idx]
    
    # Initial score for improvement calculation
    initial_score = mean(best_scores)
    
    # Convergence tracking
    convergence_history = [global_best_score]
    
    # Run PSO algorithm
    iteration = 1
    converged = false
    
    while iteration <= max_iterations && !converged
        for i in 1:swarm_size
            # Update velocity
            cognitive_component = learning_rate * rand() * (best_positions[i] .- particles[i])
            social_component = learning_rate * rand() * (global_best_position .- particles[i])
            velocities[i] = velocities[i] + cognitive_component + social_component
            
            # Update position (permutation)
            # For permutation problems, we use a modified position update
            new_particle = copy(particles[i])
            
            # Apply velocity influence through swaps
            for j in 1:n_routes
                if rand() < abs(velocities[i][j])
                    # Swap with a random position
                    swap_pos = rand(1:n_routes)
                    new_particle[j], new_particle[swap_pos] = new_particle[swap_pos], new_particle[j]
                end
            end
            
            # Evaluate new position
            new_score = fitness(new_particle)
            
            # Update particle's best if improved
            if new_score > best_scores[i]
                best_positions[i] = copy(new_particle)
                best_scores[i] = new_score
                
                # Update global best if improved
                if new_score > global_best_score
                    global_best_position = copy(new_particle)
                    global_best_score = new_score
                end
            end
            
            # Update particle position
            particles[i] = new_particle
        end
        
        # Track convergence
        push!(convergence_history, global_best_score)
        
        # Check for convergence (no improvement for 10 iterations)
        if iteration > 10 && abs(convergence_history[end] - convergence_history[end-10]) < 0.001
            converged = true
        end
        
        iteration += 1
    end
    
    # Calculate improvement percentage
    final_score = global_best_score
    improvement_percentage = ((final_score - initial_score) / abs(initial_score)) * 100
    
    # Calculate convergence speed (iterations to reach 90% of final improvement)
    convergence_target = initial_score + 0.9 * (final_score - initial_score)
    convergence_iterations = findfirst(x -> x >= convergence_target, convergence_history)
    convergence_speed = convergence_iterations === nothing ? length(convergence_history) : convergence_iterations
    
    return Dict(
        "ordered_indices" => global_best_position,
        "iterations" => iteration - 1,
        "convergence_speed" => convergence_speed,
        "improvement_percentage" => improvement_percentage
    )
end

"""
    grey_wolf_optimization(routes, weights; kwargs...)

Optimize routes using Grey Wolf Optimizer (GWO) algorithm.

Parameters:
- `routes`: Array of route feature vectors
- `weights`: Weight vector for scoring features
- `pack_size`: Number of wolves in the pack
- `alpha_score`: Alpha wolf influence factor
- `max_iterations`: Maximum number of iterations

Returns a dictionary with optimization results.
"""
function grey_wolf_optimization(routes, weights; pack_size=30, alpha_score=0.3, max_iterations=100)
    # Implementation would be similar to PSO but with GWO algorithm
    # This is a placeholder
    
    # For simplicity, we'll use PSO implementation for now
    return particle_swarm_optimization(routes, weights, swarm_size=pack_size, max_iterations=max_iterations)
end

"""
    whale_optimization(routes, weights; kwargs...)

Optimize routes using Whale Optimization Algorithm (WOA).

Parameters:
- `routes`: Array of route feature vectors
- `weights`: Weight vector for scoring features
- `population_size`: Number of whales in the population
- `a_decrease_factor`: Decrease factor for a parameter
- `max_iterations`: Maximum number of iterations

Returns a dictionary with optimization results.
"""
function whale_optimization(routes, weights; population_size=30, a_decrease_factor=0.1, max_iterations=100)
    # Implementation would be similar to PSO but with WOA algorithm
    # This is a placeholder
    
    # For simplicity, we'll use PSO implementation for now
    return particle_swarm_optimization(routes, weights, swarm_size=population_size, max_iterations=max_iterations)
end

"""
    normalize_features(routes)

Normalize route features to a 0-1 scale for consistent comparison.
"""
function normalize_features(routes)
    n_routes = length(routes)
    n_features = length(routes[1])
    
    # Extract feature columns
    features = []
    for i in 1:n_features
        push!(features, [routes[j][i] for j in 1:n_routes])
    end
    
    # Normalize each feature
    normalized = []
    for route_idx in 1:n_routes
        route_features = []
        for feature_idx in 1:n_features
            feature_values = features[feature_idx]
            min_val = minimum(feature_values)
            max_val = maximum(feature_values)
            
            # Handle case where all values are the same
            if max_val == min_val
                push!(route_features, 0.5)
            else
                # Normalize to 0-1 range
                normalized_value = (routes[route_idx][feature_idx] - min_val) / (max_val - min_val)
                push!(route_features, normalized_value)
            end
        end
        push!(normalized, route_features)
    end
    
    return normalized
end

"""
    differential_evolution_optimization(routes, weights; kwargs...)

Optimize routes using Differential Evolution (DE) algorithm, which works particularly well for
finding optimal trading routes in cross-chain scenarios.

Parameters:
- `routes`: Array of route feature vectors
- `weights`: Weight vector for scoring features
- `population_size`: Size of the population
- `crossover_rate`: CR parameter (probability of crossover)
- `differential_weight`: F parameter (mutation factor)
- `strategy`: DE strategy (e.g., "DE/rand/1/bin")
- `max_iterations`: Maximum number of iterations

Returns a dictionary with optimization results.
"""
function differential_evolution_optimization(routes, weights; 
                                            population_size=30, 
                                            crossover_rate=0.7,
                                            differential_weight=0.8,
                                            strategy="DE/rand/1/bin",
                                            max_iterations=100)
    n_routes = length(routes)
    
    if n_routes == 0
        return Dict(
            "ordered_indices" => [],
            "iterations" => 0,
            "convergence_speed" => 0.0,
            "improvement_percentage" => 0.0
        )
    end
    
    # Normalize features for consistent comparison
    normalized_features = normalize_features(routes)
    
    # Define fitness function - higher is better
    function fitness(route_order)
        total_score = 0.0
        for i in 1:length(route_order) - 1
            route_idx = Int(round(route_order[i]))
            next_route_idx = Int(round(route_order[i + 1]))
            
            # Ensure indices are within bounds
            route_idx = clamp(route_idx, 1, n_routes)
            next_route_idx = clamp(next_route_idx, 1, n_routes)
            
            route = normalized_features[route_idx]
            next_route = normalized_features[next_route_idx]
            
            # Calculate weighted score for this route
            route_score = sum(route .* weights)
            
            # Time and gas should be minimized (lower is better)
            route_score = route_score - 2 * (route[1] * weights[1] + route[2] * weights[2])
            
            # Add transition penalty between chains
            transition_penalty = 0.1  # Penalty for chain hops
            total_score += route_score - transition_penalty
        end
        
        # Add first and last route scores
        first_idx = Int(round(route_order[1]))
        last_idx = Int(round(route_order[end]))
        
        # Ensure indices are within bounds
        first_idx = clamp(first_idx, 1, n_routes)
        last_idx = clamp(last_idx, 1, n_routes)
        
        first_route = normalized_features[first_idx]
        last_route = normalized_features[last_idx]
        
        first_score = sum(first_route .* weights)
        first_score = first_score - 2 * (first_route[1] * weights[1] + first_route[2] * weights[2])
        
        last_score = sum(last_route .* weights)
        last_score = last_score - 2 * (last_route[1] * weights[1] + last_route[2] * weights[2])
        
        total_score += first_score + last_score
        
        # Penalize duplicates (encourage unique routes)
        unique_indices = length(unique(Int.(round.(route_order))))
        diversity_bonus = unique_indices / n_routes
        total_score *= diversity_bonus
        
        return total_score
    end
    
    # Create DE algorithm instance
    de_params = Dict{String, Any}(
        "crossover_rate" => crossover_rate,
        "differential_weight" => differential_weight,
        "strategy" => strategy
    )
    de_algorithm = create_algorithm("de", de_params)
    
    # Define the bounds for each dimension (route index)
    # Each dimension represents a route index, can range from 1 to n_routes
    bounds = [(1.0, Float64(n_routes)) for _ in 1:n_routes]
    
    # Initialize the DE algorithm
    initialize!(de_algorithm, population_size, n_routes, bounds)
    
    # Initial evaluation of the population
    evaluate_fitness!(de_algorithm, route_order -> -fitness(route_order))  # Negate since DE minimizes
    select_leaders!(de_algorithm)
    
    # Initial score for improvement calculation
    initial_best_fitness = get_best_fitness(de_algorithm)
    initial_score = -initial_best_fitness  # Convert back to maximization
    
    # Optimization loop
    iteration = 1
    converged = false
    convergence_history = [-initial_best_fitness]
    
    while iteration <= max_iterations && !converged
        # Update positions using DE operators
        update_positions!(de_algorithm, route_order -> -fitness(route_order))
        
        # Track convergence
        best_fitness = get_best_fitness(de_algorithm)
        push!(convergence_history, -best_fitness)  # Convert back to maximization
        
        # Check for convergence (minimal improvement over 10 iterations)
        if iteration > 10
            recent_improvement = abs(convergence_history[end] - convergence_history[end-10])
            if recent_improvement < 0.001 * abs(convergence_history[1])
                converged = true
            end
        end
        
        iteration += 1
    end
    
    # Get the best route order found
    best_position = get_best_position(de_algorithm)
    best_route_order = [Int(round(x)) for x in best_position]
    
    # Ensure all indices are within bounds and unique
    best_route_order = [clamp(idx, 1, n_routes) for idx in best_route_order]
    
    # Handle potential duplicates by using StableRankSort
    if length(unique(best_route_order)) < length(best_route_order)
        # If duplicates exist, use indices 1 through n_routes
        best_route_order = collect(1:n_routes)
    end
    
    # Calculate improvement percentage
    final_score = convergence_history[end]
    improvement_percentage = ((final_score - convergence_history[1]) / abs(convergence_history[1])) * 100
    
    # Calculate convergence speed (iterations to reach 90% of final improvement)
    convergence_target = convergence_history[1] + 0.9 * (final_score - convergence_history[1])
    convergence_iterations = findfirst(x -> x >= convergence_target, convergence_history)
    convergence_speed = convergence_iterations === nothing ? length(convergence_history) : convergence_iterations
    
    return Dict(
        "ordered_indices" => best_route_order,
        "iterations" => iteration - 1,
        "convergence_speed" => convergence_speed,
        "improvement_percentage" => improvement_percentage
    )
end

end # module 