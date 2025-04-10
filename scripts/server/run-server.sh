#!/bin/bash
# JuliaOS Server Runner
# This script finds and runs the Julia server regardless of the current directory

# Get the project root directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Check if julia directory exists
if [[ ! -d "$PROJECT_ROOT/julia" ]]; then
  echo "Error: Could not find julia directory at $PROJECT_ROOT/julia."
  echo "Please run this script from within the JuliaOS repository."
  exit 1
fi

# Change to the julia directory
cd "$PROJECT_ROOT/julia"
echo "Starting JuliaOS server from $(pwd)"

# Check if Julia is installed
if ! command -v julia &> /dev/null; then
  echo "Error: Julia is not installed or not in PATH."
  echo "Please install Julia 1.8 or later from https://julialang.org/downloads/"
  exit 1
fi

# Run the server
echo "Running with Julia $(julia --version)"
julia julia_server.jl