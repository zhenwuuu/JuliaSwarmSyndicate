using Test
using JuliaOS
using Dates
using Statistics
using Random
using LinearAlgebra
using JuliaOS.Swarm

# Test data
test_prices = [100.0, 98.0, 96.0, 94.0, 92.0, 90.0, 88.0, 86.0, 84.0, 82.0, 80.0, 78.0, 76.0, 74.0, 72.0, 70.0, 68.0, 66.0, 64.0, 62.0, 60.0, 58.0, 56.0, 54.0, 52.0, 50.0, 48.0, 46.0, 44.0, 42.0, 40.0, 38.0, 36.0, 34.0, 32.0, 30.0, 28.0, 26.0, 24.0, 22.0, 20.0, 18.0, 16.0, 14.0, 12.0, 10.0, 8.0, 6.0, 4.0, 2.0]
test_volumes = [1000.0, 1200.0, 1100.0, 1300.0, 1400.0, 1200.0, 1100.0, 1300.0, 1400.0, 1200.0, 1100.0, 1300.0, 1400.0, 1200.0, 1100.0, 1300.0, 1400.0, 1200.0, 1100.0, 1300.0, 1400.0, 1200.0, 1100.0, 1300.0, 1400.0, 1200.0, 1100.0, 1300.0, 1400.0, 1200.0, 1100.0, 1300.0, 1400.0, 1200.0, 1100.0, 1300.0, 1400.0, 1200.0, 1100.0, 1300.0, 1400.0, 1200.0, 1100.0, 1300.0, 1400.0, 1200.0, 1100.0, 1300.0, 1400.0, 1200.0]

# Create test market data
test_market_data = MarketData.MarketDataPoint(
    now(),
    test_prices[end],
    test_volumes[end],
    1000000.0,
    Dict(
        "sma_20" => mean(test_prices[end-19:end]),
        "sma_50" => mean(test_prices[end-49:end]),
        "rsi" => 20.0,  # Low RSI to trigger buy signal
        "macd" => -2.0,
        "macd_signal" => -1.5,
        "macd_hist" => -0.5,
        "bb_upper" => 10.0,
        "bb_middle" => 5.0,
        "bb_lower" => 0.0,  # Set Bollinger Bands to ensure bb_position < 0.2
        "vwap" => 95.0
    )
)

# Create test swarm configuration
test_config = SwarmManager.SwarmConfig(
    "test_swarm",
    10,
    "pso",
    ["ETH/USDC"],
    Dict(
        "w" => 0.7,
        "c1" => 1.5,
        "c2" => 1.5
    )
)

@testset "Swarm Creation" begin
    swarm = SwarmManager.create_swarm(test_config)
    
    @test length(swarm.particles) == test_config.size
    @test length(swarm.global_best_position) == 4
    @test swarm.global_best_fitness == -Inf
    @test isempty(swarm.market_data)
    @test isempty(swarm.performance_metrics)
    
    for particle in swarm.particles
        @test length(particle.position) == 4
        @test length(particle.velocity) == 4
        @test length(particle.best_position) == 4
        @test particle.best_fitness == -Inf
        @test haskey(particle.portfolio, "USDC")
        @test particle.portfolio["USDC"] == 10000.0
        @test isempty(particle.trades)
    end
end

@testset "Technical Indicators" begin
    indicators = MarketData.calculate_indicators(test_prices, test_volumes)
    
    @test haskey(indicators, "sma_20")
    @test haskey(indicators, "sma_50")
    @test haskey(indicators, "rsi")
    @test haskey(indicators, "macd")
    @test haskey(indicators, "macd_signal")
    @test haskey(indicators, "macd_hist")
    @test haskey(indicators, "bb_upper")
    @test haskey(indicators, "bb_middle")
    @test haskey(indicators, "bb_lower")
    @test haskey(indicators, "vwap")
    
    @test indicators["sma_20"] == mean(test_prices[end-19:end])
    @test indicators["sma_50"] == mean(test_prices[end-49:end])
    @test 0 <= indicators["rsi"] <= 100
    @test indicators["bb_upper"] > indicators["bb_middle"] > indicators["bb_lower"]
end

@testset "Trading Signals" begin
    swarm = SwarmManager.create_swarm(test_config)
    push!(swarm.market_data, test_market_data)
    
    # Test with low entry threshold to ensure buy signal
    swarm.particles[1].position = [0.3, 0.7, 0.05, 0.1]  # entry_threshold, exit_threshold, stop_loss, take_profit
    
    # Print debug information
    @info "RSI value: $(test_market_data.indicators["rsi"])"
    @info "Entry threshold: $(swarm.particles[1].position[1] * 100)"
    @info "BB position: $((test_market_data.price - test_market_data.indicators["bb_lower"]) / (test_market_data.indicators["bb_upper"] - test_market_data.indicators["bb_lower"]))"
    
    signals = SwarmManager.generate_signals(swarm.particles[1], swarm.market_data)
    @test !isempty(signals)
    @test signals[1]["type"] == "buy"
    @test signals[1]["price"] == test_market_data.price
    @test haskey(signals[1], "indicators")
end

@testset "Trade Execution" begin
    swarm = SwarmManager.create_swarm(test_config)
    signal = Dict(
        "type" => "buy",
        "price" => 100.0,
        "timestamp" => now(),
        "indicators" => Dict()
    )
    
    SwarmManager.execute_trade(swarm.particles[1], signal)
    
    @test haskey(swarm.particles[1].portfolio, "TOKEN")
    @test swarm.particles[1].portfolio["USDC"] == 0.0
    @test swarm.particles[1].portfolio["TOKEN"] == 100.0
    @test length(swarm.particles[1].trades) == 1
    @test swarm.particles[1].trades[1]["type"] == "buy"
end

@testset "Performance Metrics" begin
    swarm = SwarmManager.create_swarm(test_config)
    
    # Simulate some trades
    push!(swarm.particles[1].trades, Dict(
        "type" => "buy",
        "price" => 100.0,
        "timestamp" => now()
    ))
    
    # Update portfolio after buy trade
    swarm.particles[1].portfolio["USDC"] = 0.0
    swarm.particles[1].portfolio["TOKEN"] = 100.0
    
    push!(swarm.particles[1].trades, Dict(
        "type" => "sell",
        "price" => 110.0,
        "timestamp" => now()
    ))
    
    # Update portfolio after sell trade
    swarm.particles[1].portfolio["TOKEN"] = 0.0
    swarm.particles[1].portfolio["USDC"] = 11000.0
    
    returns = SwarmManager.calculate_returns(swarm.particles[1])
    @test returns > 0
    
    sharpe = SwarmManager.calculate_sharpe_ratio([returns])
    @test isfinite(sharpe)
    
    max_dd = SwarmManager.calculate_max_drawdown([returns])
    @test max_dd >= 0
end

@testset "Swarm Optimization" begin
    swarm = SwarmManager.create_swarm(test_config)
    push!(swarm.market_data, test_market_data)
    
    # Run a few iterations
    for _ in 1:5
        SwarmManager.update_swarm!(swarm)
    end
    
    @test any(p.best_fitness > -Inf for p in swarm.particles)
    @test swarm.global_best_fitness > -Inf
    @test haskey(swarm.performance_metrics, "sharpe_ratio")
    @test haskey(swarm.performance_metrics, "max_drawdown")
end

@testset "Swarm State Persistence" begin
    swarm = SwarmManager.create_swarm(test_config)
    
    # Simulate some trading activity
    push!(swarm.market_data, test_market_data)
    SwarmManager.update_swarm!(swarm)
    
    # Verify state is maintained
    @test !isempty(swarm.market_data)
    @test any(p.best_fitness > -Inf for p in swarm.particles)
    @test haskey(swarm.performance_metrics, "sharpe_ratio")
end

@testset "Swarm Coordination Tests" begin
    @testset "Swarm Creation" begin
        # Test swarm creation with different coordination types
        for coord_type in ["independent", "coordinated", "hierarchical"]
            swarm = create_swarm(
                "test_swarm",
                coord_type,
                Dict(
                    "max_agents" => 5,
                    "min_agents" => 1,
                    "coordination_interval" => 60
                )
            )
            
            @test swarm.name == "test_swarm"
            @test swarm.coordination_type == coord_type
            @test swarm.agents isa Vector
            @test swarm.metrics isa Dict
            @test swarm.config isa Dict
        end
    end
    
    @testset "Agent Management" begin
        # Create a test swarm
        swarm = create_swarm(
            "test_swarm",
            "coordinated",
            Dict(
                "max_agents" => 5,
                "min_agents" => 1,
                "coordination_interval" => 60
            )
        )
        
        # Test agent addition
        agent = Agent(
            "test_agent",
            "arbitrage",
            Dict(
                "chain" => "ethereum",
                "strategy" => "price_arbitrage",
                "risk_params" => Dict(
                    "max_position_size" => 0.1,
                    "min_profit_threshold" => 0.01
                )
            )
        )
        
        add_agent!(swarm, agent)
        @test length(swarm.agents) == 1
        @test swarm.agents[1].id == "test_agent"
        
        # Test agent removal
        remove_agent!(swarm, "test_agent")
        @test length(swarm.agents) == 0
    end
    
    @testset "Coordination Strategies" begin
        # Test independent coordination
        swarm = create_swarm(
            "test_swarm",
            "independent",
            Dict(
                "max_agents" => 3,
                "min_agents" => 1,
                "coordination_interval" => 60
            )
        )
        
        # Add test agents
        for i in 1:3
            agent = Agent(
                "agent_$i",
                "arbitrage",
                Dict(
                    "chain" => "ethereum",
                    "strategy" => "price_arbitrage",
                    "risk_params" => Dict(
                        "max_position_size" => 0.1,
                        "min_profit_threshold" => 0.01
                    )
                )
            )
            add_agent!(swarm, agent)
        end
        
        # Test independent coordination
        coordinate_agents!(swarm)
        @test length(swarm.metrics) > 0
        
        # Test coordinated coordination
        swarm.coordination_type = "coordinated"
        coordinate_agents!(swarm)
        @test haskey(swarm.metrics, "coordination_round")
        
        # Test hierarchical coordination
        swarm.coordination_type = "hierarchical"
        coordinate_agents!(swarm)
        @test haskey(swarm.metrics, "leader_id")
    end
    
    @testset "Performance Monitoring" begin
        # Create a test swarm
        swarm = create_swarm(
            "test_swarm",
            "coordinated",
            Dict(
                "max_agents" => 3,
                "min_agents" => 1,
                "coordination_interval" => 60
            )
        )
        
        # Add test agents with performance metrics
        for i in 1:3
            agent = Agent(
                "agent_$i",
                "arbitrage",
                Dict(
                    "chain" => "ethereum",
                    "strategy" => "price_arbitrage",
                    "risk_params" => Dict(
                        "max_position_size" => 0.1,
                        "min_profit_threshold" => 0.01
                    )
                )
            )
            agent.metrics = Dict(
                "total_profit" => rand() * 1000,
                "trade_count" => rand(1:100),
                "success_rate" => rand()
            )
            add_agent!(swarm, agent)
        end
        
        # Test metrics aggregation
        update_swarm_metrics!(swarm)
        
        @test haskey(swarm.metrics, "total_profit")
        @test haskey(swarm.metrics, "average_success_rate")
        @test haskey(swarm.metrics, "total_trades")
    end
    
    @testset "Risk Management" begin
        # Create a test swarm with risk parameters
        swarm = create_swarm(
            "test_swarm",
            "coordinated",
            Dict(
                "max_agents" => 3,
                "min_agents" => 1,
                "coordination_interval" => 60,
                "risk_params" => Dict(
                    "max_total_exposure" => 10000.0,
                    "max_drawdown" => 0.1,
                    "min_capital_ratio" => 0.5
                )
            )
        )
        
        # Test risk checks
        risk_status = check_swarm_risk!(swarm)
        @test risk_status isa Dict
        @test haskey(risk_status, "risk_level")
        @test haskey(risk_status, "violations")
        
        # Test risk mitigation
        if risk_status["risk_level"] > 0.7
            mitigate_risk!(swarm)
            @test check_swarm_risk!(swarm)["risk_level"] <= 0.7
        end
    end
    
    @testset "Error Handling" begin
        # Test invalid swarm creation
        @test_throws ArgumentError create_swarm(
            "",
            "coordinated",
            Dict(
                "max_agents" => 3,
                "min_agents" => 1,
                "coordination_interval" => 60
            )
        )
        
        # Test invalid coordination type
        @test_throws ArgumentError create_swarm(
            "test_swarm",
            "invalid_type",
            Dict(
                "max_agents" => 3,
                "min_agents" => 1,
                "coordination_interval" => 60
            )
        )
        
        # Test invalid agent addition
        swarm = create_swarm(
            "test_swarm",
            "coordinated",
            Dict(
                "max_agents" => 1,
                "min_agents" => 1,
                "coordination_interval" => 60
            )
        )
        
        agent1 = Agent(
            "agent_1",
            "arbitrage",
            Dict(
                "chain" => "ethereum",
                "strategy" => "price_arbitrage",
                "risk_params" => Dict(
                    "max_position_size" => 0.1,
                    "min_profit_threshold" => 0.01
                )
            )
        )
        
        agent2 = Agent(
            "agent_2",
            "arbitrage",
            Dict(
                "chain" => "ethereum",
                "strategy" => "price_arbitrage",
                "risk_params" => Dict(
                    "max_position_size" => 0.1,
                    "min_profit_threshold" => 0.01
                )
            )
        )
        
        add_agent!(swarm, agent1)
        @test_throws ErrorException add_agent!(swarm, agent2)
    end
end 