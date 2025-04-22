"""
PriceFeeds.jl - Main module for price feed integrations

This module provides integration with various price feeds and oracles.
"""
module PriceFeeds

# Export all submodules
export PriceFeedBase, ChainlinkFeed, ChainlinkOnChain

# Export key types and functions
export AbstractPriceFeed, PriceFeedConfig, PriceData, PricePoint
export get_latest_price, get_historical_prices, get_price_feed_info, list_supported_pairs
export ChainlinkPriceFeed, create_chainlink_feed
export ChainlinkOnChainFeed, create_chainlink_onchain_feed

# Include submodules
include("PriceFeedBase.jl")
include("ChainlinkFeed.jl")
include("ChainlinkOnChain.jl")

# Re-export from submodules
using .PriceFeedBase
using .ChainlinkFeed
using .ChainlinkOnChain

"""
    create_price_feed(name::String, config::PriceFeedConfig)

Create a price feed instance based on the name.

# Arguments
- `name::String`: The name of the price feed (e.g., "chainlink")
- `config::PriceFeedConfig`: The price feed configuration

# Returns
- `AbstractPriceFeed`: The created price feed instance
"""
function create_price_feed(name::String, config::PriceFeedConfig)
    if lowercase(name) == "chainlink"
        return create_chainlink_feed(config)
    elseif lowercase(name) == "chainlink_onchain"
        return create_chainlink_onchain_feed(config)
    else
        error("Unsupported price feed: $name")
    end
end

"""
    list_supported_price_feeds()

List all supported price feeds.

# Returns
- `Vector{String}`: The names of the supported price feeds
"""
function list_supported_price_feeds()
    return ["chainlink", "chainlink_onchain"]
end

end # module
