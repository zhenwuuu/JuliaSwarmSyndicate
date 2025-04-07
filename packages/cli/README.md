# JuliaOS CLI (Basic Version)

This is the basic open source version of the JuliaOS Command Line Interface (CLI). It provides fundamental functionality for creating and managing agents and swarms, with robust path resolution to ensure it works across different directory structures.

## Full-Featured Version

For the complete, production-ready version with advanced features, install the official CLI via npm:

```bash
npm install -g juliaos-cli
```

## Running The Basic CLI

To run the basic CLI from this repository:

```bash
# From the root of the repository
node packages/cli/bin/cli.js

# Or from within the CLI package directory
node bin/cli.js
```

## Features in Basic Version

- Create and list agents
- Create and list swarms
- View system information

## Path Resolution

This version includes enhanced path resolution to handle directory navigation issues. It will search for the Julia server in multiple locations:

- Current and parent directories
- Common installation locations
- Up the directory tree recursively

## Julia Server

The CLI requires the Julia server to be accessible. The path resolution logic should find it automatically, but if you encounter issues, try running the CLI from the root of the JuliaOS repository.

## Development

### Prerequisites

- Node.js 14+
- Julia 1.8+

### Installation

```bash
cd packages/cli
npm install
```

### Testing

```bash
node bin/cli.js
```

## Architecture

The basic CLI architecture:

- `bin/cli.js`: Entry point with path resolution
- `src/interactive.js`: Interactive CLI interface
- `src/server.js`: Server management

## Extending

If you want to contribute to or extend this CLI:

1. Understand the existing code structure
2. Make your changes or additions
3. Submit a PR with a clear description of your changes

We welcome community contributions while maintaining a clear separation between this basic version and the full-featured commercial offering.

# J3OS Command Line Interface (CLI)

This directory contains the command-line interface for the J3OS Framework, enabling developers to create and manage AI-powered trading agents and swarms across multiple blockchains.

## Four Ways to Use the CLI

### 1. Docker-Enhanced CLI (Recommended for All Users)

The Docker-Enhanced CLI provides the most consistent experience across all operating systems with no dependency issues. All the visual elements, animations, and interactive features work perfectly in Docker.

#### Prerequisites
- [Docker](https://www.docker.com/get-started) installed and running

#### Getting Started

**Windows Users:**
```
run-enhanced-docker.bat
```

**PowerShell Users:**
```
.\run-enhanced-docker.ps1
```

**macOS/Linux Users:**
```bash
chmod +x run-enhanced-docker.sh
./run-enhanced-docker.sh
```

This will:
1. Build a Docker container with all required dependencies
2. Create necessary directories for data persistence
3. Launch the enhanced interactive CLI with the beautiful interface
4. Save all your agent, swarm, and wallet data to your local directories

### 2. Enhanced Interactive CLI (Native)

If you prefer to run without Docker, you can use the native enhanced CLI. However, this requires Node.js and proper dependency installation.

#### Prerequisites
- [Node.js](https://nodejs.org/) (v16 or later)
- [npm](https://www.npmjs.com/) (v7 or later)

#### Getting Started

**Windows Users:**
```
run-enhanced-cli.bat
```

**PowerShell Users:**
```
.\run-enhanced-cli.ps1
```

**macOS/Linux Users:**
```bash
chmod +x run-enhanced-cli.sh
./run-enhanced-cli.sh
```

### 3. Docker-Based CLI (Legacy)

The legacy Docker-based approach for the basic CLI.

#### Prerequisites
- [Docker](https://www.docker.com/get-started) installed and running

#### Getting Started

**Windows Users:**
```
run-docker.bat
```

**macOS/Linux Users:**
```bash
chmod +x run-docker.sh
./run-docker.sh
```

### 4. Native CLI Installation (Legacy)

The basic CLI for direct system installation.

#### Prerequisites
- [Node.js](https://nodejs.org/) (v16 or later)
- [npm](https://www.npmjs.com/) (v7 or later)
- [Julia](https://julialang.org/downloads/) (v1.8 or later)

#### Installation

```bash
# Install dependencies
npm install

# Build the CLI
npm run build

# Run the CLI
node bin/j3os.js [command]
```

## Simplified J3OS CLI Workflow

Our new streamlined CLI workflow makes it easy to:

1. **Create and Manage Agents**
   - Trading agents
   - Analysis agents
   - Monitoring agents
   - Custom agents

2. **Deploy and Monitor Swarms**
   - PSO (Particle Swarm Optimization)
   - GWO (Grey Wolf Optimizer)
   - WOA (Whale Optimization Algorithm)
   - GA (Genetic Algorithm)
   - ACO (Ant Colony Optimization)
   - Hybrid algorithms

## Available Commands

- `interactive` - Start the interactive CLI experience
- `agent create` - Create a new AI agent
- `agent list` - List all created agents
- `agent start` - Start an agent
- `agent monitor` - Monitor agent performance
- `swarm create` - Create a new swarm
- `swarm monitor` - Monitor swarm performance
- `help` - Show available commands and usage information
- `tutorial` - Access interactive tutorials

## Data Persistence

Both methods store agent and swarm configurations locally:
- Docker: Mounts the `agents/` and `swarms/` directories to your local machine
- Native: Creates files directly in your project directory

## Example: Creating a Swarm

```bash
# Using Docker (interactive)
./run-docker.sh
# Select "Create a swarm" from the menu

# Using native CLI
node bin/j3os.js swarm create
```

## Troubleshooting

If you encounter issues:

1. Docker method:
   - Ensure Docker is running
   - Try running Docker with administrator/sudo privileges
   - Check that port 8080 is available (for web interface)

2. Native method:
   - Verify Node.js and Julia are installed correctly
   - Check for necessary permissions in your directory
   - Run `npm install` to ensure all dependencies are installed

## Implementation Details

The CLI is implemented using:
- Commander.js for command-line parsing
- Inquirer.js for interactive prompts
- Node.js for cross-platform compatibility
- Julia for high-performance computing tasks
- Docker for containerization and consistent execution

## Features

- **Cross-Chain Support**
  - Ethereum and EVM-compatible chains
  - Solana ecosystem
  - Custom network configurations
  - Multi-chain arbitrage capabilities

- **Wallet Integration**
  - MetaMask support
  - Phantom wallet support
  - Rabby multi-chain wallet
  - Custom RPC configurations

- **Trading Strategies**
  - Market making
  - Arbitrage
  - Cross-chain arbitrage
  - Custom strategy support

- **Execution Types**
  - Single agent execution
  - Swarm intelligence execution
  - Hybrid execution modes

- **Security Features**
  - Encrypted configuration storage
  - Secure file permissions
  - Environment variable management
  - Rate limiting for API calls

- **Monitoring & Logging**
  - Prometheus metrics integration
  - Winston logging system
  - Elasticsearch log aggregation
  - Health checks and alerts

## Installation

```bash
npm install -g @j3os/cli
```

## Quick Start

1. Initialize a new project:
```bash
j3os init
```

2. Configure DeFi trading:
```bash
j3os defi configure
```

3. Start trading:
```bash
j3os start
```

## Commands

### Project Management
- `j3os init` - Initialize a new J3OS project
- `j3os start` - Start the trading system
- `j3os stop` - Stop the trading system
- `j3os status` - Check system status

### DeFi Configuration
- `j3os defi configure` - Configure DeFi trading setup
- `j3os defi list` - List configured trading setups
- `j3os defi remove` - Remove a trading setup

### Wallet Management
- `j3os wallet add-network` - Add a new network
- `j3os wallet configure` - Configure wallet settings
- `j3os wallet backup` - Backup wallet configuration
- `j3os wallet restore` - Restore wallet configuration

### Monitoring
- `j3os monitor add` - Add a new monitoring rule
- `j3os monitor list` - List monitoring rules
- `j3os monitor remove` - Remove a monitoring rule
- `j3os monitor status` - Check monitoring status

## Configuration

### Environment Variables

Required:
```bash
WEB3_PROVIDER="https://your-rpc-url"
API_KEY="your-api-key"
WALLET_PRIVATE_KEY="your-private-key"
```

Optional:
```bash
ELASTICSEARCH_URL="https://your-elasticsearch-url"  # For logging
LOG_LEVEL="info"  # For logging level
```

### Project Structure

```
j3os-project/
├── config/
│   ├── agent.json
│   └── swarm.json
├── julia/
│   ├── src/
│   │   ├── agents/
│   │   └── swarms/
│   └── tests/
├── logs/
│   ├── error.log
│   └── combined.log
└── backups/
    └── metrics.json
```

## Development

### Prerequisites
- Node.js >= 14
- Julia >= 1.6
- npm or yarn

### Setup
```bash
# Clone repository
git clone https://github.com/j3os/framework.git
cd framework

# Install dependencies
npm install

# Build
npm run build

# Run tests
npm test
```

### Running Tests

```bash
# Run unit tests
npm run test:unit

# Run integration tests
npm run test:integration

# Run E2E tests (requires network access)
RUN_E2E=true npm run test:e2e
```

## Security

- Never share private keys
- Use environment variables for sensitive data
- Regularly backup configurations
- Monitor for suspicious activity
- Test on testnet first

## Monitoring

The CLI includes comprehensive monitoring capabilities:

- Transaction monitoring
- Balance tracking
- Performance metrics
- Health checks
- Alert system

Access metrics at `/metrics` endpoint when running in server mode.

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

MIT License - see LICENSE file for details

## Support

- Documentation: [docs.j3os.io](https://docs.j3os.io)
- Discord: [J3OS Community](https://discord.gg/j3os)
- GitHub Issues: [J3OS Framework](https://github.com/j3os/framework/issues)

# J3OS CLI - Docker Container

This directory contains the enhanced J3OS CLI with a Docker-based workflow. Running the CLI in a Docker container ensures consistent behavior across different platforms (Windows, Mac, Linux).

## Prerequisites

- Docker installed on your system
- Basic knowledge of terminal/command prompt

## Running the CLI

### For Linux/Mac users:

1. Open a terminal in this directory
2. Run the script:
   ```
   ./run-docker.sh
   ```
3. Follow the on-screen prompts

### For Windows users:

1. Open Command Prompt or PowerShell in this directory
2. Run the batch script:
   ```
   run-docker.bat
   ```
3. Follow the on-screen prompts

## Available Commands

The CLI supports the following main commands:

- `interactive` - Start the interactive CLI experience with guided workflows
- `agent create` - Create a new AI agent
- `agent list` - List all created agents
- `agent start` - Start an agent
- `agent monitor` - Monitor agent performance
- `swarm create` - Create a new swarm
- `swarm monitor` - Monitor swarm performance
- `help` - Show available commands and usage information
- `tutorial` - Access interactive tutorials

## Data Persistence

The Docker container mounts the `agents/` and `swarms/` directories from your local machine, ensuring that your agent and swarm configurations are saved between runs.

## Advanced Usage

To run a custom command, choose option 6 from the menu and enter your command. For example:

```
agent monitor --name my-trading-agent
```

## Troubleshooting

If you encounter any issues:

1. Make sure Docker is running
2. Check that you have permissions to create files in the current directory
3. If the container fails to build, try running Docker with administrator/sudo privileges 

## Production-Ready Features

The J3OS CLI now includes fully production-ready features:

### Wallet Management

✅ **Create Wallets**: Generate new wallets for any supported blockchain
✅ **Import Wallets**: Import existing wallets using private keys
✅ **Secure Storage**: All private keys are stored with strong encryption
✅ **Multi-Chain Support**: Support for Ethereum, Solana, Polygon, BSC, etc.
✅ **Balance Checking**: Real-time balance checking across all supported chains
✅ **Transaction Support**: Send transactions directly from wallets

### Cross-Chain Bridging

✅ **Optimized Routes**: AI-powered route finding based on your preferences
✅ **Multi-Provider Support**: Integration with Wormhole, Stargate, Hop, etc.
✅ **Real Transaction Support**: Execute actual bridge transactions with wallet integration
✅ **Transaction History**: Keep track of all your bridge operations
✅ **Strategy Selection**: Choose lowest fee, fastest, most secure, or balanced routes
✅ **Extensive Network Support**: Ethereum, Optimism, Arbitrum, Polygon, BSC, Avalanche, Base, and more

### Exchange Integration

✅ **API Key Management**: Securely store and manage exchange API keys
✅ **Multi-Exchange Support**: Integration with Binance, Coinbase, Kraken, etc.
✅ **Real Trading**: Execute trades directly from CLI
✅ **Balance Checking**: Check your balances across all exchanges
✅ **Order Management**: Place, view, and cancel orders

### Security Features

✅ **Master Password Protection**: All sensitive data protected by a master password
✅ **Secure Encryption**: AES-256 encryption for private keys and API secrets
✅ **No Remote Storage**: All data stored locally, never sent to remote servers
✅ **Confirmation Prompts**: Verify all sensitive operations before execution
✅ **Transparent Transactions**: View all transaction details before signing

## Using Wallets and Bridges

### Creating a Wallet

```bash
# Using the CLI
./run-docker.bat

# Then choose "Bridge Assets" - you'll be prompted to create a wallet if none exists
```

Or create directly using command mode:

```bash
./run-docker.bat wallet:create
```

### Bridging Assets

```bash
# Start interactive mode
./run-docker.bat

# Choose "Bridge Assets" and follow the prompts
```

Or use command mode:

```bash
./run-docker.bat bridge --source ethereum --destination polygon --token USDC --amount 100 --strategy fastest
```

### Viewing Bridge History

```bash
./run-docker.bat bridge:history
```

## Enhanced CLI Features

Our new enhanced CLI includes:

1. **Beautiful Visual Interface**
   - Gradient colors and animated text
   - Progress bars and spinners
   - Boxed information displays
   - Emoji-rich interface for intuitive navigation

2. **Interactive Dashboard**
   - Real-time monitoring of agents and swarms
   - Performance visualization
   - Wallet status and balance display
   - Activity logs and notifications

3. **Wallet Integration**
   - Connect with MetaMask, WalletConnect, hardware wallets
   - Multi-chain support (Ethereum, Optimism, BSC, Polygon, Arbitrum, Base, etc.)
   - QR code generation for addresses
   - Development wallet for testing

4. **Cross-Chain Operations**
   - Find optimal routes based on speed, cost, or security
   - Compare bridge providers (Across, Stargate, Synapse, etc.)
   - Save and execute bridge transactions
   - Performance testing through Julia swarm intelligence

5. **Agent & Swarm Management**
   - Create AI agents with various capabilities
   - Build swarms with different intelligence algorithms
   - Real-time monitoring with ASCII visualizations
   - Performance metrics and optimization

// ... existing code ... 