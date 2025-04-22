"""
    risk_management_example.jl

Example demonstrating risk management for DeFi trading in JuliaOS.
"""

# Add the parent directory to the load path
push!(LOAD_PATH, joinpath(@__DIR__, ".."))

# Import required modules
using Random
using Statistics
using Dates
using Distributions

# Import JuliaOS modules
include("../julia/src/dex/DEXBase.jl")
include("../julia/src/dex/UniswapDEX.jl")
include("../julia/src/price/PriceFeeds.jl")
include("../julia/src/swarm/SwarmBase.jl")
include("../julia/src/swarm/algorithms/DEPSO.jl")
include("../julia/src/trading/TradingStrategy.jl")

using .DEXBase
using .UniswapDEX
using .PriceFeeds
using .SwarmBase
using .DEPSO
using .TradingStrategy
using .TradingStrategy.RiskManagement

# Set random seed for reproducibility
Random.seed!(42)

"""
    run_position_sizing_example()

Run a position sizing example using risk management.
"""
function run_position_sizing_example()
    println("Position Sizing Example")
    println("======================")

    # Create risk parameters
    risk_params = RiskParameters(
        max_position_size = 0.1,    # 10% of portfolio
        max_drawdown = 0.2,         # 20% drawdown
        max_daily_loss = 0.05,      # 5% daily loss
        max_trade_loss = 0.02,      # 2% per trade
        stop_loss_pct = 0.05,       # 5% stop loss
        take_profit_pct = 0.1,      # 10% take profit
        risk_reward_ratio = 2.0,    # 2:1 risk-reward
        confidence_level = 0.95,    # 95% confidence
        kelly_fraction = 0.5        # Half Kelly
    )

    # Create position sizer
    portfolio_value = 10000.0  # $10,000 portfolio
    position_sizer = PositionSizer(risk_params, portfolio_value)

    # Calculate position size for a trade
    entry_price = 1800.0  # ETH price
    stop_loss_price = 1710.0  # 5% below entry

    position_size = RiskManagement.calculate_position_size(position_sizer, entry_price, stop_loss_price)

    println("Portfolio value: \$$(portfolio_value)")
    println("Entry price: \$$(entry_price)")
    println("Stop loss price: \$$(stop_loss_price)")
    println("Position size: $(round(position_size, digits=4)) ETH")
    println("Position value: \$$(round(position_size * entry_price, digits=2))")
    println("Risk per trade: \$$(round(portfolio_value * risk_params.max_trade_loss, digits=2))")

    # Calculate position size using Kelly criterion
    win_probability = 0.6  # 60% win rate
    win_loss_ratio = 2.0  # 2:1 win/loss ratio

    kelly_size = RiskManagement.calculate_position_size_kelly(position_sizer, win_probability, win_loss_ratio)
    kelly_position = kelly_size * portfolio_value / entry_price

    println("\nKelly criterion:")
    println("Win probability: $(win_probability * 100)%")
    println("Win/loss ratio: $(win_loss_ratio):1")
    println("Kelly fraction: $(round(kelly_size * 100, digits=2))%")
    println("Kelly position size: $(round(kelly_position, digits=4)) ETH")
    println("Kelly position value: \$$(round(kelly_position * entry_price, digits=2))")

    # Update portfolio value after a trade
    new_portfolio_value = 9800.0  # $200 loss
    drawdown = RiskManagement.update_portfolio_value(position_sizer, new_portfolio_value)

    println("\nAfter trade:")
    println("New portfolio value: \$$(new_portfolio_value)")
    println("Drawdown: $(round(drawdown * 100, digits=2))%")
    println("Daily loss: \$$(position_sizer.daily_loss)")

    return Dict(
        "risk_params" => risk_params,
        "position_sizer" => position_sizer,
        "position_size" => position_size,
        "kelly_size" => kelly_size
    )
end

"""
    run_stop_loss_example()

Run a stop loss management example.
"""
function run_stop_loss_example()
    println("\nStop Loss Management Example")
    println("===========================")

    # Create risk parameters
    risk_params = RiskParameters(
        stop_loss_pct = 0.05,       # 5% stop loss
        take_profit_pct = 0.1       # 10% take profit
    )

    # Create stop loss manager
    stop_loss_manager = StopLossManager(risk_params)

    # Set stop loss and take profit for a position
    position_id = "ETH-001"
    entry_price = 1800.0

    stop_loss_price = RiskManagement.set_stop_loss(stop_loss_manager, position_id, entry_price)
    take_profit_price = RiskManagement.set_take_profit(stop_loss_manager, position_id, entry_price)

    println("Position ID: $position_id")
    println("Entry price: \$$(entry_price)")
    println("Stop loss price: \$$(stop_loss_price)")
    println("Take profit price: \$$(take_profit_price)")

    # Check if stop loss or take profit is triggered
    current_price = 1750.0

    println("\nCurrent price: \$$(current_price)")
    println("Stop loss triggered: $(RiskManagement.check_stop_loss(stop_loss_manager, position_id, current_price))")
    println("Take profit triggered: $(RiskManagement.check_take_profit(stop_loss_manager, position_id, current_price))")

    # Try a price that triggers stop loss
    current_price = 1700.0

    println("\nCurrent price: \$$(current_price)")
    println("Stop loss triggered: $(RiskManagement.check_stop_loss(stop_loss_manager, position_id, current_price))")
    println("Take profit triggered: $(RiskManagement.check_take_profit(stop_loss_manager, position_id, current_price))")

    # Try a price that triggers take profit
    current_price = 2000.0

    println("\nCurrent price: \$$(current_price)")
    println("Stop loss triggered: $(RiskManagement.check_stop_loss(stop_loss_manager, position_id, current_price))")
    println("Take profit triggered: $(RiskManagement.check_take_profit(stop_loss_manager, position_id, current_price))")

    # Remove the position
    RiskManagement.remove_position(stop_loss_manager, position_id)

    println("\nPosition removed")
    println("Position still exists: $(haskey(stop_loss_manager.positions, position_id))")

    return Dict(
        "risk_params" => risk_params,
        "stop_loss_manager" => stop_loss_manager
    )
end

"""
    run_risk_management_example()

Run a comprehensive risk management example.
"""
function run_risk_management_example()
    println("\nRisk Management Example")
    println("======================")

    # Create risk parameters
    risk_params = RiskParameters(
        max_position_size = 0.1,    # 10% of portfolio
        max_drawdown = 0.2,         # 20% drawdown
        max_daily_loss = 0.05,      # 5% daily loss
        max_trade_loss = 0.02,      # 2% per trade
        stop_loss_pct = 0.05,       # 5% stop loss
        take_profit_pct = 0.1,      # 10% take profit
        risk_reward_ratio = 2.0,    # 2:1 risk-reward
        confidence_level = 0.95,    # 95% confidence
        kelly_fraction = 0.5        # Half Kelly
    )

    # Create risk manager
    portfolio_value = 10000.0  # $10,000 portfolio

    # Generate historical returns
    n_days = 100
    μ = 0.001  # 0.1% daily return
    σ = 0.02   # 2% daily volatility

    historical_returns = rand(Normal(μ, σ), n_days)

    risk_manager = RiskManager(risk_params, portfolio_value, historical_returns)

    # Check risk limits for a new position
    position_size = 0.5  # 0.5 ETH
    entry_price = 1800.0  # ETH price

    allowed, message = RiskManagement.check_risk_limits(risk_manager, position_size, entry_price)

    println("Portfolio value: \$$(portfolio_value)")
    println("Position size: $(position_size) ETH")
    println("Position value: \$$(position_size * entry_price)")
    println("Position allowed: $allowed")
    println("Message: $message")

    # Calculate Value at Risk (VaR)
    position_value = position_size * entry_price

    var_parametric = RiskManagement.calculate_value_at_risk(risk_manager, position_value, method=:parametric)
    var_historical = RiskManagement.calculate_value_at_risk(risk_manager, position_value, method=:historical)
    var_monte_carlo = RiskManagement.calculate_value_at_risk(risk_manager, position_value, method=:monte_carlo)

    println("\nValue at Risk (VaR) at $(risk_params.confidence_level * 100)% confidence level:")
    println("  Parametric VaR: \$$(round(var_parametric, digits=2))")
    println("  Historical VaR: \$$(round(var_historical, digits=2))")
    println("  Monte Carlo VaR: \$$(round(var_monte_carlo, digits=2))")

    # Calculate Expected Shortfall (ES)
    es_parametric = RiskManagement.calculate_expected_shortfall(risk_manager, position_value, method=:parametric)
    es_historical = RiskManagement.calculate_expected_shortfall(risk_manager, position_value, method=:historical)
    es_monte_carlo = RiskManagement.calculate_expected_shortfall(risk_manager, position_value, method=:monte_carlo)

    println("\nExpected Shortfall (ES) at $(risk_params.confidence_level * 100)% confidence level:")
    println("  Parametric ES: \$$(round(es_parametric, digits=2))")
    println("  Historical ES: \$$(round(es_historical, digits=2))")
    println("  Monte Carlo ES: \$$(round(es_monte_carlo, digits=2))")

    # Calculate Kelly criterion
    win_probability = 0.6  # 60% win rate
    win_loss_ratio = 2.0  # 2:1 win/loss ratio

    kelly = RiskManagement.calculate_kelly_criterion(risk_manager, win_probability, win_loss_ratio)

    println("\nKelly criterion:")
    println("  Win probability: $(win_probability * 100)%")
    println("  Win/loss ratio: $(win_loss_ratio):1")
    println("  Kelly fraction: $(round(kelly * 100, digits=2))%")
    println("  Recommended position size: \$$(round(kelly * portfolio_value, digits=2))")

    return Dict(
        "risk_params" => risk_params,
        "risk_manager" => risk_manager,
        "var" => Dict(
            "parametric" => var_parametric,
            "historical" => var_historical,
            "monte_carlo" => var_monte_carlo
        ),
        "es" => Dict(
            "parametric" => es_parametric,
            "historical" => es_historical,
            "monte_carlo" => es_monte_carlo
        ),
        "kelly" => kelly
    )
end

# Run all examples if this file is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    position_sizing_result = run_position_sizing_example()
    stop_loss_result = run_stop_loss_example()
    risk_management_result = run_risk_management_example()
end
