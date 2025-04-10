"""
Google ADK adapter for JuliaOS.

This module provides the adapter class for integrating JuliaOS with Google ADK.
"""

from typing import Dict, Any, List, Optional, Union, Callable
import asyncio
import json

from ..bridge import JuliaBridge
from ..agents import Agent
from ..swarms import Swarm

try:
    from google.agent.sdk import Agent as ADKAgent
    from google.agent.sdk import Tool as ADKTool
    from google.agent.sdk import Memory as ADKMemory
    from google.agent.sdk import AgentConfig
    ADK_AVAILABLE = True
except ImportError:
    ADK_AVAILABLE = False
    # Create placeholder classes for type hints
    class ADKAgent:
        pass
    
    class ADKTool:
        pass
    
    class ADKMemory:
        pass
    
    class AgentConfig:
        pass


class JuliaOSADKAdapter:
    """
    Adapter for integrating JuliaOS with Google ADK.
    """
    
    def __init__(self, bridge: Optional[JuliaBridge] = None):
        """
        Initialize the adapter.
        
        Args:
            bridge: JuliaBridge instance for communicating with the Julia backend
        """
        if not ADK_AVAILABLE:
            raise ImportError(
                "Google Agent Development Kit (ADK) is not installed. "
                "Install it with 'pip install google-agent-sdk' or "
                "'pip install juliaos[adk]'."
            )
        
        self.bridge = bridge
    
    def agent_to_adk(self, agent: Agent) -> ADKAgent:
        """
        Convert a JuliaOS agent to a Google ADK agent.
        
        Args:
            agent: JuliaOS agent to convert
        
        Returns:
            ADKAgent: Google ADK agent
        """
        from .agent import JuliaOSADKAgent
        
        # Create an ADK agent config
        config = AgentConfig(
            name=agent.name,
            description=f"JuliaOS {agent.agent_type} agent",
            model="gemini-pro",  # Default model, can be overridden
            tools=self._get_tools_for_agent(agent)
        )
        
        # Create and return the ADK agent
        return JuliaOSADKAgent(agent, config)
    
    def swarm_to_adk(self, swarm: Swarm) -> List[ADKAgent]:
        """
        Convert a JuliaOS swarm to a list of Google ADK agents.
        
        Args:
            swarm: JuliaOS swarm to convert
        
        Returns:
            List[ADKAgent]: List of Google ADK agents
        """
        adk_agents = []
        
        # Convert each agent in the swarm to an ADK agent
        for agent_id in swarm.get_agents():
            agent = swarm.get_agent(agent_id)
            adk_agent = self.agent_to_adk(agent)
            adk_agents.append(adk_agent)
        
        return adk_agents
    
    def _get_tools_for_agent(self, agent: Agent) -> List[ADKTool]:
        """
        Get the ADK tools for a JuliaOS agent.
        
        Args:
            agent: JuliaOS agent
        
        Returns:
            List[ADKTool]: List of ADK tools
        """
        from .tool import JuliaOSADKTool
        
        tools = []
        
        # Add tools based on agent type and capabilities
        if agent.agent_type == "TRADING":
            tools.append(JuliaOSADKTool(
                name="execute_trade",
                description="Execute a trade on a specified exchange",
                function=self._execute_trade_function(agent)
            ))
            tools.append(JuliaOSADKTool(
                name="get_market_data",
                description="Get market data for a specified trading pair",
                function=self._get_market_data_function(agent)
            ))
        elif agent.agent_type == "MONITOR":
            tools.append(JuliaOSADKTool(
                name="monitor_price",
                description="Monitor the price of a specified asset",
                function=self._monitor_price_function(agent)
            ))
        elif agent.agent_type == "ARBITRAGE":
            tools.append(JuliaOSADKTool(
                name="find_arbitrage_opportunities",
                description="Find arbitrage opportunities across exchanges",
                function=self._find_arbitrage_function(agent)
            ))
        
        # Add general tools available to all agents
        tools.append(JuliaOSADKTool(
            name="send_message",
            description="Send a message to another agent",
            function=self._send_message_function(agent)
        ))
        
        return tools
    
    def _execute_trade_function(self, agent: Agent) -> Callable:
        """
        Create a function for executing trades.
        
        Args:
            agent: JuliaOS agent
        
        Returns:
            Callable: Function for executing trades
        """
        async def execute_trade(
            trading_pair: str,
            side: str,
            amount: float,
            price: Optional[float] = None,
            order_type: str = "market"
        ) -> Dict[str, Any]:
            """
            Execute a trade on a specified exchange.
            
            Args:
                trading_pair: Trading pair (e.g., "BTC/USDT")
                side: Trade side ("buy" or "sell")
                amount: Amount to trade
                price: Price for limit orders
                order_type: Order type ("market" or "limit")
            
            Returns:
                Dict[str, Any]: Trade result
            """
            result = await agent.execute_task("execute_trade", {
                "trading_pair": trading_pair,
                "side": side,
                "amount": amount,
                "price": price,
                "order_type": order_type
            })
            
            return result
        
        return execute_trade
    
    def _get_market_data_function(self, agent: Agent) -> Callable:
        """
        Create a function for getting market data.
        
        Args:
            agent: JuliaOS agent
        
        Returns:
            Callable: Function for getting market data
        """
        async def get_market_data(
            trading_pair: str,
            timeframe: str = "1h",
            limit: int = 100
        ) -> Dict[str, Any]:
            """
            Get market data for a specified trading pair.
            
            Args:
                trading_pair: Trading pair (e.g., "BTC/USDT")
                timeframe: Timeframe (e.g., "1m", "5m", "1h", "1d")
                limit: Number of candles to retrieve
            
            Returns:
                Dict[str, Any]: Market data
            """
            result = await agent.execute_task("get_market_data", {
                "trading_pair": trading_pair,
                "timeframe": timeframe,
                "limit": limit
            })
            
            return result
        
        return get_market_data
    
    def _monitor_price_function(self, agent: Agent) -> Callable:
        """
        Create a function for monitoring prices.
        
        Args:
            agent: JuliaOS agent
        
        Returns:
            Callable: Function for monitoring prices
        """
        async def monitor_price(
            asset: str,
            threshold: float,
            comparison: str = "above"
        ) -> Dict[str, Any]:
            """
            Monitor the price of a specified asset.
            
            Args:
                asset: Asset to monitor (e.g., "BTC")
                threshold: Price threshold
                comparison: Comparison type ("above" or "below")
            
            Returns:
                Dict[str, Any]: Monitoring result
            """
            result = await agent.execute_task("monitor_price", {
                "asset": asset,
                "threshold": threshold,
                "comparison": comparison
            })
            
            return result
        
        return monitor_price
    
    def _find_arbitrage_function(self, agent: Agent) -> Callable:
        """
        Create a function for finding arbitrage opportunities.
        
        Args:
            agent: JuliaOS agent
        
        Returns:
            Callable: Function for finding arbitrage opportunities
        """
        async def find_arbitrage_opportunities(
            asset: str,
            exchanges: List[str],
            min_profit_percentage: float = 0.5
        ) -> Dict[str, Any]:
            """
            Find arbitrage opportunities across exchanges.
            
            Args:
                asset: Asset to find arbitrage for (e.g., "BTC")
                exchanges: List of exchanges to check
                min_profit_percentage: Minimum profit percentage
            
            Returns:
                Dict[str, Any]: Arbitrage opportunities
            """
            result = await agent.execute_task("find_arbitrage", {
                "asset": asset,
                "exchanges": exchanges,
                "min_profit_percentage": min_profit_percentage
            })
            
            return result
        
        return find_arbitrage_opportunities
    
    def _send_message_function(self, agent: Agent) -> Callable:
        """
        Create a function for sending messages.
        
        Args:
            agent: JuliaOS agent
        
        Returns:
            Callable: Function for sending messages
        """
        async def send_message(
            recipient_id: str,
            message: str,
            metadata: Optional[Dict[str, Any]] = None
        ) -> Dict[str, Any]:
            """
            Send a message to another agent.
            
            Args:
                recipient_id: ID of the recipient agent
                message: Message content
                metadata: Additional metadata
            
            Returns:
                Dict[str, Any]: Message sending result
            """
            result = await agent.execute_task("send_message", {
                "recipient_id": recipient_id,
                "message": message,
                "metadata": metadata or {}
            })
            
            return result
        
        return send_message
