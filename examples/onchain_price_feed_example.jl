"""
    onchain_price_feed_example.jl

Example demonstrating on-chain Chainlink price feed integration in JuliaOS.
"""

# Add the parent directory to the load path
push!(LOAD_PATH, joinpath(@__DIR__, ".."))

# Import required modules
using Random
using Statistics
using Dates

# Import JuliaOS modules
include("../julia/src/blockchain/Blockchain.jl")
include("../julia/src/price/PriceFeeds.jl")

using .Blockchain
using .PriceFeeds

# Set random seed for reproducibility
Random.seed!(42)

"""
    run_onchain_price_feed_example()

Run an on-chain Chainlink price feed example.
"""
function run_onchain_price_feed_example()
    println("On-Chain Chainlink Price Feed Example")
    println("=====================================")
    
    # Create an Ethereum provider
    ethereum_config = EthereumConfig(
        rpc_url = "https://mainnet.infura.io/v3/your-api-key",  # Replace with your actual API key
        chain_id = 1  # Ethereum mainnet
    )
    ethereum_provider = create_provider(ethereum_config)
    
    # Create a Chainlink price feed configuration
    chainlink_config = PriceFeedConfig(
        name = "Chainlink (On-Chain)",
        cache_duration = 60  # Cache for 60 seconds
    )
    
    # Create an on-chain Chainlink price feed
    chainlink = create_chainlink_onchain_feed(chainlink_config, ethereum_provider)
    
    # Get information about the price feed
    info = PriceFeeds.get_price_feed_info(chainlink)
    
    println("Price feed: $(info["name"])")
    println("Supported pairs: $(length(info["supported_pairs"]))")
    
    # List some supported pairs
    println("\nSupported pairs:")
    for pair in info["supported_pairs"][1:min(5, length(info["supported_pairs"]))]
        println("  $pair")
    end
    
    # Get the latest price for ETH/USD
    latest_price = PriceFeeds.get_latest_price(chainlink, "ETH", "USD")
    
    println("\nLatest ETH/USD price:")
    println("  Price: \$$(latest_price.price)")
    println("  Timestamp: $(latest_price.timestamp)")
    
    # Get historical prices for ETH/USD
    historical_prices = PriceFeeds.get_historical_prices(
        chainlink,
        "ETH",
        "USD";
        interval = "1d",
        limit = 10
    )
    
    println("\nHistorical ETH/USD prices:")
    println("  Number of data points: $(length(historical_prices.points))")
    
    if length(historical_prices.points) > 0
        println("  First data point: \$$(historical_prices.points[1].price) at $(historical_prices.points[1].timestamp)")
        
        if length(historical_prices.points) > 1
            println("  Last data point: \$$(historical_prices.points[end].price) at $(historical_prices.points[end].timestamp)")
        end
    end
    
    # Get prices for other pairs
    println("\nPrices for other pairs:")
    
    for pair in ["BTC/USD", "LINK/USD", "UNI/USD"]
        try
            price = PriceFeeds.get_latest_price(chainlink, split(pair, "/")[1], split(pair, "/")[2])
            println("  $pair: \$$(price.price)")
        catch e
            println("  $pair: Error - $e")
        end
    end
    
    return Dict(
        "feed" => chainlink,
        "latest_price" => latest_price,
        "historical_prices" => historical_prices
    )
end

# Run the example if this file is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    result = run_onchain_price_feed_example()
end
