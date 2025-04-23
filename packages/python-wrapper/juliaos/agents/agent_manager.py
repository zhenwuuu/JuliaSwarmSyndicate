"""
Agent manager for the JuliaOS Python wrapper.
"""

import uuid
from typing import Dict, Any, List, Optional, Union

from ..bridge import JuliaBridge
from ..exceptions import AgentError, ResourceNotFoundError
from .agent import Agent
from .agent_types import AgentType
from .specialized import TradingAgent, MonitorAgent, ArbitrageAgent


class AgentManager:
    """
    Manager for agent operations.
    
    This class provides methods for creating, retrieving, and managing agents.
    """
    
    def __init__(self, bridge: JuliaBridge):
        """
        Initialize the AgentManager.
        
        Args:
            bridge: JuliaBridge instance for communicating with the JuliaOS server
        """
        self.bridge = bridge
    
    async def create_agent(
        self,
        name: str,
        agent_type: Union[AgentType, str],
        config: Dict[str, Any],
        agent_id: Optional[str] = None
    ) -> Agent:
        """
        Create a new agent.
        
        Args:
            name: Name of the agent
            agent_type: Type of the agent
            config: Agent configuration
            agent_id: Optional agent ID (if not provided, a UUID will be generated)
        
        Returns:
            Agent: The created agent
        
        Raises:
            AgentError: If agent creation fails
        """
        # Convert agent_type to string if it's an enum
        if isinstance(agent_type, AgentType):
            agent_type = agent_type.value
        
        # Generate agent ID if not provided
        if agent_id is None:
            agent_id = str(uuid.uuid4())
        
        try:
            # Execute create agent command
            result = await self.bridge.execute("Agents.createAgent", [
                agent_id,
                name,
                agent_type,
                config
            ])
            
            if not result.get("success", False):
                raise AgentError(f"Failed to create agent: {result.get('error', 'Unknown error')}")
            
            # Create appropriate agent instance based on type
            if agent_type == AgentType.TRADING.value:
                return TradingAgent(self.bridge, result["agent"])
            elif agent_type == AgentType.MONITOR.value:
                return MonitorAgent(self.bridge, result["agent"])
            elif agent_type == AgentType.ARBITRAGE.value:
                return ArbitrageAgent(self.bridge, result["agent"])
            else:
                return Agent(self.bridge, result["agent"])
        except Exception as e:
            if not isinstance(e, AgentError):
                raise AgentError(f"Error creating agent: {e}")
            raise
    
    async def get_agent(self, agent_id: str) -> Agent:
        """
        Get an agent by ID.
        
        Args:
            agent_id: ID of the agent to retrieve
        
        Returns:
            Agent: The retrieved agent
        
        Raises:
            ResourceNotFoundError: If agent is not found
            AgentError: If agent retrieval fails
        """
        try:
            # Execute get agent command
            result = await self.bridge.execute("Agents.getAgent", [agent_id])
            
            if not result:
                raise ResourceNotFoundError(f"Agent not found: {agent_id}")
            
            # Create appropriate agent instance based on type
            agent_type = result.get("type")
            if agent_type == AgentType.TRADING.value:
                return TradingAgent(self.bridge, result)
            elif agent_type == AgentType.MONITOR.value:
                return MonitorAgent(self.bridge, result)
            elif agent_type == AgentType.ARBITRAGE.value:
                return ArbitrageAgent(self.bridge, result)
            else:
                return Agent(self.bridge, result)
        except Exception as e:
            if isinstance(e, ResourceNotFoundError):
                raise
            raise AgentError(f"Error retrieving agent: {e}")
    
    async def list_agents(self) -> List[Agent]:
        """
        List all agents.
        
        Returns:
            List[Agent]: List of agents
        
        Raises:
            AgentError: If agent listing fails
        """
        try:
            # Execute list agents command
            result = await self.bridge.execute("Agents.listAgents", [])
            
            agents = []
            for agent_data in result.get("agents", []):
                # Create appropriate agent instance based on type
                agent_type = agent_data.get("type")
                if agent_type == AgentType.TRADING.value:
                    agents.append(TradingAgent(self.bridge, agent_data))
                elif agent_type == AgentType.MONITOR.value:
                    agents.append(MonitorAgent(self.bridge, agent_data))
                elif agent_type == AgentType.ARBITRAGE.value:
                    agents.append(ArbitrageAgent(self.bridge, agent_data))
                else:
                    agents.append(Agent(self.bridge, agent_data))
            
            return agents
        except Exception as e:
            raise AgentError(f"Error listing agents: {e}")
    
    async def delete_agent(self, agent_id: str) -> bool:
        """
        Delete an agent.
        
        Args:
            agent_id: ID of the agent to delete
        
        Returns:
            bool: True if deletion was successful
        
        Raises:
            ResourceNotFoundError: If agent is not found
            AgentError: If agent deletion fails
        """
        try:
            # Execute delete agent command
            result = await self.bridge.execute("Agents.deleteAgent", [agent_id])
            
            if not result.get("success", False):
                if "not found" in result.get("error", "").lower():
                    raise ResourceNotFoundError(f"Agent not found: {agent_id}")
                raise AgentError(f"Failed to delete agent: {result.get('error', 'Unknown error')}")
            
            return True
        except Exception as e:
            if isinstance(e, (ResourceNotFoundError, AgentError)):
                raise
            raise AgentError(f"Error deleting agent: {e}")
    
    async def get_agent_types(self) -> List[str]:
        """
        Get available agent types.
        
        Returns:
            List[str]: List of available agent types
        
        Raises:
            AgentError: If agent type retrieval fails
        """
        try:
            # Execute get agent types command
            result = await self.bridge.execute("Agents.getAgentTypes", [])
            
            return result.get("types", [])
        except Exception as e:
            raise AgentError(f"Error retrieving agent types: {e}")
    
    async def get_agent_status(self, agent_id: str) -> Dict[str, Any]:
        """
        Get the status of an agent.
        
        Args:
            agent_id: ID of the agent
        
        Returns:
            Dict[str, Any]: Agent status
        
        Raises:
            ResourceNotFoundError: If agent is not found
            AgentError: If status retrieval fails
        """
        try:
            # Execute get agent status command
            result = await self.bridge.execute("Agents.getAgentStatus", [agent_id])
            
            if not result.get("success", False):
                if "not found" in result.get("error", "").lower():
                    raise ResourceNotFoundError(f"Agent not found: {agent_id}")
                raise AgentError(f"Failed to get agent status: {result.get('error', 'Unknown error')}")
            
            return result
        except Exception as e:
            if isinstance(e, (ResourceNotFoundError, AgentError)):
                raise
            raise AgentError(f"Error retrieving agent status: {e}")
