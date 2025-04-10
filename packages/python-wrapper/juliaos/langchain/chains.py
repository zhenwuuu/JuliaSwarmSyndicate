"""
LangChain chains integration with JuliaOS.

This module provides chain classes that use JuliaOS components.
"""

from typing import Dict, Any, List, Optional, Union, Callable, Type
import asyncio
from pydantic import BaseModel, Field

from langchain.chains.base import Chain
from langchain.chains import LLMChain
from langchain.prompts import PromptTemplate
from langchain_core.language_models import BaseLanguageModel

from ..bridge import JuliaBridge


class JuliaOSChain(Chain):
    """
    Base chain class for JuliaOS.
    
    This class provides the basic functionality for creating chains that use JuliaOS components.
    """
    
    bridge: JuliaBridge = Field(exclude=True)
    
    def __init__(self, bridge: JuliaBridge, **kwargs):
        """
        Initialize the chain with a JuliaBridge.
        
        Args:
            bridge: The JuliaBridge to use for communication with the Julia backend
            **kwargs: Additional arguments to pass to the Chain constructor
        """
        super().__init__(**kwargs)
        self.bridge = bridge
    
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
        raise NotImplementedError("Subclasses must implement _acall")


class SwarmOptimizationChain(JuliaOSChain):
    """
    Chain for swarm optimization.
    
    This chain uses JuliaOS swarm optimization algorithms to find optimal solutions.
    """
    
    llm: BaseLanguageModel = Field(exclude=True)
    algorithm: str = "DE"
    
    def __init__(
        self,
        bridge: JuliaBridge,
        llm: BaseLanguageModel,
        algorithm: str = "DE",
        **kwargs
    ):
        """
        Initialize the chain with a JuliaBridge and LLM.
        
        Args:
            bridge: The JuliaBridge to use for communication with the Julia backend
            llm: The language model to use for generating objective functions
            algorithm: The swarm algorithm to use (DE, PSO, GWO, ACO, GA, WOA)
            **kwargs: Additional arguments to pass to the JuliaOSChain constructor
        """
        super().__init__(bridge=bridge, **kwargs)
        self.llm = llm
        self.algorithm = algorithm
    
    @property
    def input_keys(self) -> List[str]:
        """
        Get the input keys for the chain.
        
        Returns:
            List[str]: The input keys
        """
        return ["problem_description", "bounds", "config"]
    
    @property
    def output_keys(self) -> List[str]:
        """
        Get the output keys for the chain.
        
        Returns:
            List[str]: The output keys
        """
        return ["best_position", "best_fitness", "iterations"]
    
    async def _acall(self, inputs: Dict[str, Any]) -> Dict[str, Any]:
        """
        Call the chain asynchronously.
        
        Args:
            inputs: The inputs to the chain
        
        Returns:
            Dict[str, Any]: The outputs from the chain
        """
        # Extract inputs
        problem_description = inputs.get("problem_description", "")
        bounds = inputs.get("bounds", [[-5, 5], [-5, 5]])
        config = inputs.get("config", {})
        
        # Generate an objective function from the problem description
        objective_function_prompt = PromptTemplate(
            input_variables=["problem_description"],
            template="""
            You are an expert in mathematical optimization. Given the following problem description,
            write a Python function that calculates the objective value to be minimized.
            
            Problem description: {problem_description}
            
            Write a Python function named 'objective_function' that takes a list of values as input
            and returns a single numerical value to be minimized.
            
            Example:
            ```python
            def objective_function(x):
                return sum(xi**2 for xi in x)
            ```
            
            Your function:
            """
        )
        
        # Create an LLMChain to generate the objective function
        objective_function_chain = LLMChain(llm=self.llm, prompt=objective_function_prompt)
        
        # Generate the objective function
        objective_function_result = await objective_function_chain.arun(problem_description=problem_description)
        
        # Extract the function code
        import re
        function_match = re.search(r"```python\s*(def objective_function.*?)\s*```", objective_function_result, re.DOTALL)
        if function_match:
            function_code = function_match.group(1)
        else:
            function_match = re.search(r"def objective_function.*", objective_function_result, re.DOTALL)
            if function_match:
                function_code = function_match.group(0)
            else:
                raise ValueError("Could not extract objective function from LLM output")
        
        # Execute the function code to get the objective function
        local_vars = {}
        exec(function_code, globals(), local_vars)
        objective_function = local_vars["objective_function"]
        
        # Create the appropriate algorithm
        from ..swarms import (
            DifferentialEvolution, ParticleSwarmOptimization,
            GreyWolfOptimizer, AntColonyOptimization,
            GeneticAlgorithm, WhaleOptimizationAlgorithm
        )
        
        algorithm_map = {
            "DE": DifferentialEvolution,
            "PSO": ParticleSwarmOptimization,
            "GWO": GreyWolfOptimizer,
            "ACO": AntColonyOptimization,
            "GA": GeneticAlgorithm,
            "WOA": WhaleOptimizationAlgorithm
        }
        
        if self.algorithm not in algorithm_map:
            raise ValueError(f"Unsupported algorithm: {self.algorithm}. Supported algorithms: {', '.join(algorithm_map.keys())}")
        
        algorithm_class = algorithm_map[self.algorithm]
        algorithm = algorithm_class(self.bridge)
        
        # Run the optimization
        result = await algorithm.optimize(objective_function, bounds, config)
        
        # Return the results
        return {
            "best_position": result.get("best_position", []),
            "best_fitness": result.get("best_fitness", float("inf")),
            "iterations": result.get("iterations", 0)
        }


class BlockchainAnalysisChain(JuliaOSChain):
    """
    Chain for blockchain analysis.
    
    This chain analyzes blockchain data using JuliaOS.
    """
    
    llm: BaseLanguageModel = Field(exclude=True)
    chain: str = "ethereum"
    
    def __init__(
        self,
        bridge: JuliaBridge,
        llm: BaseLanguageModel,
        chain: str = "ethereum",
        **kwargs
    ):
        """
        Initialize the chain with a JuliaBridge and LLM.
        
        Args:
            bridge: The JuliaBridge to use for communication with the Julia backend
            llm: The language model to use for analyzing blockchain data
            chain: The blockchain to analyze
            **kwargs: Additional arguments to pass to the JuliaOSChain constructor
        """
        super().__init__(bridge=bridge, **kwargs)
        self.llm = llm
        self.chain = chain
    
    @property
    def input_keys(self) -> List[str]:
        """
        Get the input keys for the chain.
        
        Returns:
            List[str]: The input keys
        """
        return ["address", "query_type", "parameters"]
    
    @property
    def output_keys(self) -> List[str]:
        """
        Get the output keys for the chain.
        
        Returns:
            List[str]: The output keys
        """
        return ["data", "analysis"]
    
    async def _acall(self, inputs: Dict[str, Any]) -> Dict[str, Any]:
        """
        Call the chain asynchronously.
        
        Args:
            inputs: The inputs to the chain
        
        Returns:
            Dict[str, Any]: The outputs from the chain
        """
        # Extract inputs
        address = inputs.get("address", "")
        query_type = inputs.get("query_type", "balance")
        parameters = inputs.get("parameters", {})
        
        # Query the blockchain
        result = await self.bridge.execute("Blockchain.query", [
            self.chain,
            query_type,
            address,
            parameters
        ])
        
        # Generate an analysis of the data
        analysis_prompt = PromptTemplate(
            input_variables=["chain", "address", "query_type", "data"],
            template="""
            You are an expert in blockchain analysis. Given the following blockchain data,
            provide a detailed analysis of what it means.
            
            Chain: {chain}
            Address: {address}
            Query Type: {query_type}
            Data: {data}
            
            Provide a detailed analysis of this data, including any insights or patterns you observe.
            """
        )
        
        # Create an LLMChain to generate the analysis
        analysis_chain = LLMChain(llm=self.llm, prompt=analysis_prompt)
        
        # Generate the analysis
        analysis = await analysis_chain.arun(
            chain=self.chain,
            address=address,
            query_type=query_type,
            data=str(result)
        )
        
        # Return the results
        return {
            "data": result,
            "analysis": analysis
        }


class TradingStrategyChain(JuliaOSChain):
    """
    Chain for trading strategies.
    
    This chain develops and tests trading strategies using JuliaOS.
    """
    
    llm: BaseLanguageModel = Field(exclude=True)
    
    def __init__(
        self,
        bridge: JuliaBridge,
        llm: BaseLanguageModel,
        **kwargs
    ):
        """
        Initialize the chain with a JuliaBridge and LLM.
        
        Args:
            bridge: The JuliaBridge to use for communication with the Julia backend
            llm: The language model to use for developing trading strategies
            **kwargs: Additional arguments to pass to the JuliaOSChain constructor
        """
        super().__init__(bridge=bridge, **kwargs)
        self.llm = llm
    
    @property
    def input_keys(self) -> List[str]:
        """
        Get the input keys for the chain.
        
        Returns:
            List[str]: The input keys
        """
        return ["market", "timeframe", "strategy_description", "parameters"]
    
    @property
    def output_keys(self) -> List[str]:
        """
        Get the output keys for the chain.
        
        Returns:
            List[str]: The output keys
        """
        return ["strategy", "backtest_results", "analysis"]
    
    async def _acall(self, inputs: Dict[str, Any]) -> Dict[str, Any]:
        """
        Call the chain asynchronously.
        
        Args:
            inputs: The inputs to the chain
        
        Returns:
            Dict[str, Any]: The outputs from the chain
        """
        # Extract inputs
        market = inputs.get("market", "BTC/USDC")
        timeframe = inputs.get("timeframe", "1h")
        strategy_description = inputs.get("strategy_description", "")
        parameters = inputs.get("parameters", {})
        
        # Generate a trading strategy from the description
        strategy_prompt = PromptTemplate(
            input_variables=["market", "timeframe", "strategy_description"],
            template="""
            You are an expert in algorithmic trading. Given the following strategy description,
            develop a detailed trading strategy for the specified market and timeframe.
            
            Market: {market}
            Timeframe: {timeframe}
            Strategy Description: {strategy_description}
            
            Provide a detailed trading strategy, including entry and exit conditions, position sizing,
            risk management, and any indicators or signals to use.
            """
        )
        
        # Create an LLMChain to generate the strategy
        strategy_chain = LLMChain(llm=self.llm, prompt=strategy_prompt)
        
        # Generate the strategy
        strategy = await strategy_chain.arun(
            market=market,
            timeframe=timeframe,
            strategy_description=strategy_description
        )
        
        # Create and backtest the strategy
        backtest_result = await self.bridge.execute("Trading.backtest_strategy", [
            market,
            timeframe,
            strategy,
            parameters
        ])
        
        # Generate an analysis of the backtest results
        analysis_prompt = PromptTemplate(
            input_variables=["market", "timeframe", "strategy", "backtest_results"],
            template="""
            You are an expert in algorithmic trading. Given the following backtest results for a trading strategy,
            provide a detailed analysis of the strategy's performance.
            
            Market: {market}
            Timeframe: {timeframe}
            Strategy: {strategy}
            Backtest Results: {backtest_results}
            
            Provide a detailed analysis of the strategy's performance, including profitability, risk-adjusted returns,
            drawdowns, win rate, and any other relevant metrics. Also provide recommendations for improving the strategy.
            """
        )
        
        # Create an LLMChain to generate the analysis
        analysis_chain = LLMChain(llm=self.llm, prompt=analysis_prompt)
        
        # Generate the analysis
        analysis = await analysis_chain.arun(
            market=market,
            timeframe=timeframe,
            strategy=strategy,
            backtest_results=str(backtest_result)
        )
        
        # Return the results
        return {
            "strategy": strategy,
            "backtest_results": backtest_result,
            "analysis": analysis
        }
