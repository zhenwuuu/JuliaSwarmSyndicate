using Test
using Dates
using ..AgentSystem
using ..Blockchain
using ..DEX
using ..RiskManagement
using ..SecurityManager

# Test configuration
const TEST_CONFIG = AgentConfig(
    "test_agent_1",
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
        "max_trades" => 10,
        "risk_limit" => 0.02,  # 2%
        "update_interval" => 60,
        "max_retries" => 3
    )
)

# Test data
const TEST_SKILL = AgentSkill(
    "market_analysis",
    "Analyze market conditions",
    Dict{String, Any}(
        "indicators" => ["price", "volume", "liquidity"],
        "thresholds" => Dict{String, Float64}(
            "price_change" => 0.05,
            "volume_change" => 0.1,
            "liquidity_change" => 0.15
        )
    )
)

const TEST_MESSAGE = AgentMessage(
    "test_message_1",
    "market_update",
    "high",
    Dict{String, Any}(
        "chain" => "ethereum",
        "token" => "0x1234567890123456789012345678901234567890",
        "price" => 2000.0,
        "timestamp" => now()
    )
)

# Test agent creation and management
@testset "Agent Creation and Management" begin
    @test begin
        # Create agent
        agent = AgentSystem.create_agent(TEST_CONFIG)
        agent !== nothing
    end
    
    @test begin
        # Get agent state
        state = AgentSystem.get_agent_state(agent.id)
        state !== nothing
    end
    
    @test begin
        # Update agent
        success = AgentSystem.update_agent(agent.id)
        success
    end
    
    @test begin
        # Get agent metrics
        metrics = AgentSystem.get_agent_metrics(agent.id)
        metrics !== nothing
    end
end

# Test skill management
@testset "Skill Management" begin
    @test begin
        # Add skill
        success = AgentSystem.add_skill(agent.id, TEST_SKILL)
        success
    end
    
    @test begin
        # Get agent skills
        skills = AgentSystem.get_agent_skills(agent.id)
        skills !== nothing
    end
    
    @test begin
        # Execute skill
        result = AgentSystem.execute_skill(
            agent.id,
            TEST_SKILL.name,
            Dict{String, Any}(
                "chain" => "ethereum",
                "token" => "0x1234567890123456789012345678901234567890"
            )
        )
        result !== nothing
    end
    
    @test begin
        # Remove skill
        success = AgentSystem.remove_skill(agent.id, TEST_SKILL.name)
        success
    end
end

# Test swarm coordination
@testset "Swarm Coordination" begin
    @test begin
        # Create swarm
        swarm = AgentSystem.create_swarm(
            "test_swarm_1",
            Dict{String, Any}(
                "consensus_threshold" => 0.7,
                "max_agents" => 10,
                "update_interval" => 60
            )
        )
        swarm !== nothing
    end
    
    @test begin
        # Add agent to swarm
        success = AgentSystem.add_agent_to_swarm(swarm.id, agent.id)
        success
    end
    
    @test begin
        # Update swarm
        success = AgentSystem.update_swarm(swarm.id)
        success
    end
    
    @test begin
        # Get swarm metrics
        metrics = AgentSystem.get_swarm_metrics(swarm.id)
        metrics !== nothing
    end
end

# Test message passing
@testset "Message Passing" begin
    @test begin
        # Send message
        success = AgentSystem.send_message(TEST_MESSAGE)
        success
    end
    
    @test begin
        # Get message history
        history = AgentSystem.get_message_history()
        history !== nothing
    end
    
    @test begin
        # Process message
        success = AgentSystem.process_message(TEST_MESSAGE.id)
        success
    end
    
    @test begin
        # Get pending messages
        pending = AgentSystem.get_pending_messages()
        pending !== nothing
    end
end

# Test consensus and decision making
@testset "Consensus and Decision Making" begin
    @test begin
        # Create proposal
        proposal = AgentSystem.create_proposal(
            swarm.id,
            "test_proposal_1",
            Dict{String, Any}(
                "action" => "trade",
                "token" => "0x1234567890123456789012345678901234567890",
                "amount" => BigInt(1000000000000000000)  # 1 ETH
            )
        )
        proposal !== nothing
    end
    
    @test begin
        # Vote on proposal
        success = AgentSystem.vote_on_proposal(
            proposal.id,
            agent.id,
            true
        )
        success
    end
    
    @test begin
        # Get proposal status
        status = AgentSystem.get_proposal_status(proposal.id)
        status !== nothing
    end
    
    @test begin
        # Execute approved proposal
        success = AgentSystem.execute_proposal(proposal.id)
        success
    end
end

# Test error handling
@testset "Error Handling" begin
    @test begin
        # Test invalid agent
        state = AgentSystem.get_agent_state("invalid_agent")
        state === nothing
    end
    
    @test begin
        # Test invalid swarm
        metrics = AgentSystem.get_swarm_metrics("invalid_swarm")
        metrics === nothing
    end
    
    @test begin
        # Test invalid skill execution
        result = AgentSystem.execute_skill(
            agent.id,
            "invalid_skill",
            Dict{String, Any}()
        )
        result === nothing
    end
    
    @test begin
        # Test invalid message processing
        success = AgentSystem.process_message("invalid_message")
        !success
    end
end

# Test cleanup
@testset "Cleanup" begin
    @test begin
        # Remove agent from swarm
        success = AgentSystem.remove_agent_from_swarm(swarm.id, agent.id)
        success
    end
    
    @test begin
        # Delete swarm
        success = AgentSystem.delete_swarm(swarm.id)
        success
    end
    
    @test begin
        # Delete agent
        success = AgentSystem.delete_agent(agent.id)
        success
    end
    
    @test begin
        # Reset global state
        AGENT_STATE[] = nothing
        true
    end
end 