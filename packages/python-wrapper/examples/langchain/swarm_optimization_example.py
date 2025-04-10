"""
Example of using JuliaOS swarm optimization with LangChain.

This example demonstrates how to use JuliaOS swarm optimization with LangChain.
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
    SwarmOptimizationTool,
    SwarmOptimizationChain
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
    
    print("=== JuliaOS Swarm Optimization with LangChain Example ===\n")
    
    try:
        # Example 1: Using SwarmOptimizationTool
        print("Example 1: Using SwarmOptimizationTool")
        
        # Create a SwarmOptimizationTool
        swarm_tool = SwarmOptimizationTool(juliaos.bridge)
        
        # Create an agent with the tool
        agent = initialize_agent(
            tools=[swarm_tool],
            llm=llm,
            agent=AgentType.STRUCTURED_CHAT_ZERO_SHOT_REACT_DESCRIPTION,
            verbose=True
        )
        
        # Run the agent
        print("\nRunning the agent with SwarmOptimizationTool...")
        result = await agent.arun(
            "Find the minimum of the Rosenbrock function: f(x,y) = (1-x)^2 + 100(y-x^2)^2"
        )
        
        print(f"\nResult: {result}\n")
        
        # Example 2: Using SwarmOptimizationChain
        print("Example 2: Using SwarmOptimizationChain")
        
        # Create a SwarmOptimizationChain
        chain = SwarmOptimizationChain(
            bridge=juliaos.bridge,
            llm=llm,
            algorithm="DE"
        )
        
        # Run the chain
        print("\nRunning the SwarmOptimizationChain...")
        result = await chain.arun(
            problem_description="Find the minimum of the Rosenbrock function: f(x,y) = (1-x)^2 + 100(y-x^2)^2",
            bounds=[[-5, 5], [-5, 5]],
            config={"population_size": 50, "max_iterations": 100}
        )
        
        print(f"\nResult: {result}\n")
    finally:
        # Disconnect from JuliaOS
        await juliaos.disconnect()
        print("Done!")


if __name__ == "__main__":
    asyncio.run(main())
