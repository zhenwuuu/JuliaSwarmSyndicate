# J3OS JuliaBridge

A TypeScript bridge for communicating with the Julia backend of the J3OS framework.

## Overview

The JuliaBridge package provides a TypeScript interface to the Julia backend of the J3OS framework. It allows TypeScript applications to communicate with the Julia backend through a WebSocket connection, enabling seamless integration between the two languages.

## Features

- **WebSocket Communication**: Communicates with the Julia backend through a WebSocket connection
- **Command Execution**: Executes Julia functions from TypeScript
- **Automatic Server Management**: Can start and manage the Julia server process
- **Error Handling**: Robust error handling and timeout management
- **Event Emitter**: Emits events for connection status and errors

## Installation

```bash
npm install @j3os/julia-bridge
```

## Usage

### Basic Usage

```typescript
import { JuliaBridge } from '@j3os/julia-bridge';

// Create a new JuliaBridge instance
const bridge = new JuliaBridge({
  debug: true, // Enable debug logging
  projectPath: '/path/to/julia', // Path to the Julia project
  serverPort: 8052 // Port for the Julia server
});

// Initialize the bridge
await bridge.initialize();

// Run a Julia command
const result = await bridge.runJuliaCommand('JuliaOS.check_system_health', {});

console.log(result);

// Shutdown the bridge
await bridge.shutdown();
```

### Connecting to an Existing Server

```typescript
import { JuliaBridge } from '@j3os/julia-bridge';

// Create a new JuliaBridge instance
const bridge = new JuliaBridge({
  debug: true, // Enable debug logging
  useWebSocket: true, // Use WebSocket connection
  wsUrl: 'ws://localhost:8052' // WebSocket URL
});

// Initialize the bridge
await bridge.initialize();

// Run a Julia command
const result = await bridge.runJuliaCommand('JuliaOS.check_system_health', {});

console.log(result);

// Shutdown the bridge
await bridge.shutdown();
```

### Event Handling

```typescript
import { JuliaBridge } from '@j3os/julia-bridge';

// Create a new JuliaBridge instance
const bridge = new JuliaBridge({
  debug: true
});

// Register event handlers
bridge.on('initialized', () => {
  console.log('JuliaBridge initialized');
});

bridge.on('server-started', () => {
  console.log('Julia server started');
});

bridge.on('ws-connected', () => {
  console.log('WebSocket connected');
});

bridge.on('ws-closed', () => {
  console.log('WebSocket closed');
});

bridge.on('error', (error) => {
  console.error('JuliaBridge error:', error);
});

// Initialize the bridge
await bridge.initialize();
```

### Available Commands

The JuliaBridge provides several convenience methods for common operations:

```typescript
// Create a swarm
const swarmId = await bridge.createSwarm({
  name: 'My Swarm',
  type: 'Trading',
  config: {
    size: 100,
    strategy: 'Momentum'
  }
});

// Optimize a swarm
const optimizationResult = await bridge.optimizeSwarm(swarmId, {
  data: [...],
  options: {
    iterations: 1000,
    populationSize: 50
  }
});

// Analyze a cross-chain route
const routeAnalysis = await bridge.analyzeRoute({
  source: 'ethereum',
  destination: 'solana',
  token: 'USDC',
  amount: '1000'
});

// Get system health
const health = await bridge.getHealth();
```

## Configuration

The JuliaBridge constructor accepts the following configuration options:

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `juliaPath` | string | auto-detected | Path to the Julia executable |
| `projectPath` | string | `./julia` | Path to the Julia project |
| `serverScript` | string | `start_server.jl` | Name of the Julia server script |
| `serverPort` | number | 8052 | Port for the Julia server |
| `debug` | boolean | false | Enable debug logging |
| `useWebSocket` | boolean | true | Use WebSocket connection |
| `wsUrl` | string | `ws://localhost:8052` | WebSocket URL |

## Development

### Building

```bash
npm run build
```

### Testing

```bash
npm test
```

### Linting

```bash
npm run lint
```

## License

MIT 