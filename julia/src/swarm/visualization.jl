"""
Visualization module for JuliaOS swarm algorithms.

This module provides visualization tools for swarm algorithms.
"""
module SwarmVisualization

export visualize_convergence, visualize_swarm, visualize_particles, save_visualization

using Plots
using Statistics
using ..SwarmBase

"""
    visualize_convergence(result::OptimizationResult; title="Convergence Curve", save_path=nothing)

Visualize the convergence curve of an optimization result.

# Arguments
- `result::OptimizationResult`: The optimization result to visualize
- `title::String`: Title for the plot
- `save_path::String`: Optional path to save the plot

# Returns
- `Plot`: The generated plot
"""
function visualize_convergence(result::OptimizationResult; title="Convergence Curve", save_path=nothing)
    p = plot(
        1:length(result.convergence_curve),
        result.convergence_curve,
        title = title,
        xlabel = "Iteration",
        ylabel = "Fitness",
        legend = false,
        linewidth = 2,
        grid = true,
        color = :blue
    )
    
    if save_path !== nothing
        savefig(p, save_path)
    end
    
    return p
end

"""
    visualize_swarm(positions::Matrix{Float64}, fitness::Vector{Float64}; 
                    best_position=nothing, dims=[1, 2], title="Swarm Visualization", save_path=nothing)

Visualize the swarm particles in 2D.

# Arguments
- `positions::Matrix{Float64}`: Matrix of particle positions (n_particles × dimensions)
- `fitness::Vector{Float64}`: Vector of fitness values for each particle
- `best_position::Vector{Float64}`: Optional best position to highlight
- `dims::Vector{Int}`: Which dimensions to plot (default: [1, 2])
- `title::String`: Title for the plot
- `save_path::String`: Optional path to save the plot

# Returns
- `Plot`: The generated plot
"""
function visualize_swarm(positions::Matrix{Float64}, fitness::Vector{Float64}; 
                         best_position=nothing, dims=[1, 2], title="Swarm Visualization", save_path=nothing)
    # Ensure we have at least 2 dimensions
    if size(positions, 2) < 2
        error("Positions matrix must have at least 2 dimensions for visualization")
    end
    
    # Ensure dims are valid
    if length(dims) != 2 || any(dims .> size(positions, 2)) || any(dims .< 1)
        error("Invalid dimensions specified")
    end
    
    # Normalize fitness for color scaling
    min_fitness = minimum(fitness)
    max_fitness = maximum(fitness)
    normalized_fitness = (fitness .- min_fitness) ./ (max_fitness - min_fitness + eps())
    
    # Create scatter plot
    p = scatter(
        positions[:, dims[1]],
        positions[:, dims[2]],
        marker_z = normalized_fitness,
        color = :viridis,
        title = title,
        xlabel = "Dimension $(dims[1])",
        ylabel = "Dimension $(dims[2])",
        label = "Particles",
        markersize = 6,
        markerstrokewidth = 0,
        grid = true,
        aspect_ratio = :equal
    )
    
    # Add best position if provided
    if best_position !== nothing
        scatter!(
            p,
            [best_position[dims[1]]],
            [best_position[dims[2]]],
            color = :red,
            markersize = 10,
            markershape = :star5,
            label = "Best Position"
        )
    end
    
    if save_path !== nothing
        savefig(p, save_path)
    end
    
    return p
end

"""
    visualize_particles(result::OptimizationResult, problem::OptimizationProblem, algorithm::AbstractSwarmAlgorithm; 
                        callback=nothing, dims=[1, 2], save_dir=nothing)

Run the optimization algorithm and visualize particles at each iteration.

# Arguments
- `problem::OptimizationProblem`: The optimization problem
- `algorithm::AbstractSwarmAlgorithm`: The swarm algorithm
- `callback::Function`: Optional callback function
- `dims::Vector{Int}`: Which dimensions to plot (default: [1, 2])
- `save_dir::String`: Optional directory to save plots

# Returns
- `OptimizationResult`: The optimization result
"""
function visualize_particles(problem::OptimizationProblem, algorithm::AbstractSwarmAlgorithm; 
                            callback=nothing, dims=[1, 2], save_dir=nothing)
    # Create save directory if needed
    if save_dir !== nothing
        mkpath(save_dir)
    end
    
    # Frame counter
    frame = 1
    
    # Custom callback to visualize each iteration
    function visualization_callback(iter, best_position, best_fitness, positions)
        # Calculate fitness for each particle
        n_particles = size(positions, 1)
        fitness = zeros(n_particles)
        for i in 1:n_particles
            fitness[i] = problem.objective_function(positions[i, :])
        end
        
        # Create visualization
        p = visualize_swarm(
            positions,
            fitness,
            best_position = best_position,
            dims = dims,
            title = "Iteration $iter, Best Fitness: $(round(best_fitness, digits=6))"
        )
        
        # Save if requested
        if save_dir !== nothing
            savefig(p, joinpath(save_dir, "iteration_$(lpad(frame, 4, '0')).png"))
            frame += 1
        end
        
        # Display the plot
        display(p)
        
        # Call original callback if provided
        if callback !== nothing
            return callback(iter, best_position, best_fitness, positions)
        end
        
        return true
    end
    
    # Run optimization with visualization callback
    result = optimize(problem, algorithm, callback=visualization_callback)
    
    return result
end

"""
    save_visualization(result::OptimizationResult, save_dir::String)

Save visualization of optimization result.

# Arguments
- `result::OptimizationResult`: The optimization result
- `save_dir::String`: Directory to save visualization

# Returns
- `String`: Path to saved visualization
"""
function save_visualization(result::OptimizationResult, save_dir::String)
    mkpath(save_dir)
    
    # Save convergence curve
    p_convergence = visualize_convergence(
        result,
        title = "$(result.algorithm_name) Convergence",
        save_path = joinpath(save_dir, "convergence.png")
    )
    
    return joinpath(save_dir, "convergence.png")
end

end # module
