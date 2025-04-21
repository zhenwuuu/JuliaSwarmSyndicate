"""
    Bridges Module for JuliaOS

This module serves as the main entry point for all bridge functionality.
It integrates all bridge implementations and provides a unified interface.
"""
module Bridges

export initialize, get_available_bridges, get_bridge, get_available_chains, get_available_tokens,
       bridge_tokens, check_bridge_status, redeem_tokens, get_wrapped_asset_info, check_health

using Logging
using Dates
using JSON

# Include the bridge interface
include("bridge_interface.jl")
using .BridgeInterface

# Include bridge implementations
include("wormhole.jl")
include("axelar.jl")
include("layerzero.jl")
include("stargate.jl")
include("synapse.jl")
include("hop.jl")
include("across.jl")
include("multichain.jl")

# Bridge registry
const BRIDGES = Dict{String, AbstractBridge}()

"""
    initialize(config=nothing)

Initialize the bridge module with the given configuration.
"""
function initialize(config=nothing)
    @info "Initializing Bridges module"
    
    # Initialize bridge implementations
    try
        # Register Wormhole bridge
        BRIDGES["wormhole"] = WormholeBridge.WormholeBridgeImpl()
        WormholeBridge.initialize(BRIDGES["wormhole"], config)
        @info "Wormhole bridge initialized"
    catch e
        @warn "Failed to initialize Wormhole bridge: $e"
    end
    
    try
        # Register Axelar bridge
        BRIDGES["axelar"] = AxelarBridge.AxelarBridgeImpl()
        AxelarBridge.initialize(BRIDGES["axelar"], config)
        @info "Axelar bridge initialized"
    catch e
        @warn "Failed to initialize Axelar bridge: $e"
    end
    
    try
        # Register LayerZero bridge
        BRIDGES["layerzero"] = LayerZeroBridge.LayerZeroBridgeImpl()
        LayerZeroBridge.initialize(BRIDGES["layerzero"], config)
        @info "LayerZero bridge initialized"
    catch e
        @warn "Failed to initialize LayerZero bridge: $e"
    end
    
    try
        # Register Stargate bridge
        BRIDGES["stargate"] = StargateBridge.StargateBridgeImpl()
        StargateBridge.initialize(BRIDGES["stargate"], config)
        @info "Stargate bridge initialized"
    catch e
        @warn "Failed to initialize Stargate bridge: $e"
    end
    
    try
        # Register Synapse bridge
        BRIDGES["synapse"] = SynapseBridge.SynapseBridgeImpl()
        SynapseBridge.initialize(BRIDGES["synapse"], config)
        @info "Synapse bridge initialized"
    catch e
        @warn "Failed to initialize Synapse bridge: $e"
    end
    
    try
        # Register Hop bridge
        BRIDGES["hop"] = HopBridge.HopBridgeImpl()
        HopBridge.initialize(BRIDGES["hop"], config)
        @info "Hop bridge initialized"
    catch e
        @warn "Failed to initialize Hop bridge: $e"
    end
    
    try
        # Register Across bridge
        BRIDGES["across"] = AcrossBridge.AcrossBridgeImpl()
        AcrossBridge.initialize(BRIDGES["across"], config)
        @info "Across bridge initialized"
    catch e
        @warn "Failed to initialize Across bridge: $e"
    end
    
    try
        # Register Multichain bridge
        BRIDGES["multichain"] = MultichainBridge.MultichainBridgeImpl()
        MultichainBridge.initialize(BRIDGES["multichain"], config)
        @info "Multichain bridge initialized"
    catch e
        @warn "Failed to initialize Multichain bridge: $e"
    end
    
    @info "Bridges module initialized with $(length(BRIDGES)) bridges"
end

"""
    get_available_bridges()

Get a list of available bridges.
"""
function get_available_bridges()
    return collect(keys(BRIDGES))
end

"""
    get_bridge(bridge_name::String)

Get a bridge by name.
"""
function get_bridge(bridge_name::String)
    if !haskey(BRIDGES, bridge_name)
        error("Bridge not found: $bridge_name")
    end
    
    return BRIDGES[bridge_name]
end

"""
    get_available_chains(bridge_name::String)

Get a list of available chains for a specific bridge.
"""
function get_available_chains(bridge_name::String)
    bridge = get_bridge(bridge_name)
    return BridgeInterface.get_available_chains(bridge)
end

"""
    get_available_tokens(bridge_name::String, params::Dict)

Get a list of available tokens for a specific chain on a specific bridge.
"""
function get_available_tokens(bridge_name::String, params::Dict)
    bridge = get_bridge(bridge_name)
    return BridgeInterface.get_available_tokens(bridge, params)
end

"""
    bridge_tokens(bridge_name::String, params::Dict)

Bridge tokens from one chain to another using a specific bridge.
"""
function bridge_tokens(bridge_name::String, params::Dict)
    bridge = get_bridge(bridge_name)
    return BridgeInterface.bridge_tokens(bridge, params)
end

"""
    check_bridge_status(bridge_name::String, params::Dict)

Check the status of a bridge transaction on a specific bridge.
"""
function check_bridge_status(bridge_name::String, params::Dict)
    bridge = get_bridge(bridge_name)
    return BridgeInterface.check_bridge_status(bridge, params)
end

"""
    redeem_tokens(bridge_name::String, params::Dict)

Redeem tokens on the target chain using a specific bridge.
"""
function redeem_tokens(bridge_name::String, params::Dict)
    bridge = get_bridge(bridge_name)
    return BridgeInterface.redeem_tokens(bridge, params)
end

"""
    get_wrapped_asset_info(bridge_name::String, params::Dict)

Get information about a wrapped asset on a specific bridge.
"""
function get_wrapped_asset_info(bridge_name::String, params::Dict)
    bridge = get_bridge(bridge_name)
    return BridgeInterface.get_wrapped_asset_info(bridge, params)
end

"""
    check_health(bridge_name::String)

Check the health of a specific bridge.
"""
function check_health(bridge_name::String)
    bridge = get_bridge(bridge_name)
    return BridgeInterface.check_health(bridge)
end

"""
    check_health()

Check the health of all bridges.
"""
function check_health()
    health = Dict{String, Any}()
    
    for (bridge_name, bridge) in BRIDGES
        try
            health[bridge_name] = BridgeInterface.check_health(bridge)
        catch e
            @warn "Failed to check health of $bridge_name bridge: $e"
            health[bridge_name] = Dict(
                "status" => "error",
                "error" => string(e)
            )
        end
    end
    
    # Determine overall status
    all_healthy = all(get(h, "status", "") == "healthy" for (_, h) in health)
    
    return Dict(
        "status" => all_healthy ? "healthy" : "degraded",
        "bridges" => health,
        "timestamp" => string(now())
    )
end

end # module
