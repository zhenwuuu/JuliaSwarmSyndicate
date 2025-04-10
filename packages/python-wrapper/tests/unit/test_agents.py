"""
Unit tests for the agents module.
"""

import asyncio
import pytest
from unittest.mock import MagicMock, patch
from juliaos.agents import AgentManager, Agent, AgentType
from juliaos.exceptions import AgentError, ResourceNotFoundError


@pytest.fixture
def mock_bridge():
    """
    Create a mock JuliaBridge.
    """
    bridge = MagicMock()
    bridge.execute = MagicMock(return_value=asyncio.Future())
    return bridge


@pytest.fixture
def agent_manager(mock_bridge):
    """
    Create an AgentManager instance with a mock bridge.
    """
    return AgentManager(mock_bridge)


@pytest.mark.asyncio
async def test_create_agent_success(agent_manager, mock_bridge):
    """
    Test successful agent creation.
    """
    # Set up mock response
    mock_bridge.execute.return_value.set_result({
        "success": True,
        "agent": {
            "id": "test_id",
            "name": "Test Agent",
            "type": "TRADING",
            "status": "CREATED",
            "config": {"parameters": {"risk_tolerance": 0.5}}
        }
    })
    
    # Create agent
    agent = await agent_manager.create_agent(
        name="Test Agent",
        agent_type=AgentType.TRADING,
        config={"parameters": {"risk_tolerance": 0.5}},
        agent_id="test_id"
    )
    
    # Verify
    assert agent.id == "test_id"
    assert agent.name == "Test Agent"
    assert agent.type == "TRADING"
    assert agent.status == "CREATED"
    mock_bridge.execute.assert_called_once_with("Agents.createAgent", [
        "test_id",
        "Test Agent",
        "TRADING",
        {"parameters": {"risk_tolerance": 0.5}}
    ])


@pytest.mark.asyncio
async def test_create_agent_failure(agent_manager, mock_bridge):
    """
    Test agent creation failure.
    """
    # Set up mock response
    mock_bridge.execute.return_value.set_result({
        "success": False,
        "error": "Agent creation failed"
    })
    
    # Create agent
    with pytest.raises(AgentError) as excinfo:
        await agent_manager.create_agent(
            name="Test Agent",
            agent_type=AgentType.TRADING,
            config={"parameters": {}},
            agent_id="test_id"
        )
    
    # Verify
    assert "Agent creation failed" in str(excinfo.value)
    mock_bridge.execute.assert_called_once()


@pytest.mark.asyncio
async def test_get_agent_success(agent_manager, mock_bridge):
    """
    Test successful agent retrieval.
    """
    # Set up mock response
    mock_bridge.execute.return_value.set_result({
        "id": "test_id",
        "name": "Test Agent",
        "type": "TRADING",
        "status": "RUNNING",
        "config": {"parameters": {}}
    })
    
    # Get agent
    agent = await agent_manager.get_agent("test_id")
    
    # Verify
    assert agent.id == "test_id"
    assert agent.name == "Test Agent"
    assert agent.type == "TRADING"
    assert agent.status == "RUNNING"
    mock_bridge.execute.assert_called_once_with("Agents.getAgent", ["test_id"])


@pytest.mark.asyncio
async def test_get_agent_not_found(agent_manager, mock_bridge):
    """
    Test agent retrieval when agent is not found.
    """
    # Set up mock response
    mock_bridge.execute.return_value.set_result(None)
    
    # Get agent
    with pytest.raises(ResourceNotFoundError) as excinfo:
        await agent_manager.get_agent("test_id")
    
    # Verify
    assert "Agent not found" in str(excinfo.value)
    mock_bridge.execute.assert_called_once()


@pytest.mark.asyncio
async def test_list_agents(agent_manager, mock_bridge):
    """
    Test listing agents.
    """
    # Set up mock response
    mock_bridge.execute.return_value.set_result({
        "agents": [
            {
                "id": "agent1",
                "name": "Agent 1",
                "type": "TRADING",
                "status": "RUNNING"
            },
            {
                "id": "agent2",
                "name": "Agent 2",
                "type": "MONITOR",
                "status": "STOPPED"
            }
        ]
    })
    
    # List agents
    agents = await agent_manager.list_agents()
    
    # Verify
    assert len(agents) == 2
    assert agents[0].id == "agent1"
    assert agents[0].name == "Agent 1"
    assert agents[0].type == "TRADING"
    assert agents[1].id == "agent2"
    assert agents[1].name == "Agent 2"
    assert agents[1].type == "MONITOR"
    mock_bridge.execute.assert_called_once_with("Agents.listAgents", [])


@pytest.mark.asyncio
async def test_delete_agent_success(agent_manager, mock_bridge):
    """
    Test successful agent deletion.
    """
    # Set up mock response
    mock_bridge.execute.return_value.set_result({
        "success": True
    })
    
    # Delete agent
    result = await agent_manager.delete_agent("test_id")
    
    # Verify
    assert result == True
    mock_bridge.execute.assert_called_once_with("Agents.deleteAgent", ["test_id"])


@pytest.mark.asyncio
async def test_delete_agent_not_found(agent_manager, mock_bridge):
    """
    Test agent deletion when agent is not found.
    """
    # Set up mock response
    mock_bridge.execute.return_value.set_result({
        "success": False,
        "error": "Agent not found"
    })
    
    # Delete agent
    with pytest.raises(ResourceNotFoundError) as excinfo:
        await agent_manager.delete_agent("test_id")
    
    # Verify
    assert "Agent not found" in str(excinfo.value)
    mock_bridge.execute.assert_called_once()


@pytest.fixture
def mock_agent():
    """
    Create a mock Agent.
    """
    bridge = MagicMock()
    bridge.execute = MagicMock(return_value=asyncio.Future())
    
    agent_data = {
        "id": "test_id",
        "name": "Test Agent",
        "type": "TRADING",
        "status": "CREATED",
        "config": {"parameters": {}}
    }
    
    return Agent(bridge, agent_data)


@pytest.mark.asyncio
async def test_agent_start(mock_agent):
    """
    Test starting an agent.
    """
    # Set up mock response
    mock_agent.bridge.execute.return_value.set_result({
        "success": True,
        "agent": {
            "id": "test_id",
            "status": "RUNNING"
        }
    })
    
    # Start agent
    result = await mock_agent.start()
    
    # Verify
    assert result == True
    assert mock_agent.status == "RUNNING"
    mock_agent.bridge.execute.assert_called_once_with("Agents.startAgent", ["test_id"])


@pytest.mark.asyncio
async def test_agent_stop(mock_agent):
    """
    Test stopping an agent.
    """
    # Set up mock response
    mock_agent.bridge.execute.return_value.set_result({
        "success": True,
        "agent": {
            "id": "test_id",
            "status": "STOPPED"
        }
    })
    
    # Stop agent
    result = await mock_agent.stop()
    
    # Verify
    assert result == True
    assert mock_agent.status == "STOPPED"
    mock_agent.bridge.execute.assert_called_once_with("Agents.stopAgent", ["test_id"])


@pytest.mark.asyncio
async def test_agent_execute_task(mock_agent):
    """
    Test executing a task on an agent.
    """
    # Set up mock response
    mock_agent.bridge.execute.return_value.set_result({
        "success": True,
        "task_id": "task_id"
    })
    
    # Execute task
    task_data = {
        "type": "test",
        "parameters": {"param1": "value1"}
    }
    
    task = await mock_agent.execute_task(task_data)
    
    # Verify
    assert task.id == "task_id"
    assert task.agent_id == "test_id"
    assert task.data == task_data
    mock_agent.bridge.execute.assert_called_once_with("Agents.executeTask", ["test_id", task_data])


@pytest.mark.asyncio
async def test_agent_set_memory(mock_agent):
    """
    Test setting agent memory.
    """
    # Set up mock response
    mock_agent.bridge.execute.return_value.set_result({
        "success": True
    })
    
    # Set memory
    key = "test_key"
    value = {"key1": "value1", "key2": 42}
    
    result = await mock_agent.set_memory(key, value)
    
    # Verify
    assert result == True
    mock_agent.bridge.execute.assert_called_once_with("Agents.setAgentMemory", ["test_id", key, value])


@pytest.mark.asyncio
async def test_agent_get_memory(mock_agent):
    """
    Test getting agent memory.
    """
    # Set up mock response
    mock_agent.bridge.execute.return_value.set_result({
        "key1": "value1",
        "key2": 42
    })
    
    # Get memory
    memory = await mock_agent.get_memory("test_key")
    
    # Verify
    assert memory == {"key1": "value1", "key2": 42}
    mock_agent.bridge.execute.assert_called_once_with("Agents.getAgentMemory", ["test_id", "test_key"])
