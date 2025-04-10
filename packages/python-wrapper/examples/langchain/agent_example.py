"""
Example of using JuliaOS agents with LangChain.

This example demonstrates how to use JuliaOS agents with LangChain.
"""

import asyncio
import os
from dotenv import load_dotenv

from langchain_openai import ChatOpenAI
from langchain.agents import AgentExecutor
from langchain.chains import LLMChain
from langchain.prompts import ChatPromptTemplate

from juliaos import JuliaOS
from juliaos.langchain import (
    JuliaOSTradingAgentAdapter,
    BlockchainQueryTool,
    WalletOperationTool
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
    
    print("=== JuliaOS Agent with LangChain Example ===\n")
    
    try:
        # Create a JuliaOS trading agent
        print("Creating a JuliaOS trading agent...")
        trading_agent = await juliaos.agents.create_agent(
            name="Trading Agent",
            agent_type="TRADING",
            config={
                "parameters": {
                    "risk_tolerance": 0.5,
                    "max_position_size": 1000.0
                }
            }
        )
        
        # Create a LangChain agent from the JuliaOS agent
        print("Creating a LangChain agent from the JuliaOS agent...")
        langchain_agent = JuliaOSTradingAgentAdapter(trading_agent).as_langchain_agent(
            llm=llm,
            verbose=True
        )
        
        # Create additional tools
        print("Creating additional tools...")
        blockchain_tool = BlockchainQueryTool(juliaos.bridge)
        wallet_tool = WalletOperationTool(juliaos.bridge)
        
        # Create an agent executor with the tools
        print("Creating an agent executor with the tools...")
        agent_executor = AgentExecutor.from_agent_and_tools(
            agent=langchain_agent.agent,
            tools=[blockchain_tool, wallet_tool],
            verbose=True
        )
        
        # Run the agent
        print("\nRunning the agent...")
        result = await agent_executor.arun(
            "Analyze the current market conditions for BTC/USDC and suggest a trading strategy. "
            "Then check the balance of my wallet on Ethereum."
        )
        
        print(f"\nResult: {result}\n")
        
        # Clean up
        print("Cleaning up...")
        await trading_agent.delete()
    finally:
        # Disconnect from JuliaOS
        await juliaos.disconnect()
        print("Done!")


if __name__ == "__main__":
    asyncio.run(main())
