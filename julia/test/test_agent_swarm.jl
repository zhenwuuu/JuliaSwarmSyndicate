#!/usr/bin/env julia

# Test script for Agent and Swarm Management systems

# Add the julia directory to the load path
push!(LOAD_PATH, joinpath(pwd(), "julia", "src"))

# Import the modules
using AgentSystem
using SwarmManager
using Algorithms
using Dates
using UUIDs

println("Starting Agent and Swarm Management test...")

# Create agents with different roles
function create_test_agents()
    println("\n=== Creating Test Agents ===")

    # Create a trading agent
    trading_agent_config = AgentConfig(
        string(UUIDs.uuid4())[1:8],
        "Trading Agent",
        "trading",
        ["trading", "analysis", "execution"],
        Dict("blockchain" => Dict("chain" => "ethereum", "network" => "mainnet"))
    )

    trading_agent = create_agent(trading_agent_config)
    println("Created trading agent: $(trading_agent.config.id)")

    # Create a monitoring agent
    monitoring_agent_config = AgentConfig(
        string(UUIDs.uuid4())[1:8],
        "Monitoring Agent",
        "monitoring",
        ["monitoring", "analysis", "notification"],
        Dict("api" => Dict("type" => "rest", "endpoint" => "https://api.example.com"))
    )

    monitoring_agent = create_agent(monitoring_agent_config)
    println("Created monitoring agent: $(monitoring_agent.config.id)")

    # Create a communication agent
    communication_agent_config = AgentConfig(
        string(UUIDs.uuid4())[1:8],
        "Communication Agent",
        "communication",
        ["communication", "coordination"],
        Dict("messaging" => Dict("type" => "internal"))
    )

    communication_agent = create_agent(communication_agent_config)
    println("Created communication agent: $(communication_agent.config.id)")

    return [trading_agent, monitoring_agent, communication_agent]
end

# Create a swarm
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
    swarm = create_swarm(swarm_config, "ethereum", "uniswap-v3")
    println("Created swarm: $(swarm.swarm_object.config.name) ($(swarm.swarm_object.config.id))")

    return swarm
end

# Add agents to swarm
function add_agents_to_swarm(agents, swarm)
    println("\n=== Adding Agents to Swarm ===")

    for agent in agents
        success = add_agent_to_swarm(agent.config.id, swarm.swarm_object.config.id)
        if success
            println("Added agent $(agent.config.id) to swarm $(swarm.swarm_object.config.id)")
        else
            println("Failed to add agent $(agent.config.id) to swarm $(swarm.swarm_object.config.id)")
        end
    end
end

# Start agents and swarm
function start_agents_and_swarm(agents, swarm)
    println("\n=== Starting Agents and Swarm ===")

    # Start agents
    for agent in agents
        success = update_agent_status(agent.config.id, "active")
        if success
            println("Started agent $(agent.config.id)")
        else
            println("Failed to start agent $(agent.config.id)")
        end
    end

    # Start swarm
    success = update_swarm_status(swarm.swarm_object.config.id, "active")
    if success
        println("Started swarm $(swarm.swarm_object.config.id)")
    else
        println("Failed to start swarm $(swarm.swarm_object.config.id)")
    end
end

# Send messages between agents
function send_test_messages(agents)
    println("\n=== Sending Test Messages ===")

    # Get the first agent as sender and second as receiver
    sender = agents[1]
    receiver = agents[2]

    # Create a status request message
    status_message = AgentMessage(
        sender.config.id,
        receiver.config.id,
        "command",
        Dict("command" => "status"),
        3,
        true,
        nothing,
        60,
        Dict()
    )

    # Send the message
    result = handle_message(receiver.config.id, status_message)
    println("Sent status request from $(sender.config.id) to $(receiver.config.id)")
    println("Response: ", result)

    # Create a market data message
    market_data_message = AgentMessage(
        sender.config.id,
        receiver.config.id,
        "data",
        Dict(
            "data_type" => "market_data",
            "data" => Dict(
                "symbol" => "BTC/USDT",
                "price" => 50000.0,
                "volume" => 1000.0,
                "timestamp" => now()
            )
        ),
        3,
        false,
        nothing,
        60,
        Dict()
    )

    # Send the message
    result = handle_message(receiver.config.id, market_data_message)
    println("Sent market data from $(sender.config.id) to $(receiver.config.id)")
    println("Response: ", result)
end

# Execute skills
function execute_test_skills(agents)
    println("\n=== Executing Test Skills ===")

    # Execute status report skill for the first agent
    trading_agent = agents[1]
    result = execute_skill(trading_agent.config.id, "status_report")
    println("Executed status_report skill for agent $(trading_agent.config.id)")
    println("Result: ", result)

    # Execute market analysis skill for the first agent
    result = execute_skill(trading_agent.config.id, "market_analysis", Dict("timeframe" => "4h", "indicators" => ["ma", "rsi", "macd"]))
    println("Executed market_analysis skill for agent $(trading_agent.config.id)")
    println("Result: ", result)

    # Execute trade skill for the first agent
    result = execute_skill(trading_agent.config.id, "execute_trade", Dict("action" => "buy", "symbol" => "ETH/USDT", "amount" => 0.1))
    println("Executed execute_trade skill for agent $(trading_agent.config.id)")
    println("Result: ", result)
end

# Stop agents and swarm
function stop_agents_and_swarm(agents, swarm)
    println("\n=== Stopping Agents and Swarm ===")

    # Stop swarm
    success = update_swarm_status(swarm.swarm_object.config.id, "inactive")
    if success
        println("Stopped swarm $(swarm.swarm_object.config.id)")
    else
        println("Failed to stop swarm $(swarm.swarm_object.config.id)")
    end

    # Stop agents
    for agent in agents
        success = update_agent_status(agent.config.id, "inactive")
        if success
            println("Stopped agent $(agent.config.id)")
        else
            println("Failed to stop agent $(agent.config.id)")
        end
    end
end

# Clean up
function cleanup(agents, swarm)
    println("\n=== Cleaning Up ===")

    # Remove agents from swarm
    for agent in agents
        if agent.swarm_id !== nothing
            success = remove_agent_from_swarm(agent.config.id, swarm.swarm_object.config.id)
            if success
                println("Removed agent $(agent.config.id) from swarm $(swarm.swarm_object.config.id)")
            else
                println("Failed to remove agent $(agent.config.id) from swarm $(swarm.swarm_object.config.id)")
            end
        end
    end

    # Delete agents
    for agent in agents
        success = delete_agent(agent.config.id)
        if success
            println("Deleted agent $(agent.config.id)")
        else
            println("Failed to delete agent $(agent.config.id)")
        end
    end

    # Delete swarm
    success = delete_swarm(swarm.swarm_object.config.id)
    if success
        println("Deleted swarm $(swarm.swarm_object.config.id)")
    else
        println("Failed to delete swarm $(swarm.swarm_object.config.id)")
    end
end

# Run the test
function run_test()
    try
        # Create agents
        agents = create_test_agents()

        # Create swarm
        swarm = create_test_swarm()

        # Add agents to swarm
        add_agents_to_swarm(agents, swarm)

        # Start agents and swarm
        start_agents_and_swarm(agents, swarm)

        # Wait a bit for everything to start
        println("\nWaiting for 2 seconds for everything to start...")
        sleep(2)

        # Send messages between agents
        send_test_messages(agents)

        # Execute skills
        execute_test_skills(agents)

        # Wait a bit to see the results
        println("\nWaiting for 2 seconds to see the results...")
        sleep(2)

        # Stop agents and swarm
        stop_agents_and_swarm(agents, swarm)

        # Clean up
        cleanup(agents, swarm)

        println("\nTest completed successfully!")
    catch e
        println("\nTest failed: $e")
        println(stacktrace(catch_backtrace()))
    end
end

# Run the test
run_test()
