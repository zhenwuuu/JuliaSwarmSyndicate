#!/bin/bash

# setup_julia_bridge.sh - Script to set up Julia bridge for JuliaOS
# This script initializes the bridge between JavaScript and Julia

echo "Setting up Julia bridge..."

# Check if Julia is installed
if ! command -v julia &> /dev/null; then
    echo "Julia not found. Please install Julia first."
    exit 1
fi

# Check Julia version
JULIA_VERSION=$(julia --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
REQUIRED_VERSION="1.6.0"

# Compare versions using sort -V
if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$JULIA_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo "Julia version $JULIA_VERSION detected. Version $REQUIRED_VERSION or higher is required."
    exit 1
fi

echo "Julia $JULIA_VERSION detected."

# Create necessary directories
mkdir -p packages/julia-bridge/dist
mkdir -p julia/bridge

# Install required Julia packages
echo "Installing required Julia packages..."
julia -e 'using Pkg; Pkg.add(["HTTP", "WebSockets", "JSON", "DataFrames", "Plots", "SQLite", "TimeSeries", "Distributions"])'

# Initialize the Julia bridge
echo "Initializing Julia bridge..."
cat > julia/bridge/init.jl << 'EOF'
module BridgeInit

using HTTP
using WebSockets
using JSON

# Initialize the bridge
function initialize()
    println("Julia bridge initialized!")
    return Dict("status" => "initialized", "timestamp" => string(Dates.now()))
end

# Test connection
function test_connection()
    return Dict("status" => "connected", "timestamp" => string(Dates.now()))
end

end # module
EOF

# Create TypeScript interface for the bridge
echo "Creating TypeScript interface..."
cat > packages/julia-bridge/src/types.ts << 'EOF'
export interface JuliaBridgeOptions {
  apiUrl?: string;
  useWebSocket?: boolean;
  useExistingServer?: boolean;
  timeout?: number;
}

export interface CommandResponse {
  status: string;
  result?: any;
  error?: string;
  timestamp: string;
}
EOF

echo "Julia bridge setup complete!"
echo "You can now use the bridge to communicate between JavaScript and Julia." 