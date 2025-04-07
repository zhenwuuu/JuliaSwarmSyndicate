# JuliaOS CLI

A powerful command-line interface for the JuliaOS framework, providing tools to create, manage, and monitor AI-powered trading agents and swarms.

## Features

- **Interactive Mode**: User-friendly interface for creating and managing agents
- **Rich Terminal UI**: Color-coded status displays and progress indicators
- **Real-time Monitoring**: Live monitoring of agent performance and market data
- **Comprehensive Commands**: Full suite of commands for agent and swarm management
- **Error Handling**: Clear error messages and stack traces
- **Configuration Management**: Easy configuration of agents and swarms

## Installation

1. Clone the repository:
```bash
git clone https://github.com/juliaos/framework.git
cd framework
```

2. Install dependencies:
```bash
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

3. Make the CLI executable:
```bash
chmod +x juliaos.jl
```

## Usage

### Interactive Mode

Launch the interactive mode:
```bash
./juliaos.jl interactive
```

This will start an interactive session where you can:
- Create new agents and swarms
- Monitor active agents
- View market data
- Manage bridge operations

### Command Line Mode

#### Dashboard
```bash
./juliaos.jl dashboard [--host HOST] [--port PORT]
```

#### Backtest
```bash
./juliaos.jl backtest --strategy STRATEGY --start-date YYYY-MM-DD --end-date YYYY-MM-DD --initial-capital AMOUNT --pairs PAIR1 PAIR2 ...
```

#### Optimize
```bash
./juliaos.jl optimize --algorithm ALGO --iterations N --population-size N --parameters PARAM1 PARAM2 ...
```

#### Market Data
```bash
./juliaos.jl market --pair PAIR --timeframe TIMEFRAME --limit N
```

#### Project Scaffolding
```bash
./juliaos.jl scaffold --name NAME --type TYPE
```

### Examples

1. Create a new arbitrage agent:
```bash
./juliaos.jl interactive
# Select "Create New Agent"
# Choose "Arbitrage Agent"
# Configure parameters
```

2. Run a backtest:
```bash
./juliaos.jl backtest \
  --strategy "Momentum" \
  --start-date "2023-01-01" \
  --end-date "2023-12-31" \
  --initial-capital 10000 \
  --pairs "ETH/USDC" "BTC/USDC"
```

3. Monitor market data:
```bash
./juliaos.jl market \
  --pair "ETH/USDC" \
  --timeframe "1h" \
  --limit 100
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

### Adding New Commands

1. Add command definition in `apps/cli.jl`:
```julia
@add_arg_table! s begin
    "new-command"
        help = "Description of the new command"
        action = :command
end
```

2. Add command implementation:
```julia
function cmd_new_command(args)
    # Implementation
end
```

3. Update main function:
```julia
if args["%COMMAND%"] == "new-command"
    cmd_new_command(args["new-command"])
end
```

### Testing

Run tests:
```bash
julia --project=test test/runtests.jl
```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

# JuliaOS Server

This is the Julia server component of JuliaOS, providing computational capabilities and bridging with the TypeScript frontend.

## Setup

### Requirements

- Julia 1.8 or higher
- For development: Git, curl

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/your-org/juliaos.git
   cd juliaos
   ```

2. Set up the Julia environment:
   ```bash
   cd julia
   julia setup.jl
   ```

3. Alternatively, use the bridge setup script:
   ```bash
   ./setup_julia_bridge.sh
   ```

## Running the Server

### Quick Start

Use the start script to launch the server:

```bash
cd julia
./start.sh
```

This script:
1. Checks if Julia is installed
2. Verifies that JuliaOSBridge is set up
3. Starts the server on port 8052
4. Verifies that the server is running

### Manual Start

To start the server manually:

```bash
cd julia
julia simple_server.jl
```

Or for the full server with all features:

```bash
cd julia
julia start_server.jl
```

### Testing

To test the bridge installation:

```bash
cd julia
julia test_bridge.jl
```

For troubleshooting:

```bash
cd julia
julia troubleshoot.jl
```

## API Endpoints

The server provides the following endpoints:

- `GET /health` - Health check endpoint, returns server status
- WebSocket endpoint at the root path for real-time communication

## Architecture

- `JuliaOSBridge` - Handles communication between TypeScript and Julia
- `JuliaOS` - Core computational engine
- Supporting modules for specialized functionality

## Development

### Project Structure

- `src/` - Source code for the JuliaOS system
- `test/` - Tests for the JuliaOS system
- `packages/julia-bridge/` - JuliaOSBridge implementation
- `simple_server.jl` - Simplified server for testing and development
- `start_server.jl` - Full-featured server for production use
- `setup.jl` - Script to set up the Julia environment
- `test_bridge.jl` - Tests for the JuliaOSBridge
- `troubleshoot.jl` - Troubleshooting script

### Extending the Bridge

To extend the JuliaOSBridge with new functionality:

1. Edit `packages/julia-bridge/src/JuliaOSBridge.jl`
2. Add function implementations to the `_execute_function` mapping
3. Restart the server for changes to take effect

## Troubleshooting

If you encounter issues:

1. Run the troubleshooting script: `julia troubleshoot.jl`
2. Check the server logs
3. Verify that the JuliaOSBridge is properly installed
4. Make sure all required packages are installed

## Using the Wallet Connection Feature

JuliaOS includes a wallet connection feature accessible through `scripts/interactive.js` or the standalone `scripts/wallet_test.js` script.

### Connecting a Wallet

1. Start the Julia server:
   ```bash
   cd julia
   ./start.sh
   ```

2. Run the interactive script or wallet test script:
   ```bash
   node scripts/interactive.js
   # or
   node scripts/wallet_test.js
   ```

3. To connect a wallet:
   - From the main menu, select "Cross-Chain Hub"
   - Choose "Connect Wallet"
   - Select a connection mode:
     - **Address Only (Read-only)**: Enter any wallet address to view (no transactions)
     - **Private Key (Full Access)**: Enter a private key for full transaction capabilities
   - Select a blockchain network (Ethereum, Solana, etc.)
   - Enter your address or private key as requested

4. Wallet operations:
   - View balance (simulated in demonstration mode)
   - Send transactions (simulated)
   - View transaction history
   - Disconnect wallet

### Implementation Notes

- The wallet connection is a demonstration of CLI wallet functionality
- No real blockchain transactions are executed
- Private keys are not stored persistently or transmitted anywhere
- For production use, additional security measures would be needed

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