using Test
using JuliaOS.CLI.DefiCLI

@testset "CLI Tests" begin
    @testset "User Input Functions" begin
        # Test get_user_input
        @test DefiCLI.get_user_input("Test prompt: ") isa String
        
        # Test select_from_menu
        options = ["Option 1", "Option 2", "Option 3"]
        @test DefiCLI.select_from_menu("Test Menu", options) in options
        
        # Test select_multiple_from_menu
        selected = DefiCLI.select_multiple_from_menu("Test Multi Menu", options)
        @test all(opt -> opt in options, selected)
    end
    
    @testset "Risk Parameter Configuration" begin
        # Test arbitrage risk params
        arb_params = DefiCLI.configure_risk_params("Arbitrage Agent")
        @test haskey(arb_params, "max_position_size")
        @test haskey(arb_params, "min_profit_threshold")
        @test haskey(arb_params, "max_gas_price")
        @test haskey(arb_params, "confidence_threshold")
        
        # Test LP risk params
        lp_params = DefiCLI.configure_risk_params("Liquidity Provider Agent")
        @test haskey(lp_params, "max_position_size")
        @test haskey(lp_params, "min_liquidity_depth")
        @test haskey(lp_params, "max_il_threshold")
        @test haskey(lp_params, "min_apy_threshold")
    end
    
    @testset "Strategy Parameter Configuration" begin
        # Test LP strategy params
        lp_strategy_params = DefiCLI.configure_strategy_params(
            "Liquidity Provider Agent",
            "Concentrated"
        )
        @test haskey(lp_strategy_params, "price_range_multiplier")
        @test haskey(lp_strategy_params, "concentration_factor")
        @test haskey(lp_strategy_params, "rebalance_frequency")
        @test haskey(lp_strategy_params, "fee_tier_preference")
    end
    
    @testset "Agent Configuration" begin
        agent = DefiCLI.create_agent_config()
        @test agent isa DefiCLI.AgentConfig
        @test agent.name != ""
        @test agent.type in ["arbitrage", "liquidity"]
        @test !isempty(agent.chains)
        @test !isempty(agent.risk_params)
        @test !isempty(agent.strategy_params)
    end
    
    @testset "Swarm Configuration" begin
        swarm = DefiCLI.create_swarm_config()
        @test swarm isa DefiCLI.SwarmConfig
        @test swarm.name != ""
        @test swarm.coordination_type in ["independent", "coordinated", "hierarchical"]
        @test !isempty(swarm.agents)
        @test !isempty(swarm.shared_risk_params)
    end
    
    @testset "Configuration Serialization" begin
        # Test saving configuration
        config = DefiCLI.create_swarm_config()
        test_file = "test_data/config/test_config.json"
        
        DefiCLI.save_config(config, test_file)
        @test isfile(test_file)
        
        # Test loading configuration
        loaded_config = DefiCLI.load_config(test_file)
        @test loaded_config.name == config.name
        @test loaded_config.coordination_type == config.coordination_type
        @test length(loaded_config.agents) == length(config.agents)
        
        # Cleanup
        rm(test_file)
    end
    
    @testset "Swarm Execution" begin
        # Test swarm initialization
        config = DefiCLI.create_swarm_config()
        @test_throws ArgumentError DefiCLI.run_swarm(config)  # Should fail without RPC endpoints
        
        # Test with mock data
        chain_info = Dict(
            "ethereum" => CrossChainArbitrage.ChainInfo(
                "ethereum",
                "https://eth-mainnet.alchemyapi.io/v2/test-key",
                50.0,
                "0x1234567890123456789012345678901234567890",
                ["ETH", "USDC"]
            )
        )
        
        # Test arbitrage swarm
        arb_swarm = create_arbitrage_swarm(1, chain_info, Dict())
        @test length(arb_swarm.agents) == 1
        
        # Test LP swarm
        pool_info = Dict(
            "test_pool" => LiquidityProvider.PoolInfo(
                "ethereum",
                "uniswap-v3",
                "ETH/USDC",
                0.003,
                1000000.0,
                500000.0,
                0.1,
                (1900.0, 2100.0)
            )
        )
        
        lp_swarm = create_lp_swarm(1, pool_info, Dict(), Dict())
        @test length(lp_swarm.agents) == 1
    end
end 