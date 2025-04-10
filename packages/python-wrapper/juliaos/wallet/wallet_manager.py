"""
Wallet manager for the JuliaOS Python wrapper.
"""

import uuid
from typing import Dict, Any, List, Optional, Union

from ..bridge import JuliaBridge
from ..exceptions import WalletError, ResourceNotFoundError
from .wallet import Wallet
from .wallet_types import WalletType


class WalletManager:
    """
    Manager for wallet operations.
    
    This class provides methods for creating, retrieving, and managing wallets.
    """
    
    def __init__(self, bridge: JuliaBridge):
        """
        Initialize the WalletManager.
        
        Args:
            bridge: JuliaBridge instance for communicating with the JuliaOS server
        """
        self.bridge = bridge
    
    async def create_wallet(
        self,
        name: str,
        wallet_type: Union[WalletType, str] = WalletType.HD,
        config: Dict[str, Any] = None,
        wallet_id: Optional[str] = None
    ) -> Wallet:
        """
        Create a new wallet.
        
        Args:
            name: Name of the wallet
            wallet_type: Type of the wallet
            config: Wallet configuration
            wallet_id: Optional wallet ID (if not provided, a UUID will be generated)
        
        Returns:
            Wallet: The created wallet
        
        Raises:
            WalletError: If wallet creation fails
        """
        # Convert wallet_type to string if it's an enum
        if isinstance(wallet_type, WalletType):
            wallet_type = wallet_type.value
        
        # Generate wallet ID if not provided
        if wallet_id is None:
            wallet_id = str(uuid.uuid4())
        
        # Ensure config is a dictionary
        if config is None:
            config = {}
        
        try:
            # Execute create wallet command
            result = await self.bridge.execute("Wallet.create_wallet", [
                wallet_id,
                name,
                wallet_type,
                config
            ])
            
            if not result.get("success", False):
                raise WalletError(f"Failed to create wallet: {result.get('error', 'Unknown error')}")
            
            # Create wallet instance
            return Wallet(self.bridge, result.get("wallet", {}))
        except Exception as e:
            if not isinstance(e, WalletError):
                raise WalletError(f"Error creating wallet: {e}")
            raise
    
    async def get_wallet(self, wallet_id: str) -> Wallet:
        """
        Get a wallet by ID.
        
        Args:
            wallet_id: ID of the wallet to retrieve
        
        Returns:
            Wallet: The retrieved wallet
        
        Raises:
            ResourceNotFoundError: If wallet is not found
            WalletError: If wallet retrieval fails
        """
        try:
            # Execute get wallet command
            result = await self.bridge.execute("Wallet.get_wallet_info", [wallet_id])
            
            if not result.get("success", False):
                if "not found" in result.get("error", "").lower():
                    raise ResourceNotFoundError(f"Wallet not found: {wallet_id}")
                raise WalletError(f"Failed to get wallet: {result.get('error', 'Unknown error')}")
            
            # Create wallet instance
            return Wallet(self.bridge, result.get("wallet", {}))
        except Exception as e:
            if isinstance(e, (ResourceNotFoundError, WalletError)):
                raise
            raise WalletError(f"Error retrieving wallet: {e}")
    
    async def list_wallets(self) -> List[Wallet]:
        """
        List all wallets.
        
        Returns:
            List[Wallet]: List of wallets
        
        Raises:
            WalletError: If wallet listing fails
        """
        try:
            # Execute list wallets command
            result = await self.bridge.execute("Wallet.list_wallets", [])
            
            if not result.get("success", False):
                raise WalletError(f"Failed to list wallets: {result.get('error', 'Unknown error')}")
            
            # Create wallet instances
            wallets = []
            for wallet_data in result.get("wallets", []):
                wallets.append(Wallet(self.bridge, wallet_data))
            
            return wallets
        except Exception as e:
            if not isinstance(e, WalletError):
                raise WalletError(f"Error listing wallets: {e}")
            raise
    
    async def delete_wallet(self, wallet_id: str) -> bool:
        """
        Delete a wallet.
        
        Args:
            wallet_id: ID of the wallet to delete
        
        Returns:
            bool: True if deletion was successful
        
        Raises:
            ResourceNotFoundError: If wallet is not found
            WalletError: If wallet deletion fails
        """
        try:
            # Execute delete wallet command
            result = await self.bridge.execute("Wallet.delete_wallet", [wallet_id])
            
            if not result.get("success", False):
                if "not found" in result.get("error", "").lower():
                    raise ResourceNotFoundError(f"Wallet not found: {wallet_id}")
                raise WalletError(f"Failed to delete wallet: {result.get('error', 'Unknown error')}")
            
            return True
        except Exception as e:
            if isinstance(e, (ResourceNotFoundError, WalletError)):
                raise
            raise WalletError(f"Error deleting wallet: {e}")
    
    async def import_wallet(
        self,
        name: str,
        import_data: Dict[str, Any],
        wallet_type: Union[WalletType, str] = WalletType.HD,
        wallet_id: Optional[str] = None
    ) -> Wallet:
        """
        Import a wallet.
        
        Args:
            name: Name of the wallet
            import_data: Wallet import data
            wallet_type: Type of the wallet
            wallet_id: Optional wallet ID (if not provided, a UUID will be generated)
        
        Returns:
            Wallet: The imported wallet
        
        Raises:
            WalletError: If wallet import fails
        """
        # Convert wallet_type to string if it's an enum
        if isinstance(wallet_type, WalletType):
            wallet_type = wallet_type.value
        
        # Generate wallet ID if not provided
        if wallet_id is None:
            wallet_id = str(uuid.uuid4())
        
        try:
            # Execute import wallet command
            result = await self.bridge.execute("Wallet.import_wallet", [
                wallet_id,
                name,
                import_data,
                wallet_type
            ])
            
            if not result.get("success", False):
                raise WalletError(f"Failed to import wallet: {result.get('error', 'Unknown error')}")
            
            # Create wallet instance
            return Wallet(self.bridge, result.get("wallet", {}))
        except Exception as e:
            if not isinstance(e, WalletError):
                raise WalletError(f"Error importing wallet: {e}")
            raise
    
    async def get_supported_chains(self) -> List[str]:
        """
        Get supported blockchain chains.
        
        Returns:
            List[str]: List of supported chains
        
        Raises:
            WalletError: If chain retrieval fails
        """
        try:
            # Execute get supported chains command
            result = await self.bridge.execute("WalletIntegration.get_supported_chains", [])
            
            if not result.get("success", False):
                raise WalletError(f"Failed to get supported chains: {result.get('error', 'Unknown error')}")
            
            return result.get("chains", [])
        except Exception as e:
            if not isinstance(e, WalletError):
                raise WalletError(f"Error retrieving supported chains: {e}")
            raise
    
    async def get_chain_info(self, chain: str) -> Dict[str, Any]:
        """
        Get information about a blockchain chain.
        
        Args:
            chain: Blockchain chain
        
        Returns:
            Dict[str, Any]: Chain information
        
        Raises:
            WalletError: If chain info retrieval fails
        """
        try:
            # Execute get chain info command
            result = await self.bridge.execute("WalletIntegration.get_chain_info", [chain])
            
            if not result.get("success", False):
                raise WalletError(f"Failed to get chain info: {result.get('error', 'Unknown error')}")
            
            return result.get("chain_info", {})
        except Exception as e:
            if not isinstance(e, WalletError):
                raise WalletError(f"Error retrieving chain info: {e}")
            raise
