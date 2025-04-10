"""
Example of using different LLM providers with JuliaOS.

This example demonstrates how to use different LLM providers with JuliaOS.
"""

import asyncio
import os
from dotenv import load_dotenv

from juliaos import JuliaOS
from juliaos.llm import (
    LLMMessage, LLMRole,
    OpenAIProvider, AnthropicProvider, LlamaProvider,
    MistralProvider, CohereProvider, GeminiProvider
)


async def main():
    # Load environment variables
    load_dotenv()
    
    # Initialize JuliaOS
    juliaos = JuliaOS()
    await juliaos.connect()
    
    print("=== JuliaOS LLM Providers Example ===\n")
    
    try:
        # Example messages
        messages = [
            LLMMessage(role=LLMRole.SYSTEM, content="You are a helpful AI assistant specialized in blockchain technology."),
            LLMMessage(role=LLMRole.USER, content="What is the difference between proof of work and proof of stake?")
        ]
        
        # Example 1: OpenAI
        if os.environ.get("OPENAI_API_KEY"):
            print("Example 1: OpenAI")
            openai_provider = OpenAIProvider()
            
            print("\nGenerating response from OpenAI...")
            openai_response = await openai_provider.generate(
                messages=messages,
                model="gpt-3.5-turbo",
                temperature=0.7
            )
            print(f"\nOpenAI Response: {openai_response.content}\n")
            print(f"Model: {openai_response.model}")
            print(f"Usage: {openai_response.usage}")
            print("-" * 80)
        else:
            print("Skipping OpenAI example (OPENAI_API_KEY not set)")
        
        # Example 2: Anthropic
        if os.environ.get("ANTHROPIC_API_KEY"):
            print("\nExample 2: Anthropic")
            anthropic_provider = AnthropicProvider()
            
            print("\nGenerating response from Anthropic...")
            anthropic_response = await anthropic_provider.generate(
                messages=messages,
                model="claude-3-sonnet-20240229",
                temperature=0.7
            )
            print(f"\nAnthropic Response: {anthropic_response.content}\n")
            print(f"Model: {anthropic_response.model}")
            print(f"Usage: {anthropic_response.usage}")
            print("-" * 80)
        else:
            print("Skipping Anthropic example (ANTHROPIC_API_KEY not set)")
        
        # Example 3: Mistral
        if os.environ.get("MISTRAL_API_KEY"):
            print("\nExample 3: Mistral")
            mistral_provider = MistralProvider()
            
            print("\nGenerating response from Mistral...")
            mistral_response = await mistral_provider.generate(
                messages=messages,
                model="mistral-medium-latest",
                temperature=0.7
            )
            print(f"\nMistral Response: {mistral_response.content}\n")
            print(f"Model: {mistral_response.model}")
            print(f"Usage: {mistral_response.usage}")
            print("-" * 80)
        else:
            print("Skipping Mistral example (MISTRAL_API_KEY not set)")
        
        # Example 4: Cohere
        if os.environ.get("COHERE_API_KEY"):
            print("\nExample 4: Cohere")
            cohere_provider = CohereProvider()
            
            print("\nGenerating response from Cohere...")
            cohere_response = await cohere_provider.generate(
                messages=messages,
                model="command",
                temperature=0.7
            )
            print(f"\nCohere Response: {cohere_response.content}\n")
            print(f"Model: {cohere_response.model}")
            print(f"Usage: {cohere_response.usage}")
            print("-" * 80)
        else:
            print("Skipping Cohere example (COHERE_API_KEY not set)")
        
        # Example 5: Llama (via Replicate)
        if os.environ.get("REPLICATE_API_KEY"):
            print("\nExample 5: Llama (via Replicate)")
            llama_provider = LlamaProvider()
            
            print("\nGenerating response from Llama...")
            llama_response = await llama_provider.generate(
                messages=messages,
                model="meta/llama-3-8b-instruct:dd2c4223f0ceee5d14e0a9a9f9d3f7f4e7470c3c9e3b5b1a79c780f4c6aef0be",
                temperature=0.7
            )
            print(f"\nLlama Response: {llama_response.content}\n")
            print(f"Model: {llama_response.model}")
            print(f"Usage: {llama_response.usage}")
            print("-" * 80)
        else:
            print("Skipping Llama example (REPLICATE_API_KEY not set)")
        
        # Example 6: Gemini
        if os.environ.get("GOOGLE_API_KEY"):
            print("\nExample 6: Gemini")
            gemini_provider = GeminiProvider()
            
            print("\nGenerating response from Gemini...")
            gemini_response = await gemini_provider.generate(
                messages=messages,
                model="gemini-1.0-pro",
                temperature=0.7
            )
            print(f"\nGemini Response: {gemini_response.content}\n")
            print(f"Model: {gemini_response.model}")
            print(f"Usage: {gemini_response.usage}")
            print("-" * 80)
        else:
            print("Skipping Gemini example (GOOGLE_API_KEY not set)")
        
        # Example 7: Embeddings
        if os.environ.get("OPENAI_API_KEY"):
            print("\nExample 7: Embeddings with OpenAI")
            openai_provider = OpenAIProvider()
            
            texts = [
                "Blockchain is a distributed ledger technology.",
                "Smart contracts are self-executing contracts with the terms directly written into code."
            ]
            
            print("\nGenerating embeddings from OpenAI...")
            embeddings = await openai_provider.embed(texts)
            
            print(f"Generated {len(embeddings)} embeddings")
            print(f"Embedding dimensions: {len(embeddings[0])}")
            print("-" * 80)
        else:
            print("Skipping embeddings example (OPENAI_API_KEY not set)")
    finally:
        # Disconnect from JuliaOS
        await juliaos.disconnect()
        print("Done!")


if __name__ == "__main__":
    asyncio.run(main())
