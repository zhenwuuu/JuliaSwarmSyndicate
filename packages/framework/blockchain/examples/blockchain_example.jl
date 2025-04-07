#!/usr/bin/env julia

# Add the Blockchain package to the environment if it's not already there
import Pkg
if !haskey(Pkg.project().dependencies, "Blockchain")
    Pkg.develop(path="../")
end

using Blockchain
using Dates

println("JuliaOS Blockchain Example - Network Interaction")
println("-----------------------------------------------")

# Define colors for prettier output
const GREEN = "\e[32m"
const RED = "\e[31m"
const YELLOW = "\e[33m"
const RESET = "\e[0m"
const BLUE = "\e[34m"
const CYAN = "\e[36m"

function printSection(title)
    println("\n$(BLUE)$title$(RESET)")
    println(repeat("-", length(title)))
end

# 1. Explore available networks
printSection("1. Available Blockchain Networks")

networks = [
    ETHEREUM_MAINNET,
    ETHEREUM_SEPOLIA,
    POLYGON_MAINNET,
    ARBITRUM_ONE,
    OPTIMISM,
    BASE,
    SOLANA_MAINNET
]

println("Available blockchain networks:")
for network in networks
    chain_id = isnothing(network.chainId) ? "N/A" : network.chainId
    println("  • $(CYAN)$(network.name)$(RESET)")
    println("    Chain ID: $(chain_id)")
    println("    Native Currency: $(network.nativeCurrency)")
    println("    Block Explorer: $(network.explorer)")
    println()
end

# 2. Query network by name and ID
printSection("2. Finding Networks by Name or Chain ID")

# Get network by name
println("Finding Ethereum network by name...")
ethereum = getNetwork("ethereum")
println("$(GREEN)✓$(RESET) Found: $(ethereum.name) (Chain ID: $(ethereum.chainId))")

# Get network by chain ID
println("\nFinding Polygon network by chain ID...")
polygon = getNetwork(137)
println("$(GREEN)✓$(RESET) Found: $(polygon.name) (Native currency: $(polygon.nativeCurrency))")

# 3. Check account balances
printSection("3. Checking Account Balances")

# This is a demonstration address (do not send real funds to it)
address = "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"

# Check native balance on Ethereum
eth_balance = getBalance(address, ethereum)
println("Balance on $(ethereum.name): $(eth_balance) $(ethereum.nativeCurrency)")

# Check token balances on Ethereum
usdc_balance = getBalance(address, ethereum, "USDC")
usdt_balance = getBalance(address, ethereum, "USDT")
println("USDC Balance: $usdc_balance")
println("USDT Balance: $usdt_balance")

# Check balance on Polygon
matic_balance = getBalance(address, polygon)
println("\nBalance on $(polygon.name): $(matic_balance) $(polygon.nativeCurrency)")

# 4. Transaction information
printSection("4. Transaction Information")

# Example transaction hash (this is a real transaction on Ethereum)
tx_hash = "0x2c6a212e34cb9f3f5b7ba2cd29222c0e58b3664cb49a55e7e2b2eb1139607f21"
println("Fetching information for transaction $(CYAN)$tx_hash$(RESET)...")

# Get transaction details
tx = getTransaction(tx_hash, ethereum)
println("$(GREEN)✓$(RESET) Transaction details:")
println("  From: $(tx.from)")
println("  To: $(tx.to)")
println("  Value: $(tx.value) ETH")
println("  Gas Price: $(tx.gasPrice) Gwei")
println("  Gas Limit: $(tx.gasLimit)")
println("  Status: $(tx.status)")
println("  Timestamp: $(tx.timestamp)")

# 5. Block information
printSection("5. Block Information")

# Get a specific block
block_number = 17000000  # Example Ethereum block
println("Fetching information for block $(CYAN)#$block_number$(RESET) on Ethereum...")

# Get block details
block = getBlock(block_number, ethereum)
println("$(GREEN)✓$(RESET) Block details:")
println("  Hash: $(block.hash)")
println("  Timestamp: $(block.timestamp)")
println("  Miner: $(block.miner)")
println("  Gas Used: $(block.gasUsed)")
println("  Gas Limit: $(block.gasLimit)")
println("  Transaction Count: $(length(block.transactions))")

# 6. Smart contract interaction
printSection("6. Smart Contract Interaction")

# Define a simple ERC-20 ABI (abbreviated for the example)
erc20_abi = [
    Dict(
        "name" => "balanceOf",
        "type" => "function",
        "inputs" => [Dict("name" => "owner", "type" => "address")],
        "outputs" => [Dict("name" => "balance", "type" => "uint256")],
        "stateMutability" => "view"
    ),
    Dict(
        "name" => "name",
        "type" => "function",
        "inputs" => [],
        "outputs" => [Dict("name" => "", "type" => "string")],
        "stateMutability" => "view"
    ),
    Dict(
        "name" => "symbol",
        "type" => "function",
        "inputs" => [],
        "outputs" => [Dict("name" => "", "type" => "string")],
        "stateMutability" => "view"
    ),
    Dict(
        "name" => "decimals",
        "type" => "function",
        "inputs" => [],
        "outputs" => [Dict("name" => "", "type" => "uint8")],
        "stateMutability" => "view"
    )
]

# USDC contract on Ethereum
usdc_address = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
println("Creating contract instance for USDC ($(CYAN)$usdc_address$(RESET)) on Ethereum...")

# Create contract instance
usdc_contract = SmartContract(
    usdc_address,
    ethereum,
    erc20_abi,
    ""  # No bytecode needed for existing contracts
)

# Call contract methods
println("\nCalling contract methods:")
token_name = callContract(usdc_contract, "name", [])
token_symbol = callContract(usdc_contract, "symbol", [])
token_decimals = callContract(usdc_contract, "decimals", [])
balance = callContract(usdc_contract, "balanceOf", [address])

println("$(GREEN)✓$(RESET) Token information:")
println("  Name: $token_name")
println("  Symbol: $token_symbol")
println("  Decimals: $token_decimals")
println("  Balance of $address: $balance")

# 7. Gas estimation
printSection("7. Gas Estimation")

# Estimate gas for a simple transfer
from_address = "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
to_address = "0x8F90595A593919Cf19aAECf6f71E174fa4713cCE"
println("Estimating gas for a simple ETH transfer...")

# Simple transfer (empty data)
transfer_gas = estimateGas(from_address, to_address, "0x", ethereum)
println("$(GREEN)✓$(RESET) Gas for simple transfer: $transfer_gas")

# ERC-20 transfer (with data)
# This is the encoded data for a transfer function call
token_transfer_data = "0xa9059cbb000000000000000000000000742d35cc6634c0532925a3b844bc454e4438f44e0000000000000000000000000000000000000000000000000000000000000064"
println("\nEstimating gas for an ERC-20 token transfer...")

token_transfer_gas = estimateGas(from_address, usdc_address, token_transfer_data, ethereum)
println("$(GREEN)✓$(RESET) Gas for token transfer: $token_transfer_gas")

# Compare gas prices across networks
printSection("8. Network Gas Price Comparison")

println("Current gas prices across networks:")
for network in [ETHEREUM_MAINNET, POLYGON_MAINNET, ARBITRUM_ONE, OPTIMISM, BASE]
    # In a real implementation, this would make an RPC call
    # Using simulated values for demonstration
    gas_price = network.name == "Ethereum Mainnet" ? 20.0 : 
                network.name == "Polygon Mainnet" ? 50.0 :
                network.name == "Arbitrum One" ? 0.1 :
                network.name == "Optimism" ? 0.01 :
                0.005  # Base
                
    println("  $(CYAN)$(network.name)$(RESET): $(gas_price) Gwei")
end

println("\n$(GREEN)JuliaOS Blockchain Example Completed$(RESET)")
println("-----------------------------------------------") 