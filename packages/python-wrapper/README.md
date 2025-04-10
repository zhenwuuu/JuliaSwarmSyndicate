# JuliaOS Python Wrapper

Python wrapper for the JuliaOS Framework, providing a Pythonic interface to interact with the Julia backend.

## Installation

```bash
pip install juliaos
```

## Features

- Agent management and execution
- Swarm intelligence algorithms:
  - Differential Evolution (DE)
  - Particle Swarm Optimization (PSO)
  - Grey Wolf Optimizer (GWO)
  - Ant Colony Optimization (ACO)
  - Genetic Algorithm (GA)
  - Whale Optimization Algorithm (WOA)
- Blockchain integration
- Wallet management
- Storage operations
- LangChain integration
- Multiple LLM providers (OpenAI, Anthropic, Llama, Mistral, Cohere, Gemini)
- Google Agent Development Kit (ADK) integration

## Quick Start

### Agent Management

```python
import asyncio
from juliaos import JuliaOS

async def main():
    # Initialize JuliaOS
    juliaos = JuliaOS()
    await juliaos.connect()

    # Create an agent
    agent = await juliaos.agents.create_agent(
        name="My Agent",
        agent_type="TRADING",
        config={
            "parameters": {
                "risk_tolerance": 0.5,
                "max_position_size": 1000.0
            }
        }
    )

    # Start the agent
    await agent.start()

    # Execute a task
    task = await agent.execute_task({
        "type": "analyze_market",
        "parameters": {
            "asset": "BTC",
            "timeframe": "1h"
        }
    })

    # Wait for task completion
    result = await task.wait_for_completion()
    print(result)

    # Clean up
    await agent.stop()
    await agent.delete()
    await juliaos.disconnect()

if __name__ == "__main__":
    asyncio.run(main())
```

### Swarm Optimization

```python
import asyncio
from juliaos import JuliaOS
from juliaos.swarms import DifferentialEvolution

async def main():
    # Initialize JuliaOS
    juliaos = JuliaOS()
    await juliaos.connect()

    try:
        # Create a Differential Evolution optimizer
        de = DifferentialEvolution(juliaos.bridge)

        # Define an objective function
        def sphere(x):
            return sum(xi**2 for xi in x)

        # Define bounds for each dimension
        bounds = [(-5.0, 5.0), (-5.0, 5.0)]

        # Configure the algorithm
        config = {
            "population_size": 50,
            "max_generations": 100,
            "crossover_probability": 0.7,
            "differential_weight": 0.8,
            "max_time_seconds": 30
        }

        # Run optimization
        result = await de.optimize(sphere, bounds, config)

        print(f"Best position: {result['best_position']}")
        print(f"Best fitness: {result['best_fitness']}")
        print(f"Iterations: {result['iterations']}")

    finally:
        # Disconnect from JuliaOS
        await juliaos.disconnect()

if __name__ == "__main__":
    asyncio.run(main())
```

## Available Swarm Algorithms

The JuliaOS Python wrapper provides access to various swarm intelligence algorithms:

### Differential Evolution (DE)

A powerful evolutionary algorithm that excels at finding global optima in complex, multimodal landscapes. DE is particularly effective for portfolio optimization and trading strategy development due to its robustness and ability to handle non-differentiable objective functions.

```python
from juliaos.swarms import DifferentialEvolution

de = DifferentialEvolution(juliaos.bridge)
result = await de.optimize(objective_function, bounds, config)
```

### Particle Swarm Optimization (PSO)

A widely used algorithm that excels in exploring continuous solution spaces. PSO is particularly effective for trading strategy optimization due to its ability to balance exploration and exploitation.

```python
from juliaos.swarms import ParticleSwarmOptimization

pso = ParticleSwarmOptimization(juliaos.bridge)
result = await pso.optimize(objective_function, bounds, config)
```

### Grey Wolf Optimizer (GWO)

Simulates the hunting behavior of grey wolves, with distinct leadership hierarchy. GWO is excellent for capturing market regimes and adapting to changing market conditions.

```python
from juliaos.swarms import GreyWolfOptimizer

gwo = GreyWolfOptimizer(juliaos.bridge)
result = await gwo.optimize(objective_function, bounds, config)
```

### Ant Colony Optimization (ACO)

Inspired by the foraging behavior of ants. ACO is well-suited for path-dependent strategies and sequential decision making in trading.

```python
from juliaos.swarms import AntColonyOptimization

aco = AntColonyOptimization(juliaos.bridge)
result = await aco.optimize(objective_function, bounds, config)
```

### Genetic Algorithm (GA)

Mimics natural selection through evolutionary processes. Genetic algorithms are excellent for complex trading rules with many interdependent parameters.

```python
from juliaos.swarms import GeneticAlgorithm

ga = GeneticAlgorithm(juliaos.bridge)
result = await ga.optimize(objective_function, bounds, config)
```

### Whale Optimization Algorithm (WOA)

Based on the bubble-net hunting strategy of humpback whales. WOA handles market volatility well with its spiral hunting technique and is effective for finding global optima.

```python
from juliaos.swarms import WhaleOptimizationAlgorithm

woa = WhaleOptimizationAlgorithm(juliaos.bridge)
result = await woa.optimize(objective_function, bounds, config)
```

## LangChain Integration

JuliaOS Python wrapper provides integration with LangChain, allowing you to use JuliaOS components with LangChain.

```python
import asyncio
from langchain_openai import ChatOpenAI
from juliaos import JuliaOS
from juliaos.langchain import JuliaOSTradingAgentAdapter, SwarmOptimizationTool

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

### Available LangChain Components

- **Agent Adapters**: Convert JuliaOS agents to LangChain agents
  - `JuliaOSAgentAdapter`: Base adapter class
  - `JuliaOSTradingAgentAdapter`: For trading agents
  - `JuliaOSMonitorAgentAdapter`: For monitor agents
  - `JuliaOSArbitrageAgentAdapter`: For arbitrage agents

- **Tools**: LangChain tools that wrap JuliaOS functionality
  - `SwarmOptimizationTool`: Run swarm optimization algorithms
  - `BlockchainQueryTool`: Query blockchain data
  - `WalletOperationTool`: Perform wallet operations
  - `StorageQueryTool`: Query JuliaOS storage

- **Memory**: LangChain memory classes that use JuliaOS storage
  - `JuliaOSConversationBufferMemory`: Conversation buffer memory
  - `JuliaOSVectorStoreMemory`: Vector store memory

- **Chains**: LangChain chains that use JuliaOS components
  - `SwarmOptimizationChain`: Chain for swarm optimization
  - `BlockchainAnalysisChain`: Chain for blockchain analysis
  - `TradingStrategyChain`: Chain for trading strategies

## LLM Providers

JuliaOS Python wrapper provides a unified interface for interacting with various LLM providers:

```python
import asyncio
from juliaos import JuliaOS
from juliaos.llm import OpenAIProvider, LLMMessage, LLMRole

async def main():
    # Initialize JuliaOS
    juliaos = JuliaOS()
    await juliaos.connect()

    # Initialize OpenAI provider
    openai_provider = OpenAIProvider()

    # Create messages
    messages = [
        LLMMessage(role=LLMRole.SYSTEM, content="You are a helpful AI assistant."),
        LLMMessage(role=LLMRole.USER, content="What is the capital of France?")
    ]

    # Generate response
    response = await openai_provider.generate(messages)
    print(response.content)

    # Clean up
    await juliaos.disconnect()

if __name__ == "__main__":
    asyncio.run(main())
```

### Available LLM Providers

- **OpenAIProvider**: For OpenAI models (GPT-4, GPT-3.5, etc.)
- **AnthropicProvider**: For Anthropic models (Claude 3 Opus, Sonnet, Haiku)
- **LlamaProvider**: For Llama models via Replicate API
- **MistralProvider**: For Mistral AI models
- **CohereProvider**: For Cohere models
- **GeminiProvider**: For Google Gemini models

## Google ADK Integration

JuliaOS Python wrapper provides integration with the Google Agent Development Kit (ADK):

```python
import asyncio
from juliaos import JuliaOS
from juliaos.adk import JuliaOSADKAdapter

async def main():
    # Initialize JuliaOS
    juliaos = JuliaOS()
    await juliaos.connect()

    # Create a JuliaOS agent
    agent = await juliaos.agents.create_agent({
        "name": "trading_agent",
        "agent_type": "TRADING",
        "description": "A trading agent for cryptocurrency markets"
    })

    # Create ADK adapter
    adk_adapter = JuliaOSADKAdapter(juliaos.bridge)

    # Convert JuliaOS agent to ADK agent
    adk_agent = adk_adapter.agent_to_adk(agent)

    # Process user input with the ADK agent
    response = await adk_agent.process("What's the current market sentiment for Bitcoin?")
    print(response.response)

    # Clean up
    await juliaos.disconnect()

if __name__ == "__main__":
    asyncio.run(main())
```

### Available ADK Components

- **JuliaOSADKAdapter**: Adapter for converting JuliaOS components to ADK components
- **JuliaOSADKAgent**: ADK agent implementation for JuliaOS agents
- **JuliaOSADKTool**: ADK tool implementation for JuliaOS tools
- **JuliaOSADKMemory**: ADK memory implementation using JuliaOS storage

## Documentation

For detailed documentation, see [https://docs.juliaos.com/python](https://docs.juliaos.com/python)

## License

MIT
