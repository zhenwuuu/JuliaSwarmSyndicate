# JuliaOS Framework Maintenance Guide

This guide covers how to maintain and organize the JuliaOS Framework codebase.

## Project Structure

The JuliaOS Framework follows this organizational structure:

```
.
├── data/             # Runtime data storage
│   ├── agents/       # Agent data storage
│   └── ...           # Other data directories
├── julia/            # Julia language components
│   ├── src/          # Julia source code
│   │   ├── JuliaOS.jl     # Main Julia module
│   │   ├── AgentSystem.jl # Agent system implementation
│   │   ├── SwarmManager.jl # Swarm management functionality
│   │   └── ...            # Other Julia components
│   ├── julia_server.jl    # WebSocket/HTTP server (port 8052)
│   ├── apps/              # Application-specific Julia code
│   ├── examples/          # Example Julia implementations
│   ├── test/             # Julia tests
│   └── use_cases/        # Example use cases
├── packages/         # Core packages (monorepo)
│   ├── framework/    # Julia-based framework modules
│   │   ├── agents/   # Agent system interfaces for Julia backend
│   │   ├── swarms/   # Swarm intelligence algorithm interfaces
│   │   ├── blockchain/ # Blockchain interaction interfaces
│   │   ├── bridge/   # Communication bridge interfaces
│   │   ├── wallet/   # Wallet management interfaces
│   │   └── utils/    # Utility functions
│   ├── julia-bridge/ # WebSocket bridge to Julia backend
│   ├── core/         # Framework core functionality
│   ├── wallets/      # Wallet integrations (MetaMask, Phantom, Rabby)
│   ├── bridges/      # Cross-chain bridge implementations
│   └── ...           # Other packages
├── scripts/          # Utility scripts
│   ├── interactive.cjs # Main interactive CLI (connects to Julia server)
│   ├── server/       # Server management scripts
│   │   ├── run-server.sh  # Script to run the Julia server
│   │   └── ...       # Other server scripts
│   └── ...           # Other scripts
├── contracts/        # Smart contracts
└── ...
```

## Scripts and Entry Points

### Main Scripts

The framework provides several scripts to run the application:

1. **scripts/interactive.cjs**: Main interactive CLI
   - Command: `node scripts/interactive.cjs`
   - For help: `node scripts/interactive.cjs --help`

2. **scripts/server/run-server.sh**: Script to run the Julia server
   - Command: `cd scripts/server && ./run-server.sh`

### Usage Examples

```bash
# Start the Julia server
cd scripts/server
./run-server.sh

# In another terminal, run the interactive CLI
node scripts/interactive.cjs

# Run with custom configuration
node scripts/interactive.cjs --config ./my-config.json

# Get help on available options
node scripts/interactive.cjs --help
```

## Clean Code Guidelines

1. **Avoid Duplication**: Don't create duplicate directories or files for the same purpose.
2. **Use Proper Directory Structure**: Maintain separation of concerns in the directory structure.
3. **Archive Old Files**: Move old or replaced files to `old-files/` directories instead of creating backup files.
4. **Clean Build Artifacts**: Don't commit build artifacts to the repository.

## Where to Put New Code

- **New CLI Features**: Add to `scripts/interactive.cjs` for interactive CLI functionality.
- **New Julia Backend Features**: Add to `julia/src/` in the appropriate module.
- **New Cross-Chain Features**: Add to `packages/bridges/` for bridge implementations.
- **New Framework Modules**: Add to `packages/framework/` for reusable modules.

## Before Committing

1. **Clean Build Artifacts**:
   ```
   # Clean dist directories
   npm run clean

   # Remove other build artifacts if needed
   rm -rf .turbo/ dist/ target/ artifacts/ cache/
   ```

2. **Check for Sensitive Data**:
   - Ensure no private keys or API keys are committed
   - Check that `.env` files are not committed (only `.env.example`)
   - Verify no wallet data is included in commits

3. **Run Tests**:
   ```
   npm test
   ```

## Managing Dependencies

1. **Shared Dependencies**: Add to the root `package.json`
2. **Package-specific Dependencies**: Add to the specific package's `package.json`
3. **CLI Dependencies**: Add to `cli/package.json`

## Future Cleanup Tasks

As the project evolves, periodically review and clean up:

1. **Old Files**: Clean up `old-files/` directories when code is stable.
2. **Unused Dependencies**: Remove unused dependencies from package.json files.
3. **Build Artifacts**: Clean up build artifacts before committing.
4. **Test Data**: Remove test data that's no longer needed.

## Maintaining Julia Integration

1. **Julia-TypeScript Bridge**: Any changes to `julia/julia_server.jl` should be reflected in `packages/julia-bridge/src/index.ts`
2. **Julia Packages**: Keep the `julia/Project.toml` file updated with dependencies
3. **Julia Environment**: Update `julia/setup.jl` if new dependencies are required
4. **Server Scripts**: Update scripts in `scripts/server/` if server startup procedures change