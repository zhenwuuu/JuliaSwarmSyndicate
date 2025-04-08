using HTTP
using JSON
using Sockets
using Dates
using Logging
using UUIDs

# Include application modules
include("src/Blockchain.jl")
include("src/Bridge.jl")
include("src/AgentSystem.jl")
include("src/SwarmManager.jl")
include("src/DEX.jl")
include("src/Storage.jl")
include("src/OpenAISwarmAdapter.jl")
# include("src/SmartContracts.jl") # If needed later
# include("src/MLIntegration.jl")   # If needed later

# Use the modules
using .Blockchain
using .Bridge
using .AgentSystem
using .SwarmManager
using .DEX
using .Storage
using .OpenAISwarmAdapter
# using .SmartContracts
# using .MLIntegration

# --- Global Server State and Configuration ---
const HOST = "0.0.0.0"
const PORT = 8052
const MAX_CONNECTIONS = 100

# Basic Logging Configuration
Logging.global_logger(Logging.ConsoleLogger(stderr, Logging.Info))
@info "JuliaOS Server starting..." PID=getpid()

# --- HTTP Request Handling --- #

# Function to handle CORS headers
function handle_cors(response)
    HTTP.setheader(response, "Access-Control-Allow-Origin" => "*") # Allow all origins (adjust for production)
    HTTP.setheader(response, "Access-Control-Allow-Methods" => "GET, POST, OPTIONS")
    HTTP.setheader(response, "Access-Control-Allow-Headers" => "Content-Type, Authorization")
    return response
end

# Handler for API requests
function handle_api_request(req::HTTP.Request)
    # Handle OPTIONS requests for CORS preflight
    if req.method == "OPTIONS"
        response = HTTP.Response(204)
        return handle_cors(response)
    end

    # Basic health check endpoint
    if req.target == "/api/health" && req.method == "GET"
        response = HTTP.Response(200, JSON.json(Dict("status" => "healthy", "timestamp" => now())))
        return handle_cors(response)
    end

    # Command execution endpoint
    if req.target == "/api/command" && req.method == "POST"
        try
            body_str = String(req.body)
            if isempty(body_str)
                 response = HTTP.Response(400, JSON.json(Dict("error" => "Empty request body")))
                 return handle_cors(response)
            end
            json_body = JSON.parse(body_str)

            command = get(json_body, "command", "")
            params = get(json_body, "params", [])

            if isempty(command)
                response = HTTP.Response(400, JSON.json(Dict("error" => "Missing command field")))
                return handle_cors(response)
            end

            # --- Route command to the appropriate module/function --- #
            @info "Processing command: $command" params=params
            result = execute_command(command, params)
            @info "Command result:" command=command result_status=result.success error=result.error data_keys=keys(result.data)

            # Prepare response based on CommandResult
            response_data = Dict("success" => result.success)
            if result.success
                response_data["data"] = result.data
            else
                response_data["error"] = result.error
                # Optionally include data even on error if useful
                if !isempty(result.data)
                     response_data["data"] = result.data
                end
            end

            status_code = result.success ? 200 : 500 # Use 500 for server-side errors
            if !result.success && contains(lowercase(result.error), "invalid parameter")
                 status_code = 400 # Use 400 for client-side errors
            end

            response = HTTP.Response(status_code, JSON.json(response_data))
            return handle_cors(response)

        catch e
            @error "Error processing command: $e" stacktrace(catch_backtrace())
            response = HTTP.Response(500, JSON.json(Dict("error" => "Internal server error: $(sprint(showerror, e))")))
            return handle_cors(response)
        end
    end

    # Default 404 for other paths
    response = HTTP.Response(404, "Not Found")
    return handle_cors(response)
end

# --- Command Dispatch Logic --- #

function execute_command(command::String, params::Vector)::CommandResult
    try
        # --- Blockchain Commands --- #
        if command == "Blockchain.connect"
            network = length(params) >= 1 ? params[1] : "ethereum"
            endpoint = length(params) >= 2 ? params[2] : ""
            conn_info = Blockchain.connect(network=network, endpoint=endpoint)
            return CommandResult(conn_info)

        elseif command == "Blockchain.getBalance"
            if length(params) < 2
                 return CommandResult("Missing parameters: address, connection_dict")
            end
            address = params[1]
            connection = params[2] # Assuming JS passes the connection dict back
            balance = Blockchain.getBalance(address, connection)
            return CommandResult(Dict("balance" => balance))

        elseif command == "Bridge.get_wallet_balance"
            if length(params) < 3
                return CommandResult("error", Dict("message" => "Missing required parameters for Bridge.get_wallet_balance: address, token_address (or null), chain"), "bridge_error")
            end
            result = Bridge.get_wallet_balance(params[1], params[2], params[3])
            return CommandResult(result["success"] ? "success" : "error", result["success"] ? result["data"] : Dict("message" => result["error"]), result["success"] ? "bridge_success" : "bridge_error")

        elseif command == "Bridge.get_token_address"
            if length(params) < 2
                return CommandResult("error", Dict("message" => "Missing required parameters for Bridge.get_token_address: symbol, chain"), "bridge_error")
            end
            result = Bridge.get_token_address(params[1], params[2])
            return CommandResult(result["success"] ? "success" : "error", result["success"] ? result["data"] : Dict("message" => result["error"]), result["success"] ? "bridge_success" : "bridge_error")

        elseif command == "Bridge.execute_trade"
            if length(params) < 3
                return CommandResult("error", Dict("message" => "Missing required parameters for Bridge.execute_trade: dex, chain, trade_params"), "bridge_error")
            end
            bridge_result = Bridge.execute_trade(params[1], params[2], params[3])
            return bridge_result

        elseif command == "Bridge.submit_signed_transaction"
            if length(params) < 3
                return CommandResult("error", Dict("message" => "Missing required parameters for Bridge.submit_signed_transaction: chain, request_id, signed_tx_hex"), "bridge_error")
            end
            bridge_result = Bridge.submit_signed_transaction(params[1], params[2], params[3])
            return bridge_result

        elseif command == "Bridge.get_transaction_status"
            if length(params) < 2
                return CommandResult("error", Dict("message" => "Missing required parameters for Bridge.get_transaction_status: chain, tx_hash"), "bridge_error")
            end
            bridge_result = Bridge.get_transaction_status(params[1], params[2])
            return bridge_result

        # --- DEX Commands --- #
        elseif command == "DEX.get_swap_quote"
             if length(params) < 5
                 return CommandResult("Missing parameters: token_in, token_out, amount_in_wei, dex_name, chain")
             end
             # Ensure amount_in_wei is BigInt
             amount_in_wei = try BigInt(string(params[3])) catch; return CommandResult("Invalid amount_in_wei parameter") end
             quote_data = DEX.get_swap_quote(params[1], params[2], amount_in_wei, params[4], params[5])
             return CommandResult(quote_data)

        # --- Agent Commands --- #
        elseif command == "AgentSystem.create_agent"
            if length(params) < 3
                 return CommandResult("Missing parameters: name, type, config_json_string")
            end
            name, type, config_str = params[1], params[2], params[3]
            config = try JSON.parse(config_str) catch; Dict() end
            agent_info = AgentSystem.create_agent(name, type, config)
            return CommandResult(agent_info)

        elseif command == "AgentSystem.list_agents"
            @info "[list_agents] Handler started."
            # Get real agents from AgentSystem and DB
            # First try to get from AgentSystem (runtime)
            active_agents = []
            @info "[list_agents] Runtime agents: $(AgentSystem.ACTIVE_AGENTS)"
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
            return CommandResult(result)

        elseif command == "AgentSystem.get_agent_state"
            if isempty(params)
                 return CommandResult("Missing parameter: agent_id")
            end
            state = AgentSystem.get_agent_state(params[1])
            return isnothing(state) ? CommandResult("Agent not found") : CommandResult(state)

        elseif command == "AgentSystem.update_agent"
            if length(params) < 2
                 return CommandResult("Missing parameters: agent_id, updates_json_string")
            end
            agent_id, updates_str = params[1], params[2]
            updates = try JSON.parse(updates_str) catch; return CommandResult("Invalid updates JSON") end
            updated_agent = AgentSystem.update_agent(agent_id, updates)
            return isnothing(updated_agent) ? CommandResult("Agent not found or update failed") : CommandResult(updated_agent)

         elseif command == "AgentSystem.delete_agent"
             if isempty(params)
                 return CommandResult("Missing parameter: agent_id")
             end
             success = AgentSystem.delete_agent(params[1])
             return success ? CommandResult(Dict("deleted" => true)) : CommandResult("Agent not found or delete failed")

        # --- Swarm Commands --- #
        elseif command == "SwarmManager.create_swarm"
            if length(params) < 3
                 return CommandResult("Missing parameters: config_dict, chain, dex")
            end
            config = params[1] # Assuming JS passes the dict directly
            chain = params[2]
            dex = params[3]
            swarm_info = SwarmManager.create_swarm(config, chain, dex)
            return CommandResult(swarm_info)

        elseif command == "SwarmManager.list_swarms"
            @info "[list_swarms] Handler started."
            # Get real swarms from AgentSystem and DB
            active_swarms = []
            @info "[list_swarms] Runtime swarms: $(AgentSystem.ACTIVE_SWARMS)"
            
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
            return CommandResult(result)

        elseif command == "SwarmManager.get_swarm_state"
            if isempty(params)
                 return CommandResult("Missing parameter: swarm_id")
            end
            state = SwarmManager.get_swarm_state(params[1])
            return isnothing(state) ? CommandResult("Swarm not found") : CommandResult(state)

        elseif command == "SwarmManager.update_swarm"
            if length(params) < 2
                 return CommandResult("Missing parameters: swarm_id, updates_json_string")
            end
            swarm_id, updates_str = params[1], params[2]
            updates = try JSON.parse(updates_str) catch; return CommandResult("Invalid updates JSON") end
            updated_swarm = SwarmManager.update_swarm_settings(swarm_id, updates)
            return isnothing(updated_swarm) ? CommandResult("Swarm not found or update failed") : CommandResult(updated_swarm)

         elseif command == "SwarmManager.delete_swarm"
             if isempty(params)
                 return CommandResult("Missing parameter: swarm_id")
             end
             success = SwarmManager.delete_swarm(params[1])
             return success ? CommandResult(Dict("deleted" => true)) : CommandResult("Swarm not found or delete failed")

        # --- Storage Commands --- #
        elseif command == "Storage.save_agent"
            if length(params) < 1 || !isa(params[1], Dict)
                 return CommandResult("Missing or invalid parameter: agent_dict")
            end
            agent_id = Storage.save_agent(params[1])
            return CommandResult(Dict("agent_id" => agent_id))
        elseif command == "Storage.load_agent"
            if isempty(params)
                 return CommandResult("Missing parameter: agent_id")
            end
            agent_data = Storage.load_agent(params[1])
            return isnothing(agent_data) ? CommandResult("Agent not found") : CommandResult(agent_data)
        # Add other Storage commands (save/load swarm, settings etc.) here
        elseif command == "Storage.save_settings"
            if length(params) < 1 || !isa(params[1], Dict)
                 return CommandResult("Missing or invalid parameter: settings_dict")
            end
            Storage.save_settings(params[1])
            return CommandResult(Dict("saved" => true))
        elseif command == "Storage.load_settings"
            settings = Storage.load_settings()
            return CommandResult(settings)

        # --- OpenAI Swarm Adapter Commands --- #
        elseif command == "OpenAISwarmAdapter.create_openai_swarm"
            if isempty(params) || !isa(params[1], Dict)
                return CommandResult("Missing or invalid parameter: swarm_config_dict")
            end
            swarm_config = params[1]
            swarm_info = OpenAISwarmAdapter.create_openai_swarm(swarm_config)
            return CommandResult(swarm_info)

        # --- Default: Unknown Command --- #
        else
            @warn "Received unknown command: $command"
            return CommandResult("Unknown command: $command")
        end

    catch e
        # Catch errors during command execution itself
        @error "Error executing command '$command': $e" stacktrace(catch_backtrace())
        return CommandResult("Error executing command '$command': $(sprint(showerror, e))")
    end
end

# --- Server Startup --- #
function run_server()
    try
        HTTP.serve(handle_api_request, HOST, PORT; server=nothing, verbose=false)
    catch e
        @error "Server encountered a fatal error: $e" stacktrace(catch_backtrace())
        # Potentially try to restart or cleanup
    finally
        @info "JuliaOS Server shutting down."
    end
end

# --- Main Execution --- #
if abspath(PROGRAM_FILE) == @__FILE__
    # Initialize Bridge (register handlers from other modules if needed)
    # Bridge.register_command_handler("example_command", example_handler_function)

    # Start the server
    run_server()
end 