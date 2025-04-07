using JuliaOS
using SpecializedAgents
using AdvancedSwarm
using Plots
using Random
using Statistics

# Set random seed for reproducibility
Random.seed!(42)

# Generate synthetic market data
function generate_market_data(n_points=1000)
    # Generate a random walk with some trends
    prices = zeros(n_points)
    prices[1] = 100.0
    
    for i in 2:n_points
        # Add some trend and noise
        trend = sin(i/50) * 0.5  # Cyclical trend
        noise = randn() * 0.1    # Random noise
        prices[i] = prices[i-1] * (1 + trend + noise)
    end
    
    return prices
end

# Create a market simulation environment
function create_market_environment(n_agents=50)
    # Generate market data
    market_data = generate_market_data()
    
    # Create different types of agents
    trading_agents = [
        create_trading_agent(
            initial_capital=10000.0,
            risk_tolerance=rand()
        ) for _ in 1:div(n_agents, 2)
    ]
    
    analysis_agents = [
        create_analysis_agent(
            buffer_size=100,
            pattern_threshold=0.8
        ) for _ in 1:div(n_agents, 2)
    ]
    
    # Create swarm behaviors
    emergent = create_emergent_behavior(interaction_radius=2.0, learning_rate=0.1)
    task_allocator = create_dynamic_task_allocation(max_resources=100)
    
    return Dict(
        "market_data" => market_data,
        "trading_agents" => trading_agents,
        "analysis_agents" => analysis_agents,
        "emergent" => emergent,
        "task_allocator" => task_allocator
    )
end

# Run market simulation
function run_market_simulation(env, n_steps=100)
    market_data = env["market_data"]
    trading_agents = env["trading_agents"]
    analysis_agents = env["analysis_agents"]
    emergent = env["emergent"]
    task_allocator = env["task_allocator"]
    
    # Initialize results storage
    results = Dict(
        "portfolio_values" => zeros(length(trading_agents), n_steps),
        "pattern_detections" => zeros(length(analysis_agents), n_steps),
        "market_prices" => market_data[1:n_steps]
    )
    
    # Run simulation
    for step in 1:n_steps
        current_price = market_data[step]
        
        # Update trading agents
        for (i, agent) in enumerate(trading_agents)
            # Get recent market data window
            market_window = market_data[max(1, step-20):step]
            
            # Update agent
            update_trading_agent(agent, market_window)
            
            # Store portfolio value
            total_value = agent.portfolio["cash"]
            for asset in values(agent.portfolio["assets"])
                total_value += asset["amount"] * (current_price / asset["price"])
            end
            results["portfolio_values"][i, step] = total_value
        end
        
        # Update analysis agents
        for (i, agent) in enumerate(analysis_agents)
            # Create data point for analysis
            data_point = Dict(
                "price" => current_price,
                "volume" => rand() * 1000,  # Synthetic volume
                "timestamp" => step
            )
            
            # Update agent
            update_analysis_agent(agent, data_point)
            
            # Store number of patterns detected
            results["pattern_detections"][i, step] = length(agent.patterns)
        end
        
        # Apply emergent behavior to all agents
        all_agents = vcat(trading_agents, analysis_agents)
        for i in 1:length(all_agents)
            total_force = zeros(3)
            for rule in emergent.rules
                force = rule(all_agents, i)
                total_force .+= force
            end
            
            all_agents[i].velocity .+= total_force
            all_agents[i].position .+= all_agents[i].velocity
        end
    end
    
    return results
end

# Visualize results
function visualize_results(results)
    # Create subplots
    p1 = plot(
        results["market_prices"],
        title="Market Prices",
        xlabel="Time",
        ylabel="Price",
        legend=false
    )
    
    p2 = plot(
        mean(results["portfolio_values"], dims=1)[1,:],
        title="Average Portfolio Value",
        xlabel="Time",
        ylabel="Value",
        legend=false
    )
    
    p3 = plot(
        mean(results["pattern_detections"], dims=1)[1,:],
        title="Average Pattern Detections",
        xlabel="Time",
        ylabel="Number of Patterns",
        legend=false
    )
    
    # Combine plots
    plot(p1, p2, p3, layout=(3,1), size=(800,1200))
end

# Run the example
function run_specialized_agents_example()
    println("Creating market environment...")
    env = create_market_environment(50)
    
    println("Running market simulation...")
    results = run_market_simulation(env, 100)
    
    println("Visualizing results...")
    p = visualize_results(results)
    savefig(p, "specialized_agents_results.png")
    
    # Print some statistics
    println("\nSimulation Results:")
    println("Final average portfolio value: ", mean(results["portfolio_values"][:,end]))
    println("Total patterns detected: ", sum(results["pattern_detections"][:,end]))
    println("Market price change: ", (results["market_prices"][end] - results["market_prices"][1]) / results["market_prices"][1] * 100, "%")
end

# Run the example
if abspath(PROGRAM_FILE) == @__FILE__
    run_specialized_agents_example()
end 