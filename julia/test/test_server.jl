using Test
using HTTP
using WebSockets
using JSON
using JuliaOS

# Test helper functions
function create_test_swarm()
    n_agents = 10
    agents, emergent, task_allocator, learner = create_advanced_swarm(n_agents)
    return Dict(
        "agents" => agents,
        "emergent" => emergent,
        "task_allocator" => task_allocator,
        "learner" => learner,
        "created_at" => now()
    )
end

# Test HTTP endpoints
@testset "HTTP Endpoints" begin
    # Start server in test mode
    http_server, ws_server = start_server("127.0.0.1", 8081)
    
    # Test health endpoint
    response = HTTP.request("GET", "http://127.0.0.1:8081/health")
    @test response.status == 200
    health_data = JSON.parse(String(response.body))
    @test haskey(health_data, "status")
    @test haskey(health_data, "memory_usage")
    @test haskey(health_data, "active_agents")
    
    # Test swarm creation
    response = HTTP.request(
        "POST",
        "http://127.0.0.1:8081/swarm/create",
        ["Content-Type" => "application/json"],
        JSON.json(Dict("n_agents" => 10))
    )
    @test response.status == 200
    swarm_data = JSON.parse(String(response.body))
    @test haskey(swarm_data, "swarm_id")
    swarm_id = swarm_data["swarm_id"]
    
    # Test swarm retrieval
    response = HTTP.request("GET", "http://127.0.0.1:8081/swarm/$swarm_id")
    @test response.status == 200
    swarm_info = JSON.parse(String(response.body))
    @test haskey(swarm_info, "agents")
    @test haskey(swarm_info, "emergent")
    @test haskey(swarm_info, "task_allocator")
    @test haskey(swarm_info, "learner")
    
    # Test non-existent swarm
    response = HTTP.request("GET", "http://127.0.0.1:8081/swarm/nonexistent")
    @test response.status == 404
    
    # Cleanup
    close(http_server)
    close(ws_server)
end

# Test WebSocket functionality
@testset "WebSocket Functionality" begin
    # Start server in test mode
    http_server, ws_server = start_server("127.0.0.1", 8082)
    
    # Create a test swarm
    swarm_id = string(UUIDs.uuid4())
    SERVER_STATE["active_swarms"][swarm_id] = create_test_swarm()
    
    # Test WebSocket connection and message handling
    client = WebSocket("ws://127.0.0.1:8083")
    
    # Test subscribing to swarm updates
    send(client, JSON.json(Dict(
        "type" => "subscribe_swarm",
        "swarm_id" => swarm_id
    )))
    
    # Wait for a few updates
    updates = 0
    for _ in 1:5
        message = receive(client)
        data = JSON.parse(message)
        if data["type"] == "swarm_update"
            updates += 1
        end
        sleep(0.1)
    end
    
    @test updates > 0
    
    # Test swarm control
    send(client, JSON.json(Dict(
        "type" => "control_swarm",
        "swarm_id" => swarm_id,
        "action" => "pause"
    )))
    
    response = receive(client)
    data = JSON.parse(response)
    @test data["type"] == "status"
    @test data["message"] == "Swarm paused"
    
    # Cleanup
    close(client)
    close(http_server)
    close(ws_server)
end

# Test error handling
@testset "Error Handling" begin
    # Start server in test mode
    http_server, ws_server = start_server("127.0.0.1", 8084)
    
    # Test invalid JSON in request body
    response = HTTP.request(
        "POST",
        "http://127.0.0.1:8084/swarm/create",
        ["Content-Type" => "application/json"],
        "invalid json"
    )
    @test response.status == 500
    
    # Test WebSocket error handling
    client = WebSocket("ws://127.0.0.1:8085")
    
    # Test invalid message type
    send(client, JSON.json(Dict(
        "type" => "invalid_type",
        "swarm_id" => "test"
    )))
    
    response = receive(client)
    data = JSON.parse(response)
    @test data["type"] == "error"
    @test data["message"] == "Unknown message type"
    
    # Cleanup
    close(client)
    close(http_server)
    close(ws_server)
end

# Test system health monitoring
@testset "System Health Monitoring" begin
    # Start server in test mode
    http_server, ws_server = start_server("127.0.0.1", 8086)
    
    # Wait for health check to run
    sleep(2)
    
    # Check that health check data is being updated
    @test SERVER_STATE["last_health_check"] !== nothing
    
    health_data = SERVER_STATE["last_health_check"]
    @test haskey(health_data, "status")
    @test haskey(health_data, "memory_usage")
    @test haskey(health_data, "active_agents")
    
    # Cleanup
    close(http_server)
    close(ws_server)
end 