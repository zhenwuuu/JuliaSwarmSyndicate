"""
Advanced LangChain agent adapters for JuliaOS agents.

This module provides specialized adapter classes that convert JuliaOS agents to LangChain agents.
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
from .agents import JuliaOSAgentAdapter


class JuliaOSPortfolioAgentAdapter(JuliaOSAgentAdapter):
    """
    Adapter for JuliaOS portfolio management agents.
    
    This adapter specializes in adapting JuliaOS portfolio management agents to work with LangChain.
    """
    
    def __init__(self, agent: Agent):
        """
        Initialize the adapter with a JuliaOS portfolio agent.
        
        Args:
            agent: The JuliaOS portfolio agent to adapt
        """
        super().__init__(agent)
        
        # Verify that the agent is a portfolio agent
        if agent.agent_type != JuliaOSAgentType.PORTFOLIO:
            raise ValueError(f"Expected a portfolio agent, got {agent.agent_type}")
    
    def as_langchain_agent(
        self,
        llm: Optional[BaseLanguageModel] = None,
        tools: Optional[List[BaseTool]] = None,
        agent_type: AgentType = AgentType.STRUCTURED_CHAT_ZERO_SHOT_REACT_DESCRIPTION,
        **kwargs
    ) -> AgentExecutor:
        """
        Convert the JuliaOS portfolio agent to a LangChain agent.
        
        Args:
            llm: The language model to use for the agent
            tools: The tools available to the agent
            agent_type: The type of LangChain agent to create
            **kwargs: Additional arguments to pass to the agent
        
        Returns:
            AgentExecutor: A LangChain agent executor
        """
        # Use provided tools or create portfolio-specific tools
        if tools is None:
            from .tools import AgentTaskTool, BlockchainQueryTool, WalletOperationTool
            tools = [
                AgentTaskTool(agent=self.agent),
                BlockchainQueryTool(bridge=self.bridge),
                WalletOperationTool(bridge=self.bridge)
            ]
        
        # Create a portfolio-specific prompt template
        prompt_template = """
        You are a portfolio management agent that can analyze and optimize investment portfolios.
        
        {format_instructions}
        
        Use the following tools to accomplish your task:
        
        {tools}
        
        Task: {input}
        
        {agent_scratchpad}
        """
        
        # Create a custom prompt
        from langchain.prompts import ChatPromptTemplate
        prompt = ChatPromptTemplate.from_template(prompt_template)
        
        # Create and return the agent executor with portfolio-specific configuration
        return super().as_langchain_agent(
            llm=llm,
            tools=tools,
            agent_type=agent_type,
            prompt=prompt,
            **kwargs
        )


class JuliaOSMarketMakingAgentAdapter(JuliaOSAgentAdapter):
    """
    Adapter for JuliaOS market making agents.
    
    This adapter specializes in adapting JuliaOS market making agents to work with LangChain.
    """
    
    def __init__(self, agent: Agent):
        """
        Initialize the adapter with a JuliaOS market making agent.
        
        Args:
            agent: The JuliaOS market making agent to adapt
        """
        super().__init__(agent)
        
        # Verify that the agent is a market making agent
        if agent.agent_type != JuliaOSAgentType.MARKET_MAKING:
            raise ValueError(f"Expected a market making agent, got {agent.agent_type}")
    
    def as_langchain_agent(
        self,
        llm: Optional[BaseLanguageModel] = None,
        tools: Optional[List[BaseTool]] = None,
        agent_type: AgentType = AgentType.STRUCTURED_CHAT_ZERO_SHOT_REACT_DESCRIPTION,
        **kwargs
    ) -> AgentExecutor:
        """
        Convert the JuliaOS market making agent to a LangChain agent.
        
        Args:
            llm: The language model to use for the agent
            tools: The tools available to the agent
            agent_type: The type of LangChain agent to create
            **kwargs: Additional arguments to pass to the agent
        
        Returns:
            AgentExecutor: A LangChain agent executor
        """
        # Use provided tools or create market making-specific tools
        if tools is None:
            from .tools import AgentTaskTool, BlockchainQueryTool, WalletOperationTool
            tools = [
                AgentTaskTool(agent=self.agent),
                BlockchainQueryTool(bridge=self.bridge),
                WalletOperationTool(bridge=self.bridge)
            ]
        
        # Create a market making-specific prompt template
        prompt_template = """
        You are a market making agent that can provide liquidity to markets and execute trades.
        
        {format_instructions}
        
        Use the following tools to accomplish your task:
        
        {tools}
        
        Task: {input}
        
        {agent_scratchpad}
        """
        
        # Create a custom prompt
        from langchain.prompts import ChatPromptTemplate
        prompt = ChatPromptTemplate.from_template(prompt_template)
        
        # Create and return the agent executor with market making-specific configuration
        return super().as_langchain_agent(
            llm=llm,
            tools=tools,
            agent_type=agent_type,
            prompt=prompt,
            **kwargs
        )


class JuliaOSLiquidityAgentAdapter(JuliaOSAgentAdapter):
    """
    Adapter for JuliaOS liquidity provider agents.
    
    This adapter specializes in adapting JuliaOS liquidity provider agents to work with LangChain.
    """
    
    def __init__(self, agent: Agent):
        """
        Initialize the adapter with a JuliaOS liquidity agent.
        
        Args:
            agent: The JuliaOS liquidity agent to adapt
        """
        super().__init__(agent)
        
        # Verify that the agent is a liquidity agent
        if agent.agent_type != JuliaOSAgentType.LIQUIDITY:
            raise ValueError(f"Expected a liquidity agent, got {agent.agent_type}")
    
    def as_langchain_agent(
        self,
        llm: Optional[BaseLanguageModel] = None,
        tools: Optional[List[BaseTool]] = None,
        agent_type: AgentType = AgentType.STRUCTURED_CHAT_ZERO_SHOT_REACT_DESCRIPTION,
        **kwargs
    ) -> AgentExecutor:
        """
        Convert the JuliaOS liquidity agent to a LangChain agent.
        
        Args:
            llm: The language model to use for the agent
            tools: The tools available to the agent
            agent_type: The type of LangChain agent to create
            **kwargs: Additional arguments to pass to the agent
        
        Returns:
            AgentExecutor: A LangChain agent executor
        """
        # Use provided tools or create liquidity-specific tools
        if tools is None:
            from .tools import AgentTaskTool, BlockchainQueryTool, WalletOperationTool
            tools = [
                AgentTaskTool(agent=self.agent),
                BlockchainQueryTool(bridge=self.bridge),
                WalletOperationTool(bridge=self.bridge)
            ]
        
        # Create a liquidity-specific prompt template
        prompt_template = """
        You are a liquidity provider agent that can provide liquidity to DEXs and manage liquidity positions.
        
        {format_instructions}
        
        Use the following tools to accomplish your task:
        
        {tools}
        
        Task: {input}
        
        {agent_scratchpad}
        """
        
        # Create a custom prompt
        from langchain.prompts import ChatPromptTemplate
        prompt = ChatPromptTemplate.from_template(prompt_template)
        
        # Create and return the agent executor with liquidity-specific configuration
        return super().as_langchain_agent(
            llm=llm,
            tools=tools,
            agent_type=agent_type,
            prompt=prompt,
            **kwargs
        )


class JuliaOSYieldFarmingAgentAdapter(JuliaOSAgentAdapter):
    """
    Adapter for JuliaOS yield farming agents.
    
    This adapter specializes in adapting JuliaOS yield farming agents to work with LangChain.
    """
    
    def __init__(self, agent: Agent):
        """
        Initialize the adapter with a JuliaOS yield farming agent.
        
        Args:
            agent: The JuliaOS yield farming agent to adapt
        """
        super().__init__(agent)
        
        # Verify that the agent is a yield farming agent
        if agent.agent_type != JuliaOSAgentType.YIELD_FARMING:
            raise ValueError(f"Expected a yield farming agent, got {agent.agent_type}")
    
    def as_langchain_agent(
        self,
        llm: Optional[BaseLanguageModel] = None,
        tools: Optional[List[BaseTool]] = None,
        agent_type: AgentType = AgentType.STRUCTURED_CHAT_ZERO_SHOT_REACT_DESCRIPTION,
        **kwargs
    ) -> AgentExecutor:
        """
        Convert the JuliaOS yield farming agent to a LangChain agent.
        
        Args:
            llm: The language model to use for the agent
            tools: The tools available to the agent
            agent_type: The type of LangChain agent to create
            **kwargs: Additional arguments to pass to the agent
        
        Returns:
            AgentExecutor: A LangChain agent executor
        """
        # Use provided tools or create yield farming-specific tools
        if tools is None:
            from .tools import AgentTaskTool, BlockchainQueryTool, WalletOperationTool
            tools = [
                AgentTaskTool(agent=self.agent),
                BlockchainQueryTool(bridge=self.bridge),
                WalletOperationTool(bridge=self.bridge)
            ]
        
        # Create a yield farming-specific prompt template
        prompt_template = """
        You are a yield farming agent that can identify and execute yield farming opportunities.
        
        {format_instructions}
        
        Use the following tools to accomplish your task:
        
        {tools}
        
        Task: {input}
        
        {agent_scratchpad}
        """
        
        # Create a custom prompt
        from langchain.prompts import ChatPromptTemplate
        prompt = ChatPromptTemplate.from_template(prompt_template)
        
        # Create and return the agent executor with yield farming-specific configuration
        return super().as_langchain_agent(
            llm=llm,
            tools=tools,
            agent_type=agent_type,
            prompt=prompt,
            **kwargs
        )


class JuliaOSCrossChainAgentAdapter(JuliaOSAgentAdapter):
    """
    Adapter for JuliaOS cross-chain agents.
    
    This adapter specializes in adapting JuliaOS cross-chain agents to work with LangChain.
    """
    
    def __init__(self, agent: Agent):
        """
        Initialize the adapter with a JuliaOS cross-chain agent.
        
        Args:
            agent: The JuliaOS cross-chain agent to adapt
        """
        super().__init__(agent)
        
        # Verify that the agent is a cross-chain agent
        if agent.agent_type != JuliaOSAgentType.CROSS_CHAIN:
            raise ValueError(f"Expected a cross-chain agent, got {agent.agent_type}")
    
    def as_langchain_agent(
        self,
        llm: Optional[BaseLanguageModel] = None,
        tools: Optional[List[BaseTool]] = None,
        agent_type: AgentType = AgentType.STRUCTURED_CHAT_ZERO_SHOT_REACT_DESCRIPTION,
        **kwargs
    ) -> AgentExecutor:
        """
        Convert the JuliaOS cross-chain agent to a LangChain agent.
        
        Args:
            llm: The language model to use for the agent
            tools: The tools available to the agent
            agent_type: The type of LangChain agent to create
            **kwargs: Additional arguments to pass to the agent
        
        Returns:
            AgentExecutor: A LangChain agent executor
        """
        # Use provided tools or create cross-chain-specific tools
        if tools is None:
            from .tools import AgentTaskTool, BlockchainQueryTool, WalletOperationTool
            tools = [
                AgentTaskTool(agent=self.agent),
                BlockchainQueryTool(bridge=self.bridge),
                WalletOperationTool(bridge=self.bridge)
            ]
        
        # Create a cross-chain-specific prompt template
        prompt_template = """
        You are a cross-chain agent that can execute operations across multiple blockchains.
        
        {format_instructions}
        
        Use the following tools to accomplish your task:
        
        {tools}
        
        Task: {input}
        
        {agent_scratchpad}
        """
        
        # Create a custom prompt
        from langchain.prompts import ChatPromptTemplate
        prompt = ChatPromptTemplate.from_template(prompt_template)
        
        # Create and return the agent executor with cross-chain-specific configuration
        return super().as_langchain_agent(
            llm=llm,
            tools=tools,
            agent_type=agent_type,
            prompt=prompt,
            **kwargs
        )
