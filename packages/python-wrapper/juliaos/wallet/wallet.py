"""
Wallet class for the JuliaOS Python wrapper.
"""

from typing import Dict, Any, List, Optional, Union

from ..bridge import JuliaBridge
from ..exceptions import WalletError, ResourceNotFoundError, InsufficientFundsError


class Wallet:
    """
    Class representing a wallet in the JuliaOS Framework.
    
    This class provides methods for interacting with a wallet, including
    generating addresses, getting balances, and sending transactions.
    """
    
    def __init__(self, bridge: JuliaBridge, data: Dict[str, Any]):
        """
        Initialize a Wallet.
        
        Args:
            bridge: JuliaBridge instance for communicating with the JuliaOS server
            data: Wallet data from the server
        """
        self.bridge = bridge
        self.id = data.get("id")
        self.name = data.get("name")
        self.type = data.get("type")
        self.status = data.get("status")
        self.addresses = data.get("addresses", {})
        self.created_at = data.get("created_at")
        self.updated_at = data.get("updated_at")
        self._data = data
    
    async def generate_address(self, chain: str) -> Dict[str, Any]:
        """
        Generate an address for a blockchain chain.
        
        Args:
            chain: Blockchain chain
        
        Returns:
            Dict[str, Any]: Address information
        
        Raises:
            WalletError: If address generation fails
        """
        try:
            # Execute generate address command
            result = await self.bridge.execute("Wallet.generate_address", [
                self.id,
                chain
            ])
            
            if not result.get("success", False):
                raise WalletError(f"Failed to generate address: {result.get('error', 'Unknown error')}")
            
            # Update local addresses
            if "address" in result:
                if "addresses" not in self._data:
                    self._data["addresses"] = {}
                self._data["addresses"][chain] = result["address"]
                self.addresses = self._data["addresses"]
            
            return result
        except Exception as e:
            if not isinstance(e, WalletError):
                raise WalletError(f"Error generating address: {e}")
            raise
    
    async def get_address(self, chain: str) -> str:
        """
        Get an address for a blockchain chain.
        
        Args:
            chain: Blockchain chain
        
        Returns:
            str: Address
        
        Raises:
            ResourceNotFoundError: If address is not found
            WalletError: If address retrieval fails
        """
        try:
            # Check if address exists in local data
            if chain in self.addresses:
                return self.addresses[chain]
            
            # Execute get address command
            result = await self.bridge.execute("Wallet.get_address", [
                self.id,
                chain
            ])
            
            if not result.get("success", False):
                if "not found" in result.get("error", "").lower():
                    raise ResourceNotFoundError(f"Address not found for chain: {chain}")
                raise WalletError(f"Failed to get address: {result.get('error', 'Unknown error')}")
            
            # Update local addresses
            if "address" in result:
                if "addresses" not in self._data:
                    self._data["addresses"] = {}
                self._data["addresses"][chain] = result["address"]
                self.addresses = self._data["addresses"]
                return result["address"]
            
            raise ResourceNotFoundError(f"Address not found for chain: {chain}")
        except Exception as e:
            if isinstance(e, (ResourceNotFoundError, WalletError)):
                raise
            raise WalletError(f"Error retrieving address: {e}")
    
    async def get_addresses(self) -> Dict[str, str]:
        """
        Get all addresses for the wallet.
        
        Returns:
            Dict[str, str]: Dictionary of chain -> address
        
        Raises:
            WalletError: If address retrieval fails
        """
        try:
            # Execute get addresses command
            result = await self.bridge.execute("Wallet.get_addresses", [self.id])
            
            if not result.get("success", False):
                raise WalletError(f"Failed to get addresses: {result.get('error', 'Unknown error')}")
            
            # Update local addresses
            if "addresses" in result:
                self._data["addresses"] = result["addresses"]
                self.addresses = self._data["addresses"]
            
            return self.addresses
        except Exception as e:
            if not isinstance(e, WalletError):
                raise WalletError(f"Error retrieving addresses: {e}")
            raise
    
    async def get_balance(self, chain: str) -> Dict[str, Any]:
        """
        Get balance for a blockchain chain.
        
        Args:
            chain: Blockchain chain
        
        Returns:
            Dict[str, Any]: Balance information
        
        Raises:
            ResourceNotFoundError: If address is not found
            WalletError: If balance retrieval fails
        """
        try:
            # Execute get balance command
            result = await self.bridge.execute("Wallet.get_balance", [
                self.id,
                chain
            ])
            
            if not result.get("success", False):
                if "not found" in result.get("error", "").lower():
                    raise ResourceNotFoundError(f"Address not found for chain: {chain}")
                raise WalletError(f"Failed to get balance: {result.get('error', 'Unknown error')}")
            
            return result
        except Exception as e:
            if isinstance(e, (ResourceNotFoundError, WalletError)):
                raise
            raise WalletError(f"Error retrieving balance: {e}")
    
    async def get_token_balance(self, chain: str, token_address: str) -> Dict[str, Any]:
        """
        Get token balance for a blockchain chain.
        
        Args:
            chain: Blockchain chain
            token_address: Token contract address
        
        Returns:
            Dict[str, Any]: Token balance information
        
        Raises:
            ResourceNotFoundError: If address is not found
            WalletError: If token balance retrieval fails
        """
        try:
            # Execute get token balance command
            result = await self.bridge.execute("Wallet.get_token_balance", [
                self.id,
                chain,
                token_address
            ])
            
            if not result.get("success", False):
                if "not found" in result.get("error", "").lower():
                    raise ResourceNotFoundError(f"Address not found for chain: {chain}")
                raise WalletError(f"Failed to get token balance: {result.get('error', 'Unknown error')}")
            
            return result
        except Exception as e:
            if isinstance(e, (ResourceNotFoundError, WalletError)):
                raise
            raise WalletError(f"Error retrieving token balance: {e}")
    
    async def send_transaction(
        self,
        chain: str,
        to_address: str,
        amount: str,
        token_address: Optional[str] = None,
        gas_limit: Optional[int] = None,
        gas_price: Optional[str] = None,
        data: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Send a transaction.
        
        Args:
            chain: Blockchain chain
            to_address: Recipient address
            amount: Amount to send
            token_address: Token contract address (None for native token)
            gas_limit: Gas limit (None for automatic estimation)
            gas_price: Gas price (None for automatic estimation)
            data: Transaction data (None for simple transfer)
        
        Returns:
            Dict[str, Any]: Transaction information
        
        Raises:
            ResourceNotFoundError: If address is not found
            InsufficientFundsError: If wallet has insufficient funds
            WalletError: If transaction fails
        """
        try:
            # Execute send transaction command
            result = await self.bridge.execute("Wallet.send_transaction", [
                self.id,
                chain,
                to_address,
                amount,
                token_address,
                gas_limit,
                gas_price,
                data
            ])
            
            if not result.get("success", False):
                error = result.get("error", "").lower()
                if "not found" in error:
                    raise ResourceNotFoundError(f"Address not found for chain: {chain}")
                if "insufficient funds" in error:
                    raise InsufficientFundsError(f"Insufficient funds: {error}")
                raise WalletError(f"Failed to send transaction: {error}")
            
            return result
        except Exception as e:
            if isinstance(e, (ResourceNotFoundError, InsufficientFundsError, WalletError)):
                raise
            raise WalletError(f"Error sending transaction: {e}")
    
    async def sign_message(self, chain: str, message: str) -> Dict[str, Any]:
        """
        Sign a message.
        
        Args:
            chain: Blockchain chain
            message: Message to sign
        
        Returns:
            Dict[str, Any]: Signature information
        
        Raises:
            ResourceNotFoundError: If address is not found
            WalletError: If message signing fails
        """
        try:
            # Execute sign message command
            result = await self.bridge.execute("Wallet.sign_message", [
                self.id,
                chain,
                message
            ])
            
            if not result.get("success", False):
                if "not found" in result.get("error", "").lower():
                    raise ResourceNotFoundError(f"Address not found for chain: {chain}")
                raise WalletError(f"Failed to sign message: {result.get('error', 'Unknown error')}")
            
            return result
        except Exception as e:
            if isinstance(e, (ResourceNotFoundError, WalletError)):
                raise
            raise WalletError(f"Error signing message: {e}")
    
    async def update(self, updates: Dict[str, Any]) -> bool:
        """
        Update the wallet.
        
        Args:
            updates: Updates to apply to the wallet
        
        Returns:
            bool: True if update was successful
        
        Raises:
            WalletError: If wallet update fails
        """
        try:
            # Execute update wallet command
            result = await self.bridge.execute("Wallet.update_wallet", [
                self.id,
                updates
            ])
            
            if not result.get("success", False):
                raise WalletError(f"Failed to update wallet: {result.get('error', 'Unknown error')}")
            
            # Update local data
            if "wallet" in result:
                wallet_data = result["wallet"]
                self.name = wallet_data.get("name", self.name)
                self.status = wallet_data.get("status", self.status)
                self.updated_at = wallet_data.get("updated_at", self.updated_at)
                self._data.update(wallet_data)
            
            return True
        except Exception as e:
            if not isinstance(e, WalletError):
                raise WalletError(f"Error updating wallet: {e}")
            raise
    
    async def delete(self) -> bool:
        """
        Delete the wallet.
        
        Returns:
            bool: True if deletion was successful
        
        Raises:
            WalletError: If wallet deletion fails
        """
        try:
            # Execute delete wallet command
            result = await self.bridge.execute("Wallet.delete_wallet", [self.id])
            
            if not result.get("success", False):
                raise WalletError(f"Failed to delete wallet: {result.get('error', 'Unknown error')}")
            
            return True
        except Exception as e:
            if not isinstance(e, WalletError):
                raise WalletError(f"Error deleting wallet: {e}")
            raise
    
    async def export(self) -> Dict[str, Any]:
        """
        Export the wallet.
        
        Returns:
            Dict[str, Any]: Wallet export data
        
        Raises:
            WalletError: If wallet export fails
        """
        try:
            # Execute export wallet command
            result = await self.bridge.execute("Wallet.export_wallet", [self.id])
            
            if not result.get("success", False):
                raise WalletError(f"Failed to export wallet: {result.get('error', 'Unknown error')}")
            
            return result
        except Exception as e:
            if not isinstance(e, WalletError):
                raise WalletError(f"Error exporting wallet: {e}")
            raise
    
    async def get_recovery_phrase(self) -> Dict[str, Any]:
        """
        Get the recovery phrase for the wallet.
        
        Returns:
            Dict[str, Any]: Recovery phrase information
        
        Raises:
            WalletError: If recovery phrase retrieval fails
        """
        try:
            # Execute get recovery phrase command
            result = await self.bridge.execute("Wallet.get_recovery_phrase", [self.id])
            
            if not result.get("success", False):
                raise WalletError(f"Failed to get recovery phrase: {result.get('error', 'Unknown error')}")
            
            return result
        except Exception as e:
            if not isinstance(e, WalletError):
                raise WalletError(f"Error retrieving recovery phrase: {e}")
            raise
    
    def to_dict(self) -> Dict[str, Any]:
        """
        Convert the wallet to a dictionary.
        
        Returns:
            Dict[str, Any]: Wallet data
        """
        return {
            "id": self.id,
            "name": self.name,
            "type": self.type,
            "status": self.status,
            "addresses": self.addresses,
            "created_at": self.created_at,
            "updated_at": self.updated_at
        }
    
    def __repr__(self) -> str:
        """
        Get a string representation of the wallet.
        
        Returns:
            str: String representation
        """
        return f"Wallet(id={self.id}, name={self.name}, type={self.type}, status={self.status})"
