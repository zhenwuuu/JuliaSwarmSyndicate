module PSO

export ParticleSwarmOptimization, optimize

using Random
using Statistics
using ..SwarmBase

"""
    ParticleSwarmOptimization <: AbstractSwarmAlgorithm

Particle Swarm Optimization algorithm.

# Fields
- `swarm_size::Int`: Number of particles in the swarm
- `max_iterations::Int`: Maximum number of iterations
- `c1::Float64`: Cognitive coefficient
- `c2::Float64`: Social coefficient
- `w::Float64`: Inertia weight
- `w_damp::Float64`: Inertia weight damping ratio
"""
struct ParticleSwarmOptimization <: AbstractSwarmAlgorithm
    swarm_size::Int
    max_iterations::Int
    c1::Float64
    c2::Float64
    w::Float64
    w_damp::Float64

    function ParticleSwarmOptimization(;
        swarm_size::Int = 50,
        max_iterations::Int = 100,
        c1::Float64 = 2.0,
        c2::Float64 = 2.0,
        w::Float64 = 0.9,
        w_damp::Float64 = 0.99
    )
        # Parameter validation
        swarm_size > 0 || throw(ArgumentError("Swarm size must be positive"))
        max_iterations > 0 || throw(ArgumentError("Maximum iterations must be positive"))
        c1 >= 0.0 || throw(ArgumentError("c1 must be non-negative"))
        c2 >= 0.0 || throw(ArgumentError("c2 must be non-negative"))
        w >= 0.0 || throw(ArgumentError("w must be non-negative"))
        0.0 <= w_damp <= 1.0 || throw(ArgumentError("w_damp must be in [0, 1]"))

        new(swarm_size, max_iterations, c1, c2, w, w_damp)
    end
end

"""
    optimize(problem::OptimizationProblem, algorithm::ParticleSwarmOptimization)

Optimize the given problem using Particle Swarm Optimization.

# Arguments
- `problem::OptimizationProblem`: The optimization problem to solve
- `algorithm::ParticleSwarmOptimization`: The PSO algorithm configuration

# Returns
- `OptimizationResult`: The optimization result containing the best solution found
"""
function optimize(problem::OptimizationProblem, algorithm::ParticleSwarmOptimization; callback=nothing)
    # Initialize parameters
    n_particles = algorithm.swarm_size
    max_iter = algorithm.max_iterations
    c1 = algorithm.c1
    c2 = algorithm.c2
    w = algorithm.w
    w_damp = algorithm.w_damp
    dim = problem.dimensions
    bounds = problem.bounds
    obj_func = problem.objective_function
    is_min = problem.is_minimization

    # Initialize particles
    positions = zeros(n_particles, dim)
    velocities = zeros(n_particles, dim)
    personal_best_positions = zeros(n_particles, dim)
    personal_best_fitness = fill(is_min ? Inf : -Inf, n_particles)

    # Initialize global best
    global_best_position = zeros(dim)
    global_best_fitness = is_min ? Inf : -Inf

    # Initialize convergence curve
    convergence_curve = zeros(max_iter)

    # Function evaluation counter
    evaluations = 0

    # Initialize particles with random positions and velocities
    for i in 1:n_particles
        # Random position within bounds
        for j in 1:dim
            min_val, max_val = bounds[j]
            positions[i, j] = min_val + rand() * (max_val - min_val)
            # Random velocity within [-|max-min|, |max-min|]
            velocities[i, j] = (rand() * 2 - 1) * (max_val - min_val)
        end

        # Evaluate fitness
        fitness = obj_func(positions[i, :])
        evaluations += 1

        # Initialize personal best
        personal_best_positions[i, :] = positions[i, :]
        personal_best_fitness[i] = fitness

        # Update global best if needed
        if (is_min && fitness < global_best_fitness) || (!is_min && fitness > global_best_fitness)
            global_best_fitness = fitness
            global_best_position = positions[i, :]
        end
    end

    # Main PSO loop
    for iter in 1:max_iter
        # Update inertia weight
        w = w * w_damp

        # Update particles
        for i in 1:n_particles
            # Update velocity
            for j in 1:dim
                # Cognitive component
                r1 = rand()
                cognitive = c1 * r1 * (personal_best_positions[i, j] - positions[i, j])

                # Social component
                r2 = rand()
                social = c2 * r2 * (global_best_position[j] - positions[i, j])

                # Update velocity with inertia
                velocities[i, j] = w * velocities[i, j] + cognitive + social

                # Apply velocity bounds (optional)
                min_val, max_val = bounds[j]
                vel_range = max_val - min_val
                velocities[i, j] = clamp(velocities[i, j], -vel_range, vel_range)
            end

            # Update position
            for j in 1:dim
                positions[i, j] += velocities[i, j]

                # Apply position bounds
                min_val, max_val = bounds[j]
                positions[i, j] = clamp(positions[i, j], min_val, max_val)
            end

            # Evaluate fitness
            fitness = obj_func(positions[i, :])
            evaluations += 1

            # Update personal best if needed
            if (is_min && fitness < personal_best_fitness[i]) || (!is_min && fitness > personal_best_fitness[i])
                personal_best_fitness[i] = fitness
                personal_best_positions[i, :] = positions[i, :]

                # Update global best if needed
                if (is_min && fitness < global_best_fitness) || (!is_min && fitness > global_best_fitness)
                    global_best_fitness = fitness
                    global_best_position = positions[i, :]
                end
            end
        end

        # Store best fitness for convergence curve
        convergence_curve[iter] = global_best_fitness

        # Call callback if provided
        if callback !== nothing
            callback_result = callback(iter, global_best_position, global_best_fitness, positions)
            if callback_result === false
                # Early termination if callback returns false
                convergence_curve = convergence_curve[1:iter]
                break
            end
        end
    end

    return OptimizationResult(
        global_best_position,
        global_best_fitness,
        convergence_curve,
        max_iter,
        evaluations,
        "Particle Swarm Optimization",
        success = true,
        message = "Optimization completed successfully"
    )
end

end # module