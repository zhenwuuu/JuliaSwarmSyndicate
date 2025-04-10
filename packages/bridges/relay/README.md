# Julia Bridge Relay Service

This service monitors events on Base Sepolia and Solana networks for the Julia Bridge protocol.

## Prerequisites

- Node.js v16 or higher
- npm v7 or higher
- Base Sepolia wallet with private key
- Solana Devnet wallet with private key array

## Setup

1. Install dependencies:
```bash
npm install
```

2. Create a `.env` file in the root directory with the following variables:
```env
# Network RPC URLs
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
SOLANA_RPC_URL=https://api.devnet.solana.com

# Contract Addresses
BASE_BRIDGE_CONTRACT=<your_base_bridge_contract>
SOLANA_PROGRAM_ID=<your_solana_program_id>

# Private Keys
PRIVATE_KEY=<your_base_private_key>
SOLANA_PRIVATE_KEY=<your_solana_private_key_array>

# Chain IDs
BASE_CHAIN_ID=84532
SOLANA_CHAIN_ID=1399811149

# Relay Configuration
POLLING_INTERVAL=5000
LOG_LEVEL=info
```

3. Build the project:
```bash
npm run build
```

## Usage

Start the relay service:
```bash
npm start
```

For development with auto-reloading:
```bash
npm run dev
```

## Development

Watch mode (automatically rebuild on changes):
```bash
npm run watch
```

## Architecture

The relay service consists of two main components:

1. Base Service (`src/services/base.ts`)
   - Monitors Base Sepolia network for bridge events
   - Handles token locking and releasing events

2. Solana Service (`src/services/solana.ts`)
   - Interacts with the Solana program
   - Processes cross-chain token transfers

## Environment Variables

- `BASE_SEPOLIA_RPC_URL`: Base Sepolia RPC endpoint
- `SOLANA_RPC_URL`: Solana RPC endpoint (Devnet)
- `BASE_BRIDGE_CONTRACT`: Address of the bridge contract on Base
- `SOLANA_PROGRAM_ID`: Solana program ID
- `PRIVATE_KEY`: Base wallet private key
- `SOLANA_PRIVATE_KEY`: Solana wallet private key array
- `BASE_CHAIN_ID`: Base Sepolia chain ID (84532)
- `SOLANA_CHAIN_ID`: Solana chain ID
- `POLLING_INTERVAL`: Event polling interval in milliseconds
- `LOG_LEVEL`: Winston logger level (info/debug/error) 