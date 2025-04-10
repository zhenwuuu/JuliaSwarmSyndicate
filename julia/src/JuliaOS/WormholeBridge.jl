module WormholeBridge

using Logging
using JSON
using Dates
using ..Bridge

export get_available_chains, get_available_tokens, bridge_tokens_wormhole, 
       check_bridge_status_wormhole, redeem_tokens_wormhole, get_wrapped_asset_info_wormhole

"""
    get_available_chains()

Get the list of available chains for the Wormhole bridge.
"""
function get_available_chains()
    try
        # Call the TypeScript bridge to get available chains
        result = Bridge.send_command("WormholeBridge", "getAvailableChains", Dict())
        
        if !result["success"]
            @error "Failed to get available chains: $(result["error"])"
            return Dict(
                "success" => false,
                "error" => "Failed to get available chains: $(result["error"])"
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
        # Call the TypeScript bridge to get available tokens
        result = Bridge.send_command("WormholeBridge", "getAvailableTokens", Dict(
            "chain" => chain
        ))
        
        if !result["success"]
            @error "Failed to get available tokens: $(result["error"])"
            return Dict(
                "success" => false,
                "error" => "Failed to get available tokens: $(result["error"])"
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
        
        # Call the TypeScript bridge to bridge tokens
        result = Bridge.send_command("WormholeBridge", "bridgeTokens", Dict(
            "sourceChain" => params["sourceChain"],
            "targetChain" => params["targetChain"],
            "token" => params["token"],
            "amount" => params["amount"],
            "recipient" => params["recipient"],
            "wallet" => params["wallet"],
            "relayerFee" => get(params, "relayerFee", "0")
        ))
        
        if !result["success"]
            @error "Failed to bridge tokens: $(result["error"])"
            return Dict(
                "success" => false,
                "error" => "Failed to bridge tokens: $(result["error"])"
            )
        end
        
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
        
        # Call the TypeScript bridge to check bridge status
        result = Bridge.send_command("WormholeBridge", "checkTransactionStatus", Dict(
            "sourceChain" => params["sourceChain"],
            "transactionHash" => params["transactionHash"]
        ))
        
        if !result["success"]
            @error "Failed to check bridge status: $(result["error"])"
            return Dict(
                "success" => false,
                "error" => "Failed to check bridge status: $(result["error"])"
            )
        end
        
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
        
        # Call the TypeScript bridge to redeem tokens
        result = Bridge.send_command("WormholeBridge", "redeemTokens", Dict(
            "attestation" => params["attestation"],
            "targetChain" => params["targetChain"],
            "wallet" => params["wallet"]
        ))
        
        if !result["success"]
            @error "Failed to redeem tokens: $(result["error"])"
            return Dict(
                "success" => false,
                "error" => "Failed to redeem tokens: $(result["error"])"
            )
        end
        
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
        
        # Call the TypeScript bridge to get wrapped asset info
        result = Bridge.send_command("WormholeBridge", "getWrappedAssetInfo", Dict(
            "originalChain" => params["originalChain"],
            "originalAsset" => params["originalAsset"],
            "targetChain" => params["targetChain"]
        ))
        
        if !result["success"]
            @error "Failed to get wrapped asset info: $(result["error"])"
            return Dict(
                "success" => false,
                "error" => "Failed to get wrapped asset info: $(result["error"])"
            )
        end
        
        return Dict(
            "success" => true,
            "address" => result["data"]["address"],
            "chainId" => result["data"]["chainId"],
            "decimals" => result["data"]["decimals"],
            "symbol" => result["data"]["symbol"],
            "name" => result["data"]["name"],
            "isNative" => result["data"]["isNative"]
        )
    catch e
        @error "Error getting wrapped asset info" exception=(e, catch_backtrace())
        return Dict(
            "success" => false,
            "error" => "Error getting wrapped asset info: $(e)"
        )
    end
end

end # module
