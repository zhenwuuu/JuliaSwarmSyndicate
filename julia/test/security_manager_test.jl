using Test
using Dates
using ..SecurityManager
using ..Blockchain
using ..DEX

# Test configuration
const TEST_CONFIG = SecurityConfig(
    "test_security_1",
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
        "anomaly_threshold" => 2.0,
        "max_incidents" => 10,
        "update_interval" => 60,
        "max_retries" => 3
    )
)

# Test data
const TEST_CONTRACT = "0x1234567890123456789012345678901234567890"
const TEST_ALERT = SecurityAlert(
    "test_alert_1",
    "anomaly",
    "high",
    "Suspicious transaction detected",
    Dict{String, Any}(
        "chain" => "ethereum",
        "contract" => TEST_CONTRACT,
        "transaction" => "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
        "amount" => BigInt(1000000000000000000),  # 1 ETH
        "timestamp" => now()
    )
)

# Test security initialization
@testset "Security Initialization" begin
    @test begin
        # Initialize security
        security = SecurityManager.initialize_security(TEST_CONFIG)
        security !== nothing
    end
    
    @test begin
        # Get security state
        state = SecurityManager.get_security_state()
        state !== nothing
    end
    
    @test begin
        # Get security metrics
        metrics = SecurityManager.get_security_metrics()
        metrics !== nothing
    end
end

# Test chain monitoring
@testset "Chain Monitoring" begin
    @test begin
        # Monitor chain activity
        activity = SecurityManager.monitor_chain_activity("ethereum")
        activity !== nothing
    end
    
    @test begin
        # Get chain metrics
        metrics = SecurityManager.get_chain_metrics("ethereum")
        metrics !== nothing
    end
    
    @test begin
        # Check chain health
        health = SecurityManager.check_chain_health("ethereum")
        health !== nothing
    end
    
    @test begin
        # Get chain alerts
        alerts = SecurityManager.get_chain_alerts("ethereum")
        alerts !== nothing
    end
end

# Test anomaly detection
@testset "Anomaly Detection" begin
    @test begin
        # Detect anomalies
        anomalies = SecurityManager.detect_anomalies("ethereum")
        anomalies !== nothing
    end
    
    @test begin
        # Get anomaly metrics
        metrics = SecurityManager.get_anomaly_metrics()
        metrics !== nothing
    end
    
    @test begin
        # Update anomaly model
        success = SecurityManager.update_anomaly_model()
        success
    end
    
    @test begin
        # Get anomaly history
        history = SecurityManager.get_anomaly_history()
        history !== nothing
    end
end

# Test contract monitoring
@testset "Contract Monitoring" begin
    @test begin
        # Monitor contract
        monitoring = SecurityManager.monitor_contract(TEST_CONTRACT)
        monitoring !== nothing
    end
    
    @test begin
        # Verify contract
        verification = SecurityManager.verify_contract(TEST_CONTRACT)
        verification !== nothing
    end
    
    @test begin
        # Get contract metrics
        metrics = SecurityManager.get_contract_metrics(TEST_CONTRACT)
        metrics !== nothing
    end
    
    @test begin
        # Get contract alerts
        alerts = SecurityManager.get_contract_alerts(TEST_CONTRACT)
        alerts !== nothing
    end
end

# Test incident response
@testset "Incident Response" begin
    @test begin
        # Handle security alert
        success = SecurityManager.handle_security_alert(TEST_ALERT)
        success
    end
    
    @test begin
        # Get incident history
        history = SecurityManager.get_incident_history()
        history !== nothing
    end
    
    @test begin
        # Emergency pause
        success = SecurityManager.emergency_pause()
        success
    end
    
    @test begin
        # Emergency resume
        success = SecurityManager.emergency_resume()
        success
    end
end

# Test access control
@testset "Access Control" begin
    @test begin
        # Check access
        has_access = SecurityManager.check_access(TEST_CONTRACT)
        has_access !== nothing
    end
    
    @test begin
        # Grant access
        success = SecurityManager.grant_access(TEST_CONTRACT)
        success
    end
    
    @test begin
        # Revoke access
        success = SecurityManager.revoke_access(TEST_CONTRACT)
        success
    end
    
    @test begin
        # Get access history
        history = SecurityManager.get_access_history()
        history !== nothing
    end
end

# Test error handling
@testset "Error Handling" begin
    @test begin
        # Test invalid chain
        activity = SecurityManager.monitor_chain_activity("invalid_chain")
        activity === nothing
    end
    
    @test begin
        # Test invalid contract
        monitoring = SecurityManager.monitor_contract("invalid_contract")
        monitoring === nothing
    end
    
    @test begin
        # Test invalid alert
        success = SecurityManager.handle_security_alert(nothing)
        !success
    end
    
    @test begin
        # Test invalid access
        has_access = SecurityManager.check_access("invalid_contract")
        has_access === nothing
    end
end

# Test cleanup
@testset "Cleanup" begin
    @test begin
        # Reset global state
        SECURITY_STATE[] = nothing
        true
    end
end 