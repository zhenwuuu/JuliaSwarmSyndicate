#!/bin/bash

# JuliaOS CLI Startup Script
# This script checks if the server is running, starts the mock server if needed,
# and then launches the CLI.

# Print banner
echo "JuliaOS CLI"
echo "==========="
echo

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed or not in PATH"
    echo "Please install Node.js from https://nodejs.org/"
    exit 1
fi

# Check Node.js version
NODE_VERSION=$(node --version)
echo "✅ Node.js $NODE_VERSION found"

# Set working directory
cd "$(dirname "$0")"

# Check if the server is running
echo "Checking if the server is running..."
if curl -s http://localhost:8052/health > /dev/null; then
    echo "✅ Server is running"
else
    echo "⚠️ Server is not running"

    # Check if Julia is installed
    if command -v julia &> /dev/null; then
        JULIA_VERSION=$(julia --version | awk '{print $3}')
        echo "✅ Julia $JULIA_VERSION found"

        # Try to start the Julia server
        echo "Attempting to start the Julia server..."
        cd julia
        julia julia_server.jl &
        SERVER_PID=$!
        cd ..

        # Wait for the server to start
        echo "Waiting for server to start..."
        sleep 5

        # Check if the server started successfully
        if curl -s http://localhost:8052/health > /dev/null; then
            echo "✅ Julia server started successfully"
        else
            echo "❌ Failed to start Julia server"

            # Kill the Julia server process if it's still running
            if ps -p $SERVER_PID > /dev/null; then
                kill $SERVER_PID
            fi

            # Start the simple mock server instead
            echo "Starting simple mock server instead..."
            node scripts/simple_mock_server.js &
            MOCK_SERVER_PID=$!

            # Wait for the mock server to start
            echo "Waiting for mock server to start..."
            sleep 5

            # Check if the mock server started successfully
            if curl -s http://localhost:8052/health > /dev/null; then
                echo "✅ Mock server started successfully"
            else
                echo "❌ Failed to start mock server"
                echo "Please check the logs for errors"
                exit 1
            fi
        fi
    else
        echo "⚠️ Julia is not installed"
        echo "Starting simple mock server instead..."

        # Start the simple mock server
        node scripts/simple_mock_server.js &
        MOCK_SERVER_PID=$!

        # Wait for the mock server to start
        echo "Waiting for mock server to start..."
        sleep 5

        # Check if the mock server started successfully
        if curl -s http://localhost:8052/health > /dev/null; then
            echo "✅ Mock server started successfully"
        else
            echo "❌ Failed to start mock server"
            echo "Please check the logs for errors"
            exit 1
        fi
    fi
fi

# Start the CLI
echo
echo "Starting JuliaOS CLI..."
node scripts/interactive.cjs

# Clean up
if [ -n "$SERVER_PID" ] && ps -p $SERVER_PID > /dev/null; then
    echo "Stopping Julia server..."
    kill $SERVER_PID
fi

if [ -n "$MOCK_SERVER_PID" ] && ps -p $MOCK_SERVER_PID > /dev/null; then
    echo "Stopping mock server..."
    kill $MOCK_SERVER_PID
fi

echo
echo "Done!"
