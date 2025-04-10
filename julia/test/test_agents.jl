using Test
using Dates
using JSON
using UUIDs

# Import modules to test
using Agents
using Agents.TradingAgent
using Agents.MonitorAgent
using Agents.ArbitrageAgent
using Agents.LLMIntegration
using Agents.AgentMessaging
using Agents.AgentCollaboration
using Agents.AgentBlockchainIntegration

function run_agent_tests()
    @testset "Agent Creation and Management" begin
        # Test agent creation
        agent_id = string(uuid4())
        agent_name = "Test Agent"
        agent_type = Agents.AgentType.TRADING
        agent_config = Dict(
            "parameters" => Dict(
                "risk_tolerance" => 0.5,
                "max_position_size" => 1000.0
            )
        )
        
        result = Agents.createAgent(agent_id, agent_name, agent_type, agent_config)
        @test result["success"] == true
        @test result["agent"]["id"] == agent_id
        @test result["agent"]["name"] == agent_name
        @test result["agent"]["type"] == agent_type
        
        # Test getting agent
        agent = Agents.getAgent(agent_id)
        @test agent !== nothing
        @test agent.id == agent_id
        @test agent.name == agent_name
        @test agent.type == agent_type
        
        # Test starting agent
        start_result = Agents.startAgent(agent_id)
        @test start_result["success"] == true
        @test start_result["agent"]["status"] == Agents.AgentStatus.RUNNING
        
        # Test pausing agent
        pause_result = Agents.pauseAgent(agent_id)
        @test pause_result["success"] == true
        @test pause_result["agent"]["status"] == Agents.AgentStatus.PAUSED
        
        # Test resuming agent
        resume_result = Agents.resumeAgent(agent_id)
        @test resume_result["success"] == true
        @test resume_result["agent"]["status"] == Agents.AgentStatus.RUNNING
        
        # Test stopping agent
        stop_result = Agents.stopAgent(agent_id)
        @test stop_result["success"] == true
        @test stop_result["agent"]["status"] == Agents.AgentStatus.STOPPED
        
        # Test deleting agent
        delete_result = Agents.deleteAgent(agent_id)
        @test delete_result["success"] == true
        
        # Verify agent is deleted
        deleted_agent = Agents.getAgent(agent_id)
        @test deleted_agent === nothing
    end
    
    @testset "Agent Memory Management" begin
        # Create test agent
        agent_id = string(uuid4())
        agent_name = "Memory Test Agent"
        agent_type = Agents.AgentType.TRADING
        agent_config = Dict("parameters" => Dict())
        
        Agents.createAgent(agent_id, agent_name, agent_type, agent_config)
        Agents.startAgent(agent_id)
        
        # Test setting memory
        test_data = Dict("key1" => "value1", "key2" => 42, "key3" => [1, 2, 3])
        set_result = Agents.setAgentMemory(agent_id, "test_data", test_data)
        @test set_result["success"] == true
        
        # Test getting memory
        memory = Agents.getAgentMemory(agent_id, "test_data")
        @test memory !== nothing
        @test memory["key1"] == "value1"
        @test memory["key2"] == 42
        @test memory["key3"] == [1, 2, 3]
        
        # Test updating memory
        updated_data = Dict("key1" => "updated", "key4" => true)
        update_result = Agents.setAgentMemory(agent_id, "test_data", updated_data)
        @test update_result["success"] == true
        
        # Verify update
        updated_memory = Agents.getAgentMemory(agent_id, "test_data")
        @test updated_memory["key1"] == "updated"
        @test updated_memory["key4"] == true
        
        # Test deleting memory
        delete_result = Agents.deleteAgentMemory(agent_id, "test_data")
        @test delete_result["success"] == true
        
        # Verify memory is deleted
        deleted_memory = Agents.getAgentMemory(agent_id, "test_data")
        @test deleted_memory === nothing
        
        # Clean up
        Agents.deleteAgent(agent_id)
    end
    
    @testset "Agent Task Execution" begin
        # Create test agent
        agent_id = string(uuid4())
        agent_name = "Task Test Agent"
        agent_type = Agents.AgentType.TRADING
        agent_config = Dict("parameters" => Dict())
        
        Agents.createAgent(agent_id, agent_name, agent_type, agent_config)
        Agents.startAgent(agent_id)
        
        # Define a simple task
        task_data = Dict(
            "type" => "test",
            "parameters" => Dict("param1" => "value1", "param2" => 42)
        )
        
        # Execute task
        task_result = Agents.executeTask(agent_id, task_data)
        @test task_result["success"] == true
        @test haskey(task_result, "task_id")
        
        # Get task status
        task_id = task_result["task_id"]
        status_result = Agents.getTaskStatus(agent_id, task_id)
        @test status_result["success"] == true
        @test haskey(status_result, "status")
        
        # Clean up
        Agents.deleteAgent(agent_id)
    end
    
    @testset "Trading Agent" begin
        # Create trading agent
        agent_id = string(uuid4())
        agent_name = "Trading Test Agent"
        agent_type = Agents.AgentType.TRADING
        agent_config = Dict(
            "parameters" => Dict(
                "risk_tolerance" => 0.5,
                "max_position_size" => 1000.0,
                "take_profit" => 0.05,
                "stop_loss" => 0.03
            )
        )
        
        Agents.createAgent(agent_id, agent_name, agent_type, agent_config)
        Agents.startAgent(agent_id)
        
        # Initialize trading agent
        init_result = TradingAgent.initialize(agent_id)
        @test init_result["success"] == true
        
        # Test market analysis
        market_data = Dict(
            "BTC" => Dict(
                "prices" => [50000.0, 51000.0, 52000.0, 51500.0, 52500.0],
                "volumes" => [1000.0, 1100.0, 1200.0, 1150.0, 1250.0]
            ),
            "ETH" => Dict(
                "prices" => [3000.0, 3100.0, 3050.0, 3150.0, 3200.0],
                "volumes" => [2000.0, 2100.0, 2050.0, 2150.0, 2200.0]
            )
        )
        
        analysis_result = TradingAgent.analyze_market(agent_id, market_data)
        @test analysis_result["success"] == true
        @test haskey(analysis_result, "analysis")
        
        # Test portfolio management
        portfolio_result = TradingAgent.get_portfolio(agent_id)
        @test portfolio_result["success"] == true
        @test haskey(portfolio_result, "portfolio")
        
        # Test strategy setting
        strategy_result = TradingAgent.set_strategy(agent_id, "momentum")
        @test strategy_result["success"] == true
        @test strategy_result["strategy"] == "momentum"
        
        # Clean up
        Agents.deleteAgent(agent_id)
    end
    
    @testset "Monitor Agent" begin
        # Create monitor agent
        agent_id = string(uuid4())
        agent_name = "Monitor Test Agent"
        agent_type = Agents.AgentType.MONITOR
        agent_config = Dict(
            "parameters" => Dict(
                "check_interval" => 60,
                "alert_channels" => ["console"],
                "max_alerts_per_hour" => 10
            )
        )
        
        Agents.createAgent(agent_id, agent_name, agent_type, agent_config)
        Agents.startAgent(agent_id)
        
        # Initialize monitor agent
        init_result = MonitorAgent.initialize(agent_id)
        @test init_result["success"] == true
        
        # Configure alerts
        alert_configs = [
            Dict(
                "asset" => "BTC",
                "condition_type" => "price_above",
                "condition" => "Price above threshold",
                "threshold" => 55000.0,
                "message" => "BTC price is above \$55,000"
            ),
            Dict(
                "asset" => "ETH",
                "condition_type" => "price_below",
                "condition" => "Price below threshold",
                "threshold" => 2800.0,
                "message" => "ETH price is below \$2,800"
            )
        ]
        
        config_result = MonitorAgent.configure_alerts(agent_id, alert_configs)
        @test config_result["success"] == true
        @test length(config_result["alerts"]) == 2
        
        # Check conditions
        market_data = Dict(
            "BTC" => Dict("price" => 56000.0, "volume" => 1000.0),
            "ETH" => Dict("price" => 3000.0, "volume" => 2000.0)
        )
        
        check_result = MonitorAgent.check_conditions(agent_id, market_data)
        @test check_result["success"] == true
        @test haskey(check_result, "triggered_alerts")
        
        # Get alerts
        alerts_result = MonitorAgent.get_alerts(agent_id)
        @test alerts_result["success"] == true
        @test haskey(alerts_result, "active_alerts")
        
        # Clean up
        Agents.deleteAgent(agent_id)
    end
    
    @testset "Arbitrage Agent" begin
        # Create arbitrage agent
        agent_id = string(uuid4())
        agent_name = "Arbitrage Test Agent"
        agent_type = Agents.AgentType.ARBITRAGE
        agent_config = Dict(
            "parameters" => Dict(
                "min_profit_threshold" => 0.01,
                "max_position_size" => 1000.0,
                "gas_cost_buffer" => 0.005,
                "chains" => ["ethereum", "solana"]
            )
        )
        
        Agents.createAgent(agent_id, agent_name, agent_type, agent_config)
        Agents.startAgent(agent_id)
        
        # Initialize arbitrage agent
        init_result = ArbitrageAgent.initialize(agent_id)
        @test init_result["success"] == true
        
        # Find opportunities
        market_data = Dict(
            "BTC" => Dict(
                "ethereum" => Dict(
                    "binance" => Dict("price" => 50000.0),
                    "coinbase" => Dict("price" => 50200.0)
                ),
                "solana" => Dict(
                    "raydium" => Dict("price" => 50300.0)
                )
            ),
            "ETH" => Dict(
                "ethereum" => Dict(
                    "uniswap" => Dict("price" => 3000.0),
                    "sushiswap" => Dict("price" => 3020.0)
                ),
                "solana" => Dict(
                    "raydium" => Dict("price" => 3050.0)
                )
            )
        )
        
        opps_result = ArbitrageAgent.find_opportunities(agent_id, market_data)
        @test opps_result["success"] == true
        @test haskey(opps_result, "opportunities")
        
        # Get history
        history_result = ArbitrageAgent.get_history(agent_id)
        @test history_result["success"] == true
        @test haskey(history_result, "history")
        
        # Set parameters
        params_result = ArbitrageAgent.set_parameters(agent_id, Dict("min_profit_threshold" => 0.02))
        @test params_result["success"] == true
        @test params_result["parameters"]["min_profit_threshold"] == 0.02
        
        # Clean up
        Agents.deleteAgent(agent_id)
    end
    
    @testset "LLM Integration" begin
        # Initialize LLM
        llm_config = Dict(
            "provider" => "local",
            "model" => "local-simulation"
        )
        
        init_result = LLMIntegration.initialize_llm(llm_config)
        @test init_result["success"] == true
        @test init_result["provider"] == "local"
        
        # Generate response
        prompt = "What is the capital of France?"
        response_result = LLMIntegration.generate_response(prompt)
        @test response_result["success"] == true
        @test haskey(response_result, "text")
        
        # Generate structured output
        output_schema = Dict(
            "answer" => "The answer",
            "confidence" => 0.9
        )
        
        structured_result = LLMIntegration.generate_structured_output(prompt, output_schema)
        @test structured_result["success"] == true
        @test haskey(structured_result, "data")
        
        # Analyze text
        text = "I love this product! It's amazing and works perfectly."
        analysis_result = LLMIntegration.analyze_text(text, "sentiment")
        @test analysis_result["success"] == true
        @test haskey(analysis_result, "data")
    end
    
    @testset "Agent Messaging" begin
        # Create two test agents
        agent1_id = string(uuid4())
        agent1_name = "Messaging Test Agent 1"
        agent1_type = Agents.AgentType.TRADING
        
        agent2_id = string(uuid4())
        agent2_name = "Messaging Test Agent 2"
        agent2_type = Agents.AgentType.MONITOR
        
        Agents.createAgent(agent1_id, agent1_name, agent1_type, Dict("parameters" => Dict()))
        Agents.createAgent(agent2_id, agent2_name, agent2_type, Dict("parameters" => Dict()))
        
        Agents.startAgent(agent1_id)
        Agents.startAgent(agent2_id)
        
        # Send message
        message_content = Dict(
            "type" => "text",
            "text" => "Hello from Agent 1!"
        )
        
        send_result = AgentMessaging.send_message(agent1_id, agent2_id, message_content)
        @test send_result["success"] == true
        @test haskey(send_result, "message_id")
        
        # Get messages
        messages_result = AgentMessaging.get_messages(agent2_id)
        @test messages_result["success"] == true
        @test length(messages_result["messages"]) > 0
        
        # Mark as read
        message_id = messages_result["messages"][1]["id"]
        read_result = AgentMessaging.mark_as_read(agent2_id, message_id)
        @test read_result["success"] == true
        
        # Create channel
        channel_name = "Test Channel"
        channel_desc = "A test communication channel"
        
        channel_result = AgentMessaging.create_channel(agent1_id, channel_name, channel_desc)
        @test channel_result["success"] == true
        @test haskey(channel_result, "channel_id")
        
        # Join channel
        channel_id = channel_result["channel_id"]
        join_result = AgentMessaging.join_channel(agent2_id, channel_id)
        @test join_result["success"] == true
        
        # Broadcast to channel
        broadcast_content = Dict(
            "type" => "announcement",
            "text" => "Attention all agents!"
        )
        
        broadcast_result = AgentMessaging.broadcast_to_channel(agent1_id, channel_id, broadcast_content)
        @test broadcast_result["success"] == true
        
        # Get channel messages
        channel_messages = AgentMessaging.get_channel_messages(agent2_id, channel_id)
        @test channel_messages["success"] == true
        @test length(channel_messages["messages"]) > 0
        
        # Leave channel
        leave_result = AgentMessaging.leave_channel(agent2_id, channel_id)
        @test leave_result["success"] == true
        
        # Clean up
        Agents.deleteAgent(agent1_id)
        Agents.deleteAgent(agent2_id)
    end
    
    @testset "Agent Collaboration" begin
        # Create test agents
        agent1_id = string(uuid4())
        agent1_name = "Collaboration Test Agent 1"
        agent1_type = Agents.AgentType.TRADING
        
        agent2_id = string(uuid4())
        agent2_name = "Collaboration Test Agent 2"
        agent2_type = Agents.AgentType.MONITOR
        
        Agents.createAgent(agent1_id, agent1_name, agent1_type, Dict("parameters" => Dict()))
        Agents.createAgent(agent2_id, agent2_name, agent2_type, Dict("parameters" => Dict()))
        
        Agents.startAgent(agent1_id)
        Agents.startAgent(agent2_id)
        
        # Create team
        team_name = "Test Team"
        team_desc = "A test collaboration team"
        team_members = [agent2_id]
        
        team_result = AgentCollaboration.create_team(agent1_id, team_name, team_desc, team_members)
        @test team_result["success"] == true
        @test haskey(team_result, "team_id")
        
        # Get team
        team_id = team_result["team_id"]
        get_team_result = AgentCollaboration.get_team(team_id)
        @test get_team_result["success"] == true
        @test get_team_result["team"]["name"] == team_name
        
        # Assign task
        task_title = "Test Task"
        task_desc = "A test collaboration task"
        due_date = string(now() + Dates.Day(1))
        priority = 3
        
        task_result = AgentCollaboration.assign_task(
            team_id, agent1_id, agent2_id, task_title, task_desc, due_date, priority
        )
        @test task_result["success"] == true
        @test haskey(task_result, "task_id")
        
        # Get task
        task_id = task_result["task_id"]
        get_task_result = AgentCollaboration.get_task(team_id, task_id)
        @test get_task_result["success"] == true
        @test get_task_result["task"]["title"] == task_title
        
        # Update task status
        status_result = AgentCollaboration.update_task_status(
            team_id, task_id, agent2_id, Int(AgentCollaboration.TaskStatus.IN_PROGRESS), "Working on it"
        )
        @test status_result["success"] == true
        
        # Get agent tasks
        agent_tasks = AgentCollaboration.get_agent_tasks(agent2_id)
        @test agent_tasks["success"] == true
        @test length(agent_tasks["tasks"]) > 0
        
        # Share data
        share_result = AgentCollaboration.share_data(
            team_id, agent2_id, "test_data", Dict("key" => "value")
        )
        @test share_result["success"] == true
        
        # Get shared data
        shared_data = AgentCollaboration.get_shared_data(team_id, agent1_id, "test_data")
        @test shared_data["success"] == true
        @test shared_data["data"]["key"] == "value"
        
        # Clean up
        Agents.deleteAgent(agent1_id)
        Agents.deleteAgent(agent2_id)
    end
    
    @testset "Agent Blockchain Integration" begin
        # Create test agent
        agent_id = string(uuid4())
        agent_name = "Blockchain Test Agent"
        agent_type = Agents.AgentType.TRADING
        agent_config = Dict(
            "parameters" => Dict(
                "chains" => ["ethereum", "solana"]
            )
        )
        
        Agents.createAgent(agent_id, agent_name, agent_type, agent_config)
        Agents.startAgent(agent_id)
        
        # Initialize blockchain integration
        init_result = AgentBlockchainIntegration.initialize(agent_id)
        @test init_result["success"] == true
        
        # Create test wallet
        wallet_id = string(uuid4())
        wallet_result = Wallet.create_wallet(wallet_id, "Test Wallet")
        
        if wallet_result["success"]
            # Assign wallet to agent
            assign_result = AgentBlockchainIntegration.assign_wallet(agent_id, wallet_id, "ethereum")
            @test assign_result["success"] == true
            
            # Get agent wallet
            wallet_info = AgentBlockchainIntegration.get_agent_wallet(agent_id, "ethereum")
            @test wallet_info["success"] == true
            @test wallet_info["wallet"]["id"] == wallet_id
            
            # Monitor blockchain
            monitor_result = AgentBlockchainIntegration.monitor_blockchain(
                agent_id, "ethereum", ["block", "transaction"]
            )
            @test monitor_result["success"] == true
            
            # Clean up
            Wallet.delete_wallet(wallet_id)
        end
        
        # Clean up
        Agents.deleteAgent(agent_id)
    end
end
