# Bridges Directory

This directory contains all cross-chain bridge implementations for the JuliaOS Framework.

## Structure

- `relay/` - Relay service that monitors events across chains
- `solana-bridge/` - Solana-specific bridge implementation
- `ethereum-bridge/` - Ethereum-specific bridge implementation

## Components

Each bridge implementation includes:

1. Smart contracts or programs for the specific chain
2. Monitoring services to observe on-chain events
3. Transaction submission logic for cross-chain transfers

## Development

Each bridge component can be developed and tested independently.

```bash
# Start Ethereum bridge development
cd ethereum-bridge
npm run dev

# Start Solana bridge development
cd solana-bridge
npm run dev

# Start relay service
cd relay
npm run dev
``` 