"""
Example of using JuliaOS memory with LangChain.

This example demonstrates how to use JuliaOS memory with LangChain.
"""

import asyncio
import os
from dotenv import load_dotenv

from langchain_openai import ChatOpenAI
from langchain.chains import ConversationChain
from langchain.prompts import ChatPromptTemplate

from juliaos import JuliaOS
from juliaos.langchain import (
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
    
    print("=== JuliaOS Memory with LangChain Example ===\n")
    
    try:
        # Create a JuliaOSConversationBufferMemory
        print("Creating a JuliaOSConversationBufferMemory...")
        memory = JuliaOSConversationBufferMemory(
            bridge=juliaos.bridge,
            memory_key="chat_history"
        )
        
        # Create a prompt template
        prompt = ChatPromptTemplate.from_template(
            "You are a helpful assistant. Chat history: {chat_history}\nHuman: {input}\nAI: "
        )
        
        # Create a conversation chain
        print("Creating a conversation chain...")
        chain = ConversationChain(
            llm=llm,
            prompt=prompt,
            memory=memory,
            verbose=True
        )
        
        # Run the chain multiple times to demonstrate memory
        print("\nRunning the conversation chain...")
        
        # First message
        print("\nUser: Hello, I'm interested in crypto trading.")
        result1 = await chain.arun(input="Hello, I'm interested in crypto trading.")
        print(f"AI: {result1}")
        
        # Second message
        print("\nUser: What trading strategy would you recommend for a beginner?")
        result2 = await chain.arun(input="What trading strategy would you recommend for a beginner?")
        print(f"AI: {result2}")
        
        # Third message
        print("\nUser: Can you explain what dollar-cost averaging is?")
        result3 = await chain.arun(input="Can you explain what dollar-cost averaging is?")
        print(f"AI: {result3}")
        
        # Fourth message
        print("\nUser: How does that compare to value averaging?")
        result4 = await chain.arun(input="How does that compare to value averaging?")
        print(f"AI: {result4}")
        
        # Clear the memory
        print("\nClearing the memory...")
        memory.clear()
        
        # Verify that the memory was cleared
        print("\nUser: Do you remember what we were talking about?")
        result5 = await chain.arun(input="Do you remember what we were talking about?")
        print(f"AI: {result5}")
    finally:
        # Disconnect from JuliaOS
        await juliaos.disconnect()
        print("\nDone!")


if __name__ == "__main__":
    asyncio.run(main())
