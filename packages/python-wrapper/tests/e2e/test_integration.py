"""
End-to-end tests for integration between all components.
"""

import asyncio
import pytest
import uuid
from juliaos.agents import AgentType
from juliaos.swarms import SwarmType
from juliaos.blockchain import Chain, Network
from juliaos.wallet import WalletType


@pytest.mark.asyncio
async def test_agent_wallet_integration(juliaos_client, clean_storage):
    """
    Test integration between agents and wallets.
    """
    # Create a wallet
    wallet = await juliaos_client.wallet.create_wallet(
        name="Agent Wallet",
        wallet_type=WalletType.HD
    )
    
    # Generate addresses
    eth_result = await wallet.generate_address(Chain.ETHEREUM)
    eth_address = eth_result["address"]
    
    sol_result = await wallet.generate_address(Chain.SOLANA)
    sol_address = sol_result["address"]
    
    # Create a trading agent
    agent = await juliaos_client.agents.create_agent(
        name="Wallet Integration Agent",
        agent_type=AgentType.TRADING,
        config={
            "parameters": {
                "risk_tolerance": 0.5,
                "max_position_size": 1000.0,
                "wallets": {
                    "ethereum": wallet.id,
                    "solana": wallet.id
                }
            }
        }
    )
    
    # Start the agent
    await agent.start()
    
    # Assign wallet to agent
    assign_result = await juliaos_client.bridge.execute("AgentBlockchainIntegration.assign_wallet", [
        agent.id,
        wallet.id,
        "ethereum"
    ])
    
    assert assign_result["success"] == True
    
    # Get agent wallet
    wallet_info = await juliaos_client.bridge.execute("AgentBlockchainIntegration.get_agent_wallet", [
        agent.id,
        "ethereum"
    ])
    
    assert wallet_info["success"] == True
    assert wallet_info["wallet"]["id"] == wallet.id
    
    # Clean up
    await agent.delete()
    await wallet.delete()


@pytest.mark.asyncio
async def test_agent_swarm_integration(juliaos_client, clean_storage):
    """
    Test integration between agents and swarms.
    """
    # Create agents
    agents = []
    for i in range(3):
        agent = await juliaos_client.agents.create_agent(
            name=f"Swarm Agent {i+1}",
            agent_type=AgentType.TRADING,
            config={
                "parameters": {
                    "risk_tolerance": 0.5,
                    "max_position_size": 1000.0
                }
            }
        )
        await agent.start()
        agents.append(agent)
    
    # Create a swarm
    swarm = await juliaos_client.swarms.create_swarm(
        name="Agent Swarm",
        swarm_type=SwarmType.TRADING,
        algorithm="DE",
        dimensions=2,
        bounds=[(-10.0, 10.0), (-10.0, 10.0)],
        config={
            "population_size": 20,
            "max_generations": 50
        }
    )
    
    # Add agents to swarm
    for agent in agents:
        await juliaos_client.storage.add_agent_to_swarm(swarm.id, agent.id)
    
    # Get swarm agents
    agents_result = await juliaos_client.storage.get_swarm_agents(swarm.id)
    assert agents_result["success"] == True
    assert len(agents_result["agents"]) == 3
    
    # Define a simple objective function
    function_id = "agent_swarm_test"
    function_code = """
    function(x)
        # This function simulates agent performance
        return sum(x.^2)
    end
    """
    
    await juliaos_client.swarms.set_objective_function(
        function_id=function_id,
        function_code=function_code,
        function_type="julia"
    )
    
    # Run optimization
    opt_result = await swarm.run_optimization(
        function_id=function_id,
        max_iterations=10,
        max_time_seconds=10
    )
    
    assert opt_result["success"] == True
    
    # Clean up
    for agent in agents:
        await agent.delete()
    
    await swarm.delete()


@pytest.mark.asyncio
async def test_full_system_integration(juliaos_client, clean_storage):
    """
    Test integration between all system components.
    """
    # Create a wallet
    wallet = await juliaos_client.wallet.create_wallet(
        name="System Integration Wallet",
        wallet_type=WalletType.HD
    )
    
    # Generate addresses
    eth_result = await wallet.generate_address(Chain.ETHEREUM)
    
    # Create agents
    trading_agent = await juliaos_client.agents.create_agent(
        name="System Trading Agent",
        agent_type=AgentType.TRADING,
        config={
            "parameters": {
                "risk_tolerance": 0.5,
                "max_position_size": 1000.0,
                "wallet_id": wallet.id
            }
        }
    )
    
    monitor_agent = await juliaos_client.agents.create_agent(
        name="System Monitor Agent",
        agent_type=AgentType.MONITOR,
        config={
            "parameters": {
                "check_interval": 60,
                "alert_channels": ["console"]
            }
        }
    )
    
    # Start agents
    await trading_agent.start()
    await monitor_agent.start()
    
    # Create a swarm
    swarm = await juliaos_client.swarms.create_swarm(
        name="System Integration Swarm",
        swarm_type=SwarmType.OPTIMIZATION,
        algorithm="DE",
        dimensions=2,
        bounds=[(-10.0, 10.0), (-10.0, 10.0)]
    )
    
    # Add agents to swarm
    await juliaos_client.storage.add_agent_to_swarm(swarm.id, trading_agent.id)
    await juliaos_client.storage.add_agent_to_swarm(swarm.id, monitor_agent.id)
    
    # Connect to blockchain
    eth_connection = await juliaos_client.blockchain.connect(
        chain=Chain.ETHEREUM,
        network=Network.MAINNET
    )
    
    # Get wallet balance
    balance_result = await wallet.get_balance(Chain.ETHEREUM)
    assert balance_result["success"] == True
    
    # Save system settings
    settings_result = await juliaos_client.storage.save_setting(
        "system_integration_test",
        {
            "wallet_id": wallet.id,
            "trading_agent_id": trading_agent.id,
            "monitor_agent_id": monitor_agent.id,
            "swarm_id": swarm.id
        }
    )
    
    assert settings_result["success"] == True
    
    # Get system settings
    get_settings = await juliaos_client.storage.get_setting("system_integration_test")
    assert get_settings["success"] == True
    assert get_settings["value"]["wallet_id"] == wallet.id
    
    # Clean up
    await trading_agent.delete()
    await monitor_agent.delete()
    await swarm.delete()
    await wallet.delete()
