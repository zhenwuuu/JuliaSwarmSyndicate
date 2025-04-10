# LangChain Integration Examples

This directory contains examples of using the LangChain integration with JuliaOS.

## Prerequisites

Before running the examples, make sure you have the following:

1. JuliaOS Python wrapper installed
2. LangChain dependencies installed
3. API keys for OpenAI (or other LLM providers)

## Installation

```bash
# Install JuliaOS Python wrapper with LangChain dependencies
pip install juliaos[langchain]

# Or install LangChain dependencies separately
pip install langchain langchain-core langchain-community
```

## Examples

### Agent Example

This example demonstrates how to use JuliaOS agents with LangChain:

```bash
python agent_example.py
```

### Swarm Optimization Example

This example demonstrates how to use JuliaOS swarm optimization with LangChain:

```bash
python swarm_optimization_example.py
```

### Memory Example

This example demonstrates how to use JuliaOS memory with LangChain:

```bash
python memory_example.py
```

### Trading Strategy Example

This example demonstrates how to use JuliaOS with LangChain to develop and test trading strategies:

```bash
python trading_strategy_example.py
```

### Portfolio Optimization Example

This example demonstrates how to use JuliaOS with LangChain for portfolio optimization:

```bash
python portfolio_optimization_example.py
```

### Advanced Agents Example

This example demonstrates how to use advanced JuliaOS agents with LangChain:

```bash
python advanced_agents_example.py
```

### Advanced Tools Example

This example demonstrates how to use advanced JuliaOS tools with LangChain:

```bash
python advanced_tools_example.py
```

### Retriever Example

This example demonstrates how to use JuliaOS retrievers with LangChain:

```bash
python retriever_example.py
```

### RAG Example

This example demonstrates how to use JuliaOS retrievers with LangChain for Retrieval-Augmented Generation (RAG):

```bash
python rag_example.py
```

## Environment Variables

Create a `.env` file with the following variables:

```
JULIA_API_URL=ws://localhost:8080
OPENAI_API_KEY=your_openai_api_key
```

## Documentation

For more information about the LangChain integration, see the [LangChain Integration Documentation](../docs/langchain_integration.md).
