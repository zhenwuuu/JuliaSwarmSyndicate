# JuliaOS LangChain Integration

This module provides integration between LangChain and JuliaOS, allowing users to use JuliaOS components with LangChain.

## Installation

To use the LangChain integration, you need to install the JuliaOS Python wrapper with LangChain dependencies:

```bash
pip install juliaos[langchain]
```

Or install LangChain dependencies separately:

```bash
pip install langchain langchain-core langchain-community
```

## Components

The LangChain integration provides the following components:

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

### Utility Functions

Utility functions for working with LangChain and JuliaOS:

- `serialize_langchain_object`: Serialize a LangChain object to a string
- `deserialize_langchain_object`: Deserialize a LangChain object from a string
- `convert_to_langchain_format`: Convert JuliaOS data to LangChain format
- `convert_from_langchain_format`: Convert LangChain data to JuliaOS format

## Examples

For examples of using the LangChain integration, see the [examples directory](../../examples/langchain).

## Documentation

For more detailed documentation, see the [LangChain Integration Documentation](../../docs/langchain_integration.md).
