"""
Portfolio management module for JuliaOS.

This module provides classes for portfolio management and rebalancing.
"""

from enum import Enum
from typing import Dict, List, Optional, Tuple, Union, Any
import numpy as np
from datetime import datetime
import json

from ..bridge import JuliaBridge


class RebalanceStrategy(str, Enum):
    """Portfolio rebalancing strategies."""
    EQUAL_WEIGHT = "equal_weight"
    MINIMUM_VARIANCE = "minimum_variance"
    MAXIMUM_SHARPE = "maximum_sharpe"
    RISK_PARITY = "risk_parity"
    MAXIMUM_RETURN = "maximum_return"
    MULTI_OBJECTIVE = "multi_objective"


class PortfolioAsset:
    """Asset in a portfolio."""
    
    def __init__(
        self,
        id: str,
        symbol: str,
        name: str,
        asset_type: str,
        current_price: float,
        historical_prices: List[float],
        current_weight: float = 0.0,
        min_weight: float = 0.0,
        max_weight: float = 1.0
    ):
        """
        Initialize a portfolio asset.
        
        Args:
            id: Unique identifier for the asset
            symbol: Trading symbol for the asset
            name: Human-readable name for the asset
            asset_type: Type of asset (e.g., "stock", "bond", "crypto")
            current_price: Current price of the asset
            historical_prices: Historical prices of the asset
            current_weight: Current weight of the asset in the portfolio
            min_weight: Minimum allowed weight for the asset
            max_weight: Maximum allowed weight for the asset
        """
        self.id = id
        self.symbol = symbol
        self.name = name
        self.asset_type = asset_type
        self.current_price = current_price
        self.historical_prices = historical_prices
        self.current_weight = current_weight
        self.min_weight = min_weight
        self.max_weight = max_weight
        
        # Calculate historical returns
        if len(historical_prices) > 1:
            self.historical_returns = [
                (historical_prices[i] / historical_prices[i-1]) - 1.0
                for i in range(1, len(historical_prices))
            ]
        else:
            self.historical_returns = []
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert the asset to a dictionary."""
        return {
            "id": self.id,
            "symbol": self.symbol,
            "name": self.name,
            "asset_type": self.asset_type,
            "current_price": self.current_price,
            "historical_prices": self.historical_prices,
            "current_weight": self.current_weight,
            "min_weight": self.min_weight,
            "max_weight": self.max_weight
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'PortfolioAsset':
        """Create an asset from a dictionary."""
        return cls(
            id=data["id"],
            symbol=data["symbol"],
            name=data["name"],
            asset_type=data["asset_type"],
            current_price=data["current_price"],
            historical_prices=data["historical_prices"],
            current_weight=data["current_weight"],
            min_weight=data["min_weight"],
            max_weight=data["max_weight"]
        )


class Portfolio:
    """Portfolio of assets."""
    
    def __init__(
        self,
        id: str,
        name: str,
        assets: List[PortfolioAsset],
        cash: float = 0.0
    ):
        """
        Initialize a portfolio.
        
        Args:
            id: Unique identifier for the portfolio
            name: Human-readable name for the portfolio
            assets: Assets in the portfolio
            cash: Cash in the portfolio
        """
        self.id = id
        self.name = name
        self.assets = assets
        self.cash = cash
        
        # Calculate total value
        self.total_value = sum(asset.current_price * asset.current_weight for asset in assets) + cash
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert the portfolio to a dictionary."""
        return {
            "id": self.id,
            "name": self.name,
            "assets": [asset.to_dict() for asset in self.assets],
            "cash": self.cash,
            "total_value": self.total_value
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'Portfolio':
        """Create a portfolio from a dictionary."""
        assets = [PortfolioAsset.from_dict(asset_data) for asset_data in data["assets"]]
        
        return cls(
            id=data["id"],
            name=data["name"],
            assets=assets,
            cash=data["cash"]
        )


class RebalanceResult:
    """Result of a portfolio rebalance."""
    
    def __init__(
        self,
        portfolio: Portfolio,
        new_weights: List[float],
        expected_return: float,
        expected_risk: float,
        sharpe_ratio: float,
        strategy: str,
        timestamp: datetime = None
    ):
        """
        Initialize a rebalance result.
        
        Args:
            portfolio: The portfolio that was rebalanced
            new_weights: New weights for the assets
            expected_return: Expected return of the portfolio with new weights
            expected_risk: Expected risk of the portfolio with new weights
            sharpe_ratio: Sharpe ratio of the portfolio with new weights
            strategy: Rebalancing strategy used
            timestamp: Time of the rebalance
        """
        self.portfolio = portfolio
        self.new_weights = new_weights
        self.expected_return = expected_return
        self.expected_risk = expected_risk
        self.sharpe_ratio = sharpe_ratio
        self.strategy = strategy
        self.timestamp = timestamp or datetime.now()
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert the rebalance result to a dictionary."""
        return {
            "portfolio": self.portfolio.to_dict(),
            "new_weights": self.new_weights,
            "expected_return": self.expected_return,
            "expected_risk": self.expected_risk,
            "sharpe_ratio": self.sharpe_ratio,
            "strategy": self.strategy,
            "timestamp": self.timestamp.isoformat()
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> 'RebalanceResult':
        """Create a rebalance result from a dictionary."""
        portfolio = Portfolio.from_dict(data["portfolio"])
        
        return cls(
            portfolio=portfolio,
            new_weights=data["new_weights"],
            expected_return=data["expected_return"],
            expected_risk=data["expected_risk"],
            sharpe_ratio=data["sharpe_ratio"],
            strategy=data["strategy"],
            timestamp=datetime.fromisoformat(data["timestamp"])
        )


class PortfolioRebalancer:
    """Portfolio rebalancer for JuliaOS."""
    
    def __init__(self, bridge: JuliaBridge):
        """
        Initialize a portfolio rebalancer.
        
        Args:
            bridge: JuliaBridge instance
        """
        self.bridge = bridge
    
    async def calculate_portfolio_metrics(
        self,
        assets: List[PortfolioAsset],
        weights: List[float]
    ) -> Dict[str, float]:
        """
        Calculate various metrics for a portfolio.
        
        Args:
            assets: Assets in the portfolio
            weights: Weights of the assets
        
        Returns:
            Dict: Dictionary of portfolio metrics
        """
        # Convert assets to Julia format
        julia_assets = [asset.to_dict() for asset in assets]
        
        result = await self.bridge.execute("Finance.calculate_portfolio_metrics", [
            julia_assets,
            weights
        ])
        
        return result
    
    async def calculate_optimal_weights(
        self,
        portfolio: Portfolio,
        strategy: RebalanceStrategy,
        params: Dict[str, Any] = None
    ) -> List[float]:
        """
        Calculate optimal weights for a portfolio based on a rebalancing strategy.
        
        Args:
            portfolio: The portfolio to rebalance
            strategy: Rebalancing strategy to use
            params: Additional parameters for the strategy
        
        Returns:
            List[float]: Optimal weights for the assets
        """
        if params is None:
            params = {}
        
        # Convert portfolio to Julia format
        julia_portfolio = portfolio.to_dict()
        
        result = await self.bridge.execute("Finance.calculate_optimal_weights", [
            julia_portfolio,
            strategy.value,
            params
        ])
        
        return result
    
    async def rebalance_portfolio(
        self,
        portfolio: Portfolio,
        strategy: RebalanceStrategy,
        params: Dict[str, Any] = None
    ) -> RebalanceResult:
        """
        Rebalance a portfolio based on a strategy.
        
        Args:
            portfolio: The portfolio to rebalance
            strategy: Rebalancing strategy to use
            params: Additional parameters for the strategy
        
        Returns:
            RebalanceResult: Result of the rebalance
        """
        if params is None:
            params = {}
        
        # Convert portfolio to Julia format
        julia_portfolio = portfolio.to_dict()
        
        result = await self.bridge.execute("Finance.rebalance_portfolio", [
            julia_portfolio,
            strategy.value,
            params
        ])
        
        # Convert result to Python format
        return RebalanceResult(
            portfolio=portfolio,
            new_weights=result["new_weights"],
            expected_return=result["expected_return"],
            expected_risk=result["expected_risk"],
            sharpe_ratio=result["sharpe_ratio"],
            strategy=result["strategy"],
            timestamp=datetime.fromisoformat(result["timestamp"])
        )
    
    async def apply_rebalance(
        self,
        portfolio: Portfolio,
        rebalance_result: RebalanceResult
    ) -> Portfolio:
        """
        Apply a rebalance result to a portfolio.
        
        Args:
            portfolio: The portfolio to apply the rebalance to
            rebalance_result: The rebalance result to apply
        
        Returns:
            Portfolio: The rebalanced portfolio
        """
        # Convert portfolio and rebalance result to Julia format
        julia_portfolio = portfolio.to_dict()
        julia_rebalance_result = rebalance_result.to_dict()
        
        result = await self.bridge.execute("Finance.apply_rebalance", [
            julia_portfolio,
            julia_rebalance_result
        ])
        
        # Convert result to Python format
        return Portfolio.from_dict(result)
