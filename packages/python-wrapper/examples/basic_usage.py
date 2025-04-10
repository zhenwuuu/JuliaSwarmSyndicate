#!/usr/bin/env python3
"""
Basic usage example for the JuliaOS Python wrapper.
"""

import asyncio
import logging
from juliaos import JuliaOS
from juliaos.agents import AgentType
from juliaos.swarms import SwarmType
from juliaos.blockchain import Chain
from juliaos.wallet import WalletType

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


async def main():
    """
    Main function demonstrating basic usage of the JuliaOS Python wrapper.
    """
    # Initialize JuliaOS
    juliaos = JuliaOS(host="localhost", port=8080)
    await juliaos.connect()
    logger.info("Connected to JuliaOS server")
    
    try:
        # Get JuliaOS version
        version = await juliaos.get_version()
        logger.info(f"JuliaOS version: {version}")
        
        # Create a wallet
        wallet = await juliaos.wallet.create_wallet(
            name="Test Wallet",
            wallet_type=WalletType.HD
        )
        logger.info(f"Created wallet: {wallet.id} ({wallet.name})")
        
        # Generate addresses
        eth_address = await wallet.generate_address(Chain.ETHEREUM)
        sol_address = await wallet.generate_address(Chain.SOLANA)
        logger.info(f"Ethereum address: {eth_address}")
        logger.info(f"Solana address: {sol_address}")
        
        # Create a trading agent
        agent = await juliaos.agents.create_agent(
            name="Trading Agent",
            agent_type=AgentType.TRADING,
            config={
                "parameters": {
                    "risk_tolerance": 0.5,
                    "max_position_size": 1000.0,
                    "take_profit": 0.05,
                    "stop_loss": 0.03
                }
            }
        )
        logger.info(f"Created agent: {agent.id} ({agent.name})")
        
        # Start the agent
        await agent.start()
        logger.info(f"Started agent: {agent.status}")
        
        # Create a swarm
        swarm = await juliaos.swarms.create_swarm(
            name="Optimization Swarm",
            swarm_type=SwarmType.OPTIMIZATION,
            algorithm="DE",
            dimensions=2,
            bounds=[(-10.0, 10.0), (-10.0, 10.0)],
            config={
                "population_size": 20,
                "max_generations": 100
            }
        )
        logger.info(f"Created swarm: {swarm.id} ({swarm.name})")
        
        # Add agent to swarm
        await juliaos.storage.add_agent_to_swarm(swarm.id, agent.id)
        logger.info(f"Added agent {agent.id} to swarm {swarm.id}")
        
        # Get swarm agents
        swarm_agents = await juliaos.storage.get_swarm_agents(swarm.id)
        logger.info(f"Swarm agents: {[a['id'] for a in swarm_agents]}")
        
        # Execute a task on the agent
        task = await agent.execute_task({
            "type": "analyze_market",
            "parameters": {
                "asset": "BTC",
                "timeframe": "1h"
            }
        })
        logger.info(f"Executed task: {task.id}")
        
        # Wait for task completion (with timeout)
        try:
            result = await asyncio.wait_for(task.wait_for_completion(), timeout=10)
            logger.info(f"Task result: {result}")
        except asyncio.TimeoutError:
            logger.warning("Task execution timed out")
        
        # Stop the agent
        await agent.stop()
        logger.info(f"Stopped agent: {agent.status}")
        
        # Clean up
        await juliaos.agents.delete_agent(agent.id)
        await juliaos.swarms.delete_swarm(swarm.id)
        await juliaos.wallet.delete_wallet(wallet.id)
        logger.info("Cleaned up resources")
        
    except Exception as e:
        logger.error(f"Error: {e}")
    finally:
        # Disconnect from JuliaOS
        await juliaos.disconnect()
        logger.info("Disconnected from JuliaOS server")


if __name__ == "__main__":
    asyncio.run(main())
