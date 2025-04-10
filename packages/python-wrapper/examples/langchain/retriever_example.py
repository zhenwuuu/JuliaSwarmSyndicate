"""
Example of using JuliaOS retrievers with LangChain.

This example demonstrates how to use JuliaOS retrievers with LangChain.
"""

import asyncio
import os
from dotenv import load_dotenv

from langchain_openai import ChatOpenAI, OpenAIEmbeddings
from langchain.chains import RetrievalQA
from langchain.schema import Document

from juliaos import JuliaOS
from juliaos.langchain import (
    JuliaOSRetriever,
    JuliaOSVectorStoreRetriever
)


async def main():
    # Load environment variables
    load_dotenv()
    
    # Initialize JuliaOS
    juliaos = JuliaOS()
    await juliaos.connect()
    
    # Initialize OpenAI LLM and embeddings
    llm = ChatOpenAI(
        api_key=os.getenv("OPENAI_API_KEY"),
        model="gpt-4"
    )
    embeddings = OpenAIEmbeddings(
        api_key=os.getenv("OPENAI_API_KEY")
    )
    
    print("=== JuliaOS Retrievers with LangChain Example ===\n")
    
    try:
        # Example 1: Basic Retriever
        print("Example 1: Basic Retriever")
        
        # Create a basic retriever
        basic_retriever = JuliaOSRetriever(
            bridge=juliaos.bridge,
            storage_type="local",
            collection_name="crypto_docs"
        )
        
        # Add some documents
        print("\nAdding documents to the basic retriever...")
        await basic_retriever.add_documents([
            Document(
                page_content="Bitcoin is a decentralized digital currency that can be transferred on the peer-to-peer bitcoin network.",
                metadata={"source": "wikipedia", "topic": "bitcoin"}
            ),
            Document(
                page_content="Ethereum is a decentralized, open-source blockchain with smart contract functionality.",
                metadata={"source": "wikipedia", "topic": "ethereum"}
            ),
            Document(
                page_content="Solana is a public blockchain platform with smart contract functionality. Its native cryptocurrency is SOL.",
                metadata={"source": "wikipedia", "topic": "solana"}
            ),
            Document(
                page_content="Chainlink is a decentralized oracle network that provides real-world data to smart contracts on the blockchain.",
                metadata={"source": "wikipedia", "topic": "chainlink"}
            )
        ])
        
        # Create a retrieval QA chain
        basic_qa = RetrievalQA.from_chain_type(
            llm=llm,
            chain_type="stuff",
            retriever=basic_retriever,
            verbose=True
        )
        
        # Run the chain
        print("\nRunning the basic retriever QA chain...")
        basic_result = await basic_qa.ainvoke({"query": "What is Ethereum?"})
        print(f"\nBasic Retriever Result: {basic_result['result']}\n")
        
        # Example 2: Vector Store Retriever
        print("Example 2: Vector Store Retriever")
        
        # Create a vector store retriever
        vector_retriever = JuliaOSVectorStoreRetriever(
            bridge=juliaos.bridge,
            storage_type="local",
            collection_name="crypto_vectors",
            embeddings=embeddings,
            search_kwargs={"similarity_threshold": 0.7, "limit": 2}
        )
        
        # Add some documents
        print("\nAdding documents to the vector store retriever...")
        await vector_retriever.add_documents([
            Document(
                page_content="Bitcoin (BTC) is the first cryptocurrency. It uses a proof-of-work consensus mechanism.",
                metadata={"source": "crypto_guide", "topic": "bitcoin"}
            ),
            Document(
                page_content="Ethereum (ETH) is transitioning from proof-of-work to proof-of-stake with Ethereum 2.0.",
                metadata={"source": "crypto_guide", "topic": "ethereum"}
            ),
            Document(
                page_content="Solana (SOL) uses a proof-of-history consensus mechanism combined with proof-of-stake.",
                metadata={"source": "crypto_guide", "topic": "solana"}
            ),
            Document(
                page_content="Chainlink (LINK) provides decentralized oracle services to smart contracts on various blockchains.",
                metadata={"source": "crypto_guide", "topic": "chainlink"}
            ),
            Document(
                page_content="DeFi (Decentralized Finance) refers to financial services built on blockchain technology.",
                metadata={"source": "crypto_guide", "topic": "defi"}
            )
        ])
        
        # Create a retrieval QA chain
        vector_qa = RetrievalQA.from_chain_type(
            llm=llm,
            chain_type="stuff",
            retriever=vector_retriever,
            verbose=True
        )
        
        # Run the chain
        print("\nRunning the vector store retriever QA chain...")
        vector_result = await vector_qa.ainvoke({"query": "What consensus mechanism does Solana use?"})
        print(f"\nVector Store Retriever Result: {vector_result['result']}\n")
        
        # Example 3: Combined Retrieval
        print("Example 3: Combined Retrieval")
        
        # Create a custom retriever that combines results from both retrievers
        class CombinedRetriever:
            def __init__(self, retrievers):
                self.retrievers = retrievers
            
            async def aget_relevant_documents(self, query):
                all_docs = []
                for retriever in self.retrievers:
                    docs = await retriever.aget_relevant_documents(query)
                    all_docs.extend(docs)
                return all_docs
            
            def get_relevant_documents(self, query):
                return asyncio.run(self.aget_relevant_documents(query))
        
        # Create a combined retriever
        combined_retriever = CombinedRetriever([basic_retriever, vector_retriever])
        
        # Create a retrieval QA chain
        combined_qa = RetrievalQA.from_chain_type(
            llm=llm,
            chain_type="stuff",
            retriever=combined_retriever,
            verbose=True
        )
        
        # Run the chain
        print("\nRunning the combined retriever QA chain...")
        combined_result = await combined_qa.ainvoke({"query": "Compare Bitcoin and Ethereum."})
        print(f"\nCombined Retriever Result: {combined_result['result']}\n")
    finally:
        # Disconnect from JuliaOS
        await juliaos.disconnect()
        print("Done!")


if __name__ == "__main__":
    asyncio.run(main())
