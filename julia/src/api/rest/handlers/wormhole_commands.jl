"""
    Wormhole command handlers for JuliaOS

This file contains the implementation of Wormhole-related command handlers.
"""

using ..JuliaOS
using Dates
using Random
using JSON

export handle_wormhole_command

"""
    handle_wormhole_command(command::String, params::Dict)

Handle commands related to the Wormhole bridge.
"""
function handle_wormhole_command(command::String, params::Dict)
    if command == "WormholeBridge.get_available_chains"
        # Get available chains for Wormhole
        try
            # Check if WormholeBridge module is available
            if isdefined(JuliaOS, :WormholeBridge) && isdefined(JuliaOS.WormholeBridge, :get_available_chains)
                @info "Using JuliaOS.WormholeBridge.get_available_chains"
                result = JuliaOS.WormholeBridge.get_available_chains()

                if result["success"]
                    # Format the chains to match the expected format
                    formatted_chains = []
                    for chain in result["chains"]
                        push!(formatted_chains, Dict(
                            "id" => chain["id"],
                            "name" => chain["name"],
                            "symbol" => uppercase(chain["id"]),
                            "wormhole_id" => chain["chainId"]
                        ))
                    end

                    return Dict("success" => true, "data" => Dict("chains" => formatted_chains))
                else
                    return Dict("success" => false, "error" => get(result, "error", "Unknown error getting available chains"))
                end
            else
                @warn "JuliaOS.WormholeBridge module not available or get_available_chains not defined"
                return Dict("success" => false, "error" => "Wormhole Bridge is not available. The WormholeBridge module is not loaded or the get_available_chains function is not defined.")
            end
        catch e
            @error "Error getting available chains" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error getting available chains: $(string(e))")
        end
    elseif command == "WormholeBridge.get_available_tokens"
        # Get available tokens for a chain
        chain_id = get(params, "chain_id", nothing)
        chain = get(params, "chain", nothing)

        # If chain_id is provided but chain is not, convert chain_id to chain name
        if !isnothing(chain_id) && isnothing(chain)
            # Map chain_id to chain name
            chain_map = Dict(
                1 => "ethereum",
                56 => "bsc",
                137 => "polygon",
                43114 => "avalanche",
                42161 => "arbitrum",
                10 => "optimism",
                8453 => "base",
                1 => "solana"
            )

            chain = get(chain_map, chain_id, nothing)
        end

        if isnothing(chain)
            return Dict("success" => false, "error" => "Missing chain parameter for get_available_tokens")
        end

        try
            # Check if WormholeBridge module is available
            if isdefined(JuliaOS, :WormholeBridge) && isdefined(JuliaOS.WormholeBridge, :get_available_tokens)
                @info "Using JuliaOS.WormholeBridge.get_available_tokens"
                result = JuliaOS.WormholeBridge.get_available_tokens(chain)

                if result["success"]
                    # Format the tokens to match the expected format
                    formatted_tokens = []
                    for token in result["tokens"]
                        push!(formatted_tokens, Dict(
                            "symbol" => token["symbol"],
                            "name" => token["name"],
                            "address" => token["address"],
                            "decimals" => token["decimals"]
                        ))
                    end

                    return Dict("success" => true, "data" => Dict("tokens" => formatted_tokens, "chain_id" => chain_id, "chain" => chain))
                else
                    return Dict("success" => false, "error" => get(result, "error", "Unknown error getting available tokens"))
                end
            else
                @warn "JuliaOS.WormholeBridge module not available or get_available_tokens not defined"
                return Dict("success" => false, "error" => "Wormhole Bridge is not available. The WormholeBridge module is not loaded or the get_available_tokens function is not defined.")
            end
        catch e
            @error "Error getting available tokens" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error getting available tokens: $(string(e))")
        end
    elseif command == "WormholeBridge.bridge_tokens"
        # Bridge tokens using Wormhole
        source_chain_id = get(params, "source_chain_id", nothing)
        target_chain_id = get(params, "target_chain_id", nothing)
        source_chain = get(params, "sourceChain", nothing)
        target_chain = get(params, "targetChain", nothing)
        token_address = get(params, "token_address", nothing)
        token = get(params, "token", nothing)
        amount = get(params, "amount", nothing)
        wallet_address = get(params, "wallet_address", nothing)
        recipient = get(params, "recipient", nothing)
        wallet = get(params, "wallet", nothing)

        # Map chain_id to chain name if needed
        if !isnothing(source_chain_id) && isnothing(source_chain)
            chain_map = Dict(
                1 => "ethereum",
                56 => "bsc",
                137 => "polygon",
                43114 => "avalanche",
                42161 => "arbitrum",
                10 => "optimism",
                8453 => "base",
                1 => "solana"
            )

            source_chain = get(chain_map, source_chain_id, nothing)
        end

        if !isnothing(target_chain_id) && isnothing(target_chain)
            chain_map = Dict(
                1 => "ethereum",
                56 => "bsc",
                137 => "polygon",
                43114 => "avalanche",
                42161 => "arbitrum",
                10 => "optimism",
                8453 => "base",
                1 => "solana"
            )

            target_chain = get(chain_map, target_chain_id, nothing)
        end

        # Use token_address as token if token is not provided
        if isnothing(token) && !isnothing(token_address)
            token = token_address
        end

        # Use wallet_address as wallet if wallet is not provided
        if isnothing(wallet) && !isnothing(wallet_address)
            wallet = wallet_address
        end

        # Use wallet_address as recipient if recipient is not provided
        if isnothing(recipient) && !isnothing(wallet_address)
            recipient = wallet_address
        end

        # Check required parameters
        if (isnothing(source_chain) && isnothing(source_chain_id)) ||
           (isnothing(target_chain) && isnothing(target_chain_id)) ||
           (isnothing(token) && isnothing(token_address)) ||
           isnothing(amount) ||
           (isnothing(wallet) && isnothing(wallet_address)) ||
           isnothing(recipient)
            return Dict("success" => false, "error" => "Missing required parameters for bridge_tokens")
        end

        try
            # Check if WormholeBridge module is available
            if isdefined(JuliaOS, :WormholeBridge) && isdefined(JuliaOS.WormholeBridge, :bridge_tokens_wormhole)
                @info "Using JuliaOS.WormholeBridge.bridge_tokens_wormhole"

                # Prepare parameters for bridge_tokens_wormhole
                bridge_params = Dict(
                    "sourceChain" => source_chain,
                    "targetChain" => target_chain,
                    "token" => token,
                    "amount" => amount,
                    "recipient" => recipient,
                    "wallet" => wallet
                )

                result = JuliaOS.WormholeBridge.bridge_tokens_wormhole(bridge_params)

                if result["success"]
                    # Format the result to match the expected format
                    formatted_result = Dict(
                        "source_chain_id" => source_chain_id,
                        "target_chain_id" => target_chain_id,
                        "source_chain" => source_chain,
                        "target_chain" => target_chain,
                        "token_address" => token,
                        "amount" => amount,
                        "wallet_address" => wallet,
                        "recipient" => recipient,
                        "transaction_hash" => result["transactionHash"],
                        "status" => result["status"],
                        "attestation" => get(result, "attestation", nothing),
                        "timestamp" => get(result, "timestamp", string(now()))
                    )

                    return Dict("success" => true, "data" => formatted_result)
                else
                    return Dict("success" => false, "error" => get(result, "error", "Unknown error bridging tokens"))
                end
            else
                @warn "JuliaOS.WormholeBridge module not available or bridge_tokens_wormhole not defined"
                return Dict("success" => false, "error" => "Wormhole Bridge is not available. The WormholeBridge module is not loaded or the bridge_tokens_wormhole function is not defined.")
            end
        catch e
            @error "Error bridging tokens" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error bridging tokens: $(string(e))")
        end
    elseif command == "WormholeBridge.check_bridge_status"
        # Check bridge status
        transaction_hash = get(params, "transaction_hash", nothing)
        source_chain_id = get(params, "source_chain_id", nothing)
        source_chain = get(params, "sourceChain", nothing)
        attestation = get(params, "attestation", nothing)

        # Map chain_id to chain name if needed
        if !isnothing(source_chain_id) && isnothing(source_chain)
            chain_map = Dict(
                1 => "ethereum",
                56 => "bsc",
                137 => "polygon",
                43114 => "avalanche",
                42161 => "arbitrum",
                10 => "optimism",
                8453 => "base",
                1 => "solana"
            )

            source_chain = get(chain_map, source_chain_id, nothing)
        end

        # Check required parameters
        if (isnothing(transaction_hash) && isnothing(attestation)) || (isnothing(source_chain) && isnothing(source_chain_id))
            return Dict("success" => false, "error" => "Missing required parameters for check_bridge_status")
        end

        try
            # Check if WormholeBridge module is available
            if isdefined(JuliaOS, :WormholeBridge) && isdefined(JuliaOS.WormholeBridge, :check_bridge_status)
                @info "Using JuliaOS.WormholeBridge.check_bridge_status"

                # Prepare parameters for check_bridge_status
                status_params = Dict(
                    "sourceChain" => source_chain,
                    "transactionHash" => transaction_hash
                )

                # Add attestation if available
                if !isnothing(attestation)
                    status_params["attestation"] = attestation
                end

                result = JuliaOS.WormholeBridge.check_bridge_status(status_params)

                if result["success"]
                    # Format the result to match the expected format
                    formatted_result = Dict(
                        "transaction_hash" => transaction_hash,
                        "source_chain_id" => source_chain_id,
                        "source_chain" => source_chain,
                        "status" => result["status"],
                        "confirmations" => get(result, "confirmations", 0),
                        "timestamp" => get(result, "timestamp", string(now()))
                    )

                    return Dict("success" => true, "data" => formatted_result)
                else
                    return Dict("success" => false, "error" => get(result, "error", "Unknown error checking bridge status"))
                end
            else
                @warn "JuliaOS.WormholeBridge module not available or check_bridge_status not defined"
                return Dict("success" => false, "error" => "Wormhole Bridge is not available. The WormholeBridge module is not loaded or the check_bridge_status function is not defined.")
            end
        catch e
            @error "Error checking bridge status" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error checking bridge status: $(string(e))")
        end
    elseif command == "WormholeBridge.redeem_tokens"
        # Redeem tokens
        transaction_hash = get(params, "transaction_hash", nothing)
        target_chain_id = get(params, "target_chain_id", nothing)
        target_chain = get(params, "targetChain", nothing)
        wallet_address = get(params, "wallet_address", nothing)
        wallet = get(params, "wallet", nothing)
        attestation = get(params, "attestation", nothing)

        # Map chain_id to chain name if needed
        if !isnothing(target_chain_id) && isnothing(target_chain)
            chain_map = Dict(
                1 => "ethereum",
                56 => "bsc",
                137 => "polygon",
                43114 => "avalanche",
                42161 => "arbitrum",
                10 => "optimism",
                8453 => "base",
                1 => "solana"
            )

            target_chain = get(chain_map, target_chain_id, nothing)
        end

        # Use wallet_address as wallet if wallet is not provided
        if isnothing(wallet) && !isnothing(wallet_address)
            wallet = wallet_address
        end

        # Check required parameters
        if (isnothing(transaction_hash) && isnothing(attestation)) ||
           (isnothing(target_chain) && isnothing(target_chain_id)) ||
           (isnothing(wallet) && isnothing(wallet_address))
            return Dict("success" => false, "error" => "Missing required parameters for redeem_tokens")
        end

        try
            # Check if WormholeBridge module is available
            if isdefined(JuliaOS, :WormholeBridge) && isdefined(JuliaOS.WormholeBridge, :redeem_tokens_wormhole)
                @info "Using JuliaOS.WormholeBridge.redeem_tokens_wormhole"

                # Prepare parameters for redeem_tokens_wormhole
                redeem_params = Dict(
                    "targetChain" => target_chain,
                    "wallet" => wallet
                )

                # Add transaction_hash or attestation
                if !isnothing(transaction_hash)
                    redeem_params["transactionHash"] = transaction_hash
                elseif !isnothing(attestation)
                    redeem_params["attestation"] = attestation
                end

                result = JuliaOS.WormholeBridge.redeem_tokens_wormhole(redeem_params)

                if result["success"]
                    # Format the result to match the expected format
                    formatted_result = Dict(
                        "transaction_hash" => transaction_hash,
                        "target_chain_id" => target_chain_id,
                        "target_chain" => target_chain,
                        "wallet_address" => wallet,
                        "redeem_transaction_hash" => result["redeemTransactionHash"],
                        "status" => result["status"],
                        "timestamp" => get(result, "timestamp", string(now()))
                    )

                    return Dict("success" => true, "data" => formatted_result)
                else
                    return Dict("success" => false, "error" => get(result, "error", "Unknown error redeeming tokens"))
                end
            else
                @warn "JuliaOS.WormholeBridge module not available or redeem_tokens_wormhole not defined"
                return Dict("success" => false, "error" => "Wormhole Bridge is not available. The WormholeBridge module is not loaded or the redeem_tokens_wormhole function is not defined.")
            end
        catch e
            @error "Error redeeming tokens" exception=(e, catch_backtrace())
            return Dict("success" => false, "error" => "Error redeeming tokens: $(string(e))")
        end
    else
        return Dict("success" => false, "error" => "Unknown Wormhole command: $command")
    end
end
