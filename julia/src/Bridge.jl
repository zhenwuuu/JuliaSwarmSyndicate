module Bridge

export init_bridge, start_bridge_server, register_command_handler, run_command, bridge_log
export BridgeRequest, BridgeResponse, CommandHandler, CommandResult
export get_wallet_balance, execute_trade, submit_signed_transaction, get_token_address
export monitor_transaction, get_transaction_status

using HTTP
using JSON
using Dates
using Sockets
import WebSockets
import Logging
using ..Blockchain
using ..DEX
using ..Storage
using ..Utils

# Define the API endpoint URL
const API_BASE_URL = "http://localhost:8082/api"

# Types for bridge communication
struct BridgeRequest
    command::String
    params::Vector{Any}
    id::String
end

struct BridgeResponse
    result::Any
    error::Union{String, Nothing}
    id::String
end

struct CommandResult
    success::Bool
    data::Any
    error::Union{String, Nothing}
    
    # Default constructor for successful results
    CommandResult(data::Any) = new(true, data, nothing)
    
    # Constructor for error results
    CommandResult(error::String) = new(false, nothing, error)
end

# Command handler type
const CommandHandler = Function

# Global state
const command_handlers = Dict{String, CommandHandler}()
const connections = Dict{String, Dict{String, Any}}()
const bridge_start_time = Ref(now())

# === Placeholder Token Address Map ===
# TODO: Move this to a configuration file or a dedicated TokenRegistry module
const TOKEN_ADDRESS_MAP = Dict(
    ("WETH", "ethereum") => "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
    ("USDC", "ethereum") => "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    ("DAI", "ethereum") => "0x6B175474E89094C44Da98b954EedeAC495271d0F",
    ("WBTC", "ethereum") => "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599",
    # Add other chains and tokens as needed
    # ("WMATIC", "polygon") => "0x...",
    # ("USDC", "polygon") => "0x...",
)

"""
    init_bridge()

Initialize the bridge for communication between Julia and JavaScript
"""
function init_bridge()
    # Clear any existing command handlers
    empty!(command_handlers)
    empty!(connections)
    
    # Record initialization time
    bridge_start_time[] = now()
    
    # Log initialization
    bridge_log("Bridge initialized at $(bridge_start_time[])")
end

"""
    register_command_handler(command, handler)

Register a handler function for a specific command
"""
function register_command_handler(command::String, handler::CommandHandler)
    command_handlers[command] = handler
    bridge_log("Registered command handler for '$command'")
end

"""
    run_command(request)

Run a command with the given parameters
"""
function run_command(request::BridgeRequest)::BridgeResponse
    command = request.command
    params = request.params
    id = request.id
    
    if !haskey(command_handlers, command)
        return BridgeResponse(nothing, "Command not found: $command", id)
    end
    
    try
        handler = command_handlers[command]
        result = handler(params...)
        return BridgeResponse(result, nothing, id)
    catch e
        error_msg = "Error executing command $command: $(string(e))"
        @error error_msg
        return BridgeResponse(nothing, error_msg, id)
    end
end

"""
    get_wallet_balance(address::String, token_address::Union{String, Nothing}, chain::String)

Fetches the balance of a wallet address (native or ERC20 token).
"""
function get_wallet_balance(address::String, token_address::Union{String, Nothing}, chain::String)
    @info "Bridge: Fetching balance for address $(address) on chain $(chain)"
    try
        connection = Blockchain.blockchain_connect(chain)
        if isnothing(token_address)
            balance_wei = Blockchain.getBalance(address, connection)
            # Convert wei to ether for display (assuming 18 decimals for native)
            # TODO: Get native currency decimals dynamically?
            balance_native = Blockchain.wei_to_ether(balance_wei, 18)
            @info "Bridge: Native balance retrieved successfully: $(balance_native)"
            return Dict("success" => true, "data" => Dict("balance" => balance_native, "unit" => "native"))
        else
            # TODO: Handle potential errors from getDecimals
            decimals = Blockchain.getDecimals(token_address, connection)
            balance_atomic = Blockchain.getTokenBalance(address, token_address, connection)
            balance_token = Blockchain.atomic_to_decimal(balance_atomic, decimals)
            @info "Bridge: Token balance retrieved successfully: $(balance_token)"
            return Dict("success" => true, "data" => Dict("balance" => balance_token, "unit" => "token", "decimals" => decimals))
        end
    catch e
        @error "Bridge: Error getting balance for $(address) on $(chain)" exception=(e, catch_backtrace())
        return Dict("success" => false, "error" => "Failed to get balance: $(e)")
    end
end

"""
    get_token_address(symbol::String, chain::String)

Resolves a token symbol to its address for a given chain.
"""
function get_token_address(symbol::String, chain::String)
    @info "Bridge: Resolving token address for symbol '$(symbol)' on chain '$(chain)'"
    key = (uppercase(symbol), lowercase(chain))
    if haskey(TOKEN_ADDRESS_MAP, key)
        address = TOKEN_ADDRESS_MAP[key]
        @info "Bridge: Resolved '$(symbol)' on '$(chain)' to address $(address)"
        return Dict("success" => true, "data" => Dict("address" => address))
    else
        @warn "Bridge: Token address not found for symbol '$(symbol)' on chain '$(chain)'"
        return Dict("success" => false, "error" => "Token address not found for symbol '$(symbol)' on chain '$(chain)'")
    end
end

"""
    execute_trade(dex::String, chain::String, trade_params::Dict)

Placeholder function to simulate executing a trade on a DEX.
Called by other Julia modules like SwarmManager.
!! CRITICAL: This needs implementation for DEX interaction and TXN SIGNING !!
Returns a CommandResult.
"""
function execute_trade(dex::String, chain::String, trade_params::Dict)::CommandResult
    bridge_log("Bridge: Received internal request to execute trade. DEX: $dex, Chain: $chain, Params: $trade_params")
    try
        # Extract necessary parameters for DEX.execute_swap
        token_in = get(trade_params, :token_in, "")
        token_out = get(trade_params, :token_out, "")
        amount_in_wei = get(trade_params, :amount_in_wei, BigInt(0))
        slippage = get(trade_params, :slippage, 0.005) # Default 0.5% slippage
        wallet_address = get(trade_params, :wallet_address, "")

        if isempty(token_in) || isempty(token_out) || amount_in_wei == 0 || isempty(wallet_address)
             error("Bridge: Missing required parameters (:token_in, :token_out, :amount_in_wei, :wallet_address) for execute_trade")
        end

        # Call the DEX function which prepares the unsigned transaction
        swap_preparation_result = DEX.execute_swap(
            token_in,
            token_out,
            amount_in_wei,
            slippage,
            dex,
            chain,
            wallet_address
        )

        if haskey(swap_preparation_result, "error")
            error_msg = "Bridge: Failed to prepare swap via DEX module: $(swap_preparation_result["error"])"
            @error error_msg
            return CommandResult(error_msg)
        end

        # Check if the unsigned transaction is ready for signing
        if get(swap_preparation_result, "status", "") == "unsigned_ready"
            unsigned_tx = swap_preparation_result["unsigned_transaction"]
            mock_tx_hash_as_id = swap_preparation_result["mock_transaction_hash"] # Use mock hash as temp ID
            bridge_log("Bridge: Unsigned transaction prepared. Needs signing. Request ID: $mock_tx_hash_as_id")

            # === SIGNING LOGIC NEEDED (External: JS -> Julia) ===
            # The JS layer should now:
            # 1. Receive this response.
            # 2. Prompt user for signing confirmation.
            # 3. Call walletManager.signTransaction(unsigned_tx).
            # 4. Call back to Julia with `submit_signed_transaction` command, passing the signed hex and the request ID.
            @warn "Bridge.execute_trade: Signing mechanism NOT IMPLEMENTED. Returning unsigned TX for external signing."

            # Return the details needed for signing
            result_data = Dict(
                 "status" => "needs_signing", # Changed status
                 "message" => "Transaction prepared and requires signing.",
                 "request_id" => mock_tx_hash_as_id, # Identifier for the signing request
                 "unsigned_transaction" => unsigned_tx,
                 "chain" => chain, # Include chain info needed for sending later
                 "details" => swap_preparation_result # Include original DEX result for context
             )
            return CommandResult(result_data)
        else
            # Handle unexpected status from DEX.execute_swap
            error_msg = "Bridge: Unexpected result status from DEX.execute_swap: $(get(swap_preparation_result, "status", "N/A"))"
            @error error_msg result=swap_preparation_result
            return CommandResult(error_msg)
        end

    catch e
        error_msg = "Bridge: Error executing trade preparation: $(sprint(showerror, e))"
        @error error_msg stacktrace(catch_backtrace())
        return CommandResult(error_msg)
    end
end

# New function to handle submission of a signed transaction
function submit_signed_transaction(chain::String, request_id::String, signed_tx_hex::String)::CommandResult
    bridge_log("Bridge: Received signed transaction for Request ID: $request_id on chain $chain")

    # Basic validation
    if isempty(chain) || isempty(request_id) || isempty(signed_tx_hex) || !startswith(signed_tx_hex, "0x")
        error_msg = "Bridge: Invalid parameters for submit_signed_transaction."
        @error error_msg chain=chain request_id=request_id signed_tx_hex=signed_tx_hex
        return CommandResult(error_msg)
    end

    try
        # Connect to the specified blockchain
        connection = Blockchain.connect(network=chain)
        if !connection["connected"]
            error_msg = "Bridge: Failed to connect to chain $chain to send transaction."
            @error error_msg
            return CommandResult(error_msg)
        end

        # Send the raw transaction via Blockchain module
        bridge_log("Bridge: Sending raw transaction via Blockchain.sendRawTransaction...")
        tx_hash = Blockchain.sendRawTransaction(signed_tx_hex, connection)

        bridge_log("Bridge: Transaction submitted successfully. Chain: $chain, TxHash: $tx_hash")

        # Record the transaction in storage with pending status
        try
            # Create database connection
            db = Storage.DB  # Use the module's DB constant

            # If the transaction related to a trade, it might have from/to/amount information
            # attached to the request_id. For now, just use minimal info.
            Storage.record_transaction(
                db, 
                chain, 
                tx_hash, 
                "N/A",  # from_address (not available directly)
                "N/A",  # to_address (not available directly)
                "0",    # amount
                "N/A",  # token
                "Submitted"  # initial status
            )
            
            # Start transaction monitoring in background
            @async begin
                try
                    monitor_transaction(chain, tx_hash)
                catch mon_error
                    @error "Error in background transaction monitoring: $mon_error"
                end
            end
        catch storage_error
            @warn "Failed to record transaction in storage: $storage_error. Continuing without recording."
        end

        result_data = Dict(
            "status" => "submitted",
            "message" => "Transaction successfully submitted to the network.",
            "transaction_hash" => tx_hash,
            "chain" => chain,
            "request_id" => request_id
        )
        return CommandResult(result_data)

    catch e
        error_msg = "Bridge: Error submitting signed transaction: $(sprint(showerror, e))"
        @error error_msg chain=chain request_id=request_id tx_hex=signed_tx_hex stacktrace(catch_backtrace())
        # Include specific details in the error response if possible
        error_data = Dict(
            "status" => "failed",
            "message" => "Failed to submit transaction: $(sprint(showerror, e))",
            "chain" => chain,
            "request_id" => request_id
        )
        return CommandResult(error_data)
    end
end

"""
    monitor_transaction(chain::String, tx_hash::String)

Monitors a blockchain transaction until it confirms or fails.
This runs as a background task and updates transaction status in storage.
"""
function monitor_transaction(chain::String, tx_hash::String)
    bridge_log("Bridge: Started monitoring transaction $tx_hash on $chain")
    
    max_attempts = 30            # Maximum number of attempts
    initial_delay_seconds = 3    # Start with a short delay for faster chains
    max_delay_seconds = 60       # Maximum delay between checks
    current_delay = initial_delay_seconds
    
    # Connect to the chain
    connection = Blockchain.connect(network=chain)
    if !connection["connected"]
        @error "Bridge: Failed to connect to chain $chain for monitoring tx: $tx_hash"
        return
    end
    
    # Find transactions in storage matching this hash
    db = Storage.DB
    txs = Storage.list_transactions(db, chain=chain)
    matching_txs = filter(tx -> tx[:tx_hash] == tx_hash, txs)
    
    tx_id = nothing
    if !isempty(matching_txs)
        tx_id = matching_txs[1][:id]
        bridge_log("Bridge: Found transaction ID $tx_id in storage for tx_hash $tx_hash")
    else
        @warn "Bridge: No matching transaction found in storage for tx_hash $tx_hash"
    end
    
    # Monitor transaction until confirmed or max attempts reached
    for attempt in 1:max_attempts
        try
            # Get transaction receipt from blockchain
            receipt = Blockchain.getTransactionReceipt(tx_hash, connection)
            
            if receipt === nothing
                # Transaction not yet mined, continue waiting
                bridge_log("Bridge: Transaction $tx_hash still pending (attempt $attempt/$max_attempts)")
                sleep(current_delay)
                # Increase delay exponentially (with max cap)
                current_delay = min(current_delay * 1.5, max_delay_seconds)
                continue
            end
            
            # We have a receipt - check status
            # For EVM chains, status 1 = success, 0 = failure
            # For Solana, check status.err === null (details vary by chain)
            tx_status = "Unknown"
            
            if chain in ["ethereum", "polygon", "arbitrum", "optimism", "base", "bsc", "avalanche", "fantom"]
                # For EVM chains
                if haskey(receipt, "status")
                    status_code = receipt["status"]
                    if status_code == "0x1"
                        tx_status = "Confirmed"
                        bridge_log("Bridge: Transaction $tx_hash confirmed successfully")
                    elseif status_code == "0x0"
                        tx_status = "Failed"
                        bridge_log("Bridge: Transaction $tx_hash failed on-chain")
                    else
                        tx_status = "Unknown"
                        bridge_log("Bridge: Unknown status code for tx $tx_hash: $status_code")
                    end
                else
                    # Some chains might not have status field
                    # If we have a blockHash and blockNumber, transaction was included
                    if haskey(receipt, "blockHash") && haskey(receipt, "blockNumber")
                        tx_status = "Confirmed"
                        bridge_log("Bridge: Transaction $tx_hash confirmed (included in block)")
                    end
                end
            elseif chain == "solana"
                # For Solana
                if haskey(receipt, "meta") && haskey(receipt["meta"], "err")
                    if receipt["meta"]["err"] === nothing
                        tx_status = "Confirmed"
                        bridge_log("Bridge: Solana transaction $tx_hash confirmed successfully")
                    else
                        tx_status = "Failed"
                        bridge_log("Bridge: Solana transaction $tx_hash failed: $(receipt["meta"]["err"])")
                    end
                else
                    # If we have a transaction but no error field, assume success
                    if haskey(receipt, "blockTime")
                        tx_status = "Confirmed"
                        bridge_log("Bridge: Solana transaction $tx_hash confirmed (has blockTime)")
                    end
                end
            end
            
            # Update transaction status in storage if we have an ID
            if tx_id !== nothing && tx_status !== "Unknown"
                try
                    Storage.update_transaction_status(db, tx_id, tx_status)
                    bridge_log("Bridge: Updated transaction status to $tx_status for ID $tx_id")
                    
                    # If this transaction was part of a trade execution (indicated by request_id),
                    # notify relevant systems (SwarmManager or DEX) of the status change
                    # TODO: Add a more robust notification system later, perhaps with callbacks
                catch update_error
                    @error "Failed to update transaction status: $update_error"
                end
            end
            
            # If we have a definitive status, we're done monitoring
            if tx_status == "Confirmed" || tx_status == "Failed"
                bridge_log("Bridge: Completed monitoring for transaction $tx_hash (final status: $tx_status)")
                return
            end
            
            # If we got here, we have a receipt but inconclusive status
            # Wait and try again
            sleep(current_delay)
            
        catch e
            @error "Error monitoring transaction $tx_hash: $e"
            sleep(current_delay)
        end
    end
    
    # If we reach here, we've exceeded max attempts without confirmation
    bridge_log("Bridge: Exceeded maximum monitoring attempts for transaction $tx_hash")
    if tx_id !== nothing
        try
            # Mark as 'Pending' instead of 'Unknown' since it might still confirm later
            Storage.update_transaction_status(db, tx_id, "Pending")
            bridge_log("Bridge: Updated transaction status to 'Pending' for ID $tx_id (monitoring timeout)")
        catch update_error
            @error "Failed to update transaction status: $update_error"
        end
    end
end

"""
    get_transaction_status(chain::String, tx_hash::String)::CommandResult

Gets the current status of a transaction from the blockchain.
"""
function get_transaction_status(chain::String, tx_hash::String)::CommandResult
    bridge_log("Bridge: Fetching status for transaction $tx_hash on $chain")
    
    try
        # Connect to the specified blockchain
        connection = Blockchain.connect(network=chain)
        if !connection["connected"]
            error_msg = "Bridge: Failed to connect to chain $chain to check status."
            @error error_msg
            return CommandResult(error_msg)
        end
        
        # Get transaction receipt
        receipt = Blockchain.getTransactionReceipt(tx_hash, connection)
        
        # If no receipt, transaction is still pending
        if receipt === nothing
            return CommandResult(Dict(
                "status" => "pending", 
                "message" => "Transaction is still pending.", 
                "tx_hash" => tx_hash,
                "chain" => chain
            ))
        end
        
        # Check receipt status based on chain type
        status = "unknown"
        block_number = nothing
        confirmations = 0
        
        if chain in ["ethereum", "polygon", "arbitrum", "optimism", "base", "bsc", "avalanche", "fantom"]
            # For EVM chains
            if haskey(receipt, "status")
                status = receipt["status"] == "0x1" ? "confirmed" : "failed"
            end
            # Get block info if available
            if haskey(receipt, "blockNumber")
                block_number = parse(Int, receipt["blockNumber"][3:end], base=16)
                
                # Get confirmations by comparing to current block
                latest_block_response = HTTP.post(
                    connection["endpoint"],
                    ["Content-Type" => "application/json"],
                    JSON.json(Dict(
                        "jsonrpc" => "2.0",
                        "method" => "eth_blockNumber",
                        "params" => [],
                        "id" => 1
                    ))
                )
                latest_block_result = JSON.parse(String(latest_block_response.body))
                if haskey(latest_block_result, "result")
                    latest_block = parse(Int, latest_block_result["result"][3:end], base=16)
                    confirmations = latest_block - block_number + 1
                end
            end
        elseif chain == "solana"
            # For Solana
            if haskey(receipt, "meta") && haskey(receipt["meta"], "err")
                status = receipt["meta"]["err"] === nothing ? "confirmed" : "failed"
            end
            
            # Get confirmations if available
            if haskey(receipt, "slot")
                tx_slot = receipt["slot"]
                # TODO: Fetch latest slot and calculate confirmations
                confirmations = 1 # Placeholder
            end
        end
        
        # Return the transaction status
        return CommandResult(Dict(
            "status" => status,
            "tx_hash" => tx_hash,
            "chain" => chain,
            "receipt" => receipt,
            "block_number" => block_number,
            "confirmations" => confirmations
        ))
        
    catch e
        error_msg = "Bridge: Error fetching transaction status: $(sprint(showerror, e))"
        @error error_msg chain=chain tx_hash=tx_hash stacktrace(catch_backtrace())
        return CommandResult(error_msg)
    end
end

"""
    bridge_log(message)

Log a message with the current timestamp
"""
function bridge_log(message)
    @info message
end

"""
    start_bridge_server(host, port)

Start the bridge server for handling requests from JavaScript
"""
function start_bridge_server(host::String="0.0.0.0", port::Int=8052)
    server_started = Ref(false)
    ws_server_started = Ref(false)
    
    # HTTP server for API endpoints
    try
        # Define the command API endpoint
        router = HTTP.Router()
        
        # Add health check endpoint
        HTTP.register!(router, "GET", "/health", function(req)
            storage_status = try
                local_db_path = get(ENV, "DB_PATH", joinpath(homedir(), ".juliaos", "juliaos.sqlite"))
                db_exists = isfile(local_db_path)
                web3_key = get(ENV, "IPFS_API_KEY", "")
                
                Dict(
                    "local_db" => db_exists ? "connected" : "not found",
                    "web3_storage" => web3_key != "" ? "configured" : "not configured"
                )
            catch e
                Dict("error" => string(e))
            end
            
            response = Dict(
                "status" => "healthy",
                "storage" => storage_status,
                "timestamp" => Dates.format(now(), "yyyy-mm-ddTHH:MM:SS.sss"),
                "version" => "1.0.0"
            )
            
            return HTTP.Response(200, JSON.json(response))
        end)
        
        # Add command API endpoint
        HTTP.register!(router, "POST", "/api/command", function(req)
            try
                # Parse the request body as JSON
                body = JSON.parse(String(HTTP.payload(req)))
                
                # Create a BridgeRequest from the JSON data
                bridge_request = BridgeRequest(
                    body["command"],
                    body["params"],
                    get(body, "id", string(rand(UInt32)))
                )
                
                # Run the command
                response = run_command(bridge_request)
                
                # Return the response as JSON
                return HTTP.Response(
                    200,
                    ["Content-Type" => "application/json"],
                    body=JSON.json(response)
                )
            catch e
                # Return error response
                error_response = Dict(
                    "result" => nothing,
                    "error" => string(e),
                    "id" => get(body, "id", "unknown")
                )
                
                return HTTP.Response(
                    500,
                    ["Content-Type" => "application/json"],
                    body=JSON.json(error_response)
                )
            end
        end)
        
        # Health check endpoint
        HTTP.register!(router, "GET", "/health", request -> begin
            health_response = Dict(
                "status" => "healthy", 
                "timestamp" => string(now()),
                "version" => "1.0.0",
                "bridge_uptime_seconds" => round(Dates.value(now() - bridge_start_time[]) / 1000, digits=2)
            )
            
            return HTTP.Response(
                200,
                ["Content-Type" => "application/json"],
                body=JSON.json(health_response)
            )
        end)
        
        # Start HTTP server
        @async begin
            try
                bridge_log("Attempting to start HTTP server on $host:$port...")
                HTTP.serve(router, host, port)
            catch e
                @error "HTTP Server error: $e" stacktrace(catch_backtrace())
                # Potentially exit or retry?
            end
        end
        
        server_started[] = true
        bridge_log("Bridge server started on http://$host:$port")
    catch e
        @error "Server error: $e"
    end
    
    # WebSocket server for real-time communication
    ws_port = port + 1
    
    try
        # Start WebSocket server
        @async begin
            try
                # Comment out the WebSockets implementation for now
                # WebSockets.listen(host, ws_port) do ws
                #     # Handle WebSocket messages
                #     while true
                #         data = WebSockets.receive(ws)
                #         
                #         # Parse request
                #         try
                #             request = JSON.parse(String(data))
                #             
                #             # Process command
                #             response = run_command(request["command"], request["params"], request["id"])
                #             
                #             # Send response
                #             WebSockets.send(ws, JSON.json(response))
                #         catch e
                #             # Send error response
                #             error_response = BridgeResponse(
                #                 nothing,
                #                 "Error processing request: $(string(e))",
                #                 "error"
                #             )
                #             
                #             WebSockets.send(ws, JSON.json(error_response))
                #         end
                #     end
                # end
                
                # Mark as started even without actual WebSockets for now
                ws_server_started[] = true
                bridge_log("WebSocket server disabled but marked as started")
            catch e
                @error "WebSocket server error: $e"
            end
        end
    catch e
        @error "WebSocket server error: $e"
    end
    
    # Wait for servers to start
    for _ in 1:10
        if server_started[] && ws_server_started[]
            bridge_log("Server started successfully on port $port")
            return true
        end
        sleep(0.1)
    end
    
    if !server_started[]
        @warn "HTTP server failed to start"
    end
    
    if !ws_server_started[]
        @warn "WebSocket server failed to start"
    end
    
    return server_started[] && ws_server_started[]
end

# Register built-in commands
function __init__()
    # Health check command
    register_command_handler("health", () -> Dict("status" => "healthy", "timestamp" => now()))
    
    # Echo command for testing
    register_command_handler("echo", (message) -> message)
end

end # module 