"""
Example of using advanced JuliaOS tools with LangChain.

This example demonstrates how to use advanced JuliaOS tools with LangChain.
"""

import asyncio
import os
from dotenv import load_dotenv

from langchain_openai import ChatOpenAI
from langchain.agents import AgentExecutor, AgentType, initialize_agent
from langchain.chains import LLMChain
from langchain.prompts import ChatPromptTemplate

from juliaos import JuliaOS
from juliaos.langchain import (
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
    
    print("=== Advanced JuliaOS Tools with LangChain Example ===\n")
    
    try:
        # Create all the tools
        cross_chain_bridge_tool = CrossChainBridgeTool(juliaos.bridge)
        dex_trading_tool = DEXTradingTool(juliaos.bridge)
        yield_farming_tool = YieldFarmingTool(juliaos.bridge)
        nft_tool = NFTTool(juliaos.bridge)
        dao_tool = DAOTool(juliaos.bridge)
        social_media_tool = SocialMediaTool(juliaos.bridge)
        
        # Example 1: Cross-Chain Bridge Tool
        print("Example 1: Cross-Chain Bridge Tool")
        
        # Create an agent with the cross-chain bridge tool
        cross_chain_agent = initialize_agent(
            tools=[cross_chain_bridge_tool],
            llm=llm,
            agent=AgentType.STRUCTURED_CHAT_ZERO_SHOT_REACT_DESCRIPTION,
            verbose=True
        )
        
        # Run the agent
        print("\nRunning the agent with Cross-Chain Bridge Tool...")
        cross_chain_result = await cross_chain_agent.arun(
            "What's the most efficient way to transfer 100 USDC from Ethereum to Solana?"
        )
        print(f"\nCross-Chain Bridge Tool Result: {cross_chain_result}\n")
        
        # Example 2: DEX Trading Tool
        print("Example 2: DEX Trading Tool")
        
        # Create an agent with the DEX trading tool
        dex_agent = initialize_agent(
            tools=[dex_trading_tool],
            llm=llm,
            agent=AgentType.STRUCTURED_CHAT_ZERO_SHOT_REACT_DESCRIPTION,
            verbose=True
        )
        
        # Run the agent
        print("\nRunning the agent with DEX Trading Tool...")
        dex_result = await dex_agent.arun(
            "How can I swap 1 ETH for USDC on Uniswap with minimal slippage?"
        )
        print(f"\nDEX Trading Tool Result: {dex_result}\n")
        
        # Example 3: Yield Farming Tool
        print("Example 3: Yield Farming Tool")
        
        # Create an agent with the yield farming tool
        yield_farming_agent = initialize_agent(
            tools=[yield_farming_tool],
            llm=llm,
            agent=AgentType.STRUCTURED_CHAT_ZERO_SHOT_REACT_DESCRIPTION,
            verbose=True
        )
        
        # Run the agent
        print("\nRunning the agent with Yield Farming Tool...")
        yield_farming_result = await yield_farming_agent.arun(
            "What are the best yield farming opportunities for USDC on Ethereum?"
        )
        print(f"\nYield Farming Tool Result: {yield_farming_result}\n")
        
        # Example 4: NFT Tool
        print("Example 4: NFT Tool")
        
        # Create an agent with the NFT tool
        nft_agent = initialize_agent(
            tools=[nft_tool],
            llm=llm,
            agent=AgentType.STRUCTURED_CHAT_ZERO_SHOT_REACT_DESCRIPTION,
            verbose=True
        )
        
        # Run the agent
        print("\nRunning the agent with NFT Tool...")
        nft_result = await nft_agent.arun(
            "What NFTs does the address 0x742d35Cc6634C0532925a3b844Bc454e4438f44e own on Ethereum?"
        )
        print(f"\nNFT Tool Result: {nft_result}\n")
        
        # Example 5: DAO Tool
        print("Example 5: DAO Tool")
        
        # Create an agent with the DAO tool
        dao_agent = initialize_agent(
            tools=[dao_tool],
            llm=llm,
            agent=AgentType.STRUCTURED_CHAT_ZERO_SHOT_REACT_DESCRIPTION,
            verbose=True
        )
        
        # Run the agent
        print("\nRunning the agent with DAO Tool...")
        dao_result = await dao_agent.arun(
            "What are the active proposals in the Uniswap DAO?"
        )
        print(f"\nDAO Tool Result: {dao_result}\n")
        
        # Example 6: Social Media Tool
        print("Example 6: Social Media Tool")
        
        # Create an agent with the social media tool
        social_media_agent = initialize_agent(
            tools=[social_media_tool],
            llm=llm,
            agent=AgentType.STRUCTURED_CHAT_ZERO_SHOT_REACT_DESCRIPTION,
            verbose=True
        )
        
        # Run the agent
        print("\nRunning the agent with Social Media Tool...")
        social_media_result = await social_media_agent.arun(
            "What are the latest tweets about Bitcoin?"
        )
        print(f"\nSocial Media Tool Result: {social_media_result}\n")
        
        # Example 7: Combining Multiple Tools
        print("Example 7: Combining Multiple Tools")
        
        # Create an agent with multiple tools
        multi_tool_agent = initialize_agent(
            tools=[
                cross_chain_bridge_tool,
                dex_trading_tool,
                yield_farming_tool,
                nft_tool,
                dao_tool,
                social_media_tool
            ],
            llm=llm,
            agent=AgentType.STRUCTURED_CHAT_ZERO_SHOT_REACT_DESCRIPTION,
            verbose=True
        )
        
        # Run the agent
        print("\nRunning the agent with Multiple Tools...")
        multi_tool_result = await multi_tool_agent.arun(
            "I want to maximize my yield on 1000 USDC. Should I provide liquidity on a DEX, stake in a yield farming protocol, or bridge to another chain for better opportunities? Also, check if there are any relevant DAO proposals that might affect my decision."
        )
        print(f"\nMultiple Tools Result: {multi_tool_result}\n")
    finally:
        # Disconnect from JuliaOS
        await juliaos.disconnect()
        print("Done!")


if __name__ == "__main__":
    asyncio.run(main())
