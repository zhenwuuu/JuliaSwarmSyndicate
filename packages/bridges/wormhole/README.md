# JuliaOS Wormhole Bridge

This package provides a Wormhole bridge integration for JuliaOS, enabling cross-chain token transfers between multiple blockchains including Ethereum, Solana, BSC, Avalanche, Fantom, Arbitrum, and Base.

## Features

- Bridge tokens between multiple chains using Wormhole
- Support for EVM chains (Ethereum, BSC, Avalanche, Fantom, Arbitrum, Base) and Solana
- Automatic VAA (Verified Action Approval) retrieval and processing
- Token wrapping and unwrapping
- Fee calculation and management
- Comprehensive error handling and logging

## Installation

```bash
# Clone the repository
git clone https://github.com/Juliaoscode/JuliaOS.git
cd JuliaOS

# Install dependencies
npm install
```

## Configuration

Create a `.env` file based on the provided `.env.example` with your RPC endpoints, private keys, and Wormhole contract addresses.

## Usage

### Using the Interactive CLI

The easiest way to use the Wormhole bridge is through the interactive CLI:

```bash
# Start the Julia server
cd scripts/server
./run-server.sh

# In another terminal, run the interactive CLI
node scripts/interactive.cjs

# Navigate to the Cross-Chain Hub and select Wormhole Bridge
```

### Programmatic Usage

```javascript
const { WormholeBridge } = require('./packages/bridges/wormhole');
const { ethers } = require('ethers');

async function bridgeTokens() {
  // Initialize Wormhole Bridge
  const wormholeBridge = new WormholeBridge({
    rpcEndpoints: {
      ethereum: 'https://mainnet.infura.io/v3/your-infura-key',
      solana: 'https://api.mainnet-beta.solana.com'
    }
  });

  // Bridge parameters
  const params = {
    sourceChain: 'ethereum',
    targetChain: 'solana',
    token: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', // USDC on Ethereum
    amount: ethers.parseUnits('10.0', 6), // 10 USDC
    recipient: 'your_solana_address'
  };

  // Bridge tokens
  const result = await wormholeBridge.bridgeTokens(params);
  console.log('Bridge result:', result);

  // If the bridge was successful, get the VAA
  if (result.status === 'pending' && result.sequence && result.emitterAddress) {
    // Wait for VAA (in production, this would be a separate process)
    setTimeout(async () => {
      const vaa = await wormholeBridge.getVAA(
        params.sourceChain,
        result.emitterAddress,
        result.sequence
      );

      // Redeem tokens on target chain
      const redeemResult = await wormholeBridge.redeemTokens(vaa, params.targetChain);
      console.log('Redeem result:', redeemResult);
    }, 60000); // Wait 1 minute for VAA
  }
}

bridgeTokens().catch(console.error);
```

### Getting Wrapped Asset Information

```javascript
const { WormholeBridge } = require('./packages/bridges/wormhole');

async function getWrappedAssetInfo() {
  const wormholeBridge = new WormholeBridge({
    rpcEndpoints: {
      ethereum: 'https://mainnet.infura.io/v3/your-infura-key',
      solana: 'https://api.mainnet-beta.solana.com'
    }
  });

  // Get wrapped USDC info on Solana
  const wrappedAssetInfo = await wormholeBridge.getWrappedAssetInfo(
    'ethereum',
    'A0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', // USDC on Ethereum (without 0x prefix)
    'solana'
  );

  console.log('Wrapped asset info:', wrappedAssetInfo);
}

getWrappedAssetInfo().catch(console.error);
```

## Testing

Test the Wormhole bridge integration through the interactive CLI:

```bash
# Start the Julia server
cd scripts/server
./run-server.sh

# In another terminal, run the interactive CLI
node scripts/interactive.cjs

# Navigate to the Cross-Chain Hub and select Wormhole Bridge
# Choose "Test Bridge Connection" option
```

Or run the Julia tests:

```bash
cd julia/test
julia test_wormhole_bridge.jl
```

## License

MIT
