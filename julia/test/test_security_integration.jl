#!/usr/bin/env julia

using Test
using Dates
using JuliaOS.SecurityManager
using JuliaOS.SwarmManager
using JuliaOS.MLIntegration
using JuliaOS.RiskManagement
using JuliaOS.UserModules

@testset "Security Integration Tests" begin
    # Test Security Configuration
    @testset "Security Configuration" begin
        security_config = SecurityManager.SecurityConfig(
            ["security@example.com"],  # emergency_contacts
            0.75,                      # anomaly_detection_threshold
            10.0,                      # max_transaction_value
            String[],                  # paused_chains
            Dict(                      # risk_params
                "max_slippage" => 0.02,
                "max_gas_multiplier" => 3.0,
                "contract_risk_threshold" => 0.7
            ),
            60,                        # monitoring_interval
            true                       # hooks_enabled
        )
        
        @test length(security_config.emergency_contacts) == 1
        @test security_config.anomaly_detection_threshold == 0.75
        @test security_config.max_transaction_value == 10.0
        @test security_config.hooks_enabled == true
    end
    
    # Test Security Initialization
    @testset "Security Initialization" begin
        security_config = SecurityManager.SecurityConfig(
            ["security@example.com"],  # emergency_contacts
            0.75,                      # anomaly_detection_threshold
            10.0,                      # max_transaction_value
            String[],                  # paused_chains
            Dict(                      # risk_params
                "max_slippage" => 0.02,
                "max_gas_multiplier" => 3.0,
                "contract_risk_threshold" => 0.7
            ),
            60,                        # monitoring_interval
            true                       # hooks_enabled
        )
        
        security_status = SecurityManager.initialize_security(security_config)
        
        @test security_status["status"] == "initialized"
        @test haskey(security_status, "timestamp")
        @test haskey(security_status, "config")
        @test haskey(security_status, "anomaly_model")
    end
    
    # Test Chain Monitoring
    @testset "Chain Monitoring" begin
        chain_activity = SecurityManager.monitor_chain_activity("ethereum")
        
        @test haskey(chain_activity, "transaction_count")
        @test haskey(chain_activity, "gas_prices")
        @test haskey(chain_activity, "anomaly_score")
        
        # Test anomaly score is within expected range (0-1)
        @test 0 <= chain_activity["anomaly_score"] <= 1
    end
    
    # Test Transaction Risk Assessment
    @testset "Transaction Risk Assessment" begin
        # Test low-risk transaction
        tx_data_low_risk = Dict(
            "from" => "0x123...",
            "to" => "0x456...",
            "value" => 0.1,           # Small amount
            "chain" => "ethereum",
            "gas_price" => 30.0,      # Normal gas
            "type" => "swap"
        )
        
        risk_assessment_low = SecurityManager.assess_transaction_risk(tx_data_low_risk)
        
        @test haskey(risk_assessment_low, "overall_risk")
        @test haskey(risk_assessment_low, "recommendation")
        @test risk_assessment_low["recommendation"] in ["Proceed", "Caution", "Abort"]
        
        # Test high-risk transaction
        tx_data_high_risk = Dict(
            "from" => "0x123...",
            "to" => "0x789...",  # Different contract
            "value" => 15.0,     # Large amount
            "chain" => "ethereum",
            "gas_price" => 200.0, # High gas
            "type" => "liquidation"  # Riskier type
        )
        
        risk_assessment_high = SecurityManager.assess_transaction_risk(tx_data_high_risk)
        
        @test risk_assessment_high["overall_risk"] > risk_assessment_low["overall_risk"]
    end
    
    # Test Security Hooks
    @testset "Security Hooks" begin
        # Register a test hook
        test_hook_called = false
        
        function test_hook(data)
            global test_hook_called = true
            return Dict("action" => "allow", "test" => true)
        end
        
        hook_count = SecurityManager.register_security_hook("test_hook_point", test_hook)
        @test hook_count == 1
        
        # Execute the hook
        result = SecurityManager.execute_security_hooks("test_hook_point", Dict("test" => true))
        
        @test test_hook_called == true
        @test result["status"] == "completed"
        @test length(result["hook_results"]) == 1
        @test result["hook_results"][1]["test"] == true
    end
    
    # Test Emergency Pause
    @testset "Emergency Pause" begin
        pause_result = SecurityManager.emergency_pause!("optimism", "Test emergency")
        
        @test pause_result["status"] == "paused"
        @test pause_result["chain"] == "optimism"
        @test haskey(pause_result, "timestamp")
        @test haskey(pause_result, "event")
    end
    
    # Test Contract Verification
    @testset "Contract Verification" begin
        contract_info = SecurityManager.verify_contract("ethereum", "0xabc...")
        
        @test haskey(contract_info, "risk_score")
        @test haskey(contract_info, "risk_category")
        @test 0 <= contract_info["risk_score"] <= 1
    end
    
    # Test Incident Response Creation
    @testset "Incident Response" begin
        incident = SecurityManager.create_incident_response(
            "bridge_exploit",           # incident_type
            "critical",                 # severity
            Dict(                       # details
                "chain" => "optimism",
                "bridge_address" => "0x789...",
                "estimated_loss" => 500000.0,
                "attack_vector" => "price oracle manipulation"
            )
        )
        
        @test incident["incident_type"] == "bridge_exploit"
        @test incident["severity"] == "critical"
        @test haskey(incident, "response_steps")
        @test length(incident["response_steps"]) > 0
        @test haskey(incident, "timeframe")
    end
    
    # Test Security Report Generation
    @testset "Security Report Generation" begin
        report = SecurityManager.generate_security_report()
        
        @test haskey(report, "report_id")
        @test haskey(report, "generated_at")
        @test haskey(report, "summary")
        @test haskey(report, "chain_status")
        @test haskey(report, "bridge_status")
        @test haskey(report, "recommendations")
    end
    
    # Test Integration with Risk Management
    @testset "Risk Management Integration" begin
        # Test impermanent loss calculation
        il = RiskManagement.calculate_impermanent_loss(1.5)  # 50% price change
        @test il < 0  # Should be negative (a loss)
        
        # Test MEV exposure estimation
        mev_risk = RiskManagement.estimate_mev_exposure(
            10.0,       # trade_value
            50.0,       # gas_price
            blockchain="ethereum",
            trade_type="swap"
        )
        
        @test haskey(mev_risk, "mev_rate")
        @test haskey(mev_risk, "mev_value")
        @test 0 <= mev_risk["mev_rate"] <= 1
        
        # Test cross-chain risk analysis
        bridge_risks = RiskManagement.analyze_cross_chain_risks(
            "optimistic",
            ["arbitrum"]
        )
        
        @test haskey(bridge_risks, "arbitrum")
        @test haskey(bridge_risks["arbitrum"], "adjusted_risk")
        @test haskey(bridge_risks["arbitrum"], "risk_category")
    end
    
    # Test User Modules Integration (if available)
    @testset "User Modules Integration" begin
        # Load user modules
        loaded_modules = UserModules.load_user_modules()
        
        # If CustomSecurity module is available, test it
        if "CustomSecurity" in keys(loaded_modules)
            custom_security = UserModules.get_user_module("CustomSecurity")
            
            # Create test configuration
            test_config = custom_security.CustomSecurityConfig(
                Dict("ethereum" => 0.5),           # custom_risk_thresholds
                ["0x123..."],                      # wallet_whitelist
                Dict("ethereum" => ["0x456..."]),  # contract_whitelist
                [],                                # notification_endpoints
                "test_model.jld2",                 # ml_model_path
                false                              # enable_advanced_monitoring
            )
            
            # Test initialization
            init_result = custom_security.initialize_security_extensions(test_config)
            @test init_result["status"] == "initialized"
            
            # Test status check
            status = custom_security.get_security_status()
            @test haskey(status, "timestamp")
        else
            @info "CustomSecurity module not available, skipping tests"
        end
    end
    
    # Test SwarmManager Integration
    @testset "SwarmManager Integration" begin
        # Create a small swarm for testing
        swarm_config = SwarmManager.SwarmConfig(
            "security_test_swarm",     # name
            5,                         # size (small for testing)
            "pso",                     # algorithm
            ["eth_usdt"],              # trading_pairs
            Dict(                      # parameters
                "inertia_weight" => 0.7,
                "cognitive_coef" => 1.5,
                "social_coef" => 1.5
            )
        )
        
        security_swarm = SwarmManager.create_swarm(swarm_config)
        
        # Create some test market data
        market_data = [
            MarketData.MarketDataPoint(
                "eth_usdt",           # pair
                now(),                # timestamp
                1500.0,               # price
                1000.0,               # volume
                "ethereum",           # chain
                "uniswap-v3",         # dex
                Dict("rsi" => 45.0)   # indicators
            )
        ]
        
        # Initialize the swarm
        SwarmManager.start_swarm!(security_swarm, market_data)
        
        # Verify the swarm has been initialized
        @test haskey(security_swarm.performance_metrics, "best_fitness")
        @test haskey(security_swarm.performance_metrics, "entry_threshold")
        @test haskey(security_swarm.performance_metrics, "exit_threshold")
    end
end

println("All security integration tests completed!") 