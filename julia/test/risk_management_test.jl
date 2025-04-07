using Test
using Dates
using ..RiskManagement
using ..DEX
using ..SecurityManager

# Test configuration
const TEST_CONFIG = RiskConfig(
    "test_risk_1",
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
        "max_portfolio_value" => BigInt(1000000000000000000000),  # 1000 ETH
        "max_position_size" => BigInt(100000000000000000000),     # 100 ETH
        "max_leverage" => 5.0,
        "risk_per_trade" => 0.02,  # 2%
        "max_drawdown" => 0.1,      # 10%
        "stop_loss" => 0.05,        # 5%
        "take_profit" => 0.1,       # 10%
        "update_interval" => 60,
        "max_retries" => 3
    )
)

# Test data
const TEST_WALLET = "0x2222222222222222222222222222222222222222"
const TEST_TOKEN = "0x3333333333333333333333333333333333333333"
const TEST_AMOUNT = BigInt(1000000000000000000)  # 1 ETH
const TEST_PRICE = 2000.0  # $2000 per ETH

# Test portfolio management
@testset "Portfolio Management" begin
    @test begin
        # Initialize risk management
        risk = RiskManagement.initialize_risk(TEST_CONFIG)
        risk !== nothing
    end
    
    @test begin
        # Create portfolio
        portfolio = RiskManagement.create_portfolio(TEST_WALLET)
        portfolio !== nothing
    end
    
    @test begin
        # Update portfolio
        success = RiskManagement.update_portfolio(
            portfolio.id,
            TEST_TOKEN,
            TEST_AMOUNT,
            TEST_PRICE
        )
        success
    end
    
    @test begin
        # Get portfolio metrics
        metrics = RiskManagement.get_portfolio_metrics(portfolio.id)
        metrics !== nothing
    end
end

# Test position management
@testset "Position Management" begin
    @test begin
        # Calculate position size
        size = RiskManagement.calculate_position_size(
            portfolio.id,
            TEST_TOKEN,
            TEST_PRICE
        )
        size !== nothing
    end
    
    @test begin
        # Create position
        position = RiskManagement.create_position(
            portfolio.id,
            TEST_TOKEN,
            TEST_AMOUNT,
            TEST_PRICE
        )
        position !== nothing
    end
    
    @test begin
        # Update position
        success = RiskManagement.update_position(
            position.id,
            TEST_PRICE * 1.1  # 10% price increase
        )
        success
    end
    
    @test begin
        # Get position metrics
        metrics = RiskManagement.get_position_metrics(position.id)
        metrics !== nothing
    end
end

# Test risk assessment
@testset "Risk Assessment" begin
    @test begin
        # Assess cross-chain risk
        risk = RiskManagement.assess_cross_chain_risk(
            "ethereum",
            "base",
            TEST_TOKEN
        )
        risk !== nothing
    end
    
    @test begin
        # Estimate smart contract risk
        risk = RiskManagement.estimate_smart_contract_risk(
            TEST_TOKEN
        )
        risk !== nothing
    end
    
    @test begin
        # Calculate portfolio risk
        risk = RiskManagement.calculate_portfolio_risk(portfolio.id)
        risk !== nothing
    end
    
    @test begin
        # Get risk metrics
        metrics = RiskManagement.get_risk_metrics(portfolio.id)
        metrics !== nothing
    end
end

# Test risk controls
@testset "Risk Controls" begin
    @test begin
        # Check stop loss
        triggered = RiskManagement.check_stop_loss(
            position.id,
            TEST_PRICE * 0.95  # 5% price decrease
        )
        triggered
    end
    
    @test begin
        # Check take profit
        triggered = RiskManagement.check_take_profit(
            position.id,
            TEST_PRICE * 1.15  # 15% price increase
        )
        triggered
    end
    
    @test begin
        # Check portfolio limits
        within_limits = RiskManagement.check_portfolio_limits(
            portfolio.id,
            TEST_AMOUNT
        )
        within_limits
    end
    
    @test begin
        # Rebalance portfolio
        success = RiskManagement.rebalance_portfolio(portfolio.id)
        success
    end
end

# Test error handling
@testset "Error Handling" begin
    @test begin
        # Test invalid portfolio
        metrics = RiskManagement.get_portfolio_metrics("invalid_portfolio")
        metrics === nothing
    end
    
    @test begin
        # Test invalid position
        metrics = RiskManagement.get_position_metrics("invalid_position")
        metrics === nothing
    end
    
    @test begin
        # Test invalid token
        risk = RiskManagement.estimate_smart_contract_risk("invalid_token")
        risk === nothing
    end
    
    @test begin
        # Test invalid amount
        within_limits = RiskManagement.check_portfolio_limits(
            portfolio.id,
            BigInt(-1)  # Invalid amount
        )
        !within_limits
    end
end

# Test cleanup
@testset "Cleanup" begin
    @test begin
        # Delete portfolio
        success = RiskManagement.delete_portfolio(portfolio.id)
        success
    end
    
    @test begin
        # Reset global state
        RISK_STATE[] = nothing
        true
    end
end 