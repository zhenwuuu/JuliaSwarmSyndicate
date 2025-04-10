using Test
using Dates
using JSON
using UUIDs

# Import modules to test
using Blockchain

function run_blockchain_tests()
    @testset "Blockchain Connection" begin
        # Test connecting to Ethereum
        eth_connection = Blockchain.connect(network="ethereum")
        @test eth_connection !== nothing
        @test eth_connection.network == "ethereum"
        
        # Test connecting to Solana
        sol_connection = Blockchain.connect(network="solana")
        @test sol_connection !== nothing
        @test sol_connection.network == "solana"
    end
    
    @testset "Blockchain Status" begin
        # Test getting Ethereum status
        eth_connection = Blockchain.connect(network="ethereum")
        eth_status = Blockchain.getStatus(eth_connection)
        
        @test eth_status !== nothing
        @test haskey(eth_status, "connected")
        @test haskey(eth_status, "block_height")
        
        # Test getting Solana status
        sol_connection = Blockchain.connect(network="solana")
        sol_status = Blockchain.getStatus(sol_connection)
        
        @test sol_status !== nothing
        @test haskey(sol_status, "connected")
        @test haskey(sol_status, "block_height")
    end
    
    @testset "Balance Operations" begin
        # Test getting Ethereum balance
        eth_connection = Blockchain.connect(network="ethereum")
        eth_address = "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"  # Test address
        
        eth_balance = Blockchain.getBalance(eth_address, eth_connection)
        @test eth_balance !== nothing
        
        # Test getting Solana balance
        sol_connection = Blockchain.connect(network="solana")
        sol_address = "5U3bH5b6XtG99aVWLqwVzYPVpQiFHytBD68Rz2eFPZd7"  # Test address
        
        sol_balance = Blockchain.getBalance(sol_address, sol_connection)
        @test sol_balance !== nothing
    end
    
    @testset "Token Operations" begin
        # Test getting Ethereum token balance
        eth_connection = Blockchain.connect(network="ethereum")
        eth_address = "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"  # Test address
        usdc_address = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"  # USDC on Ethereum
        
        usdc_balance = Blockchain.getTokenBalance(eth_address, usdc_address, eth_connection)
        @test usdc_balance !== nothing
        
        # Test getting token decimals
        usdc_decimals = Blockchain.getDecimals(usdc_address, eth_connection)
        @test usdc_decimals !== nothing
        @test usdc_decimals == 6  # USDC has 6 decimals
    end
    
    @testset "Transaction Operations" begin
        # Test estimating gas
        eth_connection = Blockchain.connect(network="ethereum")
        from_address = "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
        to_address = "0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984"
        
        gas_estimate = Blockchain.estimateGas(
            from_address,
            to_address,
            "0x0",  # No value
            "0x",   # No data
            eth_connection
        )
        
        @test gas_estimate !== nothing
        @test gas_estimate > 0
        
        # Test getting gas price
        gas_price = Blockchain.getGasPrice(eth_connection)
        @test gas_price !== nothing
        @test gas_price > 0
    end
    
    @testset "Block Operations" begin
        # Test getting latest block
        eth_connection = Blockchain.connect(network="ethereum")
        latest_block = Blockchain.getLatestBlock(eth_connection)
        
        @test latest_block !== nothing
        @test haskey(latest_block, "number")
        @test haskey(latest_block, "hash")
        @test haskey(latest_block, "timestamp")
        
        # Test getting block by number
        block_number = latest_block["number"] - 10
        block = Blockchain.getBlockByNumber(block_number, eth_connection)
        
        @test block !== nothing
        @test block["number"] == block_number
    end
    
    @testset "Contract Operations" begin
        # Test getting contract ABI
        eth_connection = Blockchain.connect(network="ethereum")
        usdc_address = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"  # USDC on Ethereum
        
        abi = Blockchain.getContractABI(usdc_address, eth_connection)
        @test abi !== nothing
        @test length(abi) > 0
        
        # Test calling contract method
        method = "decimals"
        args = []
        
        result = Blockchain.callContractMethod(usdc_address, method, args, eth_connection)
        @test result !== nothing
        @test result == 6  # USDC has 6 decimals
    end
    
    @testset "Cross-Chain Operations" begin
        # Test getting supported chains
        chains = Blockchain.getSupportedChains()
        @test chains !== nothing
        @test "ethereum" in chains
        @test "solana" in chains
        
        # Test getting chain info
        eth_info = Blockchain.getChainInfo("ethereum")
        @test eth_info !== nothing
        @test eth_info["chain_id"] == 1
        
        sol_info = Blockchain.getChainInfo("solana")
        @test sol_info !== nothing
        @test sol_info["chain_id"] == 1
    end
end
