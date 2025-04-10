#!/bin/bash

# Change to the script directory
cd "$(dirname "$0")"

# Check if pytest is installed
if ! command -v pytest &> /dev/null; then
    echo "pytest is not installed. Installing..."
    pip install pytest pytest-asyncio
fi

# Run the tests
echo "Running unit tests..."
pytest -xvs tests/unit

echo "Running end-to-end tests..."
pytest -xvs tests/e2e
