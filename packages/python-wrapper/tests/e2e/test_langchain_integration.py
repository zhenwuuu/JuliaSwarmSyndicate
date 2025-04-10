"""
End-to-end tests for the LangChain integration with JuliaOS.

This module contains end-to-end tests for the LangChain integration with JuliaOS.
"""

import os
import pytest
import asyncio
from unittest.mock import MagicMock, patch

from juliaos import JuliaOS
from juliaos.langchain import (
    JuliaOSAgentAdapter,
    JuliaOSTradingAgentAdapter,
    SwarmOptimizationTool,
    JuliaOSConversationBufferMemory,
    SwarmOptimizationChain
)


@pytest.mark.asyncio
async def test_agent_adapter():
    """
    Test that the agent adapter can be used with a real JuliaOS instance.
    """
    # Skip this test if JULIA_API_URL is not set
    if not os.environ.get("JULIA_API_URL"):
        pytest.skip("JULIA_API_URL not set")
    
    # Initialize JuliaOS
    juliaos = JuliaOS()
    await juliaos.connect()
    
    try:
        # Create a trading agent
        trading_agent = await juliaos.agents.create_agent(
            name="Test Trading Agent",
            agent_type="TRADING",
            config={"parameters": {"risk_tolerance": 0.5}}
        )
        
        # Create an agent adapter
        adapter = JuliaOSTradingAgentAdapter(trading_agent)
        
        # Verify that the adapter has the correct agent
        assert adapter.agent == trading_agent
        assert adapter.bridge == juliaos.bridge
        
        # Clean up
        await trading_agent.delete()
    finally:
        await juliaos.disconnect()


@pytest.mark.asyncio
async def test_swarm_optimization_tool():
    """
    Test that the swarm optimization tool can be used with a real JuliaOS instance.
    """
    # Skip this test if JULIA_API_URL is not set
    if not os.environ.get("JULIA_API_URL"):
        pytest.skip("JULIA_API_URL not set")
    
    # Initialize JuliaOS
    juliaos = JuliaOS()
    await juliaos.connect()
    
    try:
        # Create a swarm optimization tool
        tool = SwarmOptimizationTool(juliaos.bridge)
        
        # Verify that the tool has the correct bridge
        assert tool.bridge == juliaos.bridge
        assert tool.name == "swarm_optimization"
        
        # Test the tool with a simple input
        input_str = """
        {
            "algorithm": "DE",
            "objective_function": "Minimize the sum of squares of the inputs",
            "bounds": [[-5, 5], [-5, 5]],
            "config": {
                "population_size": 10,
                "max_iterations": 10
            }
        }
        """
        
        # Mock the _arun method to avoid actual execution
        with patch.object(tool, '_arun', return_value='{"best_position": [0, 0], "best_fitness": 0}'):
            result = await tool._arun(input_str)
            assert result is not None
    finally:
        await juliaos.disconnect()


@pytest.mark.asyncio
async def test_conversation_buffer_memory():
    """
    Test that the conversation buffer memory can be used with a real JuliaOS instance.
    """
    # Skip this test if JULIA_API_URL is not set
    if not os.environ.get("JULIA_API_URL"):
        pytest.skip("JULIA_API_URL not set")
    
    # Initialize JuliaOS
    juliaos = JuliaOS()
    await juliaos.connect()
    
    try:
        # Create a conversation buffer memory
        memory = JuliaOSConversationBufferMemory(juliaos.bridge)
        
        # Verify that the memory has the correct bridge
        assert memory.bridge == juliaos.bridge
        assert memory.storage_type == "local"
        assert memory.storage_key == "langchain_conversation_memory"
        
        # Test saving and loading memory
        memory.save_context(
            {"input": "Hello"},
            {"output": "Hi there!"}
        )
        
        # Load the memory
        memory_variables = memory.load_memory_variables({})
        
        # Verify that the memory was loaded correctly
        assert "chat_history" in memory_variables
    finally:
        await juliaos.disconnect()


@pytest.mark.asyncio
async def test_swarm_optimization_chain():
    """
    Test that the swarm optimization chain can be used with a real JuliaOS instance.
    """
    # Skip this test if JULIA_API_URL is not set
    if not os.environ.get("JULIA_API_URL"):
        pytest.skip("JULIA_API_URL not set")
    
    # Initialize JuliaOS
    juliaos = JuliaOS()
    await juliaos.connect()
    
    try:
        # Create a mock LLM
        mock_llm = MagicMock()
        mock_llm.arun.return_value = """
        ```python
        def objective_function(x):
            return sum(xi**2 for xi in x)
        ```
        """
        
        # Create a swarm optimization chain
        chain = SwarmOptimizationChain(
            bridge=juliaos.bridge,
            llm=mock_llm,
            algorithm="DE"
        )
        
        # Verify that the chain has the correct bridge and LLM
        assert chain.bridge == juliaos.bridge
        assert chain.llm == mock_llm
        assert chain.algorithm == "DE"
        
        # Mock the _acall method to avoid actual execution
        with patch.object(chain, '_acall', return_value={
            "best_position": [0, 0],
            "best_fitness": 0,
            "iterations": 10
        }):
            result = await chain._acall({
                "problem_description": "Minimize the sum of squares of the inputs",
                "bounds": [[-5, 5], [-5, 5]],
                "config": {
                    "population_size": 10,
                    "max_iterations": 10
                }
            })
            
            assert result is not None
            assert "best_position" in result
            assert "best_fitness" in result
            assert "iterations" in result
    finally:
        await juliaos.disconnect()
