#!/usr/bin/env julia

# Add the Wallets package to the environment if it's not already there
import Pkg
if !haskey(Pkg.project().dependencies, "Wallets")
    Pkg.develop(path="../")
end

using Wallets
using Dates

println("JuliaOS Wallets Example - Blockchain Wallet Management")
println("-----------------------------------------------------")

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

# 1. List supported chains
printSection("1. Supported Blockchain Networks")

chains = supportedChains()
println("JuliaOS supports the following blockchain networks:")

for chain in chains
    chainId = isnothing(chain.chainId) ? "N/A" : chain.chainId
    println("  • $(CYAN)$(chain.name)$(RESET) (chainId: $chainId)")
end

# 2. Connect to Ethereum wallet in read-only mode
printSection("2. Connecting to Ethereum Wallet (Read-Only)")

# This is a demonstration address (do not send real funds to it)
ethereum_address = "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"

# Validate the address
valid = validateAddress(ethereum_address, ETHEREUM)
if valid
    println("$(GREEN)✓$(RESET) Address is valid for Ethereum")
else
    println("$(RED)✗$(RESET) Invalid Ethereum address")
    exit(1)
end

# Connect to the wallet
println("\nConnecting to Ethereum wallet in read-only mode...")
eth_wallet = connectWallet(ethereum_address, ETHEREUM)
println("$(GREEN)✓$(RESET) Connected to $(eth_wallet.chain.name) wallet")
println("  Address: $(eth_wallet.address)")
println("  Read-only: $(eth_wallet.readOnly ? "Yes" : "No")")

# 3. Check wallet balances
printSection("3. Checking Wallet Balances")

balances = getWalletBalance(ethereum_address)
println("Balances for $(CYAN)$(ethereum_address)$(RESET):")

for (token, amount) in balances
    println("  • $(token): $(amount)")
end

# 4. View transaction history
printSection("4. Viewing Transaction History")

transactions = getTransactionHistory(ethereum_address)
println("Transaction history for $(CYAN)$(ethereum_address)$(RESET):")

for (i, tx) in enumerate(transactions)
    direction = tx["from"] == ethereum_address ? "OUT" : "IN"
    direction_color = direction == "OUT" ? RED : GREEN
    println("  $(i). [$(direction_color)$(direction)$(RESET)] $(tx["amount"]) $(tx["token"]) - $(tx["status"])")
    println("     From: $(tx["from"][1:10])...$(tx["from"][end-8:end])")
    println("     To: $(tx["to"][1:10])...$(tx["to"][end-8:end])")
    println("     Hash: $(tx["hash"][1:10])...$(tx["hash"][end-8:end])")
    println("     Time: $(tx["timestamp"])")
    println()
end

# 5. Connect to multiple chains
printSection("5. Connecting to Multiple Blockchain Networks")

# Connect to Polygon
polygon_address = "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
println("Connecting to Polygon wallet...")
polygon_wallet = connectWallet(polygon_address, POLYGON)
println("$(GREEN)✓$(RESET) Connected to $(polygon_wallet.chain.name) wallet")

# Check Polygon balances
polygon_balances = getWalletBalance(polygon_address)
println("\nBalances for $(CYAN)$(polygon_address)$(RESET) on Polygon:")
for (token, amount) in polygon_balances
    println("  • $(token): $(amount)")
end

# Connect to Solana (using a demo address)
solana_address = "5ZPBHzMr4zXgbANg2TKdX9zHEX1shBN3bdtX9c5vc2m5"
println("\nConnecting to Solana wallet...")
solana_wallet = connectWallet(solana_address, SOLANA)
println("$(GREEN)✓$(RESET) Connected to $(solana_wallet.chain.name) wallet")

# Check Solana balances
solana_balances = getWalletBalance(solana_address)
println("\nBalances for $(CYAN)$(solana_address)$(RESET) on Solana:")
for (token, amount) in solana_balances
    println("  • $(token): $(amount)")
end

# 6. Send Transaction (simulated, wallet is read-only)
printSection("6. Sending a Transaction (Simulated)")

recipient = "0x8F90595A593919Cf19aAECf6f71E174fa4713cCE"
amount = 0.05
println("Attempting to send $(amount) ETH to $(recipient)...")

try
    tx = sendTransaction(ethereum_address, recipient, amount)
    println("Transaction sent successfully!")
    println("  Hash: $(tx["hash"])")
    println("  Status: $(tx["status"])")
catch e
    println("$(RED)✗$(RESET) Transaction failed: $(e)")
    println("$(YELLOW)Note:$(RESET) This is expected since we're in read-only mode")
    
    println("\nTo send actual transactions, you would connect with a private key:")
    println("```julia")
    println("wallet = connectWallet(address, ETHEREUM, privateKey=\"your_private_key\")")
    println("tx = sendTransaction(wallet.address, recipient, amount)")
    println("```")
end

# 7. Disconnect wallets
printSection("7. Disconnecting Wallets")

println("Disconnecting all wallets...")
disconnectWallet(ethereum_address)
disconnectWallet(polygon_address)
disconnectWallet(solana_address)
println("$(GREEN)✓$(RESET) All wallets disconnected")

println("\n$(GREEN)JuliaOS Wallets Example Completed$(RESET)")
println("-----------------------------------------------------") 