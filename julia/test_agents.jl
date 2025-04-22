#!/usr/bin/env julia

# Test script for the enhanced Agents.jl implementation
println("Testing enhanced Agents.jl implementation...")

# Include the Agents.jl file directly
include(joinpath(@__DIR__, "src", "agents", "Agents.jl"))

# Use the Agents module
using .Agents

# Test 1: Create an agent with the new features
println("\n=== Test 1: Create an agent ===")
# Get the TRADING enum value
trading_type = Agents.AgentType(1) # TRADING = 1

config = AgentConfig(
    "TestAgent",
    trading_type,
    abilities=["ping", "llm_chat"],
    chains=["ethereum", "polygon"],
    parameters=Dict{String,Any}("test_param" => "test_value"),
    llm_config=Dict{String,Any}("model" => "gpt-4o-mini", "temperature" => 0.5),
    memory_config=Dict{String,Any}("max_size" => 1000, "retention_policy" => "lru")
)

agent = createAgent(config)
println("Created agent: $(agent.name) ($(agent.id))")
println("Agent status: $(agent.status)")
println("Agent abilities: $(agent.config.abilities)")
println("Agent has $(length(agent.skills)) skills")

# Test 2: Register a custom ability and skill
println("\n=== Test 2: Register custom ability and skill ===")
register_ability("test_ability", (agent, task) -> begin
    println("Executing test_ability for agent: $(agent.name)")
    return Dict("result" => "test_ability executed")
end)

register_skill("scheduled_skill", (agent) -> println("Scheduled skill executed for $(agent.name)"), schedule=5)
println("Registered custom ability and skill")

# Test 3: Start the agent
println("\n=== Test 3: Start the agent ===")
success = startAgent(agent.id)
println("Agent started: $success")
println("Agent status: $(getAgent(agent.id).status)")

# Test 4: Set and get agent memory
println("\n=== Test 4: Agent memory ===")
setAgentMemory(agent.id, "test_key", "test_value")
setAgentMemory(agent.id, "another_key", Dict("nested" => "value"))

# Test LRU behavior by adding many items
for i in 1:10
    setAgentMemory(agent.id, "key_$i", i)
end

value = getAgentMemory(agent.id, "test_key")
println("Memory test_key: $value")
value = getAgentMemory(agent.id, "key_5")
println("Memory key_5: $value")

# Test 5: Execute a task
println("\n=== Test 5: Execute a task ===")
result = executeAgentTask(agent.id, Dict{String,Any}("ability" => "ping"))
println("Task result: $result")

# Test 6: Queue a task
println("\n=== Test 6: Queue a task ===")
result = executeAgentTask(agent.id, Dict{String,Any}(
    "mode" => "queue",
    "ability" => "test_ability",
    "priority" => 10
))
println("Queue result: $result")

# Test 7: Get agent status
println("\n=== Test 7: Agent status ===")
status = getAgentStatus(agent.id)
println("Agent status: $status")

# Test 8: Test LLM chat (if OpenAI.jl is installed)
println("\n=== Test 8: LLM chat ===")
result = executeAgentTask(agent.id, Dict{String,Any}(
    "ability" => "llm_chat",
    "prompt" => "Hello, what can you do?"
))
println("LLM chat result: $(get(result, "answer", "No answer"))")

# Test 9: Publish to swarm
println("\n=== Test 9: Publish to swarm ===")
try
    publish_to_swarm(agent, Dict("message" => "Test message to swarm"))
    println("Published to swarm")
catch e
    println("Error publishing to swarm: $e")
end

# Test 10: Pause and resume agent
println("\n=== Test 10: Pause and resume agent ===")
pauseAgent(agent.id)
println("Agent paused, status: $(getAgent(agent.id).status)")
sleep(1)
resumeAgent(agent.id)
println("Agent resumed, status: $(getAgent(agent.id).status)")

# Test 11: Test persistence
println("\n=== Test 11: Test persistence ===")
println("Agents will be saved to: $(Agents.STORE_PATH)")

# Wait a bit to let the agent process tasks
println("\n=== Waiting for agent to process tasks (5 seconds) ===")
sleep(5)

# Test 12: Stop the agent
println("\n=== Test 12: Stop the agent ===")
stopAgent(agent.id)
println("Agent stopped, status: $(getAgent(agent.id).status)")

# Test 13: Delete the agent
println("\n=== Test 13: Delete the agent ===")
success = deleteAgent(agent.id)
println("Agent deleted: $success")

println("\nAll tests completed!")
