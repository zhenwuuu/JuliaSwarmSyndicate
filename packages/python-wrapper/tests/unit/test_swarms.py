"""
Unit tests for the swarms module.
"""

import asyncio
import pytest
from unittest.mock import MagicMock, patch
from juliaos.swarms import SwarmManager, Swarm, SwarmType
from juliaos.exceptions import SwarmError, ResourceNotFoundError


@pytest.fixture
def mock_bridge():
    """
    Create a mock JuliaBridge.
    """
    bridge = MagicMock()
    bridge.execute = MagicMock(return_value=asyncio.Future())
    return bridge


@pytest.fixture
def swarm_manager(mock_bridge):
    """
    Create a SwarmManager instance with a mock bridge.
    """
    return SwarmManager(mock_bridge)


@pytest.mark.asyncio
async def test_create_swarm_success(swarm_manager, mock_bridge):
    """
    Test successful swarm creation.
    """
    # Set up mock response
    mock_bridge.execute.return_value.set_result({
        "success": True,
        "swarm_id": "test_id",
        "algorithm": "DE",
        "dimensions": 2,
        "swarm_size": 20
    })
    
    # Create swarm
    swarm = await swarm_manager.create_swarm(
        name="Test Swarm",
        swarm_type=SwarmType.OPTIMIZATION,
        algorithm="DE",
        dimensions=2,
        bounds=[(-10.0, 10.0), (-10.0, 10.0)],
        config={"population_size": 20},
        swarm_id="test_id"
    )
    
    # Verify
    assert swarm.id == "test_id"
    assert swarm.name == "Test Swarm"
    assert swarm.type == "OPTIMIZATION"
    assert swarm.algorithm == "DE"
    assert swarm.dimensions == 2
    assert swarm.swarm_size == 20
    mock_bridge.execute.assert_called_once()


@pytest.mark.asyncio
async def test_create_swarm_failure(swarm_manager, mock_bridge):
    """
    Test swarm creation failure.
    """
    # Set up mock response
    mock_bridge.execute.return_value.set_result({
        "success": False,
        "error": "Swarm creation failed"
    })
    
    # Create swarm
    with pytest.raises(SwarmError) as excinfo:
        await swarm_manager.create_swarm(
            name="Test Swarm",
            swarm_type=SwarmType.OPTIMIZATION,
            algorithm="DE",
            dimensions=2,
            bounds=[(-10.0, 10.0), (-10.0, 10.0)],
            config={"population_size": 20},
            swarm_id="test_id"
        )
    
    # Verify
    assert "Swarm creation failed" in str(excinfo.value)
    mock_bridge.execute.assert_called_once()


@pytest.mark.asyncio
async def test_get_swarm_success(swarm_manager, mock_bridge):
    """
    Test successful swarm retrieval.
    """
    # Set up mock response
    mock_bridge.execute.return_value.set_result({
        "success": True,
        "id": "test_id",
        "name": "Test Swarm",
        "type": "OPTIMIZATION",
        "algorithm": "DE",
        "dimensions": 2,
        "status": "CREATED"
    })
    
    # Get swarm
    swarm = await swarm_manager.get_swarm("test_id")
    
    # Verify
    assert swarm.id == "test_id"
    assert swarm.name == "Test Swarm"
    assert swarm.type == "OPTIMIZATION"
    assert swarm.algorithm == "DE"
    assert swarm.dimensions == 2
    assert swarm.status == "CREATED"
    mock_bridge.execute.assert_called_once_with("Swarms.get_swarm_status", ["test_id"])


@pytest.mark.asyncio
async def test_get_swarm_not_found(swarm_manager, mock_bridge):
    """
    Test swarm retrieval when swarm is not found.
    """
    # Set up mock response
    mock_bridge.execute.return_value.set_result({
        "success": False,
        "error": "Swarm not found"
    })
    
    # Get swarm
    with pytest.raises(ResourceNotFoundError) as excinfo:
        await swarm_manager.get_swarm("test_id")
    
    # Verify
    assert "Swarm not found" in str(excinfo.value)
    mock_bridge.execute.assert_called_once()


@pytest.mark.asyncio
async def test_list_swarms(swarm_manager, mock_bridge):
    """
    Test listing swarms.
    """
    # Set up mock response
    mock_bridge.execute.return_value.set_result({
        "swarms": [
            {
                "id": "swarm1",
                "name": "Swarm 1",
                "type": "OPTIMIZATION",
                "algorithm": "DE",
                "status": "RUNNING"
            },
            {
                "id": "swarm2",
                "name": "Swarm 2",
                "type": "OPTIMIZATION",
                "algorithm": "PSO",
                "status": "STOPPED"
            }
        ]
    })
    
    # List swarms
    swarms = await swarm_manager.list_swarms()
    
    # Verify
    assert len(swarms) == 2
    assert swarms[0].id == "swarm1"
    assert swarms[0].name == "Swarm 1"
    assert swarms[0].algorithm == "DE"
    assert swarms[1].id == "swarm2"
    assert swarms[1].name == "Swarm 2"
    assert swarms[1].algorithm == "PSO"
    mock_bridge.execute.assert_called_once_with("Swarms.list_swarms", [])


@pytest.mark.asyncio
async def test_delete_swarm_success(swarm_manager, mock_bridge):
    """
    Test successful swarm deletion.
    """
    # Set up mock response
    mock_bridge.execute.return_value.set_result({
        "success": True
    })
    
    # Delete swarm
    result = await swarm_manager.delete_swarm("test_id")
    
    # Verify
    assert result == True
    mock_bridge.execute.assert_called_once_with("Swarms.delete_swarm", ["test_id"])


@pytest.mark.asyncio
async def test_delete_swarm_not_found(swarm_manager, mock_bridge):
    """
    Test swarm deletion when swarm is not found.
    """
    # Set up mock response
    mock_bridge.execute.return_value.set_result({
        "success": False,
        "error": "Swarm not found"
    })
    
    # Delete swarm
    with pytest.raises(ResourceNotFoundError) as excinfo:
        await swarm_manager.delete_swarm("test_id")
    
    # Verify
    assert "Swarm not found" in str(excinfo.value)
    mock_bridge.execute.assert_called_once()


@pytest.fixture
def mock_swarm():
    """
    Create a mock Swarm.
    """
    bridge = MagicMock()
    bridge.execute = MagicMock(return_value=asyncio.Future())
    
    swarm_data = {
        "id": "test_id",
        "name": "Test Swarm",
        "type": "OPTIMIZATION",
        "algorithm": "DE",
        "dimensions": 2,
        "bounds": [(-10.0, 10.0), (-10.0, 10.0)],
        "config": {"population_size": 20},
        "swarm_size": 20,
        "status": "CREATED"
    }
    
    return Swarm(bridge, swarm_data)


@pytest.mark.asyncio
async def test_swarm_run_optimization(mock_swarm):
    """
    Test running an optimization with a swarm.
    """
    # Set up mock response
    mock_swarm.bridge.execute.return_value.set_result({
        "success": True,
        "optimization_id": "opt_id"
    })
    
    # Run optimization
    result = await mock_swarm.run_optimization(
        function_id="test_func",
        max_iterations=100,
        max_time_seconds=60,
        tolerance=1e-6
    )
    
    # Verify
    assert result["success"] == True
    assert result["optimization_id"] == "opt_id"
    mock_swarm.bridge.execute.assert_called_once()


@pytest.mark.asyncio
async def test_swarm_get_optimization_result(mock_swarm):
    """
    Test getting optimization result.
    """
    # Set up mock response
    mock_swarm.bridge.execute.return_value.set_result({
        "success": True,
        "status": "completed",
        "result": {
            "best_individual": [0.1, 0.2],
            "best_fitness": 0.05
        }
    })
    
    # Get optimization result
    result = await mock_swarm.get_optimization_result("opt_id")
    
    # Verify
    assert result["success"] == True
    assert result["status"] == "completed"
    assert result["result"]["best_individual"] == [0.1, 0.2]
    assert result["result"]["best_fitness"] == 0.05
    mock_swarm.bridge.execute.assert_called_once_with("Swarms.get_optimization_result", ["opt_id"])


@pytest.mark.asyncio
async def test_swarm_get_status(mock_swarm):
    """
    Test getting swarm status.
    """
    # Set up mock response
    mock_swarm.bridge.execute.return_value.set_result({
        "success": True,
        "id": "test_id",
        "status": "RUNNING",
        "algorithm": "DE"
    })
    
    # Get status
    result = await mock_swarm.get_status()
    
    # Verify
    assert result["success"] == True
    assert result["id"] == "test_id"
    assert result["status"] == "RUNNING"
    assert result["algorithm"] == "DE"
    assert mock_swarm.status == "RUNNING"
    mock_swarm.bridge.execute.assert_called_once_with("Swarms.get_swarm_status", ["test_id"])


@pytest.mark.asyncio
async def test_swarm_stop(mock_swarm):
    """
    Test stopping a swarm.
    """
    # Set up mock response
    mock_swarm.bridge.execute.return_value.set_result({
        "success": True
    })
    
    # Stop swarm
    result = await mock_swarm.stop()
    
    # Verify
    assert result == True
    assert mock_swarm.status == "STOPPED"
    mock_swarm.bridge.execute.assert_called_once_with("Swarms.stop_swarm", ["test_id"])


@pytest.mark.asyncio
async def test_swarm_reset(mock_swarm):
    """
    Test resetting a swarm.
    """
    # Set up mock response
    mock_swarm.bridge.execute.return_value.set_result({
        "success": True
    })
    
    # Reset swarm
    result = await mock_swarm.reset()
    
    # Verify
    assert result == True
    assert mock_swarm.status == "CREATED"
    mock_swarm.bridge.execute.assert_called_once_with("Swarms.reset_swarm", ["test_id"])
