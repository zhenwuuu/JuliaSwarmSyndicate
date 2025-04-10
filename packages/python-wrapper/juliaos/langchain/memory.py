"""
LangChain memory integration with JuliaOS storage.

This module provides memory classes that use JuliaOS storage.
"""

from typing import Dict, Any, List, Optional, Union, Callable, Type
import asyncio
import json
from pydantic import BaseModel, Field

from langchain.memory import ConversationBufferMemory, VectorStoreRetrieverMemory
from langchain.schema import BaseMemory
from langchain.schema.messages import get_buffer_string, BaseMessage, HumanMessage, AIMessage

from ..bridge import JuliaBridge


class JuliaOSMemory(BaseMemory):
    """
    Base memory class using JuliaOS storage.
    
    This class provides the basic functionality for storing and retrieving
    memory using JuliaOS storage.
    """
    
    bridge: JuliaBridge = Field(exclude=True)
    memory_key: str = "memory"
    storage_type: str = "local"
    storage_key: str = "langchain_memory"
    
    def __init__(
        self,
        bridge: JuliaBridge,
        memory_key: str = "memory",
        storage_type: str = "local",
        storage_key: str = "langchain_memory",
        **kwargs
    ):
        """
        Initialize the memory with a JuliaBridge.
        
        Args:
            bridge: The JuliaBridge to use for communication with the Julia backend
            memory_key: The key to use for the memory in the context
            storage_type: The type of storage to use (local, arweave, etc.)
            storage_key: The key to use for storing the memory in JuliaOS storage
            **kwargs: Additional arguments to pass to the BaseMemory constructor
        """
        super().__init__(
            bridge=bridge,
            memory_key=memory_key,
            storage_type=storage_type,
            storage_key=storage_key,
            **kwargs
        )
    
    async def _store_memory(self, memory_data: Dict[str, Any]) -> None:
        """
        Store memory data in JuliaOS storage.
        
        Args:
            memory_data: The memory data to store
        """
        await self.bridge.execute("Storage.store", [
            self.storage_type,
            self.storage_key,
            memory_data
        ])
    
    async def _load_memory(self) -> Dict[str, Any]:
        """
        Load memory data from JuliaOS storage.
        
        Returns:
            Dict[str, Any]: The loaded memory data
        """
        result = await self.bridge.execute("Storage.get", [
            self.storage_type,
            self.storage_key,
            {}  # Default value
        ])
        
        return result.get("data", {})
    
    def load_memory_variables(self, inputs: Dict[str, Any]) -> Dict[str, Any]:
        """
        Load memory variables from JuliaOS storage.
        
        Args:
            inputs: The inputs to the chain
        
        Returns:
            Dict[str, Any]: The memory variables
        """
        # This is a synchronous method, so we need to run the async method in a new event loop
        memory_data = asyncio.run(self._load_memory())
        
        return {self.memory_key: memory_data}
    
    def save_context(self, inputs: Dict[str, Any], outputs: Dict[str, Any]) -> None:
        """
        Save the context to JuliaOS storage.
        
        Args:
            inputs: The inputs to the chain
            outputs: The outputs from the chain
        """
        # This is a synchronous method, so we need to run the async method in a new event loop
        memory_data = {
            "inputs": inputs,
            "outputs": outputs
        }
        
        asyncio.run(self._store_memory(memory_data))
    
    def clear(self) -> None:
        """
        Clear the memory.
        """
        # This is a synchronous method, so we need to run the async method in a new event loop
        asyncio.run(self._store_memory({}))


class JuliaOSConversationBufferMemory(ConversationBufferMemory):
    """
    Conversation buffer memory using JuliaOS storage.
    
    This class provides a conversation buffer memory that uses JuliaOS storage.
    """
    
    bridge: JuliaBridge = Field(exclude=True)
    storage_type: str = "local"
    storage_key: str = "langchain_conversation_memory"
    
    def __init__(
        self,
        bridge: JuliaBridge,
        storage_type: str = "local",
        storage_key: str = "langchain_conversation_memory",
        **kwargs
    ):
        """
        Initialize the memory with a JuliaBridge.
        
        Args:
            bridge: The JuliaBridge to use for communication with the Julia backend
            storage_type: The type of storage to use (local, arweave, etc.)
            storage_key: The key to use for storing the memory in JuliaOS storage
            **kwargs: Additional arguments to pass to the ConversationBufferMemory constructor
        """
        super().__init__(
            **kwargs
        )
        self.bridge = bridge
        self.storage_type = storage_type
        self.storage_key = storage_key
        
        # Load the chat history from storage
        self._load_chat_history()
    
    def _load_chat_history(self) -> None:
        """
        Load the chat history from JuliaOS storage.
        """
        # This is a synchronous method, so we need to run the async method in a new event loop
        chat_history = asyncio.run(self._load_chat_history_async())
        
        # Set the chat history
        self.chat_memory.messages = chat_history
    
    async def _load_chat_history_async(self) -> List[BaseMessage]:
        """
        Load the chat history from JuliaOS storage asynchronously.
        
        Returns:
            List[BaseMessage]: The loaded chat history
        """
        result = await self.bridge.execute("Storage.get", [
            self.storage_type,
            self.storage_key,
            {"messages": []}  # Default value
        ])
        
        # Convert the stored messages to BaseMessage objects
        messages = []
        for message_data in result.get("messages", []):
            if message_data.get("type") == "human":
                messages.append(HumanMessage(content=message_data.get("content", "")))
            elif message_data.get("type") == "ai":
                messages.append(AIMessage(content=message_data.get("content", "")))
        
        return messages
    
    def save_context(self, inputs: Dict[str, Any], outputs: Dict[str, Any]) -> None:
        """
        Save the context to JuliaOS storage.
        
        Args:
            inputs: The inputs to the chain
            outputs: The outputs from the chain
        """
        # Call the parent method to update the chat memory
        super().save_context(inputs, outputs)
        
        # Save the updated chat history to storage
        self._save_chat_history()
    
    def _save_chat_history(self) -> None:
        """
        Save the chat history to JuliaOS storage.
        """
        # This is a synchronous method, so we need to run the async method in a new event loop
        asyncio.run(self._save_chat_history_async())
    
    async def _save_chat_history_async(self) -> None:
        """
        Save the chat history to JuliaOS storage asynchronously.
        """
        # Convert the BaseMessage objects to a serializable format
        messages = []
        for message in self.chat_memory.messages:
            if isinstance(message, HumanMessage):
                messages.append({
                    "type": "human",
                    "content": message.content
                })
            elif isinstance(message, AIMessage):
                messages.append({
                    "type": "ai",
                    "content": message.content
                })
        
        # Store the messages
        await self.bridge.execute("Storage.store", [
            self.storage_type,
            self.storage_key,
            {"messages": messages}
        ])
    
    def clear(self) -> None:
        """
        Clear the memory.
        """
        # Call the parent method to clear the chat memory
        super().clear()
        
        # Clear the storage
        asyncio.run(self.bridge.execute("Storage.store", [
            self.storage_type,
            self.storage_key,
            {"messages": []}
        ]))


class JuliaOSVectorStoreMemory(VectorStoreRetrieverMemory):
    """
    Vector store memory using JuliaOS storage.
    
    This class provides a vector store memory that uses JuliaOS storage.
    """
    
    bridge: JuliaBridge = Field(exclude=True)
    
    def __init__(
        self,
        bridge: JuliaBridge,
        **kwargs
    ):
        """
        Initialize the memory with a JuliaBridge.
        
        Args:
            bridge: The JuliaBridge to use for communication with the Julia backend
            **kwargs: Additional arguments to pass to the VectorStoreRetrieverMemory constructor
        """
        # Create a retriever if not provided
        if "retriever" not in kwargs:
            from .retrievers import JuliaOSVectorStoreRetriever
            kwargs["retriever"] = JuliaOSVectorStoreRetriever(bridge=bridge)
        
        super().__init__(**kwargs)
        self.bridge = bridge
