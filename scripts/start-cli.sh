#!/bin/bash

# Start JuliaOS CLI
# This script starts the Julia server and then runs the CLI

# Set the current directory to the script directory
cd "$(dirname "$0")"

# Check if Julia is installed
if ! command -v julia &> /dev/null; then
    echo "Error: Julia is not installed or not in PATH."
    echo "Please install Julia 1.8 or later from https://julialang.org/downloads/"
    exit 1
fi

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "Error: Node.js is not installed or not in PATH."
    echo "Please install Node.js 16 or later from https://nodejs.org/en/download/"
    exit 1
fi

# Start the Julia server
echo "Starting Julia server..."
cd julia
julia julia_server.jl &
JULIA_PID=$!

# Wait for the server to start
echo "Waiting for Julia server to start..."
sleep 5

# Check if the server is running
if ! curl -s http://localhost:8052/health > /dev/null; then
    echo "Warning: Julia server may not be running. The CLI will use mock implementations."
fi

# Start the CLI
echo "Starting JuliaOS CLI..."
cd ..
node scripts/interactive.cjs

# Kill the Julia server when the CLI exits
kill $JULIA_PID 2>/dev/null
