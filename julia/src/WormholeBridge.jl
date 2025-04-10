module WormholeBridge

using Logging
using JSON
using Dates
using Random
using HTTP
using ..Bridge
using ..Wallet

export get_available_chains, get_available_tokens, bridge_tokens_wormhole,
       check_bridge_status_wormhole, redeem_tokens_wormhole, get_wrapped_asset_info_wormhole

# Configuration
const BRIDGE_API_URL = get(ENV, "WORMHOLE_BRIDGE_API_URL", "http://localhost:3001/api")

# Helper function to make API requests to the TypeScript bridge service
function call_bridge_api(endpoint::String, params::Dict)
    try
        url = "$(BRIDGE_API_URL)/$(endpoint)"
        headers = ["Content-Type" => "application/json"]

        response = HTTP.post(url, headers, JSON.json(params))
        result = JSON.parse(String(response.body))

        if !result["success"]
            @error "Bridge API error: $(result["error"])"
            return Dict("success" => false, "error" => result["error"])
        end

        return Dict("success" => true, "data" => result["data"])
    catch e
        @error "Error calling bridge API: $e" exception=(e, catch_backtrace())
        return Dict("success" => false, "error" => "Error calling bridge API: $e")
    end
end

"""
    get_available_chains()

Get the list of available chains for the Wormhole bridge.
"""
function get_available_chains()
    try
        # Call the TypeScript bridge service to get available chains
        result = call_bridge_api("getAvailableChains", Dict())

        if !result["success"]
            return Dict(
                "success" => false,
                "error" => get(result, "error", "Unknown error")
            )
        end

        return Dict(
            "success" => true,
            "chains" => result["data"]["chains"]
        )
    catch e
        @error "Error getting available chains" exception=(e, catch_backtrace())
        return Dict(
            "success" => false,
            "error" => "Error getting available chains: $(e)"
        )
    end
end

"""
    get_available_tokens(chain)

Get the list of available tokens for a specific chain.
"""
function get_available_tokens(chain)
    try
        # Call the TypeScript bridge service to get available tokens
        result = call_bridge_api("getAvailableTokens", Dict("chain" => chain))

        if !result["success"]
            return Dict(
                "success" => false,
                "error" => get(result, "error", "Unknown error")
            )
        end

        return Dict(
            "success" => true,
            "tokens" => result["data"]["tokens"]
        )
    catch e
        @error "Error getting available tokens" exception=(e, catch_backtrace())
        return Dict(
            "success" => false,
            "error" => "Error getting available tokens: $(e)"
        )
    end
end

"""
    bridge_tokens_wormhole(params)

Bridge tokens from one chain to another using the Wormhole protocol.

Parameters:
- sourceChain: The source chain
- targetChain: The target chain
- token: The token address
- amount: The amount to bridge
- recipient: The recipient address
- wallet: The wallet address
- privateKey: (Optional) The private key for signing transactions
"""
function bridge_tokens_wormhole(params)
    try
        # Validate parameters
        required_params = ["sourceChain", "targetChain", "token", "amount", "recipient", "wallet"]
        for param in required_params
            if !haskey(params, param) || isempty(params[param])
                return Dict(
                    "success" => false,
                    "error" => "Missing required parameter: $param"
                )
            end
        end

        # Validate wallet connection
        wallet_address = params["wallet"]
        source_chain = params["sourceChain"]

        # Check if wallet is connected
        if !Wallet.is_wallet_connected(wallet_address, source_chain)
            # Try to connect the wallet
            wallet_result = Wallet.connect_wallet(wallet_address, source_chain)
            if !wallet_result["success"]
                return Dict(
                    "success" => false,
                    "error" => "Failed to connect wallet: $(wallet_result["error"])"
                )
            end
        end

        # Get private key if available
        if !haskey(params, "privateKey") || isempty(params["privateKey"])
            # Try to get private key from wallet module
            private_key_result = Wallet.get_private_key(wallet_address, source_chain)
            if private_key_result["success"]
                params["privateKey"] = private_key_result["privateKey"]
            else
                @warn "No private key available for wallet: $wallet_address on chain: $source_chain"
            end
        end

        # Call the TypeScript bridge service to bridge tokens
        result = call_bridge_api("bridgeTokens", params)

        if !result["success"]
            return Dict(
                "success" => false,
                "error" => get(result, "error", "Unknown error")
            )
        end

        # Return the result
        return Dict(
            "success" => true,
            "transactionHash" => result["data"]["transactionHash"],
            "status" => result["data"]["status"],
            "attestation" => get(result["data"], "attestation", nothing)
        )
    catch e
        @error "Error bridging tokens" exception=(e, catch_backtrace())
        return Dict(
            "success" => false,
            "error" => "Error bridging tokens: $(e)"
        )
    end
end

"""
    check_bridge_status_wormhole(params)

Check the status of a bridge transaction.

Parameters:
- sourceChain: The source chain
- transactionHash: The transaction hash
"""
function check_bridge_status_wormhole(params)
    try
        # Validate parameters
        required_params = ["sourceChain", "transactionHash"]
        for param in required_params
            if !haskey(params, param) || isempty(params[param])
                return Dict(
                    "success" => false,
                    "error" => "Missing required parameter: $param"
                )
            end
        end

        # Call the TypeScript bridge service to check bridge status
        result = call_bridge_api("checkTransactionStatus", params)

        if !result["success"]
            return Dict(
                "success" => false,
                "error" => get(result, "error", "Unknown error")
            )
        end

        # Return the result
        return Dict(
            "success" => true,
            "status" => result["data"]["status"],
            "attestation" => get(result["data"], "attestation", nothing),
            "targetChain" => get(result["data"], "targetChain", nothing)
        )
    catch e
        @error "Error checking bridge status" exception=(e, catch_backtrace())
        return Dict(
            "success" => false,
            "error" => "Error checking bridge status: $(e)"
        )
    end
end

"""
    redeem_tokens_wormhole(params)

Redeem tokens on the target chain.

Parameters:
- attestation: The attestation (VAA)
- targetChain: The target chain
- wallet: The wallet address
- privateKey: (Optional) The private key for signing transactions
"""
function redeem_tokens_wormhole(params)
    try
        # Validate parameters
        required_params = ["attestation", "targetChain", "wallet"]
        for param in required_params
            if !haskey(params, param) || isempty(params[param])
                return Dict(
                    "success" => false,
                    "error" => "Missing required parameter: $param"
                )
            end
        end

        # Validate wallet connection
        wallet_address = params["wallet"]
        target_chain = params["targetChain"]

        # Check if wallet is connected
        if !Wallet.is_wallet_connected(wallet_address, target_chain)
            # Try to connect the wallet
            wallet_result = Wallet.connect_wallet(wallet_address, target_chain)
            if !wallet_result["success"]
                return Dict(
                    "success" => false,
                    "error" => "Failed to connect wallet: $(wallet_result["error"])"
                )
            end
        end

        # Get private key if available
        if !haskey(params, "privateKey") || isempty(params["privateKey"])
            # Try to get private key from wallet module
            private_key_result = Wallet.get_private_key(wallet_address, target_chain)
            if private_key_result["success"]
                params["privateKey"] = private_key_result["privateKey"]
            else
                @warn "No private key available for wallet: $wallet_address on chain: $target_chain"
            end
        end

        # Call the TypeScript bridge service to redeem tokens
        result = call_bridge_api("redeemTokens", params)

        if !result["success"]
            return Dict(
                "success" => false,
                "error" => get(result, "error", "Unknown error")
            )
        end

        # Return the result
        return Dict(
            "success" => true,
            "transactionHash" => result["data"]["transactionHash"],
            "status" => result["data"]["status"]
        )
    catch e
        @error "Error redeeming tokens" exception=(e, catch_backtrace())
        return Dict(
            "success" => false,
            "error" => "Error redeeming tokens: $(e)"
        )
    end
end

"""
    get_wrapped_asset_info_wormhole(params)

Get information about a wrapped asset.

Parameters:
- originalChain: The original chain
- originalAsset: The original asset address
- targetChain: The target chain
"""
function get_wrapped_asset_info_wormhole(params)
    try
        # Validate parameters
        required_params = ["originalChain", "originalAsset", "targetChain"]
        for param in required_params
            if !haskey(params, param) || isempty(params[param])
                return Dict(
                    "success" => false,
                    "error" => "Missing required parameter: $param"
                )
            end
        end

        # Call the TypeScript bridge service to get wrapped asset info
        result = call_bridge_api("getWrappedAssetInfo", params)

        if !result["success"]
            return Dict(
                "success" => false,
                "error" => get(result, "error", "Unknown error")
            )
        end

        # Return the result
        data = result["data"]
        return Dict(
            "success" => true,
            "address" => data["address"],
            "chainId" => data["chainId"],
            "decimals" => data["decimals"],
            "symbol" => data["symbol"],
            "name" => data["name"],
            "isNative" => data["isNative"]
        )
    catch e
        @error "Error getting wrapped asset info" exception=(e, catch_backtrace())
        return Dict(
            "success" => false,
            "error" => "Error getting wrapped asset info: $(e)"
        )
    end
end

# Register commands with the Bridge module
function register_commands()
    Bridge.register_command_handler("WormholeBridge.get_available_chains", (args...) -> get_available_chains())
    Bridge.register_command_handler("WormholeBridge.get_available_tokens", (chain) -> get_available_tokens(chain))

    # For dictionary parameters, we need to handle them differently
    Bridge.register_command_handler("WormholeBridge.bridge_tokens_wormhole", function(params_dict)
        if isa(params_dict, Dict)
            return bridge_tokens_wormhole(params_dict)
        else
            return Dict("success" => false, "error" => "Invalid parameters: expected dictionary")
        end
    end)

    Bridge.register_command_handler("WormholeBridge.check_bridge_status_wormhole", function(params_dict)
        if isa(params_dict, Dict)
            return check_bridge_status_wormhole(params_dict)
        else
            return Dict("success" => false, "error" => "Invalid parameters: expected dictionary")
        end
    end)

    Bridge.register_command_handler("WormholeBridge.redeem_tokens_wormhole", function(params_dict)
        if isa(params_dict, Dict)
            return redeem_tokens_wormhole(params_dict)
        else
            return Dict("success" => false, "error" => "Invalid parameters: expected dictionary")
        end
    end)

    Bridge.register_command_handler("WormholeBridge.get_wrapped_asset_info_wormhole", function(params_dict)
        if isa(params_dict, Dict)
            return get_wrapped_asset_info_wormhole(params_dict)
        else
            return Dict("success" => false, "error" => "Invalid parameters: expected dictionary")
        end
    end)

    @info "WormholeBridge commands registered"
end

# Register commands when the module is loaded
register_commands()

end # module
