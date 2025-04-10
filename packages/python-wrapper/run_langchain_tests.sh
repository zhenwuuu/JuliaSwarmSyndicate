#!/bin/bash

# Change to the script directory
cd "$(dirname "$0")"

# Check if pytest is installed
if ! command -v pytest &> /dev/null; then
    echo "pytest is not installed. Installing..."
    pip install pytest pytest-asyncio
fi

# Check if langchain is installed
if ! python -c "import langchain" &> /dev/null; then
    echo "langchain is not installed. Installing..."
    pip install langchain langchain-core langchain-community
fi

# Run the import tests first
echo "Running LangChain import tests..."
python test_langchain_imports.py

# Run the unit tests for LangChain integration
echo "Running unit tests for LangChain integration..."
pytest -xvs tests/unit/test_langchain_integration.py tests/unit/test_langchain_retrievers.py

# Run the end-to-end tests for LangChain integration
echo "Running end-to-end tests for LangChain integration..."
pytest -xvs tests/e2e/test_langchain_integration.py tests/e2e/test_langchain_retrievers.py
