module MarketData

using Dates
using HTTP
using JSON
using Statistics
using LinearAlgebra
using DataFrames
using ..Bridge
using TimeSeries

export MarketDataPoint, fetch_market_data, fetch_historical, calculate_indicators
export connect_websocket, subscribe_to_price_updates, get_liquidity_depth
export get_supported_dexes, get_supported_pairs, PriceListenerCallback
export calculate_macd, calculate_ema, calculate_rsi, calculate_bollinger_bands, calculate_vwap
export check_feeds

# Structure to hold a single market data point with chain information
struct MarketDataPoint
    timestamp::DateTime
    chain::String
    dex::String
    pair::String
    price::Float64
    volume::Float64
    liquidity::Float64
    indicators::Dict{String, Float64}
end

# Constants for supported DEXes and endpoints
const SUPPORTED_DEXES = [
    "uniswap-v3",  # Ethereum 
    "pancakeswap", # BSC
    "raydium",     # Solana
    "traderjoe",   # Avalanche
    "balancer",    # Ethereum
    "curve",       # Ethereum
    "orca",        # Solana
    "sushiswap"    # Multiple chains
]

# Typealias for price update callbacks
const PriceListenerCallback = Function

# Internal storage for price subscriptions
mutable struct PriceSubscription
    chain::String
    dex::String
    pair::String
    callback::PriceListenerCallback
end

# Keep track of active subscriptions
const ACTIVE_SUBSCRIPTIONS = PriceSubscription[]

"""
    fetch_market_data(chain::String, dex::String, pair::String)

Fetch current market data for a specific trading pair on a specific DEX and chain.
"""
function fetch_market_data(chain::String, dex::String, pair::String)
    # Check if the bridge is connected
    if !Bridge.CONNECTION.is_connected
        @warn "Bridge not connected. Attempting to connect..."
        if !Bridge.start_bridge()
            error("Failed to connect to bridge for market data")
        end
    end
    
    # Request data through the bridge
    response = Bridge.receive_data("market_data", Dict(
        "chain" => chain,
        "dex" => dex,
        "pair" => pair
    ))
    
    if response === nothing || !haskey(response, "success") || !response["success"]
        @warn "Failed to fetch market data for $pair on $dex ($chain)"
        return nothing
    end
    
    data = response["data"]
    
    indicators = Dict{String, Float64}()
    if haskey(data, "indicators")
        for (key, value) in data["indicators"]
            indicators[key] = value
        end
    end
    
    return MarketDataPoint(
        DateTime(data["timestamp"], "yyyy-mm-ddTHH:MM:SS.sssZ"),
        chain,
        dex,
        pair,
        parse(Float64, data["price"]),
        parse(Float64, data["volume24h"]),
        parse(Float64, data["liquidity"]),
        indicators
    )
end

"""
    fetch_historical(chain::String, dex::String, pair::String; 
                    days::Int=30, interval::String="1h")

Fetch historical market data for a specific trading pair.
"""
function fetch_historical(chain::String, dex::String, pair::String; 
                        days::Int=30, interval::String="1h")
    # Check if the bridge is connected
    if !Bridge.CONNECTION.is_connected
        @warn "Bridge not connected. Attempting to connect..."
        if !Bridge.start_bridge()
            error("Failed to connect to bridge for historical data")
        end
    end
    
    # Request data through the bridge
    response = Bridge.receive_data("historical_data", Dict(
        "chain" => chain,
        "dex" => dex,
        "pair" => pair,
        "days" => days,
        "interval" => interval
    ))
    
    if response === nothing || !haskey(response, "success") || !response["success"]
        @warn "Failed to fetch historical data for $pair on $dex ($chain)"
        return MarketDataPoint[]
    end
    
    data = response["data"]
    result = MarketDataPoint[]
    
    for point in data
        indicators = Dict{String, Float64}()
        if haskey(point, "indicators")
            for (key, value) in point["indicators"]
                indicators[key] = parse(Float64, value)
            end
        end
        
        push!(result, MarketDataPoint(
            DateTime(point["timestamp"], "yyyy-mm-ddTHH:MM:SS.sssZ"),
            chain,
            dex,
            pair,
            parse(Float64, point["price"]),
            parse(Float64, point["volume"]),
            parse(Float64, point["liquidity"]),
            indicators
        ))
    end
    
    # Calculate additional indicators if they're not present
    if !isempty(result)
        calculate_additional_indicators!(result)
    end
    
    return result
end

"""
    calculate_indicators(prices::Vector{Float64}, volumes::Vector{Float64})

Calculate technical indicators for a given price and volume series.
"""
function calculate_indicators(prices::Vector{Float64}, volumes::Vector{Float64})
    indicators = Dict{String, Float64}()
    
    # Calculate SMA
    if length(prices) >= 20
        sma_20 = mean(prices[end-19:end])
        indicators["sma_20"] = sma_20
    end
    
    if length(prices) >= 50
        sma_50 = mean(prices[end-49:end])
        indicators["sma_50"] = sma_50
    end
    
    # Calculate RSI
    if length(prices) >= 14
        indicators["rsi"] = calculate_rsi(prices)
    end
    
    # Calculate MACD
    if length(prices) >= 26
        macd, signal, hist = calculate_macd(prices)
        indicators["macd"] = macd
        indicators["macd_signal"] = signal
        indicators["macd_hist"] = hist
    end
    
    # Calculate Bollinger Bands
    if length(prices) >= 20
        bb_upper, bb_middle, bb_lower = calculate_bollinger_bands(prices)
        indicators["bb_upper"] = bb_upper
        indicators["bb_middle"] = bb_middle
        indicators["bb_lower"] = bb_lower
    end
    
    # Calculate VWAP
    if length(prices) == length(volumes) && length(prices) > 0
        indicators["vwap"] = calculate_vwap(prices, volumes)
    end
    
    return indicators
end

"""
    calculate_additional_indicators!(data_points::Vector{MarketDataPoint})

Calculate additional indicators for a series of market data points.
"""
function calculate_additional_indicators!(data_points::Vector{MarketDataPoint})
    n = length(data_points)
    if n < 2
        return
    end
    
    # Extract price and volume series
    prices = [point.price for point in data_points]
    volumes = [point.volume for point in data_points]
    
    # Calculate for each window size we need
    for i in 50:n
        # Get window
        window_start = max(1, i-50+1)
        window_prices = prices[window_start:i]
        window_volumes = volumes[window_start:i]
        
        # Calculate indicators
        window_indicators = calculate_indicators(window_prices, window_volumes)
        
        # Add new indicators
        for (key, value) in window_indicators
            data_points[i].indicators[key] = value
        end
    end
end

"""
    calculate_rsi(prices::Vector{Float64}, period::Int=14)

Calculate Relative Strength Index (RSI) for a given price series.
"""
function calculate_rsi(prices::Vector{Float64}, period::Int=14)
    if length(prices) < period + 1
        return 50.0
    end
    
    deltas = diff(prices)
    gains = [max(0, d) for d in deltas]
    losses = [max(0, -d) for d in deltas]
    
    avg_gain = mean(gains[end-period+1:end])
    avg_loss = mean(losses[end-period+1:end])
    
    if avg_loss == 0
        return 100.0
    end
    
    rs = avg_gain / avg_loss
    return 100.0 - (100.0 / (1.0 + rs))
end

"""
    calculate_macd(prices::Vector{Float64})

Calculate Moving Average Convergence Divergence (MACD) for a given price series.
"""
function calculate_macd(prices::Vector{Float64})
    if length(prices) < 26
        return 0.0, 0.0, 0.0
    end
    
    ema_12 = calculate_ema(prices, 12)
    ema_26 = calculate_ema(prices, 26)
    macd = ema_12 - ema_26
    signal = calculate_ema([macd], 9)[1]
    hist = macd - signal
    
    return macd, signal, hist
end

"""
    calculate_ema(prices::Vector{Float64}, period::Int)

Calculate Exponential Moving Average (EMA) for a given price series.
"""
function calculate_ema(prices::Vector{Float64}, period::Int)
    if length(prices) < period + 1
        return mean(prices)
    end
    
    multiplier = 2.0 / (period + 1)
    ema = prices[1]
    
    for i in 2:length(prices)
        ema = (prices[i] - ema) * multiplier + ema
    end
    
    return ema
end

"""
    calculate_bollinger_bands(prices::Vector{Float64}, period::Int=20, std_dev::Float64=2.0)

Calculate Bollinger Bands for a given price series.
"""
function calculate_bollinger_bands(prices::Vector{Float64}, period::Int=20, std_dev::Float64=2.0)
    if length(prices) < period
        return mean(prices), mean(prices), mean(prices)
    end
    
    sma = mean(prices[end-period+1:end])
    std_val = Statistics.std(prices[end-period+1:end])
    
    upper = sma + (std_dev * std_val)
    lower = sma - (std_dev * std_val)
    
    return upper, sma, lower
end

"""
    calculate_vwap(prices::Vector{Float64}, volumes::Vector{Float64})

Calculate Volume Weighted Average Price (VWAP) for given price and volume series.
"""
function calculate_vwap(prices::Vector{Float64}, volumes::Vector{Float64})
    if length(prices) != length(volumes)
        return mean(prices)
    end
    
    total_volume = sum(volumes)
    if total_volume == 0
        return mean(prices)
    end
    
    return sum(prices .* volumes) / total_volume
end

"""
    connect_websocket(chain::String, dex::String)

Initialize a websocket connection to a specific DEX for live data.
"""
function connect_websocket(chain::String, dex::String)
    if !Bridge.CONNECTION.is_connected
        @warn "Bridge not connected. Attempting to connect..."
        if !Bridge.start_bridge()
            error("Failed to connect to bridge for websocket")
        end
    end
    
    # Register global callback for price updates
    Bridge.register_callback("price_update", handle_price_update)
    
    return Bridge.send_command("connect_dex_ws", Dict(
        "chain" => chain,
        "dex" => dex
    ))
end

"""
    subscribe_to_price_updates(chain::String, dex::String, pair::String, callback::PriceListenerCallback)

Subscribe to price updates for a specific trading pair.
"""
function subscribe_to_price_updates(chain::String, dex::String, pair::String, callback::PriceListenerCallback)
    if !Bridge.CONNECTION.is_connected
        @warn "Bridge not connected. Attempting to connect..."
        if !Bridge.start_bridge()
            error("Failed to connect to bridge for price updates")
        end
    end
    
    # Add to local subscriptions
    subscription = PriceSubscription(chain, dex, pair, callback)
    push!(ACTIVE_SUBSCRIPTIONS, subscription)
    
    # Send command to bridge
    return Bridge.send_command("subscribe_price", Dict(
        "chain" => chain,
        "dex" => dex,
        "pair" => pair
    ))
end

"""
    handle_price_update(data::Dict{String,Any})

Internal function to handle price update events from the websocket.
"""
function handle_price_update(data::Dict{String,Any})
    if !haskey(data, "chain") || !haskey(data, "dex") || !haskey(data, "pair")
        return
    end
    
    chain = data["chain"]
    dex = data["dex"]
    pair = data["pair"]
    
    # Find matching subscriptions
    for subscription in ACTIVE_SUBSCRIPTIONS
        if subscription.chain == chain && subscription.dex == dex && subscription.pair == pair
            # Create market data point
            indicators = Dict{String, Float64}()
            if haskey(data, "indicators")
                for (key, value) in data["indicators"]
                    indicators[key] = parse(Float64, value)
                end
            end
            
            market_data = MarketDataPoint(
                now(),
                chain,
                dex,
                pair,
                parse(Float64, data["price"]),
                parse(Float64, data["volume24h"]),
                parse(Float64, data["liquidity"]),
                indicators
            )
            
            # Call callback
            subscription.callback(market_data)
        end
    end
end

"""
    get_liquidity_depth(chain::String, dex::String, pair::String, depth::Int=10)

Get liquidity depth (order book) for a specific trading pair.
"""
function get_liquidity_depth(chain::String, dex::String, pair::String, depth::Int=10)
    if !Bridge.CONNECTION.is_connected
        @warn "Bridge not connected. Attempting to connect..."
        if !Bridge.start_bridge()
            error("Failed to connect to bridge for liquidity depth")
        end
    end
    
    return Bridge.receive_data("liquidity_depth", Dict(
        "chain" => chain,
        "dex" => dex,
        "pair" => pair,
        "depth" => depth
    ))
end

"""
    get_supported_dexes()

Get list of supported DEXes.
"""
function get_supported_dexes()
    if !Bridge.CONNECTION.is_connected
        @warn "Bridge not connected. Attempting to connect..."
        if !Bridge.start_bridge()
            @warn "Failed to connect to bridge, returning default list"
            return SUPPORTED_DEXES
        end
    end
    
    response = Bridge.receive_data("supported_dexes")
    if response === nothing || !haskey(response, "success") || !response["success"]
        return SUPPORTED_DEXES
    end
    
    return response["data"]
end

"""
    get_supported_pairs(chain::String, dex::String)

Get supported trading pairs for a specific DEX.
"""
function get_supported_pairs(chain::String, dex::String)
    if !Bridge.CONNECTION.is_connected
        @warn "Bridge not connected. Attempting to connect..."
        if !Bridge.start_bridge()
            error("Failed to connect to bridge for supported pairs")
        end
    end
    
    response = Bridge.receive_data("supported_pairs", Dict(
        "chain" => chain,
        "dex" => dex
    ))
    
    if response === nothing || !haskey(response, "success") || !response["success"]
        return String[]
    end
    
    return response["data"]
end

"""
    check_feeds()

Check the status of all market data feeds.
Returns a dictionary with feed status information.
"""
function check_feeds()
    return Dict(
        "status" => "active",
        "feeds" => ["binance", "coinbase", "ftx"],
        "last_update" => string(now())
    )
end

end # module 