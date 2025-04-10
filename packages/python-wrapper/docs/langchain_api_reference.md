# LangChain Integration API Reference

This document provides a comprehensive API reference for the LangChain integration with JuliaOS.

## Table of Contents

1. [Agent Adapters](#agent-adapters)
2. [Tools](#tools)
3. [Memory](#memory)
4. [Chains](#chains)
5. [Retrievers](#retrievers)
6. [Utility Functions](#utility-functions)

## Agent Adapters

### JuliaOSAgentAdapter

Base adapter class for converting JuliaOS agents to LangChain agents.

```python
from juliaos.langchain import JuliaOSAgentAdapter

adapter = JuliaOSAgentAdapter(agent)
langchain_agent = adapter.as_langchain_agent(
    llm=llm,
    tools=tools,
    agent_type=AgentType.STRUCTURED_CHAT_ZERO_SHOT_REACT_DESCRIPTION,
    verbose=True
)
```

#### Parameters

- `agent`: The JuliaOS agent to adapt

#### Methods

- `execute_task(task)`: Execute a task on the JuliaOS agent
- `as_langchain_agent(llm, tools, agent_type, **kwargs)`: Convert the JuliaOS agent to a LangChain agent

### JuliaOSTradingAgentAdapter

Adapter for JuliaOS trading agents.

```python
from juliaos.langchain import JuliaOSTradingAgentAdapter

adapter = JuliaOSTradingAgentAdapter(trading_agent)
langchain_agent = adapter.as_langchain_agent(
    llm=llm,
    tools=tools,
    agent_type=AgentType.STRUCTURED_CHAT_ZERO_SHOT_REACT_DESCRIPTION,
    verbose=True
)
```

#### Parameters

- `agent`: The JuliaOS trading agent to adapt

#### Methods

- `execute_task(task)`: Execute a task on the JuliaOS trading agent
- `as_langchain_agent(llm, tools, agent_type, **kwargs)`: Convert the JuliaOS trading agent to a LangChain agent

### JuliaOSMonitorAgentAdapter

Adapter for JuliaOS monitor agents.

```python
from juliaos.langchain import JuliaOSMonitorAgentAdapter

adapter = JuliaOSMonitorAgentAdapter(monitor_agent)
langchain_agent = adapter.as_langchain_agent(
    llm=llm,
    tools=tools,
    agent_type=AgentType.STRUCTURED_CHAT_ZERO_SHOT_REACT_DESCRIPTION,
    verbose=True
)
```

#### Parameters

- `agent`: The JuliaOS monitor agent to adapt

#### Methods

- `execute_task(task)`: Execute a task on the JuliaOS monitor agent
- `as_langchain_agent(llm, tools, agent_type, **kwargs)`: Convert the JuliaOS monitor agent to a LangChain agent

### JuliaOSArbitrageAgentAdapter

Adapter for JuliaOS arbitrage agents.

```python
from juliaos.langchain import JuliaOSArbitrageAgentAdapter

adapter = JuliaOSArbitrageAgentAdapter(arbitrage_agent)
langchain_agent = adapter.as_langchain_agent(
    llm=llm,
    tools=tools,
    agent_type=AgentType.STRUCTURED_CHAT_ZERO_SHOT_REACT_DESCRIPTION,
    verbose=True
)
```

#### Parameters

- `agent`: The JuliaOS arbitrage agent to adapt

#### Methods

- `execute_task(task)`: Execute a task on the JuliaOS arbitrage agent
- `as_langchain_agent(llm, tools, agent_type, **kwargs)`: Convert the JuliaOS arbitrage agent to a LangChain agent

### JuliaOSPortfolioAgentAdapter

Adapter for JuliaOS portfolio management agents.

```python
from juliaos.langchain import JuliaOSPortfolioAgentAdapter

adapter = JuliaOSPortfolioAgentAdapter(portfolio_agent)
langchain_agent = adapter.as_langchain_agent(
    llm=llm,
    tools=tools,
    agent_type=AgentType.STRUCTURED_CHAT_ZERO_SHOT_REACT_DESCRIPTION,
    verbose=True
)
```

#### Parameters

- `agent`: The JuliaOS portfolio agent to adapt

#### Methods

- `execute_task(task)`: Execute a task on the JuliaOS portfolio agent
- `as_langchain_agent(llm, tools, agent_type, **kwargs)`: Convert the JuliaOS portfolio agent to a LangChain agent

### JuliaOSMarketMakingAgentAdapter

Adapter for JuliaOS market making agents.

```python
from juliaos.langchain import JuliaOSMarketMakingAgentAdapter

adapter = JuliaOSMarketMakingAgentAdapter(market_making_agent)
langchain_agent = adapter.as_langchain_agent(
    llm=llm,
    tools=tools,
    agent_type=AgentType.STRUCTURED_CHAT_ZERO_SHOT_REACT_DESCRIPTION,
    verbose=True
)
```

#### Parameters

- `agent`: The JuliaOS market making agent to adapt

#### Methods

- `execute_task(task)`: Execute a task on the JuliaOS market making agent
- `as_langchain_agent(llm, tools, agent_type, **kwargs)`: Convert the JuliaOS market making agent to a LangChain agent

### JuliaOSLiquidityAgentAdapter

Adapter for JuliaOS liquidity provider agents.

```python
from juliaos.langchain import JuliaOSLiquidityAgentAdapter

adapter = JuliaOSLiquidityAgentAdapter(liquidity_agent)
langchain_agent = adapter.as_langchain_agent(
    llm=llm,
    tools=tools,
    agent_type=AgentType.STRUCTURED_CHAT_ZERO_SHOT_REACT_DESCRIPTION,
    verbose=True
)
```

#### Parameters

- `agent`: The JuliaOS liquidity agent to adapt

#### Methods

- `execute_task(task)`: Execute a task on the JuliaOS liquidity agent
- `as_langchain_agent(llm, tools, agent_type, **kwargs)`: Convert the JuliaOS liquidity agent to a LangChain agent

### JuliaOSYieldFarmingAgentAdapter

Adapter for JuliaOS yield farming agents.

```python
from juliaos.langchain import JuliaOSYieldFarmingAgentAdapter

adapter = JuliaOSYieldFarmingAgentAdapter(yield_farming_agent)
langchain_agent = adapter.as_langchain_agent(
    llm=llm,
    tools=tools,
    agent_type=AgentType.STRUCTURED_CHAT_ZERO_SHOT_REACT_DESCRIPTION,
    verbose=True
)
```

#### Parameters

- `agent`: The JuliaOS yield farming agent to adapt

#### Methods

- `execute_task(task)`: Execute a task on the JuliaOS yield farming agent
- `as_langchain_agent(llm, tools, agent_type, **kwargs)`: Convert the JuliaOS yield farming agent to a LangChain agent

### JuliaOSCrossChainAgentAdapter

Adapter for JuliaOS cross-chain agents.

```python
from juliaos.langchain import JuliaOSCrossChainAgentAdapter

adapter = JuliaOSCrossChainAgentAdapter(cross_chain_agent)
langchain_agent = adapter.as_langchain_agent(
    llm=llm,
    tools=tools,
    agent_type=AgentType.STRUCTURED_CHAT_ZERO_SHOT_REACT_DESCRIPTION,
    verbose=True
)
```

#### Parameters

- `agent`: The JuliaOS cross-chain agent to adapt

#### Methods

- `execute_task(task)`: Execute a task on the JuliaOS cross-chain agent
- `as_langchain_agent(llm, tools, agent_type, **kwargs)`: Convert the JuliaOS cross-chain agent to a LangChain agent

## Tools

### JuliaOSBaseTool

Base class for all JuliaOS tools.

```python
from juliaos.langchain import JuliaOSBaseTool

class CustomTool(JuliaOSBaseTool):
    name = "custom_tool"
    description = "Custom tool description"

    async def _arun(self, input_str, run_manager=None):
        # Implement the tool logic here
        pass
```

#### Parameters

- `bridge`: The JuliaBridge to use for communication with the Julia backend

#### Methods

- `_arun(input_str, run_manager=None)`: Run the tool asynchronously

### SwarmOptimizationTool

Tool for running swarm optimization algorithms.

```python
from juliaos.langchain import SwarmOptimizationTool

tool = SwarmOptimizationTool(bridge)
```

#### Parameters

- `bridge`: The JuliaBridge to use for communication with the Julia backend

#### Methods

- `_arun(input_str, run_manager=None)`: Run the tool asynchronously

### BlockchainQueryTool

Tool for querying blockchain data.

```python
from juliaos.langchain import BlockchainQueryTool

tool = BlockchainQueryTool(bridge)
```

#### Parameters

- `bridge`: The JuliaBridge to use for communication with the Julia backend

#### Methods

- `_arun(input_str, run_manager=None)`: Run the tool asynchronously

### WalletOperationTool

Tool for wallet operations.

```python
from juliaos.langchain import WalletOperationTool

tool = WalletOperationTool(bridge)
```

#### Parameters

- `bridge`: The JuliaBridge to use for communication with the Julia backend

#### Methods

- `_arun(input_str, run_manager=None)`: Run the tool asynchronously

### StorageQueryTool

Tool for querying JuliaOS storage.

```python
from juliaos.langchain import StorageQueryTool

tool = StorageQueryTool(bridge)
```

#### Parameters

- `bridge`: The JuliaBridge to use for communication with the Julia backend

#### Methods

- `_arun(input_str, run_manager=None)`: Run the tool asynchronously

### AgentTaskTool

Tool for executing tasks on JuliaOS agents.

```python
from juliaos.langchain import AgentTaskTool

tool = AgentTaskTool(agent)
```

#### Parameters

- `agent`: The JuliaOS agent to use for executing tasks

#### Methods

- `_arun(input_str, run_manager=None)`: Run the tool asynchronously

### CrossChainBridgeTool

Tool for cross-chain bridge operations.

```python
from juliaos.langchain import CrossChainBridgeTool

tool = CrossChainBridgeTool(bridge)
```

#### Parameters

- `bridge`: The JuliaBridge to use for communication with the Julia backend

#### Methods

- `_arun(input_str, run_manager=None)`: Run the tool asynchronously

### DEXTradingTool

Tool for DEX trading operations.

```python
from juliaos.langchain import DEXTradingTool

tool = DEXTradingTool(bridge)
```

#### Parameters

- `bridge`: The JuliaBridge to use for communication with the Julia backend

#### Methods

- `_arun(input_str, run_manager=None)`: Run the tool asynchronously

### YieldFarmingTool

Tool for yield farming operations.

```python
from juliaos.langchain import YieldFarmingTool

tool = YieldFarmingTool(bridge)
```

#### Parameters

- `bridge`: The JuliaBridge to use for communication with the Julia backend

#### Methods

- `_arun(input_str, run_manager=None)`: Run the tool asynchronously

### NFTTool

Tool for NFT operations.

```python
from juliaos.langchain import NFTTool

tool = NFTTool(bridge)
```

#### Parameters

- `bridge`: The JuliaBridge to use for communication with the Julia backend

#### Methods

- `_arun(input_str, run_manager=None)`: Run the tool asynchronously

### DAOTool

Tool for DAO operations.

```python
from juliaos.langchain import DAOTool

tool = DAOTool(bridge)
```

#### Parameters

- `bridge`: The JuliaBridge to use for communication with the Julia backend

#### Methods

- `_arun(input_str, run_manager=None)`: Run the tool asynchronously

### SocialMediaTool

Tool for social media operations.

```python
from juliaos.langchain import SocialMediaTool

tool = SocialMediaTool(bridge)
```

#### Parameters

- `bridge`: The JuliaBridge to use for communication with the Julia backend

#### Methods

- `_arun(input_str, run_manager=None)`: Run the tool asynchronously

## Memory

### JuliaOSMemory

Base memory class using JuliaOS storage.

```python
from juliaos.langchain import JuliaOSMemory

memory = JuliaOSMemory(
    bridge=bridge,
    memory_key="memory",
    storage_type="local",
    storage_key="langchain_memory"
)
```

#### Parameters

- `bridge`: The JuliaBridge to use for communication with the Julia backend
- `memory_key`: The key to use for the memory in the context
- `storage_type`: The type of storage to use (local, arweave, etc.)
- `storage_key`: The key to use for storing the memory in JuliaOS storage

#### Methods

- `load_memory_variables(inputs)`: Load memory variables from JuliaOS storage
- `save_context(inputs, outputs)`: Save the context to JuliaOS storage
- `clear()`: Clear the memory

### JuliaOSConversationBufferMemory

Conversation buffer memory using JuliaOS storage.

```python
from juliaos.langchain import JuliaOSConversationBufferMemory

memory = JuliaOSConversationBufferMemory(
    bridge=bridge,
    memory_key="chat_history",
    storage_type="local",
    storage_key="langchain_conversation_memory"
)
```

#### Parameters

- `bridge`: The JuliaBridge to use for communication with the Julia backend
- `memory_key`: The key to use for the memory in the context
- `storage_type`: The type of storage to use (local, arweave, etc.)
- `storage_key`: The key to use for storing the memory in JuliaOS storage

#### Methods

- `load_memory_variables(inputs)`: Load memory variables from JuliaOS storage
- `save_context(inputs, outputs)`: Save the context to JuliaOS storage
- `clear()`: Clear the memory

### JuliaOSVectorStoreMemory

Vector store memory using JuliaOS storage.

```python
from juliaos.langchain import JuliaOSVectorStoreMemory

memory = JuliaOSVectorStoreMemory(
    bridge=bridge,
    retriever=retriever
)
```

#### Parameters

- `bridge`: The JuliaBridge to use for communication with the Julia backend
- `retriever`: The retriever to use for retrieving memory

#### Methods

- `load_memory_variables(inputs)`: Load memory variables from JuliaOS storage
- `save_context(inputs, outputs)`: Save the context to JuliaOS storage
- `clear()`: Clear the memory

## Chains

### JuliaOSChain

Base chain class for JuliaOS.

```python
from juliaos.langchain import JuliaOSChain

class CustomChain(JuliaOSChain):
    @property
    def input_keys(self):
        return ["input"]

    @property
    def output_keys(self):
        return ["output"]

    async def _acall(self, inputs):
        # Implement the chain logic here
        pass
```

#### Parameters

- `bridge`: The JuliaBridge to use for communication with the Julia backend

#### Methods

- `_call(inputs)`: Call the chain
- `_acall(inputs)`: Call the chain asynchronously

### SwarmOptimizationChain

Chain for swarm optimization.

```python
from juliaos.langchain import SwarmOptimizationChain

chain = SwarmOptimizationChain(
    bridge=bridge,
    llm=llm,
    algorithm="DE"
)
```

#### Parameters

- `bridge`: The JuliaBridge to use for communication with the Julia backend
- `llm`: The language model to use for generating objective functions
- `algorithm`: The swarm algorithm to use (DE, PSO, GWO, ACO, GA, WOA)

#### Methods

- `_acall(inputs)`: Call the chain asynchronously

### BlockchainAnalysisChain

Chain for blockchain analysis.

```python
from juliaos.langchain import BlockchainAnalysisChain

chain = BlockchainAnalysisChain(
    bridge=bridge,
    llm=llm,
    chain="ethereum"
)
```

#### Parameters

- `bridge`: The JuliaBridge to use for communication with the Julia backend
- `llm`: The language model to use for analyzing blockchain data
- `chain`: The blockchain to analyze

#### Methods

- `_acall(inputs)`: Call the chain asynchronously

### TradingStrategyChain

Chain for trading strategies.

```python
from juliaos.langchain import TradingStrategyChain

chain = TradingStrategyChain(
    bridge=bridge,
    llm=llm
)
```

#### Parameters

- `bridge`: The JuliaBridge to use for communication with the Julia backend
- `llm`: The language model to use for developing trading strategies

#### Methods

- `_acall(inputs)`: Call the chain asynchronously

## Retrievers

### JuliaOSRetriever

Base retriever class using JuliaOS storage.

```python
from juliaos.langchain import JuliaOSRetriever

retriever = JuliaOSRetriever(
    bridge=bridge,
    storage_type="local",
    collection_name="langchain_documents"
)
```

#### Parameters

- `bridge`: The JuliaBridge to use for communication with the Julia backend
- `storage_type`: The type of storage to use (local, arweave, etc.)
- `collection_name`: The name of the document collection in JuliaOS storage

#### Methods

- `_get_relevant_documents(query)`: Get documents relevant to the query
- `_aget_relevant_documents(query)`: Get documents relevant to the query asynchronously
- `add_documents(documents)`: Add documents to the storage
- `delete_documents(document_ids)`: Delete documents from the storage

### JuliaOSVectorStoreRetriever

Vector store retriever using JuliaOS storage.

```python
from juliaos.langchain import JuliaOSVectorStoreRetriever

retriever = JuliaOSVectorStoreRetriever(
    bridge=bridge,
    storage_type="local",
    collection_name="langchain_vector_documents",
    embeddings=embeddings
)
```

#### Parameters

- `bridge`: The JuliaBridge to use for communication with the Julia backend
- `storage_type`: The type of storage to use (local, arweave, etc.)
- `collection_name`: The name of the document collection in JuliaOS storage
- `embeddings`: The embeddings to use for vectorizing documents
- `search_kwargs`: Additional arguments to pass to the search function

#### Methods

- `_aget_relevant_documents(query)`: Get documents relevant to the query asynchronously
- `add_documents(documents)`: Add documents to the storage

## Utility Functions

### serialize_langchain_object

Serialize a LangChain object to a string.

```python
from juliaos.langchain import serialize_langchain_object

serialized = serialize_langchain_object(obj)
```

#### Parameters

- `obj`: The LangChain object to serialize

#### Returns

- `str`: The serialized object

### deserialize_langchain_object

Deserialize a LangChain object from a string.

```python
from juliaos.langchain import deserialize_langchain_object

obj = deserialize_langchain_object(serialized)
```

#### Parameters

- `serialized`: The serialized object

#### Returns

- `Any`: The deserialized object

### convert_to_langchain_format

Convert JuliaOS data to LangChain format.

```python
from juliaos.langchain import convert_to_langchain_format

langchain_data = convert_to_langchain_format(juliaos_data)
```

#### Parameters

- `data`: The JuliaOS data to convert

#### Returns

- `Dict[str, Any]`: The converted data in LangChain format

### convert_from_langchain_format

Convert LangChain data to JuliaOS format.

```python
from juliaos.langchain import convert_from_langchain_format

juliaos_data = convert_from_langchain_format(langchain_data)
```

#### Parameters

- `data`: The LangChain data to convert

#### Returns

- `Dict[str, Any]`: The converted data in JuliaOS format
