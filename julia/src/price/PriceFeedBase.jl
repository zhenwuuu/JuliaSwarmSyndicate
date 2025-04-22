"""
PriceFeedBase.jl - Base module for price feed integrations

This module provides the base types and interfaces for integrating with
price feeds and oracles in JuliaOS.
"""
module PriceFeedBase

export AbstractPriceFeed, PriceFeedConfig, PriceData, PricePoint
export get_latest_price, get_historical_prices, get_price_feed_info, list_supported_pairs

using Dates

"""
    PricePoint

Structure representing a single price point.

# Fields
- `timestamp::DateTime`: The timestamp of the price point
- `price::Float64`: The price value
- `volume::Float64`: The trading volume (if available)
- `open::Float64`: The opening price (if available)
- `high::Float64`: The highest price (if available)
- `low::Float64`: The lowest price (if available)
- `close::Float64`: The closing price (if available)
"""
struct PricePoint
    timestamp::DateTime
    price::Float64
    volume::Float64
    open::Float64
    high::Float64
    low::Float64
    close::Float64
    
    function PricePoint(
        timestamp::DateTime,
        price::Float64;
        volume::Float64 = 0.0,
        open::Float64 = 0.0,
        high::Float64 = 0.0,
        low::Float64 = 0.0,
        close::Float64 = 0.0
    )
        new(timestamp, price, volume, open, high, low, close)
    end
end

"""
    PriceData

Structure representing a collection of price points.

# Fields
- `base_asset::String`: The base asset (e.g., "ETH")
- `quote_asset::String`: The quote asset (e.g., "USD")
- `source::String`: The source of the price data
- `interval::String`: The interval of the price data (e.g., "1h", "1d")
- `points::Vector{PricePoint}`: The price points
"""
struct PriceData
    base_asset::String
    quote_asset::String
    source::String
    interval::String
    points::Vector{PricePoint}
end

"""
    PriceFeedConfig

Structure representing the configuration for a price feed.

# Fields
- `name::String`: The name of the price feed
- `api_key::String`: API key for the price feed
- `api_secret::String`: API secret for the price feed
- `base_url::String`: Base URL for the price feed API
- `timeout::Int`: Timeout in seconds for API calls
- `cache_duration::Int`: Duration in seconds to cache responses
- `metadata::Dict{String, Any}`: Additional metadata
"""
struct PriceFeedConfig
    name::String
    api_key::String
    api_secret::String
    base_url::String
    timeout::Int
    cache_duration::Int
    metadata::Dict{String, Any}
    
    function PriceFeedConfig(;
        name::String,
        api_key::String = "",
        api_secret::String = "",
        base_url::String = "",
        timeout::Int = 30,
        cache_duration::Int = 60,
        metadata::Dict{String, Any} = Dict{String, Any}()
    )
        new(name, api_key, api_secret, base_url, timeout, cache_duration, metadata)
    end
end

"""
    AbstractPriceFeed

Abstract type for price feed implementations.
"""
abstract type AbstractPriceFeed end

# ===== Interface Methods =====

"""
    get_latest_price(feed::AbstractPriceFeed, base_asset::String, quote_asset::String)

Get the latest price for a trading pair.

# Arguments
- `feed::AbstractPriceFeed`: The price feed instance
- `base_asset::String`: The base asset (e.g., "ETH")
- `quote_asset::String`: The quote asset (e.g., "USD")

# Returns
- `PricePoint`: The latest price point
"""
function get_latest_price(feed::AbstractPriceFeed, base_asset::String, quote_asset::String)
    error("get_latest_price not implemented for $(typeof(feed))")
end

"""
    get_historical_prices(feed::AbstractPriceFeed, base_asset::String, quote_asset::String;
                         interval::String="1d", limit::Int=100, start_time::DateTime=DateTime(0),
                         end_time::DateTime=now())

Get historical prices for a trading pair.

# Arguments
- `feed::AbstractPriceFeed`: The price feed instance
- `base_asset::String`: The base asset (e.g., "ETH")
- `quote_asset::String`: The quote asset (e.g., "USD")
- `interval::String`: The interval of the price data (e.g., "1h", "1d")
- `limit::Int`: Maximum number of price points to return
- `start_time::DateTime`: Start time for the price data
- `end_time::DateTime`: End time for the price data

# Returns
- `PriceData`: The historical price data
"""
function get_historical_prices(feed::AbstractPriceFeed, base_asset::String, quote_asset::String;
                              interval::String="1d", limit::Int=100, start_time::DateTime=DateTime(0),
                              end_time::DateTime=now())
    error("get_historical_prices not implemented for $(typeof(feed))")
end

"""
    get_price_feed_info(feed::AbstractPriceFeed)

Get information about the price feed.

# Arguments
- `feed::AbstractPriceFeed`: The price feed instance

# Returns
- `Dict{String, Any}`: Information about the price feed
"""
function get_price_feed_info(feed::AbstractPriceFeed)
    error("get_price_feed_info not implemented for $(typeof(feed))")
end

"""
    list_supported_pairs(feed::AbstractPriceFeed)

List all supported trading pairs.

# Arguments
- `feed::AbstractPriceFeed`: The price feed instance

# Returns
- `Vector{Tuple{String, String}}`: List of supported trading pairs (base_asset, quote_asset)
"""
function list_supported_pairs(feed::AbstractPriceFeed)
    error("list_supported_pairs not implemented for $(typeof(feed))")
end

end # module
