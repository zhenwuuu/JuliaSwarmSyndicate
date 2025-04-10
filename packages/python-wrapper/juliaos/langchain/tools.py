"""
LangChain tools for JuliaOS.

This module provides LangChain tools that wrap JuliaOS functionality.
"""

from typing import Dict, Any, List, Optional, Union, Callable, Type
import asyncio
from pydantic import BaseModel, Field

from langchain.tools import BaseTool
from langchain.callbacks.manager import AsyncCallbackManagerForToolRun, CallbackManagerForToolRun

from ..agents import Agent
from ..swarms import (
    DifferentialEvolution, ParticleSwarmOptimization,
    GreyWolfOptimizer, AntColonyOptimization,
    GeneticAlgorithm, WhaleOptimizationAlgorithm
)
from ..bridge import JuliaBridge


class JuliaOSBaseTool(BaseTool):
    """
    Base class for all JuliaOS tools.
    
    This class provides common functionality for all JuliaOS tools.
    """
    
    bridge: JuliaBridge = Field(exclude=True)
    
    def __init__(self, bridge: JuliaBridge, **kwargs):
        """
        Initialize the tool with a JuliaBridge.
        
        Args:
            bridge: The JuliaBridge to use for communication with the Julia backend
            **kwargs: Additional arguments to pass to the BaseTool constructor
        """
        super().__init__(bridge=bridge, **kwargs)
    
    async def _arun(self, *args, **kwargs) -> str:
        """
        Run the tool asynchronously.
        
        This method should be implemented by subclasses.
        """
        raise NotImplementedError("Subclasses must implement _arun")


class SwarmOptimizationTool(JuliaOSBaseTool):
    """
    Tool for running swarm optimization algorithms.
    
    This tool allows LangChain agents to use JuliaOS swarm optimization algorithms.
    """
    
    name = "swarm_optimization"
    description = """
    Run a swarm optimization algorithm to find the optimal solution to a problem.
    
    Input should be a JSON object with the following fields:
    - algorithm: The algorithm to use (DE, PSO, GWO, ACO, GA, WOA)
    - objective_function: A description of the objective function
    - bounds: A list of [min, max] bounds for each dimension
    - config: Optional configuration parameters for the algorithm
    
    Example:
    {
        "algorithm": "DE",
        "objective_function": "Minimize the sum of squares of the inputs",
        "bounds": [[-5, 5], [-5, 5]],
        "config": {
            "population_size": 50,
            "max_iterations": 100
        }
    }
    """
    
    def _get_algorithm_class(self, algorithm_name: str):
        """
        Get the algorithm class for the given algorithm name.
        
        Args:
            algorithm_name: The name of the algorithm
        
        Returns:
            The algorithm class
        
        Raises:
            ValueError: If the algorithm is not supported
        """
        algorithm_map = {
            "DE": DifferentialEvolution,
            "PSO": ParticleSwarmOptimization,
            "GWO": GreyWolfOptimizer,
            "ACO": AntColonyOptimization,
            "GA": GeneticAlgorithm,
            "WOA": WhaleOptimizationAlgorithm
        }
        
        if algorithm_name not in algorithm_map:
            raise ValueError(f"Unsupported algorithm: {algorithm_name}. Supported algorithms: {', '.join(algorithm_map.keys())}")
        
        return algorithm_map[algorithm_name]
    
    async def _arun(
        self,
        input_str: str,
        run_manager: Optional[AsyncCallbackManagerForToolRun] = None
    ) -> str:
        """
        Run a swarm optimization algorithm.
        
        Args:
            input_str: The input string in JSON format
            run_manager: The callback manager for the tool run
        
        Returns:
            str: The result of the optimization
        """
        import json
        
        try:
            # Parse the input
            input_data = json.loads(input_str)
            
            # Extract the parameters
            algorithm_name = input_data.get("algorithm", "DE")
            objective_function_desc = input_data.get("objective_function", "")
            bounds = input_data.get("bounds", [[-5, 5], [-5, 5]])
            config = input_data.get("config", {})
            
            # Create a simple objective function based on the description
            # In a real implementation, this would be more sophisticated
            if "sum of squares" in objective_function_desc.lower():
                objective_function = lambda x: sum(xi**2 for xi in x)
            elif "rosenbrock" in objective_function_desc.lower():
                objective_function = lambda x: sum(100 * (x[i+1] - x[i]**2)**2 + (1 - x[i])**2 for i in range(len(x) - 1))
            else:
                # Default to sum of squares
                objective_function = lambda x: sum(xi**2 for xi in x)
            
            # Get the algorithm class
            algorithm_class = self._get_algorithm_class(algorithm_name)
            
            # Create the algorithm instance
            algorithm = algorithm_class(self.bridge)
            
            # Run the optimization
            result = await algorithm.optimize(objective_function, bounds, config)
            
            # Format the result
            return json.dumps({
                "best_position": result.get("best_position", []),
                "best_fitness": result.get("best_fitness", float("inf")),
                "iterations": result.get("iterations", 0),
                "success": result.get("success", False)
            }, indent=2)
            
        except Exception as e:
            return f"Error running optimization: {str(e)}"


class BlockchainQueryTool(JuliaOSBaseTool):
    """
    Tool for querying blockchain data.
    
    This tool allows LangChain agents to query blockchain data using JuliaOS.
    """
    
    name = "blockchain_query"
    description = """
    Query blockchain data such as token balances, transaction history, and contract state.
    
    Input should be a JSON object with the following fields:
    - chain: The blockchain to query (ethereum, solana, etc.)
    - query_type: The type of query (balance, transaction, contract, etc.)
    - address: The address to query
    - parameters: Additional parameters for the query
    
    Example:
    {
        "chain": "ethereum",
        "query_type": "balance",
        "address": "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
        "parameters": {
            "token": "ETH"
        }
    }
    """
    
    async def _arun(
        self,
        input_str: str,
        run_manager: Optional[AsyncCallbackManagerForToolRun] = None
    ) -> str:
        """
        Query blockchain data.
        
        Args:
            input_str: The input string in JSON format
            run_manager: The callback manager for the tool run
        
        Returns:
            str: The result of the query
        """
        import json
        
        try:
            # Parse the input
            input_data = json.loads(input_str)
            
            # Extract the parameters
            chain = input_data.get("chain", "ethereum")
            query_type = input_data.get("query_type", "balance")
            address = input_data.get("address", "")
            parameters = input_data.get("parameters", {})
            
            # Execute the query
            result = await self.bridge.execute("Blockchain.query", [
                chain,
                query_type,
                address,
                parameters
            ])
            
            # Format the result
            return json.dumps(result, indent=2)
            
        except Exception as e:
            return f"Error querying blockchain: {str(e)}"


class WalletOperationTool(JuliaOSBaseTool):
    """
    Tool for wallet operations.
    
    This tool allows LangChain agents to perform wallet operations using JuliaOS.
    """
    
    name = "wallet_operation"
    description = """
    Perform wallet operations such as sending transactions, signing messages, and managing keys.
    
    Input should be a JSON object with the following fields:
    - operation: The operation to perform (send, sign, etc.)
    - chain: The blockchain to use (ethereum, solana, etc.)
    - parameters: Parameters for the operation
    
    Example:
    {
        "operation": "send",
        "chain": "ethereum",
        "parameters": {
            "to": "0x742d35Cc6634C0532925a3b844Bc454e4438f44e",
            "amount": "0.1",
            "token": "ETH"
        }
    }
    """
    
    async def _arun(
        self,
        input_str: str,
        run_manager: Optional[AsyncCallbackManagerForToolRun] = None
    ) -> str:
        """
        Perform a wallet operation.
        
        Args:
            input_str: The input string in JSON format
            run_manager: The callback manager for the tool run
        
        Returns:
            str: The result of the operation
        """
        import json
        
        try:
            # Parse the input
            input_data = json.loads(input_str)
            
            # Extract the parameters
            operation = input_data.get("operation", "")
            chain = input_data.get("chain", "ethereum")
            parameters = input_data.get("parameters", {})
            
            # Execute the operation
            result = await self.bridge.execute("Wallet.execute_operation", [
                operation,
                chain,
                parameters
            ])
            
            # Format the result
            return json.dumps(result, indent=2)
            
        except Exception as e:
            return f"Error performing wallet operation: {str(e)}"


class StorageQueryTool(JuliaOSBaseTool):
    """
    Tool for querying JuliaOS storage.
    
    This tool allows LangChain agents to query data stored in JuliaOS.
    """
    
    name = "storage_query"
    description = """
    Query data stored in JuliaOS storage.
    
    Input should be a JSON object with the following fields:
    - storage_type: The type of storage to query (local, arweave, etc.)
    - query_type: The type of query (get, list, etc.)
    - key: The key to query
    - parameters: Additional parameters for the query
    
    Example:
    {
        "storage_type": "local",
        "query_type": "get",
        "key": "agent_data",
        "parameters": {
            "default_value": {}
        }
    }
    """
    
    async def _arun(
        self,
        input_str: str,
        run_manager: Optional[AsyncCallbackManagerForToolRun] = None
    ) -> str:
        """
        Query JuliaOS storage.
        
        Args:
            input_str: The input string in JSON format
            run_manager: The callback manager for the tool run
        
        Returns:
            str: The result of the query
        """
        import json
        
        try:
            # Parse the input
            input_data = json.loads(input_str)
            
            # Extract the parameters
            storage_type = input_data.get("storage_type", "local")
            query_type = input_data.get("query_type", "get")
            key = input_data.get("key", "")
            parameters = input_data.get("parameters", {})
            
            # Execute the query
            result = await self.bridge.execute("Storage.query", [
                storage_type,
                query_type,
                key,
                parameters
            ])
            
            # Format the result
            return json.dumps(result, indent=2)
            
        except Exception as e:
            return f"Error querying storage: {str(e)}"


class AgentTaskTool(BaseTool):
    """
    Tool for executing tasks on JuliaOS agents.
    
    This tool allows LangChain agents to execute tasks on JuliaOS agents.
    """
    
    name = "agent_task"
    description = """
    Execute a task on a JuliaOS agent.
    
    Input should be a JSON object with the following fields:
    - task_type: The type of task to execute
    - parameters: Parameters for the task
    
    Example:
    {
        "task_type": "analyze_market",
        "parameters": {
            "asset": "BTC",
            "timeframe": "1h"
        }
    }
    """
    
    agent: Agent = Field(exclude=True)
    
    def __init__(self, agent: Agent, **kwargs):
        """
        Initialize the tool with a JuliaOS agent.
        
        Args:
            agent: The JuliaOS agent to use for executing tasks
            **kwargs: Additional arguments to pass to the BaseTool constructor
        """
        super().__init__(agent=agent, **kwargs)
    
    async def _arun(
        self,
        input_str: str,
        run_manager: Optional[AsyncCallbackManagerForToolRun] = None
    ) -> str:
        """
        Execute a task on a JuliaOS agent.
        
        Args:
            input_str: The input string in JSON format
            run_manager: The callback manager for the tool run
        
        Returns:
            str: The result of the task
        """
        import json
        
        try:
            # Parse the input
            input_data = json.loads(input_str)
            
            # Extract the parameters
            task_type = input_data.get("task_type", "")
            parameters = input_data.get("parameters", {})
            
            # Create the task
            task = {
                "type": task_type,
                "parameters": parameters
            }
            
            # Execute the task
            result = await self.agent.execute_task(task)
            
            # Format the result
            return json.dumps(result, indent=2)
            
        except Exception as e:
            return f"Error executing agent task: {str(e)}"
