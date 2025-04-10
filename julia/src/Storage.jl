module Storage

export initialize, create_agent, get_agent, list_agents, update_agent, delete_agent,
       create_swarm, get_swarm, list_swarms, update_swarm, delete_swarm,
       add_agent_to_swarm, remove_agent_from_swarm, get_swarm_agents,
       save_setting, get_setting, list_settings, delete_setting,
       record_transaction, update_transaction_status, get_transaction, list_transactions,
       create_backup, restore_backup, list_backups, delete_backup, backup_database, vacuum_database,
       configure_arweave, get_arweave_network_info, get_arweave_wallet_info,
       store_agent_in_arweave, retrieve_agent_from_arweave, search_agents_in_arweave,
       store_swarm_in_arweave, retrieve_swarm_from_arweave, search_swarms_in_arweave,
       store_data_in_arweave, retrieve_data_from_arweave, get_arweave_transaction_status,
       # Document storage functions for LangChain integration
       add_documents, add_vector_documents, search_documents, search_vector_documents,
       delete_documents, get_document, list_documents, list_collections

using SQLite
using DataFrames
using Dates
using JSON
using Logging

# Import storage modules
include("Storage/ArweaveStorage.jl")
using .ArweaveStorage

# Import document storage module for LangChain integration
include("Storage/DocumentStorage.jl")
using .DocumentStorage

# Database path in user's home directory
const DB_PATH = joinpath(homedir(), ".juliaos", "juliaos.sqlite")

# Ensure directory exists
function ensure_db_dir()
    db_dir = dirname(DB_PATH)
    if !isdir(db_dir)
        mkpath(db_dir)
        @info "Created database directory: $db_dir"
    end
end

# Initialize database connection
function init_db()
    ensure_db_dir()

    # Create database if it doesn't exist
    if !isfile(DB_PATH)
        @info "Creating new database at $DB_PATH"
    else
        @info "Using existing database at $DB_PATH"
    end

    db = SQLite.DB(DB_PATH)

    # Create tables if they don't exist
    create_tables(db)

    return db
end

# Create all required tables
function create_tables(db)
    # Agents table
    SQLite.execute(db, """
        CREATE TABLE IF NOT EXISTS agents (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            config TEXT,
            status TEXT,
            created_at DATETIME,
            updated_at DATETIME
        )
    """)

    # Swarms table
    SQLite.execute(db, """
        CREATE TABLE IF NOT EXISTS swarms (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            type TEXT NOT NULL,
            algorithm TEXT,
            config TEXT,
            status TEXT,
            agent_count INTEGER DEFAULT 0,
            created_at DATETIME,
            updated_at DATETIME
        )
    """)

    # Swarm agents junction table
    SQLite.execute(db, """
        CREATE TABLE IF NOT EXISTS swarm_agents (
            swarm_id TEXT,
            agent_id TEXT,
            added_at DATETIME,
            PRIMARY KEY (swarm_id, agent_id),
            FOREIGN KEY (swarm_id) REFERENCES swarms(id) ON DELETE CASCADE,
            FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE CASCADE
        )
    """)

    # Transactions table
    SQLite.execute(db, """
        CREATE TABLE IF NOT EXISTS transactions (
            id TEXT PRIMARY KEY,
            chain TEXT NOT NULL,
            tx_hash TEXT,
            from_address TEXT,
            to_address TEXT,
            amount TEXT,
            token TEXT,
            status TEXT,
            created_at DATETIME,
            confirmed_at DATETIME
        )
    """)

    # API Keys table
    SQLite.execute(db, """
        CREATE TABLE IF NOT EXISTS api_keys (
            id TEXT PRIMARY KEY,
            service TEXT NOT NULL,
            api_key TEXT NOT NULL,
            is_valid BOOLEAN DEFAULT 1,
            last_used DATETIME,
            created_at DATETIME
        )
    """)

    # Settings table
    SQLite.execute(db, """
        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT,
            updated_at DATETIME
        )
    """)

    # Create document tables for LangChain integration
    DocumentStorage.create_document_tables(db)

    @info "Database tables initialized"
end

# =====================
# Agent CRUD Operations
# =====================

# Create a new agent
function create_agent(db, id, name, type, config)
    config_json = typeof(config) == String ? config : JSON.json(config)

    @info "[Storage.create_agent] Attempting to insert agent ID: $id, Name: $name, Type: $type"
    try
        SQLite.execute(db, """
            INSERT INTO agents (id, name, type, config, status, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, [id, name, type, config_json, "Initialized", string(now()), string(now())])
        @info "[Storage.create_agent] Successfully executed INSERT for agent ID: $id"
    catch e
        @error "[Storage.create_agent] FAILED to execute INSERT for agent ID: $id. Error: $e" stacktrace(catch_backtrace())
        # Re-throw the error to ensure the calling function knows about the failure
        rethrow(e)
    end

    @info "Created agent: $id ($name)"

    return get_agent(db, id)
end

# Get agent by ID
function get_agent(db, id)
    result = SQLite.DBInterface.execute(db, """
        SELECT * FROM agents WHERE id = ?
    """, [id]) |> DataFrame

    if size(result, 1) == 0
        return nothing
    end

    # Convert config from JSON string to Dict
    agent = Dict(pairs(result[1, :]))
    if haskey(agent, :config) && agent[:config] !== nothing
        try
            agent[:config] = JSON.parse(agent[:config])
        catch e
            @warn "Failed to parse agent config: $e"
        end
    end

    return agent
end

# List all agents
function list_agents(db)
    result = SQLite.DBInterface.execute(db, "SELECT * FROM agents") |> DataFrame

    agents = []
    for row in eachrow(result)
        agent = Dict(pairs(row))
        if haskey(agent, :config) && agent[:config] !== nothing
            try
                agent[:config] = JSON.parse(agent[:config])
            catch e
                @warn "Failed to parse agent config: $e"
            end
        end
        push!(agents, agent)
    end

    return agents
end

# Update agent
function update_agent(db, id, updates)
    # Get current agent to confirm it exists
    current = get_agent(db, id)
    if current === nothing
        error("Agent not found: $id")
    end

    # Build update query
    set_clause = []
    values = []

    for (key, value) in pairs(updates)
        if key == :config || key == "config"
            # Convert config to JSON if it's not already a string
            config_str = typeof(value) == String ? value : JSON.json(value)
            push!(set_clause, "config = ?")
            push!(values, config_str)
        elseif key in [:name, :type, :status, "name", "type", "status"]
            push!(set_clause, "$(key) = ?")
            push!(values, value)
        end
    end

    # Add updated_at
    push!(set_clause, "updated_at = ?")
    push!(values, string(now()))

    # Add ID for WHERE clause
    push!(values, id)

    # Execute update
    SQLite.execute(db, """
        UPDATE agents
        SET $(join(set_clause, ", "))
        WHERE id = ?
    """, values)

    @info "Updated agent: $id"

    return get_agent(db, id)
end

# Delete agent
function delete_agent(db, id)
    # Check if agent exists
    agent = get_agent(db, id)
    if agent === nothing
        error("Agent not found: $id")
    end

    # Delete agent
    SQLite.execute(db, "DELETE FROM agents WHERE id = ?", [id])

    @info "Deleted agent: $id"

    return Dict("success" => true, "id" => id)
end

# =====================
# Swarm CRUD Operations
# =====================

# Create a new swarm
function create_swarm(db, id, name, type, algorithm, config)
    config_json = typeof(config) == String ? config : JSON.json(config)
    # Convert algorithm dict to JSON string if it's not already
    algo_json = typeof(algorithm) == String ? algorithm : JSON.json(algorithm)

    @info "[Storage.create_swarm] Attempting to insert swarm ID: $id, Name: $name, Type: $type, Algo: $algo_json"
    try
        SQLite.execute(db, """
            INSERT INTO swarms (id, name, type, algorithm, config, status, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, [id, name, type, algo_json, config_json, "Initialized", string(now()), string(now())])
         @info "[Storage.create_swarm] Successfully executed INSERT for swarm ID: $id"
    catch e
        @error "[Storage.create_swarm] FAILED to execute INSERT for swarm ID: $id. Error: $e" stacktrace(catch_backtrace())
        # Re-throw the error
        rethrow(e)
    end

    @info "Created swarm: $id ($name)"

    return get_swarm(db, id)
end

# Get swarm by ID
function get_swarm(db, id)
    result = SQLite.DBInterface.execute(db, """
        SELECT * FROM swarms WHERE id = ?
    """, [id]) |> DataFrame

    if size(result, 1) == 0
        return nothing
    end

    # Convert config from JSON string to Dict
    swarm = Dict(pairs(result[1, :]))
    if haskey(swarm, :config) && swarm[:config] !== nothing
        try
            swarm[:config] = JSON.parse(swarm[:config])
        catch e
            @warn "Failed to parse swarm config: $e"
        end
    end

    return swarm
end

# List all swarms
function list_swarms(db)
    result = SQLite.DBInterface.execute(db, "SELECT * FROM swarms") |> DataFrame

    swarms = []
    for row in eachrow(result)
        swarm = Dict(pairs(row))
        if haskey(swarm, :config) && swarm[:config] !== nothing
            try
                swarm[:config] = JSON.parse(swarm[:config])
            catch e
                @warn "Failed to parse swarm config: $e"
            end
        end
        push!(swarms, swarm)
    end

    return swarms
end

# Update swarm
function update_swarm(db, id, updates)
    # Get current swarm to confirm it exists
    current = get_swarm(db, id)
    if current === nothing
        error("Swarm not found: $id")
    end

    # Build update query
    set_clause = []
    values = []

    for (key, value) in pairs(updates)
        if key == :config || key == "config"
            # Convert config to JSON if it's not already a string
            config_str = typeof(value) == String ? value : JSON.json(value)
            push!(set_clause, "config = ?")
            push!(values, config_str)
        elseif key in [:name, :type, :algorithm, :status, :agent_count, "name", "type", "algorithm", "status", "agent_count"]
            push!(set_clause, "$(key) = ?")
            push!(values, value)
        end
    end

    # Add updated_at
    push!(set_clause, "updated_at = ?")
    push!(values, string(now()))

    # Add ID for WHERE clause
    push!(values, id)

    # Execute update
    SQLite.execute(db, """
        UPDATE swarms
        SET $(join(set_clause, ", "))
        WHERE id = ?
    """, values)

    @info "Updated swarm: $id"

    return get_swarm(db, id)
end

# Delete swarm
function delete_swarm(db, id)
    # Check if swarm exists
    swarm = get_swarm(db, id)
    if swarm === nothing
        error("Swarm not found: $id")
    end

    # Delete swarm
    SQLite.execute(db, "DELETE FROM swarms WHERE id = ?", [id])

    @info "Deleted swarm: $id"

    return Dict("success" => true, "id" => id)
end

# Add agent to swarm
function add_agent_to_swarm(db, swarm_id, agent_id)
    # Check if swarm exists
    swarm = get_swarm(db, swarm_id)
    if swarm === nothing
        error("Swarm not found: $swarm_id")
    end

    # Check if agent exists
    agent = get_agent(db, agent_id)
    if agent === nothing
        error("Agent not found: $agent_id")
    end

    # Add agent to swarm
    SQLite.execute(db, """
        INSERT OR REPLACE INTO swarm_agents (swarm_id, agent_id, added_at)
        VALUES (?, ?, ?)
    """, [swarm_id, agent_id, string(now())])

    # Update agent count in swarm
    agent_count = SQLite.DBInterface.execute(db, """
        SELECT COUNT(*) as count FROM swarm_agents WHERE swarm_id = ?
    """, [swarm_id]) |> DataFrame

    update_swarm(db, swarm_id, Dict("agent_count" => agent_count[1, :count]))

    @info "Added agent $agent_id to swarm $swarm_id"

    return Dict("success" => true)
end

# Remove agent from swarm
function remove_agent_from_swarm(db, swarm_id, agent_id)
    # Delete association
    SQLite.execute(db, """
        DELETE FROM swarm_agents
        WHERE swarm_id = ? AND agent_id = ?
    """, [swarm_id, agent_id])

    # Update agent count in swarm
    agent_count = SQLite.DBInterface.execute(db, """
        SELECT COUNT(*) as count FROM swarm_agents WHERE swarm_id = ?
    """, [swarm_id]) |> DataFrame

    update_swarm(db, swarm_id, Dict("agent_count" => agent_count[1, :count]))

    @info "Removed agent $agent_id from swarm $swarm_id"

    return Dict("success" => true)
end

# Get agents in swarm
function get_swarm_agents(db, swarm_id)
    result = SQLite.DBInterface.execute(db, """
        SELECT a.* FROM agents a
        JOIN swarm_agents sa ON a.id = sa.agent_id
        WHERE sa.swarm_id = ?
    """, [swarm_id]) |> DataFrame

    agents = []
    for row in eachrow(result)
        agent = Dict(pairs(row))
        if haskey(agent, :config) && agent[:config] !== nothing
            try
                agent[:config] = JSON.parse(agent[:config])
            catch e
                @warn "Failed to parse agent config: $e"
            end
        end
        push!(agents, agent)
    end

    return agents
end

# =====================
# API Keys Operations
# =====================

# Add API key
function add_api_key(db, service, api_key)
    id = string(hash(string(service, api_key, now())), base=16)

    SQLite.execute(db, """
        INSERT INTO api_keys (id, service, api_key, created_at)
        VALUES (?, ?, ?, ?)
    """, [id, service, api_key, string(now())])

    @info "Added API key for service: $service"

    return Dict("id" => id, "service" => service)
end

# List API keys (returns service and validity but not the actual keys)
function list_api_keys(db)
    result = SQLite.DBInterface.execute(db, """
        SELECT id, service, is_valid, last_used, created_at
        FROM api_keys
    """) |> DataFrame

    return [Dict(pairs(row)) for row in eachrow(result)]
end

# Update API key
function update_api_key(db, id, api_key)
    SQLite.execute(db, """
        UPDATE api_keys
        SET api_key = ?, is_valid = 1
        WHERE id = ?
    """, [api_key, id])

    @info "Updated API key: $id"

    return Dict("success" => true, "id" => id)
end

# Delete API key
function delete_api_key(db, id)
    SQLite.execute(db, "DELETE FROM api_keys WHERE id = ?", [id])

    @info "Deleted API key: $id"

    return Dict("success" => true, "id" => id)
end

# Get API key by service (internal use only)
function get_api_key(db, service)
    result = SQLite.DBInterface.execute(db, """
        SELECT * FROM api_keys
        WHERE service = ? AND is_valid = 1
        ORDER BY created_at DESC
        LIMIT 1
    """, [service]) |> DataFrame

    if size(result, 1) == 0
        return nothing
    end

    # Mark as used
    SQLite.execute(db, """
        UPDATE api_keys
        SET last_used = ?
        WHERE id = ?
    """, [string(now()), result[1, :id]])

    return Dict(pairs(result[1, :]))
end

# =====================
# Settings Operations
# =====================

# Save setting
function save_setting(db, key, value)
    value_str = typeof(value) <: AbstractString ? value : JSON.json(value)

    SQLite.execute(db, """
        INSERT OR REPLACE INTO settings (key, value, updated_at)
        VALUES (?, ?, ?)
    """, [key, value_str, string(now())])

    return Dict("success" => true, "key" => key)
end

# Get setting
function get_setting(db, key, default_value=nothing)
    result = SQLite.DBInterface.execute(db, """
        SELECT value FROM settings WHERE key = ?
    """, [key]) |> DataFrame

    if size(result, 1) == 0
        return default_value
    end

    value = result[1, :value]

    # Try to parse as JSON if it looks like a JSON object or array
    if startswith(value, "{") || startswith(value, "[")
        try
            return JSON.parse(value)
        catch
            return value
        end
    end

    return value
end

# List all settings
function list_settings(db)
    result = SQLite.DBInterface.execute(db, "SELECT * FROM settings") |> DataFrame

    settings = []
    for row in eachrow(result)
        setting = Dict(pairs(row))

        # Try to parse value as JSON if it looks like a JSON object or array
        if haskey(setting, :value) && setting[:value] !== nothing &&
           (startswith(setting[:value], "{") || startswith(setting[:value], "["))
            try
                setting[:value] = JSON.parse(setting[:value])
            catch e
                @warn "Failed to parse setting value: $e"
            end
        end

        push!(settings, setting)
    end

    return settings
end

# =====================
# Transaction Operations
# =====================

# Record a new transaction
function record_transaction(db, chain, tx_hash, from_address, to_address, amount, token, status="Pending")
    id = string(hash(string(chain, tx_hash, from_address, to_address, now())), base=16)

    SQLite.execute(db, """
        INSERT INTO transactions (id, chain, tx_hash, from_address, to_address, amount, token, status, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, [id, chain, tx_hash, from_address, to_address, amount, token, status, string(now())])

    @info "Recorded transaction: $id on $chain"

    return Dict("id" => id, "tx_hash" => tx_hash, "status" => status)
end

# Update transaction status
function update_transaction_status(db, id, status)
    # If status is Confirmed, also set confirmed_at timestamp
    if status == "Confirmed"
        SQLite.execute(db, """
            UPDATE transactions
            SET status = ?, confirmed_at = ?
            WHERE id = ?
        """, [status, string(now()), id])
    else
        SQLite.execute(db, """
            UPDATE transactions
            SET status = ?
            WHERE id = ?
        """, [status, id])
    end

    @info "Updated transaction $id status to $status"

    return Dict("success" => true, "id" => id, "status" => status)
end

# Get transaction by ID
function get_transaction(db, id)
    result = SQLite.DBInterface.execute(db, """
        SELECT * FROM transactions WHERE id = ?
    """, [id]) |> DataFrame

    if size(result, 1) == 0
        return nothing
    end

    return Dict(pairs(result[1, :]))
end

# List transactions (with optional filters)
function list_transactions(db; chain=nothing, status=nothing, address=nothing, limit=50)
    query = "SELECT * FROM transactions"
    conditions = []
    values = []

    if chain !== nothing
        push!(conditions, "chain = ?")
        push!(values, chain)
    end

    if status !== nothing
        push!(conditions, "status = ?")
        push!(values, status)
    end

    if address !== nothing
        push!(conditions, "(from_address = ? OR to_address = ?)")
        push!(values, address)
        push!(values, address)
    end

    if !isempty(conditions)
        query *= " WHERE " * join(conditions, " AND ")
    end

    query *= " ORDER BY created_at DESC LIMIT ?"
    push!(values, limit)

    result = SQLite.DBInterface.execute(db, query, values) |> DataFrame

    return [Dict(pairs(row)) for row in eachrow(result)]
end

# =====================
# Database Maintenance
# =====================

# Backup database
function backup_database(db, backup_path=nothing)
    if backup_path === nothing
        # Generate backup filename with timestamp
        timestamp = Dates.format(now(), "yyyymmdd_HHMMSS")
        backup_path = joinpath(dirname(DB_PATH), "backup_$(timestamp).sqlite")
    end

    # Create a backup copy
    try
        cp(DB_PATH, backup_path, force=true)
        @info "Database backed up to $backup_path"
        return Dict("success" => true, "backup_path" => backup_path)
    catch e
        @error "Failed to backup database: $e"
        error("Failed to backup database: $e")
    end
end

# Vacuum database to reclaim space
function vacuum_database(db)
    try
        SQLite.execute(db, "VACUUM")
        @info "Database vacuumed successfully"
        return Dict("success" => true)
    catch e
        @error "Failed to vacuum database: $e"
        error("Failed to vacuum database: $e")
    end
end

# Initialize a connection to the database
const DB = init_db()

# =====================
# Arweave Storage Functions
# =====================

# Configure Arweave storage
function configure_arweave(gateway=nothing, port=nothing, protocol=nothing, timeout=nothing, logging=nothing, wallet=nothing)
    return ArweaveStorage.configure(gateway, port, protocol, timeout, logging, wallet)
end

# Get Arweave network info
function get_arweave_network_info()
    return ArweaveStorage.get_network_info()
end

# Get Arweave wallet info
function get_arweave_wallet_info()
    return ArweaveStorage.get_wallet_info()
end

# Store agent in Arweave
function store_agent_in_arweave(agent_data, tags=Dict())
    return ArweaveStorage.store_agent(agent_data, tags)
end

# Retrieve agent from Arweave
function retrieve_agent_from_arweave(tx_id)
    return ArweaveStorage.retrieve_agent(tx_id)
end

# Search for agents in Arweave
function search_agents_in_arweave(tags)
    return ArweaveStorage.search_agents(tags)
end

# Store swarm in Arweave
function store_swarm_in_arweave(swarm_data, tags=Dict())
    return ArweaveStorage.store_swarm(swarm_data, tags)
end

# Retrieve swarm from Arweave
function retrieve_swarm_from_arweave(tx_id)
    return ArweaveStorage.retrieve_swarm(tx_id)
end

# Search for swarms in Arweave
function search_swarms_in_arweave(tags)
    return ArweaveStorage.search_swarms(tags)
end

# Store data in Arweave
function store_data_in_arweave(data, tags=Dict(), content_type="application/json")
    return ArweaveStorage.store_data(data, tags, content_type)
end

# Retrieve data from Arweave
function retrieve_data_from_arweave(tx_id)
    return ArweaveStorage.retrieve_data(tx_id)
end

# Get transaction status from Arweave
function get_arweave_transaction_status(tx_id)
    return ArweaveStorage.get_transaction_status(tx_id)
end

# =====================
# Document Storage Functions for LangChain Integration
# =====================

# Add documents to storage
function add_documents(storage_type, collection_name, documents)
    return DocumentStorage.add_documents(DB, storage_type, collection_name, documents)
end

# Add vector documents to storage
function add_vector_documents(storage_type, collection_name, documents)
    return DocumentStorage.add_vector_documents(DB, storage_type, collection_name, documents)
end

# Search documents by text query
function search_documents(storage_type, collection_name, query, params=Dict())
    return DocumentStorage.search_documents(DB, storage_type, collection_name, query, params)
end

# Search vector documents by embedding
function search_vector_documents(storage_type, collection_name, query_embedding, params=Dict())
    return DocumentStorage.search_vector_documents(DB, storage_type, collection_name, query_embedding, params)
end

# Delete documents
function delete_documents(storage_type, collection_name, document_ids)
    return DocumentStorage.delete_documents(DB, storage_type, collection_name, document_ids)
end

# Get a document by ID
function get_document(storage_type, collection_name, document_id)
    return DocumentStorage.get_document(DB, storage_type, collection_name, document_id)
end

# List documents in a collection
function list_documents(storage_type, collection_name, limit=100, offset=0)
    return DocumentStorage.list_documents(DB, storage_type, collection_name, limit, offset)
end

# List all collections
function list_collections(storage_type)
    return DocumentStorage.list_collections(DB, storage_type)
end

end # module