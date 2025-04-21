module SecurityTypes

using JSON
using Dates

export SecurityConfig, SecurityState, SecurityAlert, SecurityIncident
export RiskConfig, RiskState, Portfolio, Position
export CrossChainMonitor, SmartContractMonitor

# Monitor Types
struct CrossChainMonitor
    id::String
    source_chain::String
    destination_chain::String
    bridge_type::String
    status::String
    last_check::DateTime
    metrics::Dict{String, Any}
end

struct SmartContractMonitor
    id::String
    chain::String
    address::String
    contract_type::String
    risk_score::Float64
    last_audit::DateTime
    metrics::Dict{String, Any}
end

# Security Types
struct SecurityAlert
    id::String
    alert_type::String
    severity::String
    source::String
    details::Dict{String, Any}
    timestamp::DateTime
end

struct SecurityIncident
    id::String
    incident_type::String
    severity::String
    alerts::Vector{SecurityAlert}
    status::String
    resolution::Union{Nothing, String}
    timestamp::DateTime
end

struct SecurityConfig
    enabled::Bool
    monitoring_interval::Int
    max_memory::Int
    max_alerts::Int
    max_incidents::Int
    alert_threshold::Float64
    max_retries::Int
    emergency_contacts::Vector{String}
    network_configs::Dict{String, Dict{String, Any}}
    model_path::String
    rules::Dict{String, Dict{String, Any}}
    paused_chains::Vector{String}
end

mutable struct SecurityState
    config::SecurityConfig
    alerts::Vector{SecurityAlert}
    incidents::Vector{SecurityIncident}
    monitors::Dict{String, CrossChainMonitor}
    last_update::DateTime
    status::String
    
    SecurityState(config::SecurityConfig) = new(
        config,
        SecurityAlert[],
        SecurityIncident[],
        Dict{String, CrossChainMonitor}(),
        now(),
        "initializing"
    )
end

# Risk Types
struct Position
    id::String
    portfolio_id::String
    asset::String
    amount::Float64
    entry_price::Float64
    current_price::Float64
    leverage::Float64
    stop_loss::Float64
    take_profit::Float64
    pnl::Float64
    risk_metrics::Dict{String, Float64}
    status::String
end

mutable struct Portfolio
    id::String
    name::String
    total_value::Float64
    positions::Dict{String, Position}
    risk_metrics::Dict{String, Float64}
    last_rebalance::DateTime
    status::String
end

struct RiskConfig
    enabled::Bool
    max_portfolio_value::Float64
    max_position_size::Float64
    max_leverage::Float64
    risk_per_trade::Float64
    max_drawdown::Float64
    stop_loss_pct::Float64
    take_profit_pct::Float64
    rebalance_threshold::Float64
    update_interval::Int
    network_configs::Dict{String, Dict{String, Any}}
    risk_models::Dict{String, Any}
end

mutable struct RiskState
    config::RiskConfig
    portfolios::Dict{String, Portfolio}
    positions::Dict{String, Position}
    risk_metrics::Dict{String, Float64}
    last_update::DateTime
    status::String
end

end # module 