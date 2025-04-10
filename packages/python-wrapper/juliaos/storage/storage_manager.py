"""
Storage manager for the JuliaOS Python wrapper.
"""

from typing import Dict, Any, List, Optional, Union

from ..bridge import JuliaBridge
from ..exceptions import StorageError, ResourceNotFoundError
from .storage_types import StorageType


class StorageManager:
    """
    Manager for storage operations.
    
    This class provides methods for storing, retrieving, and managing data in the JuliaOS Framework.
    """
    
    def __init__(self, bridge: JuliaBridge):
        """
        Initialize the StorageManager.
        
        Args:
            bridge: JuliaBridge instance for communicating with the JuliaOS server
        """
        self.bridge = bridge
    
    async def initialize(self) -> Dict[str, Any]:
        """
        Initialize the storage system.
        
        Returns:
            Dict[str, Any]: Initialization result
        
        Raises:
            StorageError: If initialization fails
        """
        try:
            # Execute initialize command
            result = await self.bridge.execute("Storage.initialize", [])
            
            return result
        except Exception as e:
            raise StorageError(f"Error initializing storage: {e}")
    
    # Agent storage operations
    
    async def save_agent(
        self,
        agent_id: str,
        name: str,
        agent_type: str,
        config: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Save an agent to storage.
        
        Args:
            agent_id: Agent ID
            name: Agent name
            agent_type: Agent type
            config: Agent configuration
        
        Returns:
            Dict[str, Any]: Save result
        
        Raises:
            StorageError: If agent save fails
        """
        try:
            # Execute create agent command
            result = await self.bridge.execute("Storage.create_agent", [
                self.bridge.db,
                agent_id,
                name,
                agent_type,
                config
            ])
            
            return result
        except Exception as e:
            raise StorageError(f"Error saving agent: {e}")
    
    async def get_agent(self, agent_id: str) -> Dict[str, Any]:
        """
        Get an agent from storage.
        
        Args:
            agent_id: Agent ID
        
        Returns:
            Dict[str, Any]: Agent data
        
        Raises:
            ResourceNotFoundError: If agent is not found
            StorageError: If agent retrieval fails
        """
        try:
            # Execute get agent command
            result = await self.bridge.execute("Storage.get_agent", [
                self.bridge.db,
                agent_id
            ])
            
            if result is None:
                raise ResourceNotFoundError(f"Agent not found: {agent_id}")
            
            return result
        except Exception as e:
            if isinstance(e, ResourceNotFoundError):
                raise
            raise StorageError(f"Error retrieving agent: {e}")
    
    async def list_agents(self) -> List[Dict[str, Any]]:
        """
        List all agents in storage.
        
        Returns:
            List[Dict[str, Any]]: List of agents
        
        Raises:
            StorageError: If agent listing fails
        """
        try:
            # Execute list agents command
            result = await self.bridge.execute("Storage.list_agents", [self.bridge.db])
            
            return result
        except Exception as e:
            raise StorageError(f"Error listing agents: {e}")
    
    async def update_agent(self, agent_id: str, updates: Dict[str, Any]) -> Dict[str, Any]:
        """
        Update an agent in storage.
        
        Args:
            agent_id: Agent ID
            updates: Fields to update
        
        Returns:
            Dict[str, Any]: Updated agent
        
        Raises:
            ResourceNotFoundError: If agent is not found
            StorageError: If agent update fails
        """
        try:
            # Execute update agent command
            result = await self.bridge.execute("Storage.update_agent", [
                self.bridge.db,
                agent_id,
                updates
            ])
            
            if result is None:
                raise ResourceNotFoundError(f"Agent not found: {agent_id}")
            
            return result
        except Exception as e:
            if isinstance(e, ResourceNotFoundError):
                raise
            raise StorageError(f"Error updating agent: {e}")
    
    async def delete_agent(self, agent_id: str) -> Dict[str, Any]:
        """
        Delete an agent from storage.
        
        Args:
            agent_id: Agent ID
        
        Returns:
            Dict[str, Any]: Delete result
        
        Raises:
            ResourceNotFoundError: If agent is not found
            StorageError: If agent deletion fails
        """
        try:
            # Execute delete agent command
            result = await self.bridge.execute("Storage.delete_agent", [
                self.bridge.db,
                agent_id
            ])
            
            if not result.get("success", False):
                if "not found" in result.get("error", "").lower():
                    raise ResourceNotFoundError(f"Agent not found: {agent_id}")
                raise StorageError(f"Failed to delete agent: {result.get('error', 'Unknown error')}")
            
            return result
        except Exception as e:
            if isinstance(e, (ResourceNotFoundError, StorageError)):
                raise
            raise StorageError(f"Error deleting agent: {e}")
    
    # Swarm storage operations
    
    async def save_swarm(
        self,
        swarm_id: str,
        name: str,
        swarm_type: str,
        algorithm: str,
        config: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Save a swarm to storage.
        
        Args:
            swarm_id: Swarm ID
            name: Swarm name
            swarm_type: Swarm type
            algorithm: Swarm algorithm
            config: Swarm configuration
        
        Returns:
            Dict[str, Any]: Save result
        
        Raises:
            StorageError: If swarm save fails
        """
        try:
            # Execute create swarm command
            result = await self.bridge.execute("Storage.create_swarm", [
                self.bridge.db,
                swarm_id,
                name,
                swarm_type,
                algorithm,
                config
            ])
            
            return result
        except Exception as e:
            raise StorageError(f"Error saving swarm: {e}")
    
    async def get_swarm(self, swarm_id: str) -> Dict[str, Any]:
        """
        Get a swarm from storage.
        
        Args:
            swarm_id: Swarm ID
        
        Returns:
            Dict[str, Any]: Swarm data
        
        Raises:
            ResourceNotFoundError: If swarm is not found
            StorageError: If swarm retrieval fails
        """
        try:
            # Execute get swarm command
            result = await self.bridge.execute("Storage.get_swarm", [
                self.bridge.db,
                swarm_id
            ])
            
            if result is None:
                raise ResourceNotFoundError(f"Swarm not found: {swarm_id}")
            
            return result
        except Exception as e:
            if isinstance(e, ResourceNotFoundError):
                raise
            raise StorageError(f"Error retrieving swarm: {e}")
    
    async def list_swarms(self) -> List[Dict[str, Any]]:
        """
        List all swarms in storage.
        
        Returns:
            List[Dict[str, Any]]: List of swarms
        
        Raises:
            StorageError: If swarm listing fails
        """
        try:
            # Execute list swarms command
            result = await self.bridge.execute("Storage.list_swarms", [self.bridge.db])
            
            return result
        except Exception as e:
            raise StorageError(f"Error listing swarms: {e}")
    
    async def update_swarm(self, swarm_id: str, updates: Dict[str, Any]) -> Dict[str, Any]:
        """
        Update a swarm in storage.
        
        Args:
            swarm_id: Swarm ID
            updates: Fields to update
        
        Returns:
            Dict[str, Any]: Updated swarm
        
        Raises:
            ResourceNotFoundError: If swarm is not found
            StorageError: If swarm update fails
        """
        try:
            # Execute update swarm command
            result = await self.bridge.execute("Storage.update_swarm", [
                self.bridge.db,
                swarm_id,
                updates
            ])
            
            if result is None:
                raise ResourceNotFoundError(f"Swarm not found: {swarm_id}")
            
            return result
        except Exception as e:
            if isinstance(e, ResourceNotFoundError):
                raise
            raise StorageError(f"Error updating swarm: {e}")
    
    async def delete_swarm(self, swarm_id: str) -> Dict[str, Any]:
        """
        Delete a swarm from storage.
        
        Args:
            swarm_id: Swarm ID
        
        Returns:
            Dict[str, Any]: Delete result
        
        Raises:
            ResourceNotFoundError: If swarm is not found
            StorageError: If swarm deletion fails
        """
        try:
            # Execute delete swarm command
            result = await self.bridge.execute("Storage.delete_swarm", [
                self.bridge.db,
                swarm_id
            ])
            
            if not result.get("success", False):
                if "not found" in result.get("error", "").lower():
                    raise ResourceNotFoundError(f"Swarm not found: {swarm_id}")
                raise StorageError(f"Failed to delete swarm: {result.get('error', 'Unknown error')}")
            
            return result
        except Exception as e:
            if isinstance(e, (ResourceNotFoundError, StorageError)):
                raise
            raise StorageError(f"Error deleting swarm: {e}")
    
    # Swarm-agent relationship operations
    
    async def add_agent_to_swarm(self, swarm_id: str, agent_id: str) -> Dict[str, Any]:
        """
        Add an agent to a swarm.
        
        Args:
            swarm_id: Swarm ID
            agent_id: Agent ID
        
        Returns:
            Dict[str, Any]: Add result
        
        Raises:
            ResourceNotFoundError: If swarm or agent is not found
            StorageError: If agent addition fails
        """
        try:
            # Execute add agent to swarm command
            result = await self.bridge.execute("Storage.add_agent_to_swarm", [
                self.bridge.db,
                swarm_id,
                agent_id
            ])
            
            if not result.get("success", False):
                error = result.get("error", "").lower()
                if "swarm not found" in error:
                    raise ResourceNotFoundError(f"Swarm not found: {swarm_id}")
                if "agent not found" in error:
                    raise ResourceNotFoundError(f"Agent not found: {agent_id}")
                raise StorageError(f"Failed to add agent to swarm: {error}")
            
            return result
        except Exception as e:
            if isinstance(e, (ResourceNotFoundError, StorageError)):
                raise
            raise StorageError(f"Error adding agent to swarm: {e}")
    
    async def remove_agent_from_swarm(self, swarm_id: str, agent_id: str) -> Dict[str, Any]:
        """
        Remove an agent from a swarm.
        
        Args:
            swarm_id: Swarm ID
            agent_id: Agent ID
        
        Returns:
            Dict[str, Any]: Remove result
        
        Raises:
            ResourceNotFoundError: If swarm or agent is not found
            StorageError: If agent removal fails
        """
        try:
            # Execute remove agent from swarm command
            result = await self.bridge.execute("Storage.remove_agent_from_swarm", [
                self.bridge.db,
                swarm_id,
                agent_id
            ])
            
            if not result.get("success", False):
                error = result.get("error", "").lower()
                if "swarm not found" in error:
                    raise ResourceNotFoundError(f"Swarm not found: {swarm_id}")
                if "agent not found" in error:
                    raise ResourceNotFoundError(f"Agent not found: {agent_id}")
                raise StorageError(f"Failed to remove agent from swarm: {error}")
            
            return result
        except Exception as e:
            if isinstance(e, (ResourceNotFoundError, StorageError)):
                raise
            raise StorageError(f"Error removing agent from swarm: {e}")
    
    async def get_swarm_agents(self, swarm_id: str) -> List[Dict[str, Any]]:
        """
        Get agents in a swarm.
        
        Args:
            swarm_id: Swarm ID
        
        Returns:
            List[Dict[str, Any]]: List of agents
        
        Raises:
            ResourceNotFoundError: If swarm is not found
            StorageError: If agent retrieval fails
        """
        try:
            # Execute get swarm agents command
            result = await self.bridge.execute("Storage.get_swarm_agents", [
                self.bridge.db,
                swarm_id
            ])
            
            if result is None:
                raise ResourceNotFoundError(f"Swarm not found: {swarm_id}")
            
            return result
        except Exception as e:
            if isinstance(e, ResourceNotFoundError):
                raise
            raise StorageError(f"Error retrieving swarm agents: {e}")
    
    # Settings operations
    
    async def save_setting(self, key: str, value: Any) -> Dict[str, Any]:
        """
        Save a setting.
        
        Args:
            key: Setting key
            value: Setting value
        
        Returns:
            Dict[str, Any]: Save result
        
        Raises:
            StorageError: If setting save fails
        """
        try:
            # Execute save setting command
            result = await self.bridge.execute("Storage.save_setting", [
                self.bridge.db,
                key,
                value
            ])
            
            return result
        except Exception as e:
            raise StorageError(f"Error saving setting: {e}")
    
    async def get_setting(self, key: str, default_value: Any = None) -> Any:
        """
        Get a setting.
        
        Args:
            key: Setting key
            default_value: Default value if setting not found
        
        Returns:
            Any: Setting value
        
        Raises:
            StorageError: If setting retrieval fails
        """
        try:
            # Execute get setting command
            result = await self.bridge.execute("Storage.get_setting", [
                self.bridge.db,
                key,
                default_value
            ])
            
            return result
        except Exception as e:
            raise StorageError(f"Error retrieving setting: {e}")
    
    async def list_settings(self) -> List[Dict[str, Any]]:
        """
        List all settings.
        
        Returns:
            List[Dict[str, Any]]: List of settings
        
        Raises:
            StorageError: If setting listing fails
        """
        try:
            # Execute list settings command
            result = await self.bridge.execute("Storage.list_settings", [self.bridge.db])
            
            return result
        except Exception as e:
            raise StorageError(f"Error listing settings: {e}")
    
    # Arweave storage operations
    
    async def configure_arweave(
        self,
        gateway: Optional[str] = None,
        port: Optional[int] = None,
        protocol: Optional[str] = None,
        timeout: Optional[int] = None,
        logging: Optional[bool] = None,
        wallet: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Configure Arweave storage.
        
        Args:
            gateway: Arweave gateway
            port: Arweave port
            protocol: Arweave protocol
            timeout: Arweave timeout
            logging: Arweave logging
            wallet: Arweave wallet
        
        Returns:
            Dict[str, Any]: Configuration result
        
        Raises:
            StorageError: If Arweave configuration fails
        """
        try:
            # Execute configure Arweave command
            result = await self.bridge.execute("Storage.configure_arweave", [
                gateway,
                port,
                protocol,
                timeout,
                logging,
                wallet
            ])
            
            return result
        except Exception as e:
            raise StorageError(f"Error configuring Arweave: {e}")
    
    async def get_arweave_network_info(self) -> Dict[str, Any]:
        """
        Get Arweave network information.
        
        Returns:
            Dict[str, Any]: Network information
        
        Raises:
            StorageError: If network info retrieval fails
        """
        try:
            # Execute get Arweave network info command
            result = await self.bridge.execute("Storage.get_arweave_network_info", [])
            
            return result
        except Exception as e:
            raise StorageError(f"Error retrieving Arweave network info: {e}")
    
    async def store_agent_in_arweave(
        self,
        agent_data: Dict[str, Any],
        tags: Dict[str, str] = None
    ) -> Dict[str, Any]:
        """
        Store an agent in Arweave.
        
        Args:
            agent_data: Agent data
            tags: Additional tags
        
        Returns:
            Dict[str, Any]: Store result
        
        Raises:
            StorageError: If agent storage fails
        """
        try:
            # Execute store agent in Arweave command
            result = await self.bridge.execute("Storage.store_agent_in_arweave", [
                agent_data,
                tags or {}
            ])
            
            return result
        except Exception as e:
            raise StorageError(f"Error storing agent in Arweave: {e}")
    
    async def store_swarm_in_arweave(
        self,
        swarm_data: Dict[str, Any],
        tags: Dict[str, str] = None
    ) -> Dict[str, Any]:
        """
        Store a swarm in Arweave.
        
        Args:
            swarm_data: Swarm data
            tags: Additional tags
        
        Returns:
            Dict[str, Any]: Store result
        
        Raises:
            StorageError: If swarm storage fails
        """
        try:
            # Execute store swarm in Arweave command
            result = await self.bridge.execute("Storage.store_swarm_in_arweave", [
                swarm_data,
                tags or {}
            ])
            
            return result
        except Exception as e:
            raise StorageError(f"Error storing swarm in Arweave: {e}")
    
    async def store_data_in_arweave(
        self,
        data: Any,
        tags: Dict[str, str] = None,
        content_type: str = "application/json"
    ) -> Dict[str, Any]:
        """
        Store data in Arweave.
        
        Args:
            data: Data to store
            tags: Additional tags
            content_type: Content type
        
        Returns:
            Dict[str, Any]: Store result
        
        Raises:
            StorageError: If data storage fails
        """
        try:
            # Execute store data in Arweave command
            result = await self.bridge.execute("Storage.store_data_in_arweave", [
                data,
                tags or {},
                content_type
            ])
            
            return result
        except Exception as e:
            raise StorageError(f"Error storing data in Arweave: {e}")
    
    async def retrieve_data_from_arweave(self, tx_id: str) -> Dict[str, Any]:
        """
        Retrieve data from Arweave.
        
        Args:
            tx_id: Transaction ID
        
        Returns:
            Dict[str, Any]: Retrieved data
        
        Raises:
            ResourceNotFoundError: If data is not found
            StorageError: If data retrieval fails
        """
        try:
            # Execute retrieve data from Arweave command
            result = await self.bridge.execute("Storage.retrieve_data_from_arweave", [tx_id])
            
            if not result.get("success", False):
                if "not found" in result.get("error", "").lower():
                    raise ResourceNotFoundError(f"Data not found: {tx_id}")
                raise StorageError(f"Failed to retrieve data: {result.get('error', 'Unknown error')}")
            
            return result
        except Exception as e:
            if isinstance(e, (ResourceNotFoundError, StorageError)):
                raise
            raise StorageError(f"Error retrieving data from Arweave: {e}")
    
    # Database maintenance operations
    
    async def create_backup(self, backup_path: Optional[str] = None) -> Dict[str, Any]:
        """
        Create a database backup.
        
        Args:
            backup_path: Backup path
        
        Returns:
            Dict[str, Any]: Backup result
        
        Raises:
            StorageError: If backup creation fails
        """
        try:
            # Execute create backup command
            result = await self.bridge.execute("Storage.backup_database", [
                self.bridge.db,
                backup_path
            ])
            
            return result
        except Exception as e:
            raise StorageError(f"Error creating backup: {e}")
    
    async def vacuum_database(self) -> Dict[str, Any]:
        """
        Vacuum the database to reclaim space.
        
        Returns:
            Dict[str, Any]: Vacuum result
        
        Raises:
            StorageError: If database vacuum fails
        """
        try:
            # Execute vacuum database command
            result = await self.bridge.execute("Storage.vacuum_database", [self.bridge.db])
            
            return result
        except Exception as e:
            raise StorageError(f"Error vacuuming database: {e}")
