#!/bin/bash

# Start the Wormhole bridge service
echo "Starting Wormhole bridge service..."

# Set environment variables
export WORMHOLE_BRIDGE_PORT=3001
export WALLET_API_PORT=3002
export ETH_RPC_URL="https://eth-mainnet.g.alchemy.com/v2/your-api-key"
export SOLANA_RPC_URL="https://api.mainnet-beta.solana.com"
export BSC_RPC_URL="https://bsc-dataseed.binance.org"
export AVAX_RPC_URL="https://api.avax.network/ext/bc/C/rpc"
export FANTOM_RPC_URL="https://rpcapi.fantom.network"
export ARBITRUM_RPC_URL="https://arb1.arbitrum.io/rpc"
export BASE_RPC_URL="https://mainnet.base.org"

# Navigate to the package directory
cd "$(dirname "$0")"

# Compile TypeScript for simplified bridge service
echo "Compiling TypeScript for simplified bridge service..."
npx tsc src/simplified-index.ts src/simplified-bridge-api.ts src/simplified-bridge-service.ts src/simplified-register-service.ts src/utils/logger.ts --outDir dist --esModuleInterop true --target ES2020 --module CommonJS

# Start the simplified bridge service
echo "Starting simplified bridge service..."
node dist/simplified-index.js
