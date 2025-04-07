# Contracts Directory

This directory contains all smart contracts for the JuliaOS Framework.

## Structure

- `ethereum/` - Ethereum-compatible smart contracts (Solidity)
  - `JuliaMarketplace.sol` - NFT and module marketplace contract
  - `JuliaBridge.sol` - Ethereum side of the cross-chain bridge
  - `TestToken.sol` - Test token for development and testing

- `solana/` - Solana programs (Rust)
  - Bridge program for Solana
  - Token program integrations

## Development

### Ethereum Contracts

```bash
# Compile contracts
npx hardhat compile

# Run tests
npx hardhat test

# Deploy contracts
npx hardhat run scripts/deploy/deploy-contracts.js --network base-sepolia
```

### Solana Programs

```bash
# Build Solana programs
cd solana
cargo build-bpf

# Run tests
cargo test-bpf

# Deploy programs
solana program deploy target/deploy/julia_bridge.so
```

## Security

All contracts have been audited by [Audit Firm Name] and the reports are available in the `audits/` directory. 