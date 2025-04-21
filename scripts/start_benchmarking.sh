#!/bin/bash

# JuliaOS Benchmarking Startup Script
# This script sets up the environment and starts the benchmarking server

# Print banner
echo "JuliaOS Benchmarking"
echo "===================="
echo

# Check if Julia is installed
if ! command -v julia &> /dev/null; then
    echo "❌ Julia is not installed or not in PATH"
    echo "Please install Julia from https://julialang.org/downloads/"
    exit 1
fi

# Check Julia version
JULIA_VERSION=$(julia --version | awk '{print $3}')
echo "✅ Julia $JULIA_VERSION found"

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed or not in PATH"
    echo "Please install Node.js from https://nodejs.org/"
    exit 1
fi

# Check Node.js version
NODE_VERSION=$(node --version)
echo "✅ Node.js $NODE_VERSION found"

# Set up the environment
echo
echo "Setting up the environment..."
cd "$(dirname "$0")"
julia julia/setup_environment.jl

# Check if port 8052 is available
if lsof -Pi :8052 -sTCP:LISTEN -t >/dev/null ; then
    echo
    echo "⚠️ Port 8052 is already in use"
    echo "Attempting to kill the process..."
    
    # Try to kill the process
    PID=$(lsof -Pi :8052 -sTCP:LISTEN -t)
    if kill -9 $PID 2>/dev/null; then
        echo "✅ Process killed successfully"
    else
        echo "❌ Failed to kill the process"
        echo "Please manually kill the process using port 8052 and try again"
        exit 1
    fi
fi

# Start the benchmarking server
echo
echo "Starting the benchmarking server..."
julia julia/benchmarking_server.jl &
SERVER_PID=$!

# Wait for the server to start
echo "Waiting for server to start..."
sleep 5

# Check if the server is running
if ! curl -s http://localhost:8052/health > /dev/null; then
    echo "❌ Failed to start the benchmarking server"
    echo "Please check the logs for errors"
    exit 1
fi

echo "✅ Benchmarking server started successfully"

# Run the benchmarking CLI
echo
echo "Running the benchmarking CLI..."
node scripts/commands/benchmark.js

# Clean up
echo
echo "Cleaning up..."
kill $SERVER_PID 2>/dev/null

echo
echo "Done!"
