"""
    ACO - Ant Colony Optimization

Implementation of the Ant Colony Optimization algorithm for swarm intelligence.
Based on the foraging behavior of ants and their pheromone trails.
"""
module ACO

using Random
using Statistics
using LinearAlgebra # ACO might use this
using ..BaseAlgorithm # Import the base module
import ..BaseAlgorithm: initialize!, update_positions!, evaluate_fitness!, select_leaders!, get_best_position, get_best_fitness, get_convergence_data # Explicitly import functions to extend

export ACOAlgorithm

"""
    Ant

Represents an ant in the ACO algorithm.
"""
mutable struct Ant
    position::Vector{Float64}  # Current position
    fitness::Float64           # Current fitness value
    path::Vector{Int}          # Path taken by the ant (for combinatorial problems)
end

"""
    ACOAlgorithm

Ant Colony Optimization algorithm implementation.
This is a continuous version of ACO adapted for numerical optimization.
"""
mutable struct ACOAlgorithm <: AbstractSwarmAlgorithm
    ants::Vector{Ant}
    best_ant::Ant                      # Best ant found
    pheromone_matrix::Matrix{Float64}  # Pheromone concentrations
    bounds::Vector{Tuple{Float64, Float64}}
    evaporation_rate::Float64          # Rate at which pheromones evaporate
    alpha::Float64                     # Pheromone importance
    beta::Float64                      # Heuristic importance
    q0::Float64                        # Exploitation vs exploration balance
    bin_count::Int                     # Number of discretization bins per dimension
    iteration::Int                     # Current iteration
    convergence_curve::Vector{Float64} # Convergence history
    
    # Constructor with default parameters
    function ACOAlgorithm(
        evaporation_rate::Float64 = 0.1,
        alpha::Float64 = 1.0,
        beta::Float64 = 2.0,
        q0::Float64 = 0.9,
        bin_count::Int = 10
    )
        new(
            Vector{Ant}(),         # ants
            Ant(Float64[], Inf, Int[]), # best_ant
            Matrix{Float64}(undef, 0, 0), # pheromone_matrix (initialized in initialize!)
            Vector{Tuple{Float64, Float64}}(), # bounds
            evaporation_rate,
            alpha,
            beta,
            q0,
            bin_count,
            0,                     # iteration
            Float64[]              # convergence_curve
        )
    end
end

function initialize!(algorithm::ACOAlgorithm, swarm_size::Int, dimension::Int, bounds::Vector{Tuple{Float64, Float64}})
    algorithm.bounds = bounds
    algorithm.ants = Vector{Ant}(undef, swarm_size)
    algorithm.iteration = 0
    algorithm.convergence_curve = Float64[]
    
    # Initialize pheromone matrix for continuous ACO
    # Each dimension is discretized into bin_count bins, and we track pheromone levels for each bin
    algorithm.pheromone_matrix = ones(algorithm.bin_count, dimension)
    
    # Initialize each ant with random position
    for i in 1:swarm_size
        position = zeros(dimension)
        path = Int[]
        
        # Initialize position within bounds
        for d in 1:dimension
            lower, upper = bounds[d]
            position[d] = lower + rand() * (upper - lower)
            
            # Store discretized bin for path
            bin_idx = discretize_position(position[d], lower, upper, algorithm.bin_count)
            push!(path, bin_idx)
        end
        
        algorithm.ants[i] = Ant(position, Inf, path)
    end
    
    algorithm.best_ant = Ant(zeros(dimension), Inf, Int[])
    
    return algorithm
end

"""
    discretize_position(value, lower, upper, bin_count)

Discretize a continuous position value into a bin index.
"""
function discretize_position(value::Float64, lower::Float64, upper::Float64, bin_count::Int)
    normalized = (value - lower) / (upper - lower)
    bin = floor(Int, normalized * bin_count) + 1
    return clamp(bin, 1, bin_count)
end

"""
    continuous_value(bin, lower, upper, bin_count)

Convert a bin index back to a continuous value (center of the bin).
"""
function continuous_value(bin::Int, lower::Float64, upper::Float64, bin_count::Int)
    bin_size = (upper - lower) / bin_count
    return lower + (bin - 0.5) * bin_size
end

function evaluate_fitness!(algorithm::ACOAlgorithm, fitness_function::Function)
    for ant in algorithm.ants
        # Calculate fitness for current position
        ant.fitness = fitness_function(ant.position)
    end
end

function select_leaders!(algorithm::ACOAlgorithm)
    # Find the ant with the best fitness
    best_idx = argmin([a.fitness for a in algorithm.ants])
    best_ant_candidate = algorithm.ants[best_idx]
    
    # Update best ant if improved
    if best_ant_candidate.fitness < algorithm.best_ant.fitness
        algorithm.best_ant = Ant(
            copy(best_ant_candidate.position),
            best_ant_candidate.fitness,
            copy(best_ant_candidate.path)
        )
    end
    
    # Record convergence data
    push!(algorithm.convergence_curve, algorithm.best_ant.fitness)
end

function update_pheromones!(algorithm::ACOAlgorithm)
    # 1. Evaporation
    algorithm.pheromone_matrix .*= (1.0 - algorithm.evaporation_rate)
    
    # 2. Pheromone deposit by each ant based on solution quality
    for ant in algorithm.ants
        # Deposit amount is inversely proportional to the cost
        # For minimization problems, this works well
        deposit = 1.0 / (ant.fitness + 1e-10)  # Avoid division by zero
        
        # Deposit pheromones along the path
        for d in 1:length(ant.path)
            bin = ant.path[d]
            algorithm.pheromone_matrix[bin, d] += deposit
        end
    end
    
    # 3. Elite ant (best so far) deposits additional pheromones
    if !isempty(algorithm.best_ant.path)
        elite_deposit = 2.0 / (algorithm.best_ant.fitness + 1e-10)
        for d in 1:length(algorithm.best_ant.path)
            bin = algorithm.best_ant.path[d]
            algorithm.pheromone_matrix[bin, d] += elite_deposit
        end
    end
end

function construct_solutions!(algorithm::ACOAlgorithm)
    dimension = length(algorithm.bounds)
    
    for ant_idx in 1:length(algorithm.ants)
        position = zeros(dimension)
        path = Int[]
        
        # Construct solution dimension by dimension
        for d in 1:dimension
            lower, upper = algorithm.bounds[d]
            
            # Decide whether to exploit or explore
            if rand() < algorithm.q0  # Exploitation (choose best according to pheromone)
                bin = argmax(algorithm.pheromone_matrix[:, d])
            else  # Exploration (probabilistic selection)
                # Calculate probabilities based on pheromone levels
                pheromones = algorithm.pheromone_matrix[:, d]
                probs = pheromones.^algorithm.alpha
                probs = probs ./ sum(probs)
                
                # Roulette wheel selection
                cum_probs = cumsum(probs)
                r = rand()
                bin = findfirst(p -> p >= r, cum_probs)
                if bin === nothing  # Fallback in case of numerical issues
                    bin = rand(1:algorithm.bin_count)
                end
            end
            
            # Convert bin to continuous value with some randomness
            bin_center = continuous_value(bin, lower, upper, algorithm.bin_count)
            bin_width = (upper - lower) / algorithm.bin_count
            
            # Add some random deviation within the bin
            position[d] = bin_center + (rand() - 0.5) * bin_width
            
            # Keep within bounds
            position[d] = clamp(position[d], lower, upper)
            
            # Store the bin in the path
            push!(path, bin)
        end
        
        algorithm.ants[ant_idx] = Ant(position, Inf, path)
    end
end

function update_positions!(algorithm::ACOAlgorithm, fitness_function::Function)
    # Increment the iteration counter
    algorithm.iteration += 1
    
    # 1. Construct new solutions
    construct_solutions!(algorithm)
    
    # 2. Evaluate fitness for all ants
    evaluate_fitness!(algorithm, fitness_function)
    
    # 3. Update best ant
    select_leaders!(algorithm)
    
    # 4. Update pheromone trails
    update_pheromones!(algorithm)
end

function get_best_position(algorithm::ACOAlgorithm)
    return algorithm.best_ant.position
end

function get_best_fitness(algorithm::ACOAlgorithm)
    return algorithm.best_ant.fitness
end

function get_convergence_data(algorithm::ACOAlgorithm)
    return algorithm.convergence_curve
end

end # module 