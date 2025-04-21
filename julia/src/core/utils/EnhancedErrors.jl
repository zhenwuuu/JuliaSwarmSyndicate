module EnhancedErrors

export JuliaOSError, ValidationError, NotFoundError, AuthenticationError
export UnauthorizedError, RateLimitError, InternalError, ConfigurationError, NetworkError
export DependencyError, DataError, BusinessLogicError, OperationTimeoutError
export handle_error, with_error_context, capture_stacktrace, format_exception
export try_operation

using Logging
using Dates
using Base: @kwdef

#=
Enhanced error system for JuliaOS with:
1. Contextual information for better debugging
2. Standardized error types across modules
3. Improved error handling with context capture
4. Structured error formatting for logging and API responses
=#

"""
    JuliaOSError

Base abstract type for all JuliaOS errors.
All error types in the system should inherit from this.
"""
abstract type JuliaOSError <: Exception end

"""
    ErrorContext

Stores contextual information about an error occurrence.
"""
@kwdef struct ErrorContext
    timestamp::DateTime = now()
    module_name::String = ""
    function_name::String = ""
    file::String = ""
    line::Int = 0
    stacktrace::Union{Array, Nothing} = nothing
    metadata::Dict{String, Any} = Dict{String, Any}()
end

"""
    ValidationError

Thrown when input validation fails.
"""
struct ValidationError <: JuliaOSError
    message::String
    field::Union{String, Nothing}
    context::ErrorContext
    
    ValidationError(message::String, field::Union{String, Nothing}=nothing; 
                    context::ErrorContext=ErrorContext()) = new(message, field, context)
end

"""
    NotFoundError

Thrown when a requested resource cannot be found.
"""
struct NotFoundError <: JuliaOSError
    message::String
    resource_type::String
    resource_id::String
    context::ErrorContext
    
    NotFoundError(resource_type::String, resource_id::String; context::ErrorContext=ErrorContext()) = 
        new("$resource_type with ID $resource_id not found", resource_type, resource_id, context)
end

"""
    AuthenticationError

Thrown when authentication is required but not provided or invalid.
"""
struct AuthenticationError <: JuliaOSError
    message::String
    context::ErrorContext
    
    AuthenticationError(message::String="Authentication required"; context::ErrorContext=ErrorContext()) = 
        new(message, context)
end

"""
    UnauthorizedError

Thrown when a user doesn't have permission to perform an action.
"""
struct UnauthorizedError <: JuliaOSError
    message::String
    resource::String
    action::String
    context::ErrorContext
    
    UnauthorizedError(resource::String, action::String; context::ErrorContext=ErrorContext()) = 
        new("Not authorized to $action $resource", resource, action, context)
end

"""
    RateLimitError

Thrown when a rate limit is exceeded.
"""
struct RateLimitError <: JuliaOSError
    message::String
    limit::Int
    reset_after::Int
    context::ErrorContext
    
    RateLimitError(limit::Int, reset_after::Int; context::ErrorContext=ErrorContext()) = 
        new("Rate limit exceeded. Limit: $limit requests. Try again in $reset_after seconds.", 
            limit, reset_after, context)
end

"""
    InternalError

Thrown for unspecified internal errors, often wrapping another exception.
"""
struct InternalError <: JuliaOSError
    message::String
    original_error::Exception
    context::ErrorContext
    
    InternalError(message::String, original_error::Exception; context::ErrorContext=ErrorContext()) = 
        new(message, original_error, context)
end

"""
    ConfigurationError

Thrown when there is an issue with configuration settings.
"""
struct ConfigurationError <: JuliaOSError
    message::String
    parameter::String
    context::ErrorContext
    
    ConfigurationError(message::String, parameter::String; context::ErrorContext=ErrorContext()) = 
        new(message, parameter, context)
end

"""
    NetworkError

Thrown when network operations fail.
"""
struct NetworkError <: JuliaOSError
    message::String
    endpoint::String
    status_code::Union{Int, Nothing}
    context::ErrorContext
    
    NetworkError(message::String, endpoint::String, status_code::Union{Int, Nothing}=nothing; 
                 context::ErrorContext=ErrorContext()) = 
        new(message, endpoint, status_code, context)
end

"""
    DependencyError

Thrown when a dependency (external service, library) fails.
"""
struct DependencyError <: JuliaOSError
    message::String
    dependency::String
    context::ErrorContext
    
    DependencyError(message::String, dependency::String; context::ErrorContext=ErrorContext()) = 
        new(message, dependency, context)
end

"""
    DataError

Thrown when there are data integrity or format issues.
"""
struct DataError <: JuliaOSError
    message::String
    data_source::String
    context::ErrorContext
    
    DataError(message::String, data_source::String; context::ErrorContext=ErrorContext()) = 
        new(message, data_source, context)
end

"""
    BusinessLogicError

Thrown when business rules or logic constraints are violated.
"""
struct BusinessLogicError <: JuliaOSError
    message::String
    rule::String
    context::ErrorContext
    
    BusinessLogicError(message::String, rule::String; context::ErrorContext=ErrorContext()) = 
        new(message, rule, context)
end

"""
    OperationTimeoutError

Thrown when an operation times out.
"""
struct OperationTimeoutError <: JuliaOSError
    message::String
    operation::String
    timeout_seconds::Float64
    context::ErrorContext
    
    OperationTimeoutError(operation::String, timeout_seconds::Number; context::ErrorContext=ErrorContext()) = 
        new("Operation '$operation' timed out after $timeout_seconds seconds", operation, Float64(timeout_seconds), context)
end

"""
    capture_stacktrace()

Capture the current call stack, skipping internal frames.
"""
function capture_stacktrace(skip_frames::Int=0)
    return stacktrace(backtrace())[skip_frames+1:end]
end

"""
    with_error_context(module_name::String, function_name::String; metadata=Dict())

Create an ErrorContext with the current source location and optional metadata.
"""
function with_error_context(module_name::String, function_name::String; metadata=Dict{String, Any}())
    # Get caller information
    frame = stacktrace()[2]  # Skip this function's frame
    file = String(frame.file)
    line = frame.line
    
    return ErrorContext(
        timestamp = now(),
        module_name = module_name,
        function_name = function_name,
        file = file,
        line = line,
        stacktrace = capture_stacktrace(2),  # Skip this function and the caller
        metadata = metadata
    )
end

"""
    format_exception(e::Exception)

Format an exception into a structured dictionary for logging and API responses.
"""
function format_exception(e::Exception)
    error_type = string(typeof(e))
    error_msg = string(e)
    
    if e isa JuliaOSError
        # Get standard fields for all JuliaOSError types
        result = Dict(
            "error_type" => error_type,
            "message" => e.message
        )
        
        # Add context information if available
        if isdefined(e, :context)
            context = e.context
            result["context"] = Dict(
                "timestamp" => string(context.timestamp),
                "module" => context.module_name,
                "function" => context.function_name,
                "file" => context.file,
                "line" => context.line,
                "metadata" => context.metadata
            )
        end
        
        # Add specific fields based on error type
        if e isa ValidationError && e.field !== nothing
            result["field"] = e.field
        elseif e isa NotFoundError
            result["resource_type"] = e.resource_type
            result["resource_id"] = e.resource_id
        elseif e isa UnauthorizedError
            result["resource"] = e.resource
            result["action"] = e.action
        elseif e isa RateLimitError
            result["limit"] = e.limit
            result["reset_after"] = e.reset_after
        elseif e isa NetworkError && e.status_code !== nothing
            result["endpoint"] = e.endpoint
            result["status_code"] = e.status_code
        elseif e isa ConfigurationError
            result["parameter"] = e.parameter
        elseif e isa DependencyError
            result["dependency"] = e.dependency
        elseif e isa DataError
            result["data_source"] = e.data_source
        elseif e isa BusinessLogicError
            result["rule"] = e.rule
        elseif e isa OperationTimeoutError
            result["operation"] = e.operation
            result["timeout_seconds"] = e.timeout_seconds
        end
        
        return result
    else
        # For non-JuliaOSError exceptions
        return Dict(
            "error_type" => error_type,
            "message" => error_msg,
            "stacktrace" => string.(stacktrace())
        )
    end
end

"""
    handle_error(e::Exception)

Handle an exception and return an appropriate API response.
Returns a tuple of (status_code, response_dict)
"""
function handle_error(e::Exception)
    # Start with basic information
    error_data = format_exception(e)
    
    # Determine HTTP status code based on error type
    status = if e isa ValidationError
        400  # Bad Request
    elseif e isa NotFoundError
        404  # Not Found
    elseif e isa AuthenticationError
        401  # Unauthorized
    elseif e isa UnauthorizedError
        403  # Forbidden
    elseif e isa RateLimitError
        429  # Too Many Requests
    elseif e isa NetworkError && e.status_code !== nothing
        e.status_code  # Use the status code from the network error
    elseif e isa ConfigurationError || e isa DataError || e isa BusinessLogicError
        400  # Bad Request
    elseif e isa OperationTimeoutError
        408  # Request Timeout
    elseif e isa DependencyError || e isa InternalError
        500  # Internal Server Error
    else
        # Log unhandled exception types
        @error "Unhandled exception type: $(typeof(e))" exception=(e, catch_backtrace())
        500  # Internal Server Error
    end
    
    # Create API response
    response = Dict(
        "success" => false,
        "error" => error_data
    )
    
    # In production, we might want to hide the stack trace
    # and internal details for 500-level errors
    if status >= 500 && haskey(response["error"], "stacktrace")
        # Log the full error but only return a sanitized version to the client
        @error "Internal server error" error_details=response["error"]
        response["error"] = Dict(
            "error_type" => get(response["error"], "error_type", "InternalError"),
            "message" => "An internal server error occurred"
        )
    end
    
    return status, response
end

"""
    try_operation(operation::Function, error_context::ErrorContext)

Execute a function and handle any exceptions with the provided error context.
Returns the function's result or throws an enhanced error with context.
"""
function try_operation(operation::Function, error_context::ErrorContext)
    try
        return operation()
    catch e
        # If it's already a JuliaOSError with context, rethrow it
        if e isa JuliaOSError && isdefined(e, :context)
            rethrow(e)
        end
        
        # For standard JuliaOSError without context, add context
        if e isa JuliaOSError
            # Create a new instance of the same error type with context
            error_type = typeof(e)
            if error_type <: ValidationError
                throw(ValidationError(e.message, e.field; context=error_context))
            elseif error_type <: NotFoundError
                throw(NotFoundError(e.resource_type, e.resource_id; context=error_context))
            elseif error_type <: AuthenticationError
                throw(AuthenticationError(e.message; context=error_context))
            elseif error_type <: UnauthorizedError
                throw(UnauthorizedError(e.resource, e.action; context=error_context))
            elseif error_type <: RateLimitError
                throw(RateLimitError(e.limit, e.reset_after; context=error_context))
            elseif error_type <: InternalError
                throw(InternalError(e.message, e.original_error; context=error_context))
            elseif error_type <: ConfigurationError
                throw(ConfigurationError(e.message, e.parameter; context=error_context))
            elseif error_type <: NetworkError
                throw(NetworkError(e.message, e.endpoint, e.status_code; context=error_context))
            elseif error_type <: DependencyError
                throw(DependencyError(e.message, e.dependency; context=error_context))
            elseif error_type <: DataError
                throw(DataError(e.message, e.data_source; context=error_context))
            elseif error_type <: BusinessLogicError
                throw(BusinessLogicError(e.message, e.rule; context=error_context))
            elseif error_type <: OperationTimeoutError
                throw(OperationTimeoutError(e.operation, e.timeout_seconds; context=error_context))
            else
                # For other JuliaOSError subtypes, wrap in InternalError
                throw(InternalError("Unhandled JuliaOSError subtype: $(typeof(e))", e; context=error_context))
            end
        end
        
        # For standard exceptions, wrap in InternalError
        throw(InternalError("Operation failed: $(typeof(e))", e; context=error_context))
    end
end

end # module
