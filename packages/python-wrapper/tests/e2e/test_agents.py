"""
End-to-end tests for agent functionality.
"""

import asyncio
import pytest
import uuid
from juliaos.agents import AgentType


@pytest.mark.asyncio
async def test_agent_lifecycle(juliaos_client, clean_storage):
    """
    Test the complete lifecycle of an agent.
    """
    # Create an agent
    agent_id = str(uuid.uuid4())
    agent_name = "Test Agent"
    agent_type = AgentType.TRADING
    agent_config = {
        "parameters": {
            "risk_tolerance": 0.5,
            "max_position_size": 1000.0
        }
    }
    
    agent = await juliaos_client.agents.create_agent(
        name=agent_name,
        agent_type=agent_type,
        config=agent_config,
        agent_id=agent_id
    )
    
    # Verify agent was created correctly
    assert agent.id == agent_id
    assert agent.name == agent_name
    assert agent.type == agent_type.value
    assert agent.status == "CREATED"
    
    # Start the agent
    await agent.start()
    assert agent.status == "RUNNING"
    
    # Pause the agent
    await agent.pause()
    assert agent.status == "PAUSED"
    
    # Resume the agent
    await agent.resume()
    assert agent.status == "RUNNING"
    
    # Execute a task
    task = await agent.execute_task({
        "type": "test",
        "parameters": {"param1": "value1", "param2": 42}
    })
    
    # Verify task was created
    assert task.id is not None
    assert task.agent_id == agent_id
    
    # Get task status
    status = await agent.get_task_status(task.id)
    assert status is not None
    
    # Stop the agent
    await agent.stop()
    assert agent.status == "STOPPED"
    
    # Delete the agent
    await agent.delete()
    
    # Verify agent was deleted
    with pytest.raises(Exception):
        await juliaos_client.agents.get_agent(agent_id)


@pytest.mark.asyncio
async def test_agent_memory(juliaos_client, clean_storage):
    """
    Test agent memory operations.
    """
    # Create an agent
    agent = await juliaos_client.agents.create_agent(
        name="Memory Test Agent",
        agent_type=AgentType.GENERIC,
        config={"parameters": {}}
    )
    
    # Start the agent
    await agent.start()
    
    # Set memory
    test_data = {"key1": "value1", "key2": 42, "key3": [1, 2, 3]}
    await agent.set_memory("test_data", test_data)
    
    # Get memory
    memory = await agent.get_memory("test_data")
    assert memory == test_data
    
    # Update memory
    updated_data = {"key1": "updated", "key4": True}
    await agent.set_memory("test_data", updated_data)
    
    # Verify update
    updated_memory = await agent.get_memory("test_data")
    assert updated_memory["key1"] == "updated"
    assert updated_memory["key4"] == True
    
    # Delete memory
    await agent.delete_memory("test_data")
    
    # Verify memory was deleted
    with pytest.raises(Exception):
        await agent.get_memory("test_data")
    
    # Clean up
    await agent.delete()


@pytest.mark.asyncio
async def test_trading_agent(juliaos_client, clean_storage):
    """
    Test trading agent functionality.
    """
    # Create a trading agent
    agent = await juliaos_client.agents.create_agent(
        name="Trading Test Agent",
        agent_type=AgentType.TRADING,
        config={
            "parameters": {
                "risk_tolerance": 0.5,
                "max_position_size": 1000.0,
                "take_profit": 0.05,
                "stop_loss": 0.03
            }
        }
    )
    
    # Start the agent
    await agent.start()
    
    # Initialize trading agent
    init_result = await agent.initialize()
    assert init_result["success"] == True
    
    # Test market analysis
    market_data = {
        "BTC": {
            "prices": [50000.0, 51000.0, 52000.0, 51500.0, 52500.0],
            "volumes": [1000.0, 1100.0, 1200.0, 1150.0, 1250.0]
        },
        "ETH": {
            "prices": [3000.0, 3100.0, 3050.0, 3150.0, 3200.0],
            "volumes": [2000.0, 2100.0, 2050.0, 2150.0, 2200.0]
        }
    }
    
    analysis_result = await agent.analyze_market(market_data)
    assert analysis_result["success"] == True
    assert "analysis" in analysis_result
    
    # Test portfolio management
    portfolio_result = await agent.get_portfolio()
    assert portfolio_result["success"] == True
    assert "portfolio" in portfolio_result
    
    # Test strategy setting
    strategy_result = await agent.set_strategy("momentum")
    assert strategy_result["success"] == True
    assert strategy_result["strategy"] == "momentum"
    
    # Clean up
    await agent.delete()


@pytest.mark.asyncio
async def test_monitor_agent(juliaos_client, clean_storage):
    """
    Test monitor agent functionality.
    """
    # Create a monitor agent
    agent = await juliaos_client.agents.create_agent(
        name="Monitor Test Agent",
        agent_type=AgentType.MONITOR,
        config={
            "parameters": {
                "check_interval": 60,
                "alert_channels": ["console"],
                "max_alerts_per_hour": 10
            }
        }
    )
    
    # Start the agent
    await agent.start()
    
    # Initialize monitor agent
    init_result = await agent.initialize()
    assert init_result["success"] == True
    
    # Configure alerts
    alert_configs = [
        {
            "asset": "BTC",
            "condition_type": "price_above",
            "condition": "Price above threshold",
            "threshold": 55000.0,
            "message": "BTC price is above $55,000"
        },
        {
            "asset": "ETH",
            "condition_type": "price_below",
            "condition": "Price below threshold",
            "threshold": 2800.0,
            "message": "ETH price is below $2,800"
        }
    ]
    
    config_result = await agent.configure_alerts(alert_configs)
    assert config_result["success"] == True
    assert len(config_result["alerts"]) == 2
    
    # Check conditions
    market_data = {
        "BTC": {"price": 56000.0, "volume": 1000.0},
        "ETH": {"price": 3000.0, "volume": 2000.0}
    }
    
    check_result = await agent.check_conditions(market_data)
    assert check_result["success"] == True
    assert "triggered_alerts" in check_result
    
    # Get alerts
    alerts_result = await agent.get_alerts()
    assert alerts_result["success"] == True
    assert "active_alerts" in alerts_result
    
    # Clean up
    await agent.delete()


@pytest.mark.asyncio
async def test_agent_collaboration(juliaos_client, clean_storage):
    """
    Test agent collaboration functionality.
    """
    # Create two agents
    agent1 = await juliaos_client.agents.create_agent(
        name="Collaboration Test Agent 1",
        agent_type=AgentType.TRADING,
        config={"parameters": {}}
    )
    
    agent2 = await juliaos_client.agents.create_agent(
        name="Collaboration Test Agent 2",
        agent_type=AgentType.MONITOR,
        config={"parameters": {}}
    )
    
    # Start the agents
    await agent1.start()
    await agent2.start()
    
    # Send a message from agent1 to agent2
    message_content = {
        "type": "text",
        "text": "Hello from Agent 1!"
    }
    
    send_result = await juliaos_client.bridge.execute("AgentMessaging.send_message", [
        agent1.id,
        agent2.id,
        message_content
    ])
    
    assert send_result["success"] == True
    assert "message_id" in send_result
    
    # Get messages for agent2
    messages_result = await juliaos_client.bridge.execute("AgentMessaging.get_messages", [
        agent2.id
    ])
    
    assert messages_result["success"] == True
    assert len(messages_result["messages"]) > 0
    
    # Create a team
    team_name = "Test Team"
    team_desc = "A test collaboration team"
    team_members = [agent2.id]
    
    team_result = await juliaos_client.bridge.execute("AgentCollaboration.create_team", [
        agent1.id,
        team_name,
        team_desc,
        team_members
    ])
    
    assert team_result["success"] == True
    assert "team_id" in team_result
    
    # Clean up
    await agent1.delete()
    await agent2.delete()
