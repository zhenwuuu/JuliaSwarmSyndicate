#!/bin/bash

# Script to run the JuliaOS server

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Change to the julia directory
cd "$PROJECT_ROOT/julia"
echo "Starting JuliaOS server from $(pwd)"

# Check if Julia is installed
if ! command -v julia &> /dev/null; then
  echo "Error: Julia is not installed or not in PATH."
  echo "Please install Julia 1.8 or later from https://julialang.org/downloads/"
  exit 1
fi

# Parse command line arguments
PRECOMPILE=false
SKIP_PRECOMPILE=false
HOST="localhost"
PORT=8053

while [[ $# -gt 0 ]]; do
  case $1 in
    -p|--precompile)
      PRECOMPILE=true
      shift
      ;;
    -s|--skip-precompile)
      SKIP_PRECOMPILE=true
      shift
      ;;
    -h|--host)
      HOST="$2"
      shift 2
      ;;
    -P|--port)
      PORT="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [-p|--precompile] [-s|--skip-precompile] [-h|--host HOST] [-P|--port PORT]"
      exit 1
      ;;
  esac
done

# Build the command
CMD="julia run_server.jl"

if [ "$PRECOMPILE" = true ]; then
  CMD="$CMD --precompile"
fi

if [ "$SKIP_PRECOMPILE" = true ]; then
  CMD="$CMD --skip-precompile"
fi

# Run the server
echo "Running with Julia $(julia --version)"
echo "Starting JuliaOS server on $HOST:$PORT"
echo "Command: $CMD"

$CMD

# Check exit status
if [ $? -ne 0 ]; then
  echo "Error: JuliaOS server failed to start."
  exit 1
fi
