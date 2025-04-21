#!/bin/bash

# Script to generate documentation for JuliaOS

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Change to the julia directory
cd "$PROJECT_ROOT/julia"
echo "Generating JuliaOS documentation from $(pwd)"

# Check if Julia is installed
if ! command -v julia &> /dev/null; then
  echo "Error: Julia is not installed or not in PATH."
  echo "Please install Julia 1.8 or later from https://julialang.org/downloads/"
  exit 1
fi

# Run the documentation generator
echo "Running with Julia $(julia --version)"
julia generate_docs.jl

# Check exit status
if [ $? -ne 0 ]; then
  echo "Error: Documentation generation failed."
  exit 1
fi

# Open the documentation in a browser if available
DOCS_INDEX="$PROJECT_ROOT/docs/system.md"
if [ -f "$DOCS_INDEX" ]; then
  echo "Documentation generated successfully."
  echo "Documentation available at: $DOCS_INDEX"
  
  # Try to open the documentation in a browser
  if command -v open &> /dev/null; then
    echo "Opening documentation in browser..."
    open "$DOCS_INDEX"
  elif command -v xdg-open &> /dev/null; then
    echo "Opening documentation in browser..."
    xdg-open "$DOCS_INDEX"
  elif command -v start &> /dev/null; then
    echo "Opening documentation in browser..."
    start "$DOCS_INDEX"
  else
    echo "To view the documentation, open $DOCS_INDEX in your browser."
  fi
else
  echo "Error: Documentation index file not found."
  exit 1
fi
