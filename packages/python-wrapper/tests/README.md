# JuliaOS Python Wrapper Tests

This directory contains tests for the JuliaOS Python wrapper.

## Test Structure

- `unit/`: Unit tests for individual components
- `e2e/`: End-to-end tests for integration between components

## Running Tests

You can run the tests using the provided script:

```bash
./run_tests.sh
```

Or manually using pytest:

```bash
# Run all tests
pytest -xvs tests/

# Run only unit tests
pytest -xvs tests/unit/

# Run only end-to-end tests
pytest -xvs tests/e2e/

# Run a specific test file
pytest -xvs tests/e2e/test_agents.py

# Run a specific test
pytest -xvs tests/e2e/test_agents.py::test_agent_lifecycle
```

## Test Configuration

The tests use the following environment variables:

- `JULIAOS_HOST`: Host address of the JuliaOS server (default: `localhost`)
- `JULIAOS_PORT`: Port number of the JuliaOS server (default: `8080`)
- `JULIAOS_API_KEY`: API key for authentication (optional)

You can set these variables before running the tests:

```bash
export JULIAOS_HOST=localhost
export JULIAOS_PORT=8080
export JULIAOS_API_KEY=your_api_key
```

## Writing Tests

When writing tests, follow these guidelines:

1. Use the provided fixtures:
   - `juliaos_client`: A connected JuliaOS client
   - `clean_storage`: Cleans up storage before and after tests

2. Use descriptive test names and docstrings

3. Clean up resources after tests

4. Use appropriate assertions

5. Handle exceptions properly

## Example

```python
import pytest
from juliaos.agents import AgentType

@pytest.mark.asyncio
async def test_agent_creation(juliaos_client, clean_storage):
    """
    Test creating an agent.
    """
    # Create an agent
    agent = await juliaos_client.agents.create_agent(
        name="Test Agent",
        agent_type=AgentType.TRADING,
        config={"parameters": {}}
    )
    
    # Verify agent was created correctly
    assert agent.id is not None
    assert agent.name == "Test Agent"
    assert agent.type == AgentType.TRADING.value
    
    # Clean up
    await agent.delete()
```
