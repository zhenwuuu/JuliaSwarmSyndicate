# JuliaOS Framework Test Suite

This directory contains the test suite for the JuliaOS Framework, which includes tests for all major components of the system.

## Test Structure

The test suite is organized into the following components:

- `runtests.jl`: Main test runner script
- `test_utils.jl`: Test utilities and helper functions
- `test_config.json`: Test configuration file
- `bridge_tests.jl`: Tests for bridge operations
- `market_data_tests.jl`: Tests for market data operations
- `swarm_tests.jl`: Tests for swarm management
- `cli_tests.jl`: Tests for CLI operations

## Running Tests

To run the test suite:

```bash
julia test/runtests.jl
```

To run specific test files:

```bash
julia test/bridge_tests.jl
julia test/market_data_tests.jl
julia test/swarm_tests.jl
julia test/cli_tests.jl
```

## Test Environment

The test suite uses a mock environment with the following features:

- Mock bridge implementation for cross-chain operations
- Mock market data provider for price and volume data
- Test configuration with predefined settings
- Isolated test directories for data and logs

## Test Coverage

The test suite covers:

1. Bridge Operations
   - Chain status monitoring
   - Token balance checking
   - Cross-chain transfers
   - Transaction monitoring
   - Bridge configuration

2. Market Data
   - Price data fetching
   - Volume data fetching
   - Historical data retrieval
   - Technical indicators
   - Market analysis

3. Swarm Management
   - Swarm creation and configuration
   - Agent management
   - Swarm coordination
   - Performance metrics
   - Parameter optimization
   - Risk management

4. CLI Operations
   - Command completion
   - Input validation
   - Command handling
   - Interactive mode
   - Progress display
   - Status display
   - Error handling
   - Configuration management
   - Help system

## Writing Tests

When adding new tests:

1. Use the test utilities in `test_utils.jl`
2. Follow the existing test structure
3. Include proper setup and teardown
4. Test both success and error cases
5. Validate input and output
6. Use descriptive test names
7. Add comments for complex test cases

## Test Utilities

The `test_utils.jl` module provides:

- Test data generators
- Mock implementations
- Test assertions
- Setup and teardown helpers
- Test environment management

## Configuration

The test configuration in `test_config.json` includes:

- Environment settings
- API keys (test values)
- Bridge configuration
- Agent settings
- Swarm parameters
- Dashboard settings
- Logging configuration
- Backup settings

## Contributing

When contributing to the test suite:

1. Follow the existing test structure
2. Add tests for new features
3. Update existing tests when modifying features
4. Ensure all tests pass
5. Add documentation for new test cases
6. Update the test README if necessary

## Troubleshooting

Common issues and solutions:

1. Test Environment Setup
   - Ensure test directories exist
   - Check test configuration file
   - Verify environment variables

2. Mock Data
   - Validate mock data structure
   - Check mock implementation
   - Verify data consistency

3. Test Failures
   - Check test logs
   - Verify test environment
   - Review test dependencies

## License

This test suite is part of the JuliaOS Framework and is licensed under the MIT License. 