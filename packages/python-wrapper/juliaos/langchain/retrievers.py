"""
LangChain retrievers integration with JuliaOS storage.

This module provides retriever classes that use JuliaOS storage.
"""

from typing import Dict, Any, List, Optional, Union, Callable, Type
import asyncio
from pydantic import BaseModel, Field

from langchain.schema import BaseRetriever, Document
from langchain.vectorstores.base import VectorStore
from langchain.embeddings.base import Embeddings

from ..bridge import JuliaBridge


class JuliaOSRetriever(BaseRetriever):
    """
    Base retriever class using JuliaOS storage.
    
    This class provides the basic functionality for retrieving documents from JuliaOS storage.
    """
    
    bridge: JuliaBridge = Field(exclude=True)
    storage_type: str = "local"
    collection_name: str = "langchain_documents"
    
    def __init__(
        self,
        bridge: JuliaBridge,
        storage_type: str = "local",
        collection_name: str = "langchain_documents",
        **kwargs
    ):
        """
        Initialize the retriever with a JuliaBridge.
        
        Args:
            bridge: The JuliaBridge to use for communication with the Julia backend
            storage_type: The type of storage to use (local, arweave, etc.)
            collection_name: The name of the document collection in JuliaOS storage
            **kwargs: Additional arguments to pass to the BaseRetriever constructor
        """
        super().__init__(**kwargs)
        self.bridge = bridge
        self.storage_type = storage_type
        self.collection_name = collection_name
    
    def _get_relevant_documents(self, query: str) -> List[Document]:
        """
        Get documents relevant to the query.
        
        Args:
            query: The query to search for
        
        Returns:
            List[Document]: The relevant documents
        """
        # This is a synchronous method, so we need to run the async method in a new event loop
        return asyncio.run(self._aget_relevant_documents(query))
    
    async def _aget_relevant_documents(self, query: str) -> List[Document]:
        """
        Get documents relevant to the query asynchronously.
        
        Args:
            query: The query to search for
        
        Returns:
            List[Document]: The relevant documents
        """
        # Query the storage for documents
        result = await self.bridge.execute("Storage.search_documents", [
            self.storage_type,
            self.collection_name,
            query,
            {}  # Additional parameters
        ])
        
        # Convert the results to Document objects
        documents = []
        for doc_data in result.get("documents", []):
            documents.append(Document(
                page_content=doc_data.get("content", ""),
                metadata=doc_data.get("metadata", {})
            ))
        
        return documents
    
    async def add_documents(self, documents: List[Document]) -> None:
        """
        Add documents to the storage.
        
        Args:
            documents: The documents to add
        """
        # Convert the Document objects to a serializable format
        doc_data_list = []
        for doc in documents:
            doc_data_list.append({
                "content": doc.page_content,
                "metadata": doc.metadata
            })
        
        # Store the documents
        await self.bridge.execute("Storage.add_documents", [
            self.storage_type,
            self.collection_name,
            doc_data_list
        ])
    
    async def delete_documents(self, document_ids: List[str]) -> None:
        """
        Delete documents from the storage.
        
        Args:
            document_ids: The IDs of the documents to delete
        """
        await self.bridge.execute("Storage.delete_documents", [
            self.storage_type,
            self.collection_name,
            document_ids
        ])


class JuliaOSVectorStoreRetriever(JuliaOSRetriever):
    """
    Vector store retriever using JuliaOS storage.
    
    This class provides a vector store retriever that uses JuliaOS storage.
    """
    
    embeddings: Optional[Embeddings] = None
    search_kwargs: Dict[str, Any] = Field(default_factory=dict)
    
    def __init__(
        self,
        bridge: JuliaBridge,
        storage_type: str = "local",
        collection_name: str = "langchain_vector_documents",
        embeddings: Optional[Embeddings] = None,
        search_kwargs: Optional[Dict[str, Any]] = None,
        **kwargs
    ):
        """
        Initialize the retriever with a JuliaBridge.
        
        Args:
            bridge: The JuliaBridge to use for communication with the Julia backend
            storage_type: The type of storage to use (local, arweave, etc.)
            collection_name: The name of the document collection in JuliaOS storage
            embeddings: The embeddings to use for vectorizing documents
            search_kwargs: Additional arguments to pass to the search function
            **kwargs: Additional arguments to pass to the JuliaOSRetriever constructor
        """
        super().__init__(
            bridge=bridge,
            storage_type=storage_type,
            collection_name=collection_name,
            **kwargs
        )
        self.embeddings = embeddings
        self.search_kwargs = search_kwargs or {}
    
    async def _aget_relevant_documents(self, query: str) -> List[Document]:
        """
        Get documents relevant to the query asynchronously.
        
        Args:
            query: The query to search for
        
        Returns:
            List[Document]: The relevant documents
        """
        # If embeddings are provided, use them to vectorize the query
        if self.embeddings:
            query_embedding = self.embeddings.embed_query(query)
            
            # Query the storage for documents using the embedding
            result = await self.bridge.execute("Storage.search_vector_documents", [
                self.storage_type,
                self.collection_name,
                query_embedding,
                self.search_kwargs
            ])
        else:
            # Fall back to text search if no embeddings are provided
            result = await self.bridge.execute("Storage.search_documents", [
                self.storage_type,
                self.collection_name,
                query,
                self.search_kwargs
            ])
        
        # Convert the results to Document objects
        documents = []
        for doc_data in result.get("documents", []):
            documents.append(Document(
                page_content=doc_data.get("content", ""),
                metadata=doc_data.get("metadata", {})
            ))
        
        return documents
    
    async def add_documents(self, documents: List[Document]) -> None:
        """
        Add documents to the storage.
        
        Args:
            documents: The documents to add
        """
        # If embeddings are provided, use them to vectorize the documents
        if self.embeddings:
            # Convert the Document objects to a serializable format with embeddings
            doc_data_list = []
            for doc in documents:
                embedding = self.embeddings.embed_documents([doc.page_content])[0]
                doc_data_list.append({
                    "content": doc.page_content,
                    "metadata": doc.metadata,
                    "embedding": embedding
                })
            
            # Store the documents with embeddings
            await self.bridge.execute("Storage.add_vector_documents", [
                self.storage_type,
                self.collection_name,
                doc_data_list
            ])
        else:
            # Fall back to regular document storage if no embeddings are provided
            await super().add_documents(documents)
