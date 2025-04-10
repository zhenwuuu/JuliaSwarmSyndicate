# JuliaOS Bridges

This directory contains cross-chain bridge implementations for JuliaOS, enabling token transfers between different blockchains.

## Available Bridges

### 1. Relay Bridge

A custom bridge implementation that uses a relay service to monitor events and complete transfers between chains. Currently supports Base Sepolia and Solana.

**Features:**
- Simple interface
- Automatic completion via relay service
- Easy to understand and use
- Suitable for testing and development

### 2. Wormhole Bridge

A bridge implementation that integrates with the Wormhole protocol, enabling cross-chain token transfers between multiple blockchains.

**Features:**
- Support for multiple chains (Ethereum, Solana, BSC, Avalanche, Fantom, Arbitrum, Base)
- Direct integration with Wormhole protocol
- Secure VAA (Verified Action Approval) verification
- Token wrapping and unwrapping
- Suitable for production use

## Structure

- `relay/` - Relay service that monitors events across chains
- `solana-bridge/` - Solana-specific bridge implementation
- `wormhole/` - Wormhole protocol integration
- `examples/` - Usage examples and comparisons

## Components

Each bridge implementation includes:

1. Smart contracts or programs for the specific chain
2. Monitoring services to observe on-chain events
3. Transaction submission logic for cross-chain transfers

## Bridge Comparison

| Feature | Relay Bridge | Wormhole Bridge |
|---------|-------------|----------------|
| Chain Support | Limited (Base Sepolia, Solana) | Multiple chains |
| Implementation | Custom | Wormhole protocol |
| Completion | Automatic via relay | Manual VAA handling |
| Complexity | Simple | More complex |
| Security | Basic | High (VAA verification) |
| Use Case | Testing, development | Production |

## Development

Each bridge component can be developed and tested independently.

```bash
# Start Relay bridge development
cd relay
npm run dev

# Start Solana bridge development
cd solana-bridge
npm run dev

# Build Wormhole bridge
cd wormhole
npm run build

# Run bridge comparison example
cd examples
npx ts-node bridge-comparison.ts
```

## License

MIT