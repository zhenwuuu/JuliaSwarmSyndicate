"""
Example of using the LangChain integration with JuliaOS.

This example demonstrates how to use the LangChain integration with JuliaOS
to create and run agents, chains, and tools.
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
    SwarmOptimizationTool,
    BlockchainQueryTool,
    JuliaOSConversationBufferMemory,
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
    
    print("=== LangChain Integration Example ===\n")
    
    # Example 1: Create a trading agent with LangChain
    print("Example 1: Creating a trading agent with LangChain")
    
    # Create a JuliaOS trading agent
    trading_agent = await juliaos.agents.create_agent(
        name="Trading Agent",
        agent_type="TRADING",
        config={"parameters": {"risk_tolerance": 0.5}}
    )
    
    # Create a LangChain agent from the JuliaOS agent
    langchain_agent = JuliaOSTradingAgentAdapter(trading_agent).as_langchain_agent(
        llm=llm,
        verbose=True
    )
    
    # Run the agent
    print("\nRunning the trading agent...")
    result = await langchain_agent.arun("Analyze the current market conditions for BTC/USDC and suggest a trading strategy.")
    print(f"\nResult: {result}\n")
    
    # Example 2: Using SwarmOptimizationTool
    print("Example 2: Using SwarmOptimizationTool")
    
    # Create a SwarmOptimizationTool
    swarm_tool = SwarmOptimizationTool(juliaos.bridge)
    
    # Create a prompt template
    prompt = ChatPromptTemplate.from_template(
        "You are an optimization expert. Use the swarm_optimization tool to find the minimum of the function described: {problem_description}"
    )
    
    # Create an LLMChain
    chain = LLMChain(llm=llm, prompt=prompt)
    
    # Create an agent executor with the tool
    agent_executor = AgentExecutor.from_agent_and_tools(
        agent=langchain_agent.agent,
        tools=[swarm_tool],
        verbose=True
    )
    
    # Run the agent
    print("\nRunning the swarm optimization...")
    result = await agent_executor.arun(
        problem_description="Find the minimum of the Rosenbrock function: f(x,y) = (1-x)^2 + 100(y-x^2)^2"
    )
    print(f"\nResult: {result}\n")
    
    # Example 3: Using SwarmOptimizationChain
    print("Example 3: Using SwarmOptimizationChain")
    
    # Create a SwarmOptimizationChain
    optimization_chain = SwarmOptimizationChain(
        bridge=juliaos.bridge,
        llm=llm,
        algorithm="DE"
    )
    
    # Run the chain
    print("\nRunning the swarm optimization chain...")
    result = await optimization_chain.arun(
        problem_description="Find the minimum of the Rosenbrock function: f(x,y) = (1-x)^2 + 100(y-x^2)^2",
        bounds=[[-5, 5], [-5, 5]],
        config={"population_size": 50, "max_iterations": 100}
    )
    print(f"\nResult: {result}\n")
    
    # Example 4: Using JuliaOSConversationBufferMemory
    print("Example 4: Using JuliaOSConversationBufferMemory")
    
    # Create a JuliaOSConversationBufferMemory
    memory = JuliaOSConversationBufferMemory(
        bridge=juliaos.bridge,
        memory_key="chat_history"
    )
    
    # Create a prompt template
    prompt = ChatPromptTemplate.from_template(
        "You are a helpful assistant. Chat history: {chat_history}\nHuman: {input}\nAI: "
    )
    
    # Create an LLMChain with memory
    chain = LLMChain(
        llm=llm,
        prompt=prompt,
        memory=memory,
        verbose=True
    )
    
    # Run the chain multiple times to demonstrate memory
    print("\nRunning the conversation chain...")
    result1 = await chain.arun(input="Hello, I'm interested in crypto trading.")
    print(f"Result 1: {result1}")
    
    result2 = await chain.arun(input="What trading strategy would you recommend for a beginner?")
    print(f"Result 2: {result2}")
    
    result3 = await chain.arun(input="Can you explain what dollar-cost averaging is?")
    print(f"Result 3: {result3}\n")
    
    # Clean up
    await juliaos.disconnect()
    print("Done!")


if __name__ == "__main__":
    asyncio.run(main())
