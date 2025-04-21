module StructuredLogging

export configure_logging, log_event, LogLevel, Logger
export debug, info, warn, error, critical
export with_context, current_context, clear_context
export get_logger, set_global_logger

using Logging
using Dates
using JSON
using UUIDs

"""
    LogLevel

Enum representing different log levels.
"""
@enum LogLevel begin
    DEBUG
    INFO
    WARN
    ERROR
    CRITICAL
end

"""
    LogContext

Structure to hold contextual information for logs.
"""
struct LogContext
    request_id::Union{String, Nothing}
    user_id::Union{String, Nothing}
    session_id::Union{String, Nothing}
    component::String
    operation::String
    metadata::Dict{String, Any}
    
    function LogContext(;
        request_id::Union{String, Nothing}=nothing,
        user_id::Union{String, Nothing}=nothing,
        session_id::Union{String, Nothing}=nothing,
        component::String="system",
        operation::String="generic",
        metadata::Dict{String, Any}=Dict{String, Any}()
    )
        return new(request_id, user_id, session_id, component, operation, metadata)
    end
end

"""
    LogEntry

Structure representing a single log entry.
"""
struct LogEntry
    timestamp::DateTime
    level::LogLevel
    message::String
    context::LogContext
    data::Dict{String, Any}
    exception::Union{Exception, Nothing}
    stacktrace::Union{Array, Nothing}
end

"""
    Logger

Structure for a logger with configuration options.
"""
mutable struct Logger
    min_level::LogLevel
    format::String  # "text" or "json"
    output::Union{IO, String, Nothing}  # IO object, filename, or nothing (default)
    include_stacktrace::Bool
    
    function Logger(;
        min_level::LogLevel=INFO,
        format::String="text",
        output::Union{IO, String, Nothing}=nothing,
        include_stacktrace::Bool=true
    )
        return new(min_level, format, output, include_stacktrace)
    end
end

# Thread-local context
const THREAD_LOCAL_CONTEXT = Dict{Int, LogContext}()

# Global logger instance
global_logger = Logger()

"""
    set_global_logger(logger::Logger)

Set the global logger instance.
"""
function set_global_logger(logger::Logger)
    global global_logger = logger
end

"""
    get_logger()

Get the current global logger instance.
"""
function get_logger()
    return global_logger
end

"""
    with_context(f::Function, context::LogContext)

Execute a function with the specified logging context.
"""
function with_context(f::Function, context::LogContext)
    thread_id = Threads.threadid()
    old_context = get(THREAD_LOCAL_CONTEXT, thread_id, nothing)
    
    try
        THREAD_LOCAL_CONTEXT[thread_id] = context
        return f()
    finally
        if old_context === nothing
            delete!(THREAD_LOCAL_CONTEXT, thread_id)
        else
            THREAD_LOCAL_CONTEXT[thread_id] = old_context
        end
    end
end

"""
    current_context()

Get the current thread-local logging context or create a default one.
"""
function current_context()
    thread_id = Threads.threadid()
    return get(THREAD_LOCAL_CONTEXT, thread_id, LogContext())
end

"""
    clear_context()

Clear the current thread-local logging context.
"""
function clear_context()
    thread_id = Threads.threadid()
    delete!(THREAD_LOCAL_CONTEXT, thread_id)
    return nothing
end

"""
    format_log_entry(entry::LogEntry, format::String)

Format a log entry according to the specified format.
"""
function format_log_entry(entry::LogEntry, format::String)
    if lowercase(format) == "json"
        # Construct a dictionary representation of the log entry
        log_dict = Dict{String, Any}(
            "timestamp" => string(entry.timestamp),
            "level" => string(entry.level),
            "message" => entry.message,
            "data" => entry.data
        )
        
        # Add context information
        context_dict = Dict{String, Any}(
            "component" => entry.context.component,
            "operation" => entry.context.operation
        )
        
        if entry.context.request_id !== nothing
            context_dict["request_id"] = entry.context.request_id
        end
        
        if entry.context.user_id !== nothing
            context_dict["user_id"] = entry.context.user_id
        end
        
        if entry.context.session_id !== nothing
            context_dict["session_id"] = entry.context.session_id
        end
        
        if !isempty(entry.context.metadata)
            context_dict["metadata"] = entry.context.metadata
        end
        
        log_dict["context"] = context_dict
        
        # Add exception information if available
        if entry.exception !== nothing
            log_dict["exception"] = Dict{String, Any}(
                "type" => string(typeof(entry.exception)),
                "message" => string(entry.exception)
            )
            
            if entry.stacktrace !== nothing
                log_dict["exception"]["stacktrace"] = string.(entry.stacktrace)
            end
        end
        
        # Convert to JSON
        return JSON.json(log_dict)
    else
        # Text format
        level_str = string(entry.level)
        timestamp_str = Dates.format(entry.timestamp, "yyyy-mm-dd HH:MM:SS.sss")
        
        # Basic log line
        log_line = "[$timestamp_str] [$level_str] [$(entry.context.component)/$(entry.context.operation)] $(entry.message)"
        
        # Add context information
        if entry.context.request_id !== nothing || entry.context.user_id !== nothing
            context_parts = String[]
            
            if entry.context.request_id !== nothing
                push!(context_parts, "request_id=$(entry.context.request_id)")
            end
            
            if entry.context.user_id !== nothing
                push!(context_parts, "user_id=$(entry.context.user_id)")
            end
            
            if entry.context.session_id !== nothing
                push!(context_parts, "session_id=$(entry.context.session_id)")
            end
            
            log_line *= " ($(join(context_parts, ", ")))"
        end
        
        # Add data if available
        if !isempty(entry.data)
            data_str = join(["$k=$v" for (k, v) in entry.data], ", ")
            log_line *= " | $data_str"
        end
        
        # Add exception information if available
        if entry.exception !== nothing
            log_line *= "\nException: $(typeof(entry.exception)): $(entry.exception)"
            
            if entry.stacktrace !== nothing
                stacktrace_str = join(string.(entry.stacktrace), "\n  ")
                log_line *= "\nStacktrace:\n  $stacktrace_str"
            end
        end
        
        return log_line
    end
end

"""
    log_event(level::LogLevel, message::String; kwargs...)

Log an event with the specified level and message.
Additional data and exception information can be provided as keyword arguments.
"""
function log_event(level::LogLevel, message::String; 
                   data::Dict{String, Any}=Dict{String, Any}(),
                   exception::Union{Exception, Nothing}=nothing,
                   include_stacktrace::Union{Bool, Nothing}=nothing,
                   logger::Union{Logger, Nothing}=nothing,
                   context::Union{LogContext, Nothing}=nothing)
    
    # Use provided logger or global logger
    log_logger = logger !== nothing ? logger : global_logger
    
    # Skip if log level is below minimum
    if level < log_logger.min_level
        return nothing
    end
    
    # Use provided context or current thread-local context
    log_context = context !== nothing ? context : current_context()
    
    # Determine whether to include stacktrace
    include_st = include_stacktrace !== nothing ? include_stacktrace : log_logger.include_stacktrace
    
    # Capture stacktrace if needed
    st = if include_st && exception !== nothing
        try
            stacktrace(catch_backtrace())
        catch
            nothing
        end
    else
        nothing
    end
    
    # Create log entry
    entry = LogEntry(
        now(),
        level,
        message,
        log_context,
        data,
        exception,
        st
    )
    
    # Format log entry
    log_str = format_log_entry(entry, log_logger.format)
    
    # Write to output
    if log_logger.output isa IO
        println(log_logger.output, log_str)
    elseif log_logger.output isa String
        # Append to file
        open(log_logger.output, "a") do io
            println(io, log_str)
        end
    else
        # Default to standard streams based on level
        if level == ERROR || level == CRITICAL
            println(stderr, log_str)
        else
            println(stdout, log_str)
        end
    end
    
    return nothing
end

# Convenience functions for different log levels
"""
    debug(message::String; kwargs...)

Log a debug message.
"""
debug(message::String; kwargs...) = log_event(DEBUG, message; kwargs...)

"""
    info(message::String; kwargs...)

Log an info message.
"""
info(message::String; kwargs...) = log_event(INFO, message; kwargs...)

"""
    warn(message::String; kwargs...)

Log a warning message.
"""
warn(message::String; kwargs...) = log_event(WARN, message; kwargs...)

"""
    error(message::String; kwargs...)

Log an error message.
"""
error(message::String; kwargs...) = log_event(ERROR, message; kwargs...)

"""
    critical(message::String; kwargs...)

Log a critical message.
"""
critical(message::String; kwargs...) = log_event(CRITICAL, message; kwargs...)

"""
    configure_logging(;
        min_level::Union{LogLevel, String}=INFO,
        format::String="text",
        output::Union{IO, String, Nothing}=nothing,
        include_stacktrace::Bool=true
    )

Configure the global logger with the specified options.
"""
function configure_logging(;
    min_level::Union{LogLevel, String}=INFO,
    format::String="text",
    output::Union{IO, String, Nothing}=nothing,
    include_stacktrace::Bool=true
)
    # Convert string level to enum if needed
    log_level = if min_level isa String
        level_str = uppercase(min_level)
        if level_str == "DEBUG"
            DEBUG
        elseif level_str == "INFO"
            INFO
        elseif level_str == "WARN" || level_str == "WARNING"
            WARN
        elseif level_str == "ERROR"
            ERROR
        elseif level_str == "CRITICAL"
            CRITICAL
        else
            @warn "Unknown log level: $min_level, using INFO"
            INFO
        end
    else
        min_level
    end
    
    # Ensure format is valid
    log_format = if lowercase(format) in ["text", "json"]
        format
    else
        @warn "Unknown log format: $format, using text"
        "text"
    end
    
    # Create and set global logger
    logger = Logger(
        min_level=log_level,
        format=log_format,
        output=output,
        include_stacktrace=include_stacktrace
    )
    
    set_global_logger(logger)
    
    # Log configuration
    info("Logging configured", 
        data=Dict(
            "min_level" => string(log_level),
            "format" => log_format,
            "output_type" => output isa IO ? "io" : (output isa String ? "file" : "default"),
            "include_stacktrace" => include_stacktrace
        )
    )
    
    return logger
end

end # module
