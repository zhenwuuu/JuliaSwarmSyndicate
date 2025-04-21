module Finance

export PortfolioRebalancer
export rebalance_portfolio, calculate_optimal_weights, apply_rebalance
export PortfolioAsset, Portfolio, RebalanceResult, RebalanceStrategy
export calculate_portfolio_metrics, calculate_expected_return, calculate_risk

# Import from JuliaOS core
using JuliaOS.Finance

# Re-export all public symbols
for name in names(JuliaOS.Finance, all=true)
    if !startswith(string(name), "#") && name != :Finance
        @eval export $name
    end
end

end # module
