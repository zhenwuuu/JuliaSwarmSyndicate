using Test
using Dates
using JSON
using UUIDs

# Import modules to test
using Wallet
using WalletIntegration

function run_wallet_tests()
    @testset "Wallet Creation and Management" begin
        # Test wallet creation
        wallet_id = string(uuid4())
        wallet_name = "Test Wallet"
        
        create_result = Wallet.create_wallet(wallet_id, wallet_name)
        @test create_result["success"] == true
        @test create_result["wallet"]["id"] == wallet_id
        @test create_result["wallet"]["name"] == wallet_name
        
        # Test getting wallet info
        info_result = Wallet.get_wallet_info(wallet_id)
        @test info_result["success"] == true
        @test info_result["wallet"]["id"] == wallet_id
        @test info_result["wallet"]["name"] == wallet_name
        
        # Test listing wallets
        list_result = Wallet.list_wallets()
        @test list_result["success"] == true
        @test wallet_id in [wallet["id"] for wallet in list_result["wallets"]]
        
        # Test updating wallet
        update_result = Wallet.update_wallet(wallet_id, Dict("name" => "Updated Test Wallet"))
        @test update_result["success"] == true
        @test update_result["wallet"]["name"] == "Updated Test Wallet"
        
        # Test deleting wallet
        delete_result = Wallet.delete_wallet(wallet_id)
        @test delete_result["success"] == true
        
        # Verify deletion
        verify_result = Wallet.get_wallet_info(wallet_id)
        @test verify_result["success"] == false
    end
    
    @testset "Wallet Address Management" begin
        # Create test wallet
        wallet_id = string(uuid4())
        Wallet.create_wallet(wallet_id, "Address Test Wallet")
        
        # Test generating Ethereum address
        eth_result = Wallet.generate_address(wallet_id, "ethereum")
        @test eth_result["success"] == true
        @test haskey(eth_result, "address")
        @test startswith(eth_result["address"], "0x")
        
        # Test generating Solana address
        sol_result = Wallet.generate_address(wallet_id, "solana")
        @test sol_result["success"] == true
        @test haskey(sol_result, "address")
        
        # Test getting addresses
        addresses_result = Wallet.get_addresses(wallet_id)
        @test addresses_result["success"] == true
        @test haskey(addresses_result["addresses"], "ethereum")
        @test haskey(addresses_result["addresses"], "solana")
        
        # Test getting specific address
        eth_address_result = Wallet.get_address(wallet_id, "ethereum")
        @test eth_address_result["success"] == true
        @test eth_address_result["address"] == addresses_result["addresses"]["ethereum"]
        
        # Clean up
        Wallet.delete_wallet(wallet_id)
    end
    
    @testset "Wallet Balance Operations" begin
        # Create test wallet
        wallet_id = string(uuid4())
        Wallet.create_wallet(wallet_id, "Balance Test Wallet")
        
        # Generate addresses
        Wallet.generate_address(wallet_id, "ethereum")
        Wallet.generate_address(wallet_id, "solana")
        
        # Test getting Ethereum balance
        eth_balance = Wallet.get_balance(wallet_id, "ethereum")
        @test eth_balance["success"] == true
        @test haskey(eth_balance, "balance")
        
        # Test getting Solana balance
        sol_balance = Wallet.get_balance(wallet_id, "solana")
        @test sol_balance["success"] == true
        @test haskey(sol_balance, "balance")
        
        # Test getting token balance
        usdc_address = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"  # USDC on Ethereum
        token_balance = Wallet.get_token_balance(wallet_id, "ethereum", usdc_address)
        @test token_balance["success"] == true
        @test haskey(token_balance, "balance")
        
        # Clean up
        Wallet.delete_wallet(wallet_id)
    end
    
    @testset "Wallet Integration" begin
        # Test getting supported chains
        chains = WalletIntegration.get_supported_chains()
        @test chains["success"] == true
        @test "ethereum" in chains["chains"]
        @test "solana" in chains["chains"]
        
        # Test getting chain info
        eth_info = WalletIntegration.get_chain_info("ethereum")
        @test eth_info["success"] == true
        @test eth_info["chain_info"]["name"] == "Ethereum"
        
        # Test message signing (mock implementation)
        address = "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
        message = "Test message"
        
        sign_result = WalletIntegration.sign_message(address, "ethereum", message)
        @test sign_result["success"] == true
        @test haskey(sign_result, "signature")
    end
    
    @testset "Wallet Security" begin
        # Create test wallet
        wallet_id = string(uuid4())
        Wallet.create_wallet(wallet_id, "Security Test Wallet")
        
        # Test setting password
        password = "TestPassword123!"
        set_password_result = Wallet.set_password(wallet_id, password)
        @test set_password_result["success"] == true
        
        # Test verifying password
        verify_result = Wallet.verify_password(wallet_id, password)
        @test verify_result["success"] == true
        
        # Test verifying incorrect password
        wrong_verify_result = Wallet.verify_password(wallet_id, "WrongPassword")
        @test wrong_verify_result["success"] == false
        
        # Test changing password
        new_password = "NewTestPassword456!"
        change_result = Wallet.change_password(wallet_id, password, new_password)
        @test change_result["success"] == true
        
        # Verify new password
        new_verify_result = Wallet.verify_password(wallet_id, new_password)
        @test new_verify_result["success"] == true
        
        # Clean up
        Wallet.delete_wallet(wallet_id)
    end
    
    @testset "Wallet Backup and Recovery" begin
        # Create test wallet
        wallet_id = string(uuid4())
        Wallet.create_wallet(wallet_id, "Backup Test Wallet")
        
        # Test getting recovery phrase
        phrase_result = Wallet.get_recovery_phrase(wallet_id)
        @test phrase_result["success"] == true
        @test haskey(phrase_result, "phrase")
        @test length(split(phrase_result["phrase"], " ")) == 12
        
        # Test exporting wallet
        export_result = Wallet.export_wallet(wallet_id)
        @test export_result["success"] == true
        @test haskey(export_result, "data")
        
        # Test importing wallet
        import_id = string(uuid4())
        import_result = Wallet.import_wallet(import_id, "Imported Wallet", export_result["data"])
        @test import_result["success"] == true
        @test import_result["wallet"]["id"] == import_id
        
        # Clean up
        Wallet.delete_wallet(wallet_id)
        Wallet.delete_wallet(import_id)
    end
end
