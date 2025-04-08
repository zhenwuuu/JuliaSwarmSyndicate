#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# Check if .env file exists and source it
if [ -f /app/.env ]; then
  echo "Loading environment variables from /app/.env..."
  set -a # Automatically export all variables defined from now on
  source /app/.env
  set +a # Stop automatically exporting variables
else
  echo "Warning: /app/.env file not found. Running with default settings."
fi

# Execute the main command (passed from Dockerfile CMD)
# In our case, this will be "julia julia_server.jl"
echo "Starting Julia server..."
exec "$@" 