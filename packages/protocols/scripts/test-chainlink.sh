#!/bin/bash

# Run the Chainlink integration test
echo "Running Chainlink integration test..."
npx ts-node src/dex/test-chainlink.ts
