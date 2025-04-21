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
    else
        return Dict("success" => false, "error" => "Unknown storage command: $command")
    end
end