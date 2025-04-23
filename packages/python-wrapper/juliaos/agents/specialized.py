"""
Specialized agent classes for the JuliaOS Python wrapper.
"""

from typing import Dict, Any, List, Optional, Union

from ..bridge import JuliaBridge
from ..exceptions import AgentError
from .agent import Agent


class TradingAgent(Agent):
    """
    Trading agent class.
    
    This class provides methods for interacting with a trading agent in the JuliaOS Framework.
    """
    
    async def initialize(self) -> Dict[str, Any]:
        """
        Initialize the trading agent.
        
        Returns:
            Dict[str, Any]: Initialization result
        
        Raises:
            AgentError: If initialization fails
        """
        try:
            result = await self.bridge.execute("TradingAgent.initialize", [self.id])
            
            if not result.get("success", False):
                raise AgentError(f"Failed to initialize trading agent: {result.get('error', 'Unknown error')}")
            
            return result
        except Exception as e:
            if not isinstance(e, AgentError):
                raise AgentError(f"Error initializing trading agent: {e}")
            raise
    
    async def execute_trade(self, trade_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Execute a trade.
        
        Args:
            trade_data: Trade data
        
        Returns:
            Dict[str, Any]: Trade execution result
        
        Raises:
            AgentError: If trade execution fails
        """
        try:
            result = await self.bridge.execute("TradingAgent.execute_trade", [self.id, trade_data])
            
            if not result.get("success", False):
                raise AgentError(f"Failed to execute trade: {result.get('error', 'Unknown error')}")
            
            return result
        except Exception as e:
            if not isinstance(e, AgentError):
                raise AgentError(f"Error executing trade: {e}")
            raise
    
    async def analyze_market(self, market_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Analyze market data.
        
        Args:
            market_data: Market data
        
        Returns:
            Dict[str, Any]: Analysis result
        
        Raises:
            AgentError: If market analysis fails
        """
        try:
            result = await self.bridge.execute("TradingAgent.analyze_market", [self.id, market_data])
            
            if not result.get("success", False):
                raise AgentError(f"Failed to analyze market: {result.get('error', 'Unknown error')}")
            
            return result
        except Exception as e:
            if not isinstance(e, AgentError):
                raise AgentError(f"Error analyzing market: {e}")
            raise
    
    async def get_portfolio(self) -> Dict[str, Any]:
        """
        Get portfolio information.
        
        Returns:
            Dict[str, Any]: Portfolio information
        
        Raises:
            AgentError: If portfolio retrieval fails
        """
        try:
            result = await self.bridge.execute("TradingAgent.get_portfolio", [self.id])
            
            if not result.get("success", False):
                raise AgentError(f"Failed to get portfolio: {result.get('error', 'Unknown error')}")
            
            return result
        except Exception as e:
            if not isinstance(e, AgentError):
                raise AgentError(f"Error retrieving portfolio: {e}")
            raise
    
    async def set_strategy(self, strategy: str, config: Dict[str, Any] = None) -> Dict[str, Any]:
        """
        Set trading strategy.
        
        Args:
            strategy: Strategy name
            config: Strategy configuration
        
        Returns:
            Dict[str, Any]: Strategy setting result
        
        Raises:
            AgentError: If strategy setting fails
        """
        try:
            result = await self.bridge.execute("TradingAgent.set_strategy", [
                self.id,
                strategy,
                config or {}
            ])
            
            if not result.get("success", False):
                raise AgentError(f"Failed to set strategy: {result.get('error', 'Unknown error')}")
            
            return result
        except Exception as e:
            if not isinstance(e, AgentError):
                raise AgentError(f"Error setting strategy: {e}")
            raise


class MonitorAgent(Agent):
    """
    Monitor agent class.
    
    This class provides methods for interacting with a monitor agent in the JuliaOS Framework.
    """
    
    async def initialize(self) -> Dict[str, Any]:
        """
        Initialize the monitor agent.
        
        Returns:
            Dict[str, Any]: Initialization result
        
        Raises:
            AgentError: If initialization fails
        """
        try:
            result = await self.bridge.execute("MonitorAgent.initialize", [self.id])
            
            if not result.get("success", False):
                raise AgentError(f"Failed to initialize monitor agent: {result.get('error', 'Unknown error')}")
            
            return result
        except Exception as e:
            if not isinstance(e, AgentError):
                raise AgentError(f"Error initializing monitor agent: {e}")
            raise
    
    async def configure_alerts(self, alert_configs: List[Dict[str, Any]]) -> Dict[str, Any]:
        """
        Configure alerts.
        
        Args:
            alert_configs: Alert configurations
        
        Returns:
            Dict[str, Any]: Alert configuration result
        
        Raises:
            AgentError: If alert configuration fails
        """
        try:
            result = await self.bridge.execute("MonitorAgent.configure_alerts", [self.id, alert_configs])
            
            if not result.get("success", False):
                raise AgentError(f"Failed to configure alerts: {result.get('error', 'Unknown error')}")
            
            return result
        except Exception as e:
            if not isinstance(e, AgentError):
                raise AgentError(f"Error configuring alerts: {e}")
            raise
    
    async def check_conditions(self, market_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Check alert conditions against market data.
        
        Args:
            market_data: Market data
        
        Returns:
            Dict[str, Any]: Check result
        
        Raises:
            AgentError: If condition checking fails
        """
        try:
            result = await self.bridge.execute("MonitorAgent.check_conditions", [self.id, market_data])
            
            if not result.get("success", False):
                raise AgentError(f"Failed to check conditions: {result.get('error', 'Unknown error')}")
            
            return result
        except Exception as e:
            if not isinstance(e, AgentError):
                raise AgentError(f"Error checking conditions: {e}")
            raise
    
    async def get_alerts(self) -> Dict[str, Any]:
        """
        Get active alerts.
        
        Returns:
            Dict[str, Any]: Active alerts
        
        Raises:
            AgentError: If alert retrieval fails
        """
        try:
            result = await self.bridge.execute("MonitorAgent.get_alerts", [self.id])
            
            if not result.get("success", False):
                raise AgentError(f"Failed to get alerts: {result.get('error', 'Unknown error')}")
            
            return result
        except Exception as e:
            if not isinstance(e, AgentError):
                raise AgentError(f"Error retrieving alerts: {e}")
            raise
    
    async def get_alert_history(self) -> Dict[str, Any]:
        """
        Get alert history.
        
        Returns:
            Dict[str, Any]: Alert history
        
        Raises:
            AgentError: If alert history retrieval fails
        """
        try:
            result = await self.bridge.execute("MonitorAgent.get_alert_history", [self.id])
            
            if not result.get("success", False):
                raise AgentError(f"Failed to get alert history: {result.get('error', 'Unknown error')}")
            
            return result
        except Exception as e:
            if not isinstance(e, AgentError):
                raise AgentError(f"Error retrieving alert history: {e}")
            raise


class ArbitrageAgent(Agent):
    """
    Arbitrage agent class.
    
    This class provides methods for interacting with an arbitrage agent in the JuliaOS Framework.
    """
    
    async def initialize(self) -> Dict[str, Any]:
        """
        Initialize the arbitrage agent.
        
        Returns:
            Dict[str, Any]: Initialization result
        
        Raises:
            AgentError: If initialization fails
        """
        try:
            result = await self.bridge.execute("ArbitrageAgent.initialize", [self.id])
            
            if not result.get("success", False):
                raise AgentError(f"Failed to initialize arbitrage agent: {result.get('error', 'Unknown error')}")
            
            return result
        except Exception as e:
            if not isinstance(e, AgentError):
                raise AgentError(f"Error initializing arbitrage agent: {e}")
            raise
    
    async def find_opportunities(self, market_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Find arbitrage opportunities.
        
        Args:
            market_data: Market data
        
        Returns:
            Dict[str, Any]: Opportunities found
        
        Raises:
            AgentError: If opportunity finding fails
        """
        try:
            result = await self.bridge.execute("ArbitrageAgent.find_opportunities", [self.id, market_data])
            
            if not result.get("success", False):
                raise AgentError(f"Failed to find opportunities: {result.get('error', 'Unknown error')}")
            
            return result
        except Exception as e:
            if not isinstance(e, AgentError):
                raise AgentError(f"Error finding opportunities: {e}")
            raise
    
    async def execute_arbitrage(self, opportunity_id: str) -> Dict[str, Any]:
        """
        Execute an arbitrage opportunity.
        
        Args:
            opportunity_id: Opportunity ID
        
        Returns:
            Dict[str, Any]: Execution result
        
        Raises:
            AgentError: If arbitrage execution fails
        """
        try:
            result = await self.bridge.execute("ArbitrageAgent.execute_arbitrage", [self.id, opportunity_id])
            
            if not result.get("success", False):
                raise AgentError(f"Failed to execute arbitrage: {result.get('error', 'Unknown error')}")
            
            return result
        except Exception as e:
            if not isinstance(e, AgentError):
                raise AgentError(f"Error executing arbitrage: {e}")
            raise
    
    async def get_history(self) -> Dict[str, Any]:
        """
        Get arbitrage history.
        
        Returns:
            Dict[str, Any]: Arbitrage history
        
        Raises:
            AgentError: If history retrieval fails
        """
        try:
            result = await self.bridge.execute("ArbitrageAgent.get_history", [self.id])
            
            if not result.get("success", False):
                raise AgentError(f"Failed to get history: {result.get('error', 'Unknown error')}")
            
            return result
        except Exception as e:
            if not isinstance(e, AgentError):
                raise AgentError(f"Error retrieving history: {e}")
            raise
    
    async def set_parameters(self, parameters: Dict[str, Any]) -> Dict[str, Any]:
        """
        Set arbitrage parameters.
        
        Args:
            parameters: Arbitrage parameters
        
        Returns:
            Dict[str, Any]: Parameter setting result
        
        Raises:
            AgentError: If parameter setting fails
        """
        try:
            result = await self.bridge.execute("ArbitrageAgent.set_parameters", [self.id, parameters])
            
            if not result.get("success", False):
                raise AgentError(f"Failed to set parameters: {result.get('error', 'Unknown error')}")
            
            return result
        except Exception as e:
            if not isinstance(e, AgentError):
                raise AgentError(f"Error setting parameters: {e}")
            raise
