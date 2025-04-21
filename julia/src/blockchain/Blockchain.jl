module Blockchain

using HTTP
using JSON
using Dates
using Base64
using Printf # Add Printf for formatting

export connect, getBalance, sendTransaction, getTransactionReceipt, isNodeHealthy
export getChainId, getGasPrice, getTokenBalance, sendRawTransaction, eth_call
export getTransactionCount, estimateGas, getDecimals # Added getDecimals export
export SUPPORTED_CHAINS, getEndpoint

# Supported blockchain networks
const SUPPORTED_CHAINS = [
    "ethereum", "polygon", "solana", "arbitrum", "optimism", 
    "base", "avalanche", "bsc", "fantom"
]

# Function to get environment variable with fallback
function getenv(key, default="")
    return get(ENV, key, default)
end

# Get RPC endpoint for a chain from environment variables
function getEndpoint(network)
    # Convert network name to uppercase for environment variable
    env_var = "$(uppercase(network))_RPC_URL"
    
    # Use specific environment variables for certain networks
    endpoint = if network == "ethereum"
        getenv("ETHEREUM_RPC_URL", "https://dry-capable-wildflower.quiknode.pro/2c509d168dcf3f71d49a4341f650c4b427be5b30")
    elseif network == "solana"
        getenv("SOLANA_RPC_URL", "https://cosmopolitan-restless-sunset.solana-mainnet.quiknode.pro/ca360edea8156bd1629813a9aaabbfceb5cc9d05")
    elseif network == "base"
        getenv("BASE_RPC_URL", "https://withered-boldest-waterfall.base-mainnet.quiknode.pro/38ed3b981b066d4bd33984e96f6809e54d6c71b8")
    elseif network == "arbitrum"
        getenv("ARBITRUM_RPC_URL", "https://wiser-thrilling-pool.arbitrum-mainnet.quiknode.pro/f7b7ccfade9f3ac53e01aaaff329dd5565239945")
    elseif network == "avalanche"
        getenv("AVALANCHE_RPC_URL", "https://green-cosmological-glade.avalanche-mainnet.quiknode.pro/aa5db7aa86b1576f08e44c51054d709f6698d485/ext/bc/C/rpc/")
    elseif network == "bsc"
        getenv("BSC_RPC_URL", "https://still-magical-orb.bsc.quiknode.pro/e14cb1f002c159ce0eb678a480698dc2abd7846c")
    elseif network == "fantom"
        getenv("FANTOM_RPC_URL", "https://distinguished-icy-meme.fantom.quiknode.pro/69343151a0265c018d02ecfbca4b62a6c011fe1b")
    elseif network == "polygon"
        getenv("POLYGON_RPC_URL", "https://polygon-mainnet.infura.io/v3")
    elseif network == "optimism"
        getenv("OPTIMISM_RPC_URL", "https://mainnet.optimism.io")
    else
        getenv(env_var, "")
    end
    
    if endpoint == ""
        @warn "No endpoint provided for $network. Using default or mock endpoint."
        return "http://localhost:8545"  # Default fallback
    end
    
    return endpoint
end

# Connect to a blockchain network
function connect(; network="ethereum", endpoint="")
    if !(network in SUPPORTED_CHAINS)
        @warn "Unsupported network: $network. Supported networks: $(join(SUPPORTED_CHAINS, ", "))"
    end
    
    # If no endpoint provided, get from environment
    if endpoint == ""
        endpoint = getEndpoint(network)
    end
    
    # Test connection
    is_healthy = try
        isNodeHealthy(Dict("network" => network, "endpoint" => endpoint))
    catch e
        @warn "Failed to connect to $network at $endpoint: $e"
        false
    end
    
    return Dict(
        "network" => network,
        "endpoint" => endpoint,
        "connected" => is_healthy,
        "timestamp" => now()
    )
end

# Get balance for an address
function getBalance(address, connection)
    network = connection["network"]
    endpoint = connection["endpoint"]
    
    if !connection["connected"]
        error("Not connected to network: $network")
    end
    
    try
        if network in ["ethereum", "polygon", "arbitrum", "optimism", "base", "bsc", "avalanche", "fantom"]
            # Ethereum-compatible call
            response = HTTP.post(
                endpoint,
                ["Content-Type" => "application/json"],
                JSON.json(Dict(
                    "jsonrpc" => "2.0",
                    "method" => "eth_getBalance",
                    "params" => [address, "latest"],
                    "id" => 1
                ))
            )
            
            result = JSON.parse(String(response.body))
            if haskey(result, "result")
                # Convert hex result to decimal
                hex_result = result["result"]
                # Remove "0x" prefix and convert to integer
                balance_wei = parse(BigInt, hex_result[3:end], base=16)
                # Convert wei to ether (1 ether = 10^18 wei)
                balance_eth = balance_wei / BigInt(10)^18
                return balance_eth
            else
                error("Failed to get balance: $(get(result, "error", "Unknown error"))")
            end
        elseif network == "solana"
            # Solana-specific call
            response = HTTP.post(
                endpoint,
                ["Content-Type" => "application/json"],
                JSON.json(Dict(
                    "jsonrpc" => "2.0",
                    "id" => 1,
                    "method" => "getBalance",
                    "params" => [address]
                ))
            )
            
            result = JSON.parse(String(response.body))
            if haskey(result, "result") && haskey(result["result"], "value")
                # Solana balance is in lamports (1 SOL = 10^9 lamports)
                balance_lamports = result["result"]["value"]
                balance_sol = balance_lamports / 1_000_000_000
                return balance_sol
            else
                error("Failed to get Solana balance: $(get(result, "error", "Unknown error"))")
            end
        else
            error("Unsupported network for balance check: $network")
        end
    catch e
        @warn "Error getting balance: $e"
        return 0.0
    end
end

# Get chain ID
function getChainId(connection)
    network = connection["network"]
    endpoint = connection["endpoint"]
    
    if !connection["connected"]
        error("Not connected to network: $network")
    end
    
    try
        if network in ["ethereum", "polygon", "arbitrum", "optimism", "base", "bsc", "avalanche", "fantom"]
            response = HTTP.post(
                endpoint,
                ["Content-Type" => "application/json"],
                JSON.json(Dict(
                    "jsonrpc" => "2.0",
                    "method" => "eth_chainId",
                    "params" => [],
                    "id" => 1
                ))
            )
            
            result = JSON.parse(String(response.body))
            if haskey(result, "result")
                hex_chain_id = result["result"]
                chain_id = parse(Int, hex_chain_id[3:end], base=16)
                return chain_id
            else
                error("Failed to get chain ID: $(get(result, "error", "Unknown error"))")
            end
        elseif network == "solana"
            # Solana doesn't have a chain ID in the same way as EVM chains
            # Return 1 for Mainnet, 2 for Testnet
            return 1
        else
            error("Unsupported network for chain ID: $network")
        end
    catch e
        @warn "Error getting chain ID: $e"
        return 0
    end
end

# Get gas price
function getGasPrice(connection)
    network = connection["network"]
    endpoint = connection["endpoint"]
    
    if !connection["connected"]
        error("Not connected to network: $network")
    end
    
    try
        if network in ["ethereum", "polygon", "arbitrum", "optimism", "base", "bsc", "avalanche", "fantom"]
            response = HTTP.post(
                endpoint,
                ["Content-Type" => "application/json"],
                JSON.json(Dict(
                    "jsonrpc" => "2.0",
                    "method" => "eth_gasPrice",
                    "params" => [],
                    "id" => 1
                ))
            )
            
            result = JSON.parse(String(response.body))
            if haskey(result, "result")
                hex_gas_price = result["result"]
                gas_price_wei = parse(BigInt, hex_gas_price[3:end], base=16)
                gas_price_gwei = gas_price_wei / BigInt(10)^9
                return gas_price_gwei
            else
                error("Failed to get gas price: $(get(result, "error", "Unknown error"))")
            end
        elseif network == "solana"
            # For Solana, get recent blockhash and associated fee
            response = HTTP.post(
                endpoint,
                ["Content-Type" => "application/json"],
                JSON.json(Dict(
                    "jsonrpc" => "2.0",
                    "id" => 1,
                    "method" => "getFees",
                    "params" => []
                ))
            )
            
            result = JSON.parse(String(response.body))
            if haskey(result, "result") && haskey(result["result"], "feeCalculator")
                # Extract lamports per signature
                fee = result["result"]["feeCalculator"]["lamportsPerSignature"]
                return fee
            else
                error("Failed to get Solana fee: $(get(result, "error", "Unknown error"))")
            end
        else
            error("Unsupported network for gas price: $network")
        end
    catch e
        @warn "Error getting gas price: $e"
        return 0.0
    end
end

# Get transaction count (nonce)
function getTransactionCount(address::String, connection::Dict)
    network = connection["network"]
    endpoint = connection["endpoint"]
    if !connection["connected"]
        error("Not connected to network: $network for getTransactionCount")
    end

    try
        if network in ["ethereum", "polygon", "arbitrum", "optimism", "base", "bsc", "avalanche", "fantom"]
            response = HTTP.post(
                endpoint,
                ["Content-Type" => "application/json"],
                JSON.json(Dict(
                    "jsonrpc" => "2.0",
                    "method" => "eth_getTransactionCount",
                    "params" => [address, "latest"],
                    "id" => rand(UInt32)
                ))
            )
            response_body = String(response.body)
            result = JSON.parse(response_body)

            if haskey(result, "result")
                nonce_hex = result["result"]
                return parse(Int, nonce_hex[3:end], base=16)
            elseif haskey(result, "error")
                error_details = result["error"]
                error("eth_getTransactionCount failed: $(get(error_details, "message", "Unknown RPC error"))")
            else
                error("eth_getTransactionCount failed with unexpected response: $response_body")
            end
        else
            error("getTransactionCount not supported for network: $network")
        end
    catch e
        @error "Error getting transaction count for $address on $network: $e"
        rethrow(e)
    end
end

# Estimate gas for a transaction (placeholder/basic implementation)
function estimateGas(tx_params::Dict, connection::Dict)
    network = connection["network"]
    endpoint = connection["endpoint"]
    if !connection["connected"]
        error("Not connected to network: $network for estimateGas")
    end

    # Ensure required fields are present (to, from, data, value)
    if !haskey(tx_params, "to") || !haskey(tx_params, "from")
         error("Missing required fields 'to' or 'from' for estimateGas")
     end
     # Default optional fields if missing
     tx_call_params = Dict(
         "from" => tx_params["from"],
         "to" => tx_params["to"],
         "gas" => get(tx_params, "gas", nothing), # Usually omitted for estimateGas itself
         "gasPrice" => get(tx_params, "gasPrice", nothing), # Usually omitted
         "value" => get(tx_params, "value", "0x0"),
         "data" => get(tx_params, "data", "0x")
     )

    try
        if network in ["ethereum", "polygon", "arbitrum", "optimism", "base", "bsc", "avalanche", "fantom"]
            response = HTTP.post(
                endpoint,
                ["Content-Type" => "application/json"],
                JSON.json(Dict(
                    "jsonrpc" => "2.0",
                    "method" => "eth_estimateGas",
                    "params" => [tx_call_params],
                    "id" => rand(UInt32)
                ))
            )
            response_body = String(response.body)
            result = JSON.parse(response_body)

            if haskey(result, "result")
                gas_hex = result["result"]
                # Add a buffer (e.g., 20%) to the estimate
                estimated_gas = parse(Int, gas_hex[3:end], base=16)
                buffered_gas = Int(ceil(estimated_gas * 1.2))
                @info "Gas estimate: $estimated_gas, Buffered: $buffered_gas" tx_params=tx_params
                return buffered_gas
            elseif haskey(result, "error")
                error_details = result["error"]
                err_msg = get(error_details, "message", "Unknown RPC error")
                err_data = get(error_details, "data", "N/A")
                @error "eth_estimateGas failed: $err_msg" details=error_details params=tx_call_params
                # Provide a high default gas limit as fallback? Or error out?
                # Erroring out is safer to prevent unexpected high fees.
                error("eth_estimateGas failed: $err_msg (Data: $err_data)")
            else
                error("eth_estimateGas failed with unexpected response: $response_body")
            end
        else
            # Return a high default for unsupported networks? Safer to error.
            error("estimateGas not supported for network: $network")
        end
    catch e
        @error "Error estimating gas on $network: $e" tx_params=tx_params
        rethrow(e)
    end
end

# Generic eth_call function
function eth_call(to::String, data::String, connection::Dict)
    network = connection["network"]
    endpoint = connection["endpoint"]

    if !connection["connected"]
        error("Not connected to network: $network for eth_call")
    end

    # Ensure data starts with 0x
    if !startswith(data, "0x")
        data = "0x" * data
    end

    try
        if network in ["ethereum", "polygon", "arbitrum", "optimism", "base", "bsc", "avalanche", "fantom"]
            response = HTTP.post(
                endpoint,
                ["Content-Type" => "application/json"],
                JSON.json(Dict(
                    "jsonrpc" => "2.0",
                    "method" => "eth_call",
                    "params" => [
                        Dict(
                            "to" => to,
                            "data" => data
                        ),
                        "latest"
                    ],
                    "id" => rand(UInt32) # Use random ID
                ))
            )

            response_body = String(response.body)
            result = JSON.parse(response_body)

            if haskey(result, "result")
                # Return the raw hex result
                return result["result"]
            elseif haskey(result, "error")
                 error_details = result["error"]
                 error_msg = "eth_call failed: $(get(error_details, "message", "Unknown RPC error")) (Code: $(get(error_details, "code", "N/A")))"
                 # Optionally include data in error: $(get(error_details, "data", "N/A"))
                 error(error_msg)
            else
                error("eth_call failed with unexpected response: $response_body")
            end
        else
            error("eth_call is not supported for network: $network")
        end
    catch e
        @error "Error during eth_call to $to on $network: $e" data=data
        rethrow(e)
    end
end

# Get token decimals for an ERC20 token
function getDecimals(token_address::String, connection::Dict)::Union{Int, Nothing}
    network = connection["network"]
    if !connection["connected"]
        error("Not connected to network: $network for getDecimals")
    end

    # ERC20 decimals() function signature: 0x313ce567
    data = "0x313ce567"

    try
        if network in ["ethereum", "polygon", "arbitrum", "optimism", "base", "bsc", "avalanche", "fantom"]
            hex_result = eth_call(token_address, data, connection)

            # Check for empty or invalid results
            if hex_result == "0x" || isempty(hex_result) || length(hex_result) <= 2
                @warn "getDecimals eth_call returned empty/invalid result for $token_address on $network."
                return nothing # Indicate failure to get decimals
            end

            # Convert hex result to integer
            decimals_val = tryparse(Int, hex_result[3:end], base=16)
            if isnothing(decimals_val)
                 @error "Failed to parse decimals result: $hex_result for $token_address on $network"
                 return nothing
             end
            return decimals_val
        elseif network == "solana"
            # TODO: Implement SPL token decimals fetching (requires different method)
            @warn "getDecimals not implemented for Solana SPL tokens yet." token=token_address
            return nothing
        else
            error("getDecimals is not supported for network: $network")
        end
    catch e
        # Log error but return nothing to allow calling code to handle missing decimals
        @error "Error getting token decimals for $token_address on $network: $e" token=token_address error=e
        return nothing
    end
end

# Get token balance for an address (updated to use getDecimals)
function getTokenBalance(address, token_address, connection)
    network = connection["network"]

    if !connection["connected"]
        error("Not connected to network: $network for getTokenBalance")
    end

    try
        if network in ["ethereum", "polygon", "arbitrum", "optimism", "base", "bsc", "avalanche", "fantom"]
            # ERC20 balanceOf function signature: 0x70a08231
            padded_address = lpad(address[3:end], 64, '0')
            data = "0x70a08231" * padded_address

            hex_result = eth_call(token_address, data, connection)

            if hex_result == "0x" || isempty(hex_result)
                 @warn "getTokenBalance eth_call returned empty result for $token_address, address $address"
                 return 0.0
             end

            balance_wei = tryparse(BigInt, hex_result[3:end], base=16)
            if isnothing(balance_wei)
                 error("Failed to parse balance result: $hex_result")
            end

            # Fetch decimals dynamically
            decimals = getDecimals(token_address, connection)
            if isnothing(decimals)
                @warn "Could not determine decimals for token $token_address on $network. Assuming 18 for balance calculation."
                decimals = 18 # Default fallback
            end

            balance_token = balance_wei / BigInt(10)^decimals
            return balance_token

        elseif network == "solana"
            # TODO: Implement SPL token balance fetching
            error("Solana token balance not yet implemented")
        else
            error("Unsupported network for token balance: $network")
        end
    catch e
        @error "Error getting token balance for $token_address on $network: $e" address=address
        return 0.0
    end
end

# Send a raw transaction
function sendRawTransaction(tx, connection)
    network = connection["network"]
    endpoint = connection["endpoint"]
    
    if !connection["connected"]
        error("Not connected to network: $network")
    end
    
    try
        if network in ["ethereum", "polygon", "arbitrum", "optimism", "base", "bsc", "avalanche", "fantom"]
            response = HTTP.post(
                endpoint,
                ["Content-Type" => "application/json"],
                JSON.json(Dict(
                    "jsonrpc" => "2.0",
                    "method" => "eth_sendRawTransaction",
                    "params" => [tx],
                    "id" => 1
                ))
            )
            
            result = JSON.parse(String(response.body))
            if haskey(result, "result")
                return result["result"]  # Transaction hash
            else
                error("Failed to send transaction: $(get(result, "error", "Unknown error"))")
            end
        elseif network == "solana"
            response = HTTP.post(
                endpoint,
                ["Content-Type" => "application/json"],
                JSON.json(Dict(
                    "jsonrpc" => "2.0",
                    "id" => 1,
                    "method" => "sendTransaction",
                    "params" => [tx, Dict("encoding" => "base64")]
                ))
            )
            
            result = JSON.parse(String(response.body))
            if haskey(result, "result")
                return result["result"]  # Transaction signature
            else
                error("Failed to send Solana transaction: $(get(result, "error", "Unknown error"))")
            end
        else
            error("Unsupported network: $network")
        end
    catch e
        @warn "Error sending transaction: $e"
        error("Transaction failed: $e")
    end
end

# Send a transaction
function sendTransaction(tx, connection)
    network = connection["network"]
    endpoint = connection["endpoint"]
    
    if !connection["connected"]
        error("Not connected to network: $network")
    end
    
    # This function assumes the transaction is already signed
    # In a real implementation, we would handle signing here or elsewhere
    return sendRawTransaction(tx, connection)
end

# Get transaction receipt
function getTransactionReceipt(txHash, connection)
    network = connection["network"]
    endpoint = connection["endpoint"]
    
    if !connection["connected"]
        error("Not connected to network: $network")
    end
    
    try
        if network in ["ethereum", "polygon", "arbitrum", "optimism", "base", "bsc", "avalanche", "fantom"]
            # Ethereum-compatible call
            response = HTTP.post(
                endpoint,
                ["Content-Type" => "application/json"],
                JSON.json(Dict(
                    "jsonrpc" => "2.0",
                    "method" => "eth_getTransactionReceipt",
                    "params" => [txHash],
                    "id" => 1
                ))
            )
            
            result = JSON.parse(String(response.body))
            return get(result, "result", nothing)
        elseif network == "solana"
            # Solana-specific call
            response = HTTP.post(
                endpoint,
                ["Content-Type" => "application/json"],
                JSON.json(Dict(
                    "jsonrpc" => "2.0",
                    "id" => 1,
                    "method" => "getTransaction",
                    "params" => [txHash, Dict("encoding" => "json")]
                ))
            )
            
            result = JSON.parse(String(response.body))
            return get(result, "result", nothing)
        else
            error("Unsupported network: $network")
        end
    catch e
        @warn "Error getting transaction receipt: $e"
        return nothing
    end
end

# Check if the node is healthy
function isNodeHealthy(connection)
    network = connection["network"]
    endpoint = connection["endpoint"]
    
    try
        if network in ["ethereum", "polygon", "arbitrum", "optimism", "base", "bsc", "avalanche", "fantom"]
            # Ethereum-compatible health check
            response = HTTP.post(
                endpoint,
                ["Content-Type" => "application/json"],
                JSON.json(Dict(
                    "jsonrpc" => "2.0",
                    "method" => "web3_clientVersion",
                    "params" => [],
                    "id" => 1
                ))
            )
            
            result = JSON.parse(String(response.body))
            return haskey(result, "result")
        elseif network == "solana"
            # Solana-specific health check
            response = HTTP.post(
                endpoint,
                ["Content-Type" => "application/json"],
                JSON.json(Dict(
                    "jsonrpc" => "2.0",
                    "id" => 1,
                    "method" => "getHealth",
                    "params" => []
                ))
            )
            
            result = JSON.parse(String(response.body))
            return get(result, "result", "") == "ok"
        else
            @warn "Unsupported network for health check: $network"
            return false
        end
    catch e
        @warn "Health check failed for $network: $e"
        return false
    end
end

end # module 