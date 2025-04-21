module Finance

# Import required modules
# We'll import Swarms inside the module functions to avoid circular dependencies

# Include finance modules
include("Finance/PortfolioRebalancer.jl")

# Re-export modules
using .PortfolioRebalancer

# Export main functions and types
export rebalance_portfolio, calculate_optimal_weights, apply_rebalance
export PortfolioAsset, Portfolio, RebalanceResult, RebalanceStrategy
export calculate_portfolio_metrics, calculate_expected_return, calculate_risk

end # module
