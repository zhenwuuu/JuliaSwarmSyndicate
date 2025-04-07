using JuliaOS
using Dates

# Note: This example requires API keys to be set in environment variables
# Set your API keys before running:
# ENV["UNISWAP_API_KEY"] = "your_api_key_here"

# Create a new swarm configuration
config = SwarmConfig(
    "real_market_swarm",
    100,  # larger swarm size for better optimization
    "pso",  # algorithm type
    ["ETH/USDC", "SOL/USDC"],  # multiple trading pairs
    Dict(
        "w" => 0.7,  # inertia weight
        "c1" => 1.5,  # cognitive weight
        "c2" => 1.5   # social weight
    )
)

# Create and initialize the swarm
swarm = create_swarm(config)

# Fetch real market data
println("Fetching market data...")
for pair in config.trading_pairs
    data = MarketData.fetch_market_data("uniswap", pair)
    if data !== nothing
        push!(swarm.market_data, data)
        println("Added market data for $pair")
    else
        @warn "Failed to fetch market data for $pair"
    end
end

# Run optimization with more iterations for real market data
println("\nStarting swarm optimization...")
start_swarm!(swarm, 200)  # 200 iterations

# Print detailed results
println("\nOptimization Results:")
println("Best fitness: ", swarm.global_best_fitness)
println("Best position: ", swarm.global_best_position)
println("\nPerformance Metrics:")
println("Sharpe ratio: ", swarm.performance_metrics["sharpe_ratio"])
println("Max drawdown: ", swarm.performance_metrics["max_drawdown"])

# Print portfolio status for the best particle
best_particle = swarm.particles[argmax([p.best_fitness for p in swarm.particles])]
println("\nBest Particle Portfolio:")
for (asset, amount) in best_particle.portfolio
    println("$asset: $amount")
end

# Print trading history
println("\nTrading History:")
for trade in best_particle.trades
    println("$(trade["type"]) at $(trade["price"]) on $(trade["timestamp"])")
end

# Save results to file
results_file = "swarm_results_$(Dates.format(now(), "yyyy-mm-dd_HH-MM-SS")).json"
open(results_file, "w") do f
    JSON.print(f, Dict(
        "best_fitness" => swarm.global_best_fitness,
        "best_position" => swarm.global_best_position,
        "performance_metrics" => swarm.performance_metrics,
        "portfolio" => best_particle.portfolio,
        "trades" => best_particle.trades
    ), 2)
end
println("\nResults saved to $results_file") 