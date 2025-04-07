# JuliaOS Bridge Module

The JuliaBridge module provides a reliable communication layer between Julia applications and the JuliaOS backend server. This bridge allows you to execute functions on the server and receive responses, enabling your applications to leverage the computational power of the JuliaOS system.

## Installation

To use the JuliaBridge module in your Julia project:

```julia
import Pkg
Pkg.add(url="https://github.com/juliaos/framework", subdir="packages/framework/bridge")
```

Or add it to your project's dependencies:

```julia
# In your Project.toml
[deps]
JuliaBridge = "a1b2c3d4-8e8e-11ee-0556-1befd66d0f22"
```

## Basic Usage

```julia
using JuliaBridge

# Connect to the JuliaOS backend with default settings
# (localhost:8052)
connected = connect()
if connected
    println("Connected to JuliaOS backend!")
else
    println("Failed to connect to JuliaOS backend")
end

# Execute a function on the backend
if isConnected()
    # Create parameters for the function
    params = Dict(
        "name" => "test_agent",
        "type" => "monitoring"
    )
    
    # Execute the function
    response = execute("AgentSystem.createAgent", params)
    
    if response.success
        println("Function executed successfully!")
        println("Response data: ", response.data)
    else
        println("Function execution failed: ", response.error)
    end
end

# Disconnect when done
disconnect()
```

## Connection Configuration

You can customize the connection settings by providing a `BridgeConfig` object:

```julia
# Create a custom configuration
config = BridgeConfig(
    host = "192.168.1.100",  # Custom host address
    port = 8053,             # Custom port
    apiPath = "/api/v2/command",  # Custom API path
    healthPath = "/v2/health",    # Custom health endpoint
    timeout = 60             # Longer timeout (60 seconds)
)

# Connect with custom configuration
connected = connect(config)
```

## Health Check

You can check the health of the JuliaOS backend server:

```julia
# Perform a health check
health = healthCheck()

if health.success
    println("JuliaOS backend is healthy!")
    println("Server version: ", health.data.version)
    println("Server uptime: ", health.data.uptime)
else
    println("JuliaOS backend is not healthy: ", health.error)
end
```

## Error Handling

The bridge provides detailed error information:

```julia
try
    # Try to execute a function
    response = execute("NonExistentModule.nonExistentFunction", Dict())
    
    # Handle the response
    if response.success
        # Process successful response
    else
        println("Error: ", response.error)
    end
catch e
    if isa(e, BridgeException)
        println("Bridge error (code ", e.code, "): ", e.message)
    else
        println("Unexpected error: ", e)
    end
end
```

## Advanced Usage

### Batch Execution

```julia
function executeBatch(functions)
    results = []
    
    for (funcPath, params) in functions
        println("Executing $funcPath...")
        response = execute(funcPath, params)
        push!(results, response)
    end
    
    return results
end

# Define a batch of operations
batch = [
    ("AgentSystem.createAgent", Dict("name" => "agent1", "type" => "monitoring")),
    ("AgentSystem.createAgent", Dict("name" => "agent2", "type" => "trading")),
    ("SwarmManager.createSwarm", Dict("name" => "test_swarm", "algorithm" => "PSO"))
]

# Execute the batch
results = executeBatch(batch)

# Process results
for (i, result) in enumerate(results)
    println("Result $i: $(result.success ? "Success" : "Failed")")
end
```

### Automatic Reconnection

```julia
function executeWithRetry(functionPath, params, maxRetries=3)
    retries = 0
    
    while retries < maxRetries
        if !isConnected()
            println("Not connected, attempting to connect...")
            if !connect()
                println("Failed to connect, retrying... ($(retries+1)/$maxRetries)")
                retries += 1
                sleep(1)
                continue
            end
        end
        
        try
            return execute(functionPath, params)
        catch e
            println("Execution failed: $e")
            disconnect()  # Disconnect on error
            retries += 1
            sleep(1)
        end
    end
    
    return BridgeResponse(false, nothing, "Failed after $maxRetries retries", now())
end

# Use the retry function
response = executeWithRetry("AgentSystem.getStatus", Dict("id" => "agent_123"))
```

## Integration with JuliaOS Backend

The bridge module communicates with the JuliaOS backend service, which must be running for functionality to work.

To ensure the backend is running:

```bash
# From JuliaOS root directory
cd julia
./start.sh
```

## Additional Resources

- [JuliaOS Documentation](https://docs.juliaos.org)
- [Backend API Reference](https://docs.juliaos.org/backend-api)
- [Framework Overview](https://docs.juliaos.org/framework)

## License

MIT License 