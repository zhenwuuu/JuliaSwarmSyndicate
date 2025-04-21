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
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
JULIA_DIR="$SCRIPT_DIR"
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
    echo "Running setup script from scripts directory..."
    cd "$PROJECT_ROOT" && ./scripts/setup_julia_bridge.sh
fi

# Kill any existing server
pkill -f "julia julia_server.jl" || true

# Export variables from .env file before starting Julia
if [ -f ".env" ]; then
  echo "Loading environment variables from .env..."
  set -a # Automatically export all variables defined from now on
  source .env
  set +a # Stop automatically exporting variables
else
  echo "Warning: .env file not found. Skipping environment variable loading."
fi

# Start the server
echo "Starting Julia server..."
cd "$JULIA_DIR" && julia julia_server.jl

# Comment out waiting and health check as server runs in foreground
# echo "Waiting for server to start..."
# sleep 2
#
# # Test server
# echo "Testing server health..."
# HEALTH_CHECK=$(curl -s http://localhost:8052/health)
# if [ $? -eq 0 ]; then
#     echo "✅ Server is running: $HEALTH_CHECK"
#     # echo "Server is running in the background (PID: $!)" # No longer in background
#     # echo "To stop the server: pkill -f 'julia julia_server.jl'" # Use Ctrl+C
# else
#     echo "❌ Server failed to start. Check the logs."
#     exit 1
# fi
#
# echo "====================================="
# echo "Server running at http://localhost:8052" # Will likely show logs instead
# echo "Health check available at http://localhost:8052/health"
# echo "=====================================" 