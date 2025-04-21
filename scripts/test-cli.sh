#!/bin/bash

# Test JuliaOS CLI
# This script tests the JuliaOS CLI by running it with various commands

# Set environment variables
export JULIA_SERVER_HOST=${JULIA_SERVER_HOST:-localhost}
export JULIA_SERVER_PORT=${JULIA_SERVER_PORT:-8052}
export JULIA_SERVER_URL=${JULIA_SERVER_URL:-http://${JULIA_SERVER_HOST}:${JULIA_SERVER_PORT}}

# Check if Julia server is running
echo "Checking if Julia server is running..."
if curl -s "$JULIA_SERVER_URL/health" > /dev/null; then
    echo "Julia server is running"
else
    echo "Julia server is not running. Starting Julia server..."
    ./scripts/run-julia-server.sh &
    # Wait for server to start
    echo "Waiting for Julia server to start..."
    for i in {1..30}; do
        if curl -s "$JULIA_SERVER_URL/health" > /dev/null; then
            echo "Julia server started"
            break
        fi
        sleep 1
        echo -n "."
    done
    if ! curl -s "$JULIA_SERVER_URL/health" > /dev/null; then
        echo "Failed to start Julia server. Exiting."
        exit 1
    fi
fi

# Run CLI
echo "Running CLI..."
node scripts/interactive.cjs
