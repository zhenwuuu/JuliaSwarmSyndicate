"""
Example of using Google Agent Development Kit (ADK) integration with JuliaOS.

This example demonstrates how to use the Google ADK integration with JuliaOS.
"""

import asyncio
import os
from dotenv import load_dotenv

from juliaos import JuliaOS
from juliaos.adk import JuliaOSADKAdapter, JuliaOSADKAgent, JuliaOSADKTool, JuliaOSADKMemory

# Check if Google ADK is available
try:
    from google.agent.sdk import AgentConfig, ToolSpec
    ADK_AVAILABLE = True
except ImportError:
    ADK_AVAILABLE = False
    print("Google Agent Development Kit (ADK) is not installed.")
    print("Install it with 'pip install google-agent-sdk' or 'pip install juliaos[adk]'.")
    exit(1)


async def main():
    # Load environment variables
    load_dotenv()
    
    # Initialize JuliaOS
    juliaos = JuliaOS()
    await juliaos.connect()
    
    print("=== JuliaOS Google ADK Integration Example ===\n")
    
    try:
        # Create a JuliaOS agent
        agent_config = {
            "name": "trading_agent",
            "agent_type": "TRADING",
            "description": "A trading agent for cryptocurrency markets",
            "capabilities": ["trading", "market_analysis", "portfolio_management"],
            "parameters": {
                "risk_level": "medium",
                "max_position_size": 1000,
                "trading_pairs": ["BTC/USDT", "ETH/USDT", "SOL/USDT"]
            }
        }
        
        agent = await juliaos.agents.create_agent(agent_config)
        print(f"Created JuliaOS agent: {agent.name} (ID: {agent.id})")
        
        # Create ADK adapter
        adk_adapter = JuliaOSADKAdapter(juliaos.bridge)
        
        # Convert JuliaOS agent to ADK agent
        adk_agent = adk_adapter.agent_to_adk(agent)
        print(f"Converted to ADK agent: {adk_agent.config.name}")
        
        # Create a custom ADK tool
        async def get_market_sentiment(asset: str, timeframe: str = "1d") -> dict:
            """
            Get market sentiment for a specific asset.
            
            Args:
                asset: Asset symbol (e.g., "BTC")
                timeframe: Timeframe for analysis (e.g., "1h", "1d", "1w")
            
            Returns:
                dict: Market sentiment data
            """
            # Simulate market sentiment analysis
            import random
            sentiment_score = random.uniform(-1.0, 1.0)
            
            return {
                "asset": asset,
                "timeframe": timeframe,
                "sentiment_score": sentiment_score,
                "sentiment": "bullish" if sentiment_score > 0.3 else "bearish" if sentiment_score < -0.3 else "neutral",
                "confidence": random.uniform(0.5, 0.9)
            }
        
        sentiment_tool = JuliaOSADKTool(
            name="get_market_sentiment",
            description="Get market sentiment for a specific asset",
            function=get_market_sentiment
        )
        
        print(f"Created custom ADK tool: {sentiment_tool.spec.name}")
        
        # Create ADK memory with JuliaOS storage
        adk_memory = JuliaOSADKMemory(juliaos.storage, "adk_example")
        
        # Add a memory item
        from google.agent.sdk import MemoryContent
        memory_id = await adk_memory.add(MemoryContent(
            text="Bitcoin has shown strong momentum in recent weeks.",
            metadata={"asset": "BTC", "timestamp": "2023-04-10T12:00:00Z"}
        ))
        print(f"Added memory item: {memory_id}")
        
        # Retrieve the memory item
        memory_item = await adk_memory.get(memory_id)
        print(f"Retrieved memory item: {memory_item.text}")
        
        # Search for memory items
        search_results = await adk_memory.search("Bitcoin")
        print(f"Found {len(search_results)} memory items matching 'Bitcoin'")
        
        # Process user input with the ADK agent
        user_input = "What's the current market sentiment for Bitcoin?"
        print(f"\nUser input: {user_input}")
        
        response = await adk_agent.process(user_input)
        print(f"Agent response: {response.response}")
        
        # Run a tool directly
        tool_result = await adk_agent.run_tool("get_market_sentiment", {"asset": "BTC", "timeframe": "1d"})
        print(f"\nTool result: {tool_result}")
        
        # Clean up
        await adk_memory.clear()
        print("\nCleared memory items")
        
    finally:
        # Disconnect from JuliaOS
        await juliaos.disconnect()
        print("\nDisconnected from JuliaOS")


if __name__ == "__main__":
    asyncio.run(main())
