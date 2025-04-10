#!/usr/bin/env julia

# Simple test script for Agent and Swarm Management systems

println("Starting simple Agent and Swarm Management test...")

# Include the necessary files directly
include("julia/src/JuliaOS/MarketData.jl")
include("julia/src/JuliaOS/algorithms/Algorithms.jl")
include("julia/src/JuliaOS/SwarmManager.jl")
include("julia/src/JuliaOS/AgentSystem.jl")

using .MarketData
using .Algorithms
using .SwarmManager
using .AgentSystem
using Dates
using UUIDs

println("Modules loaded successfully!")

# Create a simple agent
function create_test_agent()
    println("\n=== Creating Test Agent ===")

    # Create a trading agent
    agent_config = AgentSystem.AgentConfig(
        string(UUIDs.uuid4())[1:8],
        "Test Agent",
        "trading",
        ["trading", "analysis"],
        Dict("blockchain" => Dict("chain" => "ethereum", "network" => "mainnet"))
    )

    agent = AgentSystem.create_agent(agent_config)
    println("Created agent: $(agent.config.id)")

    return agent
end

# Create a simple swarm
function create_test_swarm()
    println("\n=== Creating Test Swarm ===")

    # Create swarm config
    swarm_config = SwarmManager.SwarmManagerConfig(
        string(UUIDs.uuid4())[1:8],
        "Test Swarm",
        "1.0.0",
        "differential_evolution",
        Dict(
            "population_size" => 10,
            "crossover_rate" => 0.7,
            "mutation_factor" => 0.5,
            "max_generations" => 50
        ),
        Dict(
            "objective" => "maximize_profit",
            "constraints" => ["risk_limit", "max_drawdown"]
        )
    )

    # Create the swarm
    swarm = AgentSystem.create_swarm(swarm_config, "ethereum", "uniswap-v3")
    println("Created swarm: $(swarm.swarm_object.config.name) ($(swarm.swarm_object.config.id))")

    return swarm
end

# Run a simple test
function run_simple_test()
    try
        # Create an agent
        agent = create_test_agent()

        # Create a swarm
        swarm = create_test_swarm()

        # Add agent to swarm
        println("\n=== Adding Agent to Swarm ===")
        success = AgentSystem.add_agent_to_swarm(agent.config.id, swarm.swarm_object.config.id)
        if success
            println("Added agent $(agent.config.id) to swarm $(swarm.swarm_object.config.id)")
        else
            println("Failed to add agent $(agent.config.id) to swarm $(swarm.swarm_object.config.id)")
        end

        # Start agent
        println("\n=== Starting Agent ===")
        success = AgentSystem.update_agent_status(agent.config.id, "active")
        if success
            println("Started agent $(agent.config.id)")
        else
            println("Failed to start agent $(agent.config.id)")
        end

        # Execute a skill
        println("\n=== Executing Skill ===")
        result = AgentSystem.execute_skill(agent.config.id, "status_report")
        println("Executed status_report skill for agent $(agent.config.id)")
        println("Result: ", result)

        # Stop agent
        println("\n=== Stopping Agent ===")
        success = AgentSystem.update_agent_status(agent.config.id, "inactive")
        if success
            println("Stopped agent $(agent.config.id)")
        else
            println("Failed to stop agent $(agent.config.id)")
        end

        # Remove agent from swarm
        println("\n=== Removing Agent from Swarm ===")
        success = AgentSystem.remove_agent_from_swarm(agent.config.id, swarm.swarm_object.config.id)
        if success
            println("Removed agent $(agent.config.id) from swarm $(swarm.swarm_object.config.id)")
        else
            println("Failed to remove agent $(agent.config.id) from swarm $(swarm.swarm_object.config.id)")
        end

        # Delete agent and swarm
        println("\n=== Cleaning Up ===")
        success = AgentSystem.delete_agent(agent.config.id)
        if success
            println("Deleted agent $(agent.config.id)")
        else
            println("Failed to delete agent $(agent.config.id)")
        end

        success = AgentSystem.delete_swarm(swarm.swarm_object.config.id)
        if success
            println("Deleted swarm $(swarm.swarm_object.config.id)")
        else
            println("Failed to delete swarm $(swarm.swarm_object.config.id)")
        end

        println("\nSimple test completed successfully!")
    catch e
        println("\nTest failed: $e")
        println(stacktrace(catch_backtrace()))
    end
end

# Run the test
run_simple_test()
