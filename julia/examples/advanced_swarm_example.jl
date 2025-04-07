using JuliaOS
using AdvancedSwarm
using Plots
using Random

# Set random seed for reproducibility
Random.seed!(42)

# Create a swarm with advanced behaviors
function create_advanced_swarm(n_agents=100)
    # Initialize positions and velocities
    positions = rand(n_agents, 3) * 10  # Random positions in 3D space
    velocities = randn(n_agents, 3) * 0.1  # Random initial velocities
    
    # Create agents with initial state
    agents = [Dict(
        "position" => positions[i,:],
        "velocity" => velocities[i,:],
        "state" => Dict(
            "energy" => 1.0,
            "task" => nothing,
            "learning_rate" => 0.1
        )
    ) for i in 1:n_agents]
    
    # Create different behavior systems
    emergent = create_emergent_behavior(interaction_radius=2.0, learning_rate=0.1)
    task_allocator = create_dynamic_task_allocation(max_resources=100)
    learner = create_adaptive_learning(adaptation_rate=0.1, memory_size=1000)
    
    return agents, emergent, task_allocator, learner
end

# Simulate swarm behavior
function simulate_swarm(agents, emergent, task_allocator, learner, n_steps=100)
    positions_history = zeros(length(agents), 3, n_steps)
    
    for step in 1:n_steps
        # Store current positions
        for i in 1:length(agents)
            positions_history[i,:,step] = agents[i]["position"]
        end
        
        # Apply emergent behavior rules
        for i in 1:length(agents)
            # Calculate forces from each rule
            total_force = zeros(3)
            for rule in emergent.rules
                force = rule(agents, i)
                total_force .+= force
            end
            
            # Update velocity and position
            agents[i]["velocity"] .+= total_force
            agents[i]["position"] .+= agents[i]["velocity"]
            
            # Add some randomness
            agents[i]["velocity"] .+= randn(3) * 0.01
        end
        
        # Dynamic task allocation
        if step % 10 == 0  # Every 10 steps, update tasks
            available_agents = filter(a -> isnothing(a["state"]["task"]), agents)
            if !isempty(available_agents)
                # Create some random tasks
                tasks = [
                    Dict(
                        "urgency" => rand(),
                        "resource_requirements" => rand(1:10),
                        "type" => "task_$(i)"
                    ) for i in 1:5
                ]
                
                # Assign tasks based on priority
                for task in sort(tasks, by=task_allocator.priority_scheme, rev=true)
                    if !isempty(available_agents)
                        agent = pop!(available_agents)
                        agent["state"]["task"] = task
                    end
                end
            end
        end
        
        # Adaptive learning
        for agent in agents
            if !isnothing(agent["state"]["task"])
                # Simulate task completion and learning
                success = rand() < 0.7  # 70% success rate
                reward = success ? 1.0 : -0.5
                
                # Update agent's learning state
                learner.learning_algorithm(
                    agent["state"],
                    agent["state"]["task"]["type"],
                    reward,
                    Dict("energy" => agent["state"]["energy"] * 0.95)
                )
                
                # Clear completed tasks
                if success
                    agent["state"]["task"] = nothing
                end
            end
        end
    end
    
    return positions_history
end

# Run simulation and visualize
function run_advanced_swarm_example()
    # Create swarm
    agents, emergent, task_allocator, learner = create_advanced_swarm(50)
    
    # Run simulation
    positions_history = simulate_swarm(agents, emergent, task_allocator, learner, 100)
    
    # Create 3D animation
    anim = @animate for i in 1:100
        scatter3d(
            positions_history[:,1,i],
            positions_history[:,2,i],
            positions_history[:,3,i],
            markersize=3,
            alpha=0.6,
            title="Advanced Swarm Simulation",
            xlabel="X",
            ylabel="Y",
            zlabel="Z",
            legend=false
        )
    end
    
    # Save animation
    gif(anim, "advanced_swarm.gif", fps=10)
    
    # Print statistics
    println("Simulation completed!")
    println("Number of agents: ", length(agents))
    println("Number of tasks completed: ", count(isnothing.(getfield.(agents, "state")["task"])))
end

# Run the example
if abspath(PROGRAM_FILE) == @__FILE__
    run_advanced_swarm_example()
end 