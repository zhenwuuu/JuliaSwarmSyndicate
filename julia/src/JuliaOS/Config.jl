module Config

using JSON
using Dates
using Printf
using Logging

# Configuration types
struct ChainConfig
    rpc_url::String
    chain_id::Int
    gas_limit::Int
    gas_price::Float64
    confirmations::Int
    timeout::Int
end

struct BridgeConfig
    chains::Dict{String, ChainConfig}
    max_pending_txs::Int
    retry_attempts::Int
    retry_delay::Int
    timeout::Int
end

struct AgentConfig
    type::String
    strategy::String
    chains::Vector{String}
    risk_params::Dict{String, Any}
    performance_thresholds::Dict{String, Float64}
    monitoring_interval::Int
end

struct SwarmConfig
    name::String
    algorithm::String
    population_size::Int
    trading_pairs::Vector{String}
    algo_params::Dict{String, Any}
    risk_params::Dict{String, Any}
    performance_thresholds::Dict{String, Float64}
end

struct DashboardConfig
    host::String
    port::Int
    update_interval::Int
    max_history::Int
    alert_thresholds::Dict{String, Float64}
end

# Main configuration struct
mutable struct JuliaOSConfig
    environment::String
    api_keys::Dict{String, String}
    bridge::BridgeConfig
    agents::Dict{String, AgentConfig}
    swarms::Dict{String, SwarmConfig}
    dashboard::DashboardConfig
    logging::Dict{String, Any}
    backup::Dict{String, Any}
end

# Default configurations
const DEFAULT_CONFIG = JuliaOSConfig(
    "development",
    Dict{String, String}(),
    BridgeConfig(
        Dict{String, ChainConfig}(),
        100,
        3,
        30,
        12
    ),
    Dict{String, AgentConfig}(),
    Dict{String, SwarmConfig}(),
    DashboardConfig(
        "127.0.0.1",
        8000,
        5,
        1000,
        Dict(
            "max_drawdown" => 0.1,
            "min_win_rate" => 0.5,
            "min_sharpe" => 1.0
        )
    ),
    Dict(
        "level" => "INFO",
        "file" => "juliaos.log",
        "max_size" => 10_000_000,
        "backup_count" => 5
    ),
    Dict(
        "enabled" => true,
        "interval" => 3600,
        "max_backups" => 24,
        "path" => "backups"
    )
)

# Configuration validation
function validate_chain_config(config::ChainConfig)
    if isempty(config.rpc_url)
        throw(ArgumentError("RPC URL cannot be empty"))
    end
    if config.chain_id <= 0
        throw(ArgumentError("Chain ID must be positive"))
    end
    if config.gas_limit <= 0
        throw(ArgumentError("Gas limit must be positive"))
    end
    if config.gas_price <= 0
        throw(ArgumentError("Gas price must be positive"))
    end
    if config.confirmations < 0
        throw(ArgumentError("Confirmations cannot be negative"))
    end
    if config.timeout <= 0
        throw(ArgumentError("Timeout must be positive"))
    end
    return true
end

function validate_bridge_config(config::BridgeConfig)
    if isempty(config.chains)
        throw(ArgumentError("At least one chain must be configured"))
    end
    for (chain, chain_config) in config.chains
        validate_chain_config(chain_config)
    end
    if config.max_pending_txs <= 0
        throw(ArgumentError("Max pending transactions must be positive"))
    end
    if config.retry_attempts < 0
        throw(ArgumentError("Retry attempts cannot be negative"))
    end
    if config.retry_delay <= 0
        throw(ArgumentError("Retry delay must be positive"))
    end
    if config.timeout <= 0
        throw(ArgumentError("Timeout must be positive"))
    end
    return true
end

function validate_agent_config(config::AgentConfig)
    if isempty(config.type)
        throw(ArgumentError("Agent type cannot be empty"))
    end
    if isempty(config.strategy)
        throw(ArgumentError("Strategy cannot be empty"))
    end
    if isempty(config.chains)
        throw(ArgumentError("At least one chain must be specified"))
    end
    if isempty(config.risk_params)
        throw(ArgumentError("Risk parameters cannot be empty"))
    end
    if isempty(config.performance_thresholds)
        throw(ArgumentError("Performance thresholds cannot be empty"))
    end
    if config.monitoring_interval <= 0
        throw(ArgumentError("Monitoring interval must be positive"))
    end
    return true
end

function validate_swarm_config(config::SwarmConfig)
    if isempty(config.name)
        throw(ArgumentError("Swarm name cannot be empty"))
    end
    if isempty(config.algorithm)
        throw(ArgumentError("Algorithm cannot be empty"))
    end
    if config.population_size <= 0
        throw(ArgumentError("Population size must be positive"))
    end
    if isempty(config.trading_pairs)
        throw(ArgumentError("At least one trading pair must be specified"))
    end
    if isempty(config.algo_params)
        throw(ArgumentError("Algorithm parameters cannot be empty"))
    end
    if isempty(config.risk_params)
        throw(ArgumentError("Risk parameters cannot be empty"))
    end
    if isempty(config.performance_thresholds)
        throw(ArgumentError("Performance thresholds cannot be empty"))
    end
    return true
end

function validate_dashboard_config(config::DashboardConfig)
    if isempty(config.host)
        throw(ArgumentError("Host cannot be empty"))
    end
    if config.port <= 0
        throw(ArgumentError("Port must be positive"))
    end
    if config.update_interval <= 0
        throw(ArgumentError("Update interval must be positive"))
    end
    if config.max_history <= 0
        throw(ArgumentError("Max history must be positive"))
    end
    if isempty(config.alert_thresholds)
        throw(ArgumentError("Alert thresholds cannot be empty"))
    end
    return true
end

function validate_config(config::JuliaOSConfig)
    if isempty(config.environment)
        throw(ArgumentError("Environment cannot be empty"))
    end
    validate_bridge_config(config.bridge)
    for (name, agent_config) in config.agents
        validate_agent_config(agent_config)
    end
    for (name, swarm_config) in config.swarms
        validate_swarm_config(swarm_config)
    end
    validate_dashboard_config(config.dashboard)
    return true
end

# Configuration loading and saving
function load_config(path::String)
    try
        config_data = JSON.parsefile(path)
        config = JuliaOSConfig(
            config_data["environment"],
            config_data["api_keys"],
            BridgeConfig(
                Dict(k => ChainConfig(v...) for (k, v) in config_data["bridge"]["chains"]),
                config_data["bridge"]["max_pending_txs"],
                config_data["bridge"]["retry_attempts"],
                config_data["bridge"]["retry_delay"],
                config_data["bridge"]["timeout"]
            ),
            Dict(k => AgentConfig(v...) for (k, v) in config_data["agents"]),
            Dict(k => SwarmConfig(v...) for (k, v) in config_data["swarms"]),
            DashboardConfig(
                config_data["dashboard"]["host"],
                config_data["dashboard"]["port"],
                config_data["dashboard"]["update_interval"],
                config_data["dashboard"]["max_history"],
                config_data["dashboard"]["alert_thresholds"]
            ),
            config_data["logging"],
            config_data["backup"]
        )
        validate_config(config)
        return config
    catch e
        @error "Error loading configuration: $e"
        return DEFAULT_CONFIG
    end
end

function save_config(config::JuliaOSConfig, path::String)
    try
        config_data = Dict(
            "environment" => config.environment,
            "api_keys" => config.api_keys,
            "bridge" => Dict(
                "chains" => Dict(k => Dict(
                    "rpc_url" => v.rpc_url,
                    "chain_id" => v.chain_id,
                    "gas_limit" => v.gas_limit,
                    "gas_price" => v.gas_price,
                    "confirmations" => v.confirmations,
                    "timeout" => v.timeout
                ) for (k, v) in config.bridge.chains),
                "max_pending_txs" => config.bridge.max_pending_txs,
                "retry_attempts" => config.bridge.retry_attempts,
                "retry_delay" => config.bridge.retry_delay,
                "timeout" => config.bridge.timeout
            ),
            "agents" => Dict(k => Dict(
                "type" => v.type,
                "strategy" => v.strategy,
                "chains" => v.chains,
                "risk_params" => v.risk_params,
                "performance_thresholds" => v.performance_thresholds,
                "monitoring_interval" => v.monitoring_interval
            ) for (k, v) in config.agents),
            "swarms" => Dict(k => Dict(
                "name" => v.name,
                "algorithm" => v.algorithm,
                "population_size" => v.population_size,
                "trading_pairs" => v.trading_pairs,
                "algo_params" => v.algo_params,
                "risk_params" => v.risk_params,
                "performance_thresholds" => v.performance_thresholds
            ) for (k, v) in config.swarms),
            "dashboard" => Dict(
                "host" => config.dashboard.host,
                "port" => config.dashboard.port,
                "update_interval" => config.dashboard.update_interval,
                "max_history" => config.dashboard.max_history,
                "alert_thresholds" => config.dashboard.alert_thresholds
            ),
            "logging" => config.logging,
            "backup" => config.backup
        )
        open(path, "w") do f
            JSON.print(f, config_data, 2)
        end
        return true
    catch e
        @error "Error saving configuration: $e"
        return false
    end
end

# Configuration backup
function backup_config(config::JuliaOSConfig)
    if !config.backup["enabled"]
        return false
    end
    
    try
        timestamp = Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")
        backup_dir = config.backup["path"]
        if !isdir(backup_dir)
            mkpath(backup_dir)
        end
        
        backup_path = joinpath(backup_dir, "config_$(timestamp).json")
        save_config(config, backup_path)
        
        # Clean up old backups
        if config.backup["max_backups"] > 0
            backups = sort(filter(f -> startswith(f, "config_"), readdir(backup_dir)))
            while length(backups) > config.backup["max_backups"]
                rm(joinpath(backup_dir, popfirst!(backups)))
            end
        end
        
        return true
    catch e
        @error "Error backing up configuration: $e"
        return false
    end
end

# Configuration restoration
function restore_config(backup_path::String)
    try
        return load_config(backup_path)
    catch e
        @error "Error restoring configuration: $e"
        return nothing
    end
end

# Export main functions
export JuliaOSConfig, DEFAULT_CONFIG, load_config, save_config, backup_config, restore_config

end # module 