"""
Anthropic LLM provider.

This module provides the Anthropic LLM provider for Claude models.
"""

import os
from typing import List, Dict, Any, Optional, Union
import aiohttp
import json

from .base import LLMProvider, LLMResponse, LLMMessage, LLMRole


class AnthropicProvider(LLMProvider):
    """
    Anthropic LLM provider for Claude models.
    """
    
    def __init__(
        self,
        api_key: Optional[str] = None,
        base_url: Optional[str] = None,
        **kwargs
    ):
        """
        Initialize the Anthropic provider.
        
        Args:
            api_key: Anthropic API key
            base_url: Base URL for the Anthropic API
            **kwargs: Additional provider-specific arguments
        """
        super().__init__(api_key, **kwargs)
        self.api_key = api_key or os.environ.get("ANTHROPIC_API_KEY")
        if not self.api_key:
            raise ValueError("Anthropic API key is required")
        
        self.base_url = base_url or os.environ.get("ANTHROPIC_BASE_URL", "https://api.anthropic.com/v1")
        self.api_version = kwargs.get("api_version", "2023-06-01")
    
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
        Generate a response from the Anthropic API.
        
        Args:
            messages: List of messages in the conversation
            model: Model to use for generation
            temperature: Temperature for generation
            max_tokens: Maximum number of tokens to generate
            functions: List of function definitions for function calling (not supported by Anthropic)
            **kwargs: Additional provider-specific arguments
        
        Returns:
            LLMResponse: The generated response
        """
        # Format messages
        formatted_messages = self.format_messages(messages)
        
        # Convert messages to Anthropic format
        anthropic_messages = []
        for message in formatted_messages:
            # Map roles from LLMRole to Anthropic roles
            role = message.role
            if role == LLMRole.SYSTEM:
                # System messages are handled separately in Anthropic
                continue
            elif role == LLMRole.ASSISTANT:
                anthropic_role = "assistant"
            elif role == LLMRole.USER:
                anthropic_role = "user"
            else:
                # Skip function messages as they're not supported
                continue
            
            anthropic_message = {
                "role": anthropic_role,
                "content": message.content
            }
            anthropic_messages.append(anthropic_message)
        
        # Extract system message if present
        system_message = next((m.content for m in formatted_messages if m.role == LLMRole.SYSTEM), None)
        
        # Prepare request payload
        payload = {
            "model": model or self.get_default_model(),
            "messages": anthropic_messages,
            "temperature": temperature,
            "max_tokens": max_tokens or 1024,
        }
        
        if system_message:
            payload["system"] = system_message
        
        # Add additional kwargs
        for key, value in kwargs.items():
            payload[key] = value
        
        # Make API request
        headers = {
            "x-api-key": self.api_key,
            "anthropic-version": self.api_version,
            "Content-Type": "application/json"
        }
        
        async with aiohttp.ClientSession() as session:
            async with session.post(
                f"{self.base_url}/messages",
                headers=headers,
                json=payload
            ) as response:
                if response.status != 200:
                    error_text = await response.text()
                    raise Exception(f"Anthropic API error: {response.status} - {error_text}")
                
                response_data = await response.json()
        
        # Extract response
        content = response_data["content"][0]["text"]
        
        # Create usage data (Anthropic doesn't provide detailed token usage)
        usage = {
            "prompt_tokens": -1,  # Not provided by Anthropic
            "completion_tokens": -1,  # Not provided by Anthropic
            "total_tokens": -1  # Not provided by Anthropic
        }
        
        # Create response
        return LLMResponse(
            content=content,
            model=response_data["model"],
            provider="anthropic",
            usage=usage,
            finish_reason=response_data.get("stop_reason"),
            function_call=None,  # Anthropic doesn't support function calling in this API version
            raw_response=response_data
        )
    
    async def embed(
        self,
        texts: List[str],
        model: Optional[str] = None,
        **kwargs
    ) -> List[List[float]]:
        """
        Generate embeddings for the given texts using the Anthropic API.
        
        Args:
            texts: List of texts to embed
            model: Model to use for embedding
            **kwargs: Additional provider-specific arguments
        
        Returns:
            List[List[float]]: List of embeddings
        """
        # Anthropic doesn't have a dedicated embeddings API yet
        # Return empty embeddings for now
        raise NotImplementedError("Anthropic does not currently provide a public embeddings API")
    
    def get_default_model(self) -> str:
        """
        Get the default model for Anthropic.
        
        Returns:
            str: The default model name
        """
        return "claude-3-opus-20240229"
    
    def get_available_models(self) -> List[str]:
        """
        Get the available models for Anthropic.
        
        Returns:
            List[str]: List of available model names
        """
        return [
            "claude-3-opus-20240229",
            "claude-3-sonnet-20240229",
            "claude-3-haiku-20240307",
            "claude-2.1",
            "claude-2.0",
            "claude-instant-1.2"
        ]
    
    def get_provider_name(self) -> str:
        """
        Get the name of this provider.
        
        Returns:
            str: The provider name
        """
        return "anthropic"
