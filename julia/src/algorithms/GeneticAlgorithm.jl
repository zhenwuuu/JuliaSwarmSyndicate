"""
    GeneticAlgorithm

Implementation of the Genetic Algorithm for swarm intelligence.
Based on natural selection and genetic operations.
"""
module GeneticAlgorithm

using Random
using Statistics
using ..BaseAlgorithm # Import the base module
import ..BaseAlgorithm: initialize!, update_positions!, evaluate_fitness!, select_leaders!, get_best_position, get_best_fitness, get_convergence_data # Explicitly import functions to extend

export GAPopulation

"""
    Individual

Represents an individual in the genetic algorithm.
"""
mutable struct Individual
    chromosome::Vector{Float64}  # Current position/chromosome
    fitness::Float64             # Current fitness value
end

"""
    GAPopulation

Genetic Algorithm implementation.
"""
mutable struct GAPopulation <: AbstractSwarmAlgorithm
    individuals::Vector{Individual}
    best_individual::Individual       # Best individual found
    bounds::Vector{Tuple{Float64, Float64}}
    crossover_rate::Float64           # Probability of crossover
    mutation_rate::Float64            # Probability of mutation
    elitism_count::Int                # Number of best individuals to preserve
    tournament_size::Int              # Size of tournament selection
    iteration::Int                    # Current iteration
    convergence_curve::Vector{Float64} # Convergence history
    
    # Constructor with default parameters
    function GAPopulation(
        crossover_rate::Float64 = 0.8,
        mutation_rate::Float64 = 0.1,
        elitism_count::Int = 2,
        tournament_size::Int = 3
    )
        new(
            Vector{Individual}(),  # individuals
            Individual(Float64[], Inf), # best_individual
            Vector{Tuple{Float64, Float64}}(), # bounds
            crossover_rate,
            mutation_rate,
            elitism_count,
            tournament_size,
            0,                     # iteration
            Float64[]              # convergence_curve
        )
    end
end

function initialize!(algorithm::GAPopulation, population_size::Int, dimension::Int, bounds::Vector{Tuple{Float64, Float64}})
    algorithm.bounds = bounds
    algorithm.individuals = Vector{Individual}(undef, population_size)
    algorithm.iteration = 0
    algorithm.convergence_curve = Float64[]
    
    # Initialize each individual with random chromosome
    for i in 1:population_size
        chromosome = zeros(dimension)
        
        # Initialize chromosome within bounds
        for d in 1:dimension
            lower, upper = bounds[d]
            chromosome[d] = lower + rand() * (upper - lower)
        end
        
        algorithm.individuals[i] = Individual(chromosome, Inf)
    end
    
    algorithm.best_individual = Individual(zeros(dimension), Inf)
    
    return algorithm
end

function evaluate_fitness!(algorithm::GAPopulation, fitness_function::Function)
    for individual in algorithm.individuals
        # Calculate fitness for current chromosome
        individual.fitness = fitness_function(individual.chromosome)
    end
end

function select_leaders!(algorithm::GAPopulation)
    # Find the individual with the best fitness
    best_idx = argmin([i.fitness for i in algorithm.individuals])
    best_individual_candidate = algorithm.individuals[best_idx]
    
    # Update best individual if improved
    if best_individual_candidate.fitness < algorithm.best_individual.fitness
        algorithm.best_individual = Individual(
            copy(best_individual_candidate.chromosome),
            best_individual_candidate.fitness
        )
    end
    
    # Record convergence data
    push!(algorithm.convergence_curve, algorithm.best_individual.fitness)
end

"""
    tournament_selection(algorithm::GAPopulation)

Perform tournament selection to choose an individual.
"""
function tournament_selection(algorithm::GAPopulation)
    # Randomly select tournament_size individuals
    tournament_indices = rand(1:length(algorithm.individuals), algorithm.tournament_size)
    tournament = algorithm.individuals[tournament_indices]
    
    # Return the best individual from the tournament
    return tournament[argmin([i.fitness for i in tournament])]
end

"""
    crossover(parent1::Individual, parent2::Individual, bounds::Vector{Tuple{Float64, Float64}})

Perform crossover between two parents to create offspring.
Uses simulated binary crossover (SBX).
"""
function crossover(parent1::Individual, parent2::Individual, bounds::Vector{Tuple{Float64, Float64}})
    dimension = length(parent1.chromosome)
    child1_chromosome = zeros(dimension)
    child2_chromosome = zeros(dimension)
    
    # Distribution index (larger values create offspring closer to parents)
    eta_c = 20.0
    
    for d in 1:dimension
        # Check if crossover should be applied
        if rand() <= 0.5
            # If parents are almost identical, just copy parent chromosomes
            if abs(parent1.chromosome[d] - parent2.chromosome[d]) < 1e-10
                child1_chromosome[d] = parent1.chromosome[d]
                child2_chromosome[d] = parent2.chromosome[d]
                continue
            end
            
            # Make sure parent1 has the smaller value
            y1 = min(parent1.chromosome[d], parent2.chromosome[d])
            y2 = max(parent1.chromosome[d], parent2.chromosome[d])
            
            # Normalize to [0, 1]
            lower, upper = bounds[d]
            y1_norm = (y1 - lower) / (upper - lower)
            y2_norm = (y2 - lower) / (upper - lower)
            
            # Calculate beta
            beta = 1.0
            alpha = 2.0 - beta^(-(eta_c + 1))
            
            # Generate a random value between 0 and 1
            u = rand()
            
            if u <= 1.0 / alpha
                beta_q = (u * alpha)^(1.0 / (eta_c + 1))
            else
                beta_q = (1.0 / (2.0 - u * alpha))^(1.0 / (eta_c + 1))
            end
            
            # Calculate child values (normalized)
            c1_norm = 0.5 * ((y1_norm + y2_norm) - beta_q * (y2_norm - y1_norm))
            c2_norm = 0.5 * ((y1_norm + y2_norm) + beta_q * (y2_norm - y1_norm))
            
            # Denormalize and clamp to bounds
            c1 = lower + c1_norm * (upper - lower)
            c2 = lower + c2_norm * (upper - lower)
            
            # Clamp values to bounds
            child1_chromosome[d] = clamp(c1, lower, upper)
            child2_chromosome[d] = clamp(c2, lower, upper)
        else
            # No crossover, just copy parent chromosomes
            child1_chromosome[d] = parent1.chromosome[d]
            child2_chromosome[d] = parent2.chromosome[d]
        end
    end
    
    return Individual(child1_chromosome, Inf), Individual(child2_chromosome, Inf)
end

"""
    mutate!(individual::Individual, bounds::Vector{Tuple{Float64, Float64}}, mutation_rate::Float64)

Apply polynomial mutation to an individual.
"""
function mutate!(individual::Individual, bounds::Vector{Tuple{Float64, Float64}}, mutation_rate::Float64)
    dimension = length(individual.chromosome)
    
    # Distribution index for mutation
    eta_m = 20.0
    
    for d in 1:dimension
        # Check if mutation should be applied
        if rand() <= mutation_rate
            lower, upper = bounds[d]
            y = individual.chromosome[d]
            
            # Calculate delta (normalized distance to bounds)
            delta1 = (y - lower) / (upper - lower)
            delta2 = (upper - y) / (upper - lower)
            
            # Mutation parameter
            mut_pow = 1.0 / (eta_m + 1.0)
            
            # Generate random number
            r = rand()
            
            if r <= 0.5
                xy = 1.0 - delta1
                val = 2.0 * r + (1.0 - 2.0 * r) * xy^(eta_m + 1.0)
                delta_q = val^mut_pow - 1.0
            else
                xy = 1.0 - delta2
                val = 2.0 * (1.0 - r) + 2.0 * (r - 0.5) * xy^(eta_m + 1.0)
                delta_q = 1.0 - val^mut_pow
            end
            
            # Calculate mutated value and clamp to bounds
            y = y + delta_q * (upper - lower)
            individual.chromosome[d] = clamp(y, lower, upper)
        end
    end
end

function update_positions!(algorithm::GAPopulation, fitness_function::Function)
    # Increment the iteration counter
    algorithm.iteration += 1
    
    population_size = length(algorithm.individuals)
    
    # Sort individuals by fitness (minimization)
    sort!(algorithm.individuals, by = ind -> ind.fitness)
    
    # Create new population
    new_population = Vector{Individual}(undef, population_size)
    
    # Apply elitism: copy best individuals to new population
    for i in 1:algorithm.elitism_count
        new_population[i] = Individual(
            copy(algorithm.individuals[i].chromosome),
            algorithm.individuals[i].fitness
        )
    end
    
    # Fill the rest of the population with offspring
    i = algorithm.elitism_count + 1
    while i <= population_size
        # Tournament selection for parents
        parent1 = tournament_selection(algorithm)
        parent2 = tournament_selection(algorithm)
        
        # Apply crossover with probability crossover_rate
        if rand() <= algorithm.crossover_rate
            child1, child2 = crossover(parent1, parent2, algorithm.bounds)
            
            # Apply mutation to offspring
            mutate!(child1, algorithm.bounds, algorithm.mutation_rate)
            mutate!(child2, algorithm.bounds, algorithm.mutation_rate)
            
            # Add children to new population
            new_population[i] = child1
            
            # Add second child if there's space
            if i + 1 <= population_size
                new_population[i + 1] = child2
                i += 1
            end
        else
            # No crossover, just copy parents
            new_population[i] = Individual(copy(parent1.chromosome), Inf)
            
            # Apply mutation
            mutate!(new_population[i], algorithm.bounds, algorithm.mutation_rate)
            
            # Add second parent if there's space
            if i + 1 <= population_size
                new_population[i + 1] = Individual(copy(parent2.chromosome), Inf)
                mutate!(new_population[i + 1], algorithm.bounds, algorithm.mutation_rate)
                i += 1
            end
        end
        
        i += 1
    end
    
    # Replace old population with new one
    algorithm.individuals = new_population
    
    # Evaluate fitness for the new population
    evaluate_fitness!(algorithm, fitness_function)
    
    # Update best individual based on new population
    select_leaders!(algorithm)
end

function get_best_position(algorithm::GAPopulation)
    return algorithm.best_individual.chromosome
end

function get_best_fitness(algorithm::GAPopulation)
    return algorithm.best_individual.fitness
end

function get_convergence_data(algorithm::GAPopulation)
    return algorithm.convergence_curve
end

end # module 