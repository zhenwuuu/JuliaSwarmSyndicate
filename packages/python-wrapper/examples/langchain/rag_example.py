"""
Example of using JuliaOS retrievers with LangChain for RAG (Retrieval-Augmented Generation).

This example demonstrates how to use JuliaOS retrievers with LangChain for RAG.
"""

import asyncio
import os
from dotenv import load_dotenv

from langchain_openai import ChatOpenAI, OpenAIEmbeddings
from langchain.chains import RetrievalQA, ConversationalRetrievalChain
from langchain.schema import Document
from langchain.prompts import PromptTemplate

from juliaos import JuliaOS
from juliaos.langchain import (
    JuliaOSVectorStoreRetriever,
    JuliaOSConversationBufferMemory
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
    
    print("=== JuliaOS RAG (Retrieval-Augmented Generation) Example ===\n")
    
    try:
        # Create a vector store retriever
        retriever = JuliaOSVectorStoreRetriever(
            bridge=juliaos.bridge,
            storage_type="local",
            collection_name="crypto_knowledge_base",
            embeddings=embeddings,
            search_kwargs={"similarity_threshold": 0.7, "limit": 5}
        )
        
        # Add documents to the knowledge base
        print("Adding documents to the knowledge base...")
        await retriever.add_documents([
            Document(
                page_content="""
                Bitcoin (BTC) is the first and most well-known cryptocurrency, created in 2009 by an anonymous person or group using the pseudonym Satoshi Nakamoto. 
                It operates on a decentralized network using blockchain technology, with transactions verified by network nodes through cryptography and recorded in a public distributed ledger.
                Bitcoin uses a proof-of-work consensus mechanism, where miners compete to solve complex mathematical problems to validate transactions and create new blocks.
                The total supply of Bitcoin is capped at 21 million coins, making it a deflationary asset.
                """,
                metadata={"source": "crypto_guide", "topic": "bitcoin", "type": "overview"}
            ),
            Document(
                page_content="""
                Ethereum (ETH) is a decentralized, open-source blockchain platform that enables the creation of smart contracts and decentralized applications (dApps).
                It was proposed in 2013 by Vitalik Buterin and went live in 2015.
                Ethereum is transitioning from a proof-of-work to a proof-of-stake consensus mechanism through a series of upgrades collectively known as Ethereum 2.0.
                The native cryptocurrency of the Ethereum blockchain is Ether (ETH), which is used to pay for transaction fees and computational services on the network.
                """,
                metadata={"source": "crypto_guide", "topic": "ethereum", "type": "overview"}
            ),
            Document(
                page_content="""
                Solana (SOL) is a high-performance blockchain platform designed for decentralized applications and marketplaces.
                It uses a unique combination of proof-of-stake and proof-of-history consensus mechanisms to achieve high throughput and low transaction costs.
                Solana can process thousands of transactions per second with sub-second finality and transaction fees as low as $0.00025.
                The Solana ecosystem includes various DeFi protocols, NFT marketplaces, and Web3 applications.
                """,
                metadata={"source": "crypto_guide", "topic": "solana", "type": "overview"}
            ),
            Document(
                page_content="""
                Decentralized Finance (DeFi) refers to financial applications built on blockchain technology that aim to recreate and improve upon traditional financial systems.
                DeFi applications include decentralized exchanges (DEXs), lending platforms, yield farming protocols, stablecoins, and insurance products.
                Key advantages of DeFi include permissionless access, transparency, programmability, and composability.
                Popular DeFi platforms include Uniswap, Aave, Compound, MakerDAO, and Curve Finance.
                """,
                metadata={"source": "crypto_guide", "topic": "defi", "type": "overview"}
            ),
            Document(
                page_content="""
                Non-Fungible Tokens (NFTs) are unique digital assets that represent ownership of a specific item or piece of content on the blockchain.
                Unlike cryptocurrencies such as Bitcoin or Ethereum, which are fungible and can be exchanged on a 1:1 basis, each NFT has distinct properties and values.
                NFTs can represent digital art, collectibles, music, videos, virtual real estate, in-game items, and even real-world assets.
                Popular NFT standards include ERC-721 and ERC-1155 on Ethereum, as well as SPL tokens on Solana.
                """,
                metadata={"source": "crypto_guide", "topic": "nft", "type": "overview"}
            ),
            Document(
                page_content="""
                Yield farming is a practice in DeFi where users provide liquidity to protocols in exchange for rewards, typically in the form of governance tokens or transaction fees.
                Common yield farming strategies include liquidity provision on DEXs, lending on platforms like Aave or Compound, and staking in liquidity pools.
                Yield farmers often move their assets between different protocols to maximize returns, a practice known as "yield hopping."
                Risks of yield farming include smart contract vulnerabilities, impermanent loss, and token price volatility.
                """,
                metadata={"source": "crypto_guide", "topic": "yield_farming", "type": "overview"}
            ),
            Document(
                page_content="""
                Stablecoins are cryptocurrencies designed to maintain a stable value, usually pegged to a fiat currency like the US dollar.
                Types of stablecoins include:
                - Fiat-collateralized (e.g., USDC, USDT): Backed 1:1 by reserves of the fiat currency they track
                - Crypto-collateralized (e.g., DAI): Backed by excess cryptocurrency collateral
                - Algorithmic (e.g., AMPL): Use algorithms to adjust supply based on demand
                Stablecoins serve as a bridge between traditional finance and crypto, offering price stability in volatile markets.
                """,
                metadata={"source": "crypto_guide", "topic": "stablecoins", "type": "overview"}
            ),
            Document(
                page_content="""
                Chainlink (LINK) is a decentralized oracle network that provides real-world data to smart contracts on various blockchain platforms.
                Oracles are essential for smart contracts to interact with external data sources, APIs, and payment systems.
                Chainlink uses a network of node operators to retrieve and verify data before delivering it to smart contracts.
                The LINK token is used to pay node operators for their services and as a form of stake to ensure honest behavior.
                """,
                metadata={"source": "crypto_guide", "topic": "chainlink", "type": "overview"}
            )
        ])
        
        # Create a memory for the conversation
        memory = JuliaOSConversationBufferMemory(
            bridge=juliaos.bridge,
            memory_key="chat_history",
            return_messages=True
        )
        
        # Create a custom prompt template for RAG
        template = """
        You are a helpful assistant specializing in cryptocurrency and blockchain technology.
        Use the following pieces of context to answer the question at the end.
        If you don't know the answer, just say that you don't know, don't try to make up an answer.
        
        Context:
        {context}
        
        Chat History:
        {chat_history}
        
        Question: {question}
        
        Answer:
        """
        
        prompt = PromptTemplate(
            input_variables=["context", "chat_history", "question"],
            template=template
        )
        
        # Create a conversational retrieval chain
        qa = ConversationalRetrievalChain.from_llm(
            llm=llm,
            retriever=retriever,
            memory=memory,
            combine_docs_chain_kwargs={"prompt": prompt},
            verbose=True
        )
        
        # Simulate a conversation
        questions = [
            "What is Bitcoin and how does it work?",
            "How does Ethereum differ from Bitcoin?",
            "Can you explain what DeFi is?",
            "What are the risks associated with yield farming?",
            "How do stablecoins maintain their value?",
            "What role does Chainlink play in the blockchain ecosystem?"
        ]
        
        for i, question in enumerate(questions):
            print(f"\nQuestion {i+1}: {question}")
            result = await qa.ainvoke({"question": question})
            print(f"Answer: {result['answer']}\n")
            print("-" * 80)
        
        # Ask a follow-up question that requires memory of the conversation
        follow_up = "Based on what we've discussed, which blockchain would be best for a high-frequency trading application?"
        print(f"\nFollow-up Question: {follow_up}")
        result = await qa.ainvoke({"question": follow_up})
        print(f"Answer: {result['answer']}\n")
    finally:
        # Disconnect from JuliaOS
        await juliaos.disconnect()
        print("Done!")


if __name__ == "__main__":
    asyncio.run(main())
