"""
Example of using JuliaOS with LangChain for portfolio optimization.

This example demonstrates how to use JuliaOS with LangChain to optimize a portfolio
using swarm optimization algorithms.
"""

import asyncio
import os
import json
from dotenv import load_dotenv

from langchain_openai import ChatOpenAI
from langchain.chains import LLMChain
from langchain.prompts import ChatPromptTemplate

from juliaos import JuliaOS
from juliaos.langchain import (
    SwarmOptimizationChain,
    BlockchainAnalysisChain,
    JuliaOSConversationBufferMemory
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
    
    print("=== JuliaOS Portfolio Optimization with LangChain Example ===\n")
    
    try:
        # Create a memory for the conversation
        memory = JuliaOSConversationBufferMemory(
            bridge=juliaos.bridge,
            memory_key="chat_history"
        )
        
        # Create a blockchain analysis chain
        blockchain_chain = BlockchainAnalysisChain(
            bridge=juliaos.bridge,
            llm=llm,
            chain="ethereum"
        )
        
        # Create a swarm optimization chain
        optimization_chain = SwarmOptimizationChain(
            bridge=juliaos.bridge,
            llm=llm,
            algorithm="DE"  # Differential Evolution
        )
        
        # Define the portfolio optimization problem
        problem_description = """
        Optimize a portfolio of 5 assets: BTC, ETH, SOL, AVAX, and MATIC.
        The objective is to maximize the Sharpe ratio (return / volatility) of the portfolio.
        The portfolio weights must sum to 1, and each weight must be between 0 and 0.5.
        """
        
        bounds = [
            [0, 0.5],  # BTC weight bounds
            [0, 0.5],  # ETH weight bounds
            [0, 0.5],  # SOL weight bounds
            [0, 0.5],  # AVAX weight bounds
            [0, 0.5],  # MATIC weight bounds
        ]
        
        config = {
            "population_size": 50,
            "max_iterations": 100,
            "constraint_handling": "penalty",
            "penalty_factor": 1000,
            "constraint_function": "sum(weights) == 1.0"
        }
        
        # Run the portfolio optimization
        print("Optimizing portfolio using Differential Evolution...")
        optimization_result = await optimization_chain.arun(
            problem_description=problem_description,
            bounds=bounds,
            config=config
        )
        
        # Print the optimization results
        print("\n=== Portfolio Optimization Results ===\n")
        print(f"Best Portfolio Weights: {optimization_result['best_position']}")
        print(f"Best Sharpe Ratio: {optimization_result['best_fitness']}")
        print(f"Iterations: {optimization_result['iterations']}\n")
        
        # Create a prompt template for analyzing the portfolio
        analysis_prompt = ChatPromptTemplate.from_template(
            """
            You are a portfolio manager. You have optimized a portfolio with the following weights:
            
            BTC: {btc_weight}
            ETH: {eth_weight}
            SOL: {sol_weight}
            AVAX: {avax_weight}
            MATIC: {matic_weight}
            
            The Sharpe ratio of this portfolio is {sharpe_ratio}.
            
            Analyze this portfolio allocation and provide insights on:
            1. The risk-return profile of the portfolio
            2. The diversification benefits
            3. Potential improvements to the allocation
            4. Market conditions that would favor or disfavor this allocation
            """
        )
        
        # Create an LLMChain for analyzing the portfolio
        analysis_chain = LLMChain(
            llm=llm,
            prompt=analysis_prompt,
            memory=memory,
            verbose=True
        )
        
        # Extract the weights from the optimization result
        weights = optimization_result['best_position']
        
        # Run the analysis chain
        print("Analyzing the optimized portfolio...")
        portfolio_analysis = await analysis_chain.arun(
            btc_weight=weights[0],
            eth_weight=weights[1],
            sol_weight=weights[2],
            avax_weight=weights[3],
            matic_weight=weights[4],
            sharpe_ratio=optimization_result['best_fitness']
        )
        
        print("\n=== Portfolio Analysis ===\n")
        print(portfolio_analysis)
        
        # Query blockchain data for the assets in the portfolio
        print("\nQuerying blockchain data for the assets in the portfolio...")
        
        # Query Ethereum data for ETH
        eth_data = await blockchain_chain.arun(
            address="0x0000000000000000000000000000000000000000",  # ETH address
            query_type="market_data",
            parameters={"timeframe": "1d", "limit": 30}
        )
        
        print("\n=== Ethereum Market Data Analysis ===\n")
        print(eth_data['analysis'])
    finally:
        # Disconnect from JuliaOS
        await juliaos.disconnect()
        print("\nDone!")


if __name__ == "__main__":
    asyncio.run(main())
