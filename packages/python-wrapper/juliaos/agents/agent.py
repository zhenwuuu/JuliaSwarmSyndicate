"""
Agent class for the JuliaOS Python wrapper.
"""

from typing import Dict, Any, List, Optional, Union

from ..bridge import JuliaBridge
from ..exceptions import AgentError, ResourceNotFoundError
from .agent_types import AgentStatus
from .task import Task


class Agent:
    """
    Base class for agents.
    
    This class provides methods for interacting with an agent in the JuliaOS Framework.
    """
    
    def __init__(self, bridge: JuliaBridge, data: Dict[str, Any]):
        """
        Initialize an Agent.
        
        Args:
            bridge: JuliaBridge instance for communicating with the JuliaOS server
            data: Agent data from the server
        """
        self.bridge = bridge
        self.id = data.get("id")
        self.name = data.get("name")
        self.type = data.get("type")
        self.status = data.get("status")
        self.config = data.get("config", {})
        self.created_at = data.get("created_at")
        self.updated_at = data.get("updated_at")
        self._data = data
    
    async def start(self) -> bool:
        """
        Start the agent.
        
        Returns:
            bool: True if start was successful
        
        Raises:
            AgentError: If agent start fails
        """
        try:
            result = await self.bridge.execute("Agents.startAgent", [self.id])
            
            if not result.get("success", False):
                raise AgentError(f"Failed to start agent: {result.get('error', 'Unknown error')}")
            
            self.status = result.get("agent", {}).get("status")
            return True
        except Exception as e:
            if not isinstance(e, AgentError):
                raise AgentError(f"Error starting agent: {e}")
            raise
    
    async def stop(self) -> bool:
        """
        Stop the agent.
        
        Returns:
            bool: True if stop was successful
        
        Raises:
            AgentError: If agent stop fails
        """
        try:
            result = await self.bridge.execute("Agents.stopAgent", [self.id])
            
            if not result.get("success", False):
                raise AgentError(f"Failed to stop agent: {result.get('error', 'Unknown error')}")
            
            self.status = result.get("agent", {}).get("status")
            return True
        except Exception as e:
            if not isinstance(e, AgentError):
                raise AgentError(f"Error stopping agent: {e}")
            raise
    
    async def pause(self) -> bool:
        """
        Pause the agent.
        
        Returns:
            bool: True if pause was successful
        
        Raises:
            AgentError: If agent pause fails
        """
        try:
            result = await self.bridge.execute("Agents.pauseAgent", [self.id])
            
            if not result.get("success", False):
                raise AgentError(f"Failed to pause agent: {result.get('error', 'Unknown error')}")
            
            self.status = result.get("agent", {}).get("status")
            return True
        except Exception as e:
            if not isinstance(e, AgentError):
                raise AgentError(f"Error pausing agent: {e}")
            raise
    
    async def resume(self) -> bool:
        """
        Resume the agent.
        
        Returns:
            bool: True if resume was successful
        
        Raises:
            AgentError: If agent resume fails
        """
        try:
            result = await self.bridge.execute("Agents.resumeAgent", [self.id])
            
            if not result.get("success", False):
                raise AgentError(f"Failed to resume agent: {result.get('error', 'Unknown error')}")
            
            self.status = result.get("agent", {}).get("status")
            return True
        except Exception as e:
            if not isinstance(e, AgentError):
                raise AgentError(f"Error resuming agent: {e}")
            raise
    
    async def delete(self) -> bool:
        """
        Delete the agent.
        
        Returns:
            bool: True if deletion was successful
        
        Raises:
            AgentError: If agent deletion fails
        """
        try:
            result = await self.bridge.execute("Agents.deleteAgent", [self.id])
            
            if not result.get("success", False):
                raise AgentError(f"Failed to delete agent: {result.get('error', 'Unknown error')}")
            
            return True
        except Exception as e:
            if not isinstance(e, AgentError):
                raise AgentError(f"Error deleting agent: {e}")
            raise
    
    async def update(self, updates: Dict[str, Any]) -> bool:
        """
        Update the agent.
        
        Args:
            updates: Updates to apply to the agent
        
        Returns:
            bool: True if update was successful
        
        Raises:
            AgentError: If agent update fails
        """
        try:
            result = await self.bridge.execute("Agents.updateAgent", [self.id, updates])
            
            if not result.get("success", False):
                raise AgentError(f"Failed to update agent: {result.get('error', 'Unknown error')}")
            
            # Update local data
            agent_data = result.get("agent", {})
            self.name = agent_data.get("name", self.name)
            self.status = agent_data.get("status", self.status)
            self.config = agent_data.get("config", self.config)
            self.updated_at = agent_data.get("updated_at", self.updated_at)
            self._data = agent_data
            
            return True
        except Exception as e:
            if not isinstance(e, AgentError):
                raise AgentError(f"Error updating agent: {e}")
            raise
    
    async def refresh(self) -> bool:
        """
        Refresh the agent data from the server.
        
        Returns:
            bool: True if refresh was successful
        
        Raises:
            ResourceNotFoundError: If agent is not found
            AgentError: If agent refresh fails
        """
        try:
            result = await self.bridge.execute("Agents.getAgent", [self.id])
            
            if not result:
                raise ResourceNotFoundError(f"Agent not found: {self.id}")
            
            # Update local data
            self.name = result.get("name", self.name)
            self.type = result.get("type", self.type)
            self.status = result.get("status", self.status)
            self.config = result.get("config", self.config)
            self.created_at = result.get("created_at", self.created_at)
            self.updated_at = result.get("updated_at", self.updated_at)
            self._data = result
            
            return True
        except Exception as e:
            if isinstance(e, ResourceNotFoundError):
                raise
            raise AgentError(f"Error refreshing agent: {e}")
    
    async def execute_task(self, task_data: Dict[str, Any]) -> Task:
        """
        Execute a task on the agent.
        
        Args:
            task_data: Task data
        
        Returns:
            Task: The created task
        
        Raises:
            AgentError: If task execution fails
        """
        try:
            result = await self.bridge.execute("Agents.executeTask", [self.id, task_data])
            
            if not result.get("success", False):
                raise AgentError(f"Failed to execute task: {result.get('error', 'Unknown error')}")
            
            return Task(self.bridge, self.id, result.get("task_id"), task_data)
        except Exception as e:
            if not isinstance(e, AgentError):
                raise AgentError(f"Error executing task: {e}")
            raise
    
    async def get_task_status(self, task_id: str) -> Dict[str, Any]:
        """
        Get the status of a task.
        
        Args:
            task_id: ID of the task
        
        Returns:
            Dict[str, Any]: Task status
        
        Raises:
            ResourceNotFoundError: If task is not found
            AgentError: If task status retrieval fails
        """
        try:
            result = await self.bridge.execute("Agents.getTaskStatus", [self.id, task_id])
            
            if not result.get("success", False):
                if "not found" in result.get("error", "").lower():
                    raise ResourceNotFoundError(f"Task not found: {task_id}")
                raise AgentError(f"Failed to get task status: {result.get('error', 'Unknown error')}")
            
            return result
        except Exception as e:
            if isinstance(e, (ResourceNotFoundError, AgentError)):
                raise
            raise AgentError(f"Error retrieving task status: {e}")
    
    async def get_tasks(self) -> List[Dict[str, Any]]:
        """
        Get all tasks for the agent.
        
        Returns:
            List[Dict[str, Any]]: List of tasks
        
        Raises:
            AgentError: If task retrieval fails
        """
        try:
            result = await self.bridge.execute("Agents.getAgentTasks", [self.id])
            
            if not result.get("success", False):
                raise AgentError(f"Failed to get agent tasks: {result.get('error', 'Unknown error')}")
            
            return result.get("tasks", [])
        except Exception as e:
            if not isinstance(e, AgentError):
                raise AgentError(f"Error retrieving agent tasks: {e}")
            raise
    
    async def set_memory(self, key: str, value: Any) -> bool:
        """
        Set a memory value for the agent.
        
        Args:
            key: Memory key
            value: Memory value
        
        Returns:
            bool: True if memory set was successful
        
        Raises:
            AgentError: If memory set fails
        """
        try:
            result = await self.bridge.execute("Agents.setAgentMemory", [self.id, key, value])
            
            if not result.get("success", False):
                raise AgentError(f"Failed to set agent memory: {result.get('error', 'Unknown error')}")
            
            return True
        except Exception as e:
            if not isinstance(e, AgentError):
                raise AgentError(f"Error setting agent memory: {e}")
            raise
    
    async def get_memory(self, key: str) -> Any:
        """
        Get a memory value for the agent.
        
        Args:
            key: Memory key
        
        Returns:
            Any: Memory value
        
        Raises:
            ResourceNotFoundError: If memory key is not found
            AgentError: If memory retrieval fails
        """
        try:
            result = await self.bridge.execute("Agents.getAgentMemory", [self.id, key])
            
            if result is None:
                raise ResourceNotFoundError(f"Memory key not found: {key}")
            
            return result
        except Exception as e:
            if isinstance(e, ResourceNotFoundError):
                raise
            raise AgentError(f"Error retrieving agent memory: {e}")
    
    async def delete_memory(self, key: str) -> bool:
        """
        Delete a memory value for the agent.
        
        Args:
            key: Memory key
        
        Returns:
            bool: True if memory deletion was successful
        
        Raises:
            ResourceNotFoundError: If memory key is not found
            AgentError: If memory deletion fails
        """
        try:
            result = await self.bridge.execute("Agents.deleteAgentMemory", [self.id, key])
            
            if not result.get("success", False):
                if "not found" in result.get("error", "").lower():
                    raise ResourceNotFoundError(f"Memory key not found: {key}")
                raise AgentError(f"Failed to delete agent memory: {result.get('error', 'Unknown error')}")
            
            return True
        except Exception as e:
            if isinstance(e, (ResourceNotFoundError, AgentError)):
                raise
            raise AgentError(f"Error deleting agent memory: {e}")
    
    def to_dict(self) -> Dict[str, Any]:
        """
        Convert the agent to a dictionary.
        
        Returns:
            Dict[str, Any]: Agent data
        """
        return {
            "id": self.id,
            "name": self.name,
            "type": self.type,
            "status": self.status,
            "config": self.config,
            "created_at": self.created_at,
            "updated_at": self.updated_at
        }
    
    def __repr__(self) -> str:
        """
        Get a string representation of the agent.
        
        Returns:
            str: String representation
        """
        return f"Agent(id={self.id}, name={self.name}, type={self.type}, status={self.status})"
