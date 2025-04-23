"""
Task class for the JuliaOS Python wrapper.
"""

import asyncio
from typing import Dict, Any, Optional

from ..bridge import JuliaBridge
from ..exceptions import AgentError, ResourceNotFoundError, TimeoutError


class Task:
    """
    Class representing a task executed by an agent.
    
    This class provides methods for interacting with a task in the JuliaOS Framework.
    """
    
    def __init__(
        self,
        bridge: JuliaBridge,
        agent_id: str,
        task_id: str,
        task_data: Dict[str, Any]
    ):
        """
        Initialize a Task.
        
        Args:
            bridge: JuliaBridge instance for communicating with the JuliaOS server
            agent_id: ID of the agent that owns the task
            task_id: ID of the task
            task_data: Task data
        """
        self.bridge = bridge
        self.agent_id = agent_id
        self.id = task_id
        self.data = task_data
        self.status = "pending"
        self.result = None
    
    async def get_status(self) -> Dict[str, Any]:
        """
        Get the status of the task.
        
        Returns:
            Dict[str, Any]: Task status
        
        Raises:
            ResourceNotFoundError: If task is not found
            AgentError: If task status retrieval fails
        """
        try:
            result = await self.bridge.execute("Agents.getTaskStatus", [self.agent_id, self.id])
            
            if not result.get("success", False):
                if "not found" in result.get("error", "").lower():
                    raise ResourceNotFoundError(f"Task not found: {self.id}")
                raise AgentError(f"Failed to get task status: {result.get('error', 'Unknown error')}")
            
            self.status = result.get("status")
            self.result = result.get("result")
            
            return result
        except Exception as e:
            if isinstance(e, (ResourceNotFoundError, AgentError)):
                raise
            raise AgentError(f"Error retrieving task status: {e}")
    
    async def wait_for_completion(self, timeout: Optional[float] = None, poll_interval: float = 0.5) -> Any:
        """
        Wait for the task to complete.
        
        Args:
            timeout: Timeout in seconds (None for no timeout)
            poll_interval: Polling interval in seconds
        
        Returns:
            Any: Task result
        
        Raises:
            TimeoutError: If task completion times out
            ResourceNotFoundError: If task is not found
            AgentError: If task status retrieval fails
        """
        start_time = asyncio.get_event_loop().time()
        
        while True:
            # Check timeout
            if timeout is not None and asyncio.get_event_loop().time() - start_time > timeout:
                raise TimeoutError(f"Task {self.id} timed out after {timeout} seconds")
            
            # Get task status
            status_result = await self.get_status()
            
            # Check if task is complete
            if status_result.get("status") in ["completed", "failed"]:
                self.status = status_result.get("status")
                self.result = status_result.get("result")
                
                if self.status == "failed":
                    raise AgentError(f"Task failed: {self.result}")
                
                return self.result
            
            # Wait before polling again
            await asyncio.sleep(poll_interval)
    
    async def cancel(self) -> bool:
        """
        Cancel the task.
        
        Returns:
            bool: True if cancellation was successful
        
        Raises:
            ResourceNotFoundError: If task is not found
            AgentError: If task cancellation fails
        """
        try:
            result = await self.bridge.execute("Agents.cancelTask", [self.agent_id, self.id])
            
            if not result.get("success", False):
                if "not found" in result.get("error", "").lower():
                    raise ResourceNotFoundError(f"Task not found: {self.id}")
                raise AgentError(f"Failed to cancel task: {result.get('error', 'Unknown error')}")
            
            self.status = "cancelled"
            return True
        except Exception as e:
            if isinstance(e, (ResourceNotFoundError, AgentError)):
                raise
            raise AgentError(f"Error cancelling task: {e}")
    
    def to_dict(self) -> Dict[str, Any]:
        """
        Convert the task to a dictionary.
        
        Returns:
            Dict[str, Any]: Task data
        """
        return {
            "id": self.id,
            "agent_id": self.agent_id,
            "data": self.data,
            "status": self.status,
            "result": self.result
        }
    
    def __repr__(self) -> str:
        """
        Get a string representation of the task.
        
        Returns:
            str: String representation
        """
        return f"Task(id={self.id}, agent_id={self.agent_id}, status={self.status})"
