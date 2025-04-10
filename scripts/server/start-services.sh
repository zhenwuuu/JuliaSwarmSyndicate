#!/bin/bash

# Start all JuliaOS services
echo "Starting JuliaOS services..."

# Get the project root directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Start the Julia backend
echo "Starting Julia backend..."
cd "$PROJECT_ROOT/julia"
./start.sh &
JULIA_PID=$!
cd "$PROJECT_ROOT"

# Wait for Julia backend to initialize
echo "Waiting for Julia backend to initialize..."
sleep 5

# Start the Wormhole bridge service
echo "Starting Wormhole bridge service..."
cd "$PROJECT_ROOT/packages/bridges/wormhole"
./start.sh &
WORMHOLE_PID=$!
cd "$PROJECT_ROOT"

# Wait for Wormhole bridge service to initialize
echo "Waiting for Wormhole bridge service to initialize..."
sleep 3

echo "All services started successfully!"
echo "Julia backend PID: $JULIA_PID"
echo "Wormhole bridge service PID: $WORMHOLE_PID"
echo ""
echo "To stop all services, run: kill $JULIA_PID $WORMHOLE_PID"
echo ""
echo "To start the interactive CLI, run: node scripts/interactive.cjs"
