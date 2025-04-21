#!/bin/bash

# Script to index the JuliaOS codebase

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default output path
OUTPUT_PATH="$PROJECT_ROOT/codebase_index.json"

# Parse command line arguments
if [ $# -gt 0 ]; then
  OUTPUT_PATH="$1"
fi

echo "Indexing JuliaOS codebase..."
echo "Project root: $PROJECT_ROOT"
echo "Output path: $OUTPUT_PATH"

# Change to the julia directory
cd "$PROJECT_ROOT/julia"

# Check if Julia is installed
if ! command -v julia &> /dev/null; then
  echo "Error: Julia is not installed or not in PATH."
  echo "Please install Julia 1.8 or later from https://julialang.org/downloads/"
  exit 1
fi

# Run the indexing script
echo "Running with Julia $(julia --version)"
julia --project index_codebase.jl "$OUTPUT_PATH"

# Check exit status
if [ $? -ne 0 ]; then
  echo "Error: Indexing failed."
  exit 1
fi

echo "Indexing completed successfully!"
echo "Index saved to: $OUTPUT_PATH"
