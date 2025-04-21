"""
    API module for JuliaOS

This module provides the HTTP server functionality for JuliaOS.
"""

module API

using HTTP
using JSON
using Logging
using Dates

export start_server, stop_server, is_running, handle_command

# Server state
const SERVER_STATE = Dict{String, Any}(
    "is_running" => false,
    "start_time" => nothing,
    "server" => nothing,
    "host" => "localhost",
    "port" => 8052
)

"""
    is_running()

Check if the server is running.
"""
function is_running()
    return get(SERVER_STATE, "is_running", false)
end

"""
    start_server(host::String, port::Int)

Start the HTTP server on the specified host and port.
"""
function start_server(host::String, port::Int)
    if is_running()
        @warn "Server is already running"
        return true
    end

    try
        # Update server state
        SERVER_STATE["host"] = host
        SERVER_STATE["port"] = port
        SERVER_STATE["start_time"] = now()

        # Create router
        router = HTTP.Router()

        # Add health check endpoint
        HTTP.register!(router, "GET", "/health", function(req)
            uptime_seconds = 0
            if SERVER_STATE["start_time"] !== nothing
                uptime_seconds = Dates.value(now() - SERVER_STATE["start_time"]) / 1000
            end

            # Check component status
            components = Dict(
                "server" => Dict("status" => "healthy"),
                "storage" => Dict("status" => isdefined(Main.JuliaOS, :Storage) ? "healthy" : "unavailable"),
                "framework" => Dict("status" => Main.JuliaOS.FRAMEWORK_EXISTS ? "healthy" : "unavailable")
            )

            return HTTP.Response(200, ["Content-Type" => "application/json"],
                JSON.json(Dict(
                    "status" => "healthy",
                    "uptime_seconds" => uptime_seconds,
                    "timestamp" => string(now()),
                    "version" => "1.0.0",
                    "components" => components
                )))
        end)

        # Add API endpoint
        HTTP.register!(router, "POST", "/api", function(req)
            try
                # Parse request body
                body = JSON.parse(String(req.body))

                # Process the command
                result = handle_command(body)

                # Return the result
                return HTTP.Response(200, ["Content-Type" => "application/json"], JSON.json(result))
            catch e
                @error "Error processing API request" exception=(e, catch_backtrace())
                return HTTP.Response(500, ["Content-Type" => "application/json"],
                    JSON.json(Dict("success" => false, "error" => "Internal server error: $(typeof(e))")))
            end
        end)

        # Start the server
        @info "Starting server on $host:$port"
        server = HTTP.serve(router, host, port)
        SERVER_STATE["server"] = server
        SERVER_STATE["is_running"] = true

        @info "Server started successfully"
        return true
    catch e
        @error "Failed to start server" exception=(e, catch_backtrace())
        SERVER_STATE["is_running"] = false
        SERVER_STATE["server"] = nothing
        return false
    end
end

"""
    stop_server()

Stop the HTTP server.
"""
function stop_server()
    if !is_running()
        @warn "Server is not running"
        return true
    end

    try
        # Get the server
        server = SERVER_STATE["server"]

        # Close the server
        close(server)

        # Update server state
        SERVER_STATE["is_running"] = false
        SERVER_STATE["server"] = nothing

        @info "Server stopped successfully"
        return true
    catch e
        @error "Failed to stop server" exception=(e, catch_backtrace())
        return false
    end
end

"""
    handle_command(request::Dict)

Process a command request and return the appropriate response.
"""
function handle_command(request::Dict)
    command = request["command"]
    params = get(request, "params", Dict())

    @info "Received API request: $(JSON.json(request))"
    @info "Received command: $command with params: $params"

    # Special case for swarm.list_algorithms command
    if command == "swarm.list_algorithms"
        @info "Handling swarm.list_algorithms command directly"
        try
            # Check if Swarms module is available
            if isdefined(Main.JuliaOS, :Swarms) && isdefined(Main.JuliaOS.Swarms, :list_algorithms)
                @info "Using JuliaOS.Swarms.list_algorithms"
                return Main.JuliaOS.Swarms.list_algorithms()
            else
                @warn "JuliaOS.Swarms module not available, trying to load it"
                # Try to load the Swarms module
                try
                    # Try to include the Swarms module
                    include(joinpath(dirname(dirname(dirname(@__FILE__))), "swarm/Swarms.jl"))
                    # Try to use the Swarms module
                    # Note: We can't use 'using' here, so we'll use the fully qualified name
                    @info "Successfully loaded Swarms module"
                    # Try to call list_algorithms
                    if isdefined(Main.JuliaOS.Swarms, :list_algorithms)
                        @info "Using JuliaOS.Swarms.list_algorithms after loading"
                        return Main.JuliaOS.Swarms.list_algorithms()
                    end
                catch e
                    @error "Failed to load Swarms module" exception=(e, catch_backtrace())
                end

                # If we still can't use the Swarms module, use a simplified implementation
                @warn "Using simplified implementation of list_algorithms"
                algorithms = [
                    Dict(
                        "id" => "SwarmPSO",
                        "name" => "Particle Swarm Optimization",
                        "description" => "A population-based optimization technique inspired by social behavior of bird flocking or fish schooling."
                    ),
                    Dict(
                        "id" => "SwarmGA",
                        "name" => "Genetic Algorithm",
                        "description" => "A search heuristic that mimics the process of natural selection."
                    ),
                    Dict(
                        "id" => "SwarmACO",
                        "name" => "Ant Colony Optimization",
                        "description" => "A probabilistic technique for solving computational problems which can be reduced to finding good paths through graphs."
                    ),
                    Dict(
                        "id" => "SwarmGWO",
                        "name" => "Grey Wolf Optimizer",
                        "description" => "A meta-heuristic algorithm inspired by the leadership hierarchy and hunting mechanism of grey wolves."
                    ),
                    Dict(
                        "id" => "SwarmWOA",
                        "name" => "Whale Optimization Algorithm",
                        "description" => "A nature-inspired meta-heuristic optimization algorithm that mimics the hunting behavior of humpback whales."
                    ),
                    Dict(
                        "id" => "SwarmDE",
                        "name" => "Differential Evolution",
                        "description" => "A stochastic population-based optimization algorithm for solving complex optimization problems."
                    ),
                    Dict(
                        "id" => "SwarmDEPSO",
                        "name" => "Hybrid Differential Evolution and Particle Swarm Optimization",
                        "description" => "A hybrid algorithm that combines the strengths of Differential Evolution and Particle Swarm Optimization."
                    )
                ]

                return Dict("success" => true, "data" => Dict("algorithms" => algorithms))
            end
        catch e
            @error "Error listing algorithms" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error listing algorithms: $(string(e))")
        end
    end

    # Try to use the CommandHandler module if available
    try
        if isdefined(Main.JuliaOS, :CommandHandler) && isdefined(Main.JuliaOS.CommandHandler, :handle_command)
            return Main.JuliaOS.CommandHandler.handle_command(command, params)
        else
            @warn "CommandHandler module not available or handle_command function not defined. Returning simple response."
            # Simple implementation that just returns a success response
            return Dict(
                "success" => true,
                "data" => Dict(
                    "message" => "Command $command received",
                    "mock" => true,
                    "timestamp" => string(now())
                )
            )
        end
    catch e
        @error "Error using CommandHandler" exception=(e, catch_backtrace())
        return Dict(
            "success" => false,
            "error" => "Error processing command: $(typeof(e))",
            "message" => string(e)
        )
    end
end

end # module API
