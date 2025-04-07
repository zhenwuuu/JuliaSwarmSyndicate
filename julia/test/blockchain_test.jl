using Test
using Dates
using ..Blockchain
using ..SecurityManager

# Test configuration
const TEST_CONFIG = BlockchainConfig(
    "test_chain_1",
    "v1",
    "testnet",
    Dict{String, Dict{String, Any}}(
        "ethereum" => Dict{String, Any}(
            "rpc_url" => "https://eth-testnet.example.com",
            "ws_url" => "wss://eth-testnet.example.com",
            "chain_id" => 5,
            "confirmations" => 12,
            "max_gas_price" => 50000000000,
            "max_priority_fee" => 2000000000
        ),
        "base" => Dict{String, Any}(
            "rpc_url" => "https://base-testnet.example.com",
            "ws_url" => "wss://base-testnet.example.com",
            "chain_id" => 84531,
            "confirmations" => 6,
            "max_gas_price" => 1000000000,
            "max_priority_fee" => 100000000
        )
    ),
    Dict{String, Any}(
        "update_interval" => 60,
        "max_retries" => 3,
        "timeout" => 30
    )
)

# Test data
const TEST_WALLET = "0x2222222222222222222222222222222222222222"
const TEST_AMOUNT = BigInt(1000000000000000000)  # 1 ETH
const TEST_TX_HASH = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"
const TEST_BLOCK_HASH = "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890"

# Test chain connection
@testset "Chain Connection" begin
    @test begin
        # Connect to chain
        chain = Blockchain.connect_chain(TEST_CONFIG, "ethereum")
        chain !== nothing
    end
    
    @test begin
        # Get chain state
        state = Blockchain.get_chain_state(chain.id)
        state !== nothing
    end
    
    @test begin
        # Get chain metrics
        metrics = Blockchain.get_chain_metrics(chain.id)
        metrics !== nothing
    end
    
    @test begin
        # Disconnect from chain
        success = Blockchain.disconnect_chain(chain.id)
        success
    end
end

# Test transaction management
@testset "Transaction Management" begin
    @test begin
        # Get transaction status
        status = Blockchain.get_transaction_status(TEST_TX_HASH)
        status !== nothing
    end
    
    @test begin
        # Get transaction receipt
        receipt = Blockchain.get_transaction_receipt(TEST_TX_HASH)
        receipt !== nothing
    end
    
    @test begin
        # Get transaction history
        history = Blockchain.get_transaction_history(TEST_WALLET)
        history !== nothing
    end
    
    @test begin
        # Get pending transactions
        pending = Blockchain.get_pending_transactions()
        pending !== nothing
    end
end

# Test block operations
@testset "Block Operations" begin
    @test begin
        # Get latest block
        block = Blockchain.get_latest_block()
        block !== nothing
    end
    
    @test begin
        # Get block by number
        block = Blockchain.get_block_by_number(1000000)
        block !== nothing
    end
    
    @test begin
        # Get block by hash
        block = Blockchain.get_block_by_hash(TEST_BLOCK_HASH)
        block !== nothing
    end
    
    @test begin
        # Get block transactions
        transactions = Blockchain.get_block_transactions(TEST_BLOCK_HASH)
        transactions !== nothing
    end
end

# Test network operations
@testset "Network Operations" begin
    @test begin
        # Get network status
        status = Blockchain.get_network_status()
        status !== nothing
    end
    
    @test begin
        # Get gas price
        gas_price = Blockchain.get_gas_price()
        gas_price !== nothing
    end
    
    @test begin
        # Get network metrics
        metrics = Blockchain.get_network_metrics()
        metrics !== nothing
    end
    
    @test begin
        # Get network peers
        peers = Blockchain.get_network_peers()
        peers !== nothing
    end
end

# Test error handling
@testset "Error Handling" begin
    @test begin
        # Test invalid chain
        chain = Blockchain.connect_chain(TEST_CONFIG, "invalid_chain")
        chain === nothing
    end
    
    @test begin
        # Test invalid transaction
        status = Blockchain.get_transaction_status("invalid_hash")
        status === nothing
    end
    
    @test begin
        # Test invalid block
        block = Blockchain.get_block_by_number(-1)
        block === nothing
    end
    
    @test begin
        # Test invalid wallet
        history = Blockchain.get_transaction_history("invalid_wallet")
        history === nothing
    end
end

# Test cleanup
@testset "Cleanup" begin
    @test begin
        # Reset global state
        CHAIN_STATE[] = nothing
        true
    end
end 