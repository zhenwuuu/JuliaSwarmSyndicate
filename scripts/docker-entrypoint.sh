#!/bin/bash

# Start Julia server in the background
cd /app/julia && julia --project=. server/julia_server.jl &
JULIA_PID=$!

# Wait for Julia server to start
echo "Waiting for Julia server to start..."
max_attempts=30
attempt=0

until curl -s http://localhost:8052/api/v1/health > /dev/null; do
  sleep 2
  attempt=$((attempt+1))
  
  # Check if we've reached the maximum number of attempts
  if [ $attempt -ge $max_attempts ]; then
    echo "Timed out waiting for Julia server to start."
    break
  fi
  
  # Check if Julia process is still running
  if ! kill -0 $JULIA_PID 2>/dev/null; then
    echo "Julia server failed to start. Starting mock server..."
    cd /app && node packages/cli/src/mock_server.js &
    MOCK_PID=$!
    sleep 2
    break
  fi
done

echo "Server is running. Starting CLI..."

# Check if the CLI file exists
CLI_PATH="/app/packages/cli/src/interactive.cjs"
if [ ! -f "$CLI_PATH" ]; then
  echo "Error: CLI file not found at $CLI_PATH"
  echo "Available files in /app/packages/cli/src:"
  ls -la /app/packages/cli/src
  exit 1
fi

# Start CLI
if [ "$1" = "cli" ]; then
  cd /app && node "$CLI_PATH"
else
  # Execute the passed command
  exec "$@"
fi

# Cleanup
if [ -n "$JULIA_PID" ]; then
  kill $JULIA_PID
fi
if [ -n "$MOCK_PID" ]; then
  kill $MOCK_PID
fi
