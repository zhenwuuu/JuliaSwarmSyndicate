"""
End-to-end tests for storage functionality.
"""

import asyncio
import pytest
import uuid
from juliaos.agents import AgentType
from juliaos.swarms import SwarmType
from juliaos.storage import StorageType


@pytest.mark.asyncio
async def test_storage_initialization(juliaos_client):
    """
    Test storage initialization.
    """
    # Initialize storage
    init_result = await juliaos_client.storage.initialize()
    assert init_result["success"] == True
    assert "local_storage_dir" in init_result


@pytest.mark.asyncio
async def test_agent_storage(juliaos_client, clean_storage):
    """
    Test agent storage operations.
    """
    # Create test data
    agent_id = str(uuid.uuid4())
    agent_name = "Storage Test Agent"
    agent_type = AgentType.TRADING
    agent_config = {
        "parameters": {
            "risk_tolerance": 0.5,
            "max_position_size": 1000.0
        }
    }
    
    # Save agent
    save_result = await juliaos_client.storage.save_agent(
        agent_id=agent_id,
        name=agent_name,
        agent_type=agent_type.value,
        config=agent_config
    )
    
    assert save_result["success"] == True
    assert save_result["id"] == agent_id
    
    # Get agent
    get_result = await juliaos_client.storage.get_agent(agent_id)
    assert get_result["success"] == True
    assert get_result["agent"]["id"] == agent_id
    assert get_result["agent"]["name"] == agent_name
    assert get_result["agent"]["type"] == agent_type.value
    
    # List agents
    list_result = await juliaos_client.storage.list_agents()
    assert list_result["success"] == True
    assert any(agent["id"] == agent_id for agent in list_result["agents"])
    
    # Update agent
    update_data = {"name": "Updated Storage Test Agent"}
    update_result = await juliaos_client.storage.update_agent(agent_id, update_data)
    assert update_result["success"] == True
    assert update_result["agent"]["name"] == "Updated Storage Test Agent"
    
    # Delete agent
    delete_result = await juliaos_client.storage.delete_agent(agent_id)
    assert delete_result["success"] == True
    
    # Verify deletion
    with pytest.raises(Exception):
        await juliaos_client.storage.get_agent(agent_id)


@pytest.mark.asyncio
async def test_swarm_storage(juliaos_client, clean_storage):
    """
    Test swarm storage operations.
    """
    # Create test data
    swarm_id = str(uuid.uuid4())
    swarm_name = "Storage Test Swarm"
    swarm_type = SwarmType.OPTIMIZATION
    algorithm = "DE"
    swarm_config = {
        "population_size": 20,
        "max_generations": 50
    }
    
    # Save swarm
    save_result = await juliaos_client.storage.save_swarm(
        swarm_id=swarm_id,
        name=swarm_name,
        swarm_type=swarm_type.value,
        algorithm=algorithm,
        config=swarm_config
    )
    
    assert save_result["success"] == True
    assert save_result["id"] == swarm_id
    
    # Get swarm
    get_result = await juliaos_client.storage.get_swarm(swarm_id)
    assert get_result["success"] == True
    assert get_result["swarm"]["id"] == swarm_id
    assert get_result["swarm"]["name"] == swarm_name
    assert get_result["swarm"]["type"] == swarm_type.value
    assert get_result["swarm"]["algorithm"] == algorithm
    
    # List swarms
    list_result = await juliaos_client.storage.list_swarms()
    assert list_result["success"] == True
    assert any(swarm["id"] == swarm_id for swarm in list_result["swarms"])
    
    # Update swarm
    update_data = {"name": "Updated Storage Test Swarm"}
    update_result = await juliaos_client.storage.update_swarm(swarm_id, update_data)
    assert update_result["success"] == True
    assert update_result["swarm"]["name"] == "Updated Storage Test Swarm"
    
    # Delete swarm
    delete_result = await juliaos_client.storage.delete_swarm(swarm_id)
    assert delete_result["success"] == True
    
    # Verify deletion
    with pytest.raises(Exception):
        await juliaos_client.storage.get_swarm(swarm_id)


@pytest.mark.asyncio
async def test_agent_swarm_relationship(juliaos_client, clean_storage):
    """
    Test agent-swarm relationship operations.
    """
    # Create agent and swarm
    agent_id = str(uuid.uuid4())
    await juliaos_client.storage.save_agent(
        agent_id=agent_id,
        name="Relationship Test Agent",
        agent_type=AgentType.TRADING.value,
        config={"parameters": {}}
    )
    
    swarm_id = str(uuid.uuid4())
    await juliaos_client.storage.save_swarm(
        swarm_id=swarm_id,
        name="Relationship Test Swarm",
        swarm_type=SwarmType.OPTIMIZATION.value,
        algorithm="DE",
        config={}
    )
    
    # Add agent to swarm
    add_result = await juliaos_client.storage.add_agent_to_swarm(swarm_id, agent_id)
    assert add_result["success"] == True
    
    # Get swarm agents
    agents_result = await juliaos_client.storage.get_swarm_agents(swarm_id)
    assert agents_result["success"] == True
    assert any(agent["id"] == agent_id for agent in agents_result["agents"])
    
    # Remove agent from swarm
    remove_result = await juliaos_client.storage.remove_agent_from_swarm(swarm_id, agent_id)
    assert remove_result["success"] == True
    
    # Verify removal
    agents_result = await juliaos_client.storage.get_swarm_agents(swarm_id)
    assert agents_result["success"] == True
    assert not any(agent["id"] == agent_id for agent in agents_result["agents"])
    
    # Clean up
    await juliaos_client.storage.delete_agent(agent_id)
    await juliaos_client.storage.delete_swarm(swarm_id)


@pytest.mark.asyncio
async def test_settings_storage(juliaos_client, clean_storage):
    """
    Test settings storage operations.
    """
    # Save setting
    key = "test_setting"
    value = {"key1": "value1", "key2": 42}
    
    save_result = await juliaos_client.storage.save_setting(key, value)
    assert save_result["success"] == True
    
    # Get setting
    get_result = await juliaos_client.storage.get_setting(key)
    assert get_result["success"] == True
    assert get_result["value"]["key1"] == "value1"
    assert get_result["value"]["key2"] == 42
    
    # Get setting with default
    missing_key = "missing_setting"
    default_value = "default"
    
    default_result = await juliaos_client.storage.get_setting(missing_key, default_value)
    assert default_result["success"] == True
    assert default_result["value"] == default_value
    
    # List settings
    list_result = await juliaos_client.storage.list_settings()
    assert list_result["success"] == True
    assert any(setting["key"] == key for setting in list_result["settings"])


@pytest.mark.asyncio
async def test_database_operations(juliaos_client):
    """
    Test database maintenance operations.
    """
    # Create backup
    backup_result = await juliaos_client.storage.create_backup()
    assert backup_result["success"] == True
    assert "backup_path" in backup_result
    
    # Vacuum database
    vacuum_result = await juliaos_client.storage.vacuum_database()
    assert vacuum_result["success"] == True
