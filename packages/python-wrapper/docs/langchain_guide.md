# Comprehensive Guide to JuliaOS LangChain Integration

This guide provides a comprehensive overview of the LangChain integration with JuliaOS, including detailed examples, best practices, and advanced usage patterns.

## Table of Contents

1. [Introduction](#introduction)
2. [Installation](#installation)
3. [Core Components](#core-components)
4. [Basic Usage](#basic-usage)
5. [Advanced Usage](#advanced-usage)
6. [Best Practices](#best-practices)
7. [Troubleshooting](#troubleshooting)
8. [API Reference](#api-reference)

## Introduction

The LangChain integration for JuliaOS allows you to combine the power of JuliaOS with the flexibility of LangChain. This integration enables you to:

- Use JuliaOS agents with LangChain
- Leverage JuliaOS swarm optimization algorithms in LangChain chains
- Store LangChain memory in JuliaOS storage
- Query blockchain data using LangChain tools
- Develop and test trading strategies using LangChain chains

## Installation

To use the LangChain integration, you need to install the JuliaOS Python wrapper with LangChain dependencies:

```bash
pip install juliaos[langchain]
```

Or install LangChain dependencies separately:

```bash
pip install langchain langchain-core langchain-community
```

You'll also need to install the appropriate LLM provider packages:

```bash
# For OpenAI
pip install langchain-openai

# For Anthropic
pip install langchain-anthropic

# For other providers
pip install langchain-google-vertexai  # Google Vertex AI
pip install langchain-cohere  # Cohere
```

## Core Components

The LangChain integration provides the following core components:

### Agent Adapters

Agent adapters convert JuliaOS agents to LangChain agents:

- `JuliaOSAgentAdapter`: Base adapter class for converting JuliaOS agents to LangChain agents
- `JuliaOSTradingAgentAdapter`: Adapter for trading agents
- `JuliaOSMonitorAgentAdapter`: Adapter for monitor agents
- `JuliaOSArbitrageAgentAdapter`: Adapter for arbitrage agents

### Tools

LangChain tools that wrap JuliaOS functionality:

- `JuliaOSBaseTool`: Base class for all JuliaOS tools
- `SwarmOptimizationTool`: Tool for running swarm optimization algorithms
- `BlockchainQueryTool`: Tool for querying blockchain data
- `WalletOperationTool`: Tool for wallet operations
- `StorageQueryTool`: Tool for querying JuliaOS storage
- `AgentTaskTool`: Tool for executing tasks on JuliaOS agents

### Memory

Memory classes that use JuliaOS storage:

- `JuliaOSMemory`: Base memory class using JuliaOS storage
- `JuliaOSConversationBufferMemory`: Conversation buffer memory using JuliaOS storage
- `JuliaOSVectorStoreMemory`: Vector store memory using JuliaOS storage

### Chains

Chain classes that use JuliaOS components:

- `JuliaOSChain`: Base chain class for JuliaOS
- `SwarmOptimizationChain`: Chain for swarm optimization
- `BlockchainAnalysisChain`: Chain for blockchain analysis
- `TradingStrategyChain`: Chain for trading strategies

### Retrievers

Retriever classes that use JuliaOS storage:

- `JuliaOSRetriever`: Base retriever class using JuliaOS storage
- `JuliaOSVectorStoreRetriever`: Vector store retriever using JuliaOS storage

## Basic Usage

### Using JuliaOS Agents with LangChain

```python
import asyncio
from langchain_openai import ChatOpenAI
from juliaos import JuliaOS
from juliaos.langchain import JuliaOSTradingAgentAdapter

async def main():
    # Initialize JuliaOS
    juliaos = JuliaOS()
    await juliaos.connect()
    
    # Initialize OpenAI LLM
    llm = ChatOpenAI(model="gpt-4")
    
    # Create a JuliaOS trading agent
    trading_agent = await juliaos.agents.create_agent(
        name="Trading Agent",
        agent_type="TRADING",
        config={"parameters": {"risk_tolerance": 0.5}}
    )
    
    # Create a LangChain agent from the JuliaOS agent
    langchain_agent = JuliaOSTradingAgentAdapter(trading_agent).as_langchain_agent(
        llm=llm,
        verbose=True
    )
    
    # Run the agent
    result = await langchain_agent.arun("Analyze the current market conditions for BTC/USDC")
    print(result)
    
    # Clean up
    await juliaos.disconnect()

if __name__ == "__main__":
    asyncio.run(main())
```

### Using JuliaOS Swarm Optimization with LangChain

```python
import asyncio
from langchain_openai import ChatOpenAI
from juliaos import JuliaOS
from juliaos.langchain import SwarmOptimizationChain

async def main():
    # Initialize JuliaOS
    juliaos = JuliaOS()
    await juliaos.connect()
    
    # Initialize OpenAI LLM
    llm = ChatOpenAI(model="gpt-4")
    
    # Create a SwarmOptimizationChain
    chain = SwarmOptimizationChain(
        bridge=juliaos.bridge,
        llm=llm,
        algorithm="DE"
    )
    
    # Run the chain
    result = await chain.arun(
        problem_description="Find the minimum of the Rosenbrock function: f(x,y) = (1-x)^2 + 100(y-x^2)^2",
        bounds=[[-5, 5], [-5, 5]],
        config={"population_size": 50, "max_iterations": 100}
    )
    print(result)
    
    # Clean up
    await juliaos.disconnect()

if __name__ == "__main__":
    asyncio.run(main())
```

### Using JuliaOS Memory with LangChain

```python
import asyncio
from langchain_openai import ChatOpenAI
from langchain.chains import ConversationChain
from langchain.prompts import ChatPromptTemplate
from juliaos import JuliaOS
from juliaos.langchain import JuliaOSConversationBufferMemory

async def main():
    # Initialize JuliaOS
    juliaos = JuliaOS()
    await juliaos.connect()
    
    # Initialize OpenAI LLM
    llm = ChatOpenAI(model="gpt-4")
    
    # Create a memory using JuliaOS storage
    memory = JuliaOSConversationBufferMemory(
        bridge=juliaos.bridge,
        memory_key="chat_history"
    )
    
    # Create a prompt template
    prompt = ChatPromptTemplate.from_template(
        "You are a helpful assistant. Chat history: {chat_history}\nHuman: {input}\nAI: "
    )
    
    # Create a conversation chain
    chain = ConversationChain(
        llm=llm,
        prompt=prompt,
        memory=memory,
        verbose=True
    )
    
    # Run the chain multiple times to demonstrate memory
    result1 = await chain.arun(input="Hello, I'm interested in crypto trading.")
    print(f"Result 1: {result1}")
    
    result2 = await chain.arun(input="What trading strategy would you recommend for a beginner?")
    print(f"Result 2: {result2}")
    
    # Clean up
    await juliaos.disconnect()

if __name__ == "__main__":
    asyncio.run(main())
```

## Advanced Usage

### Combining Multiple Components

You can combine multiple LangChain components to create more complex applications:

```python
import asyncio
from langchain_openai import ChatOpenAI
from langchain.agents import AgentExecutor
from langchain.chains import LLMChain
from langchain.prompts import ChatPromptTemplate
from juliaos import JuliaOS
from juliaos.langchain import (
    JuliaOSTradingAgentAdapter,
    SwarmOptimizationTool,
    BlockchainQueryTool,
    JuliaOSConversationBufferMemory
)

async def main():
    # Initialize JuliaOS
    juliaos = JuliaOS()
    await juliaos.connect()
    
    # Initialize OpenAI LLM
    llm = ChatOpenAI(model="gpt-4")
    
    # Create a JuliaOS trading agent
    trading_agent = await juliaos.agents.create_agent(
        name="Trading Agent",
        agent_type="TRADING",
        config={"parameters": {"risk_tolerance": 0.5}}
    )
    
    # Create a LangChain agent from the JuliaOS agent
    langchain_agent = JuliaOSTradingAgentAdapter(trading_agent).as_langchain_agent(
        llm=llm,
        verbose=True
    )
    
    # Create tools
    swarm_tool = SwarmOptimizationTool(juliaos.bridge)
    blockchain_tool = BlockchainQueryTool(juliaos.bridge)
    
    # Create a memory
    memory = JuliaOSConversationBufferMemory(
        bridge=juliaos.bridge,
        memory_key="chat_history"
    )
    
    # Create an agent executor with the tools and memory
    agent_executor = AgentExecutor.from_agent_and_tools(
        agent=langchain_agent.agent,
        tools=[swarm_tool, blockchain_tool],
        memory=memory,
        verbose=True
    )
    
    # Run the agent
    result = await agent_executor.arun(
        "Optimize a trading strategy for BTC/USDC and analyze the current market conditions."
    )
    print(result)
    
    # Clean up
    await juliaos.disconnect()

if __name__ == "__main__":
    asyncio.run(main())
```

### Creating Custom Tools

You can create custom tools that leverage JuliaOS functionality:

```python
from langchain.tools import BaseTool
from langchain.callbacks.manager import AsyncCallbackManagerForToolRun
from typing import Optional
import json

class CustomJuliaOSTool(BaseTool):
    """
    Custom tool that leverages JuliaOS functionality.
    """
    
    name = "custom_juliaos_tool"
    description = """
    Custom tool that leverages JuliaOS functionality.
    
    Input should be a JSON object with the following fields:
    - operation: The operation to perform
    - parameters: Parameters for the operation
    
    Example:
    {
        "operation": "custom_operation",
        "parameters": {
            "param1": "value1",
            "param2": "value2"
        }
    }
    """
    
    bridge = None
    
    def __init__(self, bridge, **kwargs):
        """
        Initialize the tool with a JuliaBridge.
        
        Args:
            bridge: The JuliaBridge to use for communication with the Julia backend
            **kwargs: Additional arguments to pass to the BaseTool constructor
        """
        super().__init__(bridge=bridge, **kwargs)
        self.bridge = bridge
    
    async def _arun(
        self,
        input_str: str,
        run_manager: Optional[AsyncCallbackManagerForToolRun] = None
    ) -> str:
        """
        Run the tool asynchronously.
        
        Args:
            input_str: The input string in JSON format
            run_manager: The callback manager for the tool run
        
        Returns:
            str: The result of the operation
        """
        try:
            # Parse the input
            input_data = json.loads(input_str)
            
            # Extract the parameters
            operation = input_data.get("operation", "")
            parameters = input_data.get("parameters", {})
            
            # Execute the operation
            result = await self.bridge.execute("Custom.execute_operation", [
                operation,
                parameters
            ])
            
            # Format the result
            return json.dumps(result, indent=2)
            
        except Exception as e:
            return f"Error executing custom operation: {str(e)}"
```

### Creating Custom Chains

You can create custom chains that leverage JuliaOS functionality:

```python
from langchain.chains.base import Chain
from langchain_core.language_models import BaseLanguageModel
from typing import Dict, Any, List
from pydantic import BaseModel, Field
import asyncio

class CustomJuliaOSChain(Chain):
    """
    Custom chain that leverages JuliaOS functionality.
    """
    
    bridge = None
    llm: BaseLanguageModel = None
    
    def __init__(self, bridge, llm, **kwargs):
        """
        Initialize the chain with a JuliaBridge and LLM.
        
        Args:
            bridge: The JuliaBridge to use for communication with the Julia backend
            llm: The language model to use
            **kwargs: Additional arguments to pass to the Chain constructor
        """
        super().__init__(**kwargs)
        self.bridge = bridge
        self.llm = llm
    
    @property
    def input_keys(self) -> List[str]:
        """
        Get the input keys for the chain.
        
        Returns:
            List[str]: The input keys
        """
        return ["input"]
    
    @property
    def output_keys(self) -> List[str]:
        """
        Get the output keys for the chain.
        
        Returns:
            List[str]: The output keys
        """
        return ["output"]
    
    def _call(self, inputs: Dict[str, Any]) -> Dict[str, Any]:
        """
        Call the chain.
        
        Args:
            inputs: The inputs to the chain
        
        Returns:
            Dict[str, Any]: The outputs from the chain
        """
        # This is a synchronous method, so we need to run the async method in a new event loop
        return asyncio.run(self._acall(inputs))
    
    async def _acall(self, inputs: Dict[str, Any]) -> Dict[str, Any]:
        """
        Call the chain asynchronously.
        
        Args:
            inputs: The inputs to the chain
        
        Returns:
            Dict[str, Any]: The outputs from the chain
        """
        # Extract the input
        input_str = inputs.get("input", "")
        
        # Process the input with the LLM
        llm_result = await self.llm.agenerate([input_str])
        llm_output = llm_result.generations[0][0].text
        
        # Process the LLM output with JuliaOS
        result = await self.bridge.execute("Custom.process_llm_output", [
            llm_output,
            {}  # Additional parameters
        ])
        
        # Return the result
        return {"output": result}
```

## Best Practices

### Memory Management

When using JuliaOS memory with LangChain, it's important to manage memory properly:

1. **Clear Memory When Done**: Always clear memory when you're done with it to avoid memory leaks:

```python
# Clear memory
memory.clear()
```

2. **Use Appropriate Storage Types**: Use the appropriate storage type for your use case:

```python
# For local storage
memory = JuliaOSConversationBufferMemory(
    bridge=juliaos.bridge,
    storage_type="local",
    storage_key="langchain_conversation_memory"
)

# For decentralized storage
memory = JuliaOSConversationBufferMemory(
    bridge=juliaos.bridge,
    storage_type="arweave",
    storage_key="langchain_conversation_memory"
)
```

### Error Handling

When using JuliaOS with LangChain, it's important to handle errors properly:

```python
try:
    # Run the agent
    result = await langchain_agent.arun("Analyze the current market conditions for BTC/USDC")
    print(result)
except Exception as e:
    print(f"Error running agent: {str(e)}")
finally:
    # Always disconnect from JuliaOS
    await juliaos.disconnect()
```

### Performance Optimization

To optimize performance when using JuliaOS with LangChain:

1. **Reuse Connections**: Reuse the JuliaOS connection for multiple operations:

```python
# Initialize JuliaOS once
juliaos = JuliaOS()
await juliaos.connect()

# Use the same connection for multiple operations
agent1 = await juliaos.agents.create_agent(...)
agent2 = await juliaos.agents.create_agent(...)

# Disconnect when done
await juliaos.disconnect()
```

2. **Batch Operations**: Batch operations when possible:

```python
# Instead of running multiple agents sequentially
result1 = await agent1.execute_task(task1)
result2 = await agent2.execute_task(task2)

# Run them concurrently
results = await asyncio.gather(
    agent1.execute_task(task1),
    agent2.execute_task(task2)
)
result1, result2 = results
```

## Troubleshooting

### Common Issues

#### Connection Issues

If you're having trouble connecting to JuliaOS:

```python
# Check if JuliaOS is running
try:
    juliaos = JuliaOS()
    await juliaos.connect()
    print("Connected to JuliaOS")
except Exception as e:
    print(f"Error connecting to JuliaOS: {str(e)}")
```

#### Import Issues

If you're having trouble importing the LangChain integration:

```python
# Check if the LangChain integration is installed
try:
    from juliaos import langchain
    print("LangChain integration is installed")
except ImportError:
    print("LangChain integration is not installed")
```

#### Memory Issues

If you're having trouble with JuliaOS memory:

```python
# Check if the memory is working
try:
    memory = JuliaOSConversationBufferMemory(
        bridge=juliaos.bridge,
        memory_key="chat_history"
    )
    memory.save_context({"input": "Hello"}, {"output": "Hi there!"})
    memory_variables = memory.load_memory_variables({})
    print(f"Memory variables: {memory_variables}")
except Exception as e:
    print(f"Error with memory: {str(e)}")
```

### Debugging

To debug issues with the LangChain integration:

1. **Enable Verbose Mode**: Enable verbose mode to see more detailed output:

```python
# Enable verbose mode
langchain_agent = JuliaOSTradingAgentAdapter(trading_agent).as_langchain_agent(
    llm=llm,
    verbose=True
)
```

2. **Check JuliaOS Logs**: Check the JuliaOS logs for errors:

```python
# Check JuliaOS logs
logs = await juliaos.bridge.execute("System.getLogs", [])
print(logs)
```

## API Reference

For a complete API reference, see the [LangChain Integration API Reference](./langchain_api_reference.md).
