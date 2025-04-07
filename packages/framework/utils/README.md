# JuliaOS Utils Module

The Utils module provides common utility functions shared across the JuliaOS framework. This module contains helper functions for formatting, encoding/decoding, logging, and other general-purpose utilities.

## Installation

To use the Utils module in your Julia project:

```julia
import Pkg
Pkg.add(url="https://github.com/juliaos/framework", subdir="packages/framework/utils")
```

Or add it to your project's dependencies:

```julia
# In your Project.toml
[deps]
Utils = "h1i2j3k4-8e92-11ee-055a-1befd66d0f22"
```

## Available Utilities

The Utils module provides the following utility functions:

- **Formatting**: `formatCurrency`, `formatDateTime`
- **JSON Handling**: `validateJSON`
- **Networking**: `retryWithBackoff`
- **Encoding**: `encodeHex`, `decodeHex`
- **Logging**: `logMessage`, `LogLevel`
- **Console Output**: `printProgress`

## Basic Usage

```julia
using Utils
using Dates

# Format currency values
eth_amount = formatCurrency(1.34567, "ETH", 4)  # "1.3457 ETH"
usd_amount = formatCurrency(1234.56, "$")       # "$1,234.56"

# Format dates and times
now_str = formatDateTime(now(), "yyyy-mm-dd HH:MM:SS")

# Validate JSON
json_str = """{"name": "JuliaOS", "version": "0.1.0"}"""
is_valid, error = validateJSON(json_str)
if is_valid
    println("Valid JSON")
else
    println("Invalid JSON: $error")
end

# Retry operations with backoff
result = retryWithBackoff(
    () -> begin
        # Some operation that might fail temporarily
        # (e.g., network request)
        return "success"
    end,
    3,     # max_retries
    1.0,   # initial_delay (seconds)
    2.0    # backoff_factor
)

# Encode/decode hex
hex_string = encodeHex("Hello, JuliaOS!")
original_bytes = decodeHex(hex_string)
original_string = String(original_bytes)

# Logging with different levels and context
logMessage(INFO, "System initialized", Dict("module" => "Agents", "count" => 5))
logMessage(WARNING, "Low disk space", Dict("available" => "1.2GB"))
logMessage(ERROR, "Failed to connect to server", Dict("server" => "api.example.com"))

# Display progress bar
for i in 1:100
    printProgress(i, 100, "Processing")
    sleep(0.01)  # Simulate work
end
```

## Detailed Usage

### Currency Formatting

```julia
# Format with different currencies and precision
formatCurrency(1234.56789, "ETH", 4)    # "1,234.5679 ETH"
formatCurrency(1234.56789, "$", 2)      # "$1,234.57"
formatCurrency(1234.56789, "€", 2)      # "€1,234.57"
formatCurrency(1234.56789, "BTC", 8)    # "1,234.56789000 BTC"

# Format without currency symbol
formatCurrency(1234.56789, "", 3)       # "1,234.568"
```

### Date and Time Formatting

```julia
using Dates

# Format current time
now_str = formatDateTime(now(), "yyyy-mm-dd HH:MM:SS")

# Format specific date
date = DateTime(2023, 4, 15, 13, 45, 30)
formatDateTime(date, "dd-mm-yyyy")            # "15-04-2023"
formatDateTime(date, "yyyy-mm-dd HH:MM:SS")   # "2023-04-15 13:45:30"
formatDateTime(date, "HH:MM")                 # "13:45"
```

### Retrying Operations

```julia
# Retry a network request with exponential backoff
function fetchData(url)
    return retryWithBackoff(
        () -> begin
            # This would be a real HTTP request in production
            if rand() < 0.7  # 70% chance of failure for demonstration
                throw(ErrorException("Network error"))
            end
            return Dict("status" => "success", "data" => [1, 2, 3])
        end,
        5,    # max_retries
        0.5,  # initial_delay (seconds)
        2.0   # backoff_factor (each retry doubles the wait)
    )
end

# Usage
try
    result = fetchData("https://api.example.com/data")
    println("Fetched data: $result")
catch e
    println("Failed after multiple retries: $e")
end
```

### Hex Encoding/Decoding

```julia
# Encode string to hex
hex_string = encodeHex("Hello, world!")
println(hex_string)  # "0x48656c6c6f2c20776f726c6421"

# Encode bytes to hex
bytes = [0x01, 0x02, 0x03, 0xff]
hex_bytes = encodeHex(bytes)
println(hex_bytes)  # "0x010203ff"

# Decode hex to bytes
decoded_bytes = decodeHex("0x48656c6c6f")
println(decoded_bytes)  # UInt8[0x48, 0x65, 0x6c, 0x6c, 0x6f]
println(String(decoded_bytes))  # "Hello"

# Decode without 0x prefix
decoded_bytes = decodeHex("010203ff")
println(decoded_bytes)  # UInt8[0x01, 0x02, 0x03, 0xff]
```

### Logging

```julia
# Define log levels
# DEBUG < INFO < WARNING < ERROR < CRITICAL
using Utils

# Basic logging
logMessage(DEBUG, "Debugging information")
logMessage(INFO, "User logged in")
logMessage(WARNING, "Disk space below 20%")
logMessage(ERROR, "Database connection failed")
logMessage(CRITICAL, "System crash")

# Logging with context
logMessage(INFO, "Transaction processed", Dict(
    "txHash" => "0x123...",
    "amount" => 1.5,
    "currency" => "ETH"
))

# Conditional logging based on level
function processData(data, verbose=false)
    # Log detailed information only if verbose
    if verbose
        logMessage(DEBUG, "Processing data", Dict("size" => length(data)))
    end
    
    # Always log important events
    logMessage(INFO, "Data processed successfully")
end
```

### Progress Display

```julia
# Simple progress bar
total_items = 100
for i in 1:total_items
    printProgress(i, total_items)
    # Simulate work
    sleep(0.05)
end

# Custom progress bar
function processFiles(files)
    total = length(files)
    for (i, file) in enumerate(files)
        printProgress(i, total, "Processing files", 40)
        # Process the file...
        sleep(0.1)
    end
end

# Usage
files = ["file1.txt", "file2.txt", "file3.txt", "file4.txt", "file5.txt"]
processFiles(files)
```

## Integration with Other Modules

The Utils module is designed to be used throughout the JuliaOS framework. Here's how it integrates with other modules:

```julia
using Utils
using JuliaOS.Agents
using JuliaOS.Wallet
using Dates

# Create an agent with a timestamp
agent = createAgent(AgentConfig(
    "trading_agent_" * string(Dates.format(now(), "yyyymmddHHMMSS")),
    "Trading",
    ["price_monitoring", "order_execution"],
    ["Ethereum"],
    Dict()
))

# Format agent creation timestamp
creation_time = formatDateTime(agent.created, "yyyy-mm-dd HH:MM:SS")
println("Agent created at: $creation_time")

# Format wallet balance
address = "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
wallet = connectWallet(address, ETHEREUM)
balance = getWalletBalance(address)["ETH"]
formatted_balance = formatCurrency(balance, "ETH", 6)
println("Wallet balance: $formatted_balance")
```

## License

MIT License 