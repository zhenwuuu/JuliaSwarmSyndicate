"""
Unit tests for Google ADK integration.
"""

import pytest
import asyncio
from unittest.mock import MagicMock, patch

from juliaos.adk import JuliaOSADKAdapter, JuliaOSADKAgent, JuliaOSADKTool, JuliaOSADKMemory

# Skip tests if Google ADK is not available
try:
    from google.agent.sdk import AgentConfig, ToolSpec, MemoryContent
    ADK_AVAILABLE = True
except ImportError:
    ADK_AVAILABLE = False

pytestmark = pytest.mark.skipif(not ADK_AVAILABLE, reason="Google ADK not installed")


@pytest.mark.asyncio
async def test_adk_adapter():
    """Test the ADK adapter."""
    # Mock JuliaBridge
    bridge = MagicMock()
    
    # Create adapter
    adapter = JuliaOSADKAdapter(bridge)
    
    # Mock Agent
    agent = MagicMock()
    agent.name = "test_agent"
    agent.agent_type = "TRADING"
    agent.id = "test_agent_id"
    
    # Convert to ADK agent
    adk_agent = adapter.agent_to_adk(agent)
    
    # Check conversion
    assert isinstance(adk_agent, JuliaOSADKAgent)
    assert adk_agent.get_juliaos_agent() == agent
    assert adk_agent.config.name == "test_agent"


@pytest.mark.asyncio
async def test_adk_agent():
    """Test the ADK agent."""
    # Mock Agent
    agent = MagicMock()
    agent.name = "test_agent"
    agent.agent_type = "TRADING"
    agent.id = "test_agent_id"
    agent.execute_task = MagicMock(return_value=asyncio.Future())
    agent.execute_task.return_value.set_result({
        "response": "This is a test response",
        "state": {"key": "value"}
    })
    
    # Create ADK agent config
    config = AgentConfig(
        name="test_agent",
        description="Test agent",
        model="gemini-pro"
    )
    
    # Create ADK agent
    adk_agent = JuliaOSADKAgent(agent, config)
    
    # Process input
    response = await adk_agent.process("Hello")
    
    # Check response
    assert response.response == "This is a test response"
    assert hasattr(response, "state")


@pytest.mark.asyncio
async def test_adk_tool():
    """Test the ADK tool."""
    # Create a test function
    async def test_function(param1: str, param2: int = 0) -> dict:
        return {"param1": param1, "param2": param2}
    
    # Create ADK tool
    tool = JuliaOSADKTool(
        name="test_tool",
        description="Test tool",
        function=test_function
    )
    
    # Check tool
    assert tool.spec.name == "test_tool"
    assert tool.spec.description == "Test tool"
    assert "param1" in tool.spec.parameters["properties"]
    assert "param2" in tool.spec.parameters["properties"]
    assert "param1" in tool.spec.parameters["required"]
    assert "param2" not in tool.spec.parameters["required"]
    
    # Run tool
    result = await tool.function("test", 42)
    
    # Check result
    assert result["param1"] == "test"
    assert result["param2"] == 42


@pytest.mark.asyncio
async def test_adk_memory():
    """Test the ADK memory."""
    # Mock StorageManager
    storage_manager = MagicMock()
    storage_manager.set = MagicMock(return_value=asyncio.Future())
    storage_manager.set.return_value.set_result(True)
    storage_manager.get = MagicMock(return_value=asyncio.Future())
    storage_manager.get.return_value.set_result('{"text": "Test memory", "metadata": {"key": "value"}}')
    storage_manager.keys = MagicMock(return_value=asyncio.Future())
    storage_manager.keys.return_value.set_result(["adk_test:123"])
    storage_manager.delete = MagicMock(return_value=asyncio.Future())
    storage_manager.delete.return_value.set_result(True)
    
    # Create ADK memory
    memory = JuliaOSADKMemory(storage_manager, "adk_test")
    
    # Add memory item
    with patch("uuid.uuid4", return_value="123"):
        item_id = await memory.add(MemoryContent(
            text="Test memory",
            metadata={"key": "value"}
        ))
    
    # Check item ID
    assert item_id == "123"
    
    # Get memory item
    item = await memory.get("123")
    
    # Check item
    assert item.text == "Test memory"
    assert item.metadata["key"] == "value"
    
    # Search memory
    results = await memory.search("Test")
    
    # Check results
    assert len(results) == 1
    assert results[0].text == "Test memory"
    
    # Delete memory item
    result = await memory.delete("123")
    
    # Check result
    assert result is True
    
    # Clear memory
    result = await memory.clear()
    
    # Check result
    assert result is True
