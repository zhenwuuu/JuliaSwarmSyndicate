"""
Example of using advanced JuliaOS agents with LangChain.

This example demonstrates how to use advanced JuliaOS agents with LangChain.
"""

import asyncio
import os
from dotenv import load_dotenv

from langchain_openai import ChatOpenAI
from langchain.agents import AgentExecutor
from langchain.chains import LLMChain
from langchain.prompts import ChatPromptTemplate

from juliaos import JuliaOS
from juliaos.agents import AgentType
from juliaos.langchain import (
    JuliaOSPortfolioAgentAdapter,
    JuliaOSMarketMakingAgentAdapter,
    JuliaOSLiquidityAgentAdapter,
    JuliaOSYieldFarmingAgentAdapter,
    JuliaOSCrossChainAgentAdapter,
    CrossChainBridgeTool,
    DEXTradingTool,
    YieldFarmingTool,
    NFTTool,
    DAOTool,
    SocialMediaTool
)


async def main():
    # Load environment variables
    load_dotenv()
    
    # Initialize JuliaOS
    juliaos = JuliaOS()
    await juliaos.connect()
    
    # Initialize OpenAI LLM
    llm = ChatOpenAI(
        api_key=os.getenv("OPENAI_API_KEY"),
        model="gpt-4"
    )
    
    print("=== Advanced JuliaOS Agents with LangChain Example ===\n")
    
    try:
        # Example 1: Portfolio Management Agent
        print("Example 1: Portfolio Management Agent")
        
        # Create a JuliaOS portfolio agent
        portfolio_agent = await juliaos.agents.create_agent(
            name="Portfolio Management Agent",
            agent_type=AgentType.PORTFOLIO,
            config={
                "parameters": {
                    "risk_tolerance": 0.5,
                    "rebalance_frequency": "weekly",
                    "target_allocation": {
                        "BTC": 0.4,
                        "ETH": 0.3,
                        "SOL": 0.2,
                        "USDC": 0.1
                    }
                }
            }
        )
        
        # Create a LangChain agent from the JuliaOS portfolio agent
        portfolio_langchain_agent = JuliaOSPortfolioAgentAdapter(portfolio_agent).as_langchain_agent(
            llm=llm,
            verbose=True
        )
        
        # Run the portfolio agent
        print("\nRunning the portfolio agent...")
        portfolio_result = await portfolio_langchain_agent.arun(
            "Analyze my current portfolio and suggest rebalancing actions to optimize for the current market conditions."
        )
        print(f"\nPortfolio Agent Result: {portfolio_result}\n")
        
        # Example 2: Cross-Chain Agent with Bridge Tool
        print("Example 2: Cross-Chain Agent with Bridge Tool")
        
        # Create a JuliaOS cross-chain agent
        cross_chain_agent = await juliaos.agents.create_agent(
            name="Cross-Chain Agent",
            agent_type=AgentType.CROSS_CHAIN,
            config={
                "parameters": {
                    "supported_chains": ["ethereum", "solana", "arbitrum", "base"],
                    "default_bridge": "wormhole",
                    "max_slippage": 0.5
                }
            }
        )
        
        # Create tools for the cross-chain agent
        cross_chain_bridge_tool = CrossChainBridgeTool(juliaos.bridge)
        
        # Create a LangChain agent from the JuliaOS cross-chain agent
        cross_chain_langchain_agent = JuliaOSCrossChainAgentAdapter(cross_chain_agent).as_langchain_agent(
            llm=llm,
            tools=[cross_chain_bridge_tool],
            verbose=True
        )
        
        # Run the cross-chain agent
        print("\nRunning the cross-chain agent...")
        cross_chain_result = await cross_chain_langchain_agent.arun(
            "Find the most efficient way to transfer 100 USDC from Ethereum to Solana."
        )
        print(f"\nCross-Chain Agent Result: {cross_chain_result}\n")
        
        # Example 3: Yield Farming Agent with Yield Farming Tool
        print("Example 3: Yield Farming Agent with Yield Farming Tool")
        
        # Create a JuliaOS yield farming agent
        yield_farming_agent = await juliaos.agents.create_agent(
            name="Yield Farming Agent",
            agent_type=AgentType.YIELD_FARMING,
            config={
                "parameters": {
                    "risk_tolerance": 0.7,
                    "min_apy": 5.0,
                    "max_lockup_period": "30d",
                    "supported_protocols": ["aave", "compound", "curve"]
                }
            }
        )
        
        # Create tools for the yield farming agent
        yield_farming_tool = YieldFarmingTool(juliaos.bridge)
        dex_trading_tool = DEXTradingTool(juliaos.bridge)
        
        # Create a LangChain agent from the JuliaOS yield farming agent
        yield_farming_langchain_agent = JuliaOSYieldFarmingAgentAdapter(yield_farming_agent).as_langchain_agent(
            llm=llm,
            tools=[yield_farming_tool, dex_trading_tool],
            verbose=True
        )
        
        # Run the yield farming agent
        print("\nRunning the yield farming agent...")
        yield_farming_result = await yield_farming_langchain_agent.arun(
            "Find the highest yield farming opportunities for USDC with less than 30 days lockup period."
        )
        print(f"\nYield Farming Agent Result: {yield_farming_result}\n")
        
        # Example 4: Market Making Agent with DEX Trading Tool
        print("Example 4: Market Making Agent with DEX Trading Tool")
        
        # Create a JuliaOS market making agent
        market_making_agent = await juliaos.agents.create_agent(
            name="Market Making Agent",
            agent_type=AgentType.MARKET_MAKING,
            config={
                "parameters": {
                    "spread": 0.002,
                    "max_position": 10000.0,
                    "rebalance_threshold": 0.01,
                    "target_pairs": ["ETH/USDC", "BTC/USDC"]
                }
            }
        )
        
        # Create a LangChain agent from the JuliaOS market making agent
        market_making_langchain_agent = JuliaOSMarketMakingAgentAdapter(market_making_agent).as_langchain_agent(
            llm=llm,
            tools=[dex_trading_tool],
            verbose=True
        )
        
        # Run the market making agent
        print("\nRunning the market making agent...")
        market_making_result = await market_making_langchain_agent.arun(
            "Analyze the current market conditions for ETH/USDC and suggest market making parameters."
        )
        print(f"\nMarket Making Agent Result: {market_making_result}\n")
        
        # Example 5: Liquidity Agent with DEX Trading Tool
        print("Example 5: Liquidity Agent with DEX Trading Tool")
        
        # Create a JuliaOS liquidity agent
        liquidity_agent = await juliaos.agents.create_agent(
            name="Liquidity Agent",
            agent_type=AgentType.LIQUIDITY,
            config={
                "parameters": {
                    "min_apy": 10.0,
                    "max_impermanent_loss": 0.05,
                    "rebalance_frequency": "daily",
                    "target_pairs": ["ETH/USDC", "BTC/USDC"]
                }
            }
        )
        
        # Create a LangChain agent from the JuliaOS liquidity agent
        liquidity_langchain_agent = JuliaOSLiquidityAgentAdapter(liquidity_agent).as_langchain_agent(
            llm=llm,
            tools=[dex_trading_tool],
            verbose=True
        )
        
        # Run the liquidity agent
        print("\nRunning the liquidity agent...")
        liquidity_result = await liquidity_langchain_agent.arun(
            "Find the best liquidity pools to provide liquidity for ETH/USDC with the highest APY."
        )
        print(f"\nLiquidity Agent Result: {liquidity_result}\n")
        
        # Clean up
        await portfolio_agent.delete()
        await cross_chain_agent.delete()
        await yield_farming_agent.delete()
        await market_making_agent.delete()
        await liquidity_agent.delete()
    finally:
        # Disconnect from JuliaOS
        await juliaos.disconnect()
        print("Done!")


if __name__ == "__main__":
    asyncio.run(main())
