"""
TradingAgent module for JuliaOS

This module provides specialized functionality for trading agents.
"""
module TradingAgent

export TradingAgentConfig, createTradingAgent, executeTrade, getPortfolio, getTradeHistory

using ..Agents
using Dates
using Random

"""
    TradingAgentConfig

Configuration for creating a new trading agent.

# Fields
- `name::String`: Agent name
- `chains::Vector{String}`: Blockchain chains the agent can operate on
- `risk_level::String`: Risk level (low, medium, high)
- `max_position_size::Float64`: Maximum position size
- `take_profit::Float64`: Take profit percentage
- `stop_loss::Float64`: Stop loss percentage
- `trading_pairs::Vector{String}`: Trading pairs to monitor
- `strategies::Vector{String}`: Trading strategies to use
- `parameters::Dict{String, Any}`: Additional agent-specific parameters
- `llm_config::Dict{String, Any}`: Configuration for the LLM provider
- `memory_config::Dict{String, Any}`: Configuration for agent memory
"""
struct TradingAgentConfig
    name::String
    chains::Vector{String}
    risk_level::String
    max_position_size::Float64
    take_profit::Float64
    stop_loss::Float64
    trading_pairs::Vector{String}
    strategies::Vector{String}
    parameters::Dict{String, Any}
    llm_config::Dict{String, Any}
    memory_config::Dict{String, Any}

    # Constructor with default values
    function TradingAgentConfig(
        name::String;
        chains::Vector{String}=["ethereum", "polygon"],
        risk_level::String="medium",
        max_position_size::Float64=1000.0,
        take_profit::Float64=0.05,
        stop_loss::Float64=0.03,
        trading_pairs::Vector{String}=["ETH/USDC", "MATIC/USDC"],
        strategies::Vector{String}=["momentum", "mean_reversion"],
        parameters::Dict{String, Any}=Dict{String, Any}(),
        llm_config::Dict{String, Any}=Dict{String, Any}(),
        memory_config::Dict{String, Any}=Dict{String, Any}()
    )
        # Validate risk level
        if !(risk_level in ["low", "medium", "high"])
            throw(ArgumentError("Risk level must be one of: low, medium, high"))
        end

        # Validate take profit and stop loss
        if take_profit <= 0.0
            throw(ArgumentError("Take profit must be greater than 0"))
        end
        if stop_loss <= 0.0
            throw(ArgumentError("Stop loss must be greater than 0"))
        end

        # Set default LLM config if not provided
        if isempty(llm_config)
            llm_config = Dict(
                "provider" => "openai",
                "model" => "gpt-4",
                "temperature" => 0.7,
                "max_tokens" => 1000
            )
        end

        # Set default memory config if not provided
        if isempty(memory_config)
            memory_config = Dict(
                "max_size" => 1000,
                "retention_policy" => "lru"
            )
        end

        new(
            name,
            chains,
            risk_level,
            max_position_size,
            take_profit,
            stop_loss,
            trading_pairs,
            strategies,
            parameters,
            llm_config,
            memory_config
        )
    end
end

"""
    createTradingAgent(config::TradingAgentConfig)

Create a new trading agent with the specified configuration.

# Arguments
- `config::TradingAgentConfig`: Configuration for the new trading agent

# Returns
- `Agent`: The created agent
"""
function createTradingAgent(config::TradingAgentConfig)
    # Create agent abilities based on trading strategies
    abilities = String[]
    for strategy in config.strategies
        push!(abilities, "trading_strategy_$(strategy)")
    end
    push!(abilities, "market_analysis")
    push!(abilities, "portfolio_management")

    # Create agent parameters
    parameters = Dict{String, Any}(
        "risk_level" => config.risk_level,
        "max_position_size" => config.max_position_size,
        "take_profit" => config.take_profit,
        "stop_loss" => config.stop_loss,
        "trading_pairs" => config.trading_pairs,
        "strategies" => config.strategies
    )

    # Merge with additional parameters
    for (key, value) in config.parameters
        parameters[key] = value
    end

    # Create agent config
    agent_config = Agents.AgentConfig(
        config.name,
        Agents.AgentType.TRADING,
        abilities=abilities,
        chains=config.chains,
        parameters=parameters,
        llm_config=config.llm_config,
        memory_config=config.memory_config
    )

    # Create the agent
    return Agents.createAgent(agent_config)
end

"""
    executeTrade(agent::Agents.Agent, trade::Dict{String, Any})

Execute a trade with the specified agent.

# Arguments
- `agent::Agents.Agent`: The trading agent
- `trade::Dict{String, Any}`: Trade specification

# Returns
- `Dict`: Trade result
"""
function executeTrade(agent::Agents.Agent, trade::Dict{String, Any})
    # Validate agent type
    if agent.type != Agents.AgentType.TRADING
        throw(ArgumentError("Agent is not a trading agent"))
    end

    # Validate trade parameters
    if !haskey(trade, "pair")
        throw(ArgumentError("Trade must specify a trading pair"))
    end
    if !haskey(trade, "side")
        throw(ArgumentError("Trade must specify a side (buy/sell)"))
    end
    if !haskey(trade, "amount")
        throw(ArgumentError("Trade must specify an amount"))
    end

    # Execute the trade via the agent task system
    task = Dict{String, Any}(
        "action" => "execute_trade",
        "trade" => trade
    )

    return Agents.executeAgentTask(agent.id, task)
end

"""
    getPortfolio(agent::Agents.Agent)

Get the current portfolio of a trading agent.

# Arguments
- `agent::Agents.Agent`: The trading agent

# Returns
- `Dict`: Portfolio information
"""
function getPortfolio(agent::Agents.Agent)
    # Validate agent type
    if agent.type != Agents.AgentType.TRADING
        throw(ArgumentError("Agent is not a trading agent"))
    end

    # Get the portfolio via the agent task system
    task = Dict{String, Any}(
        "action" => "get_portfolio"
    )

    return Agents.executeAgentTask(agent.id, task)
end

"""
    getTradeHistory(agent::Agents.Agent; limit::Int=10)

Get the trade history of a trading agent.

# Arguments
- `agent::Agents.Agent`: The trading agent
- `limit::Int`: Maximum number of trades to return

# Returns
- `Dict`: Trade history
"""
function getTradeHistory(agent::Agents.Agent; limit::Int=10)
    # Validate agent type
    if agent.type != Agents.AgentType.TRADING
        throw(ArgumentError("Agent is not a trading agent"))
    end

    # Get the trade history via the agent task system
    task = Dict{String, Any}(
        "action" => "get_trade_history",
        "limit" => limit
    )

    return Agents.executeAgentTask(agent.id, task)
end

end # module
