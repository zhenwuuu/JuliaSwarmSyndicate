module Middleware

export create_chain, process
export LoggingMiddleware, CorsMiddleware, JsonMiddleware
export ErrorHandlingMiddleware, AuthenticationMiddleware, RateLimitMiddleware

using HTTP
using JSON
using Logging
using Dates
using ..Types
using ..Errors
using ..Utils

# Abstract middleware type
abstract type AbstractMiddleware end

"""
    process(middleware::AbstractMiddleware, req::HTTP.Request, router)

Process a request through the middleware and pass it to the next middleware or router.
"""
function process end

"""
    create_chain(middlewares::Vector{AbstractMiddleware})

Create a middleware chain from a list of middlewares.
"""
function create_chain(middlewares::Vector{AbstractMiddleware})
    return middlewares
end

# Logging middleware
struct LoggingMiddleware <: AbstractMiddleware end

function process(middleware::LoggingMiddleware, req::HTTP.Request, next)
    start_time = now()
    @info "Request received" method=req.method target=req.target
    
    # Process the request
    try
        response = process(next, req, nothing)
        
        # Log the response
        duration_ms = Dates.value(now() - start_time)
        @info "Request completed" method=req.method target=req.target status=response.status duration_ms=duration_ms
        
        return response
    catch e
        # Log the error
        duration_ms = Dates.value(now() - start_time)
        @error "Request failed" method=req.method target=req.target error=e duration_ms=duration_ms
        rethrow(e)
    end
end

# CORS middleware
struct CorsMiddleware <: AbstractMiddleware end

function process(middleware::CorsMiddleware, req::HTTP.Request, next)
    # Handle preflight requests
    if req.method == "OPTIONS"
        return HTTP.Response(
            200,
            [
                "Access-Control-Allow-Origin" => "*",
                "Access-Control-Allow-Methods" => "GET, POST, PUT, DELETE, OPTIONS",
                "Access-Control-Allow-Headers" => "Content-Type, Authorization",
                "Access-Control-Max-Age" => "86400"
            ]
        )
    end
    
    # Process the request
    response = process(next, req, nothing)
    
    # Add CORS headers to the response
    push!(response.headers, "Access-Control-Allow-Origin" => "*")
    
    return response
end

# JSON middleware
struct JsonMiddleware <: AbstractMiddleware end

function process(middleware::JsonMiddleware, req::HTTP.Request, next)
    # Parse JSON request body if Content-Type is application/json
    if haskey(HTTP.headers(req), "Content-Type") && 
       HTTP.headers(req)["Content-Type"] == "application/json" &&
       !isempty(HTTP.payload(req))
        try
            body = JSON.parse(String(HTTP.payload(req)))
            req.body = body
        catch e
            return HTTP.Response(
                400,
                ["Content-Type" => "application/json"],
                JSON.json(Dict(
                    "success" => false,
                    "error" => "Invalid JSON in request body"
                ))
            )
        end
    end
    
    # Process the request
    response = process(next, req, nothing)
    
    # Convert response body to JSON if it's a Dict or Array
    if response.body isa Dict || response.body isa Array
        response.body = JSON.json(response.body)
        push!(response.headers, "Content-Type" => "application/json")
    end
    
    return response
end

# Error handling middleware
struct ErrorHandlingMiddleware <: AbstractMiddleware end

function process(middleware::ErrorHandlingMiddleware, req::HTTP.Request, next)
    try
        return process(next, req, nothing)
    catch e
        status, response = Errors.handle_error(e)
        
        return HTTP.Response(
            status,
            ["Content-Type" => "application/json"],
            JSON.json(response)
        )
    end
end

# Authentication middleware
struct AuthenticationMiddleware <: AbstractMiddleware end

function process(middleware::AuthenticationMiddleware, req::HTTP.Request, next)
    # Skip authentication for certain paths
    if req.target == "/health" || req.target == "/api/v1/health"
        return process(next, req, nothing)
    end
    
    # Check for Authorization header
    if !haskey(HTTP.headers(req), "Authorization")
        # For now, allow requests without authentication
        # In a real implementation, you would check if the endpoint requires authentication
        return process(next, req, nothing)
    end
    
    # Extract and validate the token
    auth_header = HTTP.headers(req)["Authorization"]
    if !startswith(auth_header, "Bearer ")
        return HTTP.Response(
            401,
            ["Content-Type" => "application/json"],
            JSON.json(Dict(
                "success" => false,
                "error" => "Invalid Authorization header format"
            ))
        )
    end
    
    token = auth_header[8:end]
    
    # Validate the token (mock implementation)
    # In a real implementation, you would verify the token signature
    if token == "invalid"
        return HTTP.Response(
            401,
            ["Content-Type" => "application/json"],
            JSON.json(Dict(
                "success" => false,
                "error" => "Invalid token"
            ))
        )
    end
    
    # Add user information to the request
    req.user = Dict(
        "id" => "user123",
        "role" => "user"
    )
    
    # Process the request
    return process(next, req, nothing)
end

# Rate limiting middleware
struct RateLimitMiddleware <: AbstractMiddleware 
    limit::Int
    window_seconds::Int
    
    RateLimitMiddleware(limit::Int=100, window_seconds::Int=60) = new(limit, window_seconds)
end

# Simple in-memory rate limiter (would use Redis or similar in production)
const rate_limit_store = Dict{String, Tuple{Int, Float64}}()

function process(middleware::RateLimitMiddleware, req::HTTP.Request, next)
    # Get client IP (or user ID if authenticated)
    client_id = get(req, :user, nothing) !== nothing ? req.user["id"] : HTTP.get_remote_address(req)
    
    # Get current count and window start time
    current_time = time()
    count, window_start = get(rate_limit_store, client_id, (0, current_time))
    
    # Reset if window has expired
    if current_time - window_start > middleware.window_seconds
        count = 0
        window_start = current_time
    end
    
    # Increment count
    count += 1
    
    # Update store
    rate_limit_store[client_id] = (count, window_start)
    
    # Check if rate limit exceeded
    if count > middleware.limit
        reset_after = Int(ceil(middleware.window_seconds - (current_time - window_start)))
        
        return HTTP.Response(
            429,
            [
                "Content-Type" => "application/json",
                "X-RateLimit-Limit" => string(middleware.limit),
                "X-RateLimit-Remaining" => "0",
                "X-RateLimit-Reset" => string(reset_after)
            ],
            JSON.json(Dict(
                "success" => false,
                "error" => "Rate limit exceeded",
                "limit" => middleware.limit,
                "reset_after" => reset_after
            ))
        )
    end
    
    # Add rate limit headers
    response = process(next, req, nothing)
    
    push!(response.headers, "X-RateLimit-Limit" => string(middleware.limit))
    push!(response.headers, "X-RateLimit-Remaining" => string(middleware.limit - count))
    push!(response.headers, "X-RateLimit-Reset" => string(Int(ceil(middleware.window_seconds - (current_time - window_start)))))
    
    return response
end

end # module
