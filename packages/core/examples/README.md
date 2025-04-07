# JuliaOS Core Examples

This directory contains example applications demonstrating how the various components of the JuliaOS framework work together.

## Prerequisites

Before running these examples, make sure you have:

1. Installed Julia 1.8 or higher
2. Installed Node.js 18 or higher
3. Set up environment variables (see `.env.example` in the root directory)
4. Built the TypeScript code with `npm run build` from the packages/core directory

## Available Examples

### 1. Optimization Example

The `optimization-example.ts` demonstrates how to use the Julia-TypeScript bridge for optimization tasks:

```bash
# Run the optimization example
npx ts-node examples/optimization-example.ts
```

This example:
- Initializes the JuliaBridge
- Defines an objective function (Rosenbrock function)
- Runs two different optimization algorithms (PSO and ACO)
- Compares the results of both algorithms
- Shows proper error handling and cleanup

### 2. Cross-Chain DeFi Example

The `defi-example.ts` demonstrates how to use the DeFiTradingSkill with JuliaOS:

```bash
# Run the DeFi example
npx ts-node examples/defi-example.ts
```

This example:
- Creates a SwarmAgent with DeFiTradingSkill
- Sets up cross-chain monitoring
- Fetches market data from Uniswap
- Uses Julia for optimization of strategy parameters
- Simulates trade execution based on optimized parameters

### 3. Agent Storage Example

The `storage-example.ts` shows how to use the persistent storage system:

```bash
# Run the storage example
npx ts-node examples/storage-example.ts
```

This example:
- Initializes the AgentStorage system
- Saves agent state to persistent storage
- Retrieves and updates agent state
- Demonstrates backup and restore functionality

## Architecture Overview

The examples demonstrate the three key layers of the JuliaOS architecture:

1. **Bridge Layer**: TypeScript-Julia communication via WebSockets
2. **Agent Layer**: Swarm agents with specialized skills
3. **Storage Layer**: Persistent storage for agent state

```
┌──────────────────────────┐
│       TypeScript         │
│                          │
│  ┌──────────────────┐    │
│  │   SwarmAgents    │    │
│  └────────┬─────────┘    │
│           │              │
│  ┌────────▼─────────┐    │
│  │   JuliaBridge    │    │
│  └────────┬─────────┘    │
└───────────┼──────────────┘
            │
┌───────────▼──────────────┐
│       WebSocket          │
└───────────┼──────────────┘
            │
┌───────────▼──────────────┐
│         Julia            │
│                          │
│  ┌──────────────────┐    │
│  │  Optimization    │    │
│  └──────────────────┘    │
│                          │
└──────────────────────────┘
```

## Customizing Examples

To modify these examples for your own use:

1. Update the optimization parameters in `optimization-example.ts`
2. Change the objective function to your own problem
3. Add additional optimization algorithms (e.g., 'abc' or 'firefly')
4. Modify environment variables to change server configuration

## Troubleshooting

If you encounter issues:

1. Check that Julia and Node.js are installed and in your PATH
2. Ensure environment variables are set correctly
3. Check that all dependencies are installed
4. Look for errors in the logs directory
5. Make sure the Julia server is running on the expected port 