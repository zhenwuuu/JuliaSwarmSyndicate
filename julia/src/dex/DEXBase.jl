"""
DEXBase.jl - Base module for DEX (Decentralized Exchange) integrations

This module provides the base types and interfaces for integrating with
decentralized exchanges in JuliaOS.
"""
module DEXBase

export AbstractDEX, DEXConfig, DEXOrder, DEXTrade, DEXPair, DEXToken
export OrderType, OrderSide, OrderStatus, TradeStatus
export get_price, get_liquidity, create_order, cancel_order, get_order_status
export get_trades, get_pairs, get_tokens, get_balance, get_trading_pairs

# ===== Enums =====

"""
    OrderType

Enum representing the type of order.
"""
@enum OrderType begin
    MARKET
    LIMIT
    STOP_LIMIT
    STOP_MARKET
end

"""
    OrderSide

Enum representing the side of an order (buy or sell).
"""
@enum OrderSide begin
    BUY
    SELL
end

"""
    OrderStatus

Enum representing the status of an order.
"""
@enum OrderStatus begin
    PENDING
    OPEN
    PARTIALLY_FILLED
    FILLED
    CANCELED
    REJECTED
    EXPIRED
end

"""
    TradeStatus

Enum representing the status of a trade.
"""
@enum TradeStatus begin
    PENDING_TX
    CONFIRMING
    CONFIRMED
    FAILED
end

# ===== Types =====

"""
    DEXToken

Structure representing a token on a DEX.

# Fields
- `address::String`: The token's contract address
- `symbol::String`: The token's symbol (e.g., "ETH", "USDC")
- `name::String`: The token's name (e.g., "Ethereum", "USD Coin")
- `decimals::Int`: The token's decimal places
- `chain_id::Int`: The chain ID where the token exists
"""
struct DEXToken
    address::String
    symbol::String
    name::String
    decimals::Int
    chain_id::Int
end

"""
    DEXPair

Structure representing a trading pair on a DEX.

# Fields
- `id::String`: Unique identifier for the pair
- `token0::DEXToken`: The base token
- `token1::DEXToken`: The quote token
- `fee::Float64`: The fee percentage for trading this pair
- `protocol::String`: The protocol name (e.g., "Uniswap", "SushiSwap")
"""
struct DEXPair
    id::String
    token0::DEXToken
    token1::DEXToken
    fee::Float64
    protocol::String
end

"""
    DEXOrder

Structure representing an order on a DEX.

# Fields
- `id::String`: Unique identifier for the order
- `pair::DEXPair`: The trading pair
- `order_type::OrderType`: The type of order
- `side::OrderSide`: The side of the order (buy or sell)
- `amount::Float64`: The amount of the base token
- `price::Float64`: The price in terms of the quote token
- `status::OrderStatus`: The status of the order
- `timestamp::Float64`: The timestamp when the order was created
- `tx_hash::String`: The transaction hash (if applicable)
- `metadata::Dict{String, Any}`: Additional metadata
"""
mutable struct DEXOrder
    id::String
    pair::DEXPair
    order_type::OrderType
    side::OrderSide
    amount::Float64
    price::Float64
    status::OrderStatus
    timestamp::Float64
    tx_hash::String
    metadata::Dict{String, Any}
end

"""
    DEXTrade

Structure representing a trade on a DEX.

# Fields
- `id::String`: Unique identifier for the trade
- `order_id::String`: The ID of the order that generated this trade
- `pair::DEXPair`: The trading pair
- `side::OrderSide`: The side of the trade (buy or sell)
- `amount::Float64`: The amount of the base token
- `price::Float64`: The price in terms of the quote token
- `fee::Float64`: The fee paid for this trade
- `status::TradeStatus`: The status of the trade
- `timestamp::Float64`: The timestamp when the trade occurred
- `tx_hash::String`: The transaction hash
- `metadata::Dict{String, Any}`: Additional metadata
"""
mutable struct DEXTrade
    id::String
    order_id::String
    pair::DEXPair
    side::OrderSide
    amount::Float64
    price::Float64
    fee::Float64
    status::TradeStatus
    timestamp::Float64
    tx_hash::String
    metadata::Dict{String, Any}
end

"""
    DEXConfig

Structure representing the configuration for a DEX.

# Fields
- `name::String`: The name of the DEX
- `chain_id::Int`: The chain ID where the DEX operates
- `rpc_url::String`: The RPC URL for the blockchain
- `router_address::String`: The address of the DEX router contract
- `factory_address::String`: The address of the DEX factory contract
- `api_key::String`: API key (if applicable)
- `private_key::String`: Private key for signing transactions
- `gas_limit::Int`: Gas limit for transactions
- `gas_price::Float64`: Gas price in native currency
- `slippage::Float64`: Maximum slippage percentage
- `timeout::Int`: Timeout in seconds for API calls
- `metadata::Dict{String, Any}`: Additional metadata
"""
struct DEXConfig
    name::String
    chain_id::Int
    rpc_url::String
    router_address::String
    factory_address::String
    api_key::String
    private_key::String
    gas_limit::Int
    gas_price::Float64
    slippage::Float64
    timeout::Int
    metadata::Dict{String, Any}

    function DEXConfig(;
        name::String,
        chain_id::Int,
        rpc_url::String,
        router_address::String = "",
        factory_address::String = "",
        api_key::String = "",
        private_key::String = "",
        gas_limit::Int = 300000,
        gas_price::Float64 = 5.0,
        slippage::Float64 = 0.5,
        timeout::Int = 30,
        metadata::Dict{String, Any} = Dict{String, Any}()
    )
        new(name, chain_id, rpc_url, router_address, factory_address,
            api_key, private_key, gas_limit, gas_price, slippage, timeout, metadata)
    end
end

"""
    AbstractDEX

Abstract type for DEX implementations.
"""
abstract type AbstractDEX end

# ===== Interface Methods =====

"""
    get_price(dex::AbstractDEX, pair::DEXPair)

Get the current price for a trading pair.

# Arguments
- `dex::AbstractDEX`: The DEX instance
- `pair::DEXPair`: The trading pair

# Returns
- `Float64`: The current price
"""
function get_price(dex::AbstractDEX, pair::DEXPair)
    error("get_price not implemented for $(typeof(dex))")
end

"""
    get_liquidity(dex::AbstractDEX, pair::DEXPair)

Get the current liquidity for a trading pair.

# Arguments
- `dex::AbstractDEX`: The DEX instance
- `pair::DEXPair`: The trading pair

# Returns
- `Tuple{Float64, Float64}`: The liquidity of token0 and token1
"""
function get_liquidity(dex::AbstractDEX, pair::DEXPair)
    error("get_liquidity not implemented for $(typeof(dex))")
end

"""
    create_order(dex::AbstractDEX, pair::DEXPair, order_type::OrderType,
                side::OrderSide, amount::Float64, price::Float64=0.0)

Create a new order on the DEX.

# Arguments
- `dex::AbstractDEX`: The DEX instance
- `pair::DEXPair`: The trading pair
- `order_type::OrderType`: The type of order
- `side::OrderSide`: The side of the order (buy or sell)
- `amount::Float64`: The amount of the base token
- `price::Float64`: The price in terms of the quote token (for limit orders)

# Returns
- `DEXOrder`: The created order
"""
function create_order(dex::AbstractDEX, pair::DEXPair, order_type::OrderType,
                     side::OrderSide, amount::Float64, price::Float64=0.0)
    error("create_order not implemented for $(typeof(dex))")
end

"""
    create_order(dex::AbstractDEX, pair_str::String, side_str::String,
                amount::Float64, price::Float64=0.0)

Create a new order on the DEX using string parameters.

# Arguments
- `dex::AbstractDEX`: The DEX instance
- `pair_str::String`: The trading pair as a string (e.g., "ETH/USDT")
- `side_str::String`: The side of the order ("BUY" or "SELL")
- `amount::Float64`: The amount of the base token
- `price::Float64`: The price in terms of the quote token

# Returns
- `DEXOrder`: The created order
"""
function create_order(dex::AbstractDEX, pair_str::String, side_str::String,
                     amount::Float64, price::Float64=0.0)
    # Get all pairs
    pairs = get_pairs(dex)

    # Find the pair that matches the string
    pair = nothing
    for p in pairs
        if "$(p.token0.symbol)/$(p.token1.symbol)" == pair_str
            pair = p
            break
        end
    end

    if pair === nothing
        error("Trading pair not found: $pair_str")
    end

    # Parse the side
    side = side_str == "BUY" ? BUY : SELL

    # Create the order
    return create_order(dex, pair, MARKET, side, amount, price)
end

"""
    cancel_order(dex::AbstractDEX, order::DEXOrder)

Cancel an existing order on the DEX.

# Arguments
- `dex::AbstractDEX`: The DEX instance
- `order::DEXOrder`: The order to cancel

# Returns
- `Bool`: Whether the cancellation was successful
"""
function cancel_order(dex::AbstractDEX, order::DEXOrder)
    error("cancel_order not implemented for $(typeof(dex))")
end

"""
    get_order_status(dex::AbstractDEX, order_id::String)

Get the status of an order.

# Arguments
- `dex::AbstractDEX`: The DEX instance
- `order_id::String`: The ID of the order

# Returns
- `DEXOrder`: The updated order
"""
function get_order_status(dex::AbstractDEX, order_id::String)
    error("get_order_status not implemented for $(typeof(dex))")
end

"""
    get_trades(dex::AbstractDEX, pair::DEXPair; limit::Int=100, from_time::Float64=0.0)

Get recent trades for a trading pair.

# Arguments
- `dex::AbstractDEX`: The DEX instance
- `pair::DEXPair`: The trading pair
- `limit::Int`: Maximum number of trades to return
- `from_time::Float64`: Timestamp to start from

# Returns
- `Vector{DEXTrade}`: Recent trades
"""
function get_trades(dex::AbstractDEX, pair::DEXPair; limit::Int=100, from_time::Float64=0.0)
    error("get_trades not implemented for $(typeof(dex))")
end

"""
    get_pairs(dex::AbstractDEX; limit::Int=100)

Get available trading pairs on the DEX.

# Arguments
- `dex::AbstractDEX`: The DEX instance
- `limit::Int`: Maximum number of pairs to return

# Returns
- `Vector{DEXPair}`: Available trading pairs
"""
function get_pairs(dex::AbstractDEX; limit::Int=100)
    error("get_pairs not implemented for $(typeof(dex))")
end

"""
    get_tokens(dex::AbstractDEX; limit::Int=100)

Get available tokens on the DEX.

# Arguments
- `dex::AbstractDEX`: The DEX instance
- `limit::Int`: Maximum number of tokens to return

# Returns
- `Vector{DEXToken}`: Available tokens
"""
function get_tokens(dex::AbstractDEX; limit::Int=100)
    error("get_tokens not implemented for $(typeof(dex))")
end

"""
    get_balance(dex::AbstractDEX, token::DEXToken, address::String="")

Get the balance of a token for the configured wallet or a specific address.

# Arguments
- `dex::AbstractDEX`: The DEX instance
- `token::DEXToken`: The token
- `address::String`: The address (if empty, uses the configured wallet)

# Returns
- `Float64`: The balance
"""
function get_balance(dex::AbstractDEX, token::DEXToken, address::String="")
    error("get_balance not implemented for $(typeof(dex))")
end

"""
    get_trading_pairs(dex::AbstractDEX)

Get available trading pairs on the DEX as strings (e.g., "ETH/USDT").

# Arguments
- `dex::AbstractDEX`: The DEX instance

# Returns
- `Vector{String}`: Available trading pairs as strings
"""
function get_trading_pairs(dex::AbstractDEX)
    # Get the pairs
    pairs = get_pairs(dex)

    # Convert to strings
    return ["$(pair.token0.symbol)/$(pair.token1.symbol)" for pair in pairs]
end

end # module
