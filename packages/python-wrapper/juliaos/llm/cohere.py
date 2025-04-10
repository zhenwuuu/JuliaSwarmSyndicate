"""
Cohere LLM provider.

This module provides the Cohere LLM provider.
"""

import os
from typing import List, Dict, Any, Optional, Union
import aiohttp
import json

from .base import LLMProvider, LLMResponse, LLMMessage, LLMRole


class CohereProvider(LLMProvider):
    """
    Cohere LLM provider.
    """
    
    def __init__(
        self,
        api_key: Optional[str] = None,
        base_url: Optional[str] = None,
        **kwargs
    ):
        """
        Initialize the Cohere provider.
        
        Args:
            api_key: Cohere API key
            base_url: Base URL for the Cohere API
            **kwargs: Additional provider-specific arguments
        """
        super().__init__(api_key, **kwargs)
        self.api_key = api_key or os.environ.get("COHERE_API_KEY")
        if not self.api_key:
            raise ValueError("Cohere API key is required")
        
        self.base_url = base_url or os.environ.get("COHERE_BASE_URL", "https://api.cohere.ai/v1")
    
    async def generate(
        self,
        messages: List[Union[LLMMessage, Dict[str, Any]]],
        model: Optional[str] = None,
        temperature: float = 0.7,
        max_tokens: Optional[int] = None,
        functions: Optional[List[Dict[str, Any]]] = None,
        **kwargs
    ) -> LLMResponse:
        """
        Generate a response from the Cohere API.
        
        Args:
            messages: List of messages in the conversation
            model: Model to use for generation
            temperature: Temperature for generation
            max_tokens: Maximum number of tokens to generate
            functions: List of function definitions for function calling (not supported by Cohere)
            **kwargs: Additional provider-specific arguments
        
        Returns:
            LLMResponse: The generated response
        """
        # Format messages
        formatted_messages = self.format_messages(messages)
        
        # Convert messages to Cohere format
        cohere_messages = []
        for message in formatted_messages:
            role = message.role
            if role == LLMRole.SYSTEM:
                cohere_role = "SYSTEM"
            elif role == LLMRole.USER:
                cohere_role = "USER"
            elif role == LLMRole.ASSISTANT:
                cohere_role = "CHATBOT"
            else:
                # Skip function messages as they're not supported
                continue
            
            cohere_message = {
                "role": cohere_role,
                "message": message.content
            }
            cohere_messages.append(cohere_message)
        
        # Prepare request payload
        payload = {
            "model": model or self.get_default_model(),
            "chat_history": cohere_messages[:-1] if len(cohere_messages) > 1 else [],
            "message": cohere_messages[-1]["message"] if cohere_messages else "",
            "temperature": temperature,
        }
        
        if max_tokens:
            payload["max_tokens"] = max_tokens
        
        # Add additional kwargs
        for key, value in kwargs.items():
            payload[key] = value
        
        # Make API request
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        
        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{self.base_url}/chat",
                headers=headers,
                json=payload
            ) as response:
                if response.status != 200:
                    error_text = await response.text()
                    raise Exception(f"Cohere API error: {response.status} - {error_text}")
                
                response_data = await response.json()
        
        # Extract response
        content = response_data["text"]
        
        # Create usage data (Cohere doesn't provide detailed token usage)
        usage = {
            "prompt_tokens": response_data.get("meta", {}).get("prompt_tokens", -1),
            "completion_tokens": response_data.get("meta", {}).get("response_tokens", -1),
            "total_tokens": response_data.get("meta", {}).get("total_tokens", -1)
        }
        
        # Create response
        return LLMResponse(
            content=content,
            model=model or self.get_default_model(),
            provider="cohere",
            usage=usage,
            finish_reason=response_data.get("finish_reason"),
            function_call=None,  # Cohere doesn't support function calling in this format
            raw_response=response_data
        )
    
    async def embed(
        self,
        texts: List[str],
        model: Optional[str] = None,
        **kwargs
    ) -> List[List[float]]:
        """
        Generate embeddings for the given texts using the Cohere API.
        
        Args:
            texts: List of texts to embed
            model: Model to use for embedding
            **kwargs: Additional provider-specific arguments
        
        Returns:
            List[List[float]]: List of embeddings
        """
        # Prepare request payload
        payload = {
            "model": model or "embed-english-v3.0",
            "texts": texts,
            "input_type": kwargs.get("input_type", "search_document")
        }
        
        # Add additional kwargs
        for key, value in kwargs.items():
            if key != "input_type":  # Already handled
                payload[key] = value
        
        # Make API request
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        
        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{self.base_url}/embed",
                headers=headers,
                json=payload
            ) as response:
                if response.status != 200:
                    error_text = await response.text()
                    raise Exception(f"Cohere API error: {response.status} - {error_text}")
                
                response_data = await response.json()
        
        # Extract embeddings
        embeddings = response_data["embeddings"]
        
        return embeddings
    
    def get_default_model(self) -> str:
        """
        Get the default model for Cohere.
        
        Returns:
            str: The default model name
        """
        return "command"
    
    def get_available_models(self) -> List[str]:
        """
        Get the available models for Cohere.
        
        Returns:
            List[str]: List of available model names
        """
        return [
            "command",
            "command-light",
            "command-nightly",
            "command-light-nightly",
            "embed-english-v3.0",
            "embed-multilingual-v3.0"
        ]
    
    def get_provider_name(self) -> str:
        """
        Get the name of this provider.
        
        Returns:
            str: The provider name
        """
        return "cohere"
