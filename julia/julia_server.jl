#!/usr/bin/env julia

\"\"\"
JuliaOS Unified Server

This script runs a consolidated JuliaOS server that exposes HTTP API endpoints.
It provides a simplified interface for the JuliaOS functionality.
\"\"\"

# Add the current directory to the load path
push!(LOAD_PATH, joinpath(@__DIR__, "src"))

using HTTP
using JSON
using Dates
using Random
using Logging # Added for logging

# Import necessary modules
using .Storage
using .Blockchain
using .AgentSystem # Added AgentSystem
using .SwarmManager # Added SwarmManager

# Script version
const VERSION = "1.0.0"

# Server configuration
const HOST = get(ENV, "JULIAOS_HOST", "127.0.0.1")  # Use 127.0.0.1 which we know works
const PORT = parse(Int, get(ENV, "JULIAOS_PORT", "8082"))

# Define HTTP router
const router = HTTP.Router()

# Helper function to convert Dict to SwarmManager.SwarmConfig
# TODO: Make this more robust, handle missing fields, type conversions etc.
function dict_to_swarm_config(config_dict::Dict, swarm_id::String)::SwarmManager.SwarmConfig
    # Assuming keys match field names closely. Need proper error handling/defaults.
    try
        return SwarmManager.SwarmConfig(
            # id = swarm_id, # SwarmManager.SwarmConfig might not have an id field itself
            name = get(config_dict, "name", "UnnamedSwarm_$(swarm_id)"),
            algorithm = get(config_dict, "algorithm", Dict("type" => "pso", "params" => Dict())), # Default algorithm
            num_particles = get(config_dict, "num_particles", 20),
            num_iterations = get(config_dict, "num_iterations", 50),
            trading_pairs = get(config_dict, "trading_pairs", ["ETH/USDT"]),
            # market_data_provider = get(config_dict, "market_data_provider", Dict("type" => "mock")), # Example
            # agent_configs = [], # AgentSystem doesn't use this field anymore here
            # storage_config = get(config_dict, "storage_config", Dict()) # Example
            # Add other fields based on SwarmManager.SwarmConfig definition
        )
    catch e
        @error "Failed to convert Dict to SwarmManager.SwarmConfig: $e" config=config_dict
        rethrow(ArgumentError("Invalid swarm configuration dictionary structure: $e"))
    end
end

# Helper function to convert runtime state to a JSON-serializable Dict
# Add specific fields you want to expose from SwarmManager.Swarm
function swarm_state_to_dict(state::AgentSystem.SwarmState)
    # Basic AgentSystem state info
    base_dict = Dict(
        "swarm_id" => state.swarm_object.config.name, # Assuming name is used as ID
        "status" => state.status,
        "last_update" => string(state.last_update),
        "agent_ids" => state.agent_ids,
        # Fields from SwarmManager.Swarm
        "algorithm_type" => state.swarm_object.config.algorithm["type"],
        "num_particles" => state.swarm_object.config.num_particles,
        "num_iterations" => state.swarm_object.config.num_iterations,
        "trading_pairs" => state.swarm_object.config.trading_pairs,
        "performance_metrics" => state.swarm_object.performance_metrics, # Expose metrics
        "best_fitness" => isempty(state.swarm_object.fitness_history) ? nothing : maximum(values(state.swarm_object.fitness_history)), # Example metric
        "last_fitness_update" => state.swarm_object.last_fitness_update, # Example timestamp
        # Add other relevant fields from state.swarm_object or state.swarm_object.config
    )
    return base_dict
end

# =============================================================================
# Health Check Endpoint
# =============================================================================
HTTP.register!(router, "GET", "/health", request -> begin
    # Check dependencies health (optional)
    db_healthy = true # Assume DB is healthy unless check fails
    # Add more checks if needed

    health_response = Dict(
        "status" => db_healthy ? "healthy" : "degraded",
        "timestamp" => string(now()),
        "version" => VERSION,
        "server" => "JuliaOS Unified Server",
        "dependencies" => Dict(
            "database" => db_healthy ? "ok" : "error"
        )
    )

    return HTTP.Response(
        db_healthy ? 200 : 503,
        ["Content-Type" => "application/json"],
        body = JSON.json(health_response)
    )
end)

# =============================================================================
# API Command Endpoint
# =============================================================================
HTTP.register!(router, "POST", "/api", request -> begin
    local body
    local command = "<unknown>"
    local id = "unknown"
    try
        # Parse request
        body_str = String(request.body)
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
# Real Command Processor
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

        # === Agent Storage Commands ===
        elseif command == "create_agent" # Creates in DB and activates in memory
            if length(params) < 3 error("Usage: create_agent <name> <type> <config_dict_or_json>") end
            agent_id = "agent_" * string(rand(UInt32))
            name, type, config_input = params[1], params[2], params[3]

            # Handle config input (Dict or JSON string)
            local agent_config_dict
            if isa(config_input, String)
                try agent_config_dict = JSON.parse(config_input) catch; error("Invalid JSON provided for agent config") end
            elseif isa(config_input, Dict)
                 agent_config_dict = config_input
            else
                 error("Agent config must be a JSON string or a Dictionary")
            end

            # Create AgentConfig struct for AgentSystem (assuming structure matches)
            # TODO: Define mapping from input config_dict to AgentConfig fields
            # For now, create a basic AgentConfig
            agent_system_config = AgentSystem.AgentConfig(
                 agent_id,
                 name,
                 "1.0.0", # Default version
                 type,
                 get(agent_config_dict, "capabilities", String[]),
                 get(agent_config_dict, "max_memory", 1024),
                 get(agent_config_dict, "max_skills", 10),
                 get(agent_config_dict, "update_interval", 60),
                 get(agent_config_dict, "network_configs", Dict{String, Dict{String, Any}}())
             )

            # 1. Save to Storage
            db_result = Storage.create_agent(db, agent_id, name, type, agent_config_dict) # Pass dict to storage
            # 2. Activate in AgentSystem
            AgentSystem.create_agent(agent_system_config)
            result = db_result # Return the result from storage creation

        elseif command == "list_agents" # Lists from DB
             result = Storage.list_agents(db)

        elseif command == "get_agent_state" # Gets from DB
             if length(params) < 1 error("Missing required parameter: agent_id") end
             agent_id = params[1]
             result = Storage.get_agent(db, agent_id)
             if result === nothing error("Agent not found in DB: $agent_id") end

        elseif command == "update_agent" # Updates DB only for now
             if length(params) < 2 error("Usage: update_agent <agent_id> <updates_dict>") end
             agent_id, updates = params[1], params[2]
             if !isa(updates, Dict) error("Updates must be a Dictionary") end
             result = Storage.update_agent(db, agent_id, updates)
             # TODO: Update AgentSystem.ACTIVE_AGENTS[agent_id].config if needed?

         elseif command == "delete_agent" # Deletes from DB and runtime
             if length(params) < 1 error("Missing required parameter: agent_id") end
             agent_id = params[1]
             # 1. Deactivate in AgentSystem
             AgentSystem.delete_agent(agent_id)
             # 2. Delete from Storage
             result = Storage.delete_agent(db, agent_id)

        # === Agent Runtime Commands ===
        elseif command == "start_agent"
            if length(params) < 1 error("Missing required parameter: agent_id") end
            agent_id = params[1]
            success = AgentSystem.update_agent_status(agent_id, "active")
            result = Dict("success" => success, "id" => agent_id, "status" => success ? "active" : "error")

        elseif command == "stop_agent"
            if length(params) < 1 error("Missing required parameter: agent_id") end
            agent_id = params[1]
            success = AgentSystem.update_agent_status(agent_id, "inactive")
            result = Dict("success" => success, "id" => agent_id, "status" => success ? "inactive" : "error")

        elseif command == "get_agent_runtime_state"
             if length(params) < 1 error("Missing required parameter: agent_id") end
             agent_id = params[1]
             runtime_state = AgentSystem.get_agent_state(agent_id)
             if runtime_state === nothing error("Agent not active or not found in runtime: $agent_id") end
             # Convert struct to Dict for JSON serialization
             # TODO: Create a dedicated helper function agent_state_to_dict if complex
             result = Dict(fn => getfield(runtime_state, fn) for fn ∈ fieldnames(typeof(runtime_state)))
             # Convert nested structs/complex types if needed
             result[:config] = Dict(fn => getfield(runtime_state.config, fn) for fn ∈ fieldnames(typeof(runtime_state.config)))
             result[:skills] = Dict(k => Dict(fn => getfield(v,fn) for fn ∈ fieldnames(typeof(v))) for (k,v) in runtime_state.skills)
             result[:memory] = runtime_state.memory # Assume memory is Dict{String, Any}

        # === Swarm Storage/Config Commands ===
        elseif command == "create_swarm" # Creates in DB and activates runtime state
             if length(params) < 1 error("Missing required parameter: config_dict") end
             config_input = params[1]
             if !isa(config_input, Dict) error("Swarm config must be a Dictionary") end

             # Generate ID and extract basic info for Storage
             swarm_id = "swarm_" * string(rand(UInt32)) # DB ID
             name = get(config_input, "name", "UnnamedSwarm_$(swarm_id)")
             type = get(config_input, "type", "Trading")
             algorithm_info = get(config_input, "algorithm", Dict("type"=>"unknown"))
             config_json = JSON.json(config_input) # Save the full input config

             # 1. Save full config to Storage
             db_result = Storage.create_swarm(db, swarm_id, name, type, JSON.json(algorithm_info), config_json)

             # 2. Create SwarmManager.SwarmConfig for runtime initialization
             # Use the *name* from config as the runtime ID for AgentSystem/SwarmManager (as per AgentSystem.create_swarm)
             runtime_id = name
             # Note: If names aren't unique, this runtime ID strategy needs revision.
             # We use swarm_id for DB, runtime_id (name) for in-memory maps.
             swarm_manager_config = dict_to_swarm_config(config_input, runtime_id) # Pass runtime_id

             # 3. Activate runtime state in AgentSystem (which calls SwarmManager.create_swarm)
             # Pass chain/dex if provided, otherwise use defaults
             chain = get(config_input, "chain", "ethereum")
             dex = get(config_input, "dex", "uniswap-v3")
             agent_system_state = AgentSystem.create_swarm(swarm_manager_config, chain, dex)

             result = Dict(
                "db_result" => db_result, # Info from DB creation (swarm_id etc.)
                "runtime_status" => agent_system_state.status,
                "runtime_id" => runtime_id # The name used for runtime lookup
             )

        elseif command == "list_swarms" # Lists from DB
             result = Storage.list_swarms(db)

        elseif command == "get_swarm_state" # Gets from DB
             if length(params) < 1 error("Missing required parameter: swarm_id (DB ID)") end
             swarm_id = params[1]
             result = Storage.get_swarm(db, swarm_id)
             if result === nothing error("Swarm not found in DB: $swarm_id") end

        elseif command == "update_swarm" # Updates DB config only
             if length(params) < 2 error("Usage: update_swarm <swarm_id (DB ID)> <updates_dict>") end
             swarm_id, updates = params[1], params[2]
             if !isa(updates, Dict) error("Updates must be a Dictionary") end
             result = Storage.update_swarm(db, swarm_id, updates)
             # Note: This only updates the persisted config. It doesn't affect the running swarm.
             # Need a separate command like `reload_swarm_config` or handle updates during `update_swarm_runtime`.

         elseif command == "delete_swarm" # Deletes from DB and runtime
             if length(params) < 1 error("Missing required parameter: swarm_id (DB ID)") end
             swarm_id_db = params[1]

             # 1. Need to find the runtime_id (name) from the db_id to delete from AgentSystem
             db_state = Storage.get_swarm(db, swarm_id_db)
             if db_state === nothing
                 @warn "Swarm $swarm_id_db not found in DB for deletion, attempting runtime deletion anyway."
                 # Attempt deletion using swarm_id_db as potential runtime_id if name lookup fails
                 runtime_id_to_delete = swarm_id_db
             else
                 runtime_id_to_delete = db_state["name"] # Assume name is the runtime key
             end

             # 2. Deactivate in AgentSystem (using runtime_id/name)
             AgentSystem.delete_swarm(runtime_id_to_delete) # Use name
             # 3. Delete from Storage (using db_id)
             result = Storage.delete_swarm(db, swarm_id_db) # Use original ID

        # === Swarm Runtime Commands ===
        elseif command == "start_swarm"
            if length(params) < 1 error("Missing required parameter: swarm_name (runtime ID)") end
            swarm_name = params[1] # Use name as runtime ID

            # 1. Get runtime state
            runtime_state = AgentSystem.get_swarm_state(swarm_name)
            if runtime_state === nothing error("Swarm '$swarm_name' not found in runtime.") end
            if runtime_state.status == "active" error("Swarm '$swarm_name' is already active.") end
            if runtime_state.status == "error" error("Cannot start swarm '$swarm_name' in error state.") end

            # 2. Fetch initial market data (placeholder - needs real implementation)
            @info "Fetching initial market data for $swarm_name..."
            # market_data = SwarmManager.get_market_data(...) # Needs implementation

            # 3. Call SwarmManager to start the optimization/trading loop
            @info "Starting swarm '$swarm_name' via SwarmManager..."
            # Pass the Swarm object from the runtime state
            # SwarmManager.start_swarm!(runtime_state.swarm_object, market_data) # Pass data
            SwarmManager.start_swarm!(runtime_state.swarm_object) # Assuming start handles data internally for now

            # 4. Update AgentSystem status
            success = AgentSystem.update_swarm_status(swarm_name, "active")
            result = Dict("success" => success, "id" => swarm_name, "status" => success ? "active" : "error_starting")

        elseif command == "update_swarm_runtime" # New command to trigger SwarmManager update
             if length(params) < 1 error("Missing required parameter: swarm_name (runtime ID)") end
             swarm_name = params[1]

             runtime_state = AgentSystem.get_swarm_state(swarm_name)
             if runtime_state === nothing error("Swarm '$swarm_name' not found in runtime.") end
             if runtime_state.status != "active" error("Swarm '$swarm_name' must be active to update.") end

             # Fetch new market data (placeholder)
             @info "Fetching new market data for update on $swarm_name..."
             # new_market_data = SwarmManager.get_market_data(...)

             @info "Updating swarm '$swarm_name' via SwarmManager..."
             # SwarmManager.update_swarm!(runtime_state.swarm_object, new_market_data) # Pass data
             SwarmManager.update_swarm!(runtime_state.swarm_object) # Assuming update handles data internally

             result = Dict("success" => true, "id" => swarm_name, "status" => "updated")
             # Optionally return updated metrics from runtime_state.swarm_object.performance_metrics

        elseif command == "stop_swarm"
            if length(params) < 1 error("Missing required parameter: swarm_name (runtime ID)") end
            swarm_name = params[1] # Use name as runtime ID

             # 1. Get runtime state
            runtime_state = AgentSystem.get_swarm_state(swarm_name)
            if runtime_state === nothing error("Swarm '$swarm_name' not found in runtime.") end
            if runtime_state.status == "inactive" error("Swarm '$swarm_name' is already inactive.") end
            if runtime_state.status == "initialized" error("Cannot stop an initialized swarm '$swarm_name', must be active.") end

            # 2. Call SwarmManager to stop/pause processes (needs implementation in SwarmManager)
             @info "Stopping swarm '$swarm_name' via SwarmManager (placeholder)..."
             # SwarmManager.stop_swarm!(runtime_state.swarm_object) # Needs implementation

             # 3. Update AgentSystem status
            success = AgentSystem.update_swarm_status(swarm_name, "inactive")
            result = Dict("success" => success, "id" => swarm_name, "status" => success ? "inactive" : "error_stopping")

        elseif command == "get_swarm_runtime_state"
             if length(params) < 1 error("Missing required parameter: swarm_name (runtime ID)") end
             swarm_name = params[1] # Use name as runtime ID
             runtime_state = AgentSystem.get_swarm_state(swarm_name)
             if runtime_state === nothing error("Swarm '$swarm_name' not active or not found in runtime") end

             # Convert AgentSystem.SwarmState (including SwarmManager.Swarm) to Dict
             result = swarm_state_to_dict(runtime_state)

        # === Storage/Settings Commands ===
        elseif command == "storage_save" # Maps to save_setting
            if length(params) < 2 error("Usage: storage_save <key> <value>") end
            result = Storage.save_setting(db, params[1], params[2])

        elseif command == "storage_load" # Maps to get_setting
            if length(params) < 1 error("Missing required parameter: key") end
            value = Storage.get_setting(db, params[1])
            result = Dict("key" => params[1], "value" => value)

        # === Unimplemented Commands ===
        elseif command == "create_openai_swarm"
            error("Command 'create_openai_swarm' is not yet implemented with real logic.")

        # Add other command handlers here using Storage.jl or other modules
        # e.g., add_agent_to_swarm, remove_agent_from_swarm, list_api_keys, add_api_key etc.

        else
            # Unknown command
            error("Unknown command: " * command)
        end
    catch e
        @error "Error processing command '$command' (ID: $id): $e" # Log error without stacktrace here
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
# Main Function
# =============================================================================
function main()
    try
        println("Starting JuliaOS Unified Server on http://$HOST:$PORT...")
        println("Using database at: $(Storage.DB_PATH)")
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