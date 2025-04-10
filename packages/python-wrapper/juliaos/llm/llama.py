"""
Llama LLM provider.

This module provides the Llama LLM provider via Replicate API.
"""

import os
from typing import List, Dict, Any, Optional, Union
import aiohttp
import json
import time

from .base import LLMProvider, LLMResponse, LLMMessage, LLMRole


class LlamaProvider(LLMProvider):
    """
    Llama LLM provider via Replicate API.
    """
    
    def __init__(
        self,
        api_key: Optional[str] = None,
        base_url: Optional[str] = None,
        **kwargs
    ):
        """
        Initialize the Llama provider.
        
        Args:
            api_key: Replicate API key
            base_url: Base URL for the Replicate API
            **kwargs: Additional provider-specific arguments
        """
        super().__init__(api_key, **kwargs)
        self.api_key = api_key or os.environ.get("REPLICATE_API_KEY")
        if not self.api_key:
            raise ValueError("Replicate API key is required")
        
        self.base_url = base_url or os.environ.get("REPLICATE_BASE_URL", "https://api.replicate.com/v1")
        self.model_version = kwargs.get("model_version", "meta/llama-3-70b-instruct:2a30b9cf20a9e9819c5a3a12cd507d6e2f9d78a2a5f7d35b9e5b3ebf5c609d7b")
    
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
        Generate a response from the Llama model via Replicate API.
        
        Args:
            messages: List of messages in the conversation
            model: Model to use for generation (overrides the default model_version)
            temperature: Temperature for generation
            max_tokens: Maximum number of tokens to generate
            functions: List of function definitions for function calling (not supported by Llama via Replicate)
            **kwargs: Additional provider-specific arguments
        
        Returns:
            LLMResponse: The generated response
        """
        # Format messages
        formatted_messages = self.format_messages(messages)
        
        # Convert messages to Llama format (chat template)
        prompt = ""
        for message in formatted_messages:
            if message.role == LLMRole.SYSTEM:
                prompt += f"<|system|>\n{message.content}</s>\n"
            elif message.role == LLMRole.USER:
                prompt += f"<|user|>\n{message.content}</s>\n"
            elif message.role == LLMRole.ASSISTANT:
                prompt += f"<|assistant|>\n{message.content}</s>\n"
        
        # Add the final assistant prompt to get the response
        prompt += "<|assistant|>\n"
        
        # Prepare request payload
        payload = {
            "version": model or self.model_version,
            "input": {
                "prompt": prompt,
                "temperature": temperature,
            }
        }
        
        if max_tokens:
            payload["input"]["max_new_tokens"] = max_tokens
        
        # Add additional kwargs to input
        for key, value in kwargs.items():
            payload["input"][key] = value
        
        # Make API request to create prediction
        headers = {
            "Authorization": f"Token {self.api_key}",
            "Content-Type": "application/json"
        }
        
        async with aiohttp.ClientSession() as session:
            # Create prediction
            async with session.post(
                f"{self.base_url}/predictions",
                headers=headers,
                json=payload
            ) as response:
                if response.status != 201:
                    error_text = await response.text()
                    raise Exception(f"Replicate API error: {response.status} - {error_text}")
                
                prediction_data = await response.json()
                prediction_id = prediction_data["id"]
            
            # Poll for prediction result
            max_retries = 60  # 5 minutes with 5-second intervals
            for _ in range(max_retries):
                async with session.get(
                    f"{self.base_url}/predictions/{prediction_id}",
                    headers=headers
                ) as response:
                    if response.status != 200:
                        error_text = await response.text()
                        raise Exception(f"Replicate API error: {response.status} - {error_text}")
                    
                    prediction_data = await response.json()
                    status = prediction_data["status"]
                    
                    if status == "succeeded":
                        break
                    elif status == "failed":
                        raise Exception(f"Replicate prediction failed: {prediction_data.get('error')}")
                    
                    # Wait before polling again
                    await asyncio.sleep(5)
            else:
                raise Exception("Replicate prediction timed out")
        
        # Extract response
        output = prediction_data["output"]
        content = "".join(output) if isinstance(output, list) else output
        
        # Create usage data (Replicate doesn't provide detailed token usage)
        usage = {
            "prompt_tokens": -1,  # Not provided by Replicate
            "completion_tokens": -1,  # Not provided by Replicate
            "total_tokens": -1  # Not provided by Replicate
        }
        
        # Create response
        return LLMResponse(
            content=content,
            model=model or self.model_version,
            provider="llama",
            usage=usage,
            finish_reason="stop",  # Replicate doesn't provide finish reason
            function_call=None,  # Llama via Replicate doesn't support function calling
            raw_response=prediction_data
        )
    
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
        # Use a different model for embeddings
        embedding_model = model or "nateraw/bge-large-en-v1.5:9cf9f015a9cb9c61d1a2610659cdac4a4ca222f2d3707a68517b18c198a9add1"
        
        embeddings = []
        
        # Process texts in batches to avoid timeouts
        batch_size = 10
        for i in range(0, len(texts), batch_size):
            batch_texts = texts[i:i+batch_size]
            
            # Prepare request payload
            payload = {
                "version": embedding_model,
                "input": {
                    "texts": batch_texts
                }
            }
            
            # Add additional kwargs
            for key, value in kwargs.items():
                payload["input"][key] = value
            
            # Make API request
            headers = {
                "Authorization": f"Token {self.api_key}",
                "Content-Type": "application/json"
            }
            
            async with aiohttp.ClientSession() as session:
                # Create prediction
                async with session.post(
                    f"{self.base_url}/predictions",
                    headers=headers,
                    json=payload
                ) as response:
                    if response.status != 201:
                        error_text = await response.text()
                        raise Exception(f"Replicate API error: {response.status} - {error_text}")
                    
                    prediction_data = await response.json()
                    prediction_id = prediction_data["id"]
                
                # Poll for prediction result
                max_retries = 30  # 2.5 minutes with 5-second intervals
                for _ in range(max_retries):
                    async with session.get(
                        f"{self.base_url}/predictions/{prediction_id}",
                        headers=headers
                    ) as response:
                        if response.status != 200:
                            error_text = await response.text()
                            raise Exception(f"Replicate API error: {response.status} - {error_text}")
                        
                        prediction_data = await response.json()
                        status = prediction_data["status"]
                        
                        if status == "succeeded":
                            break
                        elif status == "failed":
                            raise Exception(f"Replicate prediction failed: {prediction_data.get('error')}")
                        
                        # Wait before polling again
                        await asyncio.sleep(5)
                else:
                    raise Exception("Replicate prediction timed out")
            
            # Extract embeddings
            batch_embeddings = prediction_data["output"]
            embeddings.extend(batch_embeddings)
        
        return embeddings
    
    def get_default_model(self) -> str:
        """
        Get the default model for Llama.
        
        Returns:
            str: The default model name
        """
        return self.model_version
    
    def get_available_models(self) -> List[str]:
        """
        Get the available models for Llama via Replicate.
        
        Returns:
            List[str]: List of available model names
        """
        return [
            "meta/llama-3-70b-instruct:2a30b9cf20a9e9819c5a3a12cd507d6e2f9d78a2a5f7d35b9e5b3ebf5c609d7b",
            "meta/llama-3-8b-instruct:dd2c4223f0ceee5d14e0a9a9f9d3f7f4e7470c3c9e3b5b1a79c780f4c6aef0be",
            "meta/llama-2-70b-chat:02e509c789964a7ea8736978a43525956ef40397be9033abf9fd2badfe68c9e3",
            "meta/llama-2-13b-chat:f4e2de70d66816a838a89eeeb621910adffb0dd0baba3976c96980970978018d",
            "meta/llama-2-7b-chat:13c3cdee13ee059ab779f0291d29054dab00a47dad8261375654de5540165fb0",
            "nateraw/bge-large-en-v1.5:9cf9f015a9cb9c61d1a2610659cdac4a4ca222f2d3707a68517b18c198a9add1"  # For embeddings
        ]
    
    def get_provider_name(self) -> str:
        """
        Get the name of this provider.
        
        Returns:
            str: The provider name
        """
        return "llama"
