"""
Swarm manager for the JuliaOS Python wrapper.
"""

import uuid
from typing import Dict, Any, List, Optional, Union, Tuple

from ..bridge import JuliaBridge
from ..exceptions import SwarmError, ResourceNotFoundError
from .swarm import Swarm
from .swarm_types import SwarmType
from .algorithms import AVAILABLE_ALGORITHMS


class SwarmManager:
    """
    Manager for swarm operations.

    This class provides methods for creating, retrieving, and managing swarms.
    """

    def __init__(self, bridge: JuliaBridge):
        """
        Initialize the SwarmManager.

        Args:
            bridge: JuliaBridge instance for communicating with the JuliaOS server
        """
        self.bridge = bridge

    async def create_swarm(
        self,
        name: str,
        swarm_type: Union[SwarmType, str],
        algorithm: str,
        dimensions: int,
        bounds: List[Tuple[float, float]],
        config: Dict[str, Any] = None,
        swarm_id: Optional[str] = None
    ) -> Swarm:
        """
        Create a new swarm.

        Args:
            name: Name of the swarm
            swarm_type: Type of the swarm
            algorithm: Algorithm to use (e.g., "DE", "PSO")
            dimensions: Number of dimensions for the optimization problem
            bounds: List of (min, max) tuples for each dimension
            config: Swarm configuration
            swarm_id: Optional swarm ID (if not provided, a UUID will be generated)

        Returns:
            Swarm: The created swarm

        Raises:
            SwarmError: If swarm creation fails
        """
        # Convert swarm_type to string if it's an enum
        if isinstance(swarm_type, SwarmType):
            swarm_type = swarm_type.value

        # Generate swarm ID if not provided
        if swarm_id is None:
            swarm_id = str(uuid.uuid4())

        # Ensure config is a dictionary
        if config is None:
            config = {}

        try:
            # Execute create swarm command
            result = await self.bridge.execute("Swarms.create_swarm", [
                algorithm,
                dimensions,
                bounds,
                {
                    "id": swarm_id,
                    "name": name,
                    "type": swarm_type,
                    **config
                }
            ])

            if not result.get("success", False):
                raise SwarmError(f"Failed to create swarm: {result.get('error', 'Unknown error')}")

            # Create swarm instance
            swarm_data = {
                "id": swarm_id,
                "name": name,
                "type": swarm_type,
                "algorithm": algorithm,
                "dimensions": dimensions,
                "bounds": bounds,
                "config": config,
                "swarm_size": result.get("swarm_size"),
                "status": "CREATED"
            }

            return Swarm(self.bridge, swarm_data)
        except Exception as e:
            if not isinstance(e, SwarmError):
                raise SwarmError(f"Error creating swarm: {e}")
            raise

    async def get_swarm(self, swarm_id: str) -> Swarm:
        """
        Get a swarm by ID.

        Args:
            swarm_id: ID of the swarm to retrieve

        Returns:
            Swarm: The retrieved swarm

        Raises:
            ResourceNotFoundError: If swarm is not found
            SwarmError: If swarm retrieval fails
        """
        try:
            # Execute get swarm command
            result = await self.bridge.execute("Swarms.get_swarm_status", [swarm_id])

            if not result.get("success", False):
                if "not found" in result.get("error", "").lower():
                    raise ResourceNotFoundError(f"Swarm not found: {swarm_id}")
                raise SwarmError(f"Failed to get swarm: {result.get('error', 'Unknown error')}")

            # Create swarm instance
            return Swarm(self.bridge, result)
        except Exception as e:
            if isinstance(e, (ResourceNotFoundError, SwarmError)):
                raise
            raise SwarmError(f"Error retrieving swarm: {e}")

    async def list_swarms(self) -> List[Swarm]:
        """
        List all swarms.

        Returns:
            List[Swarm]: List of swarms

        Raises:
            SwarmError: If swarm listing fails
        """
        try:
            # Execute list swarms command
            result = await self.bridge.execute("Swarms.list_swarms", [])

            swarms = []
            for swarm_data in result.get("swarms", []):
                swarms.append(Swarm(self.bridge, swarm_data))

            return swarms
        except Exception as e:
            raise SwarmError(f"Error listing swarms: {e}")

    async def delete_swarm(self, swarm_id: str) -> bool:
        """
        Delete a swarm.

        Args:
            swarm_id: ID of the swarm to delete

        Returns:
            bool: True if deletion was successful

        Raises:
            ResourceNotFoundError: If swarm is not found
            SwarmError: If swarm deletion fails
        """
        try:
            # Execute delete swarm command
            result = await self.bridge.execute("Swarms.delete_swarm", [swarm_id])

            if not result.get("success", False):
                if "not found" in result.get("error", "").lower():
                    raise ResourceNotFoundError(f"Swarm not found: {swarm_id}")
                raise SwarmError(f"Failed to delete swarm: {result.get('error', 'Unknown error')}")

            return True
        except Exception as e:
            if isinstance(e, (ResourceNotFoundError, SwarmError)):
                raise
            raise SwarmError(f"Error deleting swarm: {e}")

    async def get_available_algorithms(self) -> List[str]:
        """
        Get available swarm algorithms.

        Returns:
            List[str]: List of available algorithms

        Raises:
            SwarmError: If algorithm retrieval fails
        """
        try:
            # First try to get algorithms from the server
            result = await self.bridge.execute("Swarms.get_available_algorithms", [])
            algorithms = result.get("algorithms", [])

            # If server returns empty list, use the predefined list
            if not algorithms:
                return AVAILABLE_ALGORITHMS

            return algorithms
        except Exception as e:
            # If server call fails, return the predefined list
            return AVAILABLE_ALGORITHMS

    async def set_objective_function(
        self,
        function_id: str,
        function_code: str,
        function_type: str = "julia"
    ) -> Dict[str, Any]:
        """
        Set an objective function for optimization.

        Args:
            function_id: ID for the function
            function_code: Code for the function
            function_type: Type of the function code (julia, python, etc.)

        Returns:
            Dict[str, Any]: Result of setting the function

        Raises:
            SwarmError: If function setting fails
        """
        try:
            # Execute set objective function command
            result = await self.bridge.execute("Swarms.set_objective_function", [
                function_id,
                function_code,
                function_type
            ])

            if not result.get("success", False):
                raise SwarmError(f"Failed to set objective function: {result.get('error', 'Unknown error')}")

            return result
        except Exception as e:
            if not isinstance(e, SwarmError):
                raise SwarmError(f"Error setting objective function: {e}")
            raise
