# JuliaOS Cross-Chain Router

A powerful cross-chain token routing module with swarm intelligence optimization for the JuliaOS Framework.

## Overview

The JuliaOS Cross-Chain Router provides advanced routing capabilities for transferring tokens between different blockchain networks. It leverages swarm intelligence algorithms implemented in Julia to find the most efficient routes based on customizable optimization criteria.

## Features

- **Multi-Chain Support**: Route tokens between Ethereum, Arbitrum, Optimism, Base, Polygon, and Solana
- **Swarm Intelligence**: Optimize routes using Julia-powered algorithms:
  - Particle Swarm Optimization (PSO)
  - Grey Wolf Optimizer (GWO)
  - Whale Optimization Algorithm (WOA)
- **Customizable Optimization**: Optimize for speed, cost, value, or a balanced approach
- **Bridge Integration**: Compatible with major cross-chain bridges
- **DEX Integration**: Support for on-chain swaps via DEXes
- **Gas Estimation**: Accurate gas cost prediction across chains
- **Path Visualization**: Clear visualization of multi-hop routes

## Installation

```bash
# Install from npm
npm install @juliaos/cross-chain-router

# Or add to your project
yarn add @juliaos/cross-chain-router
```

## Usage

### Basic Route Finding

```typescript
import { CrossChainRouter, ChainId } from '@juliaos/cross-chain-router';

// Initialize router
const router = new CrossChainRouter();

// Find routes from Ethereum to Arbitrum
const routes = await router.getRoutes({
  sourceChainId: ChainId.ETHEREUM,
  targetChainId: ChainId.ARBITRUM,
  sourceToken: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', // USDC on Ethereum
  targetToken: '0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8', // USDC on Arbitrum
  amount: '1000000000' // 1000 USDC (with 6 decimals)
});

// Access the best route
console.log('Best route:', routes.bestRoute);
```

### Executing a Route

```typescript
import { CrossChainRouter } from '@juliaos/cross-chain-router';

// Initialize router
const router = new CrossChainRouter();

// Execute a route
const execution = await router.executeRoute({
  routeId: 'route-123',
  sender: '0x1234...5678',
  recipient: '0x8765...4321'
});

// Check execution status
const status = await router.getRouteStatus(execution.routeId);
console.log('Status:', status.status);
```

### Optimizing with Julia Swarm Intelligence

```typescript
import { JuliaSwarmOptimizer, PathOptimizationParams } from '@juliaos/cross-chain-router';

// Initialize optimizer
const optimizer = new JuliaSwarmOptimizer();

// Check if Julia is available
const juliaAvailable = optimizer.isJuliaAvailable();

// Optimize routes
if (juliaAvailable) {
  const optimizationParams: PathOptimizationParams = {
    optimizeFor: 'balanced',
    maxRoutes: 5,
    useSwarm: true,
    swarmSize: 30,
    learningRate: 0.2,
    maxIterations: 100
  };
  
  const result = await optimizer.optimizeRoutes(routes, optimizationParams);
  console.log('Optimized routes:', result.optimizedRoutes);
}
```

## Integration with CLI

The Cross-Chain Router is integrated with the JuliaOS CLI:

```bash
# Find optimal routes for token transfers
j3os cross-chain route

# List saved routes
j3os cross-chain list

# Test Julia swarm performance
j3os cross-chain test-swarm
```

## Configuration Options

```typescript
const router = new CrossChainRouter({
  preferredBridges: ['hop', 'across', 'stargate'],
  preferredDexes: ['uniswap', 'sushiswap'],
  maxHops: 3,
  maxBridges: 2,
  minLiquidity: 10000, // $10,000 minimum liquidity
  slippageTolerance: 0.5, // 0.5%
  timeout: 30000 // 30 seconds
});
```

## Julia Integration

The router uses Julia for advanced swarm optimization algorithms. To enable this feature:

1. Install Julia (v1.8 or later) from [julialang.org](https://julialang.org/downloads/)
2. Add Julia to your PATH
3. Install required Julia packages:

```bash
# Set up Julia environment
j3os setup-julia
```

## License

MIT 