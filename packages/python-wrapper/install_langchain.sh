#!/bin/bash

# Change to the script directory
cd "$(dirname "$0")"

# Install the JuliaOS Python wrapper with LangChain dependencies
pip install -e .[langchain]

# Install LLM provider packages
pip install langchain-openai langchain-anthropic

# Test the installation
python test_langchain_imports.py
