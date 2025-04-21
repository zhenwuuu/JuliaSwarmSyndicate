module Cache

export initialize, set, get, delete, clear, has, set_ttl, stats
export CacheItem, CacheConfig, CacheType

using ..EnhancedErrors
using ..StructuredLogging
using ..EnhancedConfig
using ..Metrics

using Dates
using JSON
using Random
using DataStructures: OrderedDict

"""
    CacheType

Enum representing different types of caches.
"""
@enum CacheType begin
    MEMORY      # In-memory cache
    PERSISTENT  # Disk-based cache
    DISTRIBUTED # Distributed cache across nodes
end

"""
    CacheItem

Structure representing a cached item.
"""
struct CacheItem{T}
    key::String
    value::T
    created_at::DateTime
    expires_at::Union{DateTime, Nothing}
    metadata::Dict{String, Any}
    
    function CacheItem(key::String, value::T; 
                     ttl_seconds::Union{Int, Nothing}=nothing,
                     metadata::Dict{String, Any}=Dict{String, Any}()) where T
        created_at = now()
        expires_at = ttl_seconds === nothing ? nothing : created_at + Dates.Second(ttl_seconds)
        
        return new{T}(key, value, created_at, expires_at, metadata)
    end
end

"""
    CacheConfig

Configuration for the cache system.
"""
mutable struct CacheConfig
    enabled::Bool
    default_ttl_seconds::Union{Int, Nothing}
    max_items::Int
    eviction_policy::String  # "lru", "lfu", "fifo"
    namespaces::Set{String}
    cache_type::CacheType
    persistent_path::String
    distributed_servers::Vector{String}
    
    CacheConfig() = new(
        true,             # enabled
        3600,             # default_ttl_seconds (1 hour)
        10000,            # max_items
        "lru",            # eviction_policy
        Set{String}(),    # namespaces
        MEMORY,           # cache_type
        "cache",          # persistent_path
        String[]          # distributed_servers
    )
end

# Global state for cache system
mutable struct CacheState
    initialized::Bool
    config::CacheConfig
    memory_cache::Dict{String, Dict{String, CacheItem}}  # namespace -> key -> item
    hits::Dict{String, Int}  # key -> hit count
    misses::Dict{String, Int}  # key -> miss count
    last_cleanup::DateTime
    cleanup_task::Union{Task, Nothing}
    
    CacheState() = new(
        false,
        CacheConfig(),
        Dict{String, Dict{String, CacheItem}}(),
        Dict{String, Int}(),
        Dict{String, Int}(),
        now(),
        nothing
    )
end

# Singleton instance of cache state
const CACHE_STATE = CacheState()

"""
    initialize(config=nothing)

Initialize the cache system with the given configuration.
"""
function initialize(config=nothing)
    if CACHE_STATE.initialized
        return true
    end
    
    error_context = EnhancedErrors.with_error_context("Cache", "initialize")
    
    log_context = StructuredLogging.LogContext(
        component="Cache",
        operation="initialize"
    )
    
    # Execute with logging
    return StructuredLogging.with_context(log_context) do
        try
            # Configure the cache
            cache_config = CACHE_STATE.config
            
            # Use configuration if provided
            if config !== nothing
                if haskey(config, "enabled")
                    cache_config.enabled = config["enabled"]
                end
                
                if haskey(config, "default_ttl_seconds")
                    cache_config.default_ttl_seconds = config["default_ttl_seconds"]
                end
                
                if haskey(config, "max_items")
                    cache_config.max_items = config["max_items"]
                end
                
                if haskey(config, "eviction_policy")
                    cache_config.eviction_policy = config["eviction_policy"]
                end
                
                if haskey(config, "namespaces") && config["namespaces"] isa Vector
                    cache_config.namespaces = Set(config["namespaces"])
                end
                
                if haskey(config, "cache_type")
                    cache_config.cache_type = parse_cache_type(config["cache_type"])
                end
                
                if haskey(config, "persistent_path")
                    cache_config.persistent_path = config["persistent_path"]
                end
                
                if haskey(config, "distributed_servers") && config["distributed_servers"] isa Vector
                    cache_config.distributed_servers = config["distributed_servers"]
                end
            else
                # Try to load from EnhancedConfig
                try
                    if EnhancedConfig.has_key("cache.enabled")
                        cache_config.enabled = EnhancedConfig.get_value("cache.enabled", true)
                    end
                    
                    if EnhancedConfig.has_key("cache.default_ttl_seconds")
                        cache_config.default_ttl_seconds = EnhancedConfig.get_value("cache.default_ttl_seconds", 3600)
                    end
                    
                    if EnhancedConfig.has_key("cache.max_items")
                        cache_config.max_items = EnhancedConfig.get_value("cache.max_items", 10000)
                    end
                    
                    if EnhancedConfig.has_key("cache.eviction_policy")
                        cache_config.eviction_policy = EnhancedConfig.get_value("cache.eviction_policy", "lru")
                    end
                    
                    if EnhancedConfig.has_key("cache.namespaces")
                        namespaces = EnhancedConfig.get_value("cache.namespaces", String[])
                        if namespaces isa Vector
                            cache_config.namespaces = Set(namespaces)
                        end
                    end
                    
                    if EnhancedConfig.has_key("cache.cache_type")
                        cache_config.cache_type = parse_cache_type(
                            EnhancedConfig.get_value("cache.cache_type", "MEMORY")
                        )
                    end
                    
                    if EnhancedConfig.has_key("cache.persistent_path")
                        cache_config.persistent_path = EnhancedConfig.get_value("cache.persistent_path", "cache")
                    end
                    
                    if EnhancedConfig.has_key("cache.distributed_servers")
                        distributed_servers = EnhancedConfig.get_value("cache.distributed_servers", String[])
                        if distributed_servers isa Vector
                            cache_config.distributed_servers = distributed_servers
                        end
                    end
                catch e
                    StructuredLogging.warn("Failed to load cache configuration from EnhancedConfig",
                                          exception=e)
                end
            end
            
            # Initialize default namespaces if none provided
            if isempty(cache_config.namespaces)
                push!(cache_config.namespaces, "default")
                push!(cache_config.namespaces, "blockchain")
                push!(cache_config.namespaces, "dex")
                push!(cache_config.namespaces, "api")
            end
            
            # Initialize cache storage for each namespace
            for namespace in cache_config.namespaces
                CACHE_STATE.memory_cache[namespace] = Dict{String, CacheItem}()
            end
            
            # Initialize persistent cache if needed
            if cache_config.cache_type == PERSISTENT
                if !isdir(cache_config.persistent_path)
                    mkpath(cache_config.persistent_path)
                end
                
                # Load existing cache from disk if available
                load_persistent_cache()
            end
            
            # Initialize distributed cache if needed
            if cache_config.cache_type == DISTRIBUTED
                # This would involve setting up connections to distributed cache servers
                # For now, we'll just log a message
                StructuredLogging.warn("Distributed cache not fully implemented",
                                      data=Dict("servers" => cache_config.distributed_servers))
            end
            
            # Start cleanup task
            if cache_config.enabled
                CACHE_STATE.cleanup_task = @async cleanup_task()
            end
            
            # Register metrics
            register_cache_metrics()
            
            # Set initialized flag
            CACHE_STATE.initialized = true
            
            StructuredLogging.info("Cache system initialized",
                                  data=Dict(
                                      "enabled" => cache_config.enabled,
                                      "type" => string(cache_config.cache_type),
                                      "namespaces" => collect(cache_config.namespaces)
                                  ))
            
            return true
        catch e
            StructuredLogging.error("Failed to initialize cache system",
                                   exception=e)
            
            EnhancedErrors.try_operation(error_context) do
                throw(EnhancedErrors.InternalError("Failed to initialize cache system",
                                                  e, context=error_context))
            end
            
            return false
        end
    end
end

"""
    parse_cache_type(type_str)

Parse a cache type string into a CacheType enum value.
"""
function parse_cache_type(type_str)
    upper_type = uppercase(string(type_str))
    
    if upper_type == "MEMORY"
        return MEMORY
    elseif upper_type == "PERSISTENT"
        return PERSISTENT
    elseif upper_type == "DISTRIBUTED"
        return DISTRIBUTED
    else
        StructuredLogging.warn("Unknown cache type: $type_str, using MEMORY")
        return MEMORY
    end
end

"""
    register_cache_metrics()

Register metrics for the cache system.
"""
function register_cache_metrics()
    # Register metrics using the Metrics module
    Metrics.register_metric("cache_hits_total", Metrics.COUNTER, 
                          "Total number of cache hits", 
                          labels=["namespace"])
    
    Metrics.register_metric("cache_misses_total", Metrics.COUNTER, 
                           "Total number of cache misses", 
                           labels=["namespace"])
    
    Metrics.register_metric("cache_items", Metrics.GAUGE, 
                          "Current number of items in cache", 
                          labels=["namespace"])
    
    Metrics.register_metric("cache_memory_bytes", Metrics.GAUGE, 
                           "Approximate memory usage of cache in bytes", 
                           labels=["namespace"])
    
    Metrics.register_metric("cache_evictions_total", Metrics.COUNTER, 
                           "Total number of cache evictions", 
                           labels=["namespace", "reason"])
    
    Metrics.register_metric("cache_cleanup_seconds", Metrics.HISTOGRAM, 
                           "Time taken for cache cleanup operations", 
                           buckets=[0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0])
end

"""
    cleanup_task()

Background task for cleaning up expired cache items.
"""
function cleanup_task()
    log_context = StructuredLogging.LogContext(
        component="Cache",
        operation="cleanup_task"
    )
    
    StructuredLogging.with_context(log_context) do
        try
            # Run cleanup loop
            while CACHE_STATE.initialized && CACHE_STATE.config.enabled
                try
                    # Run cleanup
                    cleanup_cache()
                    
                    # If persistent cache, save to disk
                    if CACHE_STATE.config.cache_type == PERSISTENT
                        save_persistent_cache()
                    end
                catch e
                    StructuredLogging.error("Error during cache cleanup",
                                           exception=e)
                end
                
                # Sleep for a bit (clean up every 60 seconds)
                sleep(60)
            end
        catch e
            StructuredLogging.error("Cache cleanup task failed",
                                   exception=e)
        end
    end
end

"""
    cleanup_cache()

Clean up expired cache items and enforce size limits.
"""
function cleanup_cache()
    if !CACHE_STATE.initialized || !CACHE_STATE.config.enabled
        return
    end
    
    start_time = time()
    
    # Track evictions for metrics
    evictions = Dict{String, Dict{String, Int}}()
    
    # Initialize eviction counters
    for namespace in CACHE_STATE.config.namespaces
        evictions[namespace] = Dict("expired" => 0, "size_limit" => 0)
    end
    
    # Clean up expired items
    for (namespace, cache) in CACHE_STATE.memory_cache
        # Find expired items
        expired_keys = String[]
        for (key, item) in cache
            if item.expires_at !== nothing && now() > item.expires_at
                push!(expired_keys, key)
            end
        end
        
        # Remove expired items
        for key in expired_keys
            delete!(cache, key)
            evictions[namespace]["expired"] += 1
        end
        
        # Enforce size limits if needed
        enforce_size_limit(namespace, cache, evictions)
    end
    
    # Record cleanup time
    cleanup_time = time() - start_time
    Metrics.record_metric("cache_cleanup_seconds", cleanup_time)
    
    # Record evictions
    for (namespace, reasons) in evictions
        for (reason, count) in reasons
            if count > 0
                Metrics.record_metric("cache_evictions_total", count, 
                                     labels=Dict(
                                         "namespace" => namespace,
                                         "reason" => reason
                                     ))
            end
        end
    end
    
    # Update last cleanup time
    CACHE_STATE.last_cleanup = now()
    
    return evictions
end

"""
    enforce_size_limit(namespace, cache, evictions)

Enforce size limits on a cache namespace.
"""
function enforce_size_limit(namespace, cache, evictions)
    max_items = CACHE_STATE.config.max_items
    eviction_policy = CACHE_STATE.config.eviction_policy
    
    # Check if we need to evict items
    if length(cache) <= max_items
        return
    end
    
    # Number of items to evict
    to_evict = length(cache) - max_items
    
    if eviction_policy == "lru"
        # Evict least recently used items
        # Sort by created_at/accessed_at (we'd need to update accessed_at on gets)
        items = collect(values(cache))
        sort!(items, by = item -> item.created_at)
        
        # Evict oldest items
        for i in 1:min(to_evict, length(items))
            delete!(cache, items[i].key)
            evictions[namespace]["size_limit"] += 1
        end
    elseif eviction_policy == "lfu"
        # Evict least frequently used items
        # We need to track hit counts for this
        items = collect(pairs(cache))
        sort!(items, by = pair -> get(CACHE_STATE.hits, "$(namespace):$(pair[1])", 0))
        
        # Evict least frequently used items
        for i in 1:min(to_evict, length(items))
            delete!(cache, items[i][1])
            evictions[namespace]["size_limit"] += 1
        end
    elseif eviction_policy == "fifo"
        # Evict in first-in, first-out order
        items = collect(values(cache))
        sort!(items, by = item -> item.created_at)
        
        # Evict oldest items
        for i in 1:min(to_evict, length(items))
            delete!(cache, items[i].key)
            evictions[namespace]["size_limit"] += 1
        end
    else
        # Random eviction as fallback
        keys_to_evict = collect(keys(cache))
        shuffle!(keys_to_evict)
        
        for i in 1:min(to_evict, length(keys_to_evict))
            delete!(cache, keys_to_evict[i])
            evictions[namespace]["size_limit"] += 1
        end
    end
end

"""
    set(key::String, value; namespace::String="default", ttl_seconds=nothing, metadata=Dict())

Set a value in the cache.
"""
function set(key::String, value; 
            namespace::String="default", 
            ttl_seconds::Union{Int, Nothing}=nothing, 
            metadata::Dict{String, Any}=Dict{String, Any}())
    if !CACHE_STATE.initialized
        initialize()
    end
    
    if !CACHE_STATE.config.enabled
        return value
    end
    
    # Use default TTL if not specified
    if ttl_seconds === nothing
        ttl_seconds = CACHE_STATE.config.default_ttl_seconds
    end
    
    # Ensure namespace exists
    if !haskey(CACHE_STATE.memory_cache, namespace)
        CACHE_STATE.memory_cache[namespace] = Dict{String, CacheItem}()
        push!(CACHE_STATE.config.namespaces, namespace)
    end
    
    # Create cache item
    item = CacheItem(key, value, ttl_seconds=ttl_seconds, metadata=metadata)
    
    # Store in memory cache
    CACHE_STATE.memory_cache[namespace][key] = item
    
    # If using persistent cache, save to disk
    if CACHE_STATE.config.cache_type == PERSISTENT
        # We don't want to save the entire cache on every set, so we'll just
        # save this specific item
        save_persistent_item(namespace, key, item)
    end
    
    # If using distributed cache, propagate to other servers
    if CACHE_STATE.config.cache_type == DISTRIBUTED
        # This would involve sending the item to other cache servers
        # For now, we'll just log a message
        StructuredLogging.debug("Distributed cache set not fully implemented",
                               data=Dict("namespace" => namespace, "key" => key))
    end
    
    # Update metrics
    Metrics.record_metric("cache_items", length(CACHE_STATE.memory_cache[namespace]), 
                         labels=Dict("namespace" => namespace))
    
    # Return the value for convenience
    return value
end

"""
    get(key::String; namespace::String="default", default=nothing)

Get a value from the cache.
"""
function get(key::String; namespace::String="default", default=nothing)
    if !CACHE_STATE.initialized
        initialize()
    end
    
    if !CACHE_STATE.config.enabled
        return default
    end
    
    # Check if namespace exists
    if !haskey(CACHE_STATE.memory_cache, namespace)
        # Record cache miss
        record_miss(namespace, key)
        return default
    end
    
    # Check if key exists
    if !haskey(CACHE_STATE.memory_cache[namespace], key)
        # Record cache miss
        record_miss(namespace, key)
        return default
    end
    
    # Get item
    item = CACHE_STATE.memory_cache[namespace][key]
    
    # Check if expired
    if item.expires_at !== nothing && now() > item.expires_at
        # Remove expired item
        delete!(CACHE_STATE.memory_cache[namespace], key)
        
        # Record cache miss
        record_miss(namespace, key)
        
        # Record eviction
        Metrics.record_metric("cache_evictions_total", 1, 
                             labels=Dict(
                                 "namespace" => namespace,
                                 "reason" => "expired"
                             ))
        
        return default
    end
    
    # Record cache hit
    record_hit(namespace, key)
    
    # Return value
    return item.value
end

"""
    has(key::String; namespace::String="default")

Check if a key exists in the cache and is not expired.
"""
function has(key::String; namespace::String="default")
    if !CACHE_STATE.initialized
        initialize()
    end
    
    if !CACHE_STATE.config.enabled
        return false
    end
    
    # Check if namespace exists
    if !haskey(CACHE_STATE.memory_cache, namespace)
        return false
    end
    
    # Check if key exists
    if !haskey(CACHE_STATE.memory_cache[namespace], key)
        return false
    end
    
    # Get item
    item = CACHE_STATE.memory_cache[namespace][key]
    
    # Check if expired
    if item.expires_at !== nothing && now() > item.expires_at
        return false
    end
    
    return true
end

"""
    delete(key::String; namespace::String="default")

Delete a key from the cache.
"""
function delete(key::String; namespace::String="default")
    if !CACHE_STATE.initialized
        initialize()
    end
    
    if !CACHE_STATE.config.enabled
        return false
    end
    
    # Check if namespace exists
    if !haskey(CACHE_STATE.memory_cache, namespace)
        return false
    end
    
    # Check if key exists
    if !haskey(CACHE_STATE.memory_cache[namespace], key)
        return false
    end
    
    # Delete from memory cache
    delete!(CACHE_STATE.memory_cache[namespace], key)
    
    # If using persistent cache, remove from disk
    if CACHE_STATE.config.cache_type == PERSISTENT
        delete_persistent_item(namespace, key)
    end
    
    # If using distributed cache, propagate delete to other servers
    if CACHE_STATE.config.cache_type == DISTRIBUTED
        # This would involve sending the delete to other cache servers
        # For now, we'll just log a message
        StructuredLogging.debug("Distributed cache delete not fully implemented",
                               data=Dict("namespace" => namespace, "key" => key))
    end
    
    # Update metrics
    Metrics.record_metric("cache_items", length(CACHE_STATE.memory_cache[namespace]), 
                         labels=Dict("namespace" => namespace))
    
    return true
end

"""
    clear(; namespace::String="default")

Clear all keys in a namespace.
"""
function clear(; namespace::String="default")
    if !CACHE_STATE.initialized
        initialize()
    end
    
    if !CACHE_STATE.config.enabled
        return false
    end
    
    # Check if namespace exists
    if !haskey(CACHE_STATE.memory_cache, namespace)
        return false
    end
    
    # Count items for metrics
    items_count = length(CACHE_STATE.memory_cache[namespace])
    
    # Clear memory cache
    empty!(CACHE_STATE.memory_cache[namespace])
    
    # If using persistent cache, clear from disk
    if CACHE_STATE.config.cache_type == PERSISTENT
        clear_persistent_namespace(namespace)
    end
    
    # If using distributed cache, propagate clear to other servers
    if CACHE_STATE.config.cache_type == DISTRIBUTED
        # This would involve sending the clear to other cache servers
        # For now, we'll just log a message
        StructuredLogging.debug("Distributed cache clear not fully implemented",
                               data=Dict("namespace" => namespace))
    end
    
    # Update metrics
    Metrics.record_metric("cache_items", 0, 
                         labels=Dict("namespace" => namespace))
    
    Metrics.record_metric("cache_evictions_total", items_count, 
                         labels=Dict(
                             "namespace" => namespace,
                             "reason" => "clear"
                         ))
    
    return true
end

"""
    set_ttl(key::String, ttl_seconds::Int; namespace::String="default")

Set the TTL for a key.
"""
function set_ttl(key::String, ttl_seconds::Int; namespace::String="default")
    if !CACHE_STATE.initialized
        initialize()
    end
    
    if !CACHE_STATE.config.enabled
        return false
    end
    
    # Check if namespace exists
    if !haskey(CACHE_STATE.memory_cache, namespace)
        return false
    end
    
    # Check if key exists
    if !haskey(CACHE_STATE.memory_cache[namespace], key)
        return false
    end
    
    # Get item
    item = CACHE_STATE.memory_cache[namespace][key]
    
    # Check if expired
    if item.expires_at !== nothing && now() > item.expires_at
        return false
    end
    
    # Create new item with updated TTL
    new_item = CacheItem(
        item.key, 
        item.value, 
        ttl_seconds=ttl_seconds, 
        metadata=item.metadata
    )
    
    # Update cache
    CACHE_STATE.memory_cache[namespace][key] = new_item
    
    # If using persistent cache, update on disk
    if CACHE_STATE.config.cache_type == PERSISTENT
        save_persistent_item(namespace, key, new_item)
    end
    
    return true
end

"""
    stats(; namespace::String="default")

Get cache statistics.
"""
function stats(; namespace::String="default")
    if !CACHE_STATE.initialized
        initialize()
    end
    
    result = Dict{String, Any}(
        "enabled" => CACHE_STATE.config.enabled,
        "type" => string(CACHE_STATE.config.cache_type),
        "last_cleanup" => string(CACHE_STATE.last_cleanup),
        "eviction_policy" => CACHE_STATE.config.eviction_policy,
        "max_items" => CACHE_STATE.config.max_items
    )
    
    # Add namespace-specific stats
    namespace_stats = Dict{String, Any}()
    
    for (ns, cache) in CACHE_STATE.memory_cache
        if namespace == "all" || ns == namespace
            # Count items
            total_items = length(cache)
            
            # Count expired items
            expired_items = count(pair -> pair[2].expires_at !== nothing && now() > pair[2].expires_at, pairs(cache))
            
            # Calculate hits and misses
            hits = sum(get(CACHE_STATE.hits, "$(ns):$key", 0) for key in keys(cache))
            misses = sum(get(CACHE_STATE.misses, "$(ns):$key", 0) for key in keys(cache))
            
            # Calculate hit rate
            hit_rate = hits + misses > 0 ? hits / (hits + misses) : 0.0
            
            # Calculate size of all cached values combined (approximate)
            # This is a rough estimate and depends on the data type
            # For primitive types, sizeof works well, but for complex types it may not
            # TODO: implement a more accurate size measurement
            size_bytes = 0
            
            namespace_stats[ns] = Dict{String, Any}(
                "items" => total_items,
                "expired_items" => expired_items,
                "hits" => hits,
                "misses" => misses,
                "hit_rate" => hit_rate,
                "size_bytes" => size_bytes
            )
        end
    end
    
    result["namespaces"] = namespace_stats
    
    return result
end

"""
    record_hit(namespace::String, key::String)

Record a cache hit.
"""
function record_hit(namespace::String, key::String)
    hit_key = "$(namespace):$key"
    CACHE_STATE.hits[hit_key] = get(CACHE_STATE.hits, hit_key, 0) + 1
    
    # Record metric
    Metrics.record_metric("cache_hits_total", 1, 
                         labels=Dict("namespace" => namespace))
end

"""
    record_miss(namespace::String, key::String)

Record a cache miss.
"""
function record_miss(namespace::String, key::String)
    miss_key = "$(namespace):$key"
    CACHE_STATE.misses[miss_key] = get(CACHE_STATE.misses, miss_key, 0) + 1
    
    # Record metric
    Metrics.record_metric("cache_misses_total", 1, 
                         labels=Dict("namespace" => namespace))
end

# Persistent cache functions

"""
    save_persistent_cache()

Save the entire cache to disk.
"""
function save_persistent_cache()
    if CACHE_STATE.config.cache_type != PERSISTENT
        return false
    end
    
    # Ensure directory exists
    if !isdir(CACHE_STATE.config.persistent_path)
        mkpath(CACHE_STATE.config.persistent_path)
    end
    
    # Save each namespace
    for (namespace, cache) in CACHE_STATE.memory_cache
        namespace_dir = joinpath(CACHE_STATE.config.persistent_path, namespace)
        
        if !isdir(namespace_dir)
            mkpath(namespace_dir)
        end
        
        # Save namespace index
        index_path = joinpath(namespace_dir, "index.json")
        index = Dict{String, Dict{String, Any}}()
        
        for (key, item) in cache
            # Skip expired items
            if item.expires_at !== nothing && now() > item.expires_at
                continue
            end
            
            # Add to index
            index[key] = Dict{String, Any}(
                "created_at" => string(item.created_at),
                "expires_at" => item.expires_at === nothing ? nothing : string(item.expires_at),
                "metadata" => item.metadata
            )
            
            # Save value to file
            item_path = joinpath(namespace_dir, "items", "$key.dat")
            
            if !isdir(dirname(item_path))
                mkpath(dirname(item_path))
            end
            
            try
                open(item_path, "w") do io
                    # We need to serialize the value
                    # This is a simplified approach - in a real system,
                    # you'd want to handle different types better
                    serialize(io, item.value)
                end
            catch e
                StructuredLogging.error("Failed to save cache item",
                                       data=Dict(
                                           "namespace" => namespace,
                                           "key" => key,
                                           "path" => item_path
                                       ),
                                       exception=e)
            end
        end
        
        # Save index
        try
            open(index_path, "w") do io
                write(io, JSON.json(index))
            end
        catch e
            StructuredLogging.error("Failed to save cache index",
                                   data=Dict(
                                       "namespace" => namespace,
                                       "path" => index_path
                                   ),
                                   exception=e)
        end
    end
    
    return true
end

"""
    save_persistent_item(namespace::String, key::String, item::CacheItem)

Save a single cache item to disk.
"""
function save_persistent_item(namespace::String, key::String, item::CacheItem)
    if CACHE_STATE.config.cache_type != PERSISTENT
        return false
    end
    
    namespace_dir = joinpath(CACHE_STATE.config.persistent_path, namespace)
    
    if !isdir(namespace_dir)
        mkpath(namespace_dir)
    end
    
    # Save to items directory
    items_dir = joinpath(namespace_dir, "items")
    
    if !isdir(items_dir)
        mkpath(items_dir)
    end
    
    # Save value to file
    item_path = joinpath(items_dir, "$key.dat")
    
    try
        open(item_path, "w") do io
            # Serialize the value
            serialize(io, item.value)
        end
    catch e
        StructuredLogging.error("Failed to save cache item",
                               data=Dict(
                                   "namespace" => namespace,
                                   "key" => key,
                                   "path" => item_path
                               ),
                               exception=e)
        return false
    end
    
    # Update index
    index_path = joinpath(namespace_dir, "index.json")
    index = Dict{String, Dict{String, Any}}()
    
    if isfile(index_path)
        try
            index_data = read(index_path, String)
            index = JSON.parse(index_data)
        catch e
            StructuredLogging.warn("Failed to read cache index, creating new one",
                                  data=Dict(
                                      "namespace" => namespace,
                                      "path" => index_path
                                  ),
                                  exception=e)
        end
    end
    
    # Add or update item in index
    index[key] = Dict{String, Any}(
        "created_at" => string(item.created_at),
        "expires_at" => item.expires_at === nothing ? nothing : string(item.expires_at),
        "metadata" => item.metadata
    )
    
    # Save index
    try
        open(index_path, "w") do io
            write(io, JSON.json(index))
        end
    catch e
        StructuredLogging.error("Failed to save cache index",
                               data=Dict(
                                   "namespace" => namespace,
                                   "path" => index_path
                               ),
                               exception=e)
        return false
    end
    
    return true
end

"""
    load_persistent_cache()

Load the entire cache from disk.
"""
function load_persistent_cache()
    if CACHE_STATE.config.cache_type != PERSISTENT
        return false
    end
    
    if !isdir(CACHE_STATE.config.persistent_path)
        return false
    end
    
    # Get namespace directories
    namespace_dirs = filter(d -> isdir(joinpath(CACHE_STATE.config.persistent_path, d)), 
                           readdir(CACHE_STATE.config.persistent_path))
    
    loaded_count = 0
    
    for namespace in namespace_dirs
        # Load namespace index
        index_path = joinpath(CACHE_STATE.config.persistent_path, namespace, "index.json")
        
        if !isfile(index_path)
            continue
        end
        
        index = Dict{String, Dict{String, Any}}()
        
        try
            index_data = read(index_path, String)
            index = JSON.parse(index_data)
        catch e
            StructuredLogging.error("Failed to read cache index",
                                   data=Dict(
                                       "namespace" => namespace,
                                       "path" => index_path
                                   ),
                                   exception=e)
            continue
        end
        
        # Ensure namespace exists in memory cache
        if !haskey(CACHE_STATE.memory_cache, namespace)
            CACHE_STATE.memory_cache[namespace] = Dict{String, CacheItem}()
            push!(CACHE_STATE.config.namespaces, namespace)
        end
        
        # Load each item
        for (key, item_info) in index
            # Skip if already in memory
            if haskey(CACHE_STATE.memory_cache[namespace], key)
                continue
            end
            
            # Check if expired
            expires_at = item_info["expires_at"]
            
            if expires_at !== nothing
                try
                    expires_dt = DateTime(expires_at)
                    if now() > expires_dt
                        continue
                    end
                catch
                    # Skip if invalid expires_at
                    continue
                end
            end
            
            # Load value from file
            item_path = joinpath(CACHE_STATE.config.persistent_path, namespace, "items", "$key.dat")
            
            if !isfile(item_path)
                continue
            end
            
            try
                value = open(item_path, "r") do io
                    deserialize(io)
                end
                
                # Create item metadata
                metadata = get(item_info, "metadata", Dict{String, Any}())
                
                # Get created_at
                created_at = try
                    DateTime(item_info["created_at"])
                catch
                    now()  # Default to now if can't parse
                end
                
                # Calculate TTL
                ttl_seconds = if expires_at === nothing
                    nothing
                else
                    try
                        expires_dt = DateTime(expires_at)
                        round(Int, (expires_dt - now()).value / 1000)
                    catch
                        CACHE_STATE.config.default_ttl_seconds
                    end
                end
                
                # Create cache item and store
                item = CacheItem(key, value, ttl_seconds=ttl_seconds, metadata=metadata)
                
                # Override created_at to match persistent storage
                item = CacheItem{typeof(value)}(
                    item.key,
                    item.value,
                    created_at,
                    item.expires_at,
                    item.metadata
                )
                
                CACHE_STATE.memory_cache[namespace][key] = item
                loaded_count += 1
            catch e
                StructuredLogging.error("Failed to load cache item",
                                       data=Dict(
                                           "namespace" => namespace,
                                           "key" => key,
                                           "path" => item_path
                                       ),
                                       exception=e)
            end
        end
    end
    
    StructuredLogging.info("Loaded persistent cache",
                          data=Dict("loaded_items" => loaded_count))
    
    return true
end

"""
    delete_persistent_item(namespace::String, key::String)

Delete a single cache item from disk.
"""
function delete_persistent_item(namespace::String, key::String)
    if CACHE_STATE.config.cache_type != PERSISTENT
        return false
    end
    
    namespace_dir = joinpath(CACHE_STATE.config.persistent_path, namespace)
    
    if !isdir(namespace_dir)
        return true  # Nothing to delete
    end
    
    # Delete item file
    item_path = joinpath(namespace_dir, "items", "$key.dat")
    
    if isfile(item_path)
        try
            rm(item_path)
        catch e
            StructuredLogging.error("Failed to delete cache item file",
                                   data=Dict(
                                       "namespace" => namespace,
                                       "key" => key,
                                       "path" => item_path
                                   ),
                                   exception=e)
        end
    end
    
    # Update index
    index_path = joinpath(namespace_dir, "index.json")
    
    if !isfile(index_path)
        return true
    end
    
    index = Dict{String, Dict{String, Any}}()
    
    try
        index_data = read(index_path, String)
        index = JSON.parse(index_data)
        
        # Remove item from index
        delete!(index, key)
        
        # Save index
        open(index_path, "w") do io
            write(io, JSON.json(index))
        end
    catch e
        StructuredLogging.error("Failed to update cache index",
                               data=Dict(
                                   "namespace" => namespace,
                                   "key" => key,
                                   "path" => index_path
                               ),
                               exception=e)
        return false
    end
    
    return true
end

"""
    clear_persistent_namespace(namespace::String)

Clear all items in a namespace from disk.
"""
function clear_persistent_namespace(namespace::String)
    if CACHE_STATE.config.cache_type != PERSISTENT
        return false
    end
    
    namespace_dir = joinpath(CACHE_STATE.config.persistent_path, namespace)
    
    if !isdir(namespace_dir)
        return true  # Nothing to clear
    end
    
    # Clear items directory
    items_dir = joinpath(namespace_dir, "items")
    
    if isdir(items_dir)
        try
            # Remove all files in the directory
            for file in readdir(items_dir)
                rm(joinpath(items_dir, file))
            end
        catch e
            StructuredLogging.error("Failed to clear cache items directory",
                                   data=Dict(
                                       "namespace" => namespace,
                                       "path" => items_dir
                                   ),
                                   exception=e)
        end
    end
    
    # Clear index
    index_path = joinpath(namespace_dir, "index.json")
    
    if isfile(index_path)
        try
            # Create empty index
            open(index_path, "w") do io
                write(io, JSON.json(Dict()))
            end
        catch e
            StructuredLogging.error("Failed to clear cache index",
                                   data=Dict(
                                       "namespace" => namespace,
                                       "path" => index_path
                                   ),
                                   exception=e)
        end
    end
    
    return true
end

# Utility functions

"""
    with_cache(key::String, default_value, func; namespace::String="default", ttl_seconds=nothing)

Run a function with cache support. If the key is in the cache, return the cached value.
Otherwise, run the function, cache the result, and return it.
"""
function with_cache(key::String, default_value, func; 
                   namespace::String="default", 
                   ttl_seconds::Union{Int, Nothing}=nothing)
    # Check if in cache
    if has(key, namespace=namespace)
        return get(key, namespace=namespace, default=default_value)
    end
    
    # Run function
    result = func()
    
    # Cache result
    set(key, result, namespace=namespace, ttl_seconds=ttl_seconds)
    
    return result
end

end # module
