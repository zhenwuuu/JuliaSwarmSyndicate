module Utils

export setup_logging, get_uptime_seconds, parse_json, to_json
export generate_id, validate_required_fields, with_timeout

using Logging
using Dates
using JSON
using UUIDs

# Global start time for uptime calculation
const START_TIME = Ref(now())

"""
    setup_logging(level::String, format::String)

Set up logging with the specified level and format.
"""
function setup_logging(level::String, format::String)
    log_level = if lowercase(level) == "debug"
        Logging.Debug
    elseif lowercase(level) == "info"
        Logging.Info
    elseif lowercase(level) == "warn"
        Logging.Warn
    elseif lowercase(level) == "error"
        Logging.Error
    else
        Logging.Info
    end
    
    if lowercase(format) == "json"
        # Custom JSON logger could be implemented here
        # For now, use the standard logger
        global_logger(SimpleLogger(stderr, log_level))
    else
        global_logger(SimpleLogger(stderr, log_level))
    end
end

"""
    get_uptime_seconds()

Get the number of seconds the system has been running.
"""
function get_uptime_seconds()
    return Dates.value(now() - START_TIME[]) / 1000
end

"""
    parse_json(str::String)

Parse a JSON string into a Julia object.
"""
function parse_json(str::String)
    return JSON.parse(str)
end

"""
    to_json(obj)

Convert a Julia object to a JSON string.
"""
function to_json(obj)
    return JSON.json(obj)
end

"""
    generate_id()

Generate a unique ID.
"""
function generate_id()
    return string(uuid4())
end

"""
    validate_required_fields(data::Dict, fields::Vector{String})

Validate that the required fields are present in the data.
Throws a ValidationError if any field is missing.
"""
function validate_required_fields(data::Dict, fields::Vector{String})
    for field in fields
        if !haskey(data, field) || isnothing(data[field]) || data[field] == ""
            throw(ValidationError("Missing required field: $field", field))
        end
    end
end

"""
    with_timeout(f::Function, timeout_seconds::Number)

Run a function with a timeout. If the function doesn't complete within
the timeout, an exception is thrown.
"""
function with_timeout(f::Function, timeout_seconds::Number)
    result_channel = Channel{Any}(1)
    error_channel = Channel{Exception}(1)
    
    task = @async begin
        try
            result = f()
            put!(result_channel, result)
        catch e
            put!(error_channel, e)
        end
    end
    
    timeout_task = @async begin
        sleep(timeout_seconds)
        if !istaskdone(task)
            put!(error_channel, TimeoutError("Operation timed out after $timeout_seconds seconds"))
        end
    end
    
    # Wait for either result or error
    @sync begin
        @async begin
            result = take!(result_channel)
            return result
        end
        
        @async begin
            error = take!(error_channel)
            throw(error)
        end
    end
end

# Add a TimeoutError type
struct TimeoutError <: Exception
    message::String
end

end # module
