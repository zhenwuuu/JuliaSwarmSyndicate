"""
Unit tests for the JuliaBridge class.
"""

import asyncio
import json
import pytest
from unittest.mock import MagicMock, patch
from juliaos.bridge import JuliaBridge
from juliaos.exceptions import ConnectionError, TimeoutError


@pytest.fixture
def mock_websocket():
    """
    Create a mock websocket.
    """
    websocket = MagicMock()
    websocket.send = MagicMock(return_value=asyncio.Future())
    websocket.send.return_value.set_result(None)
    websocket.recv = MagicMock(return_value=asyncio.Future())
    return websocket


@pytest.fixture
def bridge():
    """
    Create a JuliaBridge instance.
    """
    return JuliaBridge(host="localhost", port=8080, timeout=1)


@pytest.mark.asyncio
async def test_connect_success(bridge, mock_websocket):
    """
    Test successful connection.
    """
    with patch("websockets.connect", return_value=asyncio.Future()) as mock_connect:
        mock_connect.return_value.set_result(mock_websocket)
        
        # Set up mock response for authentication
        mock_websocket.recv.return_value.set_result(json.dumps({
            "id": "auth_id",
            "result": {"success": True}
        }))
        
        # Connect
        result = await bridge.connect()
        
        # Verify
        assert result == True
        assert bridge.connected == True
        assert bridge.websocket == mock_websocket
        mock_connect.assert_called_once_with("ws://localhost:8080/ws")


@pytest.mark.asyncio
async def test_connect_failure(bridge):
    """
    Test connection failure.
    """
    with patch("websockets.connect", side_effect=Exception("Connection failed")):
        # Connect
        with pytest.raises(ConnectionError) as excinfo:
            await bridge.connect()
        
        # Verify
        assert "Connection failed" in str(excinfo.value)
        assert bridge.connected == False
        assert bridge.websocket is None


@pytest.mark.asyncio
async def test_disconnect(bridge, mock_websocket):
    """
    Test disconnection.
    """
    # Set up bridge with mock websocket
    bridge.websocket = mock_websocket
    bridge.connected = True
    bridge.listener_task = MagicMock()
    bridge.listener_task.cancel = MagicMock()
    
    # Disconnect
    result = await bridge.disconnect()
    
    # Verify
    assert result == True
    assert bridge.connected == False
    assert bridge.websocket is None
    mock_websocket.close.assert_called_once()
    bridge.listener_task.cancel.assert_called_once()


@pytest.mark.asyncio
async def test_execute_success(bridge, mock_websocket):
    """
    Test successful command execution.
    """
    # Set up bridge with mock websocket
    bridge.websocket = mock_websocket
    bridge.connected = True
    
    # Set up mock response
    command_id = None
    
    def mock_send(message):
        nonlocal command_id
        data = json.loads(message)
        command_id = data["id"]
        future = asyncio.Future()
        future.set_result(None)
        return future
    
    mock_websocket.send.side_effect = mock_send
    
    # Execute command
    command = "test_command"
    args = ["arg1", "arg2"]
    
    # Create a future for the pending request
    future = asyncio.Future()
    
    def execute():
        # Start execution
        task = asyncio.create_task(bridge.execute(command, args))
        
        # Wait a bit for the command to be sent
        yield from asyncio.sleep(0.1)
        
        # Set the result for the pending request
        bridge.pending_requests[command_id].set_result({"success": True, "data": "test_result"})
        
        # Return the task
        return task
    
    # Run the coroutine
    task = asyncio.ensure_future(execute())
    await asyncio.sleep(0.2)
    
    # Get the result
    result = await task
    
    # Verify
    assert result == {"success": True, "data": "test_result"}
    mock_websocket.send.assert_called_once()
    sent_data = json.loads(mock_websocket.send.call_args[0][0])
    assert sent_data["command"] == command
    assert sent_data["args"] == args


@pytest.mark.asyncio
async def test_execute_timeout(bridge, mock_websocket):
    """
    Test command execution timeout.
    """
    # Set up bridge with mock websocket
    bridge.websocket = mock_websocket
    bridge.connected = True
    bridge.timeout = 0.1  # Short timeout for testing
    
    # Execute command
    with pytest.raises(TimeoutError) as excinfo:
        await bridge.execute("test_command", ["arg1", "arg2"])
    
    # Verify
    assert "timed out" in str(excinfo.value)
    mock_websocket.send.assert_called_once()


@pytest.mark.asyncio
async def test_execute_not_connected(bridge):
    """
    Test command execution when not connected.
    """
    # Set up bridge as not connected
    bridge.connected = False
    
    # Execute command
    with pytest.raises(ConnectionError) as excinfo:
        await bridge.execute("test_command", ["arg1", "arg2"])
    
    # Verify
    assert "Not connected" in str(excinfo.value)
