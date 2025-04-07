using Test
using JuliaOS.CrossChain

@testset "Cross-Chain Functionality Tests" begin
    @testset "Chain Configuration" begin
        # Test chain info creation
        chain_info = ChainInfo(
            "ethereum",
            "https://eth-mainnet.alchemyapi.io/v2/test",
            50.0,  # gas price in gwei
            "0x1234...5678",  # bridge address
            ["ETH", "USDC", "WBTC"]  # supported tokens
        )
        
        @test chain_info.name == "ethereum"
        @test chain_info.rpc_url == "https://eth-mainnet.alchemyapi.io/v2/test"
        @test chain_info.gas_price == 50.0
        @test chain_info.bridge_address == "0x1234...5678"
        @test chain_info.supported_tokens == ["ETH", "USDC", "WBTC"]
    end
    
    @testset "Bridge Operations" begin
        # Test bridge initialization
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
        
        @test bridge.name == "test_bridge"
        @test length(bridge.chains) == 2
        @test haskey(bridge.chains, "ethereum")
        @test haskey(bridge.chains, "polygon")
        
        # Test token transfer
        transfer = TokenTransfer(
            "ETH",
            1.0,
            "ethereum",
            "polygon",
            "0xabcd...efgh",  # sender
            "0xijkl...mnop"   # recipient
        )
        
        @test transfer.token == "ETH"
        @test transfer.amount == 1.0
        @test transfer.source_chain == "ethereum"
        @test transfer.target_chain == "polygon"
    end
    
    @testset "Cross-Chain Price Monitoring" begin
        # Test price monitoring setup
        price_monitor = CrossChainPriceMonitor(
            Dict(
                "ethereum" => ["ETH/USDC", "WBTC/USDC"],
                "polygon" => ["ETH/USDC", "WBTC/USDC"]
            )
        )
        
        @test length(price_monitor.pairs) == 2
        @test haskey(price_monitor.pairs, "ethereum")
        @test haskey(price_monitor.pairs, "polygon")
        
        # Test price updates
        update_price!(price_monitor, "ethereum", "ETH/USDC", 2000.0)
        update_price!(price_monitor, "polygon", "ETH/USDC", 1995.0)
        
        @test price_monitor.prices["ethereum"]["ETH/USDC"] == 2000.0
        @test price_monitor.prices["polygon"]["ETH/USDC"] == 1995.0
    end
    
    @testset "Cross-Chain Arbitrage Detection" begin
        # Test arbitrage detection
        price_monitor = CrossChainPriceMonitor(
            Dict(
                "ethereum" => ["ETH/USDC"],
                "polygon" => ["ETH/USDC"]
            )
        )
        
        # Set up price differences
        update_price!(price_monitor, "ethereum", "ETH/USDC", 2000.0)
        update_price!(price_monitor, "polygon", "ETH/USDC", 1990.0)
        
        opportunities = find_arbitrage_opportunities(
            price_monitor,
            Dict(
                "min_profit_threshold" => 0.01,
                "max_slippage" => 0.005
            )
        )
        
        @test length(opportunities) > 0
        @test opportunities[1].source_chain == "polygon"
        @test opportunities[1].target_chain == "ethereum"
        @test opportunities[1].token == "ETH"
        @test opportunities[1].expected_profit > 0
    end
    
    @testset "Cross-Chain Transaction Execution" begin
        # Test transaction execution
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
        
        transfer = TokenTransfer(
            "ETH",
            1.0,
            "polygon",
            "ethereum",
            "0xabcd...efgh",
            "0xijkl...mnop"
        )
        
        # Test transaction preparation
        tx = prepare_cross_chain_transaction(bridge, transfer)
        @test tx.source_chain == "polygon"
        @test tx.target_chain == "ethereum"
        @test tx.token == "ETH"
        @test tx.amount == 1.0
        
        # Test transaction execution (mock)
        result = execute_cross_chain_transaction(bridge, tx)
        @test result.status == "success"
        @test haskey(result, "tx_hash")
        @test haskey(result, "timestamp")
    end
    
    @testset "Gas Price Monitoring" begin
        # Test gas price monitoring
        gas_monitor = GasPriceMonitor(
            Dict(
                "ethereum" => ChainInfo(
                    "ethereum",
                    "https://eth-mainnet.alchemyapi.io/v2/test",
                    50.0,
                    "0x1234...5678",
                    ["ETH", "USDC"]
                )
            )
        )
        
        # Test gas price updates
        update_gas_price!(gas_monitor, "ethereum", 55.0)
        @test gas_monitor.chains["ethereum"].gas_price == 55.0
        
        # Test gas price comparison
        is_optimal = check_gas_price_optimal(
            gas_monitor,
            "ethereum",
            Dict(
                "max_gas_price" => 100.0,
                "min_gas_price" => 20.0
            )
        )
        @test is_optimal isa Bool
    end
    
    @testset "Error Handling" begin
        # Test invalid chain info
        @test_throws ArgumentError ChainInfo(
            "",
            "https://eth-mainnet.alchemyapi.io/v2/test",
            50.0,
            "0x1234...5678",
            ["ETH", "USDC"]
        )
        
        # Test invalid bridge creation
        @test_throws ArgumentError Bridge(
            "",
            Dict(
                "ethereum" => ChainInfo(
                    "ethereum",
                    "https://eth-mainnet.alchemyapi.io/v2/test",
                    50.0,
                    "0x1234...5678",
                    ["ETH", "USDC"]
                )
            )
        )
        
        # Test invalid token transfer
        @test_throws ArgumentError TokenTransfer(
            "",
            1.0,
            "ethereum",
            "polygon",
            "0xabcd...efgh",
            "0xijkl...mnop"
        )
        
        # Test invalid price update
        price_monitor = CrossChainPriceMonitor(
            Dict(
                "ethereum" => ["ETH/USDC"]
            )
        )
        @test_throws ArgumentError update_price!(
            price_monitor,
            "invalid_chain",
            "ETH/USDC",
            2000.0
        )
    end
end 