module EnhancedConfig

export ConfigSchema, ConfigSource, load_config, get_config, get_value, validate_config, reload_config
export watch_config_file, register_config_listener, merge_configs, ENV_SOURCE
export ParseConfigError, InvalidConfigError, ConfigNotFoundError

using Logging
using Dates
using JSON
using TOML
using FileWatching
using ..EnhancedErrors
using ..StructuredLogging

# Error types
struct ParseConfigError <: Exception
    message::String
    source::String
    original_error::Exception
end

struct InvalidConfigError <: Exception
    message::String
    errors::Vector{String}
end

struct ConfigNotFoundError <: Exception
    message::String
    path::String
end

"""
    ConfigSchema

Schema definition for configuration validation.
"""
struct ConfigSchema
    name::String
    required::Vector{String}
    types::Dict{String, DataType}
    defaults::Dict{String, Any}
    validators::Dict{String, Function}
    
    function ConfigSchema(;
        name::String = "config",
        required::Vector{String} = String[],
        types::Dict{String, DataType} = Dict{String, DataType}(),
        defaults::Dict{String, Any} = Dict{String, Any}(),
        validators::Dict{String, Function} = Dict{String, Function}()
    )
        return new(name, required, types, defaults, validators)
    end
end

"""
    ConfigSource

Represents a source of configuration values.
"""
abstract type ConfigSource end

"""
    FileConfigSource

Configuration source from a file.
"""
struct FileConfigSource <: ConfigSource
    path::String
    format::String  # "toml", "json"
    auto_reload::Bool
    last_modified::Ref{DateTime}
    
    function FileConfigSource(path::String; format::String="toml", auto_reload::Bool=false)
        last_modified = Ref(isfile(path) ? Dates.unix2datetime(stat(path).mtime) : now())
        return new(path, lowercase(format), auto_reload, last_modified)
    end
end

"""
    EnvConfigSource

Configuration source from environment variables.
"""
struct EnvConfigSource <: ConfigSource
    prefix::String
    
    function EnvConfigSource(prefix::String="JULIAOS_")
        return new(prefix)
    end
end

"""
    DictConfigSource

Configuration source from a Julia dictionary.
"""
struct DictConfigSource <: ConfigSource
    data::Dict{String, Any}
    
    function DictConfigSource(data::Dict{String, Any})
        return new(data)
    end
end

# Create a global environment variable source
const ENV_SOURCE = EnvConfigSource()

# Global configuration state
mutable struct ConfigState
    config::Dict{String, Any}
    schema::Union{ConfigSchema, Nothing}
    sources::Vector{ConfigSource}
    last_update::DateTime
    listeners::Vector{Function}
    watch_task::Union{Task, Nothing}
    
    function ConfigState()
        return new(
            Dict{String, Any}(),  # Empty config
            nothing,              # No schema
            ConfigSource[],       # No sources
            now(),                # Current time
            Function[],           # No listeners
            nothing               # No watch task
        )
    end
end

# Singleton instance of config state
const CONFIG_STATE = ConfigState()

"""
    load_config(sources...; schema=nothing)

Load and merge configuration from the given sources.
Optionally validate against a schema.

# Examples
```julia
# Load from a TOML file
load_config(FileConfigSource("config.toml"))

# Load from a TOML file with auto-reload
load_config(FileConfigSource("config.toml", auto_reload=true))

# Load from environment variables with JULIAOS_ prefix
load_config(ENV_SOURCE)

# Load from multiple sources (later sources override earlier ones)
load_config(
    FileConfigSource("config.default.toml"),
    FileConfigSource("config.local.toml"),
    ENV_SOURCE
)

# Load with schema validation
schema = ConfigSchema(
    required = ["server.port", "database.url"],
    types = Dict(
        "server.port" => Int,
        "logging.level" => String
    ),
    defaults = Dict(
        "server.port" => 8080,
        "logging.level" => "info"
    ),
    validators = Dict(
        "server.port" => port -> 1 <= port <= 65535
    )
)
load_config(FileConfigSource("config.toml"), schema=schema)
```
"""
function load_config(sources...; schema::Union{ConfigSchema, Nothing}=nothing)
    context = EnhancedErrors.with_error_context("EnhancedConfig", "load_config")
    
    # Reset config state
    empty!(CONFIG_STATE.config)
    empty!(CONFIG_STATE.sources)
    CONFIG_STATE.schema = schema
    CONFIG_STATE.last_update = now()
    
    # Add sources
    append!(CONFIG_STATE.sources, sources)
    
    StructuredLogging.with_context(StructuredLogging.LogContext(
        component="EnhancedConfig",
        operation="load_config"
    )) do
        # Load from each source
        for source in sources
            try
                merge_source!(CONFIG_STATE.config, source)
                StructuredLogging.info("Loaded config from $(source_description(source))")
            catch e
                error_context = EnhancedErrors.with_error_context("EnhancedConfig", "load_config", 
                    metadata=Dict("source" => source_description(source)))
                
                if e isa ConfigNotFoundError
                    StructuredLogging.warn("Config file not found: $(e.path)", 
                        data=Dict("source" => source_description(source)))
                elseif e isa ParseConfigError
                    StructuredLogging.error("Failed to parse config", 
                        data=Dict("source" => source_description(source)), 
                        exception=e.original_error)
                    EnhancedErrors.try_operation(error_context) do
                        throw(e)
                    end
                else
                    StructuredLogging.error("Failed to load config", 
                        data=Dict("source" => source_description(source)),
                        exception=e)
                    EnhancedErrors.try_operation(error_context) do
                        throw(e)
                    end
                end
            end
        end
        
        # Apply schema defaults
        if schema !== nothing
            for (key, value) in schema.defaults
                if !has_nested_key(CONFIG_STATE.config, split(key, "."))
                    set_nested_value!(CONFIG_STATE.config, split(key, "."), value)
                end
            end
        end
        
        # Validate against schema
        if schema !== nothing
            validation_errors = validate_against_schema(CONFIG_STATE.config, schema)
            if !isempty(validation_errors)
                error_context = EnhancedErrors.with_error_context("EnhancedConfig", "load_config", 
                    metadata=Dict("schema" => schema.name, "errors" => validation_errors))
                
                StructuredLogging.error("Config validation failed", 
                    data=Dict("errors" => validation_errors))
                
                EnhancedErrors.try_operation(error_context) do
                    throw(InvalidConfigError("Configuration failed validation", validation_errors))
                end
            end
        end
        
        # Start file watching if needed
        for source in sources
            if source isa FileConfigSource && source.auto_reload
                start_file_watching()
                break
            end
        end
        
        StructuredLogging.info("Config loaded successfully", 
            data=Dict("source_count" => length(sources)))
    end
    
    # Return loaded config
    return CONFIG_STATE.config
end

"""
    reload_config()

Reload configuration from all registered sources.
"""
function reload_config()
    context = EnhancedErrors.with_error_context("EnhancedConfig", "reload_config")
    
    StructuredLogging.with_context(StructuredLogging.LogContext(
        component="EnhancedConfig",
        operation="reload_config"
    )) do
        StructuredLogging.info("Reloading configuration from all sources")
        
        # Create a new config dict
        new_config = Dict{String, Any}()
        
        # Load from each source
        for source in CONFIG_STATE.sources
            try
                merge_source!(new_config, source)
                StructuredLogging.info("Reloaded config from $(source_description(source))")
            catch e
                StructuredLogging.error("Failed to reload config", 
                    data=Dict("source" => source_description(source)),
                    exception=e)
            end
        end
        
        # Apply schema defaults
        if CONFIG_STATE.schema !== nothing
            for (key, value) in CONFIG_STATE.schema.defaults
                if !has_nested_key(new_config, split(key, "."))
                    set_nested_value!(new_config, split(key, "."), value)
                end
            end
        end
        
        # Validate against schema
        if CONFIG_STATE.schema !== nothing
            validation_errors = validate_against_schema(new_config, CONFIG_STATE.schema)
            if !isempty(validation_errors)
                StructuredLogging.error("Config validation failed during reload", 
                    data=Dict("errors" => validation_errors))
                
                EnhancedErrors.try_operation(context) do
                    throw(InvalidConfigError("Configuration failed validation during reload", validation_errors))
                end
                
                # Keep the previous config if validation fails
                return CONFIG_STATE.config
            end
        end
        
        # Update state
        old_config = copy(CONFIG_STATE.config)
        empty!(CONFIG_STATE.config)
        merge!(CONFIG_STATE.config, new_config)
        CONFIG_STATE.last_update = now()
        
        # Notify listeners
        for listener in CONFIG_STATE.listeners
            try
                listener(CONFIG_STATE.config, old_config)
            catch e
                StructuredLogging.error("Config listener failed", exception=e)
            end
        end
        
        StructuredLogging.info("Config reloaded successfully")
    end
    
    return CONFIG_STATE.config
end

"""
    get_config()

Get the current configuration dictionary.
"""
function get_config()
    return CONFIG_STATE.config
end

"""
    get_value(path, default=nothing)

Get a configuration value by path (e.g., "server.port").
Returns the default value if the path doesn't exist.

# Examples
```julia
# Get a value with a default
port = get_value("server.port", 8080)

# Get a nested value
db_url = get_value("database.connection.url")
```
"""
function get_value(path, default=nothing)
    parts = split(path, ".")
    return get_nested_value(CONFIG_STATE.config, parts, default)
end

"""
    validate_config(schema::ConfigSchema)

Validate the current configuration against a schema.
Returns a list of validation errors, which is empty if validation passes.
"""
function validate_config(schema::ConfigSchema)
    return validate_against_schema(CONFIG_STATE.config, schema)
end

"""
    register_config_listener(listener::Function)

Register a function to be called when the configuration changes.
The listener function should take two arguments: the new config and the old config.

# Examples
```julia
register_config_listener((new_config, old_config) -> begin
    if get_nested_value(new_config, ["server", "port"]) != get_nested_value(old_config, ["server", "port"])
        println("Server port changed!")
    end
end)
```
"""
function register_config_listener(listener::Function)
    push!(CONFIG_STATE.listeners, listener)
    return nothing
end

"""
    watch_config_file(path::String, format::String="toml")

Watch a config file for changes and reload when it changes.
Returns a function that can be called to stop watching.
"""
function watch_config_file(path::String, format::String="toml")
    # Add the file as a source if it's not already
    source = FileConfigSource(path, format=format, auto_reload=true)
    if !any(s -> s isa FileConfigSource && s.path == path, CONFIG_STATE.sources)
        push!(CONFIG_STATE.sources, source)
    end
    
    # Start watching
    start_file_watching()
    
    # Return a function to stop watching
    return function()
        # Remove the source
        filter!(s -> !(s isa FileConfigSource && s.path == path), CONFIG_STATE.sources)
        
        # Stop watching if no more auto-reload sources
        if !any(s -> s isa FileConfigSource && s.auto_reload, CONFIG_STATE.sources)
            stop_file_watching()
        end
    end
end

"""
    merge_configs(configs::Dict...)

Merge multiple configuration dictionaries, with later configs taking precedence.
"""
function merge_configs(configs::Dict...)
    result = Dict{String, Any}()
    for config in configs
        deep_merge!(result, config)
    end
    return result
end

# Helper functions

"""
    merge_source!(config::Dict{String, Any}, source::ConfigSource)

Merge configuration from a source into the config dictionary.
"""
function merge_source!(config::Dict{String, Any}, source::ConfigSource)
    if source isa FileConfigSource
        # Load from file
        if !isfile(source.path)
            throw(ConfigNotFoundError("Config file not found", source.path))
        end
        
        # Parse file
        local file_config
        try
            if source.format == "toml"
                file_config = TOML.parsefile(source.path)
            elseif source.format == "json"
                open(source.path, "r") do io
                    file_config = JSON.parse(io)
                end
            else
                throw(ArgumentError("Unsupported config format: $(source.format)"))
            end
            
            # Update last modified time
            source.last_modified[] = Dates.unix2datetime(stat(source.path).mtime)
        catch e
            throw(ParseConfigError("Failed to parse config file: $(source.path)", source.path, e))
        end
        
        # Merge into config
        deep_merge!(config, file_config)
    elseif source isa EnvConfigSource
        # Load from environment variables
        for (key, value) in ENV
            if startswith(key, source.prefix)
                # Convert key from ENV_VAR format to nested.key format
                config_key = key[length(source.prefix)+1:end]
                config_key = lowercase(replace(config_key, "_" => "."))
                
                # Parse value
                parsed_value = parse_env_value(value)
                
                # Set in config
                set_nested_value!(config, split(config_key, "."), parsed_value)
            end
        end
    elseif source isa DictConfigSource
        # Load from dictionary
        deep_merge!(config, source.data)
    end
    
    return config
end

"""
    source_description(source::ConfigSource)

Get a human-readable description of a config source.
"""
function source_description(source::ConfigSource)
    if source isa FileConfigSource
        return "file $(source.path) ($(source.format))"
    elseif source isa EnvConfigSource
        return "environment variables with prefix $(source.prefix)"
    elseif source isa DictConfigSource
        return "dictionary with $(length(source.data)) keys"
    else
        return string(typeof(source))
    end
end

"""
    parse_env_value(value::String)

Parse a string value from an environment variable.
"""
function parse_env_value(value::String)
    # Try to parse as a number
    if occursin(r"^-?\d+$", value)
        # Integer
        return parse(Int, value)
    elseif occursin(r"^-?\d+\.\d+$", value)
        # Float
        return parse(Float64, value)
    elseif lowercase(value) in ["true", "yes", "y", "1"]
        # Boolean true
        return true
    elseif lowercase(value) in ["false", "no", "n", "0"]
        # Boolean false
        return false
    elseif lowercase(value) == "null" || value == ""
        # Null
        return nothing
    else
        # String
        return value
    end
end

"""
    validate_against_schema(config::Dict{String, Any}, schema::ConfigSchema)

Validate a configuration dictionary against a schema.
Returns a list of validation errors, which is empty if validation passes.
"""
function validate_against_schema(config::Dict{String, Any}, schema::ConfigSchema)
    errors = String[]
    
    # Check required fields
    for key in schema.required
        if !has_nested_key(config, split(key, "."))
            push!(errors, "Missing required field: $key")
        end
    end
    
    # Check types
    for (key, expected_type) in schema.types
        if has_nested_key(config, split(key, "."))
            value = get_nested_value(config, split(key, "."), nothing)
            if value !== nothing && !isa(value, expected_type)
                push!(errors, "Field $key should be of type $expected_type, got $(typeof(value))")
            end
        end
    end
    
    # Run validators
    for (key, validator) in schema.validators
        if has_nested_key(config, split(key, "."))
            value = get_nested_value(config, split(key, "."), nothing)
            if value !== nothing
                try
                    if !validator(value)
                        push!(errors, "Validation failed for field $key")
                    end
                catch e
                    push!(errors, "Validator error for field $key: $e")
                end
            end
        end
    end
    
    return errors
end

"""
    has_nested_key(dict::Dict, keys::Vector{String})

Check if a nested key exists in a dictionary.
"""
function has_nested_key(dict::Dict, keys::Vector{String})
    if isempty(keys)
        return false
    end
    
    current = dict
    for i in 1:length(keys)-1
        key = keys[i]
        if !haskey(current, key) || !isa(current[key], Dict)
            return false
        end
        current = current[key]
    end
    
    return haskey(current, keys[end])
end

"""
    get_nested_value(dict::Dict, keys::Vector{String}, default=nothing)

Get a nested value from a dictionary.
"""
function get_nested_value(dict::Dict, keys::Vector{String}, default=nothing)
    if isempty(keys)
        return default
    end
    
    current = dict
    for i in 1:length(keys)-1
        key = keys[i]
        if !haskey(current, key) || !isa(current[key], Dict)
            return default
        end
        current = current[key]
    end
    
    return get(current, keys[end], default)
end

"""
    set_nested_value!(dict::Dict, keys::Vector{String}, value)

Set a nested value in a dictionary.
"""
function set_nested_value!(dict::Dict, keys::Vector{String}, value)
    if isempty(keys)
        return dict
    end
    
    current = dict
    for i in 1:length(keys)-1
        key = keys[i]
        if !haskey(current, key) || !isa(current[key], Dict)
            current[key] = Dict{String, Any}()
        end
        current = current[key]
    end
    
    current[keys[end]] = value
    return dict
end

"""
    deep_merge!(a::Dict, b::Dict)

Merge dictionary b into dictionary a, recursively.
"""
function deep_merge!(a::Dict, b::Dict)
    for (k, v) in b
        if haskey(a, k) && isa(a[k], Dict) && isa(v, Dict)
            deep_merge!(a[k], v)
        else
            a[k] = v
        end
    end
    return a
end

"""
    start_file_watching()

Start a background task to watch for changes in config files.
"""
function start_file_watching()
    if CONFIG_STATE.watch_task === nothing || !istaskdone(CONFIG_STATE.watch_task)
        CONFIG_STATE.watch_task = @async begin
            StructuredLogging.debug("Started config file watching task")
            while true
                try
                    # Check each file source
                    file_changed = false
                    for source in CONFIG_STATE.sources
                        if source isa FileConfigSource && source.auto_reload && isfile(source.path)
                            mtime = Dates.unix2datetime(stat(source.path).mtime)
                            if mtime > source.last_modified[]
                                StructuredLogging.info("Config file changed: $(source.path)")
                                file_changed = true
                                break
                            end
                        end
                    end
                    
                    if file_changed
                        reload_config()
                    end
                    
                    # Watch for changes with a small sleep
                    sleep(1.0)
                catch e
                    if e isa InterruptException
                        break
                    end
                    StructuredLogging.error("Error in config file watcher", exception=e)
                    sleep(5.0)  # Sleep longer after an error
                end
            end
        end
    end
end

"""
    stop_file_watching()

Stop the background task watching for changes in config files.
"""
function stop_file_watching()
    if CONFIG_STATE.watch_task !== nothing && !istaskdone(CONFIG_STATE.watch_task)
        try
            schedule(CONFIG_STATE.watch_task, InterruptException(), error=true)
            StructuredLogging.debug("Stopped config file watching task")
        catch e
            StructuredLogging.warn("Failed to stop config file watching task", exception=e)
        end
    end
    CONFIG_STATE.watch_task = nothing
end

end # module
