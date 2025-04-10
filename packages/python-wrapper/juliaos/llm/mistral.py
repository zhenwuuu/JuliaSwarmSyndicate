"""
Mistral AI LLM provider.

This module provides the Mistral AI LLM provider.
"""

import os
from typing import List, Dict, Any, Optional, Union
import aiohttp
import json

from .base import LLMProvider, LLMResponse, LLMMessage, LLMRole


class MistralProvider(LLMProvider):
    """
    Mistral AI LLM provider.
    """
    
    def __init__(
        self,
        api_key: Optional[str] = None,
        base_url: Optional[str] = None,
        **kwargs
    ):
        """
        Initialize the Mistral AI provider.
        
        Args:
            api_key: Mistral AI API key
            base_url: Base URL for the Mistral AI API
            **kwargs: Additional provider-specific arguments
        """
        super().__init__(api_key, **kwargs)
        self.api_key = api_key or os.environ.get("MISTRAL_API_KEY")
        if not self.api_key:
            raise ValueError("Mistral AI API key is required")
        
        self.base_url = base_url or os.environ.get("MISTRAL_BASE_URL", "https://api.mistral.ai/v1")
    
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
        Generate a response from the Mistral AI API.
        
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
        # Format messages
        formatted_messages = self.format_messages(messages)
        
        # Convert messages to Mistral AI format
        mistral_messages = []
        for message in formatted_messages:
            mistral_message = {
                "role": message.role,
                "content": message.content
            }
            mistral_messages.append(mistral_message)
        
        # Prepare request payload
        payload = {
            "model": model or self.get_default_model(),
            "messages": mistral_messages,
            "temperature": temperature,
        }
        
        if max_tokens:
            payload["max_tokens"] = max_tokens
        
        # Add tool calling if functions are provided
        if functions:
            payload["tools"] = [{"type": "function", "function": func} for func in functions]
        
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
                f"{self.base_url}/chat/completions",
                headers=headers,
                json=payload
            ) as response:
                if response.status != 200:
                    error_text = await response.text()
                    raise Exception(f"Mistral AI API error: {response.status} - {error_text}")
                
                response_data = await response.json()
        
        # Extract response
        choice = response_data["choices"][0]
        message = choice["message"]
        
        # Check for function call (tool calls in Mistral API)
        function_call = None
        if "tool_calls" in message:
            # Convert tool_calls to function_call format for consistency
            tool_call = message["tool_calls"][0]
            function_call = {
                "name": tool_call["function"]["name"],
                "arguments": tool_call["function"]["arguments"]
            }
        
        # Create response
        return LLMResponse(
            content=message.get("content", ""),
            model=response_data["model"],
            provider="mistral",
            usage=response_data["usage"],
            finish_reason=choice.get("finish_reason"),
            function_call=function_call,
            raw_response=response_data
        )
    
    async def embed(
        self,
        texts: List[str],
        model: Optional[str] = None,
        **kwargs
    ) -> List[List[float]]:
        """
        Generate embeddings for the given texts using the Mistral AI API.
        
        Args:
            texts: List of texts to embed
            model: Model to use for embedding
            **kwargs: Additional provider-specific arguments
        
        Returns:
            List[List[float]]: List of embeddings
        """
        # Prepare request payload
        payload = {
            "model": model or "mistral-embed",
            "input": texts
        }
        
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
                f"{self.base_url}/embeddings",
                headers=headers,
                json=payload
            ) as response:
                if response.status != 200:
                    error_text = await response.text()
                    raise Exception(f"Mistral AI API error: {response.status} - {error_text}")
                
                response_data = await response.json()
        
        # Extract embeddings
        embeddings = [item["embedding"] for item in response_data["data"]]
        
        return embeddings
    
    def get_default_model(self) -> str:
        """
        Get the default model for Mistral AI.
        
        Returns:
            str: The default model name
        """
        return "mistral-large-latest"
    
    def get_available_models(self) -> List[str]:
        """
        Get the available models for Mistral AI.
        
        Returns:
            List[str]: List of available model names
        """
        return [
            "mistral-large-latest",
            "mistral-medium-latest",
            "mistral-small-latest",
            "open-mistral-7b",
            "open-mixtral-8x7b",
            "mistral-embed"
        ]
    
    def get_provider_name(self) -> str:
        """
        Get the name of this provider.
        
        Returns:
            str: The provider name
        """
        return "mistral"
