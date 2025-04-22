"""
RiskManagement.jl - Risk management for DeFi trading

This module provides risk management functionality for DeFi trading.
"""
module RiskManagement

export RiskParameters, PositionSizer, StopLossManager, RiskManager
export calculate_position_size, set_stop_loss, set_take_profit, check_risk_limits
export calculate_value_at_risk, calculate_expected_shortfall, calculate_kelly_criterion

using Statistics
using Distributions

"""
    RiskParameters

Structure representing risk management parameters.

# Fields
- `max_position_size::Float64`: Maximum position size as a percentage of portfolio value
- `max_drawdown::Float64`: Maximum allowed drawdown as a percentage
- `max_daily_loss::Float64`: Maximum allowed daily loss as a percentage
- `max_trade_loss::Float64`: Maximum allowed loss per trade as a percentage
- `stop_loss_pct::Float64`: Default stop loss percentage
- `take_profit_pct::Float64`: Default take profit percentage
- `risk_reward_ratio::Float64`: Minimum risk-reward ratio
- `confidence_level::Float64`: Confidence level for VaR calculations
- `kelly_fraction::Float64`: Fraction of Kelly criterion to use
"""
struct RiskParameters
    max_position_size::Float64
    max_drawdown::Float64
    max_daily_loss::Float64
    max_trade_loss::Float64
    stop_loss_pct::Float64
    take_profit_pct::Float64
    risk_reward_ratio::Float64
    confidence_level::Float64
    kelly_fraction::Float64
    
    function RiskParameters(;
        max_position_size::Float64 = 0.1,  # 10% of portfolio
        max_drawdown::Float64 = 0.2,       # 20% drawdown
        max_daily_loss::Float64 = 0.05,    # 5% daily loss
        max_trade_loss::Float64 = 0.02,    # 2% per trade
        stop_loss_pct::Float64 = 0.05,     # 5% stop loss
        take_profit_pct::Float64 = 0.1,    # 10% take profit
        risk_reward_ratio::Float64 = 2.0,  # 2:1 risk-reward
        confidence_level::Float64 = 0.95,  # 95% confidence
        kelly_fraction::Float64 = 0.5      # Half Kelly
    )
        # Validate parameters
        max_position_size > 0.0 || throw(ArgumentError("max_position_size must be positive"))
        max_position_size <= 1.0 || throw(ArgumentError("max_position_size must be <= 1.0"))
        
        max_drawdown > 0.0 || throw(ArgumentError("max_drawdown must be positive"))
        max_drawdown <= 1.0 || throw(ArgumentError("max_drawdown must be <= 1.0"))
        
        max_daily_loss > 0.0 || throw(ArgumentError("max_daily_loss must be positive"))
        max_daily_loss <= 1.0 || throw(ArgumentError("max_daily_loss must be <= 1.0"))
        
        max_trade_loss > 0.0 || throw(ArgumentError("max_trade_loss must be positive"))
        max_trade_loss <= 1.0 || throw(ArgumentError("max_trade_loss must be <= 1.0"))
        
        stop_loss_pct > 0.0 || throw(ArgumentError("stop_loss_pct must be positive"))
        stop_loss_pct <= 1.0 || throw(ArgumentError("stop_loss_pct must be <= 1.0"))
        
        take_profit_pct > 0.0 || throw(ArgumentError("take_profit_pct must be positive"))
        
        risk_reward_ratio > 0.0 || throw(ArgumentError("risk_reward_ratio must be positive"))
        
        confidence_level > 0.0 || throw(ArgumentError("confidence_level must be positive"))
        confidence_level < 1.0 || throw(ArgumentError("confidence_level must be < 1.0"))
        
        kelly_fraction > 0.0 || throw(ArgumentError("kelly_fraction must be positive"))
        kelly_fraction <= 1.0 || throw(ArgumentError("kelly_fraction must be <= 1.0"))
        
        new(
            max_position_size,
            max_drawdown,
            max_daily_loss,
            max_trade_loss,
            stop_loss_pct,
            take_profit_pct,
            risk_reward_ratio,
            confidence_level,
            kelly_fraction
        )
    end
end

"""
    PositionSizer

Structure representing a position sizer.

# Fields
- `risk_parameters::RiskParameters`: Risk management parameters
- `portfolio_value::Float64`: Current portfolio value
- `daily_loss::Float64`: Current daily loss
- `max_drawdown_value::Float64`: Maximum drawdown value
"""
mutable struct PositionSizer
    risk_parameters::RiskParameters
    portfolio_value::Float64
    daily_loss::Float64
    max_drawdown_value::Float64
    
    function PositionSizer(risk_parameters::RiskParameters, portfolio_value::Float64)
        portfolio_value > 0.0 || throw(ArgumentError("portfolio_value must be positive"))
        
        new(
            risk_parameters,
            portfolio_value,
            0.0,
            0.0
        )
    end
end

"""
    StopLossManager

Structure representing a stop loss manager.

# Fields
- `risk_parameters::RiskParameters`: Risk management parameters
- `positions::Dict{String, Dict{String, Any}}`: Current positions with stop loss and take profit levels
"""
mutable struct StopLossManager
    risk_parameters::RiskParameters
    positions::Dict{String, Dict{String, Any}}
    
    function StopLossManager(risk_parameters::RiskParameters)
        new(
            risk_parameters,
            Dict{String, Dict{String, Any}}()
        )
    end
end

"""
    RiskManager

Structure representing a risk manager.

# Fields
- `risk_parameters::RiskParameters`: Risk management parameters
- `position_sizer::PositionSizer`: Position sizer
- `stop_loss_manager::StopLossManager`: Stop loss manager
- `historical_returns::Vector{Float64}`: Historical returns for VaR calculations
"""
mutable struct RiskManager
    risk_parameters::RiskParameters
    position_sizer::PositionSizer
    stop_loss_manager::StopLossManager
    historical_returns::Vector{Float64}
    
    function RiskManager(
        risk_parameters::RiskParameters,
        portfolio_value::Float64,
        historical_returns::Vector{Float64} = Float64[]
    )
        new(
            risk_parameters,
            PositionSizer(risk_parameters, portfolio_value),
            StopLossManager(risk_parameters),
            historical_returns
        )
    end
end

# ===== Position Sizing Functions =====

"""
    calculate_position_size(position_sizer::PositionSizer, entry_price::Float64, stop_loss_price::Float64)

Calculate the position size based on risk parameters.

# Arguments
- `position_sizer::PositionSizer`: The position sizer
- `entry_price::Float64`: The entry price
- `stop_loss_price::Float64`: The stop loss price

# Returns
- `Float64`: The position size in base currency
"""
function calculate_position_size(position_sizer::PositionSizer, entry_price::Float64, stop_loss_price::Float64)
    # Calculate risk per trade in currency units
    risk_per_trade = position_sizer.portfolio_value * position_sizer.risk_parameters.max_trade_loss
    
    # Calculate risk per unit
    risk_per_unit = abs(entry_price - stop_loss_price)
    
    # Calculate position size
    position_size = risk_per_trade / risk_per_unit
    
    # Apply maximum position size constraint
    max_position = position_sizer.portfolio_value * position_sizer.risk_parameters.max_position_size / entry_price
    position_size = min(position_size, max_position)
    
    return position_size
end

"""
    calculate_position_size_kelly(position_sizer::PositionSizer, win_probability::Float64, 
                                win_loss_ratio::Float64)

Calculate the position size using the Kelly criterion.

# Arguments
- `position_sizer::PositionSizer`: The position sizer
- `win_probability::Float64`: The probability of winning
- `win_loss_ratio::Float64`: The ratio of average win to average loss

# Returns
- `Float64`: The position size as a fraction of the portfolio
"""
function calculate_position_size_kelly(position_sizer::PositionSizer, win_probability::Float64, 
                                     win_loss_ratio::Float64)
    # Calculate Kelly fraction
    kelly = win_probability - (1.0 - win_probability) / win_loss_ratio
    
    # Apply Kelly fraction and ensure it's positive
    kelly = max(0.0, kelly) * position_sizer.risk_parameters.kelly_fraction
    
    # Apply maximum position size constraint
    kelly = min(kelly, position_sizer.risk_parameters.max_position_size)
    
    return kelly
end

"""
    update_portfolio_value(position_sizer::PositionSizer, new_value::Float64)

Update the portfolio value and track drawdown.

# Arguments
- `position_sizer::PositionSizer`: The position sizer
- `new_value::Float64`: The new portfolio value

# Returns
- `Float64`: The current drawdown as a percentage
"""
function update_portfolio_value(position_sizer::PositionSizer, new_value::Float64)
    # Calculate daily P&L
    daily_pnl = new_value - position_sizer.portfolio_value
    
    # Update daily loss if negative
    if daily_pnl < 0
        position_sizer.daily_loss += abs(daily_pnl)
    end
    
    # Update portfolio value
    old_value = position_sizer.portfolio_value
    position_sizer.portfolio_value = new_value
    
    # Update max drawdown
    if new_value < old_value
        drawdown = (old_value - new_value) / old_value
        position_sizer.max_drawdown_value = max(position_sizer.max_drawdown_value, drawdown)
        return drawdown
    end
    
    return 0.0
end

"""
    reset_daily_loss(position_sizer::PositionSizer)

Reset the daily loss counter.

# Arguments
- `position_sizer::PositionSizer`: The position sizer
"""
function reset_daily_loss(position_sizer::PositionSizer)
    position_sizer.daily_loss = 0.0
end

# ===== Stop Loss Functions =====

"""
    set_stop_loss(stop_loss_manager::StopLossManager, position_id::String, entry_price::Float64;
                stop_loss_pct::Union{Float64, Nothing}=nothing, stop_loss_price::Union{Float64, Nothing}=nothing)

Set a stop loss for a position.

# Arguments
- `stop_loss_manager::StopLossManager`: The stop loss manager
- `position_id::String`: The position ID
- `entry_price::Float64`: The entry price
- `stop_loss_pct::Union{Float64, Nothing}`: The stop loss percentage (optional)
- `stop_loss_price::Union{Float64, Nothing}`: The stop loss price (optional)

# Returns
- `Float64`: The stop loss price
"""
function set_stop_loss(stop_loss_manager::StopLossManager, position_id::String, entry_price::Float64;
                     stop_loss_pct::Union{Float64, Nothing}=nothing, stop_loss_price::Union{Float64, Nothing}=nothing)
    # Use provided stop loss percentage or default
    sl_pct = stop_loss_pct === nothing ? stop_loss_manager.risk_parameters.stop_loss_pct : stop_loss_pct
    
    # Calculate stop loss price if not provided
    sl_price = stop_loss_price
    if sl_price === nothing
        sl_price = entry_price * (1.0 - sl_pct)
    end
    
    # Create or update position
    if !haskey(stop_loss_manager.positions, position_id)
        stop_loss_manager.positions[position_id] = Dict{String, Any}()
    end
    
    stop_loss_manager.positions[position_id]["entry_price"] = entry_price
    stop_loss_manager.positions[position_id]["stop_loss_price"] = sl_price
    
    return sl_price
end

"""
    set_take_profit(stop_loss_manager::StopLossManager, position_id::String, entry_price::Float64;
                  take_profit_pct::Union{Float64, Nothing}=nothing, take_profit_price::Union{Float64, Nothing}=nothing)

Set a take profit for a position.

# Arguments
- `stop_loss_manager::StopLossManager`: The stop loss manager
- `position_id::String`: The position ID
- `entry_price::Float64`: The entry price
- `take_profit_pct::Union{Float64, Nothing}`: The take profit percentage (optional)
- `take_profit_price::Union{Float64, Nothing}`: The take profit price (optional)

# Returns
- `Float64`: The take profit price
"""
function set_take_profit(stop_loss_manager::StopLossManager, position_id::String, entry_price::Float64;
                       take_profit_pct::Union{Float64, Nothing}=nothing, take_profit_price::Union{Float64, Nothing}=nothing)
    # Use provided take profit percentage or default
    tp_pct = take_profit_pct === nothing ? stop_loss_manager.risk_parameters.take_profit_pct : take_profit_pct
    
    # Calculate take profit price if not provided
    tp_price = take_profit_price
    if tp_price === nothing
        tp_price = entry_price * (1.0 + tp_pct)
    end
    
    # Create or update position
    if !haskey(stop_loss_manager.positions, position_id)
        stop_loss_manager.positions[position_id] = Dict{String, Any}()
    end
    
    stop_loss_manager.positions[position_id]["entry_price"] = entry_price
    stop_loss_manager.positions[position_id]["take_profit_price"] = tp_price
    
    return tp_price
end

"""
    check_stop_loss(stop_loss_manager::StopLossManager, position_id::String, current_price::Float64)

Check if a stop loss has been triggered.

# Arguments
- `stop_loss_manager::StopLossManager`: The stop loss manager
- `position_id::String`: The position ID
- `current_price::Float64`: The current price

# Returns
- `Bool`: Whether the stop loss has been triggered
"""
function check_stop_loss(stop_loss_manager::StopLossManager, position_id::String, current_price::Float64)
    if !haskey(stop_loss_manager.positions, position_id)
        return false
    end
    
    position = stop_loss_manager.positions[position_id]
    
    if !haskey(position, "stop_loss_price")
        return false
    end
    
    return current_price <= position["stop_loss_price"]
end

"""
    check_take_profit(stop_loss_manager::StopLossManager, position_id::String, current_price::Float64)

Check if a take profit has been triggered.

# Arguments
- `stop_loss_manager::StopLossManager`: The stop loss manager
- `position_id::String`: The position ID
- `current_price::Float64`: The current price

# Returns
- `Bool`: Whether the take profit has been triggered
"""
function check_take_profit(stop_loss_manager::StopLossManager, position_id::String, current_price::Float64)
    if !haskey(stop_loss_manager.positions, position_id)
        return false
    end
    
    position = stop_loss_manager.positions[position_id]
    
    if !haskey(position, "take_profit_price")
        return false
    end
    
    return current_price >= position["take_profit_price"]
end

"""
    remove_position(stop_loss_manager::StopLossManager, position_id::String)

Remove a position from the stop loss manager.

# Arguments
- `stop_loss_manager::StopLossManager`: The stop loss manager
- `position_id::String`: The position ID
"""
function remove_position(stop_loss_manager::StopLossManager, position_id::String)
    if haskey(stop_loss_manager.positions, position_id)
        delete!(stop_loss_manager.positions, position_id)
    end
end

# ===== Risk Management Functions =====

"""
    check_risk_limits(risk_manager::RiskManager, new_position_size::Float64, entry_price::Float64)

Check if a new position would violate risk limits.

# Arguments
- `risk_manager::RiskManager`: The risk manager
- `new_position_size::Float64`: The new position size
- `entry_price::Float64`: The entry price

# Returns
- `Tuple{Bool, String}`: Whether the position is allowed and a message
"""
function check_risk_limits(risk_manager::RiskManager, new_position_size::Float64, entry_price::Float64)
    # Check maximum position size
    position_value = new_position_size * entry_price
    max_position_value = risk_manager.position_sizer.portfolio_value * risk_manager.risk_parameters.max_position_size
    
    if position_value > max_position_value
        return (false, "Position size exceeds maximum allowed")
    end
    
    # Check daily loss limit
    daily_loss_limit = risk_manager.position_sizer.portfolio_value * risk_manager.risk_parameters.max_daily_loss
    
    if risk_manager.position_sizer.daily_loss >= daily_loss_limit
        return (false, "Daily loss limit reached")
    end
    
    # Check drawdown limit
    if risk_manager.position_sizer.max_drawdown_value >= risk_manager.risk_parameters.max_drawdown
        return (false, "Maximum drawdown reached")
    end
    
    return (true, "Position allowed")
end

"""
    calculate_value_at_risk(risk_manager::RiskManager, position_value::Float64;
                          time_horizon::Int=1, method::Symbol=:parametric)

Calculate the Value at Risk (VaR) for a position.

# Arguments
- `risk_manager::RiskManager`: The risk manager
- `position_value::Float64`: The position value
- `time_horizon::Int`: The time horizon in days
- `method::Symbol`: The VaR calculation method (:parametric, :historical, or :monte_carlo)

# Returns
- `Float64`: The Value at Risk
"""
function calculate_value_at_risk(risk_manager::RiskManager, position_value::Float64;
                               time_horizon::Int=1, method::Symbol=:parametric)
    if isempty(risk_manager.historical_returns)
        error("Historical returns are required for VaR calculation")
    end
    
    # Calculate VaR based on the specified method
    if method == :parametric
        # Parametric VaR (assumes normal distribution)
        μ = mean(risk_manager.historical_returns)
        σ = std(risk_manager.historical_returns)
        
        # Calculate the z-score for the confidence level
        z = quantile(Normal(), 1.0 - risk_manager.risk_parameters.confidence_level)
        
        # Calculate VaR
        var = position_value * (μ * time_horizon + z * σ * sqrt(time_horizon))
        
        return abs(var)
    elseif method == :historical
        # Historical VaR
        sorted_returns = sort(risk_manager.historical_returns)
        index = Int(floor((1.0 - risk_manager.risk_parameters.confidence_level) * length(sorted_returns)))
        index = max(1, index)
        
        # Calculate VaR
        var = position_value * abs(sorted_returns[index]) * sqrt(time_horizon)
        
        return var
    elseif method == :monte_carlo
        # Monte Carlo VaR
        μ = mean(risk_manager.historical_returns)
        σ = std(risk_manager.historical_returns)
        
        # Generate random returns
        n_simulations = 10000
        random_returns = rand(Normal(μ, σ), n_simulations)
        
        # Calculate simulated values
        simulated_values = position_value .* (1.0 .+ random_returns .* sqrt(time_horizon))
        
        # Calculate VaR
        sorted_values = sort(simulated_values)
        index = Int(floor((1.0 - risk_manager.risk_parameters.confidence_level) * n_simulations))
        index = max(1, index)
        
        var = position_value - sorted_values[index]
        
        return var
    else
        error("Unsupported VaR method: $method")
    end
end

"""
    calculate_expected_shortfall(risk_manager::RiskManager, position_value::Float64;
                               time_horizon::Int=1, method::Symbol=:parametric)

Calculate the Expected Shortfall (ES) for a position.

# Arguments
- `risk_manager::RiskManager`: The risk manager
- `position_value::Float64`: The position value
- `time_horizon::Int`: The time horizon in days
- `method::Symbol`: The ES calculation method (:parametric, :historical, or :monte_carlo)

# Returns
- `Float64`: The Expected Shortfall
"""
function calculate_expected_shortfall(risk_manager::RiskManager, position_value::Float64;
                                    time_horizon::Int=1, method::Symbol=:parametric)
    if isempty(risk_manager.historical_returns)
        error("Historical returns are required for ES calculation")
    end
    
    # Calculate ES based on the specified method
    if method == :parametric
        # Parametric ES (assumes normal distribution)
        μ = mean(risk_manager.historical_returns)
        σ = std(risk_manager.historical_returns)
        
        # Calculate the z-score for the confidence level
        z = quantile(Normal(), 1.0 - risk_manager.risk_parameters.confidence_level)
        
        # Calculate ES
        es = position_value * (μ * time_horizon + σ * pdf(Normal(), z) / (1.0 - risk_manager.risk_parameters.confidence_level) * sqrt(time_horizon))
        
        return abs(es)
    elseif method == :historical
        # Historical ES
        sorted_returns = sort(risk_manager.historical_returns)
        index = Int(floor((1.0 - risk_manager.risk_parameters.confidence_level) * length(sorted_returns)))
        index = max(1, index)
        
        # Calculate ES as the average of returns beyond VaR
        tail_returns = sorted_returns[1:index]
        es = position_value * abs(mean(tail_returns)) * sqrt(time_horizon)
        
        return es
    elseif method == :monte_carlo
        # Monte Carlo ES
        μ = mean(risk_manager.historical_returns)
        σ = std(risk_manager.historical_returns)
        
        # Generate random returns
        n_simulations = 10000
        random_returns = rand(Normal(μ, σ), n_simulations)
        
        # Calculate simulated values
        simulated_values = position_value .* (1.0 .+ random_returns .* sqrt(time_horizon))
        
        # Calculate ES
        sorted_values = sort(simulated_values)
        index = Int(floor((1.0 - risk_manager.risk_parameters.confidence_level) * n_simulations))
        index = max(1, index)
        
        tail_values = sorted_values[1:index]
        es = position_value - mean(tail_values)
        
        return es
    else
        error("Unsupported ES method: $method")
    end
end

"""
    calculate_kelly_criterion(risk_manager::RiskManager, win_probability::Float64, win_loss_ratio::Float64)

Calculate the Kelly criterion for a betting scenario.

# Arguments
- `risk_manager::RiskManager`: The risk manager
- `win_probability::Float64`: The probability of winning
- `win_loss_ratio::Float64`: The ratio of average win to average loss

# Returns
- `Float64`: The Kelly criterion
"""
function calculate_kelly_criterion(risk_manager::RiskManager, win_probability::Float64, win_loss_ratio::Float64)
    # Calculate Kelly fraction
    kelly = win_probability - (1.0 - win_probability) / win_loss_ratio
    
    # Apply Kelly fraction and ensure it's positive
    kelly = max(0.0, kelly) * risk_manager.risk_parameters.kelly_fraction
    
    return kelly
end

end # module
