using Test
using Dates

# Add the src directory to the load path
pushfirst!(LOAD_PATH, joinpath(@__DIR__, "..", "src"))

# Include the necessary modules
include("../src/MarketData.jl")
include("../src/Bridge.jl")
include("../src/DEX.jl")
include("../src/Algorithms.jl")
include("../src/SwarmManager.jl")
include("../src/AgentSystem.jl")

# Use the modules
using .SwarmManager
using .AgentSystem

@testset "Swarm Integration Tests" begin
    @testset "Agent Skill Registration" begin
        # Create an agent
        agent_config = AgentSystem.AgentConfig(
            "test_agent_$(rand(1:1000))",
            "Test Agent",
            "cross_chain_optimizer",
            ["cross_chain", "optimization"],
            Dict{String, Any}(),
            60
        )

        agent_id = AgentSystem.create_agent(agent_config)
        @test agent_id !== nothing

        # Get the agent state
        agent_state = AgentSystem.get_agent_state(agent_id)
        @test agent_state !== nothing

        # Check if the agent has the required skills
        @test haskey(agent_state.skills, "optimize_cross_chain_routing")

        # Clean up
        AgentSystem.delete_agent(agent_id)
    end

    @testset "Swarm Creation and Management" begin
        # Create a swarm
        swarm_config = SwarmManager.SwarmManagerConfig(
            "test_swarm_$(rand(1:1000))",
            Dict{String, Any}(
                "type" => "pso",
                "params" => Dict{String, Any}(
                    "inertia_weight" => 0.7,
                    "cognitive_coefficient" => 1.5,
                    "social_coefficient" => 1.5
                ),
                "coordination_strategy" => "consensus"
            ),
            10, # num_particles
            100, # num_iterations
            ["ETH/USDC", "BTC/USDC"]
        )

        swarm = SwarmManager.create_swarm(swarm_config)
        @test swarm !== nothing

        # Add agents to the swarm
        for i in 1:3
            agent_id = "agent_$(i)_$(rand(1:1000))"
            agent_type = "cross_chain_optimizer"
            capabilities = ["cross_chain", "optimization"]

            @test SwarmManager.add_agent_to_swarm!(swarm, agent_id, agent_type, capabilities)
        end

        # Check if agents were added
        @test length(swarm.agents) == 3

        # Test agent coordination
        @test SwarmManager.coordinate_agents!(swarm)

        # Check if coordination updated the agents
        for agent in swarm.agents
            @test haskey(agent, "status")
            @test agent["status"] in ["consensus", "leader", "following_leader", "independent"]
        end

        # Test broadcasting a message
        message = Dict{String, Any}(
            "type" => "command",
            "action" => "optimize",
            "parameters" => Dict{String, Any}(
                "source_chain" => "ethereum",
                "target_chain" => "solana",
                "token" => "USDC",
                "amount" => 100.0
            )
        )

        @test SwarmManager.broadcast_message_to_agents!(swarm, message)

        # Check if the message was logged
        @test length(swarm.communication_log) > 0
    end

    @testset "OpenAI Swarm Integration" begin
        # Skip this test if OPENAI_API_KEY is not set
        if isempty(get(ENV, "OPENAI_API_KEY", ""))
            @info "Skipping OpenAI Swarm Integration test - OPENAI_API_KEY not set"
        else
            # Create an OpenAI swarm
            openai_config = Dict{String, Any}(
                "name" => "test_openai_swarm",
                "agents" => [
                    Dict{String, Any}(
                        "name" => "cross_chain_agent",
                        "instructions" => "You are a cross-chain optimization agent. Your task is to find the most efficient way to transfer tokens between different blockchain networks.",
                        "model" => "gpt-4o"
                    ),
                    Dict{String, Any}(
                        "name" => "security_agent",
                        "instructions" => "You are a security agent. Your task is to evaluate the security risks of cross-chain transfers and provide recommendations.",
                        "model" => "gpt-4o"
                    )
                ]
            )

            result = SwarmManager.create_openai_swarm(openai_config)
            @test result["success"] == true

            # Store the swarm ID for later use
            swarm_id = result["swarm_id"]

            # Run a task with the cross-chain agent
            task_prompt = "What is the most efficient way to transfer USDC from Ethereum to Solana?"
            task_result = SwarmManager.run_openai_swarm_task(swarm_id, "cross_chain_agent", task_prompt)
            @test task_result["success"] == true

            # Store the thread ID and run ID for later use
            thread_id = task_result["thread_id"]
            run_id = task_result["run_id"]

            # Wait for the task to complete (in a real application, you would poll for completion)
            @info "Waiting for OpenAI task to complete..."
            sleep(10)

            # Get the response
            response = SwarmManager.get_openai_swarm_response(swarm_id, thread_id, run_id)

            # The task might not be completed yet, so we just check if the response has the expected structure
            @test haskey(response, "status")
        end
    end

    @testset "Differential Evolution Integration" begin
        # Create a swarm with DE algorithm
        swarm_config = SwarmManager.SwarmManagerConfig(
            "test_de_swarm_$(rand(1:1000))",
            Dict{String, Any}(
                "type" => "de",
                "params" => Dict{String, Any}(
                    "crossover_rate" => 0.8,
                    "differential_weight" => 0.7,
                    "strategy" => "DE/rand/1/bin"
                ),
                "coordination_strategy" => "competitive"
            ),
            20, # num_particles
            100, # num_iterations
            ["ETH/USDC", "BTC/USDC"]
        )

        swarm = SwarmManager.create_swarm(swarm_config)
        @test swarm !== nothing
        @test swarm.algorithm isa JuliaOS.Algorithms.DE.DEAlgorithm

        # Initialize the algorithm
        dimension = 4
        bounds = [
            (0.0, 1.0),    # entry_threshold
            (0.0, 1.0),    # exit_threshold
            (0.01, 0.2),   # stop_loss
            (0.01, 0.5)    # take_profit
        ]

        JuliaOS.Algorithms.initialize!(swarm.algorithm, swarm_config.num_particles, dimension, bounds)

        # Add agents to the swarm
        for i in 1:5
            agent_id = "agent_$(i)_$(rand(1:1000))"
            agent_type = "cross_chain_optimizer"
            capabilities = ["cross_chain", "optimization"]

            @test SwarmManager.add_agent_to_swarm!(swarm, agent_id, agent_type, capabilities)

            # Assign a random position and fitness to each agent
            swarm.agents[i]["position"] = [rand(bounds[j][1]:0.01:bounds[j][2]) for j in 1:dimension]
            swarm.agents[i]["fitness"] = rand() * 10.0
        end

        # Test agent coordination with competitive strategy
        @test SwarmManager.coordinate_agents!(swarm)

        # Check if coordination updated the agents
        for agent in swarm.agents
            @test haskey(agent, "status")
        end

        # Check if a decision was made
        @test haskey(swarm.decisions, "latest")
    end
end

println("All swarm integration tests passed!")
