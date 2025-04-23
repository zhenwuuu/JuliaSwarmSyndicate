"""
Swarm class for the JuliaOS Python wrapper.
"""

from typing import Dict, Any, List, Optional, Union, Tuple

from ..bridge import JuliaBridge
from ..exceptions import SwarmError, ResourceNotFoundError
from .swarm_types import SwarmStatus


class Swarm:
    """
    Class representing a swarm in the JuliaOS Framework.
    
    This class provides methods for interacting with a swarm, including
    running optimizations, getting results, and managing the swarm lifecycle.
    """
    
    def __init__(self, bridge: JuliaBridge, data: Dict[str, Any]):
        """
        Initialize a Swarm.
        
        Args:
            bridge: JuliaBridge instance for communicating with the JuliaOS server
            data: Swarm data from the server
        """
        self.bridge = bridge
        self.id = data.get("id")
        self.name = data.get("name")
        self.type = data.get("type")
        self.algorithm = data.get("algorithm")
        self.dimensions = data.get("dimensions")
        self.bounds = data.get("bounds")
        self.config = data.get("config", {})
        self.swarm_size = data.get("swarm_size")
        self.status = data.get("status")
        self.created_at = data.get("created_at")
        self.updated_at = data.get("updated_at")
        self._data = data
    
    async def run_optimization(
        self,
        function_id: str,
        max_iterations: int = 100,
        max_time_seconds: int = 60,
        tolerance: float = 1e-6,
        config: Dict[str, Any] = None
    ) -> Dict[str, Any]:
        """
        Run an optimization with the swarm.
        
        Args:
            function_id: ID of the objective function to optimize
            max_iterations: Maximum number of iterations
            max_time_seconds: Maximum time in seconds
            tolerance: Convergence tolerance
            config: Additional configuration
        
        Returns:
            Dict[str, Any]: Optimization result
        
        Raises:
            SwarmError: If optimization fails
        """
        try:
            # Prepare optimization config
            opt_config = {
                "max_iterations": max_iterations,
                "max_time_seconds": max_time_seconds,
                "tolerance": tolerance
            }
            
            if config:
                opt_config.update(config)
            
            # Execute run optimization command
            result = await self.bridge.execute("Swarms.run_optimization", [
                self.id,
                function_id,
                opt_config
            ])
            
            if not result.get("success", False):
                raise SwarmError(f"Failed to run optimization: {result.get('error', 'Unknown error')}")
            
            return result
        except Exception as e:
            if not isinstance(e, SwarmError):
                raise SwarmError(f"Error running optimization: {e}")
            raise
    
    async def get_optimization_result(self, optimization_id: str) -> Dict[str, Any]:
        """
        Get the result of an optimization.
        
        Args:
            optimization_id: ID of the optimization
        
        Returns:
            Dict[str, Any]: Optimization result
        
        Raises:
            ResourceNotFoundError: If optimization is not found
            SwarmError: If result retrieval fails
        """
        try:
            # Execute get optimization result command
            result = await self.bridge.execute("Swarms.get_optimization_result", [optimization_id])
            
            if not result.get("success", False):
                if "not found" in result.get("error", "").lower():
                    raise ResourceNotFoundError(f"Optimization not found: {optimization_id}")
                raise SwarmError(f"Failed to get optimization result: {result.get('error', 'Unknown error')}")
            
            return result
        except Exception as e:
            if isinstance(e, (ResourceNotFoundError, SwarmError)):
                raise
            raise SwarmError(f"Error retrieving optimization result: {e}")
    
    async def get_status(self) -> Dict[str, Any]:
        """
        Get the status of the swarm.
        
        Returns:
            Dict[str, Any]: Swarm status
        
        Raises:
            ResourceNotFoundError: If swarm is not found
            SwarmError: If status retrieval fails
        """
        try:
            # Execute get swarm status command
            result = await self.bridge.execute("Swarms.get_swarm_status", [self.id])
            
            if not result.get("success", False):
                if "not found" in result.get("error", "").lower():
                    raise ResourceNotFoundError(f"Swarm not found: {self.id}")
                raise SwarmError(f"Failed to get swarm status: {result.get('error', 'Unknown error')}")
            
            # Update local data
            self.status = result.get("status")
            
            return result
        except Exception as e:
            if isinstance(e, (ResourceNotFoundError, SwarmError)):
                raise
            raise SwarmError(f"Error retrieving swarm status: {e}")
    
    async def stop(self) -> bool:
        """
        Stop the swarm.
        
        Returns:
            bool: True if stop was successful
        
        Raises:
            SwarmError: If swarm stop fails
        """
        try:
            # Execute stop swarm command
            result = await self.bridge.execute("Swarms.stop_swarm", [self.id])
            
            if not result.get("success", False):
                raise SwarmError(f"Failed to stop swarm: {result.get('error', 'Unknown error')}")
            
            self.status = SwarmStatus.STOPPED.value
            return True
        except Exception as e:
            if not isinstance(e, SwarmError):
                raise SwarmError(f"Error stopping swarm: {e}")
            raise
    
    async def reset(self) -> bool:
        """
        Reset the swarm.
        
        Returns:
            bool: True if reset was successful
        
        Raises:
            SwarmError: If swarm reset fails
        """
        try:
            # Execute reset swarm command
            result = await self.bridge.execute("Swarms.reset_swarm", [self.id])
            
            if not result.get("success", False):
                raise SwarmError(f"Failed to reset swarm: {result.get('error', 'Unknown error')}")
            
            self.status = SwarmStatus.CREATED.value
            return True
        except Exception as e:
            if not isinstance(e, SwarmError):
                raise SwarmError(f"Error resetting swarm: {e}")
            raise
    
    async def delete(self) -> bool:
        """
        Delete the swarm.
        
        Returns:
            bool: True if deletion was successful
        
        Raises:
            SwarmError: If swarm deletion fails
        """
        try:
            # Execute delete swarm command
            result = await self.bridge.execute("Swarms.delete_swarm", [self.id])
            
            if not result.get("success", False):
                raise SwarmError(f"Failed to delete swarm: {result.get('error', 'Unknown error')}")
            
            return True
        except Exception as e:
            if not isinstance(e, SwarmError):
                raise SwarmError(f"Error deleting swarm: {e}")
            raise
    
    async def update_config(self, config: Dict[str, Any]) -> bool:
        """
        Update the swarm configuration.
        
        Args:
            config: New configuration
        
        Returns:
            bool: True if update was successful
        
        Raises:
            SwarmError: If configuration update fails
        """
        try:
            # Execute update swarm config command
            result = await self.bridge.execute("Swarms.update_swarm_config", [self.id, config])
            
            if not result.get("success", False):
                raise SwarmError(f"Failed to update swarm config: {result.get('error', 'Unknown error')}")
            
            self.config.update(config)
            return True
        except Exception as e:
            if not isinstance(e, SwarmError):
                raise SwarmError(f"Error updating swarm config: {e}")
            raise
    
    async def get_optimization_history(self) -> List[Dict[str, Any]]:
        """
        Get the optimization history for the swarm.
        
        Returns:
            List[Dict[str, Any]]: Optimization history
        
        Raises:
            SwarmError: If history retrieval fails
        """
        try:
            # Execute get optimization history command
            result = await self.bridge.execute("Swarms.get_optimization_history", [self.id])
            
            if not result.get("success", False):
                raise SwarmError(f"Failed to get optimization history: {result.get('error', 'Unknown error')}")
            
            return result.get("history", [])
        except Exception as e:
            if not isinstance(e, SwarmError):
                raise SwarmError(f"Error retrieving optimization history: {e}")
            raise
    
    def to_dict(self) -> Dict[str, Any]:
        """
        Convert the swarm to a dictionary.
        
        Returns:
            Dict[str, Any]: Swarm data
        """
        return {
            "id": self.id,
            "name": self.name,
            "type": self.type,
            "algorithm": self.algorithm,
            "dimensions": self.dimensions,
            "bounds": self.bounds,
            "config": self.config,
            "swarm_size": self.swarm_size,
            "status": self.status,
            "created_at": self.created_at,
            "updated_at": self.updated_at
        }
    
    def __repr__(self) -> str:
        """
        Get a string representation of the swarm.
        
        Returns:
            str: String representation
        """
        return f"Swarm(id={self.id}, name={self.name}, algorithm={self.algorithm}, status={self.status})"
