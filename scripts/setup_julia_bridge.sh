#!/bin/bash

# JuliaOS Bridge Setup Script
# This script sets up the Julia environment and JuliaOSBridge package

set -e  # Exit on error

echo "===================================="
echo "JuliaOS Bridge Setup Script"
echo "===================================="

# Check if Julia is installed
if ! command -v julia &> /dev/null; then
    echo "❌ Julia is not installed. Please install Julia 1.8 or later."
    exit 1
fi

JULIA_VERSION=$(julia --version | cut -d' ' -f3)
echo "✅ Julia is installed (version $JULIA_VERSION)"

# Detect the project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
if [[ $SCRIPT_DIR == *"/julia" ]]; then
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
    JULIA_DIR="$SCRIPT_DIR"
else
    PROJECT_ROOT="$SCRIPT_DIR"
    JULIA_DIR="$PROJECT_ROOT/julia"
fi

echo "Project root: $PROJECT_ROOT"
echo "Julia directory: $JULIA_DIR"

# Create the JuliaOSBridge directories if they don't exist
BRIDGE_DIR="$PROJECT_ROOT/packages/julia-bridge"
BRIDGE_SRC_DIR="$BRIDGE_DIR/src"

mkdir -p "$BRIDGE_SRC_DIR"
echo "✅ Created JuliaOSBridge directories"

# Check if Project.toml exists for JuliaOSBridge
if [ ! -f "$BRIDGE_DIR/Project.toml" ]; then
    echo "Creating Project.toml for JuliaOSBridge..."
    cat > "$BRIDGE_DIR/Project.toml" << EOF
name = "JuliaOSBridge"
uuid = "87654321-4321-8765-4321-876543210987"
authors = ["JuliaOS Contributors <contributors@juliaos.org>"]
version = "0.1.0"

[deps]
HTTP = "cd3eb016-35fb-5094-929b-558a96fad6f3"
JSON = "682c06a0-de6a-54ab-a142-c8b1cf79cde6"
WebSockets = "104b5d7c-a370-577a-8038-80a2059c5097"

[compat]
HTTP = "1.9.14"
JSON = "0.21.4"
WebSockets = "1.5.9"
julia = "1.8"
EOF
    echo "✅ Created Project.toml for JuliaOSBridge"
else
    echo "✅ Project.toml for JuliaOSBridge already exists"
fi

# Check if JuliaOSBridge.jl exists
if [ ! -f "$BRIDGE_SRC_DIR/JuliaOSBridge.jl" ]; then
    echo "Creating JuliaOSBridge.jl..."
    cat > "$BRIDGE_SRC_DIR/JuliaOSBridge.jl" << 'EOF'
module JuliaOSBridge

using HTTP
using WebSockets
using JSON

# Export key functions
export deserialize_command, serialize_response, handle_ts_request

"""
    deserialize_command(json_data::String)

Deserialize a command from TypeScript JSON format to a Julia Dict.
"""
function deserialize_command(json_data::String)
    try
        return JSON.parse(json_data)
    catch e
        @error "Failed to parse JSON command: $e"
        return Dict("error" => "Invalid JSON format", "status" => "error")
    end
end

"""
    serialize_response(response_data)

Serialize a Julia response to JSON format for TypeScript.
"""
function serialize_response(response_data)
    try
        return JSON.json(response_data)
    catch e
        @error "Failed to serialize response: $e"
        return JSON.json(Dict("error" => "Failed to serialize response", "status" => "error"))
    end
end

"""
    handle_ts_request(request::Dict)

Process a request from TypeScript and return the appropriate response.
"""
function handle_ts_request(request::Dict)
    try
        # Extract request information
        command = get(request, "command", "")
        params = get(request, "params", Dict())
        id = get(request, "id", "unknown")
        
        # Process different commands
        if command == "ping"
            return Dict("status" => "success", "id" => id, "result" => "pong", "timestamp" => string(now()))
        elseif command == "execute"
            # Execute Julia code (sanitized and restricted)
            func_name = get(params, "function", "")
            func_params = get(params, "params", Dict())
            
            # Handle the function execution
            return _execute_function(func_name, func_params, id)
        elseif command == "get_system_info"
            # Return system information
            return Dict(
                "status" => "success", 
                "id" => id,
                "result" => Dict(
                    "julia_version" => string(VERSION),
                    "platform" => string(Sys.KERNEL),
                    "arch" => string(Sys.ARCH),
                    "threads" => Threads.nthreads(),
                    "memory" => Dict(
                        "total" => Sys.total_memory() / (1024^3),  # GB
                        "free" => Sys.free_memory() / (1024^3)     # GB
                    )
                )
            )
        else
            return Dict("status" => "error", "id" => id, "error" => "Unknown command: $command")
        end
    catch e
        @error "Error handling TypeScript request: $e"
        return Dict("status" => "error", "id" => request["id"], "error" => string(e))
    end
end

"""
    _execute_function(func_name::String, func_params::Dict, id::String)

Execute a Julia function with the provided parameters.
"""
function _execute_function(func_name::String, func_params::Dict, id::String)
    try
        # Map of allowed functions (for security)
        # This should be expanded based on actual needs
        function_map = Dict(
            "math.add" => (p) -> p["a"] + p["b"],
            "math.subtract" => (p) -> p["a"] - p["b"],
            "math.multiply" => (p) -> p["a"] * p["b"],
            "math.divide" => (p) -> p["a"] / p["b"],
            "system.memory" => (p) -> Dict(
                "total" => Sys.total_memory() / (1024^3),
                "free" => Sys.free_memory() / (1024^3)
            )
            # Add more functions as needed
        )
        
        if haskey(function_map, func_name)
            result = function_map[func_name](func_params)
            return Dict("status" => "success", "id" => id, "result" => result)
        else
            return Dict("status" => "error", "id" => id, "error" => "Function not found or not allowed: $func_name")
        end
    catch e
        @error "Function execution error: $e"
        return Dict("status" => "error", "id" => id, "error" => string(e))
    end
end

# Initialize the bridge module
function __init__()
    @info "JuliaOSBridge module initialized"
end

end # module
EOF
    echo "✅ Created JuliaOSBridge.jl"
else
    echo "✅ JuliaOSBridge.jl already exists"
fi

# Run Julia setup script
echo "Running Julia setup script..."
cd "$JULIA_DIR"
julia setup.jl

# Run test bridge script
echo "Testing JuliaOSBridge..."
julia test_bridge.jl

echo "===================================="
echo "Setup complete!"
echo "You can now start the JuliaOS server by running:"
echo "cd $JULIA_DIR && julia start_server.jl"
echo "===================================="

# Make the troubleshoot script executable
chmod +x "$JULIA_DIR/troubleshoot.jl"
echo "For troubleshooting, you can run: $JULIA_DIR/troubleshoot.jl" 