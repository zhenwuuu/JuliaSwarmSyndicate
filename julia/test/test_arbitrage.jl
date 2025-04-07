using Test
using JuliaOS.CrossChainArbitrage

@testset "Arbitrage Tests" begin
    @testset "Chain Info" begin
        # Test chain info creation
        chain_info = ChainInfo(
            "ethereum",
            "https://eth-mainnet.alchemyapi.io/v2/test-key",
            50.0,
            "0x1234567890123456789012345678901234567890",
            ["ETH", "USDC"]
        )
        
        @test chain_info.name == "ethereum"
        @test chain_info.rpc_url == "https://eth-mainnet.alchemyapi.io/v2/test-key"
        @test chain_info.gas_price == 50.0
        @test chain_info.bridge_address == "0x1234567890123456789012345678901234567890"
        @test chain_info.supported_tokens == ["ETH", "USDC"]
    end
    
    @testset "Market Data" begin
        # Test market data structure
        market_data = Dict(
            "ETH" => Dict(
                "price" => 2000.0,
                "volume" => 1000000.0,
                "liquidity" => 5000000.0,
                "timestamp" => now()
            ),
            "USDC" => Dict(
                "price" => 1.0,
                "volume" => 10000000.0,
                "liquidity" => 50000000.0,
                "timestamp" => now()
            )
        )
        
        @test haskey(market_data, "ETH")
        @test haskey(market_data, "USDC")
        @test all(haskey.(Ref(market_data["ETH"]), ["price", "volume", "liquidity", "timestamp"]))
        @test all(haskey.(Ref(market_data["USDC"]), ["price", "volume", "liquidity", "timestamp"]))
    end
    
    @testset "Opportunity Detection" begin
        # Test opportunity structure
        opportunity = ArbitrageOpportunity(
            "ETH",
            "ethereum",
            "polygon",
            2000.0,
            2010.0,
            0.005,  # 0.5% spread
            100.0,  # Expected profit
            "ETH price difference between Ethereum and Polygon"
        )
        
        @test opportunity.token == "ETH"
        @test opportunity.source_chain == "ethereum"
        @test opportunity.target_chain == "polygon"
        @test opportunity.source_price == 2000.0
        @test opportunity.target_price == 2010.0
        @test opportunity.price_spread == 0.005
        @test opportunity.expected_profit == 100.0
        @test opportunity.description != ""
    end
    
    @testset "Opportunity Finding" begin
        # Test finding opportunities
        market_data = Dict(
            "ethereum" => Dict(
                "ETH" => Dict(
                    "price" => 2000.0,
                    "volume" => 1000000.0,
                    "liquidity" => 5000000.0
                ),
                "USDC" => Dict(
                    "price" => 1.0,
                    "volume" => 10000000.0,
                    "liquidity" => 50000000.0
                )
            ),
            "polygon" => Dict(
                "ETH" => Dict(
                    "price" => 2010.0,
                    "volume" => 500000.0,
                    "liquidity" => 2500000.0
                ),
                "USDC" => Dict(
                    "price" => 1.0,
                    "volume" => 5000000.0,
                    "liquidity" => 25000000.0
                )
            )
        )
        
        risk_params = Dict(
            "max_position_size" => 0.05,
            "min_profit_threshold" => 0.02,
            "max_gas_price" => 50.0,
            "confidence_threshold" => 0.9
        )
        
        opportunities = find_opportunities(market_data, risk_params)
        @test !isempty(opportunities)
        @test all(opp -> opp.expected_profit > risk_params["min_profit_threshold"], opportunities)
    end
    
    @testset "Trade Execution" begin
        # Test trade execution
        chain_info = Dict(
            "ethereum" => ChainInfo(
                "ethereum",
                "https://eth-mainnet.alchemyapi.io/v2/test-key",
                50.0,
                "0x1234567890123456789012345678901234567890",
                ["ETH", "USDC"]
            ),
            "polygon" => ChainInfo(
                "polygon",
                "https://polygon-mainnet.g.alchemy.com/v2/test-key",
                50.0,
                "0x0987654321098765432109876543210987654321",
                ["ETH", "USDC"]
            )
        )
        
        opportunity = ArbitrageOpportunity(
            "ETH",
            "ethereum",
            "polygon",
            2000.0,
            2010.0,
            0.005,
            100.0,
            "ETH price difference between Ethereum and Polygon"
        )
        
        # Test trade execution (should fail without real RPC endpoints)
        @test_throws HTTP.RequestError execute_trade(
            create_arbitrage_swarm(1, chain_info, Dict()),
            opportunity,
            chain_info
        )
    end
    
    @testset "Performance Metrics" begin
        # Test metrics tracking
        swarm = create_arbitrage_swarm(1, Dict(), Dict())
        
        # Add some test trades
        push!(swarm.trades, Dict(
            "timestamp" => now(),
            "token" => "ETH",
            "profit" => 100.0,
            "gas_cost" => 50.0
        ))
        
        # Update metrics
        update_metrics(swarm)
        
        @test haskey(swarm.metrics, "total_profit")
        @test haskey(swarm.metrics, "total_gas_cost")
        @test haskey(swarm.metrics, "net_profit")
        @test haskey(swarm.metrics, "trade_count")
    end
    
    @testset "Error Handling" begin
        # Test invalid chain info
        @test_throws ArgumentError ChainInfo(
            "",
            "https://eth-mainnet.alchemyapi.io/v2/test-key",
            50.0,
            "0x1234567890123456789012345678901234567890",
            ["ETH"]
        )
        
        # Test invalid market data
        @test_throws ArgumentError find_opportunities(Dict(), Dict())
        
        # Test invalid opportunity
        @test_throws ArgumentError ArbitrageOpportunity(
            "",
            "ethereum",
            "polygon",
            2000.0,
            2010.0,
            0.005,
            100.0,
            ""
        )
    end
end 