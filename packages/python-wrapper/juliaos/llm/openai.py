"""
OpenAI LLM provider.

This module provides the OpenAI LLM provider.
"""

import os
from typing import List, Dict, Any, Optional, Union
import aiohttp
import json

from .base import LLMProvider, LLMResponse, LLMMessage, LLMRole


class OpenAIProvider(LLMProvider):
    """
    OpenAI LLM provider.
    """
    
    def __init__(
        self,
        api_key: Optional[str] = None,
        organization: Optional[str] = None,
        base_url: Optional[str] = None,
        **kwargs
    ):
        """
        Initialize the OpenAI provider.
        
        Args:
            api_key: OpenAI API key
            organization: OpenAI organization ID
            base_url: Base URL for the OpenAI API
            **kwargs: Additional provider-specific arguments
        """
        super().__init__(api_key, **kwargs)
        self.api_key = api_key or os.environ.get("OPENAI_API_KEY")
        if not self.api_key:
            raise ValueError("OpenAI API key is required")
        
        self.organization = organization or os.environ.get("OPENAI_ORGANIZATION")
        self.base_url = base_url or os.environ.get("OPENAI_BASE_URL", "https://api.openai.com/v1")
    
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
        Generate a response from the OpenAI API.
        
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
        
        # Convert messages to OpenAI format
        openai_messages = []
        for message in formatted_messages:
            openai_message = {
                "role": message.role,
                "content": message.content
            }
            if message.name:
                openai_message["name"] = message.name
            openai_messages.append(openai_message)
        
        # Prepare request payload
        payload = {
            "model": model or self.get_default_model(),
            "messages": openai_messages,
            "temperature": temperature,
        }
        
        if max_tokens:
            payload["max_tokens"] = max_tokens
        
        if functions:
            payload["functions"] = functions
        
        # Add additional kwargs
        for key, value in kwargs.items():
            payload[key] = value
        
        # Make API request
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        
        if self.organization:
            headers["OpenAI-Organization"] = self.organization
        
        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{self.base_url}/chat/completions",
                headers=headers,
                json=payload
            ) as response:
                if response.status != 200:
                    error_text = await response.text()
                    raise Exception(f"OpenAI API error: {response.status} - {error_text}")
                
                response_data = await response.json()
        
        # Extract response
        choice = response_data["choices"][0]
        message = choice["message"]
        
        # Check for function call
        function_call = None
        if "function_call" in message:
            function_call = message["function_call"]
        
        # Create response
        return LLMResponse(
            content=message.get("content", ""),
            model=response_data["model"],
            provider="openai",
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
        Generate embeddings for the given texts using the OpenAI API.
        
        Args:
            texts: List of texts to embed
            model: Model to use for embedding
            **kwargs: Additional provider-specific arguments
        
        Returns:
            List[List[float]]: List of embeddings
        """
        # Prepare request payload
        payload = {
            "model": model or "text-embedding-ada-002",
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
        
        if self.organization:
            headers["OpenAI-Organization"] = self.organization
        
        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{self.base_url}/embeddings",
                headers=headers,
                json=payload
            ) as response:
                if response.status != 200:
                    error_text = await response.text()
                    raise Exception(f"OpenAI API error: {response.status} - {error_text}")
                
                response_data = await response.json()
        
        # Extract embeddings
        embeddings = [item["embedding"] for item in response_data["data"]]
        
        return embeddings
    
    def get_default_model(self) -> str:
        """
        Get the default model for OpenAI.
        
        Returns:
            str: The default model name
        """
        return "gpt-4"
    
    def get_available_models(self) -> List[str]:
        """
        Get the available models for OpenAI.
        
        Returns:
            List[str]: List of available model names
        """
        return [
            "gpt-4",
            "gpt-4-turbo",
            "gpt-4-turbo-preview",
            "gpt-4-vision-preview",
            "gpt-4-32k",
            "gpt-3.5-turbo",
            "gpt-3.5-turbo-16k",
            "text-embedding-ada-002"
        ]
    
    def get_provider_name(self) -> str:
        """
        Get the name of this provider.
        
        Returns:
            str: The provider name
        """
        return "openai"
