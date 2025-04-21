module Handlers

export health_handler, api_handler
export list_documents_handler, create_document_handler, get_document_handler
export update_document_handler, delete_document_handler
export get_balance_handler, get_token_balance_handler, send_transaction_handler
export list_agents_handler, create_agent_handler, get_agent_handler
export update_agent_handler, delete_agent_handler
export list_swarms_handler, create_swarm_handler, get_swarm_handler
export run_optimization_handler, get_optimization_result_handler

using HTTP
using JSON
using Dates
using ..Types
using ..Errors
using ..Utils
using ...Bridge
using ...Storage
using ...Blockchain
using ...Agents
using ...Swarms

"""
    health_handler(req::HTTP.Request)

Handle health check requests.
"""
function health_handler(req::HTTP.Request)
    response = Dict(
        "status" => "healthy",
        "timestamp" => string(now()),
        "version" => "1.0.0",
        "uptime_seconds" => Utils.get_uptime_seconds()
    )
    
    return HTTP.Response(
        200,
        ["Content-Type" => "application/json"],
        JSON.json(response)
    )
end

"""
    api_handler(req::HTTP.Request)

Handle API command requests.
"""
function api_handler(req::HTTP.Request)
    try
        # Parse the request body as JSON
        body = req.body
        
        # Basic request validation
        if !haskey(body, "command")
            throw(ValidationError("Missing required field: command", "command"))
        end
        
        # Extract command and parameters
        command = body["command"]
        params = get(body, "params", Dict())
        
        # Generate request ID if not provided
        request_id = get(body, "id", Utils.generate_id())
        
        # Create bridge request
        bridge_request = Dict(
            "command" => command,
            "params" => params,
            "id" => request_id
        )
        
        # Run the command
        response = Bridge.run_command(bridge_request)
        
        # Return the response
        return HTTP.Response(
            200,
            ["Content-Type" => "application/json"],
            JSON.json(response)
        )
    catch e
        status, response = Errors.handle_error(e)
        
        return HTTP.Response(
            status,
            ["Content-Type" => "application/json"],
            JSON.json(response)
        )
    end
end

# Storage handlers

"""
    list_documents_handler(req::HTTP.Request)

Handle requests to list documents.
"""
function list_documents_handler(req::HTTP.Request)
    try
        # Parse query parameters
        query = HTTP.queryparams(req.target)
        
        # Extract collection
        collection = get(query, "collection", "default")
        
        # Extract pagination parameters
        page = parse(Int, get(query, "page", "1"))
        limit = parse(Int, get(query, "limit", "10"))
        
        # List documents
        documents = Storage.list_documents(collection, page=page, limit=limit)
        
        return HTTP.Response(
            200,
            ["Content-Type" => "application/json"],
            JSON.json(Dict(
                "success" => true,
                "data" => documents
            ))
        )
    catch e
        status, response = Errors.handle_error(e)
        
        return HTTP.Response(
            status,
            ["Content-Type" => "application/json"],
            JSON.json(response)
        )
    end
end

"""
    create_document_handler(req::HTTP.Request)

Handle requests to create a document.
"""
function create_document_handler(req::HTTP.Request)
    try
        # Parse the request body
        body = req.body
        
        # Validate required fields
        Utils.validate_required_fields(body, ["collection", "data"])
        
        # Extract fields
        collection = body["collection"]
        data = body["data"]
        
        # Create document
        document = Storage.save_document(collection, data)
        
        return HTTP.Response(
            201,
            ["Content-Type" => "application/json"],
            JSON.json(Dict(
                "success" => true,
                "data" => document
            ))
        )
    catch e
        status, response = Errors.handle_error(e)
        
        return HTTP.Response(
            status,
            ["Content-Type" => "application/json"],
            JSON.json(response)
        )
    end
end

"""
    get_document_handler(req::HTTP.Request)

Handle requests to get a document.
"""
function get_document_handler(req::HTTP.Request)
    try
        # Extract document ID from path parameters
        document_id = req.params["id"]
        
        # Parse query parameters
        query = HTTP.queryparams(req.target)
        
        # Extract collection
        collection = get(query, "collection", "default")
        
        # Get document
        document = Storage.get_document(collection, document_id)
        
        if isnothing(document)
            throw(NotFoundError("Document", document_id))
        end
        
        return HTTP.Response(
            200,
            ["Content-Type" => "application/json"],
            JSON.json(Dict(
                "success" => true,
                "data" => document
            ))
        )
    catch e
        status, response = Errors.handle_error(e)
        
        return HTTP.Response(
            status,
            ["Content-Type" => "application/json"],
            JSON.json(response)
        )
    end
end

"""
    update_document_handler(req::HTTP.Request)

Handle requests to update a document.
"""
function update_document_handler(req::HTTP.Request)
    try
        # Extract document ID from path parameters
        document_id = req.params["id"]
        
        # Parse the request body
        body = req.body
        
        # Validate required fields
        Utils.validate_required_fields(body, ["collection", "data"])
        
        # Extract fields
        collection = body["collection"]
        data = body["data"]
        
        # Update document
        document = Storage.update_document(collection, document_id, data)
        
        if isnothing(document)
            throw(NotFoundError("Document", document_id))
        end
        
        return HTTP.Response(
            200,
            ["Content-Type" => "application/json"],
            JSON.json(Dict(
                "success" => true,
                "data" => document
            ))
        )
    catch e
        status, response = Errors.handle_error(e)
        
        return HTTP.Response(
            status,
            ["Content-Type" => "application/json"],
            JSON.json(response)
        )
    end
end

"""
    delete_document_handler(req::HTTP.Request)

Handle requests to delete a document.
"""
function delete_document_handler(req::HTTP.Request)
    try
        # Extract document ID from path parameters
        document_id = req.params["id"]
        
        # Parse query parameters
        query = HTTP.queryparams(req.target)
        
        # Extract collection
        collection = get(query, "collection", "default")
        
        # Delete document
        success = Storage.delete_document(collection, document_id)
        
        if !success
            throw(NotFoundError("Document", document_id))
        end
        
        return HTTP.Response(
            200,
            ["Content-Type" => "application/json"],
            JSON.json(Dict(
                "success" => true
            ))
        )
    catch e
        status, response = Errors.handle_error(e)
        
        return HTTP.Response(
            status,
            ["Content-Type" => "application/json"],
            JSON.json(response)
        )
    end
end

# Blockchain handlers

"""
    get_balance_handler(req::HTTP.Request)

Handle requests to get a wallet balance.
"""
function get_balance_handler(req::HTTP.Request)
    try
        # Parse query parameters
        query = HTTP.queryparams(req.target)
        
        # Validate required parameters
        if !haskey(query, "address")
            throw(ValidationError("Missing required parameter: address", "address"))
        end
        
        # Extract parameters
        address = query["address"]
        chain = get(query, "chain", "ethereum")
        
        # Get balance
        balance = Blockchain.get_balance(address, chain)
        
        return HTTP.Response(
            200,
            ["Content-Type" => "application/json"],
            JSON.json(Dict(
                "success" => true,
                "data" => Dict(
                    "address" => address,
                    "chain" => chain,
                    "balance" => balance
                )
            ))
        )
    catch e
        status, response = Errors.handle_error(e)
        
        return HTTP.Response(
            status,
            ["Content-Type" => "application/json"],
            JSON.json(response)
        )
    end
end

"""
    get_token_balance_handler(req::HTTP.Request)

Handle requests to get a token balance.
"""
function get_token_balance_handler(req::HTTP.Request)
    try
        # Parse query parameters
        query = HTTP.queryparams(req.target)
        
        # Validate required parameters
        if !haskey(query, "address") || !haskey(query, "token")
            throw(ValidationError("Missing required parameters: address and token", "address"))
        end
        
        # Extract parameters
        address = query["address"]
        token = query["token"]
        chain = get(query, "chain", "ethereum")
        
        # Get token balance
        balance = Blockchain.get_token_balance(address, token, chain)
        
        return HTTP.Response(
            200,
            ["Content-Type" => "application/json"],
            JSON.json(Dict(
                "success" => true,
                "data" => Dict(
                    "address" => address,
                    "token" => token,
                    "chain" => chain,
                    "balance" => balance
                )
            ))
        )
    catch e
        status, response = Errors.handle_error(e)
        
        return HTTP.Response(
            status,
            ["Content-Type" => "application/json"],
            JSON.json(response)
        )
    end
end

"""
    send_transaction_handler(req::HTTP.Request)

Handle requests to send a transaction.
"""
function send_transaction_handler(req::HTTP.Request)
    try
        # Parse the request body
        body = req.body
        
        # Validate required fields
        Utils.validate_required_fields(body, ["to", "value"])
        
        # Extract fields
        to = body["to"]
        value = body["value"]
        data = get(body, "data", "0x")
        chain = get(body, "chain", "ethereum")
        
        # Send transaction
        tx_hash = Blockchain.send_transaction(to, value, data, chain)
        
        return HTTP.Response(
            200,
            ["Content-Type" => "application/json"],
            JSON.json(Dict(
                "success" => true,
                "data" => Dict(
                    "transaction_hash" => tx_hash,
                    "chain" => chain
                )
            ))
        )
    catch e
        status, response = Errors.handle_error(e)
        
        return HTTP.Response(
            status,
            ["Content-Type" => "application/json"],
            JSON.json(response)
        )
    end
end

# Agent handlers

"""
    list_agents_handler(req::HTTP.Request)

Handle requests to list agents.
"""
function list_agents_handler(req::HTTP.Request)
    try
        # Parse query parameters
        query = HTTP.queryparams(req.target)
        
        # Extract pagination parameters
        page = parse(Int, get(query, "page", "1"))
        limit = parse(Int, get(query, "limit", "10"))
        
        # List agents
        agents = Agents.list_agents(page=page, limit=limit)
        
        return HTTP.Response(
            200,
            ["Content-Type" => "application/json"],
            JSON.json(Dict(
                "success" => true,
                "data" => agents
            ))
        )
    catch e
        status, response = Errors.handle_error(e)
        
        return HTTP.Response(
            status,
            ["Content-Type" => "application/json"],
            JSON.json(response)
        )
    end
end

"""
    create_agent_handler(req::HTTP.Request)

Handle requests to create an agent.
"""
function create_agent_handler(req::HTTP.Request)
    try
        # Parse the request body
        body = req.body
        
        # Validate required fields
        Utils.validate_required_fields(body, ["name", "type"])
        
        # Extract fields
        name = body["name"]
        agent_type = body["type"]
        config = get(body, "config", Dict())
        
        # Create agent
        agent = Agents.create_agent(name, agent_type, config)
        
        return HTTP.Response(
            201,
            ["Content-Type" => "application/json"],
            JSON.json(Dict(
                "success" => true,
                "data" => agent
            ))
        )
    catch e
        status, response = Errors.handle_error(e)
        
        return HTTP.Response(
            status,
            ["Content-Type" => "application/json"],
            JSON.json(response)
        )
    end
end

"""
    get_agent_handler(req::HTTP.Request)

Handle requests to get an agent.
"""
function get_agent_handler(req::HTTP.Request)
    try
        # Extract agent ID from path parameters
        agent_id = req.params["id"]
        
        # Get agent
        agent = Agents.get_agent(agent_id)
        
        if isnothing(agent)
            throw(NotFoundError("Agent", agent_id))
        end
        
        return HTTP.Response(
            200,
            ["Content-Type" => "application/json"],
            JSON.json(Dict(
                "success" => true,
                "data" => agent
            ))
        )
    catch e
        status, response = Errors.handle_error(e)
        
        return HTTP.Response(
            status,
            ["Content-Type" => "application/json"],
            JSON.json(response)
        )
    end
end

"""
    update_agent_handler(req::HTTP.Request)

Handle requests to update an agent.
"""
function update_agent_handler(req::HTTP.Request)
    try
        # Extract agent ID from path parameters
        agent_id = req.params["id"]
        
        # Parse the request body
        body = req.body
        
        # Update agent
        agent = Agents.update_agent(agent_id, body)
        
        if isnothing(agent)
            throw(NotFoundError("Agent", agent_id))
        end
        
        return HTTP.Response(
            200,
            ["Content-Type" => "application/json"],
            JSON.json(Dict(
                "success" => true,
                "data" => agent
            ))
        )
    catch e
        status, response = Errors.handle_error(e)
        
        return HTTP.Response(
            status,
            ["Content-Type" => "application/json"],
            JSON.json(response)
        )
    end
end

"""
    delete_agent_handler(req::HTTP.Request)

Handle requests to delete an agent.
"""
function delete_agent_handler(req::HTTP.Request)
    try
        # Extract agent ID from path parameters
        agent_id = req.params["id"]
        
        # Delete agent
        success = Agents.delete_agent(agent_id)
        
        if !success
            throw(NotFoundError("Agent", agent_id))
        end
        
        return HTTP.Response(
            200,
            ["Content-Type" => "application/json"],
            JSON.json(Dict(
                "success" => true
            ))
        )
    catch e
        status, response = Errors.handle_error(e)
        
        return HTTP.Response(
            status,
            ["Content-Type" => "application/json"],
            JSON.json(response)
        )
    end
end

# Swarm handlers

"""
    list_swarms_handler(req::HTTP.Request)

Handle requests to list swarms.
"""
function list_swarms_handler(req::HTTP.Request)
    try
        # Parse query parameters
        query = HTTP.queryparams(req.target)
        
        # Extract pagination parameters
        page = parse(Int, get(query, "page", "1"))
        limit = parse(Int, get(query, "limit", "10"))
        
        # List swarms
        swarms = Swarms.list_swarms(page=page, limit=limit)
        
        return HTTP.Response(
            200,
            ["Content-Type" => "application/json"],
            JSON.json(Dict(
                "success" => true,
                "data" => swarms
            ))
        )
    catch e
        status, response = Errors.handle_error(e)
        
        return HTTP.Response(
            status,
            ["Content-Type" => "application/json"],
            JSON.json(response)
        )
    end
end

"""
    create_swarm_handler(req::HTTP.Request)

Handle requests to create a swarm.
"""
function create_swarm_handler(req::HTTP.Request)
    try
        # Parse the request body
        body = req.body
        
        # Validate required fields
        Utils.validate_required_fields(body, ["name", "algorithm"])
        
        # Extract fields
        name = body["name"]
        algorithm = body["algorithm"]
        config = get(body, "config", Dict())
        
        # Create swarm
        swarm = Swarms.create_swarm(name, algorithm, config)
        
        return HTTP.Response(
            201,
            ["Content-Type" => "application/json"],
            JSON.json(Dict(
                "success" => true,
                "data" => swarm
            ))
        )
    catch e
        status, response = Errors.handle_error(e)
        
        return HTTP.Response(
            status,
            ["Content-Type" => "application/json"],
            JSON.json(response)
        )
    end
end

"""
    get_swarm_handler(req::HTTP.Request)

Handle requests to get a swarm.
"""
function get_swarm_handler(req::HTTP.Request)
    try
        # Extract swarm ID from path parameters
        swarm_id = req.params["id"]
        
        # Get swarm
        swarm = Swarms.get_swarm(swarm_id)
        
        if isnothing(swarm)
            throw(NotFoundError("Swarm", swarm_id))
        end
        
        return HTTP.Response(
            200,
            ["Content-Type" => "application/json"],
            JSON.json(Dict(
                "success" => true,
                "data" => swarm
            ))
        )
    catch e
        status, response = Errors.handle_error(e)
        
        return HTTP.Response(
            status,
            ["Content-Type" => "application/json"],
            JSON.json(response)
        )
    end
end

"""
    run_optimization_handler(req::HTTP.Request)

Handle requests to run an optimization.
"""
function run_optimization_handler(req::HTTP.Request)
    try
        # Extract swarm ID from path parameters
        swarm_id = req.params["id"]
        
        # Parse the request body
        body = req.body
        
        # Validate required fields
        Utils.validate_required_fields(body, ["objective_function"])
        
        # Extract fields
        objective_function = body["objective_function"]
        constraints = get(body, "constraints", [])
        parameters = get(body, "parameters", Dict())
        
        # Run optimization
        result = Swarms.run_optimization(swarm_id, objective_function, constraints, parameters)
        
        return HTTP.Response(
            200,
            ["Content-Type" => "application/json"],
            JSON.json(Dict(
                "success" => true,
                "data" => result
            ))
        )
    catch e
        status, response = Errors.handle_error(e)
        
        return HTTP.Response(
            status,
            ["Content-Type" => "application/json"],
            JSON.json(response)
        )
    end
end

"""
    get_optimization_result_handler(req::HTTP.Request)

Handle requests to get an optimization result.
"""
function get_optimization_result_handler(req::HTTP.Request)
    try
        # Extract swarm ID from path parameters
        swarm_id = req.params["id"]
        
        # Parse query parameters
        query = HTTP.queryparams(req.target)
        
        # Extract result ID if provided
        result_id = get(query, "result_id", nothing)
        
        # Get optimization result
        result = if isnothing(result_id)
            Swarms.get_latest_result(swarm_id)
        else
            Swarms.get_result(swarm_id, result_id)
        end
        
        if isnothing(result)
            throw(NotFoundError("Optimization result", isnothing(result_id) ? "latest" : result_id))
        end
        
        return HTTP.Response(
            200,
            ["Content-Type" => "application/json"],
            JSON.json(Dict(
                "success" => true,
                "data" => result
            ))
        )
    catch e
        status, response = Errors.handle_error(e)
        
        return HTTP.Response(
            status,
            ["Content-Type" => "application/json"],
            JSON.json(response)
        )
    end
end

end # module
