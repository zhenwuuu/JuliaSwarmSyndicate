"""
End-to-end tests for the LangChain retrievers integration with JuliaOS.

This module contains end-to-end tests for the LangChain retrievers integration with JuliaOS.
"""

import os
import pytest
import asyncio
from unittest.mock import MagicMock, patch

from langchain.schema import Document
from langchain.embeddings.base import Embeddings

from juliaos import JuliaOS
from juliaos.langchain import (
    JuliaOSRetriever,
    JuliaOSVectorStoreRetriever
)


class MockEmbeddings(Embeddings):
    """Mock embeddings for testing."""
    
    def embed_documents(self, texts):
        """Mock embed_documents method."""
        return [[0.1, 0.2, 0.3] for _ in texts]
    
    def embed_query(self, text):
        """Mock embed_query method."""
        return [0.1, 0.2, 0.3]


@pytest.mark.asyncio
async def test_basic_retriever():
    """
    Test that the basic retriever can be used with a real JuliaOS instance.
    """
    # Skip this test if JULIA_API_URL is not set
    if not os.environ.get("JULIA_API_URL"):
        pytest.skip("JULIA_API_URL not set")
    
    # Initialize JuliaOS
    juliaos = JuliaOS()
    await juliaos.connect()
    
    try:
        # Create a basic retriever
        retriever = JuliaOSRetriever(
            bridge=juliaos.bridge,
            storage_type="local",
            collection_name="test_collection_e2e"
        )
        
        # Add some documents
        await retriever.add_documents([
            Document(
                page_content="This is a test document for end-to-end testing.",
                metadata={"source": "e2e_test", "type": "test"}
            ),
            Document(
                page_content="Another test document with different content.",
                metadata={"source": "e2e_test", "type": "test"}
            )
        ])
        
        # Get relevant documents
        docs = await retriever.aget_relevant_documents("test document")
        
        # Verify the results
        assert len(docs) > 0
        assert any("test document" in doc.page_content.lower() for doc in docs)
        assert all(doc.metadata.get("source") == "e2e_test" for doc in docs)
    finally:
        await juliaos.disconnect()


@pytest.mark.asyncio
async def test_vector_store_retriever():
    """
    Test that the vector store retriever can be used with a real JuliaOS instance.
    """
    # Skip this test if JULIA_API_URL is not set
    if not os.environ.get("JULIA_API_URL"):
        pytest.skip("JULIA_API_URL not set")
    
    # Initialize JuliaOS
    juliaos = JuliaOS()
    await juliaos.connect()
    
    try:
        # Create mock embeddings
        embeddings = MockEmbeddings()
        
        # Create a vector store retriever
        retriever = JuliaOSVectorStoreRetriever(
            bridge=juliaos.bridge,
            storage_type="local",
            collection_name="test_vector_collection_e2e",
            embeddings=embeddings
        )
        
        # Add some documents
        await retriever.add_documents([
            Document(
                page_content="Vector test document for semantic search.",
                metadata={"source": "e2e_test", "type": "vector"}
            ),
            Document(
                page_content="Another vector document with different content.",
                metadata={"source": "e2e_test", "type": "vector"}
            )
        ])
        
        # Get relevant documents
        docs = await retriever.aget_relevant_documents("semantic search")
        
        # Verify the results
        assert len(docs) > 0
        assert all(doc.metadata.get("source") == "e2e_test" for doc in docs)
        assert all(doc.metadata.get("type") == "vector" for doc in docs)
    finally:
        await juliaos.disconnect()


@pytest.mark.asyncio
async def test_retriever_with_real_documents():
    """
    Test that the retriever can handle real-world documents.
    """
    # Skip this test if JULIA_API_URL is not set
    if not os.environ.get("JULIA_API_URL"):
        pytest.skip("JULIA_API_URL not set")
    
    # Initialize JuliaOS
    juliaos = JuliaOS()
    await juliaos.connect()
    
    try:
        # Create a basic retriever
        retriever = JuliaOSRetriever(
            bridge=juliaos.bridge,
            storage_type="local",
            collection_name="crypto_docs_e2e"
        )
        
        # Add some realistic documents
        await retriever.add_documents([
            Document(
                page_content="""
                Bitcoin is a decentralized digital currency, without a central bank or single administrator,
                that can be sent from user to user on the peer-to-peer bitcoin network without the need for
                intermediaries. Transactions are verified by network nodes through cryptography and recorded
                in a public distributed ledger called a blockchain.
                """,
                metadata={"source": "wikipedia", "topic": "bitcoin"}
            ),
            Document(
                page_content="""
                Ethereum is a decentralized, open-source blockchain with smart contract functionality.
                Ether is the native cryptocurrency of the platform. Among cryptocurrencies, Ether is second
                only to Bitcoin in market capitalization. Ethereum was conceived in 2013 by programmer
                Vitalik Buterin.
                """,
                metadata={"source": "wikipedia", "topic": "ethereum"}
            ),
            Document(
                page_content="""
                Solana is a public blockchain platform with smart contract functionality. Its native
                cryptocurrency is SOL. Solana claims to provide much faster transaction times and lower fees
                compared to other blockchains like Ethereum.
                """,
                metadata={"source": "wikipedia", "topic": "solana"}
            )
        ])
        
        # Test queries
        bitcoin_docs = await retriever.aget_relevant_documents("What is Bitcoin?")
        ethereum_docs = await retriever.aget_relevant_documents("Tell me about Ethereum")
        blockchain_docs = await retriever.aget_relevant_documents("blockchain technology")
        
        # Verify the results
        assert len(bitcoin_docs) > 0
        assert any("bitcoin" in doc.page_content.lower() for doc in bitcoin_docs)
        
        assert len(ethereum_docs) > 0
        assert any("ethereum" in doc.page_content.lower() for doc in ethereum_docs)
        
        assert len(blockchain_docs) > 0
        assert any("blockchain" in doc.page_content.lower() for doc in blockchain_docs)
    finally:
        await juliaos.disconnect()
