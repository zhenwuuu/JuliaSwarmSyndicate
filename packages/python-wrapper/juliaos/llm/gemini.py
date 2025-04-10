"""
Gemini LLM provider.

This module provides the Gemini LLM provider from Google.
"""

import os
from typing import List, Dict, Any, Optional, Union
import aiohttp
import json
import asyncio

from .base import LLMProvider, LLMResponse, LLMMessage, LLMRole


class GeminiProvider(LLMProvider):
    """
    Gemini LLM provider from Google.
    """
    
    def __init__(
        self,
        api_key: Optional[str] = None,
        base_url: Optional[str] = None,
        **kwargs
    ):
        """
        Initialize the Gemini provider.
        
        Args:
            api_key: Google API key
            base_url: Base URL for the Gemini API
            **kwargs: Additional provider-specific arguments
        """
        super().__init__(api_key, **kwargs)
        self.api_key = api_key or os.environ.get("GOOGLE_API_KEY")
        if not self.api_key:
            raise ValueError("Google API key is required")
        
        self.base_url = base_url or os.environ.get("GEMINI_BASE_URL", "https://generativelanguage.googleapis.com/v1")
    
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
        Generate a response from the Gemini API.
        
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
        
        # Convert messages to Gemini format
        gemini_messages = []
        for message in formatted_messages:
            role = message.role
            if role == LLMRole.SYSTEM:
                # Gemini doesn't have a system role, so we'll add it as a user message
                gemini_messages.append({
                    "role": "user",
                    "parts": [{"text": f"System instruction: {message.content}"}]
                })
            elif role == LLMRole.USER:
                gemini_messages.append({
                    "role": "user",
                    "parts": [{"text": message.content}]
                })
            elif role == LLMRole.ASSISTANT:
                gemini_messages.append({
                    "role": "model",
                    "parts": [{"text": message.content}]
                })
        
        # Prepare request payload
        payload = {
            "contents": gemini_messages,
            "generationConfig": {
                "temperature": temperature,
            }
        }
        
        if max_tokens:
            payload["generationConfig"]["maxOutputTokens"] = max_tokens
        
        # Add function calling if supported and provided
        if functions and model and "1.5" in model:  # Only Gemini 1.5 supports function calling
            tools = []
            for func in functions:
                tools.append({
                    "functionDeclarations": [
                        {
                            "name": func["name"],
                            "description": func.get("description", ""),
                            "parameters": func["parameters"]
                        }
                    ]
                })
            payload["tools"] = tools
        
        # Add additional kwargs
        for key, value in kwargs.items():
            if key not in ["contents", "generationConfig", "tools"]:
                payload[key] = value
        
        # Determine the model endpoint
        model_name = model or self.get_default_model()
        model_endpoint = model_name.replace(":", "-")  # Replace any colons with hyphens
        
        # Make API request
        url = f"{self.base_url}/models/{model_endpoint}:generateContent?key={self.api_key}"
        
        async with aiohttp.ClientSession() as session:
            async with session.post(
                url,
                json=payload
            ) as response:
                if response.status != 200:
                    error_text = await response.text()
                    raise Exception(f"Gemini API error: {response.status} - {error_text}")
                
                response_data = await response.json()
        
        # Extract response
        candidates = response_data.get("candidates", [])
        if not candidates:
            raise Exception("No response from Gemini API")
        
        content_parts = candidates[0].get("content", {}).get("parts", [])
        content = "".join(part.get("text", "") for part in content_parts)
        
        # Check for function call
        function_call = None
        if "functionCall" in candidates[0].get("content", {}):
            func_call = candidates[0]["content"]["functionCall"]
            function_call = {
                "name": func_call["name"],
                "arguments": json.dumps(func_call["args"])
            }
        
        # Create usage data (Gemini doesn't provide detailed token usage)
        usage = {
            "prompt_tokens": response_data.get("usageMetadata", {}).get("promptTokenCount", -1),
            "completion_tokens": response_data.get("usageMetadata", {}).get("candidatesTokenCount", -1),
            "total_tokens": response_data.get("usageMetadata", {}).get("totalTokenCount", -1)
        }
        
        # Create response
        return LLMResponse(
            content=content,
            model=model_name,
            provider="gemini",
            usage=usage,
            finish_reason=candidates[0].get("finishReason", "STOP"),
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
        Generate embeddings for the given texts using the Gemini API.
        
        Args:
            texts: List of texts to embed
            model: Model to use for embedding
            **kwargs: Additional provider-specific arguments
        
        Returns:
            List[List[float]]: List of embeddings
        """
        # Determine the embedding model
        embedding_model = model or "models/embedding-001"
        
        embeddings = []
        
        # Process texts in batches to avoid timeouts
        batch_size = 10
        for i in range(0, len(texts), batch_size):
            batch_texts = texts[i:i+batch_size]
            
            # Process each text individually as the API expects
            batch_embeddings = []
            for text in batch_texts:
                # Prepare request payload
                payload = {
                    "model": embedding_model,
                    "content": {
                        "parts": [
                            {"text": text}
                        ]
                    }
                }
                
                # Add additional kwargs
                for key, value in kwargs.items():
                    if key not in ["model", "content"]:
                        payload[key] = value
                
                # Make API request
                url = f"{self.base_url}/models/{embedding_model}:embedContent?key={self.api_key}"
                
                async with aiohttp.ClientSession() as session:
                    async with session.post(
                        url,
                        json=payload
                    ) as response:
                        if response.status != 200:
                            error_text = await response.text()
                            raise Exception(f"Gemini API error: {response.status} - {error_text}")
                        
                        response_data = await response.json()
                
                # Extract embedding
                embedding = response_data.get("embedding", {}).get("values", [])
                batch_embeddings.append(embedding)
            
            embeddings.extend(batch_embeddings)
        
        return embeddings
    
    def get_default_model(self) -> str:
        """
        Get the default model for Gemini.
        
        Returns:
            str: The default model name
        """
        return "gemini-1.5-pro"
    
    def get_available_models(self) -> List[str]:
        """
        Get the available models for Gemini.
        
        Returns:
            List[str]: List of available model names
        """
        return [
            "gemini-1.5-pro",
            "gemini-1.5-flash",
            "gemini-1.0-pro",
            "gemini-1.0-pro-vision",
            "models/embedding-001"  # For embeddings
        ]
    
    def get_provider_name(self) -> str:
        """
        Get the name of this provider.
        
        Returns:
            str: The provider name
        """
        return "gemini"
