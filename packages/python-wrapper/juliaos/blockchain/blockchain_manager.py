"""
Blockchain manager for the JuliaOS Python wrapper.
"""

from typing import Dict, Any, List, Optional, Union

from ..bridge import JuliaBridge
from ..exceptions import BlockchainError, ResourceNotFoundError
from .blockchain_connection import BlockchainConnection
from .chain_types import Chain, Network
from .transaction import Transaction


class BlockchainManager:
    """
    Manager for blockchain operations.
    
    This class provides methods for connecting to blockchains, getting chain information,
    and performing blockchain operations.
    """
    
    def __init__(self, bridge: JuliaBridge):
        """
        Initialize the BlockchainManager.
        
        Args:
            bridge: JuliaBridge instance for communicating with the JuliaOS server
        """
        self.bridge = bridge
        self.connections = {}
    
    async def connect(
        self,
        chain: Union[Chain, str],
        network: Union[Network, str] = Network.MAINNET,
        rpc_url: Optional[str] = None,
        api_key: Optional[str] = None
    ) -> BlockchainConnection:
        """
        Connect to a blockchain.
        
        Args:
            chain: Blockchain chain
            network: Blockchain network
            rpc_url: RPC URL (optional, will use default if not provided)
            api_key: API key (optional)
        
        Returns:
            BlockchainConnection: Connection to the blockchain
        
        Raises:
            BlockchainError: If connection fails
        """
        # Convert chain and network to string if they're enums
        if isinstance(chain, Chain):
            chain = chain.value
        
        if isinstance(network, Network):
            network = network.value
        
        try:
            # Execute connect command
            result = await self.bridge.execute("Blockchain.connect", [
                chain,
                network,
                rpc_url,
                api_key
            ])
            
            if not result.get("success", False):
                raise BlockchainError(f"Failed to connect to blockchain: {result.get('error', 'Unknown error')}")
            
            # Create connection object
            connection = BlockchainConnection(self.bridge, chain, network, result)
            
            # Store connection
            self.connections[f"{chain}_{network}"] = connection
            
            return connection
        except Exception as e:
            if not isinstance(e, BlockchainError):
                raise BlockchainError(f"Error connecting to blockchain: {e}")
            raise
    
    async def get_connection(
        self,
        chain: Union[Chain, str],
        network: Union[Network, str] = Network.MAINNET
    ) -> BlockchainConnection:
        """
        Get an existing blockchain connection or create a new one.
        
        Args:
            chain: Blockchain chain
            network: Blockchain network
        
        Returns:
            BlockchainConnection: Connection to the blockchain
        
        Raises:
            BlockchainError: If connection fails
        """
        # Convert chain and network to string if they're enums
        if isinstance(chain, Chain):
            chain = chain.value
        
        if isinstance(network, Network):
            network = network.value
        
        # Check if connection exists
        connection_key = f"{chain}_{network}"
        if connection_key in self.connections:
            return self.connections[connection_key]
        
        # Create new connection
        return await self.connect(chain, network)
    
    async def get_supported_chains(self) -> List[str]:
        """
        Get supported blockchain chains.
        
        Returns:
            List[str]: List of supported chains
        
        Raises:
            BlockchainError: If chain retrieval fails
        """
        try:
            # Execute get supported chains command
            result = await self.bridge.execute("Blockchain.getSupportedChains", [])
            
            return result
        except Exception as e:
            raise BlockchainError(f"Error retrieving supported chains: {e}")
    
    async def get_chain_info(self, chain: Union[Chain, str]) -> Dict[str, Any]:
        """
        Get information about a blockchain chain.
        
        Args:
            chain: Blockchain chain
        
        Returns:
            Dict[str, Any]: Chain information
        
        Raises:
            BlockchainError: If chain info retrieval fails
        """
        # Convert chain to string if it's an enum
        if isinstance(chain, Chain):
            chain = chain.value
        
        try:
            # Execute get chain info command
            result = await self.bridge.execute("Blockchain.getChainInfo", [chain])
            
            return result
        except Exception as e:
            raise BlockchainError(f"Error retrieving chain info: {e}")
    
    async def get_transaction(
        self,
        tx_hash: str,
        chain: Union[Chain, str],
        network: Union[Network, str] = Network.MAINNET
    ) -> Transaction:
        """
        Get a transaction by hash.
        
        Args:
            tx_hash: Transaction hash
            chain: Blockchain chain
            network: Blockchain network
        
        Returns:
            Transaction: Transaction object
        
        Raises:
            ResourceNotFoundError: If transaction is not found
            BlockchainError: If transaction retrieval fails
        """
        # Get connection
        connection = await self.get_connection(chain, network)
        
        # Get transaction
        return await connection.get_transaction(tx_hash)
    
    async def get_gas_price(
        self,
        chain: Union[Chain, str],
        network: Union[Network, str] = Network.MAINNET
    ) -> Dict[str, Any]:
        """
        Get current gas price for a chain.
        
        Args:
            chain: Blockchain chain
            network: Blockchain network
        
        Returns:
            Dict[str, Any]: Gas price information
        
        Raises:
            BlockchainError: If gas price retrieval fails
        """
        # Get connection
        connection = await self.get_connection(chain, network)
        
        # Get gas price
        return await connection.get_gas_price()
    
    async def estimate_gas(
        self,
        from_address: str,
        to_address: str,
        value: str,
        data: str,
        chain: Union[Chain, str],
        network: Union[Network, str] = Network.MAINNET
    ) -> int:
        """
        Estimate gas for a transaction.
        
        Args:
            from_address: Sender address
            to_address: Recipient address
            value: Transaction value
            data: Transaction data
            chain: Blockchain chain
            network: Blockchain network
        
        Returns:
            int: Estimated gas
        
        Raises:
            BlockchainError: If gas estimation fails
        """
        # Get connection
        connection = await self.get_connection(chain, network)
        
        # Estimate gas
        return await connection.estimate_gas(from_address, to_address, value, data)
    
    async def get_balance(
        self,
        address: str,
        chain: Union[Chain, str],
        network: Union[Network, str] = Network.MAINNET
    ) -> str:
        """
        Get balance of an address.
        
        Args:
            address: Address to check
            chain: Blockchain chain
            network: Blockchain network
        
        Returns:
            str: Balance in wei/lamports
        
        Raises:
            BlockchainError: If balance retrieval fails
        """
        # Get connection
        connection = await self.get_connection(chain, network)
        
        # Get balance
        return await connection.get_balance(address)
    
    async def get_token_balance(
        self,
        address: str,
        token_address: str,
        chain: Union[Chain, str],
        network: Union[Network, str] = Network.MAINNET
    ) -> str:
        """
        Get token balance of an address.
        
        Args:
            address: Address to check
            token_address: Token contract address
            chain: Blockchain chain
            network: Blockchain network
        
        Returns:
            str: Token balance
        
        Raises:
            BlockchainError: If token balance retrieval fails
        """
        # Get connection
        connection = await self.get_connection(chain, network)
        
        # Get token balance
        return await connection.get_token_balance(address, token_address)
    
    async def get_token_info(
        self,
        token_address: str,
        chain: Union[Chain, str],
        network: Union[Network, str] = Network.MAINNET
    ) -> Dict[str, Any]:
        """
        Get information about a token.
        
        Args:
            token_address: Token contract address
            chain: Blockchain chain
            network: Blockchain network
        
        Returns:
            Dict[str, Any]: Token information
        
        Raises:
            BlockchainError: If token info retrieval fails
        """
        # Get connection
        connection = await self.get_connection(chain, network)
        
        # Get token info
        return await connection.get_token_info(token_address)
