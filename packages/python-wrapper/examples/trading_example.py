#!/usr/bin/env python3
"""
Trading example for the JuliaOS Python wrapper.
"""

import asyncio
import logging
from datetime import datetime, timedelta
import random
from juliaos import JuliaOS
from juliaos.agents import AgentType
from juliaos.blockchain import Chain
from juliaos.wallet import WalletType

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


async def simulate_market_data(minutes=60, interval_seconds=5):
    """
    Simulate market data for testing.
    
    Args:
        minutes: Number of minutes to simulate
        interval_seconds: Interval between data points in seconds
    
    Returns:
        List of market data points
    """
    start_time = datetime.now()
    end_time = start_time + timedelta(minutes=minutes)
    current_time = start_time
    
    # Initial prices
    btc_price = 50000.0
    eth_price = 3000.0
    
    market_data = []
    
    while current_time < end_time:
        # Simulate price movements
        btc_change = random.uniform(-0.002, 0.002)
        eth_change = random.uniform(-0.003, 0.003)
        
        btc_price *= (1 + btc_change)
        eth_price *= (1 + eth_change)
        
        # Create market data point
        data_point = {
            "timestamp": current_time.isoformat(),
            "BTC": {
                "price": btc_price,
                "volume": random.uniform(10, 100)
            },
            "ETH": {
                "price": eth_price,
                "volume": random.uniform(100, 1000)
            }
        }
        
        market_data.append(data_point)
        current_time += timedelta(seconds=interval_seconds)
        
        # Yield the data point
        yield data_point
        
        # Sleep for the interval
        await asyncio.sleep(interval_seconds)


async def main():
    """
    Main function demonstrating trading with JuliaOS.
    """
    # Initialize JuliaOS
    juliaos = JuliaOS(host="localhost", port=8080)
    await juliaos.connect()
    logger.info("Connected to JuliaOS server")
    
    try:
        # Create a wallet
        wallet = await juliaos.wallet.create_wallet(
            name="Trading Wallet",
            wallet_type=WalletType.HD
        )
        logger.info(f"Created wallet: {wallet.id} ({wallet.name})")
        
        # Generate addresses
        eth_address = await wallet.generate_address(Chain.ETHEREUM)
        sol_address = await wallet.generate_address(Chain.SOLANA)
        logger.info(f"Ethereum address: {eth_address['address']}")
        logger.info(f"Solana address: {sol_address['address']}")
        
        # Create a trading agent
        trading_agent = await juliaos.agents.create_agent(
            name="BTC/ETH Trading Agent",
            agent_type=AgentType.TRADING,
            config={
                "parameters": {
                    "risk_tolerance": 0.5,
                    "max_position_size": 1000.0,
                    "take_profit": 0.05,
                    "stop_loss": 0.03,
                    "assets": ["BTC", "ETH"],
                    "strategy": "momentum"
                }
            }
        )
        logger.info(f"Created trading agent: {trading_agent.id} ({trading_agent.name})")
        
        # Initialize the trading agent
        await trading_agent.start()
        logger.info(f"Started trading agent: {trading_agent.status}")
        
        # Create a monitor agent
        monitor_agent = await juliaos.agents.create_agent(
            name="Market Monitor Agent",
            agent_type=AgentType.MONITOR,
            config={
                "parameters": {
                    "check_interval": 5,
                    "alert_channels": ["console"],
                    "max_alerts_per_hour": 10
                }
            }
        )
        logger.info(f"Created monitor agent: {monitor_agent.id} ({monitor_agent.name})")
        
        # Initialize the monitor agent
        await monitor_agent.start()
        logger.info(f"Started monitor agent: {monitor_agent.status}")
        
        # Configure alerts for the monitor agent
        alert_configs = [
            {
                "asset": "BTC",
                "condition_type": "price_above",
                "threshold": 52000.0,
                "message": "BTC price is above $52,000"
            },
            {
                "asset": "BTC",
                "condition_type": "price_below",
                "threshold": 48000.0,
                "message": "BTC price is below $48,000"
            },
            {
                "asset": "ETH",
                "condition_type": "price_above",
                "threshold": 3100.0,
                "message": "ETH price is above $3,100"
            },
            {
                "asset": "ETH",
                "condition_type": "price_below",
                "threshold": 2900.0,
                "message": "ETH price is below $2,900"
            }
        ]
        
        await monitor_agent.configure_alerts(alert_configs)
        logger.info("Configured alerts for monitor agent")
        
        # Simulate market data and feed it to the agents
        logger.info("Starting market simulation...")
        
        async for market_data in simulate_market_data(minutes=5, interval_seconds=5):
            # Log current prices
            btc_price = market_data["BTC"]["price"]
            eth_price = market_data["ETH"]["price"]
            logger.info(f"Market data: BTC=${btc_price:.2f}, ETH=${eth_price:.2f}")
            
            # Feed data to the trading agent
            trading_task = await trading_agent.execute_task({
                "type": "analyze_market",
                "parameters": {
                    "market_data": market_data
                }
            })
            
            # Feed data to the monitor agent
            monitor_task = await monitor_agent.execute_task({
                "type": "check_conditions",
                "parameters": {
                    "market_data": market_data
                }
            })
            
            # Get trading analysis result
            try:
                trading_result = await asyncio.wait_for(trading_task.wait_for_completion(), timeout=3)
                if trading_result.get("trade_signals"):
                    logger.info(f"Trade signals: {trading_result['trade_signals']}")
                    
                    # Execute trades based on signals
                    for signal in trading_result.get("trade_signals", []):
                        trade_task = await trading_agent.execute_task({
                            "type": "execute_trade",
                            "parameters": signal
                        })
                        trade_result = await asyncio.wait_for(trade_task.wait_for_completion(), timeout=3)
                        logger.info(f"Trade executed: {trade_result}")
            except asyncio.TimeoutError:
                logger.warning("Trading analysis timed out")
            
            # Get monitor alerts
            try:
                monitor_result = await asyncio.wait_for(monitor_task.wait_for_completion(), timeout=3)
                if monitor_result.get("triggered_alerts"):
                    for alert in monitor_result["triggered_alerts"]:
                        logger.warning(f"ALERT: {alert['message']}")
            except asyncio.TimeoutError:
                logger.warning("Monitor check timed out")
        
        logger.info("Market simulation completed")
        
        # Get trading agent portfolio
        portfolio = await trading_agent.get_portfolio()
        logger.info(f"Final portfolio: {portfolio}")
        
        # Get monitor agent alerts history
        alerts_history = await monitor_agent.get_alert_history()
        logger.info(f"Alerts triggered: {len(alerts_history.get('alerts', []))}")
        
        # Clean up
        await trading_agent.stop()
        await monitor_agent.stop()
        await juliaos.agents.delete_agent(trading_agent.id)
        await juliaos.agents.delete_agent(monitor_agent.id)
        await juliaos.wallet.delete_wallet(wallet.id)
        logger.info("Cleaned up resources")
        
    except Exception as e:
        logger.error(f"Error: {e}")
    finally:
        # Disconnect from JuliaOS
        await juliaos.disconnect()
        logger.info("Disconnected from JuliaOS server")


if __name__ == "__main__":
    asyncio.run(main())
