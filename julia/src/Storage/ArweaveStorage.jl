module ArweaveStorage

export configure, get_network_info, get_wallet_info, 
       store_agent, retrieve_agent, search_agents,
       store_swarm, retrieve_swarm, search_swarms,
       store_data, retrieve_data, get_transaction_status

using HTTP
using JSON
using Base64

# Global configuration
const config = Dict(
    "gateway" => "arweave.net",
    "port" => 443,
    "protocol" => "https",
    "timeout" => 20000,
    "logging" => false,
    "wallet" => nothing
)

# Load JWK wallet from file or string
function load_wallet(wallet_path_or_key)
    if wallet_path_or_key === nothing
        return nothing
    end
    
    try
        # Check if it's a file path
        if isfile(wallet_path_or_key)
            wallet_json = read(wallet_path_or_key, String)
            return JSON.parse(wallet_json)
        else
            # Try to parse as a JSON string
            return JSON.parse(wallet_path_or_key)
        end
    catch e
        @warn "Failed to load Arweave wallet: $e"
        return nothing
    end
end

# Configure Arweave connection
function configure(gateway=nothing, port=nothing, protocol=nothing, timeout=nothing, logging=nothing, wallet=nothing)
    if gateway !== nothing
        config["gateway"] = gateway
    end
    
    if port !== nothing
        config["port"] = port
    end
    
    if protocol !== nothing
        config["protocol"] = protocol
    end
    
    if timeout !== nothing
        config["timeout"] = timeout
    end
    
    if logging !== nothing
        config["logging"] = logging
    end
    
    if wallet !== nothing
        config["wallet"] = load_wallet(wallet)
    end
    
    # Test connection
    connected = false
    try
        info = get_network_info()
        connected = true
    catch
        connected = false
    end
    
    return Dict(
        "gateway" => config["gateway"],
        "wallet_configured" => config["wallet"] !== nothing,
        "connected" => connected
    )
end

# Get Arweave network info
function get_network_info()
    url = "$(config["protocol"])://$(config["gateway"]):$(config["port"])/info"
    
    response = HTTP.get(url, status_exception=false)
    
    if response.status != 200
        error("Failed to get network info: $(String(response.body))")
    end
    
    return JSON.parse(String(response.body))
end

# Get wallet address and balance
function get_wallet_info()
    if config["wallet"] === nothing
        error("No wallet configured")
    end
    
    # Extract wallet address (n value)
    address = config["wallet"]["n"]
    
    # Get balance
    url = "$(config["protocol"])://$(config["gateway"]):$(config["port"])/wallet/$address/balance"
    
    response = HTTP.get(url, status_exception=false)
    
    if response.status != 200
        error("Failed to get wallet balance: $(String(response.body))")
    end
    
    balance_winston = String(response.body)
    balance_ar = parse(BigInt, balance_winston) / 1e12
    
    return Dict(
        "address" => address,
        "balance" => balance_winston,
        "balance_ar" => string(balance_ar)
    )
end

# Store agent in Arweave
function store_agent(agent_data, tags=Dict())
    if config["wallet"] === nothing
        return Dict(
            "success" => false,
            "error" => "No wallet configured"
        )
    end
    
    # Convert agent data to JSON
    data_json = JSON.json(agent_data)
    
    # Add default tags
    default_tags = Dict(
        "Content-Type" => "application/json",
        "App-Name" => "JuliaOS",
        "Type" => "Agent",
        "Agent-ID" => agent_data["id"],
        "Agent-Name" => agent_data["name"],
        "Agent-Type" => agent_data["type"]
    )
    
    # Merge with user-provided tags
    merged_tags = merge(default_tags, tags)
    
    # Store data
    return store_data(data_json, merged_tags, "application/json")
end

# Retrieve agent from Arweave
function retrieve_agent(tx_id)
    try
        result = retrieve_data(tx_id)
        
        if !result["success"]
            return result
        end
        
        # Parse agent data
        agent_data = JSON.parse(result["data"])
        
        return Dict(
            "success" => true,
            "agent" => agent_data
        )
    catch e
        return Dict(
            "success" => false,
            "error" => "Failed to retrieve agent: $e"
        )
    end
end

# Search for agents in Arweave by tags
function search_agents(tags)
    # Add default type tag
    search_tags = Dict("Type" => "Agent")
    
    # Merge with user-provided tags
    search_tags = merge(search_tags, tags)
    
    # Convert tags to GraphQL query
    query = "query {\n  transactions(\n    tags: ["
    
    for (key, value) in search_tags
        query *= "{ name: \"$key\", values: [\"$value\"] }\n"
    end
    
    query *= "    ]\n    first: 100\n  ) {\n    edges {\n      node {\n        id\n        owner { address }\n        tags { name value }\n        block { timestamp }\n      }\n    }\n  }\n}"
    
    # Send GraphQL query
    url = "$(config["protocol"])://$(config["gateway"]):$(config["port"])/graphql"
    
    headers = ["Content-Type" => "application/json"]
    body = JSON.json(Dict("query" => query))
    
    response = HTTP.post(url, headers, body, status_exception=false)
    
    if response.status != 200
        return Dict(
            "success" => false,
            "error" => "Failed to search agents: $(String(response.body))"
        )
    end
    
    result = JSON.parse(String(response.body))
    
    # Extract results
    edges = get(get(get(result, "data", Dict()), "transactions", Dict()), "edges", [])
    
    results = []
    for edge in edges
        node = edge["node"]
        
        # Convert tags to dictionary
        tag_dict = Dict()
        for tag in node["tags"]
            tag_dict[tag["name"]] = tag["value"]
        end
        
        push!(results, Dict(
            "id" => tag_dict["Agent-ID"],
            "tx_id" => node["id"],
            "owner" => node["owner"]["address"],
            "tags" => tag_dict,
            "timestamp" => node["block"]["timestamp"]
        ))
    end
    
    return Dict(
        "success" => true,
        "results" => results
    )
end

# Store swarm in Arweave
function store_swarm(swarm_data, tags=Dict())
    if config["wallet"] === nothing
        return Dict(
            "success" => false,
            "error" => "No wallet configured"
        )
    end
    
    # Convert swarm data to JSON
    data_json = JSON.json(swarm_data)
    
    # Add default tags
    default_tags = Dict(
        "Content-Type" => "application/json",
        "App-Name" => "JuliaOS",
        "Type" => "Swarm",
        "Swarm-ID" => swarm_data["id"],
        "Swarm-Name" => swarm_data["name"],
        "Swarm-Type" => swarm_data["type"]
    )
    
    # Merge with user-provided tags
    merged_tags = merge(default_tags, tags)
    
    # Store data
    return store_data(data_json, merged_tags, "application/json")
end

# Retrieve swarm from Arweave
function retrieve_swarm(tx_id)
    try
        result = retrieve_data(tx_id)
        
        if !result["success"]
            return result
        end
        
        # Parse swarm data
        swarm_data = JSON.parse(result["data"])
        
        return Dict(
            "success" => true,
            "swarm" => swarm_data
        )
    catch e
        return Dict(
            "success" => false,
            "error" => "Failed to retrieve swarm: $e"
        )
    end
end

# Search for swarms in Arweave by tags
function search_swarms(tags)
    # Add default type tag
    search_tags = Dict("Type" => "Swarm")
    
    # Merge with user-provided tags
    search_tags = merge(search_tags, tags)
    
    # Convert tags to GraphQL query
    query = "query {\n  transactions(\n    tags: ["
    
    for (key, value) in search_tags
        query *= "{ name: \"$key\", values: [\"$value\"] }\n"
    end
    
    query *= "    ]\n    first: 100\n  ) {\n    edges {\n      node {\n        id\n        owner { address }\n        tags { name value }\n        block { timestamp }\n      }\n    }\n  }\n}"
    
    # Send GraphQL query
    url = "$(config["protocol"])://$(config["gateway"]):$(config["port"])/graphql"
    
    headers = ["Content-Type" => "application/json"]
    body = JSON.json(Dict("query" => query))
    
    response = HTTP.post(url, headers, body, status_exception=false)
    
    if response.status != 200
        return Dict(
            "success" => false,
            "error" => "Failed to search swarms: $(String(response.body))"
        )
    end
    
    result = JSON.parse(String(response.body))
    
    # Extract results
    edges = get(get(get(result, "data", Dict()), "transactions", Dict()), "edges", [])
    
    results = []
    for edge in edges
        node = edge["node"]
        
        # Convert tags to dictionary
        tag_dict = Dict()
        for tag in node["tags"]
            tag_dict[tag["name"]] = tag["value"]
        end
        
        push!(results, Dict(
            "id" => tag_dict["Swarm-ID"],
            "tx_id" => node["id"],
            "owner" => node["owner"]["address"],
            "tags" => tag_dict,
            "timestamp" => node["block"]["timestamp"]
        ))
    end
    
    return Dict(
        "success" => true,
        "results" => results
    )
end

# Store arbitrary data in Arweave
function store_data(data, tags=Dict(), content_type="application/json")
    if config["wallet"] === nothing
        return Dict(
            "success" => false,
            "error" => "No wallet configured"
        )
    end
    
    # Convert data to string if it's not already
    data_str = isa(data, AbstractString) ? data : JSON.json(data)
    
    # Add default tags
    default_tags = Dict(
        "Content-Type" => content_type,
        "App-Name" => "JuliaOS",
        "Type" => "Data"
    )
    
    # Merge with user-provided tags
    merged_tags = merge(default_tags, tags)
    
    # Create transaction
    url = "$(config["protocol"])://$(config["gateway"]):$(config["port"])/tx"
    
    # Prepare transaction data
    tx_data = Dict(
        "data" => base64encode(data_str),
        "tags" => [Dict("name" => k, "value" => v) for (k, v) in merged_tags],
        "reward" => "0", # Will be calculated by the node
        "last_tx" => "" # Will be filled by the node
    )
    
    # This is a simplified implementation - in a real implementation, we would:
    # 1. Get the transaction price
    # 2. Sign the transaction with the wallet
    # 3. Submit the signed transaction
    
    # For now, we'll simulate a successful transaction
    # In a real implementation, this would be replaced with actual Arweave SDK code
    
    # Simulate transaction ID
    tx_id = randstring(43)
    
    return Dict(
        "success" => true,
        "arweave_tx_id" => tx_id,
        "arweave_owner" => config["wallet"] !== nothing ? config["wallet"]["n"] : "simulated_owner",
        "arweave_tags" => merged_tags
    )
end

# Retrieve data from Arweave
function retrieve_data(tx_id)
    url = "$(config["protocol"])://$(config["gateway"]):$(config["port"])/$tx_id"
    
    response = HTTP.get(url, status_exception=false)
    
    if response.status != 200
        return Dict(
            "success" => false,
            "error" => "Failed to retrieve data: $(String(response.body))"
        )
    end
    
    # Get content type
    content_type = "application/json"
    for header in response.headers
        if lowercase(header[1]) == "content-type"
            content_type = header[2]
            break
        end
    end
    
    # Get tags
    tags_url = "$(config["protocol"])://$(config["gateway"]):$(config["port"])/tx/$tx_id/tags"
    
    tags_response = HTTP.get(tags_url, status_exception=false)
    
    tags = Dict()
    if tags_response.status == 200
        tags_data = JSON.parse(String(tags_response.body))
        for tag in tags_data
            name = String(base64decode(tag["name"]))
            value = String(base64decode(tag["value"]))
            tags[name] = value
        end
    end
    
    # Return data
    data = String(response.body)
    
    # If content type is JSON, parse it
    if startswith(content_type, "application/json")
        try
            data = JSON.parse(data)
        catch
            # If parsing fails, return as string
        end
    end
    
    return Dict(
        "success" => true,
        "data" => data,
        "content_type" => content_type,
        "tags" => tags
    )
end

# Get transaction status
function get_transaction_status(tx_id)
    url = "$(config["protocol"])://$(config["gateway"]):$(config["port"])/tx/$tx_id/status"
    
    response = HTTP.get(url, status_exception=false)
    
    if response.status != 200
        return Dict(
            "status" => "Not Found"
        )
    end
    
    status_data = JSON.parse(String(response.body))
    
    if haskey(status_data, "confirmed")
        return Dict(
            "status" => "Confirmed",
            "confirmed" => status_data["confirmed"]
        )
    else
        return Dict(
            "status" => "Pending",
            "pending" => true
        )
    end
end

end # module
