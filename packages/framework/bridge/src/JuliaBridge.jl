module JuliaBridge

export connect, disconnect, execute, isConnected, healthCheck,
       BridgeConfig, BridgeException, BridgeResponse,
       WormholeBridge

using HTTP
using JSON3
using Sockets
using Dates

# Include Wormhole bridge module
include("wormhole/WormholeBridge.jl")

"""
    BridgeConfig

Configuration for connecting to the JuliaOS backend server.

# Fields
- `host::String`: Host address (default: "localhost")
- `port::Int`: Port number (default: 8052)
- `apiPath::String`: API path for commands (default: "/api/command")
- `healthPath::String`: Health check endpoint (default: "/health")
- `timeout::Int`: Connection timeout in seconds (default: 30)
"""
struct BridgeConfig
    host::String
    port::Int
    apiPath::String
    healthPath::String
    timeout::Int

    BridgeConfig(;
        host="localhost",
        port=8052,
        apiPath="/api/command",
        healthPath="/health",
        timeout=30
    ) = new(host, port, apiPath, healthPath, timeout)
end

"""
    BridgeException

Exception raised when bridge operations fail.

# Fields
- `message::String`: Error message
- `code::Int`: Error code
"""
struct BridgeException <: Exception
    message::String
    code::Int
end

"""
    BridgeResponse

Response from the JuliaOS backend.

# Fields
- `success::Bool`: Whether the operation was successful
- `data::Any`: Response data (if successful)
- `error::Union{String, Nothing}`: Error message (if unsuccessful)
- `timestamp::DateTime`: Response timestamp
"""
struct BridgeResponse
    success::Bool
    data::Any
    error::Union{String, Nothing}
    timestamp::DateTime
end

# Global state
const _state = Dict(
    "connected" => false,
    "config" => BridgeConfig(),
    "lastError" => nothing
)

"""
    connect(config::BridgeConfig=BridgeConfig())

Connect to the JuliaOS backend server.

# Arguments
- `config::BridgeConfig`: Connection configuration

# Returns
- `Bool`: true if connected successfully, false otherwise
"""
function connect(config::BridgeConfig=BridgeConfig())
    try
        # Store the configuration
        _state["config"] = config

        # Check if the server is reachable with a health check
        result = healthCheck()
        if result.success
            _state["connected"] = true
            return true
        else
            _state["lastError"] = "Failed to connect: $(result.error)"
            return false
        end
    catch e
        _state["lastError"] = "Connection error: $(e)"
        return false
    end
end

"""
    disconnect()

Disconnect from the JuliaOS backend server.

# Returns
- `Bool`: true if disconnected successfully
"""
function disconnect()
    _state["connected"] = false
    return true
end

"""
    isConnected()

Check if currently connected to the JuliaOS backend.

# Returns
- `Bool`: true if connected, false otherwise
"""
function isConnected()
    return _state["connected"]
end

"""
    healthCheck()

Check the health of the JuliaOS backend server.

# Returns
- `BridgeResponse`: Response with server health status
"""
function healthCheck()
    config = _state["config"]
    url = "http://$(config.host):$(config.port)$(config.healthPath)"

    try
        response = HTTP.get(url, connect_timeout=config.timeout)
        if response.status == 200
            data = JSON3.read(String(response.body))
            return BridgeResponse(true, data, nothing, now())
        else
            return BridgeResponse(false, nothing, "Health check failed with status $(response.status)", now())
        end
    catch e
        return BridgeResponse(false, nothing, "Health check error: $(e)", now())
    end
end

"""
    execute(functionPath::String, params::Dict{String, Any}=Dict{String, Any}())

Execute a function on the JuliaOS backend.

# Arguments
- `functionPath::String`: Path to the function (e.g., "AgentSystem.createAgent")
- `params::Dict{String, Any}`: Parameters for the function

# Returns
- `BridgeResponse`: Response from the backend
"""
function execute(functionPath::String, params::Dict{String, Any}=Dict{String, Any}())
    if !isConnected()
        throw(BridgeException("Not connected to JuliaOS backend", 1))
    end

    config = _state["config"]
    url = "http://$(config.host):$(config.port)$(config.apiPath)"

    # Prepare payload
    payload = Dict(
        "function" => functionPath,
        "params" => params,
        "timestamp" => string(now())
    )

    try
        # Send request to the backend
        response = HTTP.post(
            url,
            ["Content-Type" => "application/json"],
            JSON3.write(payload),
            connect_timeout=config.timeout
        )

        if response.status == 200
            data = JSON3.read(String(response.body))
            if haskey(data, "error") && data.error !== nothing
                return BridgeResponse(false, nothing, data.error, now())
            else
                return BridgeResponse(true, data.result, nothing, now())
            end
        else
            return BridgeResponse(
                false,
                nothing,
                "Request failed with status $(response.status)",
                now()
            )
        end
    catch e
        return BridgeResponse(false, nothing, "Execution error: $(e)", now())
    end
end

end # module