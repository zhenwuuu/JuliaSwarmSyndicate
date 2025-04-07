# JuliaOS Wallet Module

The Wallets module provides secure wallet management functionality for blockchain interactions within the JuliaOS framework. This module allows you to connect to wallets on various blockchain networks, query balances, send transactions, and view transaction history.

## Installation

To use the Wallets module in your Julia project:

```julia
import Pkg
Pkg.add(url="https://github.com/juliaos/framework", subdir="packages/framework/wallet")
```

Or add it to your project's dependencies:

```julia
# In your Project.toml
[deps]
Wallets = "b2c3d4e5-8e8f-11ee-0557-1befd66d0f22"
```

## Supported Blockchains

The Wallets module supports the following blockchain networks:

- **Ethereum** (chainId: 1)
- **Polygon** (chainId: 137)
- **Arbitrum** (chainId: 42161)
- **Optimism** (chainId: 10)
- **Base** (chainId: 8453)
- **BSC** (Binance Smart Chain, chainId: 56)
- **Solana**

## Basic Usage

```julia
using Wallets

# List all supported chains
chains = supportedChains()
for chain in chains
    chainId = isnothing(chain.chainId) ? "N/A" : chain.chainId
    println("$(chain.name) (chainId: $chainId)")
end

# Connect to a wallet in read-only mode (address only)
ethereum_address = "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
wallet = connectWallet(ethereum_address, ETHEREUM)

println("Connected to $(wallet.chain.name) wallet")
println("Address: $(wallet.address)")
println("Read-only mode: $(wallet.readOnly)")

# Check wallet balances
balances = getWalletBalance(wallet.address)
for (token, amount) in balances
    println("$token: $amount")
end

# Disconnect the wallet
disconnectWallet(wallet.address)
println("Wallet disconnected")
```

## Wallet Operations

### Connecting with Private Key

To connect a wallet with full transaction capabilities (not read-only):

```julia
# Replace with your actual private key (keep it secure!)
private_key = "0xYourPrivateKey"

# Connect with full access
wallet = connectWallet("0x742d35Cc6634C0532925a3b844Bc454e4438f44e", ETHEREUM, privateKey=private_key)
println("Connected to $(wallet.chain.name) wallet with full access")
```

### Sending Transactions

```julia
# Send 0.1 ETH to another address
recipient = "0x8F90595A593919Cf19aAECf6f71E174fa4713cCE"

# Validate the recipient address first
if validateAddress(recipient, ETHEREUM)
    # Send the transaction
    tx = sendTransaction(wallet.address, recipient, 0.1)
    println("Transaction sent!")
    println("Hash: $(tx["hash"])")
    println("Status: $(tx["status"])")
else
    println("Invalid recipient address")
end

# Send tokens
usdc_tx = sendTransaction(wallet.address, recipient, 100.0, "USDC")
println("Sent 100 USDC, hash: $(usdc_tx["hash"])")
```

### Viewing Transaction History

```julia
# Get transaction history
transactions = getTransactionHistory(wallet.address)

println("Transaction history:")
for (i, tx) in enumerate(transactions)
    direction = tx["from"] == wallet.address ? "OUT" : "IN"
    println("$i. [$direction] $(tx["amount"]) $(tx["token"]) - $(tx["status"])")
    println("   From: $(tx["from"])")
    println("   To: $(tx["to"])")
    println("   Hash: $(tx["hash"])")
    println("   Time: $(tx["timestamp"])")
    println()
end
```

## Working with Different Chains

```julia
# Connect to Solana wallet
solana_address = "5ZPBHzMr4zXgbANg2TKdX9zHEX1shBN3bdtX9c5vc2m5"
solana_wallet = connectWallet(solana_address, SOLANA)

println("Connected to Solana wallet")
sol_balances = getWalletBalance(solana_address)
println("SOL balance: $(sol_balances["SOL"])")

# Connect to Polygon wallet
polygon_address = "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
polygon_wallet = connectWallet(polygon_address, POLYGON)

println("Connected to Polygon wallet")
matic_balances = getWalletBalance(polygon_address)
println("MATIC balance: $(matic_balances["MATIC"])")
```

## Security Considerations

### Private Key Handling

This module is designed with security in mind:

1. Private keys are never stored persistently
2. Private keys are only used for transaction signing and never exposed
3. The read-only mode allows connecting to wallets without private keys for balance and history checking

### Best Practices

When using the Wallets module in your applications:

1. **Never** store private keys in plain text or hard-code them in your application
2. **Always** verify recipient addresses before sending transactions
3. Use the read-only mode when full transaction capabilities are not needed
4. Consider using a hardware wallet or secure key storage solution in production

## Integration with JuliaOS Backend

For advanced functionality such as cross-chain operations, the Wallets module can be integrated with the JuliaOS backend:

1. Ensure the JuliaOS backend is running: `cd julia && ./start.sh`
2. Use the Wallets module in conjunction with other modules like `Agents` and `Swarms`

## Additional Resources

- [JuliaOS Documentation](https://docs.juliaos.org)
- [Blockchain Security Guide](https://docs.juliaos.org/blockchain-security)
- [Framework Overview](https://docs.juliaos.org/framework)

## License

MIT License 