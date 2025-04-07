module Web3Storage

using HTTP
using JSON
using Dates
using Logging
using Base64

# Configuration constants
const DEFAULT_CERAMIC_TESTNET_URL = "https://ceramic-clay.3boxlabs.com"
const DEFAULT_CERAMIC_MAINNET_URL = "https://ceramic.network"
const DEFAULT_IPFS_API_URL = "https://api.web3.storage"

# Global variables for configuration
ceramic_url = get(ENV, "CERAMIC_NODE_URL", DEFAULT_CERAMIC_TESTNET_URL)
ipfs_api_url = get(ENV, "IPFS_API_URL", DEFAULT_IPFS_API_URL)
ipfs_api_key = get(ENV, "IPFS_API_KEY", "")

# Set configuration
function configure(;ceramic_node_url=nothing, ipfs_api_url_arg=nothing, ipfs_api_key_arg=nothing)
    global ceramic_url, ipfs_api_url, ipfs_api_key
    
    if ceramic_node_url !== nothing
        ceramic_url = ceramic_node_url
    end
    
    if ipfs_api_url_arg !== nothing
        ipfs_api_url = ipfs_api_url_arg
    end
    
    if ipfs_api_key_arg !== nothing
        ipfs_api_key = ipfs_api_key_arg
    end
    
    @info "Web3Storage configured with Ceramic URL: $ceramic_url, IPFS API URL: $ipfs_api_url"
    
    return Dict(
        "ceramic_url" => ceramic_url,
        "ipfs_api_url" => ipfs_api_url,
        "ipfs_api_key_configured" => (ipfs_api_key != "")
    )
end

# =====================
# Ceramic Network APIs
# =====================

# Create a new document in Ceramic Network
function create_ceramic_document(content, schema="k3y52l7qbv1frxt706gqfzmq6cbqdkptzk8uudoryc9wv5hj4xvbx21lsilj0a")
    if !is_ceramic_configured()
        error("Ceramic Network not configured. Please provide CERAMIC_NODE_URL environment variable.")
    end
    
    headers = ["Content-Type" => "application/json"]
    
    # Create a document with the given schema
    body = Dict(
        "content" => content,
        "metadata" => Dict(
            "schema" => schema,
            "controllers" => ["did:key:z6MkfGLpuLq7vLik5Gy4xZxn71NfXMwJZJHnhEgARmxQbNPG"]  # Example DID, to be replaced with wallet DID
        )
    )
    
    try
        response = HTTP.post(
            "$(ceramic_url)/api/v0/documents", 
            headers,
            JSON.json(body)
        )
        
        if response.status == 200
            result = JSON.parse(String(response.body))
            return Dict("success" => true, "document_id" => result["id"], "content" => result["content"])
        else
            @error "Failed to create Ceramic document: $(response.status)"
            return Dict("success" => false, "error" => "HTTP error: $(response.status)")
        end
    catch e
        @error "Error creating Ceramic document: $e"
        return Dict("success" => false, "error" => string(e))
    end
end

# Get a document from Ceramic Network by ID
function get_ceramic_document(document_id)
    if !is_ceramic_configured()
        error("Ceramic Network not configured. Please provide CERAMIC_NODE_URL environment variable.")
    end
    
    try
        response = HTTP.get("$(ceramic_url)/api/v0/documents/$(document_id)")
        
        if response.status == 200
            result = JSON.parse(String(response.body))
            return Dict("success" => true, "document_id" => result["id"], "content" => result["content"])
        else
            @error "Failed to get Ceramic document: $(response.status)"
            return Dict("success" => false, "error" => "HTTP error: $(response.status)")
        end
    catch e
        @error "Error getting Ceramic document: $e"
        return Dict("success" => false, "error" => string(e))
    end
end

# Update a document in Ceramic Network
function update_ceramic_document(document_id, content)
    if !is_ceramic_configured()
        error("Ceramic Network not configured. Please provide CERAMIC_NODE_URL environment variable.")
    end
    
    headers = ["Content-Type" => "application/json"]
    
    body = Dict(
        "content" => content,
        "controllers" => ["did:key:z6MkfGLpuLq7vLik5Gy4xZxn71NfXMwJZJHnhEgARmxQbNPG"]  # Example DID, to be replaced with wallet DID
    )
    
    try
        response = HTTP.put(
            "$(ceramic_url)/api/v0/documents/$(document_id)", 
            headers,
            JSON.json(body)
        )
        
        if response.status == 200
            result = JSON.parse(String(response.body))
            return Dict("success" => true, "document_id" => result["id"], "content" => result["content"])
        else
            @error "Failed to update Ceramic document: $(response.status)"
            return Dict("success" => false, "error" => "HTTP error: $(response.status)")
        end
    catch e
        @error "Error updating Ceramic document: $e"
        return Dict("success" => false, "error" => string(e))
    end
end

# =====================
# IPFS/Web3.Storage APIs
# =====================

# Upload a file to IPFS via Web3.Storage
function upload_to_ipfs(file_data; filename="file.bin", mime_type="application/octet-stream")
    if !is_ipfs_configured()
        error("IPFS not configured. Please provide IPFS_API_URL and IPFS_API_KEY environment variables.")
    end
    
    headers = [
        "Authorization" => "Bearer $(ipfs_api_key)",
        "Content-Type" => mime_type,
        "X-Name" => filename
    ]
    
    try
        response = HTTP.post(
            "$(ipfs_api_url)/upload", 
            headers,
            file_data
        )
        
        if response.status == 200
            result = JSON.parse(String(response.body))
            return Dict(
                "success" => true, 
                "cid" => result["cid"], 
                "url" => "ipfs://$(result["cid"])"
            )
        else
            @error "Failed to upload to IPFS: $(response.status)"
            return Dict("success" => false, "error" => "HTTP error: $(response.status)")
        end
    catch e
        @error "Error uploading to IPFS: $e"
        return Dict("success" => false, "error" => string(e))
    end
end

# Get a file from IPFS via Web3.Storage
function get_from_ipfs(cid)
    if !is_ipfs_configured()
        error("IPFS not configured. Please provide IPFS_API_URL and IPFS_API_KEY environment variables.")
    end
    
    headers = ["Authorization" => "Bearer $(ipfs_api_key)"]
    
    try
        response = HTTP.get(
            "$(ipfs_api_url)/$(cid)", 
            headers
        )
        
        if response.status == 200
            return Dict(
                "success" => true, 
                "data" => response.body
            )
        else
            @error "Failed to get from IPFS: $(response.status)"
            return Dict("success" => false, "error" => "HTTP error: $(response.status)")
        end
    catch e
        @error "Error getting from IPFS: $e"
        return Dict("success" => false, "error" => string(e))
    end
end

# Upload JSON data to IPFS
function upload_json_to_ipfs(json_data; filename="data.json")
    if typeof(json_data) != String
        json_data = JSON.json(json_data)
    end
    
    return upload_to_ipfs(
        json_data, 
        filename=filename, 
        mime_type="application/json"
    )
end

# Get JSON data from IPFS
function get_json_from_ipfs(cid)
    result = get_from_ipfs(cid)
    
    if result["success"]
        try
            json_data = JSON.parse(String(result["data"]))
            return Dict("success" => true, "data" => json_data)
        catch e
            @error "Error parsing JSON from IPFS: $e"
            return Dict("success" => false, "error" => "Invalid JSON data")
        end
    else
        return result
    end
end

# =====================
# Agent Storage in Web3
# =====================

# Store agent in Ceramic + IPFS
function store_agent(agent_data)
    # For large agent data (models, etc.), store in IPFS
    large_data = Dict()
    
    # Check if agent has any large data components
    if haskey(agent_data, "model") && length(JSON.json(agent_data["model"])) > 1000
        model_result = upload_json_to_ipfs(agent_data["model"], filename="$(agent_data["id"])_model.json")
        if model_result["success"]
            large_data["model"] = model_result["cid"]
            delete!(agent_data, "model")
            agent_data["model_cid"] = model_result["cid"]
        end
    end
    
    # Store the main agent data in Ceramic
    ceramic_result = create_ceramic_document(agent_data)
    
    if ceramic_result["success"]
        result = Dict(
            "success" => true,
            "ceramic_doc_id" => ceramic_result["document_id"],
            "large_data" => large_data
        )
        
        # Update the agent with storage information
        agent_data["storage"] = Dict(
            "type" => "web3",
            "ceramic_doc_id" => ceramic_result["document_id"],
            "large_data" => large_data
        )
        
        return result
    else
        return ceramic_result
    end
end

# Retrieve agent from Web3 storage
function retrieve_agent(ceramic_doc_id)
    # Get agent metadata from Ceramic
    ceramic_result = get_ceramic_document(ceramic_doc_id)
    
    if !ceramic_result["success"]
        return ceramic_result
    end
    
    agent_data = ceramic_result["content"]
    
    # If agent has IPFS-stored components, retrieve them
    if haskey(agent_data, "model_cid")
        model_result = get_json_from_ipfs(agent_data["model_cid"])
        if model_result["success"]
            agent_data["model"] = model_result["data"]
        end
    end
    
    return Dict("success" => true, "agent" => agent_data)
end

# Update agent in Web3 storage
function update_agent(ceramic_doc_id, updates)
    # First get the current agent data
    current_agent = get_ceramic_document(ceramic_doc_id)
    
    if !current_agent["success"]
        return current_agent
    end
    
    agent_data = current_agent["content"]
    
    # Apply updates
    for (key, value) in pairs(updates)
        agent_data[key] = value
    end
    
    # Check for large data components
    if haskey(agent_data, "model") && length(JSON.json(agent_data["model"])) > 1000
        model_result = upload_json_to_ipfs(agent_data["model"], filename="$(agent_data["id"])_model.json")
        if model_result["success"]
            agent_data["model_cid"] = model_result["cid"]
            delete!(agent_data, "model")
        end
    end
    
    # Update in Ceramic
    update_result = update_ceramic_document(ceramic_doc_id, agent_data)
    
    return update_result
end

# =====================
# Swarm Storage in Web3
# =====================

# Store swarm in Web3 storage
function store_swarm(swarm_data)
    # For large swarm data, store in IPFS
    large_data = Dict()
    
    # Check for large data components
    if haskey(swarm_data, "algorithm_data") && length(JSON.json(swarm_data["algorithm_data"])) > 1000
        algo_result = upload_json_to_ipfs(
            swarm_data["algorithm_data"], 
            filename="$(swarm_data["id"])_algorithm.json"
        )
        if algo_result["success"]
            large_data["algorithm_data"] = algo_result["cid"]
            delete!(swarm_data, "algorithm_data")
            swarm_data["algorithm_data_cid"] = algo_result["cid"]
        end
    end
    
    # Store the main swarm data in Ceramic
    ceramic_result = create_ceramic_document(swarm_data)
    
    if ceramic_result["success"]
        result = Dict(
            "success" => true,
            "ceramic_doc_id" => ceramic_result["document_id"],
            "large_data" => large_data
        )
        
        # Update the swarm with storage information
        swarm_data["storage"] = Dict(
            "type" => "web3",
            "ceramic_doc_id" => ceramic_result["document_id"],
            "large_data" => large_data
        )
        
        return result
    else
        return ceramic_result
    end
end

# Retrieve swarm from Web3 storage
function retrieve_swarm(ceramic_doc_id)
    # Get swarm metadata from Ceramic
    ceramic_result = get_ceramic_document(ceramic_doc_id)
    
    if !ceramic_result["success"]
        return ceramic_result
    end
    
    swarm_data = ceramic_result["content"]
    
    # If swarm has IPFS-stored components, retrieve them
    if haskey(swarm_data, "algorithm_data_cid")
        algo_result = get_json_from_ipfs(swarm_data["algorithm_data_cid"])
        if algo_result["success"]
            swarm_data["algorithm_data"] = algo_result["data"]
        end
    end
    
    return Dict("success" => true, "swarm" => swarm_data)
end

# Update swarm in Web3 storage
function update_swarm(ceramic_doc_id, updates)
    # First get the current swarm data
    current_swarm = get_ceramic_document(ceramic_doc_id)
    
    if !current_swarm["success"]
        return current_swarm
    end
    
    swarm_data = current_swarm["content"]
    
    # Apply updates
    for (key, value) in pairs(updates)
        swarm_data[key] = value
    end
    
    # Check for large data components
    if haskey(swarm_data, "algorithm_data") && length(JSON.json(swarm_data["algorithm_data"])) > 1000
        algo_result = upload_json_to_ipfs(
            swarm_data["algorithm_data"], 
            filename="$(swarm_data["id"])_algorithm.json"
        )
        if algo_result["success"]
            swarm_data["algorithm_data_cid"] = algo_result["cid"]
            delete!(swarm_data, "algorithm_data")
        end
    end
    
    # Update in Ceramic
    update_result = update_ceramic_document(ceramic_doc_id, swarm_data)
    
    return update_result
end

# =====================
# Marketplace Functions
# =====================

# Store agent on marketplace
function publish_agent_to_marketplace(agent_data, description, price="0", category="general")
    # First store the agent data itself
    storage_result = store_agent(agent_data)
    
    if !storage_result["success"]
        return storage_result
    end
    
    # Create marketplace listing
    marketplace_listing = Dict(
        "type" => "agent",
        "agent_id" => agent_data["id"],
        "name" => agent_data["name"],
        "ceramic_doc_id" => storage_result["ceramic_doc_id"],
        "description" => description,
        "price" => price,
        "category" => category,
        "creator" => agent_data["creator"] !== nothing ? agent_data["creator"] : "unknown",
        "created_at" => string(now()),
        "updated_at" => string(now()),
        "rating" => 0,
        "downloads" => 0
    )
    
    # Store the marketplace listing in Ceramic
    marketplace_result = create_ceramic_document(marketplace_listing, schema="marketplace")
    
    if marketplace_result["success"]
        return Dict(
            "success" => true,
            "listing_id" => marketplace_result["document_id"],
            "storage_info" => storage_result
        )
    else
        return marketplace_result
    end
end

# Store swarm on marketplace
function publish_swarm_to_marketplace(swarm_data, description, price="0", category="general")
    # First store the swarm data itself
    storage_result = store_swarm(swarm_data)
    
    if !storage_result["success"]
        return storage_result
    end
    
    # Create marketplace listing
    marketplace_listing = Dict(
        "type" => "swarm",
        "swarm_id" => swarm_data["id"],
        "name" => swarm_data["name"],
        "ceramic_doc_id" => storage_result["ceramic_doc_id"],
        "description" => description,
        "price" => price,
        "category" => category,
        "creator" => swarm_data["creator"] !== nothing ? swarm_data["creator"] : "unknown",
        "created_at" => string(now()),
        "updated_at" => string(now()),
        "rating" => 0,
        "downloads" => 0
    )
    
    # Store the marketplace listing in Ceramic
    marketplace_result = create_ceramic_document(marketplace_listing, schema="marketplace")
    
    if marketplace_result["success"]
        return Dict(
            "success" => true,
            "listing_id" => marketplace_result["document_id"],
            "storage_info" => storage_result
        )
    else
        return marketplace_result
    end
end

# List agents in marketplace
function list_marketplace_agents(category=nothing)
    # This is a simplified version. In a real implementation, we'd use Ceramic's querying capabilities
    # or more likely The Graph to index and query Ceramic documents
    
    # For now, we'll return mock data
    @warn "Using mock marketplace data. In a production environment, you would use a proper query mechanism like The Graph."
    
    # Mock data
    listings = [
        Dict(
            "listing_id" => "ceramic://abcdef1234567890",
            "agent_id" => "agent-1",
            "name" => "Trading Assistant",
            "description" => "Helps with crypto trading",
            "price" => "0",
            "category" => "trading",
            "creator" => "example-user",
            "created_at" => "2023-01-01T00:00:00",
            "rating" => 4.5,
            "downloads" => 120
        ),
        Dict(
            "listing_id" => "ceramic://0987654321fedcba",
            "agent_id" => "agent-2",
            "name" => "Market Analyzer",
            "description" => "Analyzes market trends",
            "price" => "10",
            "category" => "analysis",
            "creator" => "another-user",
            "created_at" => "2023-02-15T00:00:00",
            "rating" => 4.8,
            "downloads" => 85
        )
    ]
    
    # Filter by category if provided
    if category !== nothing
        listings = filter(l -> l["category"] == category, listings)
    end
    
    return Dict("success" => true, "listings" => listings)
end

# =====================
# Helper Functions
# =====================

# Check if Ceramic is configured
function is_ceramic_configured()
    return ceramic_url != "" && ceramic_url != DEFAULT_CERAMIC_TESTNET_URL
end

# Check if IPFS is configured
function is_ipfs_configured()
    return ipfs_api_url != "" && ipfs_api_key != ""
end

end # module 