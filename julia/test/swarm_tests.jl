using Test
using JuliaOS
using JuliaOS.SwarmManager
using JuliaOS.Config
using JuliaOS.MarketData
using JuliaOS.Bridge
using TestUtils
using Dates

@testset "Swarm Management Tests" begin
    @testset "Swarm Creation" begin
        TestUtils.with_test_swarm(swarm -> begin
            # Test swarm initialization
            @test swarm !== nothing
            @test swarm.name == "test_swarm"
            @test swarm.algorithm == "pso"
            @test !isempty(swarm.trading_pairs)
            @test !isempty(swarm.parameters)

            # Test swarm configuration
            config = swarm.config
            @test config !== nothing
            @test config.name == "test_swarm"
            @test config.population_size == 10
            @test config.algorithm == "pso"
            @test !isempty(config.trading_pairs)
            @test !isempty(config.parameters)
        end)
    end

    @testset "Agent Management" begin
        TestUtils.with_test_swarm(swarm -> begin
            # Test agent creation
            agent = SwarmManager.create_agent(
                "test_agent",
                "Arbitrage Agent",
                "Mean Reversion",
                ["ethereum"],
                Dict(
                    "max_position_size" => 0.1,
                    "min_profit_threshold" => 0.01
                )
            )
            @test agent !== nothing
            @test agent.name == "test_agent"
            @test agent.type == "Arbitrage Agent"
            @test agent.strategy == "Mean Reversion"
            @test !isempty(agent.chains)
            @test !isempty(agent.risk_params)

            # Test agent addition to swarm
            SwarmManager.add_agent(swarm, agent)
            @test length(swarm.agents) == 1
            @test swarm.agents[1] == agent

            # Test agent removal from swarm
            SwarmManager.remove_agent(swarm, agent)
            @test length(swarm.agents) == 0
        end)
    end

    @testset "Swarm Coordination" begin
        TestUtils.with_test_swarm(swarm -> begin
            # Test swarm coordination
            @test swarm.coordination_type in ["independent", "coordinated", "hierarchical"]
            
            # Test agent communication
            agent1 = SwarmManager.create_agent(
                "agent1",
                "Arbitrage Agent",
                "Mean Reversion",
                ["ethereum"],
                Dict()
            )
            agent2 = SwarmManager.create_agent(
                "agent2",
                "Arbitrage Agent",
                "Mean Reversion",
                ["ethereum"],
                Dict()
            )
            
            SwarmManager.add_agent(swarm, agent1)
            SwarmManager.add_agent(swarm, agent2)
            
            # Test message passing
            message = Dict(
                "type" => "opportunity",
                "data" => Dict(
                    "chain" => "ethereum",
                    "pair" => "ETH/USDC",
                    "profit" => 0.02
                )
            )
            
            SwarmManager.send_message(agent1, agent2, message)
            @test length(agent2.messages) == 1
            @test agent2.messages[1] == message
        end)
    end

    @testset "Performance Metrics" begin
        TestUtils.with_test_swarm(swarm -> begin
            # Test performance calculation
            returns = [0.01, -0.005, 0.02, -0.01, 0.015]
            metrics = SwarmManager.calculate_performance_metrics(returns)
            
            @test haskey(metrics, "sharpe_ratio")
            @test haskey(metrics, "max_drawdown")
            @test haskey(metrics, "win_rate")
            @test haskey(metrics, "profit_factor")
            @test haskey(metrics, "total_return")
            
            # Test metric validation
            @test metrics["sharpe_ratio"] isa Float64
            @test metrics["max_drawdown"] isa Float64
            @test 0 <= metrics["max_drawdown"] <= 1
            @test 0 <= metrics["win_rate"] <= 1
            @test metrics["profit_factor"] > 0
        end)
    end

    @testset "Swarm Optimization" begin
        TestUtils.with_test_swarm(swarm -> begin
            # Test parameter optimization
            params = Dict(
                "inertia_weight" => 0.7,
                "cognitive_coef" => 1.5,
                "social_coef" => 1.5
            )
            
            optimized_params = SwarmManager.optimize_parameters(
                swarm,
                params;
                iterations=10,
                population_size=5
            )
            
            @test optimized_params !== nothing
            @test haskey(optimized_params, "inertia_weight")
            @test haskey(optimized_params, "cognitive_coef")
            @test haskey(optimized_params, "social_coef")
            
            # Test parameter constraints
            @test 0 <= optimized_params["inertia_weight"] <= 1
            @test optimized_params["cognitive_coef"] > 0
            @test optimized_params["social_coef"] > 0
        end)
    end

    @testset "Risk Management" begin
        TestUtils.with_test_swarm(swarm -> begin
            # Test risk parameter validation
            risk_params = Dict(
                "max_position_size" => 0.1,
                "max_drawdown" => 0.1,
                "min_win_rate" => 0.5,
                "max_leverage" => 2.0
            )
            
            valid, errors = SwarmManager.validate_risk_params(risk_params)
            @test valid
            @test isempty(errors)
            
            # Test invalid risk parameters
            invalid_params = Dict(
                "max_position_size" => 1.5,
                "max_drawdown" => -0.1,
                "min_win_rate" => 1.5,
                "max_leverage" => 0.5
            )
            
            valid, errors = SwarmManager.validate_risk_params(invalid_params)
            @test !valid
            @test !isempty(errors)
            
            # Test risk monitoring
            position = Dict(
                "size" => 0.05,
                "entry_price" => 2000.0,
                "current_price" => 2100.0,
                "leverage" => 1.0
            )
            
            risk_metrics = SwarmManager.calculate_position_risk(position, risk_params)
            @test haskey(risk_metrics, "exposure")
            @test haskey(risk_metrics, "drawdown")
            @test haskey(risk_metrics, "leverage_ratio")
        end)
    end

    @testset "Error Handling" begin
        TestUtils.with_test_swarm(swarm -> begin
            # Test invalid agent creation
            @test_throws ArgumentError SwarmManager.create_agent(
                "",
                "Arbitrage Agent",
                "Mean Reversion",
                [],
                Dict()
            )
            
            # Test invalid swarm configuration
            @test_throws ArgumentError SwarmManager.create_swarm(
                Config.SwarmConfig(
                    "invalid_swarm",
                    0,
                    "invalid_algorithm",
                    [],
                    Dict()
                ),
                "ethereum"
            )
            
            # Test invalid message passing
            @test_throws ArgumentError SwarmManager.send_message(
                nothing,
                nothing,
                Dict()
            )
            
            # Test invalid performance calculation
            @test_throws ArgumentError SwarmManager.calculate_performance_metrics([])
        end)
    end
end 