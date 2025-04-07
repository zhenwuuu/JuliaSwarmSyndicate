# JuliaOS

<p align="center">
  <!-- Note: logo.png is not included in the repository. Create your own logo and place it in an assets directory -->
  <img src="assets/logo.png" alt="JuliaOS Logo" width="300">
</p>

<p align="center">
  A sophisticated operating system-like environment that integrates Julia programming language with a JavaScript/Node.js interface.
</p>

<p align="center">
  <a href="#key-features">Key Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#usage">Usage</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#project-structure">Project Structure</a> •
  <a href="#troubleshooting">Troubleshooting</a> •
  <a href="#license">License</a>
</p>

## Key Features

- ⚡ **Agent-based Architecture** for trading and analytics
- 🧬 **Swarm Intelligence** capabilities with multiple algorithms (PSO, GWO, ACO, GA, WOA, DE)
- ⛓️ **Multi-chain Support** for major blockchains (Ethereum, Polygon, Arbitrum, Optimism, Base, Solana)
- 📡 **Advanced Trading** capabilities with DEX integration
- 🔐 **Security Features** with built-in risk management
- 📊 **Performance Monitoring** for system optimization
- 💾 **Hybrid Storage** architecture (SQLite + Web3)
- 🖥️ **Interactive CLI** for easy system management
- 🌐 **Wallet Integration** supporting MetaMask, Phantom, and Rabby wallets

## Installation

### Prerequisites

- Julia 1.10.0+
- Node.js 18.0+
- npm 8.0+

### Step 1: Clone the repository

```bash
git clone https://github.com/Juliaoscode/JuliaOS.git
cd juliaos
```

### Step 2: Set up environment

```bash
# Copy example environment files
cp .env.example .env
cd julia && cp .env.example .env
cd ..

# Install JavaScript dependencies
npm install

# Setup Julia environment
chmod +x scripts/setup_julia_bridge.sh
./scripts/setup_julia_bridge.sh
```

### Step 3: Install Julia dependencies

```bash
cd julia
julia setup.jl
```

## Usage

### Starting the Julia server

```bash
cd julia
./start.sh
```

### Starting the interactive CLI (in a separate terminal)

```bash
node scripts/interactive.cjs
```

### Using the interactive CLI

The CLI provides a menu-driven interface with the following options:

- **Agent Management**: Create, configure, and manage autonomous agents
- **Swarm Management**: Create and coordinate swarms of agents
- **Cross-Chain Hub**: Manage wallets and perform cross-chain operations
- **API Keys Management**: Configure API keys for various services
- **System Configuration**: Configure system parameters
- **Performance Metrics**: Monitor system performance
- **Run System Checks**: Perform diagnostics on system components

## Architecture

JuliaOS follows a client-server architecture:

### Server Component (Julia Backend)

- Core computational engine written in Julia
- Runs as an HTTP/WebSocket server on port 8052
- Handles agent creation, management, and coordination
- Performs cross-chain operations and DEX interactions
- Manages swarm intelligence algorithms
- Includes storage management (SQLite)

### Client Component (JavaScript)

- Command-line interface (CLI) for user interactions
- Connects to the Julia server via HTTP/WebSocket
- Provides wallet integration (Browser extensions & Private Keys)
- Renders UI elements and displays results
- Handles transaction preparation, signing, and submission

## Project Structure

```
juliaos/
├── julia/                    # Julia backend code
│   ├── src/                  # Core Julia modules
│   │   ├── JuliaOS.jl        # Main Julia module
│   │   ├── AgentSystem.jl    # Agent system implementation
│   │   ├── SwarmManager.jl   # Swarm management functionality
│   │   ├── Blockchain.jl     # Blockchain interactions
│   │   ├── Bridge.jl         # Communication bridge
│   │   ├── Storage.jl        # Local database management
│   │   └── ...               # Other modules
│   ├── julia_server.jl       # HTTP/WebSocket server
│   └── setup.jl              # Setup script for Julia environment
├── packages/                 # JavaScript packages
│   ├── wallets/              # Wallet integration (MetaMask, Phantom, Rabby)
│   ├── julia-bridge/         # Bridge between JS and Julia
│   ├── cli/                  # Command-line interface components
│   └── ...                   # Other packages
├── scripts/                  # Utility scripts
│   ├── interactive.cjs       # Interactive CLI interface
│   └── setup_julia_bridge.sh # Setup script for Julia bridge
└── .env files                # Configuration files
```

## Troubleshooting

### Julia Server Won't Start

1. **Port Conflict**: 
   - Check if another process is using port 8052: `lsof -i :8052`
   - Kill the process if needed: `kill -9 [PID]`

2. **Missing Dependencies**:
   - Ensure all Julia packages are installed
   - Run: `cd julia && julia setup.jl`

3. **WebSockets Error**:
   - If you see WebSocket import errors, try updating the package:
   - `julia -e 'using Pkg; Pkg.update("HTTP"); Pkg.update("WebSockets"); Pkg.precompile()'`

4. **Bridge Initialization Errors**:
   - If you see errors related to Bridge initialization:
   - Check julia_server.jl for proper module setup and initialization

### CLI Won't Connect to Julia Server

1. **Server Not Running**:
   - Ensure Julia server is running in a separate terminal
   - Check if server is healthy: `curl -X GET http://localhost:8052/api/health`

2. **Fallback Mode**:
   - The CLI has fallbacks for many operations when server is unavailable
   - For full functionality, ensure the Julia server is running

### Environment Configuration

1. **API Keys**:
   - Ensure all necessary API keys are set in .env files
   - Warning about "OPENAI_API_KEY not set" is normal if not using OpenAI

2. **Blockchain RPC URLs**:
   - If blockchain operations fail, check that RPC URLs in .env are valid
   - Default RPC endpoints may have rate limits; consider using your own endpoints

## License

Licensed under the MIT License. See [LICENSE](LICENSE) for more information.