#!/bin/bash

# Change to the script directory
cd "$(dirname "$0")"

# Install the JuliaOS Python wrapper with ADK dependencies
pip install -e .[adk]

# Test the installation
python -c "
try:
    from google.agent.sdk import Agent, AgentConfig
    print('Google ADK successfully installed!')
except ImportError as e:
    print(f'Error importing Google ADK: {e}')
"
