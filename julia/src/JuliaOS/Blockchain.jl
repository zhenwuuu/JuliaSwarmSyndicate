module Blockchain

using HTTP
using JSON
using Dates
using Base64
using SHA
using MbedTLS

export BlockchainConfig, BlockchainConnection, connect_to_chain, disconnect_from_chain
export get_balance, get_transaction, send_transaction, estimate_gas
export get_block_number, get_block, get_contract_code
export sign_transaction, verify_transaction

"""
    BlockchainConfig

Configuration for blockchain connection.
"""
struct BlockchainConfig
    chain_id::Int
    rpc_url::String
    ws_url::String
    network_name::String
    native_currency::String
    block_time::Int
    confirmations_required::Int
    max_gas_price::Int
    max_priority_fee::Int
end

"""
    BlockchainConnection

Represents an active connection to a blockchain.
"""
mutable struct BlockchainConnection
    config::BlockchainConfig
    http_client::Union{Nothing, HTTP.Messages.Response}
    ws_client::Union{Nothing, WebSockets.WebSocket}
    is_connected::Bool
    last_block_number::Int
    pending_transactions::Vector{Dict{String, Any}}
    
    BlockchainConnection(config::BlockchainConfig) = new(
        config, nothing, nothing, false, 0, []
    )
end

# Global registry for active connections
const ACTIVE_CONNECTIONS = Dict{String, BlockchainConnection}()

"""
    connect_to_chain(config::BlockchainConfig)

Establish connection to a blockchain network.
"""
function connect_to_chain(config::BlockchainConfig)
    if haskey(ACTIVE_CONNECTIONS, config.network_name)
        @warn "Already connected to $(config.network_name)"
        return ACTIVE_CONNECTIONS[config.network_name]
    end
    
    connection = BlockchainConnection(config)
    
    try
        # Initialize HTTP client
        connection.http_client = HTTP.Client()
        
        # Test connection
        response = HTTP.post(
            config.rpc_url,
            ["Content-Type" => "application/json"],
            JSON.json(Dict(
                "jsonrpc" => "2.0",
                "method" => "eth_blockNumber",
                "params" => [],
                "id" => 1
            ))
        )
        
        if response.status == 200
            result = JSON.parse(String(response.body))
            if haskey(result, "result")
                connection.last_block_number = parse(Int, result["result"], base=16)
                connection.is_connected = true
                ACTIVE_CONNECTIONS[config.network_name] = connection
                
                # Start WebSocket connection for real-time updates
                @async begin
                    try
                        WebSockets.open(config.ws_url) do ws
                            connection.ws_client = ws
                            while connection.is_connected
                                data = WebSockets.receive(ws)
                                handle_ws_message(data, connection)
                            end
                        end
                    catch e
                        @error "WebSocket error: $e"
                        connection.is_connected = false
                    end
                end
                
                return connection
            end
        end
        
        @error "Failed to connect to $(config.network_name)"
        return nothing
        
    catch e
        @error "Connection error: $e"
        return nothing
    end
end

"""
    disconnect_from_chain(network_name::String)

Disconnect from a blockchain network.
"""
function disconnect_from_chain(network_name::String)
    if !haskey(ACTIVE_CONNECTIONS, network_name)
        @warn "Not connected to $network_name"
        return false
    end
    
    connection = ACTIVE_CONNECTIONS[network_name]
    
    try
        connection.is_connected = false
        
        # Close WebSocket if active
        if connection.ws_client !== nothing
            WebSockets.close(connection.ws_client)
            connection.ws_client = nothing
        end
        
        # Close HTTP client
        if connection.http_client !== nothing
            connection.http_client = nothing
        end
        
        delete!(ACTIVE_CONNECTIONS, network_name)
        return true
        
    catch e
        @error "Failed to disconnect from $network_name: $e"
        return false
    end
end

"""
    get_balance(network_name::String, address::String)

Get the balance of an address on the specified network.
"""
function get_balance(network_name::String, address::String)
    if !haskey(ACTIVE_CONNECTIONS, network_name)
        @error "Not connected to $network_name"
        return nothing
    end
    
    connection = ACTIVE_CONNECTIONS[network_name]
    
    try
        response = HTTP.post(
            connection.config.rpc_url,
            ["Content-Type" => "application/json"],
            JSON.json(Dict(
                "jsonrpc" => "2.0",
                "method" => "eth_getBalance",
                "params" => [address, "latest"],
                "id" => 1
            ))
        )
        
        if response.status == 200
            result = JSON.parse(String(response.body))
            if haskey(result, "result")
                return parse(Int, result["result"], base=16)
            end
        end
        
        @error "Failed to get balance for $address on $network_name"
        return nothing
        
    catch e
        @error "Balance check error: $e"
        return nothing
    end
end

"""
    get_transaction(network_name::String, tx_hash::String)

Get transaction details from the specified network.
"""
function get_transaction(network_name::String, tx_hash::String)
    if !haskey(ACTIVE_CONNECTIONS, network_name)
        @error "Not connected to $network_name"
        return nothing
    end
    
    connection = ACTIVE_CONNECTIONS[network_name]
    
    try
        response = HTTP.post(
            connection.config.rpc_url,
            ["Content-Type" => "application/json"],
            JSON.json(Dict(
                "jsonrpc" => "2.0",
                "method" => "eth_getTransactionByHash",
                "params" => [tx_hash],
                "id" => 1
            ))
        )
        
        if response.status == 200
            result = JSON.parse(String(response.body))
            if haskey(result, "result")
                return result["result"]
            end
        end
        
        @error "Failed to get transaction $tx_hash on $network_name"
        return nothing
        
    catch e
        @error "Transaction lookup error: $e"
        return nothing
    end
end

"""
    estimate_gas(network_name::String, from::String, to::String, value::String, data::String="0x")

Estimate gas for a transaction.
"""
function estimate_gas(network_name::String, from::String, to::String, value::String, data::String="0x")
    if !haskey(ACTIVE_CONNECTIONS, network_name)
        @error "Not connected to $network_name"
        return nothing
    end
    
    connection = ACTIVE_CONNECTIONS[network_name]
    
    try
        response = HTTP.post(
            connection.config.rpc_url,
            ["Content-Type" => "application/json"],
            JSON.json(Dict(
                "jsonrpc" => "2.0",
                "method" => "eth_estimateGas",
                "params" => [[
                    "from" => from,
                    "to" => to,
                    "value" => value,
                    "data" => data
                ]],
                "id" => 1
            ))
        )
        
        if response.status == 200
            result = JSON.parse(String(response.body))
            if haskey(result, "result")
                return parse(Int, result["result"], base=16)
            end
        end
        
        @error "Failed to estimate gas for transaction on $network_name"
        return nothing
        
    catch e
        @error "Gas estimation error: $e"
        return nothing
    end
end

"""
    send_transaction(network_name::String, signed_tx::String)

Send a signed transaction to the network.
"""
function send_transaction(network_name::String, signed_tx::String)
    if !haskey(ACTIVE_CONNECTIONS, network_name)
        @error "Not connected to $network_name"
        return nothing
    end
    
    connection = ACTIVE_CONNECTIONS[network_name]
    
    try
        response = HTTP.post(
            connection.config.rpc_url,
            ["Content-Type" => "application/json"],
            JSON.json(Dict(
                "jsonrpc" => "2.0",
                "method" => "eth_sendRawTransaction",
                "params" => [signed_tx],
                "id" => 1
            ))
        )
        
        if response.status == 200
            result = JSON.parse(String(response.body))
            if haskey(result, "result")
                return result["result"]
            end
        end
        
        @error "Failed to send transaction on $network_name"
        return nothing
        
    catch e
        @error "Transaction send error: $e"
        return nothing
    end
end

"""
    get_block_number(network_name::String)

Get the current block number.
"""
function get_block_number(network_name::String)
    if !haskey(ACTIVE_CONNECTIONS, network_name)
        @error "Not connected to $network_name"
        return nothing
    end
    
    connection = ACTIVE_CONNECTIONS[network_name]
    
    try
        response = HTTP.post(
            connection.config.rpc_url,
            ["Content-Type" => "application/json"],
            JSON.json(Dict(
                "jsonrpc" => "2.0",
                "method" => "eth_blockNumber",
                "params" => [],
                "id" => 1
            ))
        )
        
        if response.status == 200
            result = JSON.parse(String(response.body))
            if haskey(result, "result")
                return parse(Int, result["result"], base=16)
            end
        end
        
        @error "Failed to get block number on $network_name"
        return nothing
        
    catch e
        @error "Block number lookup error: $e"
        return nothing
    end
end

"""
    get_block(network_name::String, block_number::Int)

Get block details by number.
"""
function get_block(network_name::String, block_number::Int)
    if !haskey(ACTIVE_CONNECTIONS, network_name)
        @error "Not connected to $network_name"
        return nothing
    end
    
    connection = ACTIVE_CONNECTIONS[network_name]
    
    try
        response = HTTP.post(
            connection.config.rpc_url,
            ["Content-Type" => "application/json"],
            JSON.json(Dict(
                "jsonrpc" => "2.0",
                "method" => "eth_getBlockByNumber",
                "params" => [string(block_number, base=16, pad=2), true],
                "id" => 1
            ))
        )
        
        if response.status == 200
            result = JSON.parse(String(response.body))
            if haskey(result, "result")
                return result["result"]
            end
        end
        
        @error "Failed to get block $block_number on $network_name"
        return nothing
        
    catch e
        @error "Block lookup error: $e"
        return nothing
    end
end

"""
    get_contract_code(network_name::String, address::String)

Get the bytecode of a deployed contract.
"""
function get_contract_code(network_name::String, address::String)
    if !haskey(ACTIVE_CONNECTIONS, network_name)
        @error "Not connected to $network_name"
        return nothing
    end
    
    connection = ACTIVE_CONNECTIONS[network_name]
    
    try
        response = HTTP.post(
            connection.config.rpc_url,
            ["Content-Type" => "application/json"],
            JSON.json(Dict(
                "jsonrpc" => "2.0",
                "method" => "eth_getCode",
                "params" => [address, "latest"],
                "id" => 1
            ))
        )
        
        if response.status == 200
            result = JSON.parse(String(response.body))
            if haskey(result, "result")
                return result["result"]
            end
        end
        
        @error "Failed to get contract code for $address on $network_name"
        return nothing
        
    catch e
        @error "Contract code lookup error: $e"
        return nothing
    end
end

"""
    handle_ws_message(data::String, connection::BlockchainConnection)

Handle incoming WebSocket messages.
"""
function handle_ws_message(data::String, connection::BlockchainConnection)
    try
        message = JSON.parse(data)
        
        if haskey(message, "method")
            if message["method"] == "eth_subscription"
                # Handle subscription updates
                if haskey(message, "params")
                    params = message["params"]
                    if haskey(params, "result")
                        result = params["result"]
                        if haskey(result, "number")
                            # Update block number
                            connection.last_block_number = parse(Int, result["number"], base=16)
                        end
                    end
                end
            end
        end
    catch e
        @error "WebSocket message handling error: $e"
    end
end

end # module 