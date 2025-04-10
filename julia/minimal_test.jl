#!/usr/bin/env julia

# Minimal test script for Agent and Swarm Management systems
println("Starting minimal Agent and Swarm Management test...")

# Include the necessary files directly
include("src/JuliaOS/AgentSystem.jl")

using .AgentSystem
using Dates
using UUIDs

# Create a simple test
function run_minimal_test()
    try
        println("\n=== Testing Agent Creation ===")
        
        # Create a simple agent config
        agent_id = string(UUIDs.uuid4())[1:8]
        agent_config = AgentSystem.AgentConfig(
            agent_id,
            "Test Agent",
            "testing",
            ["basic"],
            Dict{String, Dict{String, Any}}()
        )
        
        # Create the agent
        agent = AgentSystem.create_agent(agent_config)
        if agent !== nothing
            println("✅ Successfully created agent: $(agent.config.id)")
            
            # Test registering a skill
            println("\n=== Testing Skill Registration ===")
            skill = AgentSystem.AgentSkill(
                "test_skill",
                "A test skill",
                ["basic"],
                "default_execute",
                "default_validate",
                "default_error_handler",
                Dict{String, Any}(),
                false,
                false
            )
            
            success = AgentSystem.register_skill(agent.config.id, skill)
            if success
                println("✅ Successfully registered skill: $(skill.name)")
            else
                println("❌ Failed to register skill: $(skill.name)")
            end
            
            # Test executing a skill
            println("\n=== Testing Skill Execution ===")
            result = AgentSystem.execute_skill(agent.config.id, "status_report")
            if haskey(result, "status") && result["status"] == "success"
                println("✅ Successfully executed skill: status_report")
                println("Result: ", result)
            else
                println("❌ Failed to execute skill: status_report")
                println("Error: ", result)
            end
            
            # Test deleting the agent
            println("\n=== Testing Agent Deletion ===")
            success = AgentSystem.delete_agent(agent.config.id)
            if success
                println("✅ Successfully deleted agent: $(agent.config.id)")
            else
                println("❌ Failed to delete agent: $(agent.config.id)")
            end
        else
            println("❌ Failed to create agent")
        end
        
        println("\nMinimal test completed!")
    catch e
        println("\n❌ Test failed: $e")
        println(stacktrace(catch_backtrace()))
    end
end

# Run the test
run_minimal_test()
