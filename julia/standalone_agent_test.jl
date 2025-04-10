#!/usr/bin/env julia

# Standalone test script for Agent and Swarm Management systems
println("Starting standalone Agent and Swarm Management test...")

# Add the current directory to the load path
push!(LOAD_PATH, joinpath(@__DIR__, "src"))
push!(LOAD_PATH, joinpath(@__DIR__, "src", "JuliaOS"))

# Import required packages
using Dates
using UUIDs

# Include the necessary files directly
try
    include(joinpath(@__DIR__, "src", "JuliaOS", "AgentSystem.jl"))
    println("AgentSystem.jl loaded successfully!")
catch e
    println("Error loading AgentSystem.jl: $e")
    println("Trying alternative path...")
    try
        include(joinpath(@__DIR__, "src", "AgentSystem.jl"))
        println("AgentSystem.jl loaded from alternative path!")
    catch e2
        println("Error loading from alternative path: $e2")
    end
end

# Access the module
const AgentSys = Main.AgentSystem

println("Module loaded successfully!")

# Create a simple test
function run_standalone_test()
    try
        println("\n=== Testing Agent Creation ===")

        # Create a simple agent config
        agent_id = string(UUIDs.uuid4())[1:8]
        agent_config = AgentSys.AgentConfig(
            agent_id,
            "Test Agent",
            "testing",
            ["basic"],
            Dict{String, Dict{String, Any}}()
        )

        println("Agent config created: $agent_id")

        # Create the agent
        agent = AgentSys.create_agent(agent_config)
        if agent !== nothing
            println("✅ Successfully created agent: $(agent.config.id)")

            # Test agent status
            println("Agent status: $(agent.status)")

            # Test agent memory
            println("Agent memory initialized: $(length(agent.memory) > 0 ? "Yes" : "No")")

            # Test agent skills
            println("Default skills registered: $(length(agent.skills))")

            # Test deleting the agent
            println("\n=== Testing Agent Deletion ===")
            success = AgentSys.delete_agent(agent.config.id)
            if success
                println("✅ Successfully deleted agent: $(agent.config.id)")
            else
                println("❌ Failed to delete agent: $(agent.config.id)")
            end
        else
            println("❌ Failed to create agent")
        end

        println("\nStandalone test completed!")
    catch e
        println("\n❌ Test failed: $e")
        println(stacktrace(catch_backtrace()))
    end
end

# Run the test
run_standalone_test()
