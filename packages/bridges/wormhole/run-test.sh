#!/bin/bash

# Compile TypeScript files
echo "Compiling TypeScript files..."
npx tsc src/simplified-bridge-service.ts src/utils/logger.ts --outDir dist --esModuleInterop true --target ES2020 --module CommonJS

# Run the test script
echo "Running test script..."
node test-bridge.js
