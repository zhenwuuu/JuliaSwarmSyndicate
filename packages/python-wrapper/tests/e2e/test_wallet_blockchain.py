"""
End-to-end tests for wallet and blockchain functionality.
"""

import asyncio
import pytest
import uuid
from juliaos.wallet import WalletType
from juliaos.blockchain import Chain, Network


@pytest.mark.asyncio
async def test_wallet_lifecycle(juliaos_client, clean_storage):
    """
    Test the complete lifecycle of a wallet.
    """
    # Create a wallet
    wallet_id = str(uuid.uuid4())
    wallet_name = "Test Wallet"
    wallet_type = WalletType.HD
    
    wallet = await juliaos_client.wallet.create_wallet(
        name=wallet_name,
        wallet_type=wallet_type,
        wallet_id=wallet_id
    )
    
    # Verify wallet was created correctly
    assert wallet.id == wallet_id
    assert wallet.name == wallet_name
    assert wallet.type == wallet_type.value
    
    # Update wallet
    await wallet.update({"name": "Updated Test Wallet"})
    assert wallet.name == "Updated Test Wallet"
    
    # Generate addresses
    eth_result = await wallet.generate_address(Chain.ETHEREUM)
    assert eth_result["success"] == True
    assert "address" in eth_result
    assert eth_result["address"].startswith("0x")
    
    sol_result = await wallet.generate_address(Chain.SOLANA)
    assert sol_result["success"] == True
    assert "address" in sol_result
    
    # Get addresses
    addresses = await wallet.get_addresses()
    assert Chain.ETHEREUM in addresses
    assert Chain.SOLANA in addresses
    
    # Get specific address
    eth_address = await wallet.get_address(Chain.ETHEREUM)
    assert eth_address == addresses[Chain.ETHEREUM]
    
    # Export wallet
    export_result = await wallet.export()
    assert export_result["success"] == True
    assert "data" in export_result
    
    # Import wallet
    import_id = str(uuid.uuid4())
    import_result = await juliaos_client.wallet.import_wallet(
        name="Imported Wallet",
        import_data=export_result["data"],
        wallet_id=import_id
    )
    
    assert import_result.id == import_id
    assert import_result.name == "Imported Wallet"
    
    # Delete wallets
    await wallet.delete()
    await import_result.delete()
    
    # Verify wallets were deleted
    with pytest.raises(Exception):
        await juliaos_client.wallet.get_wallet(wallet_id)
    
    with pytest.raises(Exception):
        await juliaos_client.wallet.get_wallet(import_id)


@pytest.mark.asyncio
async def test_blockchain_connection(juliaos_client):
    """
    Test blockchain connection functionality.
    """
    # Get supported chains
    chains = await juliaos_client.blockchain.get_supported_chains()
    assert "ethereum" in chains
    assert "solana" in chains
    
    # Get chain info
    eth_info = await juliaos_client.blockchain.get_chain_info(Chain.ETHEREUM)
    assert eth_info["chain_id"] == 1
    
    # Connect to Ethereum
    eth_connection = await juliaos_client.blockchain.connect(
        chain=Chain.ETHEREUM,
        network=Network.MAINNET
    )
    
    assert eth_connection.chain == Chain.ETHEREUM
    assert eth_connection.network == Network.MAINNET
    assert eth_connection.connected == True
    
    # Get connection status
    status = await eth_connection.get_status()
    assert status["connected"] == True
    assert "block_height" in status
    
    # Get gas price
    gas_price = await eth_connection.get_gas_price()
    assert gas_price > 0
    
    # Connect to Solana
    sol_connection = await juliaos_client.blockchain.connect(
        chain=Chain.SOLANA,
        network=Network.MAINNET
    )
    
    assert sol_connection.chain == Chain.SOLANA
    assert sol_connection.network == Network.MAINNET
    assert sol_connection.connected == True


@pytest.mark.asyncio
async def test_wallet_blockchain_integration(juliaos_client, clean_storage):
    """
    Test integration between wallet and blockchain.
    """
    # Create a wallet
    wallet = await juliaos_client.wallet.create_wallet(
        name="Integration Test Wallet",
        wallet_type=WalletType.HD
    )
    
    # Generate addresses
    eth_result = await wallet.generate_address(Chain.ETHEREUM)
    eth_address = eth_result["address"]
    
    sol_result = await wallet.generate_address(Chain.SOLANA)
    sol_address = sol_result["address"]
    
    # Connect to blockchains
    eth_connection = await juliaos_client.blockchain.connect(
        chain=Chain.ETHEREUM,
        network=Network.MAINNET
    )
    
    sol_connection = await juliaos_client.blockchain.connect(
        chain=Chain.SOLANA,
        network=Network.MAINNET
    )
    
    # Get balances from blockchain
    eth_balance_blockchain = await eth_connection.get_balance(eth_address)
    sol_balance_blockchain = await sol_connection.get_balance(sol_address)
    
    # Get balances from wallet
    eth_balance_wallet = await wallet.get_balance(Chain.ETHEREUM)
    sol_balance_wallet = await wallet.get_balance(Chain.SOLANA)
    
    # Verify balances match
    assert eth_balance_wallet["balance"] == eth_balance_blockchain
    assert sol_balance_wallet["balance"] == sol_balance_blockchain
    
    # Get token balance (USDC on Ethereum)
    usdc_address = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
    
    token_balance_blockchain = await eth_connection.get_token_balance(
        eth_address,
        usdc_address
    )
    
    token_balance_wallet = await wallet.get_token_balance(
        Chain.ETHEREUM,
        usdc_address
    )
    
    # Verify token balances match
    assert token_balance_wallet["balance"] == token_balance_blockchain
    
    # Clean up
    await wallet.delete()
