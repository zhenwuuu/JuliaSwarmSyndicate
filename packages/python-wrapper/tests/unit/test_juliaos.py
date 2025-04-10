"""
Unit tests for the JuliaOS class.
"""

import asyncio
import pytest
from unittest.mock import MagicMock, patch
from juliaos import JuliaOS
from juliaos.exceptions import ConnectionError, JuliaOSError


@pytest.fixture
def mock_bridge():
    """
    Create a mock JuliaBridge.
    """
    bridge = MagicMock()
    bridge.connect = MagicMock(return_value=asyncio.Future())
    bridge.connect.return_value.set_result(True)
    bridge.disconnect = MagicMock(return_value=asyncio.Future())
    bridge.disconnect.return_value.set_result(True)
    bridge.execute = MagicMock(return_value=asyncio.Future())
    return bridge


@pytest.fixture
def juliaos(mock_bridge):
    """
    Create a JuliaOS instance with a mock bridge.
    """
    with patch("juliaos.juliaos.JuliaBridge", return_value=mock_bridge):
        return JuliaOS(host="localhost", port=8080)


@pytest.mark.asyncio
async def test_connect_success(juliaos, mock_bridge):
    """
    Test successful connection.
    """
    # Connect
    result = await juliaos.connect()
    
    # Verify
    assert result == True
    mock_bridge.connect.assert_called_once()


@pytest.mark.asyncio
async def test_connect_failure(juliaos, mock_bridge):
    """
    Test connection failure.
    """
    # Set up mock to raise exception
    mock_bridge.connect.return_value = asyncio.Future()
    mock_bridge.connect.return_value.set_exception(Exception("Connection failed"))
    
    # Connect
    with pytest.raises(ConnectionError) as excinfo:
        await juliaos.connect()
    
    # Verify
    assert "Connection failed" in str(excinfo.value)
    mock_bridge.connect.assert_called_once()


@pytest.mark.asyncio
async def test_disconnect_success(juliaos, mock_bridge):
    """
    Test successful disconnection.
    """
    # Disconnect
    result = await juliaos.disconnect()
    
    # Verify
    assert result == True
    mock_bridge.disconnect.assert_called_once()


@pytest.mark.asyncio
async def test_disconnect_failure(juliaos, mock_bridge):
    """
    Test disconnection failure.
    """
    # Set up mock to raise exception
    mock_bridge.disconnect.return_value = asyncio.Future()
    mock_bridge.disconnect.return_value.set_exception(Exception("Disconnection failed"))
    
    # Disconnect
    with pytest.raises(ConnectionError) as excinfo:
        await juliaos.disconnect()
    
    # Verify
    assert "Disconnection failed" in str(excinfo.value)
    mock_bridge.disconnect.assert_called_once()


@pytest.mark.asyncio
async def test_ping(juliaos, mock_bridge):
    """
    Test ping.
    """
    # Set up mock response
    mock_bridge.execute.return_value = asyncio.Future()
    mock_bridge.execute.return_value.set_result({"success": True, "ping": "pong"})
    
    # Ping
    result = await juliaos.ping()
    
    # Verify
    assert result == {"success": True, "ping": "pong"}
    mock_bridge.execute.assert_called_once_with("ping", [])


@pytest.mark.asyncio
async def test_get_version(juliaos, mock_bridge):
    """
    Test get_version.
    """
    # Set up mock response
    mock_bridge.execute.return_value = asyncio.Future()
    mock_bridge.execute.return_value.set_result({"version": "1.0.0"})
    
    # Get version
    result = await juliaos.get_version()
    
    # Verify
    assert result == "1.0.0"
    mock_bridge.execute.assert_called_once_with("get_version", [])


@pytest.mark.asyncio
async def test_get_status(juliaos, mock_bridge):
    """
    Test get_status.
    """
    # Set up mock response
    mock_bridge.execute.return_value = asyncio.Future()
    mock_bridge.execute.return_value.set_result({
        "status": "running",
        "uptime": 3600,
        "memory_usage": 1024
    })
    
    # Get status
    result = await juliaos.get_status()
    
    # Verify
    assert result == {
        "status": "running",
        "uptime": 3600,
        "memory_usage": 1024
    }
    mock_bridge.execute.assert_called_once_with("get_status", [])


@pytest.mark.asyncio
async def test_execute_command(juliaos, mock_bridge):
    """
    Test execute_command.
    """
    # Set up mock response
    mock_bridge.execute.return_value = asyncio.Future()
    mock_bridge.execute.return_value.set_result({"success": True, "data": "test_result"})
    
    # Execute command
    result = await juliaos.execute_command("test_command", ["arg1", "arg2"])
    
    # Verify
    assert result == {"success": True, "data": "test_result"}
    mock_bridge.execute.assert_called_once_with("test_command", ["arg1", "arg2"])


@pytest.mark.asyncio
async def test_execute_command_failure(juliaos, mock_bridge):
    """
    Test execute_command failure.
    """
    # Set up mock to raise exception
    mock_bridge.execute.return_value = asyncio.Future()
    mock_bridge.execute.return_value.set_exception(Exception("Command failed"))
    
    # Execute command
    with pytest.raises(JuliaOSError) as excinfo:
        await juliaos.execute_command("test_command", ["arg1", "arg2"])
    
    # Verify
    assert "Command failed" in str(excinfo.value)
    mock_bridge.execute.assert_called_once_with("test_command", ["arg1", "arg2"])
