module Errors

export JuliaOSError, ValidationError, NotFoundError, AuthenticationError
export UnauthorizedError, RateLimitError, InternalError, handle_error

using Logging

# Base error type
abstract type JuliaOSError <: Exception end

# Specific error types
struct ValidationError <: JuliaOSError
    message::String
    field::Union{String, Nothing}
    
    ValidationError(message::String, field::Union{String, Nothing}=nothing) = new(message, field)
end

struct NotFoundError <: JuliaOSError
    message::String
    resource_type::String
    resource_id::String
    
    NotFoundError(resource_type::String, resource_id::String) = 
        new("$resource_type with ID $resource_id not found", resource_type, resource_id)
end

struct AuthenticationError <: JuliaOSError
    message::String
    
    AuthenticationError(message::String="Authentication required") = new(message)
end

struct UnauthorizedError <: JuliaOSError
    message::String
    resource::String
    action::String
    
    UnauthorizedError(resource::String, action::String) = 
        new("Not authorized to $action $resource", resource, action)
end

struct RateLimitError <: JuliaOSError
    message::String
    limit::Int
    reset_after::Int
    
    RateLimitError(limit::Int, reset_after::Int) = 
        new("Rate limit exceeded. Limit: $limit requests. Try again in $reset_after seconds.", limit, reset_after)
end

struct InternalError <: JuliaOSError
    message::String
    original_error::Exception
    
    InternalError(message::String, original_error::Exception) = new(message, original_error)
end

"""
    handle_error(e::Exception)

Handle an exception and return an appropriate API response.
"""
function handle_error(e::Exception)
    if e isa ValidationError
        status = 400
        response = Dict(
            "success" => false,
            "error" => e.message,
            "field" => e.field
        )
    elseif e isa NotFoundError
        status = 404
        response = Dict(
            "success" => false,
            "error" => e.message,
            "resource_type" => e.resource_type,
            "resource_id" => e.resource_id
        )
    elseif e isa AuthenticationError
        status = 401
        response = Dict(
            "success" => false,
            "error" => e.message
        )
    elseif e isa UnauthorizedError
        status = 403
        response = Dict(
            "success" => false,
            "error" => e.message,
            "resource" => e.resource,
            "action" => e.action
        )
    elseif e isa RateLimitError
        status = 429
        response = Dict(
            "success" => false,
            "error" => e.message,
            "limit" => e.limit,
            "reset_after" => e.reset_after
        )
    elseif e isa InternalError
        @error "Internal error" exception=(e.original_error, catch_backtrace())
        status = 500
        response = Dict(
            "success" => false,
            "error" => "Internal server error"
        )
    else
        @error "Unhandled exception" exception=(e, catch_backtrace())
        status = 500
        response = Dict(
            "success" => false,
            "error" => "Internal server error"
        )
    end
    
    return status, response
end

end # module
