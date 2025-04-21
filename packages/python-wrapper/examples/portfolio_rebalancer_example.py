"""
Example script demonstrating the use of the portfolio rebalancer in JuliaOS.

This script shows how to create, analyze, and rebalance portfolios.
"""

import asyncio
import numpy as np
import matplotlib.pyplot as plt
from datetime import datetime
import random

from juliaos import JuliaOS
from juliaos.finance import PortfolioAsset, Portfolio, RebalanceStrategy, PortfolioRebalancer


def generate_random_asset(
    id, symbol, name, asset_type,
    min_weight=0.0, max_weight=1.0
):
    """
    Generate a random asset for testing.
    
    Args:
        id: Unique identifier for the asset
        symbol: Trading symbol for the asset
        name: Human-readable name for the asset
        asset_type: Type of asset (e.g., "stock", "bond", "crypto")
        min_weight: Minimum allowed weight for the asset
        max_weight: Maximum allowed weight for the asset
    
    Returns:
        PortfolioAsset: The generated asset
    """
    # Generate random current price
    current_price = 10.0 + 90.0 * random.random()
    
    # Generate random historical prices (with trend and volatility)
    n_periods = 252  # One year of daily data
    
    # Random trend and volatility
    trend = -0.2 + 0.4 * random.random()  # Annual trend between -20% and +20%
    volatility = 0.1 + 0.3 * random.random()  # Annual volatility between 10% and 40%
    
    # Daily parameters
    daily_trend = trend / n_periods
    daily_volatility = volatility / np.sqrt(n_periods)
    
    # Generate prices
    historical_prices = np.zeros(n_periods)
    historical_prices[0] = current_price * (0.8 + 0.4 * random.random())  # Start at a random price
    
    for i in range(1, n_periods):
        # Random daily return with trend and volatility
        daily_return = daily_trend + daily_volatility * np.random.randn()
        
        # Update price
        historical_prices[i] = historical_prices[i-1] * (1.0 + daily_return)
    
    # Ensure the last price matches the current price
    historical_prices[-1] = current_price
    
    # Generate random current weight
    current_weight = min_weight + (max_weight - min_weight) * random.random()
    
    return PortfolioAsset(
        id=id,
        symbol=symbol,
        name=name,
        asset_type=asset_type,
        current_price=current_price,
        historical_prices=historical_prices.tolist(),
        current_weight=current_weight,
        min_weight=min_weight,
        max_weight=max_weight
    )


def generate_random_portfolio(id, name, n_assets, cash=0.0):
    """
    Generate a random portfolio for testing.
    
    Args:
        id: Unique identifier for the portfolio
        name: Human-readable name for the portfolio
        n_assets: Number of assets in the portfolio
        cash: Cash in the portfolio
    
    Returns:
        Portfolio: The generated portfolio
    """
    # Generate random assets
    assets = []
    
    asset_types = ["stock", "bond", "crypto", "commodity", "real_estate"]
    
    for i in range(n_assets):
        # Generate random asset type
        asset_type = random.choice(asset_types)
        
        # Generate random asset
        asset = generate_random_asset(
            id=f"asset-{i+1}",
            symbol=f"ASSET{i+1}",
            name=f"Asset {i+1}",
            asset_type=asset_type,
            min_weight=0.05,  # Minimum 5% allocation
            max_weight=0.5    # Maximum 50% allocation
        )
        
        assets.append(asset)
    
    # Normalize weights to sum to 1
    total_weight = sum(asset.current_weight for asset in assets)
    
    for asset in assets:
        asset.current_weight /= total_weight
    
    return Portfolio(id=id, name=name, assets=assets, cash=cash)


def print_portfolio_summary(portfolio, metrics=None):
    """
    Print a summary of a portfolio.
    
    Args:
        portfolio: The portfolio to summarize
        metrics: Portfolio metrics (optional)
    """
    print(f"Portfolio: {portfolio.name} ({portfolio.id})")
    print(f"Total Value: ${portfolio.total_value:.2f}")
    print(f"Cash: ${portfolio.cash:.2f}")
    print(f"Assets: {len(portfolio.assets)}")
    
    if metrics:
        print(f"Expected Return: {metrics['expected_return'] * 100:.2f}%")
        print(f"Risk: {metrics['risk'] * 100:.2f}%")
        print(f"Sharpe Ratio: {metrics['sharpe_ratio']:.2f}")
    
    print("\nAsset Allocations:")
    for asset in portfolio.assets:
        print(f"  {asset.name} ({asset.symbol}): {asset.current_weight * 100:.2f}%")


def print_rebalance_result(result):
    """
    Print a summary of a rebalance result.
    
    Args:
        result: The rebalance result to summarize
    """
    print("Rebalance Result:")
    print(f"Strategy: {result.strategy}")
    print(f"Expected Return: {result.expected_return * 100:.2f}%")
    print(f"Expected Risk: {result.expected_risk * 100:.2f}%")
    print(f"Sharpe Ratio: {result.sharpe_ratio:.2f}")
    print(f"Timestamp: {result.timestamp.strftime('%Y-%m-%d %H:%M:%S')}")
    
    print("\nNew Asset Allocations:")
    for i, asset in enumerate(result.portfolio.assets):
        new_weight = result.new_weights[i]
        old_weight = asset.current_weight
        change = new_weight - old_weight
        
        print(f"  {asset.name} ({asset.symbol}): {new_weight * 100:.2f}% " +
              f"({'+'if change >= 0 else ''}{change * 100:.2f}%)")


def plot_portfolio_weights(portfolio, result):
    """
    Plot the current and new weights of a portfolio.
    
    Args:
        portfolio: The portfolio
        result: The rebalance result
    """
    # Extract asset names and weights
    asset_names = [asset.symbol for asset in portfolio.assets]
    current_weights = [asset.current_weight for asset in portfolio.assets]
    new_weights = result.new_weights
    
    # Create figure
    fig, ax = plt.subplots(figsize=(12, 6))
    
    # Set width of bars
    bar_width = 0.35
    
    # Set positions of bars on x-axis
    r1 = np.arange(len(asset_names))
    r2 = [x + bar_width for x in r1]
    
    # Create bars
    ax.bar(r1, current_weights, width=bar_width, label='Current Weights', color='skyblue')
    ax.bar(r2, new_weights, width=bar_width, label='New Weights', color='lightgreen')
    
    # Add labels and title
    ax.set_xlabel('Assets')
    ax.set_ylabel('Weight')
    ax.set_title('Portfolio Weights')
    ax.set_xticks([r + bar_width/2 for r in range(len(asset_names))])
    ax.set_xticklabels(asset_names)
    ax.legend()
    
    # Save plot
    plt.tight_layout()
    plt.savefig("portfolio_weights.png")
    print("Portfolio weights plot saved to portfolio_weights.png")


async def demonstrate_portfolio_rebalancer():
    """Demonstrate the portfolio rebalancer functionality."""
    # Initialize JuliaOS
    juliaos = JuliaOS()
    await juliaos.connect()
    
    try:
        # Create portfolio rebalancer
        rebalancer = PortfolioRebalancer(juliaos.bridge)
        
        # Generate a random portfolio
        portfolio = generate_random_portfolio(
            id="portfolio-1",
            name="Test Portfolio",
            n_assets=10,  # 10 assets
            cash=10000.0
        )
        
        # Calculate portfolio metrics
        weights = [asset.current_weight for asset in portfolio.assets]
        metrics = await rebalancer.calculate_portfolio_metrics(portfolio.assets, weights)
        
        # Print portfolio summary
        print("\nInitial Portfolio:")
        print_portfolio_summary(portfolio, metrics)
        
        # Rebalance portfolio using different strategies
        print("\n=== Rebalancing Strategies ===")
        
        # Equal weight strategy
        print("\n1. Equal Weight Strategy:")
        equal_weight_result = await rebalancer.rebalance_portfolio(
            portfolio,
            RebalanceStrategy.EQUAL_WEIGHT
        )
        print_rebalance_result(equal_weight_result)
        
        # Minimum variance strategy
        print("\n2. Minimum Variance Strategy:")
        min_var_result = await rebalancer.rebalance_portfolio(
            portfolio,
            RebalanceStrategy.MINIMUM_VARIANCE
        )
        print_rebalance_result(min_var_result)
        
        # Maximum Sharpe ratio strategy
        print("\n3. Maximum Sharpe Ratio Strategy:")
        max_sharpe_result = await rebalancer.rebalance_portfolio(
            portfolio,
            RebalanceStrategy.MAXIMUM_SHARPE
        )
        print_rebalance_result(max_sharpe_result)
        
        # Risk parity strategy
        print("\n4. Risk Parity Strategy:")
        risk_parity_result = await rebalancer.rebalance_portfolio(
            portfolio,
            RebalanceStrategy.RISK_PARITY
        )
        print_rebalance_result(risk_parity_result)
        
        # Maximum return strategy (with risk constraint)
        print("\n5. Maximum Return Strategy (with risk constraint):")
        max_return_params = {"target_risk": 0.2}  # 20% maximum risk
        max_return_result = await rebalancer.rebalance_portfolio(
            portfolio,
            RebalanceStrategy.MAXIMUM_RETURN,
            params=max_return_params
        )
        print_rebalance_result(max_return_result)
        
        # Multi-objective optimization
        print("\n6. Multi-Objective Optimization:")
        multi_obj_result = await rebalancer.rebalance_portfolio(
            portfolio,
            RebalanceStrategy.MULTI_OBJECTIVE
        )
        print_rebalance_result(multi_obj_result)
        
        # Apply the maximum Sharpe ratio rebalance
        print("\nApplying Maximum Sharpe Ratio rebalance...")
        rebalanced_portfolio = await rebalancer.apply_rebalance(
            portfolio,
            max_sharpe_result
        )
        
        # Calculate metrics for rebalanced portfolio
        rebalanced_weights = [asset.current_weight for asset in rebalanced_portfolio.assets]
        rebalanced_metrics = await rebalancer.calculate_portfolio_metrics(
            rebalanced_portfolio.assets,
            rebalanced_weights
        )
        
        print("\nRebalanced Portfolio:")
        print_portfolio_summary(rebalanced_portfolio, rebalanced_metrics)
        
        # Plot portfolio weights
        plot_portfolio_weights(portfolio, max_sharpe_result)
    
    finally:
        # Disconnect from JuliaOS
        await juliaos.disconnect()
        print("Disconnected from JuliaOS")


async def main():
    """Main function to run the example."""
    print("=== Portfolio Rebalancer Example ===")
    
    # Set random seed for reproducibility
    random.seed(42)
    np.random.seed(42)
    
    await demonstrate_portfolio_rebalancer()
    
    print("\nExample completed successfully!")


if __name__ == "__main__":
    asyncio.run(main())
