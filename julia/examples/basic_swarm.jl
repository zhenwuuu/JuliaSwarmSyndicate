using JuliaOS

# Create a new swarm configuration
config = SwarmConfig(
    "basic_swarm",
    50,  # swarm size
    "pso",  # algorithm type
    ["ETH/USDC"],  # trading pairs
    Dict(
        "w" => 0.7,  # inertia weight
        "c1" => 1.5,  # cognitive weight
        "c2" => 1.5   # social weight
    )
)

# Create and initialize the swarm
swarm = create_swarm(config)

# Simulate some market data
for i in 1:100
    price = 1000.0 + randn() * 50.0
    volume = 1000000.0 + randn() * 100000.0
    market_cap = 1000000000.0 + randn() * 100000000.0
    
    # Calculate technical indicators
    sma_20 = 1000.0 + randn() * 20.0
    sma_50 = 1000.0 + randn() * 30.0
    rsi = rand() * 100.0
    macd = randn() * 2.0
    macd_signal = randn() * 1.5
    macd_hist = macd - macd_signal
    bb_upper = price + rand() * 100.0
    bb_middle = price
    bb_lower = price - rand() * 100.0
    vwap = price + randn() * 10.0
    
    # Create market data point
    data_point = MarketDataPoint(
        now(),
        price,
        volume,
        market_cap,
        Dict(
            "sma_20" => sma_20,
            "sma_50" => sma_50,
            "rsi" => rsi,
            "macd" => macd,
            "macd_signal" => macd_signal,
            "macd_hist" => macd_hist,
            "bb_upper" => bb_upper,
            "bb_middle" => bb_middle,
            "bb_lower" => bb_lower,
            "vwap" => vwap
        )
    )
    
    push!(swarm.market_data, data_point)
end

# Run optimization
println("Starting swarm optimization...")
start_swarm!(swarm, 50)  # 50 iterations

# Print results
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