"""
LangChain agent adapters for JuliaOS agents.

This module provides adapter classes that convert JuliaOS agents to LangChain agents.
"""

from typing import Dict, Any, List, Optional, Union, Callable, Type
import asyncio
from pydantic import BaseModel, Field

from langchain.agents import AgentExecutor, AgentType
from langchain.agents.agent import AgentOutputParser
from langchain.schema import AgentAction, AgentFinish
from langchain.prompts import PromptTemplate
from langchain.tools import BaseTool
from langchain_core.language_models import BaseLanguageModel

from ..agents import Agent, AgentType as JuliaOSAgentType
from ..bridge import JuliaBridge


class JuliaOSAgentAdapter:
    """
    Base adapter class for converting JuliaOS agents to LangChain agents.
    
    This class provides the basic functionality for adapting JuliaOS agents
    to work with LangChain.
    """
    
    def __init__(self, agent: Agent):
        """
        Initialize the adapter with a JuliaOS agent.
        
        Args:
            agent: The JuliaOS agent to adapt
        """
        self.agent = agent
        self.bridge = agent.bridge
    
    async def execute_task(self, task: Dict[str, Any]) -> Dict[str, Any]:
        """
        Execute a task on the JuliaOS agent.
        
        Args:
            task: The task to execute
        
        Returns:
            Dict[str, Any]: The result of the task
        """
        return await self.agent.execute_task(task)
    
    def as_langchain_agent(
        self,
        llm: Optional[BaseLanguageModel] = None,
        tools: Optional[List[BaseTool]] = None,
        agent_type: AgentType = AgentType.STRUCTURED_CHAT_ZERO_SHOT_REACT_DESCRIPTION,
        **kwargs
    ) -> AgentExecutor:
        """
        Convert the JuliaOS agent to a LangChain agent.
        
        Args:
            llm: The language model to use for the agent
            tools: The tools available to the agent
            agent_type: The type of LangChain agent to create
            **kwargs: Additional arguments to pass to the agent
        
        Returns:
            AgentExecutor: A LangChain agent executor
        """
        from langchain.agents import initialize_agent
        
        # Use provided tools or create default tools
        if tools is None:
            from .tools import AgentTaskTool
            tools = [AgentTaskTool(agent=self.agent)]
        
        # Create and return the agent executor
        return initialize_agent(
            tools=tools,
            llm=llm,
            agent=agent_type,
            verbose=kwargs.get("verbose", True),
            handle_parsing_errors=kwargs.get("handle_parsing_errors", True),
            **kwargs
        )


class JuliaOSTradingAgentAdapter(JuliaOSAgentAdapter):
    """
    Adapter for JuliaOS trading agents.
    
    This adapter specializes in adapting JuliaOS trading agents to work with LangChain.
    """
    
    def __init__(self, agent: Agent):
        """
        Initialize the adapter with a JuliaOS trading agent.
        
        Args:
            agent: The JuliaOS trading agent to adapt
        """
        super().__init__(agent)
        
        # Verify that the agent is a trading agent
        if agent.agent_type != JuliaOSAgentType.TRADING:
            raise ValueError(f"Expected a trading agent, got {agent.agent_type}")
    
    def as_langchain_agent(
        self,
        llm: Optional[BaseLanguageModel] = None,
        tools: Optional[List[BaseTool]] = None,
        agent_type: AgentType = AgentType.STRUCTURED_CHAT_ZERO_SHOT_REACT_DESCRIPTION,
        **kwargs
    ) -> AgentExecutor:
        """
        Convert the JuliaOS trading agent to a LangChain agent.
        
        Args:
            llm: The language model to use for the agent
            tools: The tools available to the agent
            agent_type: The type of LangChain agent to create
            **kwargs: Additional arguments to pass to the agent
        
        Returns:
            AgentExecutor: A LangChain agent executor
        """
        # Use provided tools or create trading-specific tools
        if tools is None:
            from .tools import AgentTaskTool, BlockchainQueryTool, WalletOperationTool
            tools = [
                AgentTaskTool(agent=self.agent),
                BlockchainQueryTool(bridge=self.bridge),
                WalletOperationTool(bridge=self.bridge)
            ]
        
        # Create a trading-specific prompt template
        prompt_template = """
        You are a trading agent that can analyze markets and execute trades.
        
        {format_instructions}
        
        Use the following tools to accomplish your task:
        
        {tools}
        
        Task: {input}
        
        {agent_scratchpad}
        """
        
        # Create a custom prompt
        from langchain.prompts import ChatPromptTemplate
        prompt = ChatPromptTemplate.from_template(prompt_template)
        
        # Create and return the agent executor with trading-specific configuration
        return super().as_langchain_agent(
            llm=llm,
            tools=tools,
            agent_type=agent_type,
            prompt=prompt,
            **kwargs
        )


class JuliaOSMonitorAgentAdapter(JuliaOSAgentAdapter):
    """
    Adapter for JuliaOS monitor agents.
    
    This adapter specializes in adapting JuliaOS monitor agents to work with LangChain.
    """
    
    def __init__(self, agent: Agent):
        """
        Initialize the adapter with a JuliaOS monitor agent.
        
        Args:
            agent: The JuliaOS monitor agent to adapt
        """
        super().__init__(agent)
        
        # Verify that the agent is a monitor agent
        if agent.agent_type != JuliaOSAgentType.MONITOR:
            raise ValueError(f"Expected a monitor agent, got {agent.agent_type}")
    
    def as_langchain_agent(
        self,
        llm: Optional[BaseLanguageModel] = None,
        tools: Optional[List[BaseTool]] = None,
        agent_type: AgentType = AgentType.STRUCTURED_CHAT_ZERO_SHOT_REACT_DESCRIPTION,
        **kwargs
    ) -> AgentExecutor:
        """
        Convert the JuliaOS monitor agent to a LangChain agent.
        
        Args:
            llm: The language model to use for the agent
            tools: The tools available to the agent
            agent_type: The type of LangChain agent to create
            **kwargs: Additional arguments to pass to the agent
        
        Returns:
            AgentExecutor: A LangChain agent executor
        """
        # Use provided tools or create monitor-specific tools
        if tools is None:
            from .tools import AgentTaskTool, BlockchainQueryTool
            tools = [
                AgentTaskTool(agent=self.agent),
                BlockchainQueryTool(bridge=self.bridge)
            ]
        
        # Create a monitor-specific prompt template
        prompt_template = """
        You are a monitoring agent that can track blockchain activity and market conditions.
        
        {format_instructions}
        
        Use the following tools to accomplish your task:
        
        {tools}
        
        Task: {input}
        
        {agent_scratchpad}
        """
        
        # Create a custom prompt
        from langchain.prompts import ChatPromptTemplate
        prompt = ChatPromptTemplate.from_template(prompt_template)
        
        # Create and return the agent executor with monitor-specific configuration
        return super().as_langchain_agent(
            llm=llm,
            tools=tools,
            agent_type=agent_type,
            prompt=prompt,
            **kwargs
        )


class JuliaOSArbitrageAgentAdapter(JuliaOSAgentAdapter):
    """
    Adapter for JuliaOS arbitrage agents.
    
    This adapter specializes in adapting JuliaOS arbitrage agents to work with LangChain.
    """
    
    def __init__(self, agent: Agent):
        """
        Initialize the adapter with a JuliaOS arbitrage agent.
        
        Args:
            agent: The JuliaOS arbitrage agent to adapt
        """
        super().__init__(agent)
        
        # Verify that the agent is an arbitrage agent
        if agent.agent_type != JuliaOSAgentType.ARBITRAGE:
            raise ValueError(f"Expected an arbitrage agent, got {agent.agent_type}")
    
    def as_langchain_agent(
        self,
        llm: Optional[BaseLanguageModel] = None,
        tools: Optional[List[BaseTool]] = None,
        agent_type: AgentType = AgentType.STRUCTURED_CHAT_ZERO_SHOT_REACT_DESCRIPTION,
        **kwargs
    ) -> AgentExecutor:
        """
        Convert the JuliaOS arbitrage agent to a LangChain agent.
        
        Args:
            llm: The language model to use for the agent
            tools: The tools available to the agent
            agent_type: The type of LangChain agent to create
            **kwargs: Additional arguments to pass to the agent
        
        Returns:
            AgentExecutor: A LangChain agent executor
        """
        # Use provided tools or create arbitrage-specific tools
        if tools is None:
            from .tools import AgentTaskTool, BlockchainQueryTool, WalletOperationTool
            tools = [
                AgentTaskTool(agent=self.agent),
                BlockchainQueryTool(bridge=self.bridge),
                WalletOperationTool(bridge=self.bridge)
            ]
        
        # Create an arbitrage-specific prompt template
        prompt_template = """
        You are an arbitrage agent that can identify and execute cross-chain and cross-DEX arbitrage opportunities.
        
        {format_instructions}
        
        Use the following tools to accomplish your task:
        
        {tools}
        
        Task: {input}
        
        {agent_scratchpad}
        """
        
        # Create a custom prompt
        from langchain.prompts import ChatPromptTemplate
        prompt = ChatPromptTemplate.from_template(prompt_template)
        
        # Create and return the agent executor with arbitrage-specific configuration
        return super().as_langchain_agent(
            llm=llm,
            tools=tools,
            agent_type=agent_type,
            prompt=prompt,
            **kwargs
        )
