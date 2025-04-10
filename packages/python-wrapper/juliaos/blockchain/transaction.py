"""
Transaction class for the JuliaOS Python wrapper.
"""

from typing import Dict, Any, Optional

from ..bridge import JuliaBridge
from ..exceptions import BlockchainError, ResourceNotFoundError


class Transaction:
    """
    Class representing a blockchain transaction.
    
    This class provides methods for interacting with a transaction.
    """
    
    def __init__(
        self,
        bridge: JuliaBridge,
        chain: str,
        network: str,
        transaction_data: Dict[str, Any]
    ):
        """
        Initialize a Transaction.
        
        Args:
            bridge: JuliaBridge instance for communicating with the JuliaOS server
            chain: Blockchain chain
            network: Blockchain network
            transaction_data: Transaction data from the server
        """
        self.bridge = bridge
        self.chain = chain
        self.network = network
        self.hash = transaction_data.get("hash")
        self.from_address = transaction_data.get("from")
        self.to_address = transaction_data.get("to")
        self.value = transaction_data.get("value")
        self.gas = transaction_data.get("gas")
        self.gas_price = transaction_data.get("gasPrice")
        self.nonce = transaction_data.get("nonce")
        self.data = transaction_data.get("data")
        self.block_number = transaction_data.get("blockNumber")
        self.block_hash = transaction_data.get("blockHash")
        self.timestamp = transaction_data.get("timestamp")
        self.status = transaction_data.get("status")
        self._data = transaction_data
    
    async def get_receipt(self) -> Dict[str, Any]:
        """
        Get the transaction receipt.
        
        Returns:
            Dict[str, Any]: Transaction receipt
        
        Raises:
            ResourceNotFoundError: If receipt is not found
            BlockchainError: If receipt retrieval fails
        """
        try:
            # Execute get transaction receipt command
            result = await self.bridge.execute("Blockchain.getTransactionReceipt", [
                self.hash,
                self.chain,
                self.network
            ])
            
            if not result:
                raise ResourceNotFoundError(f"Transaction receipt not found: {self.hash}")
            
            return result
        except Exception as e:
            if isinstance(e, ResourceNotFoundError):
                raise
            raise BlockchainError(f"Error retrieving transaction receipt: {e}")
    
    async def wait_for_confirmation(
        self,
        timeout: int = 60,
        poll_interval: int = 5
    ) -> Dict[str, Any]:
        """
        Wait for the transaction to be confirmed.
        
        Args:
            timeout: Timeout in seconds
            poll_interval: Polling interval in seconds
        
        Returns:
            Dict[str, Any]: Transaction receipt
        
        Raises:
            TimeoutError: If confirmation times out
            BlockchainError: If confirmation fails
        """
        try:
            # Execute wait for confirmation command
            result = await self.bridge.execute("Blockchain.waitForConfirmation", [
                self.hash,
                self.chain,
                self.network,
                timeout,
                poll_interval
            ])
            
            if not result.get("success", False):
                if "timeout" in result.get("error", "").lower():
                    raise TimeoutError(f"Transaction confirmation timed out after {timeout} seconds")
                raise BlockchainError(f"Failed to wait for confirmation: {result.get('error', 'Unknown error')}")
            
            # Update local data
            self.status = result.get("status")
            self.block_number = result.get("blockNumber", self.block_number)
            self.block_hash = result.get("blockHash", self.block_hash)
            self.timestamp = result.get("timestamp", self.timestamp)
            
            return result
        except Exception as e:
            if isinstance(e, (TimeoutError, BlockchainError)):
                raise
            raise BlockchainError(f"Error waiting for confirmation: {e}")
    
    async def get_events(self) -> Dict[str, Any]:
        """
        Get events emitted by the transaction.
        
        Returns:
            Dict[str, Any]: Transaction events
        
        Raises:
            ResourceNotFoundError: If transaction is not found
            BlockchainError: If event retrieval fails
        """
        try:
            # Execute get transaction events command
            result = await self.bridge.execute("Blockchain.getTransactionEvents", [
                self.hash,
                self.chain,
                self.network
            ])
            
            if not result.get("success", False):
                if "not found" in result.get("error", "").lower():
                    raise ResourceNotFoundError(f"Transaction not found: {self.hash}")
                raise BlockchainError(f"Failed to get transaction events: {result.get('error', 'Unknown error')}")
            
            return result.get("events", [])
        except Exception as e:
            if isinstance(e, (ResourceNotFoundError, BlockchainError)):
                raise
            raise BlockchainError(f"Error retrieving transaction events: {e}")
    
    async def decode_input(self) -> Dict[str, Any]:
        """
        Decode transaction input data.
        
        Returns:
            Dict[str, Any]: Decoded input data
        
        Raises:
            BlockchainError: If input decoding fails
        """
        try:
            # Execute decode transaction input command
            result = await self.bridge.execute("Blockchain.decodeTransactionInput", [
                self.hash,
                self.chain,
                self.network
            ])
            
            if not result.get("success", False):
                raise BlockchainError(f"Failed to decode transaction input: {result.get('error', 'Unknown error')}")
            
            return result.get("decoded", {})
        except Exception as e:
            if not isinstance(e, BlockchainError):
                raise BlockchainError(f"Error decoding transaction input: {e}")
            raise
    
    def to_dict(self) -> Dict[str, Any]:
        """
        Convert the transaction to a dictionary.
        
        Returns:
            Dict[str, Any]: Transaction data
        """
        return {
            "hash": self.hash,
            "from": self.from_address,
            "to": self.to_address,
            "value": self.value,
            "gas": self.gas,
            "gasPrice": self.gas_price,
            "nonce": self.nonce,
            "data": self.data,
            "blockNumber": self.block_number,
            "blockHash": self.block_hash,
            "timestamp": self.timestamp,
            "status": self.status,
            "chain": self.chain,
            "network": self.network
        }
    
    def __repr__(self) -> str:
        """
        Get a string representation of the transaction.
        
        Returns:
            str: String representation
        """
        return f"Transaction(hash={self.hash}, chain={self.chain}, status={self.status})"
