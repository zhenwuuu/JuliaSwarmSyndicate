"""
Blockchain connection for the JuliaOS Python wrapper.
"""

from typing import Dict, Any, List, Optional, Union

from ..bridge import JuliaBridge
from ..exceptions import BlockchainError, ResourceNotFoundError
from .transaction import Transaction


class BlockchainConnection:
    """
    Connection to a blockchain.
    
    This class provides methods for interacting with a specific blockchain.
    """
    
    def __init__(
        self,
        bridge: JuliaBridge,
        chain: str,
        network: str,
        connection_data: Dict[str, Any]
    ):
        """
        Initialize a BlockchainConnection.
        
        Args:
            bridge: JuliaBridge instance for communicating with the JuliaOS server
            chain: Blockchain chain
            network: Blockchain network
            connection_data: Connection data from the server
        """
        self.bridge = bridge
        self.chain = chain
        self.network = network
        self.connection_id = connection_data.get("connection_id")
        self.rpc_url = connection_data.get("rpc_url")
        self.connected = connection_data.get("connected", False)
        self.chain_id = connection_data.get("chain_id")
        self.block_height = connection_data.get("block_height")
        self._data = connection_data
    
    async def get_status(self) -> Dict[str, Any]:
        """
        Get the status of the blockchain connection.
        
        Returns:
            Dict[str, Any]: Connection status
        
        Raises:
            BlockchainError: If status retrieval fails
        """
        try:
            # Execute get status command
            result = await self.bridge.execute("Blockchain.getStatus", [self.connection_id])
            
            # Update local data
            self.connected = result.get("connected", self.connected)
            self.block_height = result.get("block_height", self.block_height)
            
            return result
        except Exception as e:
            raise BlockchainError(f"Error retrieving connection status: {e}")
    
    async def get_balance(self, address: str) -> str:
        """
        Get balance of an address.
        
        Args:
            address: Address to check
        
        Returns:
            str: Balance in wei/lamports
        
        Raises:
            BlockchainError: If balance retrieval fails
        """
        try:
            # Execute get balance command
            result = await self.bridge.execute("Blockchain.getBalance", [
                address,
                self.connection_id
            ])
            
            return result
        except Exception as e:
            raise BlockchainError(f"Error retrieving balance: {e}")
    
    async def get_token_balance(self, address: str, token_address: str) -> str:
        """
        Get token balance of an address.
        
        Args:
            address: Address to check
            token_address: Token contract address
        
        Returns:
            str: Token balance
        
        Raises:
            BlockchainError: If token balance retrieval fails
        """
        try:
            # Execute get token balance command
            result = await self.bridge.execute("Blockchain.getTokenBalance", [
                address,
                token_address,
                self.connection_id
            ])
            
            return result
        except Exception as e:
            raise BlockchainError(f"Error retrieving token balance: {e}")
    
    async def get_token_info(self, token_address: str) -> Dict[str, Any]:
        """
        Get information about a token.
        
        Args:
            token_address: Token contract address
        
        Returns:
            Dict[str, Any]: Token information
        
        Raises:
            BlockchainError: If token info retrieval fails
        """
        try:
            # Execute get token info command
            result = await self.bridge.execute("Blockchain.getTokenInfo", [
                token_address,
                self.connection_id
            ])
            
            return result
        except Exception as e:
            raise BlockchainError(f"Error retrieving token info: {e}")
    
    async def get_transaction(self, tx_hash: str) -> Transaction:
        """
        Get a transaction by hash.
        
        Args:
            tx_hash: Transaction hash
        
        Returns:
            Transaction: Transaction object
        
        Raises:
            ResourceNotFoundError: If transaction is not found
            BlockchainError: If transaction retrieval fails
        """
        try:
            # Execute get transaction command
            result = await self.bridge.execute("Blockchain.getTransaction", [
                tx_hash,
                self.connection_id
            ])
            
            if not result:
                raise ResourceNotFoundError(f"Transaction not found: {tx_hash}")
            
            return Transaction(self.bridge, self.chain, self.network, result)
        except Exception as e:
            if isinstance(e, ResourceNotFoundError):
                raise
            raise BlockchainError(f"Error retrieving transaction: {e}")
    
    async def get_transaction_receipt(self, tx_hash: str) -> Dict[str, Any]:
        """
        Get a transaction receipt.
        
        Args:
            tx_hash: Transaction hash
        
        Returns:
            Dict[str, Any]: Transaction receipt
        
        Raises:
            ResourceNotFoundError: If transaction is not found
            BlockchainError: If receipt retrieval fails
        """
        try:
            # Execute get transaction receipt command
            result = await self.bridge.execute("Blockchain.getTransactionReceipt", [
                tx_hash,
                self.connection_id
            ])
            
            if not result:
                raise ResourceNotFoundError(f"Transaction receipt not found: {tx_hash}")
            
            return result
        except Exception as e:
            if isinstance(e, ResourceNotFoundError):
                raise
            raise BlockchainError(f"Error retrieving transaction receipt: {e}")
    
    async def get_block(self, block_number: Optional[int] = None) -> Dict[str, Any]:
        """
        Get a block by number.
        
        Args:
            block_number: Block number (None for latest block)
        
        Returns:
            Dict[str, Any]: Block data
        
        Raises:
            ResourceNotFoundError: If block is not found
            BlockchainError: If block retrieval fails
        """
        try:
            if block_number is None:
                # Execute get latest block command
                result = await self.bridge.execute("Blockchain.getLatestBlock", [
                    self.connection_id
                ])
            else:
                # Execute get block by number command
                result = await self.bridge.execute("Blockchain.getBlockByNumber", [
                    block_number,
                    self.connection_id
                ])
            
            if not result:
                block_desc = "latest" if block_number is None else str(block_number)
                raise ResourceNotFoundError(f"Block not found: {block_desc}")
            
            return result
        except Exception as e:
            if isinstance(e, ResourceNotFoundError):
                raise
            raise BlockchainError(f"Error retrieving block: {e}")
    
    async def get_gas_price(self) -> Dict[str, Any]:
        """
        Get current gas price.
        
        Returns:
            Dict[str, Any]: Gas price information
        
        Raises:
            BlockchainError: If gas price retrieval fails
        """
        try:
            # Execute get gas price command
            result = await self.bridge.execute("Blockchain.getGasPrice", [
                self.connection_id
            ])
            
            return result
        except Exception as e:
            raise BlockchainError(f"Error retrieving gas price: {e}")
    
    async def estimate_gas(
        self,
        from_address: str,
        to_address: str,
        value: str,
        data: str
    ) -> int:
        """
        Estimate gas for a transaction.
        
        Args:
            from_address: Sender address
            to_address: Recipient address
            value: Transaction value
            data: Transaction data
        
        Returns:
            int: Estimated gas
        
        Raises:
            BlockchainError: If gas estimation fails
        """
        try:
            # Execute estimate gas command
            result = await self.bridge.execute("Blockchain.estimateGas", [
                from_address,
                to_address,
                value,
                data,
                self.connection_id
            ])
            
            return result
        except Exception as e:
            raise BlockchainError(f"Error estimating gas: {e}")
    
    async def call_contract(
        self,
        contract_address: str,
        method: str,
        args: List[Any],
        from_address: Optional[str] = None
    ) -> Any:
        """
        Call a contract method.
        
        Args:
            contract_address: Contract address
            method: Method name
            args: Method arguments
            from_address: Sender address (optional)
        
        Returns:
            Any: Method result
        
        Raises:
            BlockchainError: If contract call fails
        """
        try:
            # Execute call contract method command
            result = await self.bridge.execute("Blockchain.callContractMethod", [
                contract_address,
                method,
                args,
                from_address,
                self.connection_id
            ])
            
            return result
        except Exception as e:
            raise BlockchainError(f"Error calling contract method: {e}")
    
    async def get_contract_abi(self, contract_address: str) -> List[Dict[str, Any]]:
        """
        Get a contract ABI.
        
        Args:
            contract_address: Contract address
        
        Returns:
            List[Dict[str, Any]]: Contract ABI
        
        Raises:
            BlockchainError: If ABI retrieval fails
        """
        try:
            # Execute get contract ABI command
            result = await self.bridge.execute("Blockchain.getContractABI", [
                contract_address,
                self.connection_id
            ])
            
            return result
        except Exception as e:
            raise BlockchainError(f"Error retrieving contract ABI: {e}")
    
    def __repr__(self) -> str:
        """
        Get a string representation of the blockchain connection.
        
        Returns:
            str: String representation
        """
        return f"BlockchainConnection(chain={self.chain}, network={self.network}, connected={self.connected})"
