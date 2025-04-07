# Security Integration Guide

This guide explains how to integrate and use the security components in your Web3 cross-chain DeFi project.

## Overview

The security system consists of several integrated components:

1. **SecurityManager.jl** - Core security functionality in Julia
2. **SecurityManager.ts** - TypeScript interface for client-side monitoring
3. **RiskManagement.jl** - Risk assessment algorithms
4. **Custom Security Modules** - User-extensible security plugins

## Getting Started

### Server-Side Setup

1. Import the required modules:

```julia
using JuliaOS.SecurityManager
using JuliaOS.SwarmManager
using JuliaOS.MLIntegration
using JuliaOS.RiskManagement
using JuliaOS.UserModules
```

2. Configure the security system:

```julia
# Create security configuration
security_config = SecurityManager.SecurityConfig(
    ["security@yourproject.com", "admin@yourproject.com"],  # emergency_contacts
    0.75,                                                   # anomaly_detection_threshold
    10.0,                                                   # max_transaction_value (in ETH)
    String[],                                               # paused_chains
    Dict(                                                   # risk_params
        "max_slippage" => 0.02,
        "max_gas_multiplier" => 3.0,
        "contract_risk_threshold" => 0.7
    ),
    60,                                                     # monitoring_interval (seconds)
    true                                                    # hooks_enabled
)

# Initialize security system
security_status = SecurityManager.initialize_security(security_config)
```

3. Set up multi-chain monitoring:

```julia
# Create cross-chain monitors
eth_arb_monitor = SecurityManager.CrossChainMonitor(
    "ethereum",                                      # source_chain
    ["arbitrum"],                                    # destination_chains
    "optimistic",                                    # bridge_type
    Dict("arbitrum" => "0x1234..."),                 # bridge_addresses
    Dict("arbitrum" => now()),                       # last_activity
    Dict("arbitrum" => "healthy"),                   # health_status
    Dict("arbitrum" => 0.1),                         # anomaly_score
    Dict("arbitrum" => 600.0)                        # message_finality_times (seconds)
)

# Start monitoring in a background task
@async begin
    while true
        # Monitor chain activity
        eth_metrics = SecurityManager.monitor_chain_activity("ethereum")
        
        # Check for anomalies
        if eth_metrics["anomaly_score"] > security_config.anomaly_detection_threshold
            # Take action on anomaly detection
            SecurityManager.create_incident_response(
                "chain_anomaly", 
                "high", 
                Dict("chain" => "ethereum", "metrics" => eth_metrics)
            )
        end
        
        # Sleep until next monitoring interval
        sleep(security_config.monitoring_interval)
    end
end
```

### Load Custom Security Extensions

```julia
# Load user modules
UserModules.load_user_modules()

# Get CustomSecurity module if available
if "CustomSecurity" in keys(UserModules.list_user_modules())
    custom_security = UserModules.get_user_module("CustomSecurity")
    
    # Create custom security configuration
    custom_config = custom_security.CustomSecurityConfig(
        Dict("ethereum" => 0.5, "arbitrum" => 0.6),           # custom_risk_thresholds
        ["0x123...", "0x456..."],                             # wallet_whitelist
        Dict("ethereum" => ["0x789...", "0xabc..."]),         # contract_whitelist
        ["https://alerts.example.com/webhook"],               # notification_endpoints
        "models/custom_security_model.jld2",                  # ml_model_path
        true                                                  # enable_advanced_monitoring
    )
    
    # Initialize custom security extensions
    custom_security.initialize_security_extensions(custom_config)
end
```

## Transaction Security Flow

### Pre-Transaction Risk Assessment

Before executing any transaction, assess its risk:

```julia
# Example transaction data
tx_data = Dict(
    "from" => "0x123...",
    "to" => "0x456...",
    "value" => 1.5,           # ETH amount
    "chain" => "ethereum",
    "gas_price" => 50.0,      # gwei
    "type" => "swap"
)

# Execute pre-transaction security hooks
hook_result = SecurityManager.execute_security_hooks("transaction_pre", tx_data)

# Check if transaction is allowed to proceed
if hook_result["status"] == "blocked"
    @error "Transaction blocked: $(hook_result["reason"])"
    # Handle blocked transaction
    return
end

# Assess transaction risk
risk_assessment = SecurityManager.assess_transaction_risk(tx_data)

# Based on risk assessment, decide whether to proceed
if risk_assessment["recommendation"] == "Abort"
    @error "High-risk transaction: $(risk_assessment["overall_risk"])"
    # Require additional approval or abort
elseif risk_assessment["recommendation"] == "Caution"
    @warn "Proceed with caution: $(risk_assessment["overall_risk"])"
    # May require additional verification
end
```

### Post-Transaction Monitoring

After transaction execution, analyze the results:

```julia
# Example transaction result
tx_result = Dict(
    "transaction_hash" => "0xabc...",
    "status" => "success",
    "block_number" => 12345678,
    "gas_used" => 150000,
    "effective_gas_price" => 45.0
)

# Merge with original tx data
tx_data = merge(tx_data, tx_result)

# Execute post-transaction security hooks
SecurityManager.execute_security_hooks("transaction_post", tx_data)
```

## Emergency Response

When security incidents are detected:

```julia
# Example incident response
incident = SecurityManager.create_incident_response(
    "bridge_exploit",           # incident_type
    "critical",                 # severity
    Dict(                       # details
        "chain" => "optimism",
        "bridge_address" => "0x789...",
        "estimated_loss" => 500000.0,
        "attack_vector" => "price oracle manipulation"
    )
)

# Take immediate action based on incident
if incident["severity"] == "critical"
    # Pause affected contracts
    SecurityManager.emergency_pause!(incident["details"]["chain"], 
                                    "Critical security incident: $(incident["incident_type"])")
    
    # Generate comprehensive security report
    report = SecurityManager.generate_security_report()
    
    # Notify security team (implementation dependent)
    # notify_security_team(incident, report)
end
```

## Client-Side Integration

In your frontend application:

```typescript
import { SecurityManager, SecurityConfig } from './SecurityManager';

// Create security configuration
const securityConfig: SecurityConfig = {
  emergencyContacts: ['security@yourproject.com'],
  anomalyDetectionThreshold: 0.75,
  maxTransactionValue: 10.0,
  pausedChains: [],
  riskParams: {
    maxSlippage: 0.02,
    maxGasMultiplier: 3.0,
    contractRiskThreshold: 0.7
  },
  monitoringInterval: 60,
  hooksEnabled: true
};

// Initialize security manager
const securityManager = new SecurityManager(securityConfig);
await securityManager.initialize();

// Before sending transaction, assess risk
async function sendTransaction(transaction) {
  // Check if chain is paused
  if (securityManager.isChainPaused(transaction.chain)) {
    showError('Chain is currently paused due to security concerns');
    return;
  }
  
  // For cross-chain transactions, check bridge status
  if (transaction.destinationChain) {
    if (!securityManager.isBridgeOperational(
      transaction.chain, 
      transaction.destinationChain
    )) {
      showError('Bridge is currently not operational');
      return;
    }
  }
  
  // Assess transaction risk
  const riskAssessment = await securityManager.assessTransactionRisk(transaction);
  
  // Based on risk level, take appropriate action
  if (riskAssessment.recommendation === 'Abort') {
    showError(`High-risk transaction detected (${riskAssessment.riskCategory})`);
    return;
  } else if (riskAssessment.recommendation === 'Caution') {
    // Show warning and require explicit confirmation
    if (!await showWarningAndConfirm(
      `This transaction has ${riskAssessment.riskCategory} risk. Proceed anyway?`
    )) {
      return;
    }
  }
  
  // Proceed with transaction
  // ...actual transaction code...
}
```

## Using Swarm Intelligence for Security

The security system leverages SwarmManager's optimization capabilities for risk assessment:

```julia
# Create a swarm for security optimization
swarm_config = SwarmManager.SwarmConfig(
    "security_optimization",                # name
    30,                                     # size
    "pso",                                  # algorithm
    ["ethereum", "arbitrum", "optimism"],   # trading_pairs
    Dict(                                   # parameters
        "inertia_weight" => 0.7,
        "cognitive_coef" => 1.5,
        "social_coef" => 1.5
    )
)

security_swarm = SwarmManager.create_swarm(swarm_config)

# Use the swarm to optimize security parameters
# (This would be done periodically to adapt to changing conditions)
@async begin
    while true
        # Collect security metrics
        metrics = Dict{String, Vector{Float64}}()
        
        for chain in ["ethereum", "arbitrum", "optimism"]
            chain_metrics = SecurityManager.monitor_chain_activity(chain, 24*3600)  # Last 24 hours
            
            # Extract key metrics for optimization
            metrics[chain] = [
                chain_metrics["transaction_count"],
                mean(chain_metrics["gas_prices"]),
                chain_metrics["anomaly_score"]
            ]
        end
        
        # Transform metrics into market data format for SwarmManager
        market_data = []  # This would be properly formatted in real implementation
        
        # Update swarm with new data
        SwarmManager.update_swarm!(security_swarm, market_data)
        
        # Extract optimized parameters
        optimized_params = security_swarm.performance_metrics
        
        # Update security thresholds based on optimization
        # ...
        
        sleep(3600)  # Optimize hourly
    end
end
```

## Best Practices

1. **Defense in Depth** - Use multiple layers of security monitoring
2. **Continuous Monitoring** - Keep security systems running 24/7
3. **Modular Updates** - Use UserModules system to update security logic without redeploying
4. **Adaptive Thresholds** - Use ML and swarm intelligence to adapt to changing conditions
5. **Emergency Preparedness** - Test emergency response procedures regularly

## Security Checklist

Before deploying to production:

- [ ] Configure emergency contacts and notification systems
- [ ] Set appropriate risk thresholds for each chain
- [ ] Implement circuit breakers and emergency pause functionality
- [ ] Test cross-chain monitoring with simulated anomalies
- [ ] Create and test incident response procedures
- [ ] Integrate client-side security checks in all transaction flows
- [ ] Deploy custom security extensions for project-specific risks 