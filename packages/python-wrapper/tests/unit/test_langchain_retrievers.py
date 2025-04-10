"""
Unit tests for the LangChain retrievers integration with JuliaOS.

This module contains unit tests for the LangChain retrievers integration with JuliaOS.
"""

import unittest
from unittest.mock import MagicMock, patch
import asyncio

from langchain.schema import Document
from langchain.embeddings.base import Embeddings

from juliaos.bridge import JuliaBridge
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


class TestLangChainRetrievers(unittest.TestCase):
    """
    Test cases for the LangChain retrievers integration with JuliaOS.
    """
    
    def setUp(self):
        """Set up test fixtures."""
        self.bridge = MagicMock(spec=JuliaBridge)
        self.bridge.execute = MagicMock(return_value=asyncio.Future())
        self.bridge.execute.return_value.set_result({
            "success": True,
            "documents": [
                {
                    "id": "doc1",
                    "content": "Test document 1",
                    "metadata": {"source": "test"}
                },
                {
                    "id": "doc2",
                    "content": "Test document 2",
                    "metadata": {"source": "test"}
                }
            ],
            "count": 2
        })
        
        self.embeddings = MockEmbeddings()
    
    def test_retriever_initialization(self):
        """
        Test that the retriever can be initialized.
        """
        retriever = JuliaOSRetriever(
            bridge=self.bridge,
            storage_type="local",
            collection_name="test_collection"
        )
        
        self.assertEqual(retriever.bridge, self.bridge)
        self.assertEqual(retriever.storage_type, "local")
        self.assertEqual(retriever.collection_name, "test_collection")
    
    def test_vector_store_retriever_initialization(self):
        """
        Test that the vector store retriever can be initialized.
        """
        retriever = JuliaOSVectorStoreRetriever(
            bridge=self.bridge,
            storage_type="local",
            collection_name="test_collection",
            embeddings=self.embeddings,
            search_kwargs={"limit": 10}
        )
        
        self.assertEqual(retriever.bridge, self.bridge)
        self.assertEqual(retriever.storage_type, "local")
        self.assertEqual(retriever.collection_name, "test_collection")
        self.assertEqual(retriever.embeddings, self.embeddings)
        self.assertEqual(retriever.search_kwargs, {"limit": 10})
    
    @patch("asyncio.run")
    def test_get_relevant_documents(self, mock_run):
        """
        Test that the retriever can get relevant documents.
        """
        # Set up the mock
        mock_run.return_value = [
            Document(page_content="Test document 1", metadata={"source": "test"}),
            Document(page_content="Test document 2", metadata={"source": "test"})
        ]
        
        # Create a retriever
        retriever = JuliaOSRetriever(
            bridge=self.bridge,
            storage_type="local",
            collection_name="test_collection"
        )
        
        # Get relevant documents
        docs = retriever.get_relevant_documents("test query")
        
        # Verify the results
        self.assertEqual(len(docs), 2)
        self.assertEqual(docs[0].page_content, "Test document 1")
        self.assertEqual(docs[1].page_content, "Test document 2")
        
        # Verify that asyncio.run was called with the correct arguments
        mock_run.assert_called_once()
    
    async def test_aget_relevant_documents(self):
        """
        Test that the retriever can get relevant documents asynchronously.
        """
        # Create a retriever
        retriever = JuliaOSRetriever(
            bridge=self.bridge,
            storage_type="local",
            collection_name="test_collection"
        )
        
        # Get relevant documents
        docs = await retriever._aget_relevant_documents("test query")
        
        # Verify the results
        self.assertEqual(len(docs), 2)
        self.assertEqual(docs[0].page_content, "Test document 1")
        self.assertEqual(docs[1].page_content, "Test document 2")
        
        # Verify that bridge.execute was called with the correct arguments
        self.bridge.execute.assert_called_once_with("Storage.search_documents", [
            "local",
            "test_collection",
            "test query",
            {}
        ])
    
    async def test_add_documents(self):
        """
        Test that the retriever can add documents.
        """
        # Create a retriever
        retriever = JuliaOSRetriever(
            bridge=self.bridge,
            storage_type="local",
            collection_name="test_collection"
        )
        
        # Add documents
        await retriever.add_documents([
            Document(page_content="Test document 1", metadata={"source": "test"}),
            Document(page_content="Test document 2", metadata={"source": "test"})
        ])
        
        # Verify that bridge.execute was called with the correct arguments
        self.bridge.execute.assert_called_once()
        args = self.bridge.execute.call_args[0]
        self.assertEqual(args[0], "Storage.add_documents")
        self.assertEqual(args[1][0], "local")
        self.assertEqual(args[1][1], "test_collection")
        self.assertEqual(len(args[1][2]), 2)
        self.assertEqual(args[1][2][0]["content"], "Test document 1")
        self.assertEqual(args[1][2][1]["content"], "Test document 2")
    
    async def test_vector_store_retriever_add_documents(self):
        """
        Test that the vector store retriever can add documents.
        """
        # Create a vector store retriever
        retriever = JuliaOSVectorStoreRetriever(
            bridge=self.bridge,
            storage_type="local",
            collection_name="test_collection",
            embeddings=self.embeddings
        )
        
        # Add documents
        await retriever.add_documents([
            Document(page_content="Test document 1", metadata={"source": "test"}),
            Document(page_content="Test document 2", metadata={"source": "test"})
        ])
        
        # Verify that bridge.execute was called with the correct arguments
        self.bridge.execute.assert_called_once()
        args = self.bridge.execute.call_args[0]
        self.assertEqual(args[0], "Storage.add_vector_documents")
        self.assertEqual(args[1][0], "local")
        self.assertEqual(args[1][1], "test_collection")
        self.assertEqual(len(args[1][2]), 2)
        self.assertEqual(args[1][2][0]["content"], "Test document 1")
        self.assertEqual(args[1][2][1]["content"], "Test document 2")
        self.assertEqual(args[1][2][0]["embedding"], [0.1, 0.2, 0.3])
        self.assertEqual(args[1][2][1]["embedding"], [0.1, 0.2, 0.3])
    
    async def test_vector_store_retriever_aget_relevant_documents(self):
        """
        Test that the vector store retriever can get relevant documents asynchronously.
        """
        # Create a vector store retriever
        retriever = JuliaOSVectorStoreRetriever(
            bridge=self.bridge,
            storage_type="local",
            collection_name="test_collection",
            embeddings=self.embeddings,
            search_kwargs={"limit": 10}
        )
        
        # Get relevant documents
        docs = await retriever._aget_relevant_documents("test query")
        
        # Verify the results
        self.assertEqual(len(docs), 2)
        self.assertEqual(docs[0].page_content, "Test document 1")
        self.assertEqual(docs[1].page_content, "Test document 2")
        
        # Verify that bridge.execute was called with the correct arguments
        self.bridge.execute.assert_called_once_with("Storage.search_vector_documents", [
            "local",
            "test_collection",
            [0.1, 0.2, 0.3],
            {"limit": 10}
        ])
    
    async def test_vector_store_retriever_without_embeddings(self):
        """
        Test that the vector store retriever falls back to text search without embeddings.
        """
        # Create a vector store retriever without embeddings
        retriever = JuliaOSVectorStoreRetriever(
            bridge=self.bridge,
            storage_type="local",
            collection_name="test_collection"
        )
        
        # Get relevant documents
        docs = await retriever._aget_relevant_documents("test query")
        
        # Verify the results
        self.assertEqual(len(docs), 2)
        self.assertEqual(docs[0].page_content, "Test document 1")
        self.assertEqual(docs[1].page_content, "Test document 2")
        
        # Verify that bridge.execute was called with the correct arguments
        self.bridge.execute.assert_called_once_with("Storage.search_documents", [
            "local",
            "test_collection",
            "test query",
            {}
        ])


if __name__ == "__main__":
    unittest.main()
