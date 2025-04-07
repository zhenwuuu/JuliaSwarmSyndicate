# JuliaOS Blockchain Module

The Blockchain module provides a comprehensive interface for interacting with various blockchain networks. This module allows you to query blockchain data, interact with smart contracts, and perform blockchain operations across multiple networks.

## Installation

To use the Blockchain module in your Julia project:

```julia
import Pkg
Pkg.add(url="https://github.com/juliaos/framework", subdir="packages/framework/blockchain")
```

Or add it to your project's dependencies:

```julia
# In your Project.toml
[deps]
Blockchain = "f5e6d7g8-8e91-11ee-0559-1befd66d0f22"
```

## Supported Networks

The Blockchain module supports the following networks:

- **Ethereum Mainnet** (chainId: 1)
- **Ethereum Sepolia** (testnet, chainId: 11155111)
- **Polygon Mainnet** (chainId: 137)
- **Arbitrum One** (chainId: 42161)
- **Optimism** (chainId: 10)
- **Base** (chainId: 8453)
- **Solana Mainnet**

## Basic Usage

```julia
using Blockchain

# Get a predefined network
ethereum = getNetwork("ethereum")
polygon = getNetwork(137)  # By chain ID

println("Ethereum Chain ID: $(ethereum.chainId)")
println("Polygon Native Currency: $(polygon.nativeCurrency)")

# Check balance on the network
address = "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
eth_balance = getBalance(address, ethereum)
println("ETH Balance: $eth_balance")

# Check token balance
usdc_balance = getBalance(address, ethereum, "USDC")
println("USDC Balance: $usdc_balance")

# Get transaction details
tx_hash = "0x2c6a212e34cb9f3f5b7ba2cd29222c0e58b3664cb49a55e7e2b2eb1139607f21"
tx = getTransaction(tx_hash, ethereum)
println("Transaction from: $(tx.from)")
println("Transaction to: $(tx.to)")
println("Value: $(tx.value) ETH")
println("Status: $(tx.status)")

# Get block information
block = getBlock(17000000, ethereum)
println("Block timestamp: $(block.timestamp)")
println("Block miner: $(block.miner)")
println("Transactions in block: $(length(block.transactions))")
```

## Smart Contract Interaction

```julia
using Blockchain

# Define a simple ERC-20 ABI (abbreviated)
erc20_abi = [
    Dict(
        "name" => "balanceOf",
        "type" => "function",
        "inputs" => [Dict("name" => "owner", "type" => "address")],
        "outputs" => [Dict("name" => "balance", "type" => "uint256")],
        "stateMutability" => "view"
    ),
    Dict(
        "name" => "transfer",
        "type" => "function",
        "inputs" => [
            Dict("name" => "to", "type" => "address"),
            Dict("name" => "value", "type" => "uint256")
        ],
        "outputs" => [Dict("name" => "success", "type" => "bool")],
        "stateMutability" => "nonpayable"
    )
]

# Create a smart contract instance for an existing contract
usdc_address = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"  # USDC on Ethereum
ethereum = getNetwork("ethereum")

# Create a contract instance
usdc_contract = SmartContract(
    usdc_address,
    ethereum,
    erc20_abi,
    ""  # No bytecode needed for existing contracts
)

# Call contract method (read-only)
address = "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
balance = callContract(usdc_contract, "balanceOf", [address])
println("USDC Balance: $balance")

# Estimate gas for a transaction
from_address = "0x742d35Cc6634C0532925a3b844Bc454e4438f44e"
to_address = "0x8F90595A593919Cf19aAECf6f71E174fa4713cCE"
data = "0xa9059cbb000000000000000000000000742d35cc6634c0532925a3b844bc454e4438f44e0000000000000000000000000000000000000000000000000000000000000064"  # Example transfer data

gas = estimateGas(from_address, usdc_address, data, ethereum)
println("Estimated gas: $gas")
```

## Deploying Smart Contracts

```julia
using Blockchain

# Contract bytecode (abbreviated example)
bytecode = "0x608060405234801561001057600080fd5b506040518060400160405280600a81526020017f4d7920546f6b656e0000000000000000000000000000000000000000000000008152506000908051906020019061005c929190610062565b50610107565b82805461006e90610106565b90600052602060002090601f0160209004810192826100905760008555610137565b600052602060002090601f016020900482015b828111156101375780548255916100b65790600101906020826100a5565b5b50905061012991906101cf565b5090565b600081549050919050565b600061012b826100ee565b8152602001915050919050565b6000602082019050818103600083015261015081610110565b905091905056"

# Contract ABI (simplified example)
abi = [
    Dict(
        "type" => "constructor",
        "inputs" => [],
        "stateMutability" => "nonpayable"
    ),
    Dict(
        "name" => "name",
        "type" => "function",
        "inputs" => [],
        "outputs" => [Dict("name" => "", "type" => "string")],
        "stateMutability" => "view"
    )
]

# Get the desired network
ethereum_sepolia = getNetwork("ethereum sepolia")  # Use testnet for deployment

# Deploy the contract
println("Deploying contract to $(ethereum_sepolia.name)...")
contract = deployContract(bytecode, abi, [], ethereum_sepolia)

println("Contract deployed successfully!")
println("Contract address: $(contract.address)")

# Call a method on the newly deployed contract
name = callContract(contract, "name", [])
println("Contract name: $name")
```

## Working with Different Networks

```julia
using Blockchain

# Compare gas prices across networks
function compareGasPrices()
    networks = [
        getNetwork("ethereum"),
        getNetwork("polygon"),
        getNetwork("arbitrum"),
        getNetwork("optimism"),
        getNetwork("base")
    ]
    
    println("Current Gas Prices:")
    for network in networks
        # In a real implementation, this would make an RPC call
        # Using simulated values for demonstration
        gas_price = network.name == "Ethereum Mainnet" ? 20.0 : 
                    network.name == "Polygon Mainnet" ? 50.0 :
                    network.name == "Arbitrum One" ? 0.1 :
                    network.name == "Optimism" ? 0.01 :
                    0.005  # Base
                    
        println("$(network.name): $(gas_price) Gwei")
    end
end

compareGasPrices()
```

## Integration with JuliaOS Backend

The Blockchain module can be integrated with the JuliaOS backend for enhanced functionality:

```julia
using Blockchain
using JuliaOS.Bridge

# Connect to the JuliaOS backend
connected = connect()

if connected
    # Use the backend for blockchain operations
    response = execute("MarketData.getGasPrices", Dict())
    
    if response.success
        println("Gas Prices from Backend:")
        for (network, price) in response.data
            println("$network: $price Gwei")
        end
    end
end
```

## Additional Resources

- [JuliaOS Documentation](https://docs.juliaos.org)
- [Blockchain Module Reference](https://docs.juliaos.org/blockchain-module)
- [Smart Contract Development Guide](https://docs.juliaos.org/smart-contracts)
- [Framework Overview](https://docs.juliaos.org/framework)

## License

MIT License 