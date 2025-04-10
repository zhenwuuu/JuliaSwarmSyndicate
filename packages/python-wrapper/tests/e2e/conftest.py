"""
Configuration for end-to-end tests.
"""

import asyncio
import os
import pytest
import logging
from juliaos import JuliaOS

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


@pytest.fixture(scope="session")
def event_loop():
    """
    Create an event loop for the test session.
    """
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(scope="session")
async def juliaos_client():
    """
    Create a JuliaOS client for the test session.
    """
    # Get connection details from environment or use defaults
    host = os.environ.get("JULIAOS_HOST", "localhost")
    port = int(os.environ.get("JULIAOS_PORT", "8080"))
    api_key = os.environ.get("JULIAOS_API_KEY")
    
    # Create client
    client = JuliaOS(host=host, port=port, api_key=api_key)
    
    # Connect to server
    try:
        await client.connect()
        logger.info(f"Connected to JuliaOS server at {host}:{port}")
        
        # Return client for tests to use
        yield client
    finally:
        # Disconnect when tests are done
        await client.disconnect()
        logger.info("Disconnected from JuliaOS server")


@pytest.fixture
async def clean_storage(juliaos_client):
    """
    Clean up storage before and after tests.
    """
    # Initialize storage
    await juliaos_client.storage.initialize()
    
    # Clean up existing agents and swarms
    agents = await juliaos_client.agents.list_agents()
    for agent in agents:
        await juliaos_client.agents.delete_agent(agent.id)
    
    swarms = await juliaos_client.swarms.list_swarms()
    for swarm in swarms:
        await juliaos_client.swarms.delete_swarm(swarm.id)
    
    wallets = await juliaos_client.wallet.list_wallets()
    for wallet in wallets:
        await juliaos_client.wallet.delete_wallet(wallet.id)
    
    # Run the test
    yield
    
    # Clean up after test
    agents = await juliaos_client.agents.list_agents()
    for agent in agents:
        await juliaos_client.agents.delete_agent(agent.id)
    
    swarms = await juliaos_client.swarms.list_swarms()
    for swarm in swarms:
        await juliaos_client.swarms.delete_swarm(swarm.id)
    
    wallets = await juliaos_client.wallet.list_wallets()
    for wallet in wallets:
        await juliaos_client.wallet.delete_wallet(wallet.id)
