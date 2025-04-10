# LangChain Integration

JuliaOS Python wrapper provides integration with LangChain, allowing you to use JuliaOS components with LangChain.

## Additional Documentation

- [Comprehensive Guide to JuliaOS LangChain Integration](./langchain_guide.md)
- [LangChain Integration API Reference](./langchain_api_reference.md)
- [Examples](../examples/langchain/README.md)

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
- `JuliaOSPortfolioAgentAdapter`: Adapter for portfolio management agents
- `JuliaOSMarketMakingAgentAdapter`: Adapter for market making agents
- `JuliaOSLiquidityAgentAdapter`: Adapter for liquidity provider agents
- `JuliaOSYieldFarmingAgentAdapter`: Adapter for yield farming agents
- `JuliaOSCrossChainAgentAdapter`: Adapter for cross-chain agents

Example:

```python
from juliaos import JuliaOS
from juliaos.langchain import JuliaOSTradingAgentAdapter
from langchain_openai import ChatOpenAI

# Initialize JuliaOS
juliaos = JuliaOS()
await juliaos.connect()

# Create a JuliaOS trading agent
trading_agent = await juliaos.agents.create_agent(
    name="Trading Agent",
    agent_type="TRADING",
    config={"parameters": {"risk_tolerance": 0.5}}
)

# Create a LangChain agent from the JuliaOS agent
llm = ChatOpenAI(model="gpt-4")
langchain_agent = JuliaOSTradingAgentAdapter(trading_agent).as_langchain_agent(
    llm=llm,
    verbose=True
)

# Run the agent
result = await langchain_agent.arun("Analyze the current market conditions for BTC/USDC")
print(result)
```

### Tools

LangChain tools that wrap JuliaOS functionality:

- `JuliaOSBaseTool`: Base class for all JuliaOS tools
- `SwarmOptimizationTool`: Tool for running swarm optimization algorithms
- `BlockchainQueryTool`: Tool for querying blockchain data
- `WalletOperationTool`: Tool for wallet operations
- `StorageQueryTool`: Tool for querying JuliaOS storage
- `AgentTaskTool`: Tool for executing tasks on JuliaOS agents
- `CrossChainBridgeTool`: Tool for cross-chain bridge operations
- `DEXTradingTool`: Tool for DEX trading operations
- `YieldFarmingTool`: Tool for yield farming operations
- `NFTTool`: Tool for NFT operations
- `DAOTool`: Tool for DAO operations
- `SocialMediaTool`: Tool for social media operations

Example:

```python
from juliaos import JuliaOS
from juliaos.langchain import SwarmOptimizationTool
from langchain.agents import initialize_agent, AgentType
from langchain_openai import ChatOpenAI

# Initialize JuliaOS
juliaos = JuliaOS()
await juliaos.connect()

# Create a SwarmOptimizationTool
swarm_tool = SwarmOptimizationTool(juliaos.bridge)

# Create an LLM
llm = ChatOpenAI(model="gpt-4")

# Create an agent with the tool
agent = initialize_agent(
    tools=[swarm_tool],
    llm=llm,
    agent=AgentType.STRUCTURED_CHAT_ZERO_SHOT_REACT_DESCRIPTION,
    verbose=True
)

# Run the agent
result = await agent.arun(
    "Find the minimum of the Rosenbrock function: f(x,y) = (1-x)^2 + 100(y-x^2)^2"
)
print(result)
```

### Memory

Memory classes that use JuliaOS storage:

- `JuliaOSMemory`: Base memory class using JuliaOS storage
- `JuliaOSConversationBufferMemory`: Conversation buffer memory using JuliaOS storage
- `JuliaOSVectorStoreMemory`: Vector store memory using JuliaOS storage

Example:

```python
from juliaos import JuliaOS
from juliaos.langchain import JuliaOSConversationBufferMemory
from langchain.chains import ConversationChain
from langchain_openai import ChatOpenAI

# Initialize JuliaOS
juliaos = JuliaOS()
await juliaos.connect()

# Create a memory using JuliaOS storage
memory = JuliaOSConversationBufferMemory(
    bridge=juliaos.bridge,
    memory_key="conversation_history"
)

# Create a conversation chain
llm = ChatOpenAI(model="gpt-4")
conversation = ConversationChain(
    llm=llm,
    memory=memory,
    verbose=True
)

# Run the chain
response = await conversation.arun("Hello, I'm interested in crypto trading.")
print(response)
```

### Chains

Chain classes that use JuliaOS components:

- `JuliaOSChain`: Base chain class for JuliaOS
- `SwarmOptimizationChain`: Chain for swarm optimization
- `BlockchainAnalysisChain`: Chain for blockchain analysis
- `TradingStrategyChain`: Chain for trading strategies

Example:

```python
from juliaos import JuliaOS
from juliaos.langchain import SwarmOptimizationChain
from langchain_openai import ChatOpenAI

# Initialize JuliaOS
juliaos = JuliaOS()
await juliaos.connect()

# Create a SwarmOptimizationChain
llm = ChatOpenAI(model="gpt-4")
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
```

### Retrievers

Retriever classes that use JuliaOS storage:

- `JuliaOSRetriever`: Base retriever class using JuliaOS storage
- `JuliaOSVectorStoreRetriever`: Vector store retriever using JuliaOS storage

Example:

```python
from juliaos import JuliaOS
from juliaos.langchain import JuliaOSVectorStoreRetriever
from langchain.chains import RetrievalQA
from langchain_openai import ChatOpenAI, OpenAIEmbeddings

# Initialize JuliaOS
juliaos = JuliaOS()
await juliaos.connect()

# Create embeddings
embeddings = OpenAIEmbeddings()

# Create a retriever using JuliaOS storage
retriever = JuliaOSVectorStoreRetriever(
    bridge=juliaos.bridge,
    storage_type="local",
    collection_name="trading_documents",
    embeddings=embeddings
)

# Create a retrieval QA chain
llm = ChatOpenAI(model="gpt-4")
qa_chain = RetrievalQA.from_chain_type(
    llm=llm,
    chain_type="stuff",
    retriever=retriever,
    verbose=True
)

# Run the chain
response = await qa_chain.arun("What are the best trading strategies for volatile markets?")
print(response)
```

## Utility Functions

Utility functions for working with LangChain and JuliaOS:

- `serialize_langchain_object`: Serialize a LangChain object to a string
- `deserialize_langchain_object`: Deserialize a LangChain object from a string
- `convert_to_langchain_format`: Convert JuliaOS data to LangChain format
- `convert_from_langchain_format`: Convert LangChain data to JuliaOS format

Example:

```python
from juliaos.langchain.utils import serialize_langchain_object, deserialize_langchain_object

# Serialize a LangChain object
obj = {"key": "value"}
serialized = serialize_langchain_object(obj)

# Deserialize a LangChain object
deserialized = deserialize_langchain_object(serialized)
assert obj == deserialized
```
