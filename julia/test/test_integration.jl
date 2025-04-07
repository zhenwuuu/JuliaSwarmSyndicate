using Test
using JuliaOS

@testset "Integration Tests" begin
    @testset "Swarm and Agent Integration" begin
        # Test swarm creation with agents
        swarm = create_swarm(
            "test_swarm",
            "coordinated",
            Dict(
                "max_agents" => 3,
                "min_agents" => 1,
                "coordination_interval" => 60
            )
        )
        
        # Add arbitrage agent
        arb_agent = Agent(
            "arb_agent_1",
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
        
        # Add liquidity provider agent
        lp_agent = Agent(
            "lp_agent_1",
            "liquidity",
            Dict(
                "chain" => "ethereum",
                "strategy" => "concentrated_liquidity",
                "risk_params" => Dict(
                    "max_position_size" => 0.1,
                    "min_liquidity_depth" => 100000.0
                )
            )
        )
        
        add_agent!(swarm, arb_agent)
        add_agent!(swarm, lp_agent)
        
        @test length(swarm.agents) == 2
        @test any(a.type == "arbitrage" for a in swarm.agents)
        @test any(a.type == "liquidity" for a in swarm.agents)
        
        # Test agent coordination
        coordinate_agents!(swarm)
        @test haskey(swarm.metrics, "coordination_round")
    end
    
    @testset "Cross-Chain and Risk Management Integration" begin
        # Test cross-chain setup with risk management
        bridge = Bridge(
            "test_bridge",
            Dict(
                "ethereum" => ChainInfo(
                    "ethereum",
                    "https://eth-mainnet.alchemyapi.io/v2/test",
                    50.0,
                    "0x1234...5678",
                    ["ETH", "USDC"]
                ),
                "polygon" => ChainInfo(
                    "polygon",
                    "https://polygon-mainnet.infura.io/v3/test",
                    30.0,
                    "0x8765...4321",
                    ["ETH", "USDC"]
                )
            )
        )
        
        risk_params = RiskParameters(
            Dict(
                "max_position_size" => 0.1,
                "max_drawdown" => 0.15,
                "min_capital_ratio" => 0.5
            )
        )
        
        # Test cross-chain transfer with risk checks
        transfer = TokenTransfer(
            "ETH",
            1.0,
            "ethereum",
            "polygon",
            "0xabcd...efgh",
            "0xijkl...mnop"
        )
        
        # Check risk before transfer
        portfolio = Portfolio(
            Dict(
                "ETH" => Position(
                    "eth_position",
                    "ETH/USDC",
                    1.0,
                    2000.0,
                    1900.0,
                    2100.0,
                    0.003,
                    now()
                )
            ),
            10000.0
        )
        
        risk_analysis = analyze_portfolio_risk(portfolio, risk_params)
        @test risk_analysis["risk_score"] >= 0
        @test risk_analysis["risk_score"] <= 1
        
        # Execute transfer if risk is acceptable
        if risk_analysis["risk_score"] < 0.7
            result = execute_cross_chain_transaction(bridge, transfer)
            @test result.status == "success"
        end
    end
    
    @testset "Monitoring and Configuration Integration" begin
        # Test monitoring setup with configuration
        config = load_configuration("test_config.json")
        
        collector = MetricsCollector(
            Dict(
                "update_interval" => config["monitoring"]["update_interval"],
                "retention_period" => config["monitoring"]["retention_period"],
                "metrics_path" => "test_metrics"
            )
        )
        
        monitor = HealthMonitor(
            Dict(
                "check_interval" => config["monitoring"]["check_interval"],
                "timeout" => config["monitoring"]["timeout"],
                "retry_count" => config["monitoring"]["retry_count"]
            )
        )
        
        # Test metrics collection with configuration
        metrics = Dict(
            "timestamp" => now(),
            "total_profit" => 1000.0,
            "trade_count" => 10,
            "success_rate" => 0.8,
            "gas_cost" => 50.0
        )
        
        record_metrics!(collector, metrics)
        @test length(collector.metrics_history) > 0
        
        # Test health monitoring with configuration
        health_status = check_health(monitor)
        @test haskey(health_status, "status")
        @test haskey(health_status, "components")
    end
    
    @testset "Full System Integration" begin
        # Test complete system integration
        # 1. Load configuration
        config = load_configuration("test_config.json")
        
        # 2. Initialize components
        swarm = create_swarm(
            config["swarm"]["name"],
            config["swarm"]["coordination_type"],
            config["swarm"]
        )
        
        bridge = Bridge(
            "test_bridge",
            Dict(
                "ethereum" => ChainInfo(
                    "ethereum",
                    config["rpc_urls"]["ethereum"],
                    config["gas_prices"]["ethereum"],
                    config["contract_addresses"]["bridge"]["ethereum"],
                    config["supported_tokens"]["ethereum"]
                )
            )
        )
        
        risk_params = RiskParameters(config["risk_params"])
        
        collector = MetricsCollector(config["monitoring"])
        monitor = HealthMonitor(config["monitoring"])
        
        # 3. Add agents
        for agent_config in config["agents"]
            agent = Agent(
                agent_config["id"],
                agent_config["type"],
                agent_config
            )
            add_agent!(swarm, agent)
        end
        
        # 4. Start monitoring
        start_monitoring!(collector)
        start_monitoring!(monitor)
        
        # 5. Run coordination
        coordinate_agents!(swarm)
        
        # 6. Check system health
        health_status = check_health(monitor)
        @test health_status["status"] == "healthy"
        
        # 7. Check metrics
        analytics = calculate_performance_analytics(collector)
        @test haskey(analytics, "total_profit")
        @test haskey(analytics, "average_success_rate")
        
        # 8. Check risk
        risk_analysis = analyze_portfolio_risk(
            Portfolio(swarm.positions, swarm.total_value),
            risk_params
        )
        @test risk_analysis["risk_score"] < 0.7
        
        # 9. Stop monitoring
        stop_monitoring!(collector)
        stop_monitoring!(monitor)
    end
    
    @testset "Error Recovery Integration" begin
        # Test system recovery from errors
        swarm = create_swarm(
            "test_swarm",
            "coordinated",
            Dict(
                "max_agents" => 3,
                "min_agents" => 1,
                "coordination_interval" => 60
            )
        )
        
        # Add test agent
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
        
        # Simulate error
        try
            error("Test error")
        catch e
            # Test error recovery
            recovered = recover_from_error(swarm, e)
            @test recovered
            @test length(swarm.agents) > 0
            @test swarm.metrics["error_count"] > 0
        end
    end
end 