#!/bin/bash

# Change to the script directory
cd "$(dirname "$0")"

# Run the import tests
python -m unittest tests/unit/test_langchain_imports.py
