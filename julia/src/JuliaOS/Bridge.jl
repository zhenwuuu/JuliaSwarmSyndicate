module Bridge

using HTTP
using WebSockets
using JSON
using Logging
using Dates
using JuliaOSBridge

export check_connections, send_command, receive_data, register_callback, start_bridge, stop_bridge, CONNECTION

"""
Bridge connection status and WebSocket client
"""
mutable struct BridgeConnection
    url::String
    port::Int
    is_connected::Bool
    socket::Union{Nothing, WebSockets.WebSocket}
    last_message::Union{Nothing, Dict}
    callbacks::Dict{String, Function}
    request_id::Int
    pending_requests::Dict{String, Channel}
end

# Global connection instance
const CONNECTION = BridgeConnection(
    "localhost",  # url
    8052,         # port
    false,        # is_connected
    nothing,      # socket
    nothing,      # last_message
    Dict(),       # callbacks
    0,            # request_id
    Dict()        # pending_requests
)

"""
    check_connections()

Check if the bridge connections are healthy.
Return a Dict with connection statuses.
"""
function check_connections()
    return Dict(
        "status" => CONNECTION.is_connected ? "healthy" : "disconnected",
        "active_connections" => CONNECTION.is_connected ? 1 : 0,
        "last_check" => now()
    )
end

"""
    generate_request_id()

Generate a unique request ID for WebSocket messages.
"""
function generate_request_id()
    CONNECTION.request_id += 1
    return string(CONNECTION.request_id)
end

"""
    send_command(service, command, params)

Send a command to the TypeScript bridge and wait for response.
"""
function send_command(service, command, params)
    if !CONNECTION.is_connected
        try
            # Try to start the bridge if not connected
            if !start_bridge()
                @warn "Bridge not connected and failed to connect."
                return Dict(
                    "success" => false,
                    "error" => "Bridge not connected and failed to connect."
                )
            end
        catch e
            @error "Error starting bridge" exception=(e, catch_backtrace())
            return Dict(
                "success" => false,
                "error" => "Failed to start bridge: $(e)"
            )
        end
    end
    
    # Forward the command to JuliaOSBridge
    try
        request_id = generate_request_id()
        
        # Create a channel for this request
        response_channel = Channel{Dict}(1)
        CONNECTION.pending_requests[request_id] = response_channel
        
        # Create the message
        message = Dict(
            "id" => request_id,
            "service" => service,
            "command" => command,
            "params" => params
        )
        
        # Send command via JuliaOSBridge
        @info "Sending command to bridge: $service.$command"
        result = JuliaOSBridge.send_command(message, nothing)
        
        # If using direct communication, we got a result immediately
        if haskey(result, "data")
            delete!(CONNECTION.pending_requests, request_id)
            return Dict(
                "success" => true,
                "data" => result["data"]
            )
        end
        
        # Otherwise, wait for response via channel (with timeout)
        response = nothing
        @async begin
            sleep(30)  # 30 second timeout
            if haskey(CONNECTION.pending_requests, request_id)
                put!(response_channel, Dict(
                    "success" => false,
                    "error" => "Timeout waiting for response"
                ))
            end
        end
        
        response = take!(response_channel)
        delete!(CONNECTION.pending_requests, request_id)
        
        return response
    catch e
        @error "Error sending command" exception=(e, catch_backtrace())
        return Dict(
            "success" => false,
            "error" => "Error sending command: $(e)"
        )
    end
end

"""
    handle_bridge_message(message_data)

Handle a message from the bridge.
"""
function handle_bridge_message(message_data)
    try
        message = JSON.parse(message_data)
        
        # Check if this is a response to a pending request
        if haskey(message, "id") && haskey(CONNECTION.pending_requests, message["id"])
            request_id = message["id"]
            channel = CONNECTION.pending_requests[request_id]
            
            # Send response to waiting thread
            put!(channel, message)
            
        # Otherwise, it's an event or other message
        elseif haskey(message, "event") && haskey(CONNECTION.callbacks, message["event"])
            event_name = message["event"]
            callback = CONNECTION.callbacks[event_name]
            
            # Execute callback
            @async callback(message["data"])
        else
            @warn "Received unexpected message: $message"
        end
    catch e
        @error "Error handling bridge message" exception=(e, catch_backtrace())
    end
end

"""
    receive_data(source)

Receive data from the specified source.
"""
function receive_data(source)
    @info "Receiving data from: $source"
    return Dict(
        "status" => "success",
        "source" => source,
        "data" => nothing
    )
end

"""
    register_callback(event, callback)

Register a callback for a specific event.
"""
function register_callback(event, callback)
    CONNECTION.callbacks[event] = callback
    @info "Registered callback for event: $event"
    return true
end

"""
    start_bridge(; url=nothing, port=nothing)

Start the bridge with the given configuration.
"""
function start_bridge(; url=nothing, port=nothing)
    if CONNECTION.is_connected
        @info "Bridge already connected"
        return true
    end
    
    # Update connection settings if provided
    if url !== nothing
        CONNECTION.url = url
    end
    
    if port !== nothing
        CONNECTION.port = port
    end
    
    try
        # Initialize JuliaOSBridge
        @info "Initializing JuliaOSBridge with URL: $(CONNECTION.url):$(CONNECTION.port)"
        
        # Setup message handler
        JuliaOSBridge.on_message(handle_bridge_message)
        
        # Initialize the bridge
        bridge_options = Dict(
            "url" => CONNECTION.url,
            "port" => CONNECTION.port
        )
        
        init_result = JuliaOSBridge.init_bridge(bridge_options)
        
        if init_result
            CONNECTION.is_connected = true
            @info "Bridge started successfully"
            return true
        else
            @error "Failed to initialize JuliaOSBridge"
            return false
        end
    catch e
        CONNECTION.is_connected = false
        @error "Failed to start bridge" exception=(e, catch_backtrace())
        return false
    end
end

"""
    stop_bridge()

Stop the bridge.
"""
function stop_bridge()
    if !CONNECTION.is_connected
        @info "Bridge not connected"
        return true
    end
    
    try
        # Close JuliaOSBridge
        JuliaOSBridge.close_bridge()
        
        # Update connection status
        CONNECTION.is_connected = false
        
        @info "Bridge stopped successfully"
        return true
    catch e
        @error "Failed to stop bridge" exception=(e, catch_backtrace())
        return false
    end
end

end # module