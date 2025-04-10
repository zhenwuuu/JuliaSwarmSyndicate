#!/bin/bash

# JuliaOS Server Start Script
# This script starts the Julia server and ensures the JuliaOSBridge is properly set up

set -e  # Exit on error

echo "===================================="
echo "JuliaOS Server Start Script"
echo "===================================="

# Detect script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Define directories
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
JULIA_DIR="$PROJECT_ROOT/julia"
BRIDGE_DIR="$PROJECT_ROOT/packages/julia-bridge"

# Check for Julia
if ! command -v julia &> /dev/null; then
    echo "❌ Julia is not installed. Please install Julia 1.8 or later."
    exit 1
fi

JULIA_VERSION=$(julia --version | cut -d' ' -f3)
echo "✅ Julia is installed (version $JULIA_VERSION)"

# Check for bridge files
if [ ! -d "$BRIDGE_DIR" ]; then
    echo "❌ Bridge directory not found at $BRIDGE_DIR"
    echo "Running setup_julia_bridge.sh to set up the bridge..."
    cd "$SCRIPT_DIR" && ./setup_julia_bridge.sh
fi

# Kill any existing server
pkill -f "julia julia_server.jl" || true

# Start the server
echo "Starting Julia server..."
cd "$JULIA_DIR" && julia julia_server.jl &

# Wait for server to start
echo "Waiting for server to start..."
sleep 2

# Test server
echo "Testing server health..."
HEALTH_CHECK=$(curl -s http://localhost:8052/health)
if [ $? -eq 0 ]; then
    echo "✅ Server is running: $HEALTH_CHECK"
    echo "Server is running in the background (PID: $!)"
    echo "To stop the server: pkill -f 'julia julia_server.jl'"
else
    echo "❌ Server failed to start. Check the logs."
    exit 1
fi

echo "===================================="
echo "Server running at http://localhost:8052"
echo "Health check available at http://localhost:8052/health"
echo "===================================="