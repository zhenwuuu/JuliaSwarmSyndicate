"""
JuliaBridge for communicating with the JuliaOS server.
"""

import asyncio
import json
import logging
import uuid
from typing import Dict, Any, List, Optional, Callable, Awaitable

import websockets
from websockets.exceptions import ConnectionClosed

from .exceptions import ConnectionError, TimeoutError, JuliaOSError


class JuliaBridge:
    """
    Bridge for communicating with the JuliaOS server via WebSockets.

    This class handles the low-level communication with the JuliaOS server,
    including connection management, command execution, and event handling.
    """

    def __init__(
        self,
        host: str = "localhost",
        port: int = 8052,  # Updated to match the JuliaOS server port
        api_key: Optional[str] = None,
        timeout: int = 30
    ):
        """
        Initialize the JuliaBridge.

        Args:
            host: Host address of the JuliaOS server
            port: Port number of the JuliaOS server
            api_key: API key for authentication (optional)
            timeout: Default timeout for command execution in seconds
        """
        self.host = host
        self.port = port
        self.api_key = api_key
        self.timeout = timeout
        self.websocket = None
        self.connected = False
        self.pending_requests = {}
        self.event_handlers = {}
        self.logger = logging.getLogger("juliaos.bridge")
        self.listener_task = None

    async def connect(self) -> bool:
        """
        Connect to the JuliaOS server.

        Returns:
            bool: True if connection was successful

        Raises:
            ConnectionError: If connection fails
        """
        if self.connected:
            return True

        try:
            uri = f"ws://{self.host}:{self.port}/ws"
            self.websocket = await websockets.connect(uri)
            self.connected = True

            # Start listener task
            self.listener_task = asyncio.create_task(self._listen())

            # Authenticate if API key is provided
            if self.api_key:
                auth_result = await self.execute("authenticate", [self.api_key])
                if not auth_result.get("success", False):
                    raise ConnectionError(f"Authentication failed: {auth_result.get('error', 'Unknown error')}")

            return True
        except Exception as e:
            self.connected = False
            self.websocket = None
            raise ConnectionError(f"Failed to connect to JuliaOS server: {e}")

    async def disconnect(self) -> bool:
        """
        Disconnect from the JuliaOS server.

        Returns:
            bool: True if disconnection was successful
        """
        if not self.connected:
            return True

        try:
            if self.listener_task:
                self.listener_task.cancel()
                try:
                    await self.listener_task
                except asyncio.CancelledError:
                    pass
                self.listener_task = None

            if self.websocket:
                await self.websocket.close()
                self.websocket = None

            self.connected = False
            self.pending_requests = {}
            return True
        except Exception as e:
            self.logger.error(f"Error during disconnect: {e}")
            return False

    async def execute(self, command: str, args: List[Any]) -> Dict[str, Any]:
        """
        Execute a command on the JuliaOS server.

        Args:
            command: Command to execute
            args: Command arguments

        Returns:
            Dict[str, Any]: Command result

        Raises:
            ConnectionError: If not connected to the server
            TimeoutError: If command execution times out
            JuliaOSError: If command execution fails
        """
        if not self.connected:
            raise ConnectionError("Not connected to JuliaOS server")

        # Generate request ID
        request_id = str(uuid.uuid4())

        # Create request message
        request = {
            "id": request_id,
            "command": command,
            "args": args
        }

        # Create future for response
        future = asyncio.Future()
        self.pending_requests[request_id] = future

        try:
            # Send request
            await self.websocket.send(json.dumps(request))

            # Wait for response with timeout
            try:
                response = await asyncio.wait_for(future, timeout=self.timeout)
                return response
            except asyncio.TimeoutError:
                del self.pending_requests[request_id]
                raise TimeoutError(f"Command '{command}' timed out after {self.timeout} seconds")
        except ConnectionClosed:
            self.connected = False
            raise ConnectionError("Connection to JuliaOS server was closed")
        except Exception as e:
            if not isinstance(e, TimeoutError):
                raise JuliaOSError(f"Error executing command '{command}': {e}")
            raise

    async def _listen(self) -> None:
        """
        Listen for messages from the JuliaOS server.

        This method runs in a background task and processes incoming messages,
        resolving pending requests and triggering event handlers.
        """
        try:
            while self.connected:
                try:
                    message = await self.websocket.recv()
                    data = json.loads(message)

                    # Handle response
                    if "id" in data and data["id"] in self.pending_requests:
                        request_id = data["id"]
                        future = self.pending_requests.pop(request_id)
                        future.set_result(data.get("result", {}))

                    # Handle event
                    elif "event" in data:
                        event_type = data["event"]
                        event_data = data.get("data", {})
                        await self._handle_event(event_type, event_data)
                except ConnectionClosed:
                    self.connected = False
                    self.logger.error("Connection to JuliaOS server was closed")
                    break
                except Exception as e:
                    self.logger.error(f"Error processing message: {e}")
        except asyncio.CancelledError:
            # Task was cancelled, exit gracefully
            pass
        except Exception as e:
            self.logger.error(f"Listener task error: {e}")
        finally:
            self.connected = False

    async def _handle_event(self, event_type: str, event_data: Dict[str, Any]) -> None:
        """
        Handle an event from the JuliaOS server.

        Args:
            event_type: Type of the event
            event_data: Event data
        """
        if event_type in self.event_handlers:
            for handler in self.event_handlers[event_type]:
                try:
                    await handler(event_data)
                except Exception as e:
                    self.logger.error(f"Error in event handler for '{event_type}': {e}")

    def on_event(self, event_type: str, handler: Callable[[Dict[str, Any]], Awaitable[None]]) -> None:
        """
        Register an event handler.

        Args:
            event_type: Type of the event to handle
            handler: Async function to call when the event occurs
        """
        if event_type not in self.event_handlers:
            self.event_handlers[event_type] = []

        self.event_handlers[event_type].append(handler)

    def off_event(self, event_type: str, handler: Optional[Callable[[Dict[str, Any]], Awaitable[None]]] = None) -> None:
        """
        Unregister an event handler.

        Args:
            event_type: Type of the event
            handler: Handler to unregister (if None, all handlers for the event are removed)
        """
        if event_type not in self.event_handlers:
            return

        if handler is None:
            self.event_handlers[event_type] = []
        else:
            self.event_handlers[event_type] = [h for h in self.event_handlers[event_type] if h != handler]
