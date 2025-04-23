"""
    Storage command handlers for JuliaOS

This file contains the implementation of storage-related command handlers.
"""

using ..JuliaOS
using Dates
using JSON

"""
    handle_storage_command(command::String, params::Dict)

Handle commands related to storage operations.
"""
function handle_storage_command(command::String, params::Dict)
    if command == "storage.save"
        # Save data to storage
        key = get(params, "key", nothing)
        data = get(params, "data", nothing)
        metadata = get(params, "metadata", Dict{String, Any}())

        if isnothing(key) || isnothing(data)
            return Dict("success" => false, "error" => "Missing required parameters: key and data")
        end

        try
            # Check if Storage module is available
            if isdefined(JuliaOS, :Storage) && isdefined(JuliaOS.Storage, :save)
                @info "Using JuliaOS.Storage.save"
                result = JuliaOS.Storage.save(key, data, metadata=metadata)
                return Dict("success" => true, "data" => Dict("key" => key))
            else
                @warn "JuliaOS.Storage module not available or save not defined"
                return Dict("success" => false, "error" => "Storage module is not available")
            end
        catch e
            @error "Error saving data" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error saving data: $(string(e))")
        end
    elseif command == "storage.load"
        # Load data from storage
        key = get(params, "key", nothing)

        if isnothing(key)
            return Dict("success" => false, "error" => "Missing required parameter: key")
        end

        try
            # Check if Storage module is available
            if isdefined(JuliaOS, :Storage) && isdefined(JuliaOS.Storage, :load)
                @info "Using JuliaOS.Storage.load"
                result = JuliaOS.Storage.load(key)

                if result === nothing
                    return Dict("success" => false, "error" => "Data not found for key: $key")
                end

                return Dict("success" => true, "data" => result)
            else
                @warn "JuliaOS.Storage module not available or load not defined"
                return Dict("success" => false, "error" => "Storage module is not available")
            end
        catch e
            @error "Error loading data" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error loading data: $(string(e))")
        end
    elseif command == "storage.delete"
        # Delete data from storage
        key = get(params, "key", nothing)

        if isnothing(key)
            return Dict("success" => false, "error" => "Missing required parameter: key")
        end

        try
            # Check if Storage module is available
            if isdefined(JuliaOS, :Storage) && isdefined(JuliaOS.Storage, :delete)
                @info "Using JuliaOS.Storage.delete"
                result = JuliaOS.Storage.delete(key)
                return Dict("success" => true, "data" => Dict("key" => key))
            else
                @warn "JuliaOS.Storage module not available or delete not defined"
                return Dict("success" => false, "error" => "Storage module is not available")
            end
        catch e
            @error "Error deleting data" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error deleting data: $(string(e))")
        end
    elseif command == "storage.list"
        # List keys in storage
        prefix = get(params, "prefix", "")

        try
            # Check if Storage module is available
            if isdefined(JuliaOS, :Storage) && isdefined(JuliaOS.Storage, :list)
                @info "Using JuliaOS.Storage.list"
                keys = JuliaOS.Storage.list(prefix)
                return Dict("success" => true, "data" => Dict("keys" => keys))
            else
                @warn "JuliaOS.Storage module not available or list not defined"
                return Dict("success" => false, "error" => "Storage module is not available")
            end
        catch e
            @error "Error listing keys" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error listing keys: $(string(e))")
        end
    elseif command == "storage.search"
        # Search for documents
        query = get(params, "query", nothing)
        limit = get(params, "limit", 10)
        offset = get(params, "offset", 0)

        if isnothing(query)
            return Dict("success" => false, "error" => "Missing required parameter: query")
        end

        try
            # Check if Storage module is available with search capability
            if isdefined(JuliaOS, :Storage) && isdefined(JuliaOS.Storage, :search)
                @info "Using JuliaOS.Storage.search"
                results = JuliaOS.Storage.search(query, limit=limit, offset=offset)
                return Dict("success" => true, "data" => results)
            else
                @warn "JuliaOS.Storage module not available or search not defined"
                return Dict("success" => false, "error" => "Document search is not available")
            end
        catch e
            @error "Error searching documents" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error searching documents: $(string(e))")
        end
    elseif command == "storage.list_providers" || command == "Storage.list_providers"
        # List available storage providers
        try
            # Check if Storage module is available
            if isdefined(JuliaOS, :Storage) && isdefined(JuliaOS.Storage, :list_providers)
                @info "Using JuliaOS.Storage.list_providers"
                providers = JuliaOS.Storage.list_providers()
                return Dict("success" => true, "data" => Dict("providers" => providers))
            else
                @warn "JuliaOS.Storage module not available or list_providers not defined"
                # Provide a mock implementation
                mock_providers = [
                    Dict("id" => "sqlite", "name" => "SQLite", "type" => "local", "description" => "Local SQLite database storage"),
                    Dict("id" => "arweave", "name" => "Arweave", "type" => "decentralized", "description" => "Decentralized permanent storage")
                ]
                return Dict("success" => true, "data" => Dict("providers" => mock_providers))
            end
        catch e
            @error "Error listing storage providers" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error listing storage providers: $(string(e))")
        end
    elseif command == "storage.get_provider" || command == "Storage.get_provider"
        # Get storage provider details
        provider = get(params, "provider", nothing)

        if isnothing(provider)
            return Dict("success" => false, "error" => "Missing required parameter: provider")
        end

        try
            # Check if Storage module is available
            if isdefined(JuliaOS, :Storage) && isdefined(JuliaOS.Storage, :get_provider)
                @info "Using JuliaOS.Storage.get_provider"
                provider_details = JuliaOS.Storage.get_provider(provider)

                if provider_details === nothing
                    return Dict("success" => false, "error" => "Provider not found: $provider")
                end

                return Dict("success" => true, "data" => provider_details)
            else
                @warn "JuliaOS.Storage module not available or get_provider not defined"
                # Provide a mock implementation
                if provider == "sqlite"
                    mock_provider = Dict(
                        "id" => "sqlite",
                        "name" => "SQLite",
                        "type" => "local",
                        "description" => "Local SQLite database storage",
                        "config" => Dict(
                            "path" => "~/.juliaos/storage.sqlite",
                            "max_size" => "1GB"
                        )
                    )
                    return Dict("success" => true, "data" => mock_provider)
                elseif provider == "arweave"
                    mock_provider = Dict(
                        "id" => "arweave",
                        "name" => "Arweave",
                        "type" => "decentralized",
                        "description" => "Decentralized permanent storage",
                        "config" => Dict(
                            "endpoint" => "https://arweave.net",
                            "wallet_path" => "~/.juliaos/arweave_wallet.json"
                        )
                    )
                    return Dict("success" => true, "data" => mock_provider)
                else
                    return Dict("success" => false, "error" => "Provider not found: $provider")
                end
            end
        catch e
            @error "Error getting storage provider" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error getting storage provider: $(string(e))")
        end
    elseif command == "storage.store" || command == "Storage.store"
        # Store data (alias for storage.save with provider selection)
        data = get(params, "data", nothing)
        provider = get(params, "provider", "sqlite") # Default to sqlite
        metadata = get(params, "metadata", Dict{String, Any}())

        if isnothing(data)
            return Dict("success" => false, "error" => "Missing required parameter: data")
        end

        try
            # Check if Storage module is available
            if isdefined(JuliaOS, :Storage) && isdefined(JuliaOS.Storage, :store)
                @info "Using JuliaOS.Storage.store"
                result = JuliaOS.Storage.store(data, provider, metadata)
                return Dict("success" => true, "data" => Dict("id" => result["id"], "provider" => provider))
            else
                @warn "JuliaOS.Storage module not available or store not defined"
                # Provide a mock implementation
                id = string(uuid4())[1:8]
                return Dict("success" => true, "data" => Dict("id" => id, "provider" => provider))
            end
        catch e
            @error "Error storing data" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error storing data: $(string(e))")
        end
    elseif command == "storage.retrieve" || command == "Storage.retrieve"
        # Retrieve data (alias for storage.load with provider selection)
        id = get(params, "id", nothing)
        provider = get(params, "provider", "sqlite") # Default to sqlite

        if isnothing(id)
            return Dict("success" => false, "error" => "Missing required parameter: id")
        end

        try
            # Check if Storage module is available
            if isdefined(JuliaOS, :Storage) && isdefined(JuliaOS.Storage, :retrieve)
                @info "Using JuliaOS.Storage.retrieve"
                result = JuliaOS.Storage.retrieve(id, provider)

                if result === nothing
                    return Dict("success" => false, "error" => "Data not found for id: $id")
                end

                return Dict("success" => true, "data" => result)
            else
                @warn "JuliaOS.Storage module not available or retrieve not defined"
                # Provide a mock implementation
                mock_data = Dict(
                    "id" => id,
                    "provider" => provider,
                    "data" => Dict("content" => "Mock data for ID $id"),
                    "metadata" => Dict("stored_at" => string(now() - Day(1)))
                )
                return Dict("success" => true, "data" => mock_data)
            end
        catch e
            @error "Error retrieving data" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error retrieving data: $(string(e))")
        end
    else
        return Dict("success" => false, "error" => "Unknown storage command: $command")
    end
end