# JuliaOS Julia Backend

The Julia backend for the JuliaOS framework, providing computational capabilities for AI-powered trading agents and swarms.

## Features

- **Agent System**: Create and manage AI agents for various tasks
- **Swarm Intelligence**: Implement swarm algorithms for coordinated agent behavior
- **Bridge System**: Communicate with the Node.js frontend
- **Blockchain Integration**: Connect to various blockchain networks
- **Optimization Algorithms**: Implement various optimization algorithms including Differential Evolution
- **Chainlink Integration**: Real-time price data from Chainlink oracles

## Installation

1. Clone the repository:
```bash
git clone https://github.com/Juliaoscode/JuliaOS.git
cd JuliaOS
```

2. Install Node.js dependencies (for the CLI):
```bash
npm install
```

3. Install Julia dependencies:
```bash
julia -e 'using Pkg; Pkg.activate("julia"); Pkg.instantiate()'
```

## Usage

### Starting the Backend Server

Use the run-server.sh script to start the Julia server:
```bash
cd scripts/server
./run-server.sh
```
This starts the `julia_server.jl` on the configured port (default: 8052).

### Interactive CLI Mode

In a separate terminal, run the interactive Node.js script:
```bash
node scripts/interactive.cjs
```

This will start an interactive session where you can:
- Create and manage agents
- Create and manage swarms
- Monitor agent and swarm performance
- View market data
- Manage wallet connections
- Perform cross-chain operations

### Command Line Mode (Examples - Adapt as needed based on `scripts/interactive.cjs`)

The primary interface is now the Node.js interactive script. Examples below show conceptual Julia operations that might be triggered *via* the interactive CLI or could be adapted into dedicated scripts if needed.

#### Dashboard (Conceptual - Check if `scripts/interactive.cjs` offers similar views)
```bash
# No direct Julia command, use interactive CLI
```

#### Backtest (Conceptual - Check if implemented in Julia modules called by CLI)
```bash
# Example: If a backtest function exists in JuliaOS.SwarmManager
# julia -e 'using JuliaOS.SwarmManager; backtest_strategy(...)'
```

#### Optimize (Conceptual - Likely managed within SwarmManager logic)
```bash
# Swarm optimization happens within the running swarm via start_swarm!
```

#### Market Data (Conceptual - Check if CLI offers direct market data view)
```bash
# Example: If a market data function exists in JuliaOS.MarketData
# julia -e 'using JuliaOS.MarketData; fetch_market_data(...)'
```

#### Project Scaffolding (Conceptual - Needs specific script if required)
```bash
# No standard command observed
```

### Examples

1. Create a new agent via the interactive CLI:
```bash
node scripts/interactive.cjs
# Select "👤 Agent Management" -> "Create Agent"
# Enter a name for your agent (e.g., "MyTradingAgent")
# Select an agent type (e.g., "Portfolio Optimization")
# Enter agent configuration as JSON (can use {} for defaults)
```

2. Create a swarm via the interactive CLI:
```bash
node scripts/interactive.cjs
# Select "🐝 Swarm Management" -> "Create Swarm"
# Enter a name for your swarm (e.g., "MyTradingSwarm")
# Select a swarm algorithm (e.g., "Differential Evolution")
# Enter swarm configuration as JSON (can use {} for defaults)
```

3. Monitor market data via the interactive CLI:
```bash
node scripts/interactive.cjs
# Select "📊 Market Data" -> "View Price Data"
# Select a token pair to view price data
```

## Configuration

### Environment Variables

Create a `.env` file in the project root:
```env
# API Configuration
API_ENDPOINT=http://localhost:3000

# Network Configuration
ETH_RPC_URL=https://eth-mainnet.example.com
SOLANA_RPC_URL=https://api.mainnet-beta.solana.com

# Security
API_KEY=your_api_key
```

### Agent Configuration

Agents can be configured through:
1. Interactive mode
2. Configuration files
3. Command-line arguments

Example agent configuration:
```json
{
  "name": "arbitrage_agent_1",
  "type": "Arbitrage Agent",
  "strategy": "Momentum",
  "chains": ["Ethereum", "Solana"],
  "risk_params": {
    "max_position_size": 0.1,
    "min_profit_threshold": 0.02,
    "max_gas_price": 100.0,
    "confidence_threshold": 0.8
  }
}
```

## Development

### Adding New Commands (to Node.js CLI)

Refer to the structure of `scripts/interactive.cjs` and Node.js best practices (e.g., using `inquirer`, `chalk`).

### Adding New Backend Commands (Callable via Bridge)

1. Add function implementation in the relevant Julia module (e.g., `julia/src/SwarmManager.jl`).
2. Expose the function in `julia/src/JuliaOS.jl` if necessary.
3. Add a command handler case in `process_command` within `julia/julia_server.jl`.
4. Update the Node.js bridge call in `scripts/interactive.cjs` (e.g., `juliaBridge.runJuliaCommand(...)`).

### Testing

Run Julia tests:
```bash
cd julia
julia --project=test test/runtests.jl
```

Run specific Julia tests:
```bash
cd julia/test
julia test_swarm_fix.jl
```

Run Node.js tests (if any exist):
```bash
npm test
```

## Running the Server

### Quick Start

Use the run-server.sh script to launch the server:

```bash
cd scripts/server
./run-server.sh
```

This script:
1. Checks if Julia is installed
2. Verifies that the julia directory exists
3. Starts `julia_server.jl` on the configured port (default: 8052)
4. Verifies that the server is running

### Manual Start

To start the server manually:

```bash
cd julia
julia julia_server.jl
```

### Testing the Bridge Connection

You can test the bridge connection by:
1. Starting the Julia server (`cd scripts/server && ./run-server.sh`)
2. Running the Node.js interactive CLI (`node scripts/interactive.cjs`)
3. Using options like "System Configuration" or "List Agents" which communicate with the backend.

For specific troubleshooting:

```bash
curl http://localhost:8052/health
```

## Architecture

- `JuliaOSBridge` (`src/Bridge.jl`): Handles communication between Node.js/TypeScript and Julia.
- `JuliaOS` (`src/JuliaOS.jl`): Core computational engine, includes other modules.
- Supporting modules (`src/...`) for specialized functionality (Agents, Swarms, Blockchain, DEX, etc.)

## Development

### Project Structure (`julia` directory)

- `src/` - Source code for the JuliaOS system modules.
  - `JuliaOS.jl` - Main Julia module.
  - `AgentSystem.jl` - Agent system implementation.
  - `SwarmManager.jl` - Swarm management functionality.
  - `algorithms/` - Implementation of various algorithms including Differential Evolution.
- `test/` - Tests for the JuliaOS system.
- `julia_server.jl` - Main HTTP/WebSocket server script.
- `Project.toml` / `Manifest.toml` - Package dependencies.
- `setup.jl` - Script to set up the Julia environment.
- `config/` - Configuration files.
- `apps/`, `examples/`, `use_cases/` - Documentation and examples.

### Extending the Bridge

To extend the bridge with new functionality callable from Node.js:

1. Implement the desired function in the appropriate Julia module within `src/`.
2. Ensure the function is accessible (e.g., exported by its module and included in `JuliaOS.jl`).
3. Add a new `elseif command == "your_new_command"` block within the `process_command` function in `julia_server.jl` to handle the command string and call your new Julia function, passing necessary parameters from `params`.
4. In the Node.js code (`scripts/interactive.cjs` or other relevant file), call `juliaBridge.runJuliaCommand("your_new_command", [param1, param2, ...])` to invoke the new backend command.
5. Remember to handle the response or potential errors returned from the Julia backend in your Node.js code.

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

# JuliaOS Server

This is the Julia server component of JuliaOS, providing computational capabilities and bridging with the Node.js frontend.

## Setup

### Requirements

- Julia 1.8 or higher
- For development: Git, curl

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/Juliaoscode/JuliaOS.git
   cd JuliaOS
   ```

2. Install Julia dependencies:
   ```bash
   julia -e 'using Pkg; Pkg.activate("julia"); Pkg.instantiate()'
   ```

3. Set up the Julia bridge:
   ```bash
   cd scripts/server
   ./setup_julia_bridge.sh
   ```

## Running the Server

### Quick Start

Use the run-server.sh script to launch the server:

```bash
cd scripts/server
./run-server.sh
```

This script:
1. Checks if Julia is installed
2. Verifies that the julia directory exists
3. Starts the server on port 8052
4. Verifies that the server is running

### Manual Start

To start the server manually:

```bash
cd julia
julia julia_server.jl
```

### Testing

To test the server is running:

```bash
curl http://localhost:8052/health
```

## API Endpoints

The server provides the following endpoints:

- `GET /health` - Health check endpoint, returns server status
- WebSocket endpoint at the root path for real-time communication

## Architecture

- `JuliaOSBridge` - Handles communication between Node.js and Julia
- `JuliaOS` - Core computational engine
- Supporting modules for specialized functionality

## Troubleshooting

If you encounter issues:

1. Check if the server is running: `curl http://localhost:8052/health`
2. Check the server logs
3. Verify that all required Julia packages are installed
4. Make sure the Julia bridge is properly set up

## Using the Wallet Connection Feature

JuliaOS includes a wallet connection feature accessible through the interactive CLI.

### Connecting a Wallet

1. Start the Julia server:
   ```bash
   cd scripts/server
   ./run-server.sh
   ```

2. Run the interactive CLI:
   ```bash
   node scripts/interactive.cjs
   ```

3. To connect a wallet:
   - From the main menu, select "💼 Wallet Management"
   - Choose "Connect Wallet"
   - Select a connection mode:
     - **Address Only (Read-only)**: Enter any wallet address to view (no transactions)
     - **Private Key (Full Access)**: Enter a private key for full transaction capabilities
   - Select a blockchain network (Ethereum, Solana, etc.)
   - Enter your address or private key as requested

4. Wallet operations:
   - View balance
   - Send transactions
   - View transaction history
   - Disconnect wallet

### Implementation Notes

- The wallet connection provides real blockchain interaction capabilities
- Private keys are never stored persistently
- All sensitive operations are performed securely
- For production use, consider using hardware wallets or secure key management solutions

## Security Best Practices

### Wallet Management

JuliaOS follows these security best practices for wallet management:

1. **Private Key Handling**
   - Private keys are never stored directly in application state
   - Keys are only held temporarily in memory during connection and signing operations
   - Keys are cleared from memory immediately after use
   - All private key operations are encapsulated within secure wallet methods

2. **Transaction Signing**
   - Transactions are signed securely within the WalletManager class
   - The private key is never exposed outside the wallet implementation
   - All transaction data is validated before signing
   - User confirmation is required before signing transactions
   - Transaction details are clearly displayed for verification

3. **Input Validation**
   - All wallet addresses are validated using chain-specific rules
   - Transaction amounts and other parameters are validated before use
   - JSON inputs are safely parsed with error handling

4. **Error Handling**
   - Comprehensive error handling prevents crashes and security issues
   - Appropriate error messages guide users without revealing sensitive information
   - Failed operations are properly cleaned up

### General Security Guidelines

When extending or modifying the wallet functionality, follow these guidelines:

1. **Never**:
   - Store private keys in local storage, session storage, or cookies
   - Log private keys or expose them in error messages
   - Pass private keys between components as plain text
   - Store private keys in application state or Redux store

2. **Always**:
   - Use established cryptography libraries for wallet operations
   - Implement proper address validation
   - Clear sensitive data from memory when no longer needed
   - Use secure input fields for private key entry
   - Provide clear security information to users

3. **Recommended**:
   - Use hardware wallets or browser extensions when possible
   - Implement rate limiting for authentication attempts
   - Consider multi-factor authentication for high-value operations
   - Audit your code for security vulnerabilities regularly