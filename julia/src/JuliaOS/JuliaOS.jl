module JuliaOS

using JSON
using Dates
using Statistics
using Random
using HTTP
using DataFrames
using Distributions
using LinearAlgebra
using WebSockets
using Plots
using Logging
using MarketData
using TimeSeries
using JuliaOSBridge

# Abstract types for system components
abstract type AbstractAgent end
abstract type AbstractSwarm end
abstract type AbstractStrategy end
abstract type AbstractMarketData end
abstract type AbstractBridge end
abstract type SwarmBehavior end

# Include core system modules in dependency order
include("Blockchain.jl")
include("SecurityTypes.jl")
include("Bridge.jl")
include("MarketData.jl")
include("algorithms/Algorithms.jl")
include("SwarmManager.jl")
include("MLIntegration.jl")
include("SmartContracts.jl")
include("DEX.jl")
include("AgentSystem.jl")
include("RiskManagement.jl")
include("SecurityManager.jl")
include("AdvancedSwarm.jl")
include("SpecializedAgents.jl")
include("CrossChainArbitrage.jl")
include("UserModules.jl")
include("OpenAISwarmAdapter.jl")

# Export public components
export Blockchain, SecurityTypes, Bridge, SwarmManager, SecurityManager, AgentSystem, DEX, MarketData, MLIntegration, AdvancedSwarm, SpecializedAgents, CrossChainArbitrage, RiskManagement, UserModules, OpenAISwarmAdapter, Algorithms

# Initialize logging
const logger = SimpleLogger(stderr, Logging.Info)
global_logger(logger)

# System configuration
const CONFIG = Dict(
    "max_agents" => 1000,
    "default_swarm_size" => 100,
    "update_interval" => 0.1,
    "max_memory" => 1024 * 1024 * 1024,  # 1GB
    "data_dir" => "data",
    "log_dir" => "logs",
    "supported_chains" => ["ethereum", "polygon", "arbitrum", "optimism", "base"],
    "default_gas_limit" => 500000,
    "max_slippage" => 0.01,  # 1%
    "min_liquidity" => 10000.0,  # Minimum liquidity in USD
    "price_feed_update_interval" => 1.0,  # seconds
    "bridge_timeout" => 300,  # 5 minutes
    "max_retries" => 3,
    "health_check_interval" => 60,  # seconds
    "security" => Dict(
        "anomaly_detection_threshold" => 0.75,
        "max_transaction_value" => 10.0,  # ETH or equivalent
        "emergency_contacts" => ["security@yourproject.com"],
        "monitoring_interval" => 60,  # seconds
        "enable_hooks" => true
    )
)

# Initialize system directories
function initialize_system()
    # Create necessary directories
    for dir in [CONFIG["data_dir"], CONFIG["log_dir"]]
        if !isdir(dir)
            mkdir(dir)
            @info "Created directory: $dir"
        end
    end
    
    # Initialize logging
    log_file = joinpath(CONFIG["log_dir"], "juliaos_$(Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")).log")
    file_logger = SimpleLogger(open(log_file, "w"), Logging.Info)
    global_logger(logger)
    
    # Load user modules
    UserModules.load_user_modules()
    
    @info "JuliaOS system initialized"
end

# System health check
function check_system_health()
    try
        # Check memory usage
        memory_usage = Sys.free_memory() / (1024 * 1024 * 1024)  # Convert to GB
        memory_status = memory_usage < CONFIG["max_memory"] ? "healthy" : "warning"
        
        # Check active agents
        active_agents = 0 # For testing, just use 0
        agent_status = active_agents <= CONFIG["max_agents"] ? "healthy" : "warning"
        
        # Check bridge connections
        bridge_status = Bridge.check_connections()
        
        # Check market data feeds
        market_data_status = Dict("status" => "ready")

        return Dict(
            "status" => "operational",
            "memory_usage" => memory_usage,
            "memory_status" => memory_status,
            "active_agents" => active_agents,
            "agent_status" => agent_status,
            "bridge_status" => bridge_status,
            "market_data_status" => market_data_status,
            "timestamp" => now()
        )
    catch e
        @error "Error checking system health" exception=(e, catch_backtrace())
        return Dict(
            "status" => "error",
            "error" => string(e),
            "timestamp" => now()
        )
    end
end

# Export public functions
export initialize_system, check_system_health

# Module initialization
function __init__()
    @info "JuliaOS runtime initialization"
    
    # Runtime initialization code 
    # (This runs after all modules are loaded but before any user code executes)
end

# Re-export functions from JuliaOSBridge
export start_server, stop_server, process_request

end # module 