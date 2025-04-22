"""
Visualization.jl - Main module for visualization tools

This module provides visualization tools for JuliaOS.
"""
module Visualization

# Export all submodules
export TradingVisualizer

# Export key functions
export plot_price_data, plot_moving_averages, plot_mean_reversion
export plot_backtest_results, plot_equity_curve, plot_drawdown_curve
export plot_trade_distribution, plot_returns_distribution

# Include submodules
include("TradingVisualizer.jl")

# Re-export from submodules
using .TradingVisualizer

end # module
