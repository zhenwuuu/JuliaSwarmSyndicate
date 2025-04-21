#!/bin/bash

# Run JuliaOS CLI with Julia server
# This script starts the Julia server and then runs the CLI

# Set environment variables
export JULIA_SERVER_HOST=${JULIA_SERVER_HOST:-localhost}
export JULIA_SERVER_PORT=${JULIA_SERVER_PORT:-8052}
export JULIA_SERVER_URL=${JULIA_SERVER_URL:-http://${JULIA_SERVER_HOST}:${JULIA_SERVER_PORT}}

# Start Julia server
echo "Starting Julia server..."
node scripts/start-julia-server.js

# Check if Julia server started successfully
if [ $? -ne 0 ]; then
    echo "Failed to start Julia server. Exiting."
    exit 1
fi

# Run CLI
echo "Starting JuliaOS CLI..."
node scripts/interactive.cjs
