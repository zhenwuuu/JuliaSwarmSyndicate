#!/bin/bash

# Exit on first error
set -e

# Build TypeScript files
echo "Building TypeScript files..."
npm run build

# Start the relay service
echo "Starting relay service..."
node dist/relay.js
