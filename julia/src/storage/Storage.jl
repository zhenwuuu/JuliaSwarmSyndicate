module Storage

export initialize, save, load, delete, list, search
export StorageProvider, LocalStorageProvider, ArweaveStorageProvider, DocumentStorageProvider
export get_default_provider, set_default_provider

using Dates
using JSON

# Include storage interface and implementations
include("storage_interface.jl")
include("local_storage.jl")
include("arweave_storage.jl")
include("document_storage.jl")

# Import storage modules
using .StorageInterface
using .LocalStorage
using .ArweaveStorage
using .DocumentStorage

# Global state
const DEFAULT_PROVIDER = Ref{Union{StorageInterface.StorageProvider, Nothing}}(nothing)
const INITIALIZED = Ref(false)

"""
    initialize(; provider_type::Symbol=:local, config::Dict{String, Any}=Dict{String, Any}())

Initialize the storage system with the specified provider type and configuration.
"""
function initialize(; provider_type::Symbol=:local, config::Dict{String, Any}=Dict{String, Any}())
    try
        if INITIALIZED[]
            @warn "Storage system already initialized"
            return true
        end

        # Create and initialize the provider based on the type
        provider = if provider_type == :local
            # Get configuration for local storage
            db_path = get(config, "db_path", joinpath(homedir(), ".juliaos", "storage.sqlite"))
            encryption_key = get(config, "encryption_key", nothing)
            compression_enabled = get(config, "compression_enabled", true)

            # Create and initialize local storage provider
            local_provider = LocalStorage.LocalStorageProvider(
                db_path;
                encryption_key=encryption_key,
                compression_enabled=compression_enabled
            )

            LocalStorage.initialize(local_provider)
        elseif provider_type == :arweave
            # Get configuration for Arweave storage
            api_url = get(config, "api_url", "https://arweave.net")
            api_key = get(config, "api_key", nothing)
            wallet_key_file = get(config, "wallet_key_file", nothing)
            cache_enabled = get(config, "cache_enabled", true)
            cache_dir = get(config, "cache_dir", joinpath(homedir(), ".juliaos", "arweave_cache"))

            # Create and initialize Arweave storage provider
            arweave_provider = ArweaveStorage.ArweaveStorageProvider(
                api_url=api_url,
                api_key=api_key,
                wallet_key_file=wallet_key_file,
                cache_enabled=cache_enabled,
                cache_dir=cache_dir
            )

            ArweaveStorage.initialize(arweave_provider)
        elseif provider_type == :document
            # Get configuration for document storage
            base_provider_type = get(config, "base_provider_type", :local)
            base_provider_config = get(config, "base_provider_config", Dict{String, Any}())
            index_enabled = get(config, "index_enabled", true)
            search_enabled = get(config, "search_enabled", true)

            # Initialize the base provider
            base_provider = initialize(
                provider_type=base_provider_type,
                config=base_provider_config
            )

            # Create and initialize document storage provider
            document_provider = DocumentStorage.DocumentStorageProvider(
                base_provider,
                index_enabled=index_enabled,
                search_enabled=search_enabled
            )

            DocumentStorage.initialize(document_provider)
        else
            error("Unsupported storage provider type: $provider_type")
        end

        # Set the default provider
        DEFAULT_PROVIDER[] = provider
        INITIALIZED[] = true

        @info "Storage system initialized with provider type: $provider_type"
        return provider
    catch e
        @error "Error initializing storage system: $(string(e))"
        rethrow(e)
    end
end

"""
    get_default_provider()

Get the default storage provider.
"""
function get_default_provider()
    if !INITIALIZED[] || DEFAULT_PROVIDER[] === nothing
        error("Storage system not initialized")
    end

    return DEFAULT_PROVIDER[]
end

"""
    set_default_provider(provider::StorageInterface.StorageProvider)

Set the default storage provider.
"""
function set_default_provider(provider::StorageInterface.StorageProvider)
    DEFAULT_PROVIDER[] = provider
    INITIALIZED[] = true

    return provider
end

"""
    save(key::String, data::Any; metadata::Dict{String, Any}=Dict{String, Any}(), provider::Union{StorageInterface.StorageProvider, Nothing}=nothing)

Save data to storage.
"""
function save(key::String, data::Any; metadata::Dict{String, Any}=Dict{String, Any}(), provider::Union{StorageInterface.StorageProvider, Nothing}=nothing)
    # Use the specified provider or the default provider
    storage_provider = provider !== nothing ? provider : get_default_provider()

    # Save the data
    return StorageInterface.save(storage_provider, key, data, metadata=metadata)
end

"""
    load(key::String; provider::Union{StorageInterface.StorageProvider, Nothing}=nothing)

Load data from storage.
"""
function load(key::String; provider::Union{StorageInterface.StorageProvider, Nothing}=nothing)
    # Use the specified provider or the default provider
    storage_provider = provider !== nothing ? provider : get_default_provider()

    # Load the data
    return StorageInterface.load(storage_provider, key)
end

"""
    delete(key::String; provider::Union{StorageInterface.StorageProvider, Nothing}=nothing)

Delete data from storage.
"""
function delete(key::String; provider::Union{StorageInterface.StorageProvider, Nothing}=nothing)
    # Use the specified provider or the default provider
    storage_provider = provider !== nothing ? provider : get_default_provider()

    # Delete the data
    return StorageInterface.delete(storage_provider, key)
end

"""
    list(prefix::String=""; provider::Union{StorageInterface.StorageProvider, Nothing}=nothing)

List keys in storage.
"""
function list(prefix::String=""; provider::Union{StorageInterface.StorageProvider, Nothing}=nothing)
    # Use the specified provider or the default provider
    storage_provider = provider !== nothing ? provider : get_default_provider()

    # List the keys
    return StorageInterface.list(storage_provider, prefix)
end

"""
    search(query::String; limit::Int=10, offset::Int=0, provider::Union{DocumentStorageProvider, Nothing}=nothing)

Search for documents matching the query.
"""
function search(query::String; limit::Int=10, offset::Int=0, provider::Union{DocumentStorage.DocumentStorageProvider, Nothing}=nothing)
    # Check if the default provider is a document storage provider
    if provider === nothing
        default_provider = get_default_provider()
        if !(default_provider isa DocumentStorage.DocumentStorageProvider)
            error("Default provider is not a document storage provider")
        end
        provider = default_provider
    end

    # Search for documents
    return DocumentStorage.search(provider, query, limit=limit, offset=offset)
end

end # module Storage
