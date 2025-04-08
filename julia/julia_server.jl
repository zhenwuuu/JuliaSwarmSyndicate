#!/usr/bin/env julia

"""
JuliaOS Unified Server

This script runs a consolidated JuliaOS server that exposes HTTP API endpoints.
It provides a comprehensive interface for the JuliaOS functionality.
"""

# Add the current directory to the load path
push!(LOAD_PATH, joinpath(@__DIR__, "src"))

using HTTP
using JSON
using Dates
using Random
using Logging
using Statistics
using LinearAlgebra
using DataFrames

# Include the JuliaOS module which includes all other modules
include("src/JuliaOS.jl")

# Import all modules from JuliaOS
using .JuliaOS
using .JuliaOS.Storage
using .JuliaOS.Blockchain
using .JuliaOS.MarketData
using .JuliaOS.Bridge
using .JuliaOS.DEX
using .JuliaOS.Algorithms
using .JuliaOS.SwarmManager
using .JuliaOS.AgentSystem
using .JuliaOS.SmartContracts
using .JuliaOS.RiskManagement
using .JuliaOS.SecurityManager
using .JuliaOS.OpenAISwarmAdapter

# Script version
const VERSION = "1.0.0"

# Server configuration
const HOST = get(ENV, "JULIAOS_HOST", "127.0.0.1")
const PORT = parse(Int, get(ENV, "JULIAOS_PORT", "8052"))

# Define HTTP router
const router = HTTP.Router()

# =============================================================================
# Health Check Endpoint
# =============================================================================
HTTP.register!(router, "GET", "/health", request -> begin
    # Check system health using JuliaOS functionality
    health_status = JuliaOS.check_system_health()
    
    # Simplify response for API compatibility
    health_response = Dict(
        "status" => health_status["status"],
        "timestamp" => string(now()),
        "version" => VERSION,
        "server" => "JuliaOS Unified Server",
        "dependencies" => Dict(
            "database" => health_status["storage"]["local_db"] == "connected" ? "ok" : "error",
            "blockchain" => health_status["bridge"]["status"] == "healthy" ? "ok" : "error"
        )
    )

    return HTTP.Response(
        health_status["status"] == "healthy" ? 200 : 503,
        ["Content-Type" => "application/json"],
        body = JSON.json(health_response)
    )
end)

# =============================================================================
# API Command Endpoint (used by JuliaBridge)
# =============================================================================
HTTP.register!(router, "POST", "/api", request -> begin
    local body
    local command = "<unknown>"
    local id = "unknown"
    try
        # Parse request
        body_str = String(request.body)
        println("INCOMING REQUEST: $body_str") # Debug log
        body = JSON.parse(body_str)

        # Extract command, parameters and ID
        command = get(body, "command", nothing)
        params = get(body, "params", [])
        id = get(body, "id", string(rand(UInt32)))

        if command === nothing
            throw(ArgumentError("Missing 'command' field in request"))
        end

        @info "Processing command: '$command' (ID: $id)" params=params # Log command

        # Process command using real modules
        response = process_command(command, params, id)
        
        # Debug: Print response for list_agents
        if command == "list_agents"
            println("LIST_AGENTS RESPONSE: $(JSON.json(response))")
        end

        # Return response
        return HTTP.Response(
            200,
            ["Content-Type" => "application/json"],
            body = JSON.json(response)
        )
    catch e
        @error "Error processing command '$command' (ID: $id): $e" stacktrace(catch_backtrace()) # Log error with stacktrace
        # Return error response
        error_response = Dict(
            "result" => nothing,
            "error" => sprint(showerror, e), # Get error message string
            "id" => id # Use extracted id if available, otherwise default
        )

        return HTTP.Response(
            isa(e, ArgumentError) ? 400 : 500, # Bad request for arg errors
            ["Content-Type" => "application/json"],
            body = JSON.json(error_response)
        )
    end
end)

# =============================================================================
# Command Processor with Real Module Implementation
# =============================================================================
function process_command(command, params, id)
    result = nothing
    error_message = nothing

    try
        db = Storage.DB # Use the initialized DB connection from Storage module

        # === Blockchain Commands ===
        if command == "blockchain_connect"
            network = length(params) >= 1 ? params[1] : "ethereum"
            endpoint = length(params) >= 2 ? params[2] : ""
            result = Blockchain.connect(network=network, endpoint=endpoint)

        elseif command == "blockchain_getBalance"
            if length(params) < 1 error("Missing required parameter: address") end
            address = params[1]
            network = length(params) >= 2 ? params[2] : "ethereum"
            conn = Blockchain.connect(network=network)
            if !conn["connected"] error("Failed to connect to network '$network' for getBalance") end
            balance = Blockchain.getBalance(address, conn)
            result = Dict("address" => address, "balance" => balance, "network" => network)

        # === Agent Commands (Real Implementation) ===
        elseif command == "create_agent"
            if length(params) < 3 error("Usage: create_agent <name> <type> <config_dict_or_json>") end
            name, type, config_input = params[1], params[2], params[3]
            
            # Process config input
            local agent_config
            if isa(config_input, String)
                agent_config = JSON.parse(config_input)
            else
                agent_config = config_input
            end
            
            # Set agent_id for new agent
            agent_id = "agent_" * string(rand(UInt32))
            
            # Create a proper AgentConfig
            agent_system_config = AgentSystem.AgentConfig(
                agent_id,
                name,
                "1.0.0", # Default version
                type,
                get(agent_config, "capabilities", String[]),
                get(agent_config, "max_memory", 1024),
                get(agent_config, "max_skills", 10),
                get(agent_config, "update_interval", 60),
                get(agent_config, "network_configs", Dict{String, Dict{String, Any}}())
            )
            
            # Create agent in the runtime
            agent_state = AgentSystem.create_agent(agent_system_config)
            
            # Also store in database
            db_result = Storage.create_agent(db, agent_id, name, type, agent_config)
            
            # Combine results
            result = Dict(
                "id" => agent_id,
                "name" => name,
                "type" => type,
                "status" => agent_state.status
            )

        elseif command == "list_agents"
            # Get real agents from AgentSystem and DB
            # First try to get from AgentSystem (runtime)
            active_agents = []
            for (id, agent) in AgentSystem.ACTIVE_AGENTS
                push!(active_agents, Dict(
                    "id" => id,
                    "name" => agent.config.name,
                    "type" => agent.config.agent_type,
                    "status" => agent.status
                ))
            end
            
            @info "[list_agents] Processed runtime agents: $(active_agents)"

            # If no active agents, try to get from DB
            if isempty(active_agents)
                @info "[list_agents] No active runtime agents. Querying database..."
                db_agents = Storage.list_agents(db)
                @info "[list_agents] Database returned: $(typeof(db_agents)) -> $(db_agents)"
                # Corrected Check: Check if the result is a non-empty vector
                if db_agents isa Vector && !isempty(db_agents)
                    active_agents = db_agents # Assign the vector directly
                    @info "[list_agents] Using agents from database."
                else
                    @info "[list_agents] Database result is empty or not a vector. Resulting list is empty."
                end
            end

            result = Dict("agents" => active_agents)
            @info "[list_agents] Final result: $(result)"

        elseif command == "get_agent_state"
            if length(params) < 1 error("Missing required parameter: agent_id") end
            agent_id = params[1]
            
            # Try to get from runtime first
            if haskey(AgentSystem.ACTIVE_AGENTS, agent_id)
                agent = AgentSystem.ACTIVE_AGENTS[agent_id]
                result = Dict(
                    "id" => agent_id,
                    "name" => agent.config.name,
                    "type" => agent.config.agent_type,
                    "status" => agent.status,
                    "last_update" => string(agent.last_update)
                )
            else
                # Fall back to database if not in memory
                db_agent = Storage.get_agent(db, agent_id)
                if db_agent === nothing
                    error("Agent not found: $agent_id")
                end
                result = db_agent
            end

        elseif command == "update_agent"
            if length(params) < 2 error("Usage: update_agent <agent_id> <updates_dict>") end
            agent_id, updates = params[1], params[2]
            
            # Update in runtime if active
            if haskey(AgentSystem.ACTIVE_AGENTS, agent_id)
                agent = AgentSystem.ACTIVE_AGENTS[agent_id]
                
                # Apply updates (basic fields only)
                if haskey(updates, "status")
                    AgentSystem.update_agent_status(agent_id, updates["status"])
                end
                
                # Apply other updates as needed
                # TODO: Add more update logic for other fields
                
                # Get updated state
                agent = AgentSystem.ACTIVE_AGENTS[agent_id]
                result = Dict(
                    "id" => agent_id,
                    "name" => agent.config.name,
                    "status" => agent.status
                )
            else
                # Update in DB if not in memory
                result = Storage.update_agent(db, agent_id, updates)
            end

        elseif command == "delete_agent"
            if length(params) < 1 error("Missing required parameter: agent_id") end
            agent_id = params[1]
            
            # Delete from runtime if active
            if haskey(AgentSystem.ACTIVE_AGENTS, agent_id)
                AgentSystem.delete_agent(agent_id)
            end
            
            # Also delete from DB
            db_result = Storage.delete_agent(db, agent_id)
            
            result = Dict("id" => agent_id, "deleted" => true)

        # === Swarm Commands (Real Implementation) ===
        elseif command == "create_swarm"
            if length(params) < 1 error("Missing required parameter: config_dict") end
            config_input = params[1]
            
            # Generate ID and extract basic info
            swarm_id = "swarm_" * string(rand(UInt32))
            name = get(config_input, "name", "UnnamedSwarm_$(swarm_id)")
            type = get(config_input, "type", "Trading")
            algorithm_info = get(config_input, "algorithm", Dict("type"=>"pso"))
            
            # Get chain and DEX info
            chain = get(config_input, "chain", "ethereum")
            dex = get(config_input, "dex", "uniswap-v3")
            
            # Create SwarmConfig for runtime
            swarm_config = SwarmManager.SwarmConfig(
                name=name,
                algorithm=algorithm_info,
                num_particles=get(config_input, "num_particles", 20),
                num_iterations=get(config_input, "num_iterations", 50),
                trading_pairs=get(config_input, "trading_pairs", ["ETH/USDT"])
            )
            
            # Create swarm in runtime
            swarm_state = AgentSystem.create_swarm(swarm_config, chain, dex)
            
            # Also save to DB
            db_result = Storage.create_swarm(db, swarm_id, name, type, JSON.json(algorithm_info), JSON.json(config_input))
            
            result = Dict(
                "id" => swarm_id,
                "name" => name,
                "type" => algorithm_info["type"],
                "status" => swarm_state.status
            )

        elseif command == "list_swarms"
            # Get real swarms from AgentSystem and DB
            active_swarms = []
            
            # First from runtime
            for (name, swarm) in AgentSystem.ACTIVE_SWARMS
                push!(active_swarms, Dict(
                    "id" => name, # Using name as ID in runtime
                    "name" => name,
                    "type" => swarm.swarm_object.config.algorithm["type"],
                    "status" => swarm.status
                ))
            end
            
            @info "[list_swarms] Processed runtime swarms: $(active_swarms)"

            # If no active swarms, try to get from DB
            if isempty(active_swarms)
                @info "[list_swarms] No active runtime swarms. Querying database..."
                db_swarms = Storage.list_swarms(db)
                @info "[list_swarms] Database returned: $(typeof(db_swarms)) -> $(db_swarms)"
                # Corrected Check: Check if the result is a non-empty vector
                if db_swarms isa Vector && !isempty(db_swarms)
                    active_swarms = db_swarms # Assign the vector directly
                     @info "[list_swarms] Using swarms from database."
                else
                     @info "[list_swarms] Database result is empty or not a vector. Resulting list is empty."
                end
            end

            result = Dict("swarms" => active_swarms)
             @info "[list_swarms] Final result: $(result)"

        elseif command == "start_swarm"
            if length(params) < 1 error("Missing required parameter: swarm_name (runtime ID)") end
            swarm_name = params[1]
            
            # Get runtime state
            swarm_state = AgentSystem.get_swarm_state(swarm_name)
            if swarm_state === nothing
                error("Swarm not found: $swarm_name")
            end
            
            # Start the swarm using SwarmManager
            if swarm_state.status != "active"
                SwarmManager.start_swarm!(swarm_state.swarm_object)
                AgentSystem.update_swarm_status(swarm_name, "active")
            end
            
            # Get updated state
            swarm_state = AgentSystem.get_swarm_state(swarm_name)
            
            result = Dict(
                "id" => swarm_name,
                "status" => swarm_state.status
            )

        elseif command == "stop_swarm"
            if length(params) < 1 error("Missing required parameter: swarm_name") end
            swarm_name = params[1]
            
            # Get runtime state
            swarm_state = AgentSystem.get_swarm_state(swarm_name)
            if swarm_state === nothing
                error("Swarm not found: $swarm_name")
            end
            
            # Stop the swarm
            if swarm_state.status == "active"
                SwarmManager.stop_swarm!(swarm_state.swarm_object)
                AgentSystem.update_swarm_status(swarm_name, "inactive")
            end
            
            # Get updated state
            swarm_state = AgentSystem.get_swarm_state(swarm_name)
            
            result = Dict(
                "id" => swarm_name,
                "status" => swarm_state.status
            )

        # === Storage Commands ===
        elseif command == "storage_save"
            if length(params) < 2 error("Usage: storage_save <key> <value>") end
            key, value = params[1], params[2]
            result = Storage.save_setting(db, key, value)

        elseif command == "storage_load"
            if length(params) < 1 error("Missing required parameter: key") end
            key = params[1]
            value = Storage.get_setting(db, key)
            result = Dict("key" => key, "value" => value)

        # === OpenAI Swarm Commands ===
        elseif command == "create_openai_swarm"
            if length(params) < 1 error("Missing required parameter: config") end
            config = params[1]
            
            # Create OpenAI swarm
            result = OpenAISwarmAdapter.create_openai_swarm(config)

        elseif command == "run_openai_task"
            # Expected params: swarm_id, agent_name, task_prompt, [thread_id (optional)]
            if length(params) < 3 error("Usage: run_openai_task <swarm_id> <agent_name> <task_prompt> [thread_id]") end
            swarm_id = params[1]
            agent_name = params[2]
            task_prompt = params[3]
            thread_id = length(params) >= 4 ? params[4] : nothing
            
            # Call the function, passing optional thread_id as a keyword argument
            result = OpenAISwarmAdapter.run_openai_task(swarm_id, agent_name, task_prompt; thread_id=thread_id)

        elseif command == "get_openai_response"
            # Expected params: swarm_id, thread_id, run_id
            if length(params) < 3 error("Usage: get_openai_response <swarm_id> <thread_id> <run_id>") end
            swarm_id = params[1]
            thread_id = params[2]
            run_id = params[3]
            
            result = OpenAISwarmAdapter.get_openai_response(swarm_id, thread_id, run_id)
            
        else
            # Unknown command
            error("Unknown command: $command")
        end
    catch e
        @error "Error processing command '$command' (ID: $id): $e" # Log error
        error_message = sprint(showerror, e) # Capture error message
    end

    # Return success or error response
    if error_message === nothing
        return Dict(
            "result" => result,
            "error" => nothing,
            "id" => id
        )
    else
        return Dict(
            "result" => nothing,
            "error" => error_message,
            "id" => id
        )
    end
end

# =============================================================================
# WebSocket Endpoint (for continuous connections)
# =============================================================================
const ws_connections = Dict{String, WebSockets.WebSocket}()

HTTP.register!(router, "GET", "/ws", request -> begin
    return WebSockets.websocket_handler(request) do ws
        client_id = string(UInt(objectid(ws)))
        ws_connections[client_id] = ws
        
        @info "WebSocket connected, ID: $client_id"
        
        try
            while !eof(ws)
                msg = String(WebSockets.receive(ws))
                @info "WebSocket message received: $msg"
                
                # Parse message
                message = JSON.parse(msg)
                
                # Process command
                if haskey(message, "command")
                    command = message["command"]
                    params = get(message, "params", [])
                    id = get(message, "id", string(rand(UInt32)))
                    
                    # Process command
                    response = process_command(command, params, id)
                    
                    # Send response
                    WebSockets.send(ws, JSON.json(response))
                end
            end
        catch e
            @error "WebSocket error: $e" stacktrace(catch_backtrace())
        finally
            delete!(ws_connections, client_id)
            @info "WebSocket disconnected, ID: $client_id"
        end
    end
end)

# =============================================================================
# Main Function
# =============================================================================
function main()
    try
        # Initialize JuliaOS
        JuliaOS.initialize_system()
        
        println("Starting JuliaOS Unified Server on http://$HOST:$PORT...")
        println("Using database at: $(Storage.DB_PATH)")
        println("Registered endpoints: GET /health, POST /api, GET /ws")
        @info "Server starting..." # Use Logging

        # Start HTTP server
        HTTP.serve(router, HOST, PORT)
    catch e
        @error "Server startup error: $e" stacktrace(catch_backtrace())
        println("Server startup error: $e")
        exit(1)
    end
end

# Run main function
main() 