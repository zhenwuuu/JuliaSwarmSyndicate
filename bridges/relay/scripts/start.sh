#!/bin/bash

# Build TypeScript files
echo "Building TypeScript files..."
npm run build

# Start the relay service
echo "Starting relay service..."
npm start 