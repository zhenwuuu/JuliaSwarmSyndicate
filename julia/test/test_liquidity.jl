using Test
using JuliaOS.LiquidityProvider

@testset "Liquidity Provider Tests" begin
    @testset "Pool Info" begin
        # Test pool info creation
        pool_info = PoolInfo(
            "ethereum",
            "uniswap-v3",
            "ETH/USDC",
            0.003,
            1000000.0,
            500000.0,
            0.1,
            (1900.0, 2100.0)
        )
        
        @test pool_info.chain == "ethereum"
        @test pool_info.protocol == "uniswap-v3"
        @test pool_info.pair == "ETH/USDC"
        @test pool_info.fee_tier == 0.003
        @test pool_info.tvl == 1000000.0
        @test pool_info.volume_24h == 500000.0
        @test pool_info.apy == 0.1
        @test pool_info.price_range == (1900.0, 2100.0)
    end
    
    @testset "Position Management" begin
        # Test position creation
        position = Position(
            "test_position",
            "ETH/USDC",
            1.0,  # ETH amount
            2000.0,  # USDC amount
            1900.0,  # Lower price
            2100.0,  # Upper price
            0.003,  # Fee tier
            now()  # Creation time
        )
        
        @test position.id == "test_position"
        @test position.pair == "ETH/USDC"
        @test position.token0_amount == 1.0
        @test position.token1_amount == 2000.0
        @test position.lower_price == 1900.0
        @test position.upper_price == 2100.0
        @test position.fee_tier == 0.003
        @test position.created_at isa DateTime
    end
    
    @testset "Position Rebalancing" begin
        # Test rebalancing logic
        pool_info = PoolInfo(
            "ethereum",
            "uniswap-v3",
            "ETH/USDC",
            0.003,
            1000000.0,
            500000.0,
            0.1,
            (1900.0, 2100.0)
        )
        
        risk_params = Dict(
            "max_position_size" => 0.1,
            "min_liquidity_depth" => 100000.0,
            "max_il_threshold" => 0.05,
            "min_apy_threshold" => 0.1
        )
        
        # Test rebalancing check
        needs_rebalancing = needs_rebalancing(pool_info, risk_params)
        @test needs_rebalancing isa Bool
        
        # Test position rebalancing
        position = Position(
            "test_position",
            "ETH/USDC",
            1.0,
            2000.0,
            1900.0,
            2100.0,
            0.003,
            now()
        )
        
        rebalanced_position = rebalance_position(
            position,
            pool_info,
            Dict(
                "price_range_multiplier" => 0.1,
                "concentration_factor" => 0.5
            )
        )
        
        @test rebalanced_position.id == position.id
        @test rebalanced_position.pair == position.pair
        @test rebalanced_position.fee_tier == position.fee_tier
    end
    
    @testset "Impermanent Loss Calculation" begin
        # Test IL calculation
        position = Position(
            "test_position",
            "ETH/USDC",
            1.0,
            2000.0,
            1900.0,
            2100.0,
            0.003,
            now()
        )
        
        pool_info = PoolInfo(
            "ethereum",
            "uniswap-v3",
            "ETH/USDC",
            0.003,
            1000000.0,
            500000.0,
            0.1,
            (1900.0, 2100.0)
        )
        
        il = calculate_impermanent_loss(pool_info)
        @test il isa Float64
        @test il >= 0.0
    end
    
    @testset "Position Adjustment" begin
        # Test position adjustment
        position = Position(
            "test_position",
            "ETH/USDC",
            1.0,
            2000.0,
            1900.0,
            2100.0,
            0.003,
            now()
        )
        
        pool_info = PoolInfo(
            "ethereum",
            "uniswap-v3",
            "ETH/USDC",
            0.003,
            1000000.0,
            500000.0,
            0.1,
            (1900.0, 2100.0)
        )
        
        risk_params = Dict(
            "max_position_size" => 0.1,
            "min_liquidity_depth" => 100000.0,
            "max_il_threshold" => 0.05,
            "min_apy_threshold" => 0.1
        )
        
        adjusted_position = adjust_position(position, pool_info, risk_params)
        @test adjusted_position.id == position.id
        @test adjusted_position.pair == position.pair
        @test adjusted_position.fee_tier == position.fee_tier
    end
    
    @testset "Performance Metrics" begin
        # Test metrics tracking
        swarm = create_lp_swarm(1, Dict(), Dict(), Dict())
        
        # Add some test positions
        push!(swarm.positions, Position(
            "test_position",
            "ETH/USDC",
            1.0,
            2000.0,
            1900.0,
            2100.0,
            0.003,
            now()
        ))
        
        # Update metrics
        update_metrics(swarm)
        
        @test haskey(swarm.metrics, "total_value_locked")
        @test haskey(swarm.metrics, "total_fees_earned")
        @test haskey(swarm.metrics, "average_apy")
        @test haskey(swarm.metrics, "total_impermanent_loss")
    end
    
    @testset "Error Handling" begin
        # Test invalid pool info
        @test_throws ArgumentError PoolInfo(
            "",
            "uniswap-v3",
            "ETH/USDC",
            0.003,
            1000000.0,
            500000.0,
            0.1,
            (1900.0, 2100.0)
        )
        
        # Test invalid position
        @test_throws ArgumentError Position(
            "",
            "ETH/USDC",
            1.0,
            2000.0,
            1900.0,
            2100.0,
            0.003,
            now()
        )
        
        # Test invalid risk parameters
        @test_throws ArgumentError needs_rebalancing(
            PoolInfo(
                "ethereum",
                "uniswap-v3",
                "ETH/USDC",
                0.003,
                1000000.0,
                500000.0,
                0.1,
                (1900.0, 2100.0)
            ),
            Dict()
        )
    end
end 