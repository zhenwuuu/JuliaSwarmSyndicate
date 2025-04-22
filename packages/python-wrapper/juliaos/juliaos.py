"""
Main JuliaOS class for interacting with the JuliaOS Framework.
"""

import asyncio
import os
from typing import Dict, Any, Optional

from .bridge import JuliaBridge
from .agents import AgentManager
from .swarms import SwarmManager
from .blockchain import BlockchainManager
from .wallet import WalletManager
from .storage import StorageManager
from .benchmarking import BenchmarkingModule
from .exceptions import JuliaOSError, ConnectionError


class JuliaOS:
    """
    Main class for interacting with the JuliaOS Framework.

    This class provides access to all the components of the JuliaOS Framework,
    including agents, swarms, blockchain, wallet, and storage.

    This class can be used as an async context manager:

    ```python
    async with JuliaOS() as juliaos:
        # Use juliaos here
        result = await juliaos.ping()
    # Connection is automatically closed when exiting the context
    ```

    Attributes:
        agents (AgentManager): Manager for agent operations
        swarms (SwarmManager): Manager for swarm operations
        blockchain (BlockchainManager): Manager for blockchain operations
        wallet (WalletManager): Manager for wallet operations
        storage (StorageManager): Manager for storage operations
        benchmarking (BenchmarkingModule): Module for benchmarking swarm algorithms
    """

    def __init__(
        self,
        host: str = "localhost",
        port: int = 8080,
        api_key: Optional[str] = None,
        auto_connect: bool = False
    ):
        """
        Initialize the JuliaOS client.

        Args:
            host: Host address of the JuliaOS server
            port: Port number of the JuliaOS server
            api_key: API key for authentication (optional)
            auto_connect: Whether to automatically connect to the server
        """
        self.host = host
        self.port = port
        self.api_key = api_key or os.environ.get("JULIAOS_API_KEY")
        self.bridge = JuliaBridge(host, port, self.api_key)

        # Initialize managers
        self.agents = AgentManager(self.bridge)
        self.swarms = SwarmManager(self.bridge)
        self.blockchain = BlockchainManager(self.bridge)
        self.wallet = WalletManager(self.bridge)
        self.storage = StorageManager(self.bridge)
        self.benchmarking = BenchmarkingModule(self.bridge)

        # Connect if auto_connect is True
        if auto_connect:
            asyncio.create_task(self.connect())

    async def connect(self) -> bool:
        """
        Connect to the JuliaOS server.

        Returns:
            bool: True if connection was successful

        Raises:
            ConnectionError: If connection fails
        """
        try:
            await self.bridge.connect()
            return True
        except Exception as e:
            raise ConnectionError(f"Failed to connect to JuliaOS server: {e}")

    async def disconnect(self) -> bool:
        """
        Disconnect from the JuliaOS server.

        Returns:
            bool: True if disconnection was successful
        """
        try:
            await self.bridge.disconnect()
            return True
        except Exception as e:
            raise ConnectionError(f"Failed to disconnect from JuliaOS server: {e}")

    async def ping(self) -> Dict[str, Any]:
        """
        Ping the JuliaOS server to check connectivity.

        Returns:
            Dict[str, Any]: Server response

        Raises:
            ConnectionError: If ping fails
        """
        try:
            return await self.bridge.execute("ping", [])
        except Exception as e:
            raise ConnectionError(f"Failed to ping JuliaOS server: {e}")

    async def get_version(self) -> str:
        """
        Get the version of the JuliaOS server.

        Returns:
            str: Server version

        Raises:
            JuliaOSError: If version retrieval fails
        """
        try:
            result = await self.bridge.execute("get_version", [])
            return result["version"]
        except Exception as e:
            raise JuliaOSError(f"Failed to get JuliaOS version: {e}")

    async def get_status(self) -> Dict[str, Any]:
        """
        Get the status of the JuliaOS server.

        Returns:
            Dict[str, Any]: Server status

        Raises:
            JuliaOSError: If status retrieval fails
        """
        try:
            return await self.bridge.execute("get_status", [])
        except Exception as e:
            raise JuliaOSError(f"Failed to get JuliaOS status: {e}")

    async def execute_command(self, command: str, args: list = None) -> Dict[str, Any]:
        """
        Execute a raw command on the JuliaOS server.

        Args:
            command: Command to execute
            args: Command arguments

        Returns:
            Dict[str, Any]: Command result

        Raises:
            JuliaOSError: If command execution fails
        """
        try:
            return await self.bridge.execute(command, args or [])
        except Exception as e:
            raise JuliaOSError(f"Failed to execute command '{command}': {e}")

    async def __aenter__(self):
        """
        Async context manager entry point.

        Connects to the JuliaOS server when entering the context.

        Returns:
            JuliaOS: The JuliaOS instance
        """
        await self.connect()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """
        Async context manager exit point.

        Disconnects from the JuliaOS server when exiting the context.
        """
        await self.disconnect()
