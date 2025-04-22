"""
DEXIntegration.jl - Main module for DEX (Decentralized Exchange) integrations

This module provides integration with various decentralized exchanges and aggregators.
"""
module DEXIntegration

# Export all submodules
export DEXBase, UniswapDEX, SushiswapDEX, DEXAggregator

# Export key types and functions
export AbstractDEX, DEXConfig, DEXOrder, DEXTrade, DEXPair, DEXToken
export OrderType, OrderSide, OrderStatus, TradeStatus
export get_price, get_liquidity, create_order, cancel_order, get_order_status
export get_trades, get_pairs, get_tokens, get_balance
export Uniswap, UniswapV2, UniswapV3, create_uniswap
export Sushiswap, create_sushiswap
export AbstractAggregator, SimpleAggregator, create_aggregator
export get_best_price, get_best_route, execute_trade, get_supported_dexes

# Include submodules
include("DEXBase.jl")
include("UniswapDEX.jl")
include("SushiswapDEX.jl")
include("DEXAggregator.jl")

# Re-export from submodules
using .DEXBase
using .UniswapDEX
using .SushiswapDEX
using .DEXAggregator

"""
    create_dex(name::String, config::DEXConfig)

Create a DEX instance based on the name.

# Arguments
- `name::String`: The name of the DEX (e.g., "uniswap_v2", "uniswap_v3")
- `config::DEXConfig`: The DEX configuration

# Returns
- `AbstractDEX`: The created DEX instance
"""
function create_dex(name::String, config::DEXConfig)
    if lowercase(name) == "uniswap_v2"
        return UniswapV2(config)
    elseif lowercase(name) == "uniswap_v3"
        return UniswapV3(config)
    elseif lowercase(name) == "sushiswap"
        return create_sushiswap(config)
    else
        error("Unsupported DEX: $name")
    end
end

"""
    create_aggregator_from_names(dex_names::Vector{String}, configs::Vector{DEXConfig})

Create an aggregator from a list of DEX names and configurations.

# Arguments
- `dex_names::Vector{String}`: The names of the DEXes
- `configs::Vector{DEXConfig}`: The configurations for the DEXes

# Returns
- `AbstractAggregator`: The created aggregator
"""
function create_aggregator_from_names(dex_names::Vector{String}, configs::Vector{DEXConfig})
    if length(dex_names) != length(configs)
        error("Number of DEX names must match number of configurations")
    end

    dexes = AbstractDEX[]
    for i in 1:length(dex_names)
        push!(dexes, create_dex(dex_names[i], configs[i]))
    end

    return create_aggregator(dexes)
end

"""
    list_supported_dexes()

List all supported DEXes.

# Returns
- `Vector{String}`: The names of the supported DEXes
"""
function list_supported_dexes()
    return ["uniswap_v2", "uniswap_v3", "sushiswap"]
end

end # module
