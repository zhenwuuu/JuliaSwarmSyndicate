"""
    WOA - Whale Optimization Algorithm

Implementation of the Whale Optimization Algorithm for swarm intelligence.
Based on the hunting behavior of humpback whales.
"""
module WOA

using Random
using Statistics
using ..BaseAlgorithm # Import the base module
import ..BaseAlgorithm: initialize!, update_positions!, evaluate_fitness!, select_leaders!, get_best_position, get_best_fitness, get_convergence_data # Explicitly import functions to extend

export WOAAlgorithm

"""
    Whale

Represents a whale in the WOA algorithm.
"""
mutable struct Whale
    position::Vector{Float64}  # Current position
    fitness::Float64           # Current fitness value
end

"""
    WOAAlgorithm

Whale Optimization Algorithm implementation.
"""
mutable struct WOAAlgorithm <: AbstractSwarmAlgorithm
    whales::Vector{Whale}
    best_whale::Whale                 # Best whale found
    bounds::Vector{Tuple{Float64, Float64}}
    a_decrease_factor::Float64        # Controls the search range decrease over iterations
    spiral_constant::Float64          # Spiral shape constant
    max_iterations::Int               # Maximum number of iterations
    iteration::Int                    # Current iteration
    convergence_curve::Vector{Float64} # Convergence history
    
    # Constructor with default parameters
    function WOAAlgorithm(
        a_decrease_factor::Float64 = 2.0,
        spiral_constant::Float64 = 1.0,
        max_iterations::Int = 1000
    )
        new(
            Vector{Whale}(),  # whales
            Whale(Float64[], Inf), # best_whale
            Vector{Tuple{Float64, Float64}}(), # bounds
            a_decrease_factor,
            spiral_constant,
            max_iterations,
            0,                 # iteration
            Float64[]          # convergence_curve
        )
    end
end

function initialize!(algorithm::WOAAlgorithm, swarm_size::Int, dimension::Int, bounds::Vector{Tuple{Float64, Float64}})
    algorithm.bounds = bounds
    algorithm.whales = Vector{Whale}(undef, swarm_size)
    algorithm.iteration = 0
    algorithm.convergence_curve = Float64[]
    
    # Initialize each whale with random position
    for i in 1:swarm_size
        position = zeros(dimension)
        
        # Initialize position within bounds
        for d in 1:dimension
            lower, upper = bounds[d]
            position[d] = lower + rand() * (upper - lower)
        end
        
        algorithm.whales[i] = Whale(position, Inf)
    end
    
    algorithm.best_whale = Whale(zeros(dimension), Inf)
    
    return algorithm
end

function evaluate_fitness!(algorithm::WOAAlgorithm, fitness_function::Function)
    for whale in algorithm.whales
        # Calculate fitness for current position
        whale.fitness = fitness_function(whale.position)
    end
end

function select_leaders!(algorithm::WOAAlgorithm)
    # Find the whale with the best fitness
    best_idx = argmin([w.fitness for w in algorithm.whales])
    best_whale_candidate = algorithm.whales[best_idx]
    
    # Update best whale if improved
    if best_whale_candidate.fitness < algorithm.best_whale.fitness
        algorithm.best_whale = Whale(
            copy(best_whale_candidate.position),
            best_whale_candidate.fitness
        )
    end
    
    # Record convergence data
    push!(algorithm.convergence_curve, algorithm.best_whale.fitness)
end

function update_positions!(algorithm::WOAAlgorithm, fitness_function::Function)
    # Increment the iteration counter
    algorithm.iteration += 1
    
    # Calculate a (linearly decreasing from a_decrease_factor to 0)
    a = algorithm.a_decrease_factor - algorithm.iteration * (algorithm.a_decrease_factor / algorithm.max_iterations)
    
    dimension = length(algorithm.bounds)
    
    # Update each whale's position
    for i in 1:length(algorithm.whales)
        # Choose between encircling prey or spiral attack
        p = rand()
        
        if p < 0.5
            # Encircling prey
            # Calculate A and C
            r = rand(dimension)
            A = 2 * a * r .- a
            C = 2 * r
            
            # Check if doing exploitation or exploration
            if norm(A) < 1
                # Exploitation - Encircling prey
                D = abs.(C .* algorithm.best_whale.position - algorithm.whales[i].position)
                new_position = algorithm.best_whale.position - A .* D
            else
                # Exploration - Searching for prey
                # Choose a random whale
                random_idx = rand(1:length(algorithm.whales))
                random_whale = algorithm.whales[random_idx]
                
                D = abs.(C .* random_whale.position - algorithm.whales[i].position)
                new_position = random_whale.position - A .* D
            end
        else
            # Spiral attack
            # Calculate distance between whale and prey
            D = abs.(algorithm.best_whale.position - algorithm.whales[i].position)
            
            # Logarithmic spiral shape
            b = algorithm.spiral_constant
            l = rand() * 2 - 1  # Random number in [-1, 1]
            
            new_position = D .* exp(b * l) .* cos(2π * l) .+ algorithm.best_whale.position
        end
        
        # Keep position within bounds
        for d in 1:dimension
            lower, upper = algorithm.bounds[d]
            new_position[d] = clamp(new_position[d], lower, upper)
        end
        
        # Update whale position
        algorithm.whales[i] = Whale(new_position, Inf)
    end
    
    # Evaluate fitness for the updated positions
    evaluate_fitness!(algorithm, fitness_function)
    
    # Update best whale based on new positions
    select_leaders!(algorithm)
end

function get_best_position(algorithm::WOAAlgorithm)
    return algorithm.best_whale.position
end

function get_best_fitness(algorithm::WOAAlgorithm)
    return algorithm.best_whale.fitness
end

function get_convergence_data(algorithm::WOAAlgorithm)
    return algorithm.convergence_curve
end

end # module 