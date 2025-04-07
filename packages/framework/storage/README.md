# JuliaOS Storage Module

The Storage module provides a hybrid storage solution for JuliaOS, combining the benefits of local SQLite storage with decentralized Web3 storage via Ceramic Network and IPFS.

## Features

- **Local Storage**: SQLite-based persistent storage for agents, swarms, settings, and transactions
- **Web3 Storage**: Decentralized storage using Ceramic Network for structured data and IPFS for large files
- **Synchronization**: Bidirectional sync between local and Web3 storage
- **Marketplace Support**: Publish and discover agents and swarms in a decentralized marketplace
- **Access Control**: Control access to your agents and swarms with DID-based authentication
- **Cross-Device Access**: Access your agents and swarms from multiple devices

## Components

### LocalStorage

The `LocalStorage` class provides an interface to the local SQLite database:

```typescript
import { LocalStorage } from '@juliaos/framework/storage';
import { JuliaBridge } from '@juliaos/julia-bridge';

// Create a bridge to the Julia backend
const bridge = new JuliaBridge();
await bridge.connect();

// Create a LocalStorage instance
const localStorage = new LocalStorage(bridge);

// Create an agent
const agent = await localStorage.createAgent(
  'agent-1',
  'Trading Assistant',
  'trading',
  { max_position_size: 1000, risk_tolerance: 'medium' }
);

// List all agents
const agents = await localStorage.listAgents();
console.log('Agents:', agents);
```

### Web3Storage

The `Web3Storage` class provides an interface to the decentralized storage system:

```typescript
import { Web3Storage } from '@juliaos/framework/storage';
import { JuliaBridge } from '@juliaos/julia-bridge';

// Create a bridge to the Julia backend
const bridge = new JuliaBridge();
await bridge.connect();

// Create a Web3Storage instance
const web3Storage = new Web3Storage(bridge);

// Configure Web3 storage
await web3Storage.configure({
  ceramicNodeUrl: 'https://ceramic-clay.3boxlabs.com',
  ipfsApiUrl: 'https://api.web3.storage',
  ipfsApiKey: 'your-web3-storage-api-key'
});

// Store an agent in Web3 storage
const result = await web3Storage.storeAgent({
  id: 'agent-1',
  name: 'Trading Assistant',
  type: 'trading',
  config: { max_position_size: 1000, risk_tolerance: 'medium' }
});

console.log('Stored agent with Ceramic document ID:', result.ceramic_doc_id);
```

### StorageSync

The `StorageSync` class provides synchronization between local and Web3 storage:

```typescript
import { StorageSync } from '@juliaos/framework/storage';
import { JuliaBridge } from '@juliaos/julia-bridge';

// Create a bridge to the Julia backend
const bridge = new JuliaBridge();
await bridge.connect();

// Create a StorageSync instance
const storageSync = new StorageSync(bridge);

// Initialize sync configuration
await storageSync.initSync();

// Enable synchronization
await storageSync.enableSync(true);

// Set sync preferences
await storageSync.setSyncPreferences({
  agents: true,
  swarms: true,
  settings: true,
  transactions: false  // Don't sync sensitive transaction data
});

// Sync all agents
const result = await storageSync.syncAllAgents();
console.log('Sync result:', result);

// Get sync status
const status = await storageSync.getSyncStatus();
console.log('Sync status:', status);
```

## Requirements

This module requires:

1. Julia backend with `Storage.jl`, `Web3Storage.jl`, and `Sync.jl` modules
2. Environment variables for Ceramic Network and IPFS:
   - `CERAMIC_NODE_URL` (e.g., `https://ceramic-clay.3boxlabs.com`)
   - `IPFS_API_URL` (e.g., `https://api.web3.storage`)
   - `IPFS_API_KEY` (your Web3.Storage API key)

## Implementation Details

### Data Flow
```
┌───────────────┐      ┌───────────────┐      ┌───────────────┐
│ TypeScript UI │<─────│ Julia Backend │<─────│ LocalStorage  │
└───────┬───────┘      └───────┬───────┘      └───────────────┘
        │                      │                      ▲
        │                      │                      │
        │                      ▼                      │
        │              ┌───────────────┐              │
        └─────────────▶│   Web3Storage │──────────────┘
                       └───────┬───────┘
                               │
                               ▼
                 ┌───────────────────────────┐
                 │ Ceramic Network + IPFS    │
                 └───────────────────────────┘
```

### Storage Schema

The system stores:
- **Agents**: Trading and AI agents with their configuration and state
- **Swarms**: Groups of coordinated agents with their algorithm parameters
- **Settings**: User preferences and system configuration
- **Transactions**: Records of blockchain transactions (local only by default)

### Synchronization Mechanism

The synchronization system:
1. Checks for changes in both local and Web3 storage
2. Resolves conflicts based on timestamps or user preference
3. Syncs only the data types specified in the sync preferences
4. Encrypts sensitive data before storing in Web3 storage
5. Can be scheduled to run automatically at specified intervals

## Example Use Cases

### Cross-Device Agent Management

1. Create an agent on your local machine
2. Enable synchronization to Web3 storage
3. Access the same agent from another device by syncing from Web3 storage
4. Make changes on either device and sync to keep them in sync

### Agent Marketplace

1. Create and test an agent locally
2. Publish the agent to the marketplace
3. Other users can discover and download your agent
4. Receive feedback and ratings on your agent 