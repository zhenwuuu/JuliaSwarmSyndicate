"""
Base classes for LLM providers.

This module provides the base classes for LLM providers.
"""

from abc import ABC, abstractmethod
from enum import Enum, auto
from typing import List, Dict, Any, Optional, Union
from pydantic import BaseModel


class LLMRole(str, Enum):
    """
    Enum for message roles in LLM conversations.
    """
    SYSTEM = "system"
    USER = "user"
    ASSISTANT = "assistant"
    FUNCTION = "function"


class LLMMessage(BaseModel):
    """
    Model for a message in an LLM conversation.
    """
    role: LLMRole
    content: str
    name: Optional[str] = None
    function_call: Optional[Dict[str, Any]] = None


class LLMResponse(BaseModel):
    """
    Model for an LLM response.
    """
    content: str
    model: str
    provider: str
    usage: Dict[str, int]
    finish_reason: Optional[str] = None
    function_call: Optional[Dict[str, Any]] = None
    raw_response: Optional[Dict[str, Any]] = None


class LLMProvider(ABC):
    """
    Abstract base class for LLM providers.
    """
    
    def __init__(self, api_key: Optional[str] = None, **kwargs):
        """
        Initialize the LLM provider.
        
        Args:
            api_key: API key for the provider
            **kwargs: Additional provider-specific arguments
        """
        self.api_key = api_key
        self.kwargs = kwargs
    
    @abstractmethod
    async def generate(
        self,
        messages: List[LLMMessage],
        model: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: Optional[int] = None,
        functions: Optional[List[Dict[str, Any]]] = None,
        **kwargs
    ) -> LLMResponse:
        """
        Generate a response from the LLM.
        
        Args:
            messages: List of messages in the conversation
            model: Model to use for generation
            temperature: Temperature for generation
            max_tokens: Maximum number of tokens to generate
            functions: List of function definitions for function calling
            **kwargs: Additional provider-specific arguments
        
        Returns:
            LLMResponse: The generated response
        """
        pass
    
    @abstractmethod
    async def embed(
        self,
        texts: List[str],
        model: Optional[str] = None,
        **kwargs
    ) -> List[List[float]]:
        """
        Generate embeddings for the given texts.
        
        Args:
            texts: List of texts to embed
            model: Model to use for embedding
            **kwargs: Additional provider-specific arguments
        
        Returns:
            List[List[float]]: List of embeddings
        """
        pass
    
    @abstractmethod
    def get_default_model(self) -> str:
        """
        Get the default model for this provider.
        
        Returns:
            str: The default model name
        """
        pass
    
    @abstractmethod
    def get_available_models(self) -> List[str]:
        """
        Get the available models for this provider.
        
        Returns:
            List[str]: List of available model names
        """
        pass
    
    @abstractmethod
    def get_provider_name(self) -> str:
        """
        Get the name of this provider.
        
        Returns:
            str: The provider name
        """
        pass
    
    def format_messages(self, messages: List[Union[LLMMessage, Dict[str, Any]]]) -> List[LLMMessage]:
        """
        Format messages to ensure they are LLMMessage objects.
        
        Args:
            messages: List of messages to format
        
        Returns:
            List[LLMMessage]: List of formatted messages
        """
        formatted_messages = []
        for message in messages:
            if isinstance(message, dict):
                formatted_messages.append(LLMMessage(**message))
            else:
                formatted_messages.append(message)
        return formatted_messages
