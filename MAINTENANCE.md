# JuliaOS Framework Maintenance Guide

This guide covers how to maintain and organize the JuliaOS Framework codebase.

## Project Structure

The JuliaOS Framework follows this organizational structure:

```
.
├── agents/           # Root agent definitions (system level)
├── bridges/          # Cross-chain bridge implementations
│   ├── relay/        # Bridge relay service
│   ├── saved-routes/ # Saved bridge routes
│   └── solana-bridge/ # Solana bridge implementation
├── cli/              # CLI application
│   ├── agents/       # User-created agents (local data)
│   ├── data/         # CLI application data
│   ├── old-files/    # Archived files (can be deleted eventually)
│   ├── src/          # CLI source code
│   └── swarms/       # User-created swarms (local data)
├── contracts/        # Smart contracts
├── docs/             # Documentation
├── julia/            # Julia language components
│   ├── src/          # Julia source code
│   └── test/         # Julia tests
├── old-files/        # Root-level archived files
├── packages/         # Core packages (monorepo)
│   ├── core/         # Framework core functionality
│   ├── julia-bridge/ # TypeScript-Julia integration
│   └── ...           # Other packages
├── scripts/          # Utility scripts
└── ...
```

## Scripts and Entry Points

### Main Scripts

The framework provides several scripts to run the application:

1. **j3os.bat / j3os.sh**: Main entry point scripts with full functionality
   - Options for Docker, native, enhanced/standard modes
   - Command: `./j3os.sh` or `j3os.bat`
   - For help: `./j3os.sh --help` or `j3os.bat --help`

2. **cli/run-cli.bat / cli/run-cli.sh**: Simple CLI runners
   - Command: `cd cli && ./run-cli.sh` or `cd cli && run-cli.bat`

### Usage Examples

```
# Run enhanced CLI (default)
./j3os.sh
# or on Windows
j3os.bat

# Run in Docker mode
./j3os.sh --docker
# or on Windows
j3os.bat --docker

# Run with a specific command
./j3os.sh wallet create
# or on Windows
j3os.bat wallet create
```

## Clean Code Guidelines

1. **Avoid Duplication**: Don't create duplicate directories or files for the same purpose.
2. **Use Proper Directory Structure**: Maintain separation of concerns in the directory structure.
3. **Archive Old Files**: Move old or replaced files to `old-files/` directories instead of creating backup files.
4. **Clean Build Artifacts**: Don't commit build artifacts to the repository.

## Where to Put New Code

- **New CLI Features**: Add to `cli/src/commands/` for command handlers and `cli/src/` for core functionality.
- **New Julia Backend Features**: Add to `julia/src/` in the appropriate module.
- **New Cross-Chain Features**: Add to `bridges/` for bridge implementations.
- **New Packages**: Add to `packages/` for reusable modules.

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

1. **Julia-TypeScript Bridge**: Any changes to `julia/src/server.jl` should be reflected in `packages/julia-bridge/src/index.ts`
2. **Julia Packages**: Keep the `julia/Project.toml` file updated with dependencies
3. **Julia Environment**: Update `julia/setup.jl` if new dependencies are required 