"""
    Server module for JuliaOS

This module provides the HTTP server functionality for JuliaOS.
"""

module Server

using HTTP
using JSON
using Logging
using Dates

export start_server, stop_server, get_status

# Global server reference
global server_task = nothing
global is_running = false

"""
    start_server(host="localhost", port=8052)

Start the HTTP server for JuliaOS on the specified host and port.
"""
function start_server(host="localhost", port=8052)
    global server_task, is_running
    
    if is_running
        @info "Server is already running"
        return true
    end
    
    try
        # Create HTTP endpoints
        router = HTTP.Router()
        
        # Health check endpoint
        HTTP.register!(router, "GET", "/health", health_handler)
        
        # API endpoint for commands
        HTTP.register!(router, "POST", "/api", api_handler)
        
        # Start the server
        @info "Starting JuliaOS server on $host:$port"
        server = HTTP.serve!(router, host, port)
        is_running = true
        server_task = server
        
        @info "JuliaOS server started successfully"
        return true
    catch e
        @error "Failed to start server" exception=(e, catch_backtrace())
        return false
    end
end

"""
    stop_server()

Stop the running HTTP server.
"""
function stop_server()
    global server_task, is_running
    
    if !is_running
        @info "Server is not running"
        return true
    end
    
    try
        close(server_task)
        server_task = nothing
        is_running = false
        @info "JuliaOS server stopped successfully"
        return true
    catch e
        @error "Failed to stop server" exception=(e, catch_backtrace())
        return false
    end
end

"""
    get_status()

Get the current server status.
"""
function get_status()
    global is_running
    
    return Dict(
        "running" => is_running,
        "timestamp" => now()
    )
end

# Health check handler
function health_handler(req::HTTP.Request)
    response = Dict(
        "status" => "healthy",
        "timestamp" => string(now()),
        "version" => "1.0.0"
    )
    
    return HTTP.Response(
        200,
        ["Content-Type" => "application/json"],
        JSON.json(response)
    )
end

# API request handler
function api_handler(req::HTTP.Request)
    try
        # Parse the request body as JSON
        body = JSON.parse(String(req.body))
        
        # Basic request validation
        if !haskey(body, "command")
            return HTTP.Response(
                400,
                ["Content-Type" => "application/json"],
                JSON.json(Dict(
                    "success" => false,
                    "error" => "Missing required field: command"
                ))
            )
        end
        
        # Process the command
        response = handle_command(body)
        
        return HTTP.Response(
            200,
            ["Content-Type" => "application/json"],
            JSON.json(response)
        )
    catch e
        @error "Error processing API request" exception=(e, catch_backtrace())
        
        return HTTP.Response(
            500,
            ["Content-Type" => "application/json"],
            JSON.json(Dict(
                "success" => false,
                "error" => "Internal server error: $(typeof(e))"
            ))
        )
    end
end

"""
    handle_command(request::Dict)

Process a command request and return the appropriate response.
"""
function handle_command(request::Dict)
    command = request["command"]
    params = get(request, "params", Dict())
    
    @info "Processing command: $command with params: $params"
    
    # Mock implementation - just echo back the request
    response = Dict(
        "success" => true,
        "command" => command,
        "result" => "Command processed successfully",
        "echo" => params,
        "timestamp" => string(now())
    )
    
    return response
end

end # module 