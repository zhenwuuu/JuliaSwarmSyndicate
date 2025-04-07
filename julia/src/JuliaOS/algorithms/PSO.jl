"""
    PSO - Particle Swarm Optimization

Implementation of the classic PSO algorithm for swarm intelligence.
"""
module PSO

using Random
using ..BaseAlgorithm # Import the base module
import ..BaseAlgorithm: initialize!, update_positions!, evaluate_fitness!, select_leaders!, get_best_position, get_best_fitness, get_convergence_data # Explicitly import functions to extend

export PSOAlgorithm

"""
    Particle

Represents a particle in the PSO algorithm.
"""
mutable struct Particle
    position::Vector{Float64}         # Current position
    velocity::Vector{Float64}         # Current velocity
    best_position::Vector{Float64}    # Personal best position
    fitness::Float64                  # Current fitness value
    best_fitness::Float64             # Personal best fitness value
end

"""
    PSOAlgorithm

Particle Swarm Optimization algorithm implementation.
"""
mutable struct PSOAlgorithm <: AbstractSwarmAlgorithm
    particles::Vector{Particle}
    global_best_position::Vector{Float64}
    global_best_fitness::Float64
    bounds::Vector{Tuple{Float64, Float64}}
    inertia_weight::Float64           # Inertia weight (w)
    cognitive_coefficient::Float64    # Cognitive coefficient (c1)
    social_coefficient::Float64       # Social coefficient (c2)
    max_velocity::Float64             # Maximum velocity magnitude
    iteration::Int                    # Current iteration
    convergence_curve::Vector{Float64} # Convergence history
    
    # Constructor with default parameters
    function PSOAlgorithm(
        inertia_weight::Float64 = 0.7,
        cognitive_coefficient::Float64 = 1.5,
        social_coefficient::Float64 = 1.5,
        max_velocity::Float64 = 1.0
    )
        new(
            Vector{Particle}(), # particles
            Float64[], # global_best_position
            Inf, # global_best_fitness (we assume minimization)
            Vector{Tuple{Float64, Float64}}(), # bounds
            inertia_weight,
            cognitive_coefficient,
            social_coefficient,
            max_velocity,
            0, # iteration
            Float64[] # convergence_curve
        )
    end
end

function initialize!(algorithm::PSOAlgorithm, swarm_size::Int, dimension::Int, bounds::Vector{Tuple{Float64, Float64}})
    algorithm.bounds = bounds
    algorithm.particles = Vector{Particle}(undef, swarm_size)
    algorithm.global_best_position = zeros(dimension)
    algorithm.global_best_fitness = Inf  # For minimization
    algorithm.iteration = 0
    algorithm.convergence_curve = Float64[]
    
    # Initialize each particle with random position and velocity
    for i in 1:swarm_size
        position = zeros(dimension)
        velocity = zeros(dimension)
        
        # Initialize position within bounds
        for d in 1:dimension
            lower, upper = bounds[d]
            position[d] = lower + rand() * (upper - lower)
            # Initialize velocity as a fraction of the range
            velocity[d] = (rand() * 2 - 1) * algorithm.max_velocity * (upper - lower)
        end
        
        algorithm.particles[i] = Particle(
            position,
            velocity,
            copy(position),  # Best position initially equals current position
            Inf,             # Current fitness (to be calculated)
            Inf              # Best fitness (to be updated)
        )
    end
    
    return algorithm
end

function evaluate_fitness!(algorithm::PSOAlgorithm, fitness_function::Function)
    for particle in algorithm.particles
        # Calculate fitness for current position
        particle.fitness = fitness_function(particle.position)
        
        # Update personal best if improved
        if particle.fitness < particle.best_fitness
            particle.best_fitness = particle.fitness
            particle.best_position = copy(particle.position)
        end
    end
end

function select_leaders!(algorithm::PSOAlgorithm)
    # Find the particle with the best fitness
    best_idx = argmin([p.best_fitness for p in algorithm.particles])
    best_particle = algorithm.particles[best_idx]
    
    # Update global best if improved
    if best_particle.best_fitness < algorithm.global_best_fitness
        algorithm.global_best_fitness = best_particle.best_fitness
        algorithm.global_best_position = copy(best_particle.best_position)
    end
    
    # Record convergence data
    push!(algorithm.convergence_curve, algorithm.global_best_fitness)
end

function update_positions!(algorithm::PSOAlgorithm, fitness_function::Function)
    # Increment the iteration counter
    algorithm.iteration += 1
    
    # Update each particle's velocity and position
    for particle in algorithm.particles
        for d in 1:length(particle.position)
            # Calculate cognitive and social components
            r1, r2 = rand(), rand()
            cognitive_component = algorithm.cognitive_coefficient * r1 * (particle.best_position[d] - particle.position[d])
            social_component = algorithm.social_coefficient * r2 * (algorithm.global_best_position[d] - particle.position[d])
            
            # Update velocity with inertia
            particle.velocity[d] = algorithm.inertia_weight * particle.velocity[d] + cognitive_component + social_component
            
            # Clamp velocity
            lower, upper = algorithm.bounds[d]
            max_vel = algorithm.max_velocity * (upper - lower)
            particle.velocity[d] = clamp(particle.velocity[d], -max_vel, max_vel)
            
            # Update position
            particle.position[d] += particle.velocity[d]
            
            # Keep position within bounds
            particle.position[d] = clamp(particle.position[d], lower, upper)
        end
    end
    
    # Evaluate fitness for the updated positions
    evaluate_fitness!(algorithm, fitness_function)
    
    # Update leaders based on new positions
    select_leaders!(algorithm)
end

function get_best_position(algorithm::PSOAlgorithm)
    return algorithm.global_best_position
end

function get_best_fitness(algorithm::PSOAlgorithm)
    return algorithm.global_best_fitness
end

function get_convergence_data(algorithm::PSOAlgorithm)
    return algorithm.convergence_curve
end

end # module 