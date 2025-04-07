module RobotPathPlanning

using JuliaOS.SwarmManager
using JuliaOS.Bridge
using LinearAlgebra
using Plots

export optimize_path, visualize_path, Robot2D, Environment2D

"""
    Robot2D

A 2D robot model with position, velocity, and turning constraints.
"""
struct Robot2D
    start_pos::Vector{Float64}  # [x, y]
    goal_pos::Vector{Float64}   # [x, y]
    max_velocity::Float64       # Maximum velocity
    max_turn_rate::Float64      # Maximum turning rate (radians)
    radius::Float64             # Robot radius for collision detection
end

"""
    Environment2D

A 2D environment with obstacles for path planning.
"""
struct Environment2D
    width::Float64
    height::Float64
    obstacles::Vector{Tuple{Vector{Float64}, Float64}}  # [(center, radius), ...]
end

"""
    create_random_environment(width, height, num_obstacles)

Create a random environment with obstacles.
"""
function create_random_environment(width::Float64, height::Float64, num_obstacles::Int)
    obstacles = Tuple{Vector{Float64}, Float64}[]
    
    for _ in 1:num_obstacles
        center = [rand() * width, rand() * height]
        radius = 0.5 + rand() * 1.5  # Random radius between 0.5 and 2.0
        push!(obstacles, (center, radius))
    end
    
    return Environment2D(width, height, obstacles)
end

"""
    check_collision(position, environment)

Check if a position collides with any obstacle in the environment.
"""
function check_collision(position::Vector{Float64}, robot::Robot2D, environment::Environment2D)
    # Check environment boundaries
    if position[1] < 0 || position[1] > environment.width || 
       position[2] < 0 || position[2] > environment.height
        return true
    end
    
    # Check obstacles
    for (center, radius) in environment.obstacles
        if norm(position - center) < (radius + robot.radius)
            return true
        end
    end
    
    return false
end

"""
    path_length(path_points)

Calculate the total length of a path.
"""
function path_length(path_points::Vector{Vector{Float64}})
    total_length = 0.0
    
    for i in 2:length(path_points)
        total_length += norm(path_points[i] - path_points[i-1])
    end
    
    return total_length
end

"""
    path_smoothness(path_points)

Calculate the smoothness of a path (lower is smoother).
"""
function path_smoothness(path_points::Vector{Vector{Float64}})
    if length(path_points) < 3
        return 0.0
    end
    
    total_angle_change = 0.0
    
    for i in 2:(length(path_points)-1)
        v1 = path_points[i] - path_points[i-1]
        v2 = path_points[i+1] - path_points[i]
        
        # Calculate angle between vectors
        cos_angle = dot(v1, v2) / (norm(v1) * norm(v2))
        cos_angle = clamp(cos_angle, -1.0, 1.0)  # Ensure it's in valid range
        angle = acos(cos_angle)
        
        total_angle_change += angle
    end
    
    return total_angle_change
end

"""
    decode_path(position, robot, environment, num_waypoints=10)

Decode a position vector from a swarm algorithm into a valid path.
Position is a flattened vector of waypoints: [x1, y1, x2, y2, ..., xn, yn]
"""
function decode_path(position::Vector{Float64}, robot::Robot2D, environment::Environment2D, num_waypoints::Int=10)
    path_points = Vector{Float64}[]
    
    # Add start position
    push!(path_points, robot.start_pos)
    
    # Decode waypoints from position vector
    for i in 1:num_waypoints
        idx = (i-1)*2 + 1
        if idx+1 <= length(position)
            waypoint = [position[idx], position[idx+1]]
            push!(path_points, waypoint)
        end
    end
    
    # Add goal position
    push!(path_points, robot.goal_pos)
    
    return path_points
end

"""
    calculate_fitness(position, robot, environment, num_waypoints=10)

Calculate the fitness of a path (lower is better).
"""
function calculate_fitness(position::Vector{Float64}, robot::Robot2D, environment::Environment2D, num_waypoints::Int=10)
    path_points = decode_path(position, robot, environment, num_waypoints)
    
    # Calculate path length
    length_cost = path_length(path_points)
    
    # Calculate path smoothness
    smoothness_cost = path_smoothness(path_points)
    
    # Check for collisions
    collision_cost = 0.0
    for point in path_points
        if check_collision(point, robot, environment)
            collision_cost += 1000.0
        end
    end
    
    # Calculate total cost (fitness)
    total_cost = length_cost + smoothness_cost * 10.0 + collision_cost
    
    return total_cost
end

"""
    optimize_path(robot, environment; algorithm="pso", swarm_size=50, iterations=100, num_waypoints=10)

Optimize a path for a robot using swarm intelligence algorithms.
"""
function optimize_path(robot::Robot2D, environment::Environment2D; 
                       algorithm::String="pso", swarm_size::Int=50, 
                       iterations::Int=100, num_waypoints::Int=10)
    
    # Define the dimension of the search space (2D waypoints)
    dimension = num_waypoints * 2
    
    # Define bounds for each dimension
    bounds = [(0.0, environment.width), (0.0, environment.height)] * num_waypoints
    
    # Create algorithm parameters
    algo_params = if algorithm == "pso"
        Dict("inertia_weight" => 0.7, "cognitive_coef" => 1.5, "social_coef" => 1.5)
    elseif algorithm == "gwo"
        Dict("alpha_param" => 2.0, "decay_rate" => 0.01)
    elseif algorithm == "woa"
        Dict("a_decrease_factor" => 2.0, "spiral_constant" => 1.0)
    else
        Dict{String, Any}()
    end
    
    # Create swarm configuration
    config = SwarmManager.SwarmConfig(
        "path_planning_swarm",
        swarm_size,
        algorithm,
        ["path_planning"],
        algo_params
    )
    
    # Create swarm
    swarm = SwarmManager.create_swarm(config)
    
    # Initialize swarm
    SwarmManager.Algorithms.initialize!(swarm.algorithm, swarm_size, dimension, bounds)
    
    # Define fitness function
    fitness_function = position -> calculate_fitness(position, robot, environment, num_waypoints)
    
    # Evaluate initial fitness
    SwarmManager.Algorithms.evaluate_fitness!(swarm.algorithm, fitness_function)
    SwarmManager.Algorithms.select_leaders!(swarm.algorithm)
    
    # Run optimization
    for i in 1:iterations
        SwarmManager.Algorithms.update_positions!(swarm.algorithm, fitness_function)
        best_fitness = SwarmManager.Algorithms.get_best_fitness(swarm.algorithm)
        println("Iteration $i: Best fitness = $(best_fitness)")
    end
    
    # Get best path
    best_position = SwarmManager.Algorithms.get_best_position(swarm.algorithm)
    best_path = decode_path(best_position, robot, environment, num_waypoints)
    
    return best_path
end

"""
    visualize_path(path, robot, environment)

Visualize a path, robot, and environment.
"""
function visualize_path(path::Vector{Vector{Float64}}, robot::Robot2D, environment::Environment2D)
    # Create plot
    p = plot(
        aspect_ratio=:equal,
        xlim=(0, environment.width),
        ylim=(0, environment.height),
        title="Robot Path Planning",
        xlabel="X",
        ylabel="Y",
        legend=:topright
    )
    
    # Plot environment obstacles
    for (center, radius) in environment.obstacles
        theta = range(0, 2π, length=100)
        x = center[1] .+ radius .* cos.(theta)
        y = center[2] .+ radius .* sin.(theta)
        plot!(p, x, y, seriestype=:shape, fillalpha=0.3, label="", color=:red)
    end
    
    # Plot path waypoints
    x_points = [point[1] for point in path]
    y_points = [point[2] for point in path]
    plot!(p, x_points, y_points, marker=:circle, label="Path", linewidth=2)
    
    # Highlight start and goal
    scatter!(p, [robot.start_pos[1]], [robot.start_pos[2]], color=:green, markersize=8, label="Start")
    scatter!(p, [robot.goal_pos[1]], [robot.goal_pos[2]], color=:red, markersize=8, label="Goal")
    
    return p
end

"""
    demo()

Run a demonstration of robot path planning with swarm intelligence.
"""
function demo()
    # Create environment and robot
    environment = create_random_environment(100.0, 100.0, 10)
    robot = Robot2D(
        [10.0, 10.0],  # start
        [90.0, 90.0],  # goal
        5.0,           # max velocity
        π/4,           # max turn rate
        1.0            # radius
    )
    
    # Run optimization
    println("Optimizing path with PSO...")
    path = optimize_path(
        robot, 
        environment, 
        algorithm="pso", 
        swarm_size=100, 
        iterations=50, 
        num_waypoints=5
    )
    
    # Visualize result
    plot = visualize_path(path, robot, environment)
    display(plot)
    
    return path, robot, environment
end

end # module 