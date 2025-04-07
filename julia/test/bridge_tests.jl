using Test
using JuliaOS
using JuliaOS.Bridge
using JuliaOS.Config
using TestUtils
using Dates

@testset "Bridge Operations Tests" begin
    @testset "Bridge Initialization" begin
        TestUtils.with_test_bridge(bridge -> begin
            @test bridge.is_connected
            @test haskey(bridge.chain_status, "ethereum")
            @test haskey(bridge.chain_status, "solana")
            @test haskey(bridge.token_balances, "ethereum")
            @test haskey(bridge.token_balances, "solana")
        end)
    end

    @testset "Chain Status" begin
        TestUtils.with_test_bridge(bridge -> begin
            # Test Ethereum chain status
            eth_status = Bridge.get_chain_status("ethereum")
            @test eth_status["connected"]
            @test eth_status["block_height"] > 0
            @test eth_status["gas_price"] > 0

            # Test Solana chain status
            sol_status = Bridge.get_chain_status("solana")
            @test sol_status["connected"]
            @test sol_status["block_height"] > 0
            @test sol_status["gas_price"] > 0

            # Test invalid chain
            @test_throws ArgumentError Bridge.get_chain_status("invalid_chain")
        end)
    end

    @testset "Token Balances" begin
        TestUtils.with_test_bridge(bridge -> begin
            # Test Ethereum token balances
            eth_balance = Bridge.get_token_balance("ethereum", "ETH")
            @test eth_balance > 0
            usdc_balance = Bridge.get_token_balance("ethereum", "USDC")
            @test usdc_balance > 0

            # Test Solana token balances
            sol_balance = Bridge.get_token_balance("solana", "SOL")
            @test sol_balance > 0
            usdc_balance = Bridge.get_token_balance("solana", "USDC")
            @test usdc_balance > 0

            # Test invalid token
            @test_throws ArgumentError Bridge.get_token_balance("ethereum", "INVALID")
        end)
    end

    @testset "Cross-Chain Transfers" begin
        TestUtils.with_test_bridge(bridge -> begin
            # Test transfer from Ethereum to Solana
            transfer = Bridge.initiate_transfer(
                "ethereum",
                "solana",
                "USDC",
                100.0
            )
            @test transfer !== nothing
            @test haskey(transfer, "tx_hash")
            @test haskey(transfer, "status")
            @test transfer["status"] in ["pending", "completed"]

            # Test transfer with insufficient balance
            @test_throws ArgumentError Bridge.initiate_transfer(
                "ethereum",
                "solana",
                "ETH",
                1000.0
            )

            # Test transfer with invalid token
            @test_throws ArgumentError Bridge.initiate_transfer(
                "ethereum",
                "solana",
                "INVALID",
                100.0
            )
        end)
    end

    @testset "Transaction Monitoring" begin
        TestUtils.with_test_bridge(bridge -> begin
            # Test pending transactions
            pending = Bridge.get_pending_transactions()
            @test pending isa Vector
            @test !isempty(pending)

            # Test transaction history
            history = Bridge.get_transaction_history(
                Dates.now() - Day(7),
                Dates.now()
            )
            @test history isa Vector
            @test !isempty(history)

            # Test transaction details
            if !isempty(history)
                tx = history[1]
                @test haskey(tx, "tx_hash")
                @test haskey(tx, "from_chain")
                @test haskey(tx, "to_chain")
                @test haskey(tx, "token")
                @test haskey(tx, "amount")
                @test haskey(tx, "status")
                @test haskey(tx, "timestamp")
            end
        end)
    end

    @testset "Bridge Configuration" begin
        TestUtils.with_test_bridge(bridge -> begin
            # Test bridge configuration
            config = Bridge.get_bridge_config()
            @test config !== nothing
            @test haskey(config, "chains")
            @test haskey(config, "max_retries")
            @test haskey(config, "timeout")
            @test haskey(config, "gas_limit")

            # Test chain configuration
            eth_config = config["chains"]["ethereum"]
            @test haskey(eth_config, "rpc_url")
            @test haskey(eth_config, "chain_id")
            @test haskey(eth_config, "gas_price")
            @test haskey(eth_config, "confirmations")
            @test haskey(eth_config, "timeout")
        end)
    end

    @testset "Error Handling" begin
        TestUtils.with_test_bridge(bridge -> begin
            # Test network error handling
            @test_throws HTTP.RequestError Bridge.get_chain_status("ethereum")

            # Test timeout handling
            @test_throws TimeoutError Bridge.initiate_transfer(
                "ethereum",
                "solana",
                "USDC",
                100.0
            )

            # Test invalid configuration
            @test_throws ArgumentError Bridge.set_bridge_config(Dict())
        end)
    end
end 