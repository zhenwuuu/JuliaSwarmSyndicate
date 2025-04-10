"""
Example of using JuliaOS with LangChain to develop and test trading strategies.

This example demonstrates how to use JuliaOS with LangChain to develop and test
trading strategies using the TradingStrategyChain.
"""

import asyncio
import os
from dotenv import load_dotenv

from langchain_openai import ChatOpenAI
from langchain.chains import LLMChain
from langchain.prompts import ChatPromptTemplate

from juliaos import JuliaOS
from juliaos.langchain import (
    TradingStrategyChain,
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
    
    print("=== JuliaOS Trading Strategy with LangChain Example ===\n")
    
    try:
        # Create a memory for the conversation
        memory = JuliaOSConversationBufferMemory(
            bridge=juliaos.bridge,
            memory_key="chat_history"
        )
        
        # Create a trading strategy chain
        strategy_chain = TradingStrategyChain(
            bridge=juliaos.bridge,
            llm=llm
        )
        
        # Define the trading strategy parameters
        market = "BTC/USDC"
        timeframe = "1h"
        strategy_description = """
        A mean reversion strategy that buys when the price is below the 20-period moving average
        and sells when the price is above the 20-period moving average. The strategy should also
        use the RSI indicator to confirm the entry and exit signals. It should buy when the RSI
        is below 30 and sell when the RSI is above 70.
        """
        parameters = {
            "ma_period": 20,
            "rsi_period": 14,
            "rsi_oversold": 30,
            "rsi_overbought": 70,
            "position_size": 0.1,  # 10% of available balance
            "stop_loss": 0.05,     # 5% stop loss
            "take_profit": 0.1     # 10% take profit
        }
        
        # Run the trading strategy chain
        print(f"Developing and testing a trading strategy for {market} on {timeframe} timeframe...")
        result = await strategy_chain.arun(
            market=market,
            timeframe=timeframe,
            strategy_description=strategy_description,
            parameters=parameters
        )
        
        # Print the results
        print("\n=== Trading Strategy Results ===\n")
        print(f"Strategy: {result['strategy']}\n")
        print(f"Backtest Results: {result['backtest_results']}\n")
        print(f"Analysis: {result['analysis']}\n")
        
        # Create a prompt template for refining the strategy
        refine_prompt = ChatPromptTemplate.from_template(
            """
            You are a trading strategy expert. You have developed the following strategy:
            
            {strategy}
            
            The backtest results are:
            
            {backtest_results}
            
            Based on these results, suggest improvements to the strategy to increase profitability
            and reduce drawdowns. Be specific about what parameters to change and why.
            """
        )
        
        # Create an LLMChain for refining the strategy
        refine_chain = LLMChain(
            llm=llm,
            prompt=refine_prompt,
            memory=memory,
            verbose=True
        )
        
        # Run the refine chain
        print("Refining the trading strategy...")
        refined_strategy = await refine_chain.arun(
            strategy=result["strategy"],
            backtest_results=result["backtest_results"]
        )
        
        print("\n=== Refined Trading Strategy ===\n")
        print(refined_strategy)
    finally:
        # Disconnect from JuliaOS
        await juliaos.disconnect()
        print("\nDone!")


if __name__ == "__main__":
    asyncio.run(main())
