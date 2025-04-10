module WalletIntegration

using Logging
using JSON
using HTTP
using ..Wallet

export is_wallet_connected, connect_wallet, disconnect_wallet, get_wallet_balance, sign_message

# Configuration
const WALLET_API_URL = get(ENV, "WALLET_API_URL", "http://localhost:3002/api")

# Helper function to make API requests to the TypeScript wallet service
function call_wallet_api(endpoint::String, params::Dict)
    try
        url = "$(WALLET_API_URL)/$(endpoint)"
        headers = ["Content-Type" => "application/json"]

        response = HTTP.post(url, headers, JSON.json(params))
        result = JSON.parse(String(response.body))

        if !result["success"]
            error_msg = get(result, "error", "Unknown error")
            @error "Wallet API error: $(error_msg)"
            return Dict("success" => false, "error" => error_msg)
        end

        return Dict("success" => true, "data" => result)
    catch e
        @error "Error calling wallet API: $e" exception=(e, catch_backtrace())
        return Dict("success" => false, "error" => "Error calling wallet API: $e")
    end
end

"""
    is_wallet_connected(address::String, chain::String)

Check if a wallet is connected.

Parameters:
- address: The wallet address
- chain: The blockchain network
"""
function is_wallet_connected(address::String, chain::String)
    try
        # Call the TypeScript wallet service to check if wallet is connected
        result = call_wallet_api("isWalletConnected", Dict(
            "address" => address,
            "chain" => chain
        ))

        if !result["success"]
            return false
        end

        return result["data"]["isConnected"]
    catch e
        @error "Error checking wallet connection" exception=(e, catch_backtrace())
        return false
    end
end

"""
    connect_wallet(address::String, chain::String; privateKey::Union{String, Nothing}=nothing)

Connect to a wallet.

Parameters:
- address: The wallet address
- chain: The blockchain network
- privateKey: Optional private key for non-interactive wallet connection
"""
function connect_wallet(address::String, chain::String; privateKey::Union{String, Nothing}=nothing)
    try
        # Call the TypeScript wallet service to connect wallet
        params = Dict(
            "address" => address,
            "chain" => chain
        )

        if privateKey !== nothing
            params["privateKey"] = privateKey
        end

        result = call_wallet_api("connectWallet", params)

        if !result["success"]
            return Dict(
                "success" => false,
                "error" => get(result, "error", "Unknown error")
            )
        end

        return Dict(
            "success" => true
        )
    catch e
        @error "Error connecting wallet" exception=(e, catch_backtrace())
        return Dict(
            "success" => false,
            "error" => "Error connecting wallet: $(e)"
        )
    end
end

"""
    disconnect_wallet(address::String, chain::String)

Disconnect a wallet.

Parameters:
- address: The wallet address
- chain: The blockchain network
"""
function disconnect_wallet(address::String, chain::String)
    try
        # Call the TypeScript wallet service to disconnect wallet
        result = call_wallet_api("disconnectWallet", Dict(
            "address" => address,
            "chain" => chain
        ))

        if !result["success"]
            return Dict(
                "success" => false,
                "error" => get(result, "error", "Unknown error")
            )
        end

        return Dict(
            "success" => true
        )
    catch e
        @error "Error disconnecting wallet" exception=(e, catch_backtrace())
        return Dict(
            "success" => false,
            "error" => "Error disconnecting wallet: $(e)"
        )
    end
end

"""
    get_wallet_balance(address::String, chain::String)

Get wallet balance.

Parameters:
- address: The wallet address
- chain: The blockchain network
"""
function get_wallet_balance(address::String, chain::String)
    try
        # Call the TypeScript wallet service to get wallet balance
        result = call_wallet_api("getWalletBalance", Dict(
            "address" => address,
            "chain" => chain
        ))

        if !result["success"]
            return Dict(
                "success" => false,
                "error" => get(result, "error", "Unknown error")
            )
        end

        return Dict(
            "success" => true,
            "balance" => result["data"]["balance"]
        )
    catch e
        @error "Error getting wallet balance" exception=(e, catch_backtrace())
        return Dict(
            "success" => false,
            "error" => "Error getting wallet balance: $(e)"
        )
    end
end

"""
    sign_message(address::String, chain::String, message::String)

Sign a message.

Parameters:
- address: The wallet address
- chain: The blockchain network
- message: The message to sign
"""
function sign_message(address::String, chain::String, message::String)
    try
        # Call the TypeScript wallet service to sign message
        result = call_wallet_api("signMessage", Dict(
            "address" => address,
            "chain" => chain,
            "message" => message
        ))

        if !result["success"]
            return Dict(
                "success" => false,
                "error" => get(result, "error", "Unknown error")
            )
        end

        return Dict(
            "success" => true,
            "signature" => result["data"]["signature"]
        )
    catch e
        @error "Error signing message" exception=(e, catch_backtrace())
        return Dict(
            "success" => false,
            "error" => "Error signing message: $(e)"
        )
    end
end

end # module
