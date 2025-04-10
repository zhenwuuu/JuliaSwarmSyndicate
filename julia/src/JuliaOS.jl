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
using JuliaOSBridge
using MarketData
using TimeSeries
using SQLite

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
include("DEX.jl")
include("Storage.jl")
include("Web3Storage.jl")
include("Sync.jl")
include("Bridge.jl")
include("Wallet.jl")
include("WalletIntegration.jl")
include("WormholeBridge.jl")
include("MarketData.jl")
include("algorithms/Algorithms.jl")
include("SwarmManager.jl")
include("MLIntegration.jl")
include("SmartContracts.jl")
include("AgentSystem.jl")
include("RiskManagement.jl")
include("SecurityManager.jl")
include("AdvancedSwarm.jl")
include("SpecializedAgents.jl")
include("CrossChainArbitrage.jl")
include("UserModules.jl")
include("OpenAISwarmAdapter.jl")

# Export public components
export Blockchain, SecurityTypes, Bridge, Wallet, WalletIntegration, WormholeBridge, SwarmManager, SecurityManager, AgentSystem, DEX, MarketData, MLIntegration, AdvancedSwarm, SpecializedAgents, CrossChainArbitrage, RiskManagement, UserModules, OpenAISwarmAdapter, Algorithms, Storage, Web3Storage, Sync

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
    ),
    "storage" => Dict(
        "local_db_path" => joinpath(homedir(), ".juliaos", "juliaos.sqlite"),
        "ceramic_node_url" => get(ENV, "CERAMIC_NODE_URL", "https://ceramic-clay.3boxlabs.com"),
        "ipfs_api_url" => get(ENV, "IPFS_API_URL", "https://api.web3.storage"),
        "ipfs_api_key" => get(ENV, "IPFS_API_KEY", ""),
        "auto_sync_enabled" => false,
        "auto_sync_interval" => 3600  # 1 hour in seconds
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

    # Initialize storage
    Storage.init_db()

    # Configure Web3 storage if API key is available
    if CONFIG["storage"]["ipfs_api_key"] != ""
        Web3Storage.configure(
            ceramic_node_url=CONFIG["storage"]["ceramic_node_url"],
            ipfs_api_url_arg=CONFIG["storage"]["ipfs_api_url"],
            ipfs_api_key_arg=CONFIG["storage"]["ipfs_api_key"]
        )

        # Initialize sync
        Sync.init_sync()
        if CONFIG["storage"]["auto_sync_enabled"]
            Sync.enable_sync(true)
            Sync.set_auto_sync_interval(CONFIG["storage"]["auto_sync_interval"])
        end
    end

    # Load user modules
    UserModules.load_user_modules()

    @info "JuliaOS system initialized"
end

# System health check
function check_system_health()
    cpu_cores = Sys.cpu_info()
    total_memory = Sys.total_memory() / (1024^3)  # Convert to GB
    free_memory = Sys.free_memory() / (1024^3)    # Convert to GB

    bridge_status = try
        Bridge.check_connections()
    catch e
        Dict("status" => "error", "error" => string(e))
    end

    server_status = try
        Server.get_status()
    catch e
        Dict("status" => "error", "error" => string(e))
    end

    storage_status = try
        db_exists = isfile(CONFIG["storage"]["local_db_path"])
        web3_configured = CONFIG["storage"]["ipfs_api_key"] != ""
        sync_status = web3_configured ? Sync.get_sync_status() : Dict("sync_enabled" => false)

        Dict(
            "status" => "healthy",
            "local_db" => db_exists ? "connected" : "not found",
            "web3_storage" => web3_configured ? "configured" : "not configured",
            "sync" => sync_status
        )
    catch e
        Dict("status" => "error", "error" => string(e))
    end

    return Dict(
        "status" => "healthy",
        "timestamp" => now(),
        "cpu" => Dict(
            "cores" => length(cpu_cores),
            "info" => string(cpu_cores[1])
        ),
        "memory" => Dict(
            "total_gb" => total_memory,
            "free_gb" => free_memory,
            "used_percent" => (1 - free_memory/total_memory) * 100
        ),
        "bridge" => bridge_status,
        "server" => server_status,
        "storage" => storage_status,
        "julia_version" => string(VERSION)
    )
end

# Export public functions
export initialize_system, check_system_health

# Module initialization
function __init__()
    @info "JuliaOS runtime initialization"

    # Initialize core systems
    try
        AgentSystem.initialize()
        @info "AgentSystem initialized."
    catch e
        @error "Failed to initialize AgentSystem: $e" stacktrace(catch_backtrace())
    end

    try
        SwarmManager.initialize()
        @info "SwarmManager initialized."
    catch e
        @error "Failed to initialize SwarmManager: $e" stacktrace(catch_backtrace())
    end

    # Runtime initialization code
    # (This runs after all modules are loaded but before any user code executes)
end

end # module