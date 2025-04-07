"""
    DE - Differential Evolution

Implements a Differential Evolution algorithm, which is highly effective for 
optimizing trading strategies due to its ability to handle non-differentiable,
noisy, and multi-modal objective functions.
"""
module DE

using Random
using Statistics
using ..BaseAlgorithm # Import the base module
import ..BaseAlgorithm: initialize!, update_positions!, evaluate_fitness!, select_leaders!, get_best_position, get_best_fitness, get_convergence_data # Explicitly import functions to extend

export DEAlgorithm

"""
    DEAlgorithm

Differential Evolution algorithm implementation.
"""
mutable struct DEAlgorithm <: BaseAlgorithm.AbstractSwarmAlgorithm
    # Main parameters
    crossover_rate::Float64      # CR parameter (0-1)
    differential_weight::Float64 # F parameter (0-2)
    strategy::String             # DE strategy 
    
    # Algorithm state
    population::Vector{Vector{Float64}}
    fitness::Vector{Float64}
    best_position::Vector{Float64}
    best_fitness::Float64
    
    # Bounds and dimensions
    bounds::Vector{Tuple{Float64, Float64}}
    dimension::Int
    population_size::Int
    
    # History
    convergence_history::Vector{Float64}
    
    # Constructor
    function DEAlgorithm(crossover_rate::Float64=0.7, differential_weight::Float64=0.8, strategy::String="DE/rand/1/bin")
        # Validate parameters
        0.0 <= crossover_rate <= 1.0 || error("Crossover rate must be in [0, 1]")
        0.0 <= differential_weight <= 2.0 || error("Differential weight must be in [0, 2]")
        strategy in ["DE/rand/1/bin", "DE/best/1/bin", "DE/current-to-best/1/bin", "DE/rand/2/bin"] || 
            error("Unsupported DE strategy: $strategy")
            
        # Initialize with empty state
        new(
            crossover_rate,
            differential_weight,
            strategy,
            Vector{Vector{Float64}}(),
            Vector{Float64}(),
            Vector{Float64}(),
            Inf,
            Vector{Tuple{Float64, Float64}}(),
            0,
            0,
            Vector{Float64}()
        )
    end
end

function BaseAlgorithm.initialize!(algorithm::DEAlgorithm, population_size::Int, dimension::Int, bounds::Vector{Tuple{Float64, Float64}})
    algorithm.population_size = population_size
    algorithm.dimension = dimension
    algorithm.bounds = bounds
    
    # Initialize population with random positions within bounds
    algorithm.population = [
        [rand() * (bounds[d][2] - bounds[d][1]) + bounds[d][1] for d in 1:dimension]
        for _ in 1:population_size
    ]
    
    # Initialize fitness values
    algorithm.fitness = fill(Inf, population_size)
    
    # Initialize best position and fitness
    algorithm.best_position = zeros(dimension)
    algorithm.best_fitness = Inf
    
    # Initialize convergence history
    algorithm.convergence_history = Vector{Float64}()
    
    return algorithm
end

function BaseAlgorithm.evaluate_fitness!(algorithm::DEAlgorithm, fitness_function::Function)
    for i in 1:algorithm.population_size
        algorithm.fitness[i] = fitness_function(algorithm.population[i])
    end
    return nothing
end

function BaseAlgorithm.select_leaders!(algorithm::DEAlgorithm)
    best_idx = argmin(algorithm.fitness)
    
    if algorithm.fitness[best_idx] < algorithm.best_fitness
        algorithm.best_fitness = algorithm.fitness[best_idx]
        algorithm.best_position = copy(algorithm.population[best_idx])
    end
    
    push!(algorithm.convergence_history, algorithm.best_fitness)
    
    return nothing
end

function BaseAlgorithm.update_positions!(algorithm::DEAlgorithm, fitness_function::Function)
    # Create a new population
    new_population = similar(algorithm.population)
    new_fitness = similar(algorithm.fitness)
    
    for i in 1:algorithm.population_size
        # Current individual
        target = algorithm.population[i]
        
        # Select unique random indices different from i
        indices = setdiff(1:algorithm.population_size, i)
        r = rand(indices, 3)  # Get 3 random unique indices
        
        # Apply DE strategy
        if algorithm.strategy == "DE/rand/1/bin"
            # x_new = x_r1 + F * (x_r2 - x_r3)
            donor = algorithm.population[r[1]] .+ algorithm.differential_weight .* 
                    (algorithm.population[r[2]] .- algorithm.population[r[3]])
        elseif algorithm.strategy == "DE/best/1/bin"
            # x_new = x_best + F * (x_r1 - x_r2)
            donor = algorithm.best_position .+ algorithm.differential_weight .* 
                    (algorithm.population[r[1]] .- algorithm.population[r[2]])
        elseif algorithm.strategy == "DE/current-to-best/1/bin"
            # x_new = x_i + F * (x_best - x_i) + F * (x_r1 - x_r2)
            donor = target .+ algorithm.differential_weight .* (algorithm.best_position .- target) .+
                    algorithm.differential_weight .* (algorithm.population[r[1]] .- algorithm.population[r[2]])
        elseif algorithm.strategy == "DE/rand/2/bin"
            # x_new = x_r1 + F * (x_r2 - x_r3) + F * (x_r4 - x_r5)
            r4, r5 = rand(indices, 2)
            donor = algorithm.population[r[1]] .+ algorithm.differential_weight .* 
                    (algorithm.population[r[2]] .- algorithm.population[r[3]]) .+
                    algorithm.differential_weight .* (algorithm.population[r4] .- algorithm.population[r5])
        end
        
        # Create trial vector using binomial crossover
        trial = similar(target)
        j_rand = rand(1:algorithm.dimension)  # Ensure at least one parameter is always crossed
        
        for j in 1:algorithm.dimension
            # Replace parameter with probability CR or ensure at least one parameter is crossed
            if rand() <= algorithm.crossover_rate || j == j_rand
                trial[j] = donor[j]
            else
                trial[j] = target[j]
            end
            
            # Apply bounds
            trial[j] = clamp(trial[j], algorithm.bounds[j][1], algorithm.bounds[j][2])
        end
        
        # Evaluate the trial vector
        trial_fitness = fitness_function(trial)
        
        # Selection: keep the better solution
        if trial_fitness <= algorithm.fitness[i]
            new_population[i] = trial
            new_fitness[i] = trial_fitness
        else
            new_population[i] = target
            new_fitness[i] = algorithm.fitness[i]
        end
    end
    
    # Update population and fitness
    algorithm.population = new_population
    algorithm.fitness = new_fitness
    
    # Update best solution
    best_idx = argmin(algorithm.fitness)
    if algorithm.fitness[best_idx] < algorithm.best_fitness
        algorithm.best_fitness = algorithm.fitness[best_idx]
        algorithm.best_position = copy(algorithm.population[best_idx])
    end
    
    push!(algorithm.convergence_history, algorithm.best_fitness)
    
    return nothing
end

function BaseAlgorithm.get_best_position(algorithm::DEAlgorithm)
    return algorithm.best_position
end

function BaseAlgorithm.get_best_fitness(algorithm::DEAlgorithm)
    return algorithm.best_fitness
end

function BaseAlgorithm.get_convergence_data(algorithm::DEAlgorithm)
    return algorithm.convergence_history
end

end # module 