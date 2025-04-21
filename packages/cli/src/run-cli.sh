#!/bin/bash

# Run JuliaOS CLI with Julia server
# This script starts the Julia server and then runs the CLI

# Set environment variables
export JULIA_SERVER_HOST=${JULIA_SERVER_HOST:-localhost}
export JULIA_SERVER_PORT=${JULIA_SERVER_PORT:-8054}  # Use a different port to avoid conflicts
export JULIA_SERVER_URL=${JULIA_SERVER_URL:-http://${JULIA_SERVER_HOST}:${JULIA_SERVER_PORT}}

# Start Julia server
echo "Starting Julia server..."

# Determine the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Try to find the Julia server script
JULIA_SERVER_SCRIPT="${SCRIPT_DIR}/../../../julia/server/julia_server.jl"
if [ ! -f "$JULIA_SERVER_SCRIPT" ]; then
    JULIA_SERVER_SCRIPT="${SCRIPT_DIR}/../../julia/server/julia_server.jl"
    if [ ! -f "$JULIA_SERVER_SCRIPT" ]; then
        echo "Julia server script not found. Will try to connect to existing server."
    else
        echo "Found Julia server script at $JULIA_SERVER_SCRIPT"
        # Start Julia server directly with environment variables
        cd "$(dirname "$JULIA_SERVER_SCRIPT")/.."
        JULIA_SERVER_PORT=$JULIA_SERVER_PORT JULIA_SERVER_HOST=$JULIA_SERVER_HOST julia --project=. server/julia_server.jl &
        JULIA_PID=$!
        echo "Started Julia server with PID $JULIA_PID"
        sleep 5  # Give the server time to start
    fi
else
    echo "Found Julia server script at $JULIA_SERVER_SCRIPT"
    # Start Julia server directly with environment variables
    cd "$(dirname "$JULIA_SERVER_SCRIPT")/.."
    JULIA_SERVER_PORT=$JULIA_SERVER_PORT JULIA_SERVER_HOST=$JULIA_SERVER_HOST julia --project=. server/julia_server.jl &
    JULIA_PID=$!
    echo "Started Julia server with PID $JULIA_PID"
    sleep 5  # Give the server time to start
fi

# Use the Node.js script as a fallback
node "$SCRIPT_DIR/start-julia-server.js"

# Check if Julia server started successfully
if [ $? -ne 0 ]; then
    echo "Failed to start Julia server. Exiting."
    exit 1
fi

# Run CLI
echo "Starting JuliaOS CLI..."
node src/interactive.cjs
