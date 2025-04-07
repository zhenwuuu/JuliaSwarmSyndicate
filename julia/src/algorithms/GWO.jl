"""
    GWO - Grey Wolf Optimizer

Implementation of the Grey Wolf Optimizer algorithm.
"""
module GWO

using Random
using Statistics
using ..BaseAlgorithm # Import the base module
import ..BaseAlgorithm: initialize!, update_positions!, evaluate_fitness!, select_leaders!, get_best_position, get_best_fitness, get_convergence_data # Explicitly import functions to extend

export GWOAlgorithm

"""
    Wolf

Represents a wolf in the GWO algorithm.
"""
mutable struct Wolf
    position::Vector{Float64}  # Current position
    fitness::Float64           # Current fitness value
end

"""
    GWOAlgorithm

Grey Wolf Optimizer algorithm implementation.
"""
mutable struct GWOAlgorithm <: AbstractSwarmAlgorithm
    wolves::Vector{Wolf}
    alpha_wolf::Wolf           # Best wolf (leader)
    beta_wolf::Wolf            # Second best wolf
    delta_wolf::Wolf           # Third best wolf
    bounds::Vector{Tuple{Float64, Float64}}
    alpha_param::Float64       # Parameter for controlling exploration/exploitation
    decay_rate::Float64        # Parameter for decreasing alpha over iterations
    max_iterations::Int        # Maximum number of iterations
    iteration::Int             # Current iteration
    convergence_curve::Vector{Float64} # Convergence history
    
    # Constructor with default parameters
    function GWOAlgorithm(
        alpha_param::Float64 = 2.0,
        decay_rate::Float64 = 0.01,
        max_iterations::Int = 1000
    )
        # Initialize with dummy wolves for alpha, beta, delta
        dummy_wolf = Wolf(Float64[], Inf)
        new(
            Vector{Wolf}(),    # wolves
            dummy_wolf,        # alpha_wolf
            dummy_wolf,        # beta_wolf
            dummy_wolf,        # delta_wolf
            Vector{Tuple{Float64, Float64}}(), # bounds
            alpha_param,
            decay_rate,
            max_iterations,
            0,                 # iteration
            Float64[]          # convergence_curve
        )
    end
end

function initialize!(algorithm::GWOAlgorithm, swarm_size::Int, dimension::Int, bounds::Vector{Tuple{Float64, Float64}})
    algorithm.bounds = bounds
    algorithm.wolves = Vector{Wolf}(undef, swarm_size)
    algorithm.iteration = 0
    algorithm.convergence_curve = Float64[]
    
    # Initialize each wolf with random position
    for i in 1:swarm_size
        position = zeros(dimension)
        
        # Initialize position within bounds
        for d in 1:dimension
            lower, upper = bounds[d]
            position[d] = lower + rand() * (upper - lower)
        end
        
        algorithm.wolves[i] = Wolf(position, Inf)
    end
    
    # Initialize alpha, beta, and delta wolves with similar positions but infinite fitness
    algorithm.alpha_wolf = Wolf(zeros(dimension), Inf)
    algorithm.beta_wolf = Wolf(zeros(dimension), Inf)
    algorithm.delta_wolf = Wolf(zeros(dimension), Inf)
    
    return algorithm
end

function evaluate_fitness!(algorithm::GWOAlgorithm, fitness_function::Function)
    for wolf in algorithm.wolves
        # Calculate fitness for current position
        wolf.fitness = fitness_function(wolf.position)
    end
end

function select_leaders!(algorithm::GWOAlgorithm)
    # Sort wolves by fitness
    sorted_wolves = sort(algorithm.wolves, by = w -> w.fitness)
    
    # Update alpha, beta, and delta wolves
    if sorted_wolves[1].fitness < algorithm.alpha_wolf.fitness
        algorithm.alpha_wolf = Wolf(copy(sorted_wolves[1].position), sorted_wolves[1].fitness)
    end
    
    if length(sorted_wolves) >= 2 && sorted_wolves[2].fitness < algorithm.beta_wolf.fitness
        algorithm.beta_wolf = Wolf(copy(sorted_wolves[2].position), sorted_wolves[2].fitness)
    end
    
    if length(sorted_wolves) >= 3 && sorted_wolves[3].fitness < algorithm.delta_wolf.fitness
        algorithm.delta_wolf = Wolf(copy(sorted_wolves[3].position), sorted_wolves[3].fitness)
    end
    
    # Record convergence data
    push!(algorithm.convergence_curve, algorithm.alpha_wolf.fitness)
end

function update_positions!(algorithm::GWOAlgorithm, fitness_function::Function)
    # Increment the iteration counter
    algorithm.iteration += 1
    
    # Calculate a (linearly decreasing from 2 to 0)
    a = algorithm.alpha_param - algorithm.iteration * (algorithm.alpha_param / algorithm.max_iterations)
    
    # Update each wolf's position
    for wolf in algorithm.wolves
        for d in 1:length(wolf.position)
            # Update position based on alpha, beta, and delta wolves
            r1, r2 = rand(), rand()
            
            # Position update coefficients for alpha wolf
            A1 = 2 * a * r1 - a
            C1 = 2 * r2
            D_alpha = abs(C1 * algorithm.alpha_wolf.position[d] - wolf.position[d])
            X1 = algorithm.alpha_wolf.position[d] - A1 * D_alpha
            
            # Position update coefficients for beta wolf
            r1, r2 = rand(), rand()
            A2 = 2 * a * r1 - a
            C2 = 2 * r2
            D_beta = abs(C2 * algorithm.beta_wolf.position[d] - wolf.position[d])
            X2 = algorithm.beta_wolf.position[d] - A2 * D_beta
            
            # Position update coefficients for delta wolf
            r1, r2 = rand(), rand()
            A3 = 2 * a * r1 - a
            C3 = 2 * r2
            D_delta = abs(C3 * algorithm.delta_wolf.position[d] - wolf.position[d])
            X3 = algorithm.delta_wolf.position[d] - A3 * D_delta
            
            # Update wolf position as the average of positions influenced by alpha, beta, and delta
            wolf.position[d] = (X1 + X2 + X3) / 3
            
            # Keep position within bounds
            lower, upper = algorithm.bounds[d]
            wolf.position[d] = clamp(wolf.position[d], lower, upper)
        end
    end
    
    # Evaluate fitness for the updated positions
    evaluate_fitness!(algorithm, fitness_function)
    
    # Update leaders based on new positions
    select_leaders!(algorithm)
end

function get_best_position(algorithm::GWOAlgorithm)
    return algorithm.alpha_wolf.position
end

function get_best_fitness(algorithm::GWOAlgorithm)
    return algorithm.alpha_wolf.fitness
end

function get_convergence_data(algorithm::GWOAlgorithm)
    return algorithm.convergence_curve
end

end # module 