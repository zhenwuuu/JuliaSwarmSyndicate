#!/bin/bash
# JuliaOS Server Runner
# This script finds and runs the Julia server regardless of the current directory

# Find the repository root by looking for a marker file
find_repo_root() {
  local current_dir="$PWD"
  while [[ "$current_dir" != "/" ]]; do
    if [[ -d "$current_dir/julia" && -f "$current_dir/julia/standalone_server.jl" ]]; then
      echo "$current_dir"
      return 0
    fi
    current_dir="$(dirname "$current_dir")"
  done
  return 1
}

# Get repository root
REPO_ROOT=$(find_repo_root)

if [[ -z "$REPO_ROOT" ]]; then
  echo "Error: Could not find repository root with julia/standalone_server.jl."
  echo "Please run this script from within the JuliaOS repository."
  exit 1
fi

# Change to the julia directory
cd "$REPO_ROOT/julia"
echo "Starting JuliaOS server from $(pwd)"

# Check if Julia is installed
if ! command -v julia &> /dev/null; then
  echo "Error: Julia is not installed or not in PATH."
  echo "Please install Julia 1.8 or later from https://julialang.org/downloads/"
  exit 1
fi

# Run the server
echo "Running with Julia $(julia --version)"
julia standalone_server.jl