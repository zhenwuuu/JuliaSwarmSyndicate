# Wormhole Bridge Guide

This guide explains how to use the Wormhole bridge to transfer tokens between different blockchains.

## Prerequisites

Before you can use the Wormhole bridge, you need:

1. **Private Keys**: You need private keys for both the source and target chains.
2. **Native Tokens for Gas**: You need native tokens on both chains for transaction fees:
   - SOL on Solana
   - ETH on Ethereum
   - BNB on BSC
   - AVAX on Avalanche
   - FTM on Fantom
   - ARB on Arbitrum
   - ETH on Base
3. **Tokens to Bridge**: You need tokens on the source chain that you want to bridge.

## Setup

1. **Configure Environment**: Set up your environment variables in the JuliaOS project:
   - Copy the `.env.example` file to `.env` in the project root
   - Fill in your private keys and RPC endpoints

2. **Install Dependencies**: Run `npm install` to install the required dependencies.

3. **Check Balances**: Use the interactive CLI to check your wallet balances:
   ```bash
   # Start the Julia server
   cd scripts/server
   ./run-server.sh

   # In another terminal, run the interactive CLI
   node scripts/interactive.cjs

   # Navigate to "💼 Wallet Management" and select "View Balances"
   ```

## Bridging Tokens

### Using the Portal Bridge UI (Recommended)

The easiest way to bridge tokens is to use the official Wormhole Portal Bridge UI:

1. Go to [https://www.portalbridge.com/](https://www.portalbridge.com/)
2. Connect your wallets for both the source and target chains
3. Select the source and target chains
4. Select the token and amount to bridge
5. Click "Transfer" and follow the instructions

### Using the JuliaOS CLI (Recommended)

The easiest way to bridge tokens programmatically is to use the JuliaOS interactive CLI:

```bash
# Start the Julia server
cd scripts/server
./run-server.sh

# In another terminal, run the interactive CLI
node scripts/interactive.cjs

# Navigate to "🌉 Cross-Chain Hub" and select "Bridge Tokens"
# Follow the prompts to select source chain, target chain, token, and amount
```

### Using the Wormhole SDK (Advanced)

For advanced programmatic usage, you can use the Wormhole SDK through the JuliaOS framework:

```javascript
const { WormholeBridge } = require('./packages/bridges/wormhole');

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
    amount: '10000000', // 10 USDC (6 decimals)
    recipient: 'your_solana_address'
  };

  // Bridge tokens
  const result = await wormholeBridge.bridgeTokens(params);
  console.log('Bridge result:', result);
}

bridgeTokens().catch(console.error);
```

## Supported Tokens

The Wormhole bridge supports many tokens, including:

- USDC
- USDT
- ETH
- SOL
- AVAX
- BNB
- Many other ERC-20 and SPL tokens

When a token is bridged, it becomes a wrapped version on the target chain. For example, SOL on Ethereum is represented as wSOL.

## Fees

There are several fees involved in bridging tokens:

1. **Transaction Fees**: You need to pay transaction fees on both the source and target chains.
2. **Relayer Fees**: If you use automatic transfers, you need to pay a relayer fee.
3. **Wormhole Fees**: Wormhole charges a small fee for each transfer.

## Troubleshooting

If you encounter issues:

1. **Insufficient Gas**: Make sure you have enough native tokens for gas fees on both chains.
2. **Pending VAA**: Sometimes it takes time for the VAA to be generated. Wait a few minutes and try again.
3. **Failed Transaction**: Check the transaction on the blockchain explorer to see the reason for failure.
4. **Connection Issues**: Verify that your RPC endpoints are working correctly.
5. **Julia Server Not Running**: Make sure the Julia server is running before using the interactive CLI.

For JuliaOS-specific issues, check the logs in the terminal where the Julia server is running.

## Resources

- [Wormhole Documentation](https://wormhole.com/docs/)
- [Wormhole SDK Documentation](https://wormhole.com/docs/build/toolkit/typescript-sdk/wormhole-sdk/)
- [Portal Bridge UI](https://www.portalbridge.com/)
- [Wormhole Explorer](https://wormholescan.io/)
- [JuliaOS Documentation](https://github.com/Juliaoscode/JuliaOS)

## Security Considerations

- **Never share your private keys**: Keep your private keys secure and never commit them to version control.
- **Start with small amounts**: When testing, start with small amounts to minimize risk.
- **Verify addresses**: Always double-check addresses before bridging tokens.
- **Use official interfaces**: Prefer official interfaces like the Portal Bridge UI or the JuliaOS CLI to minimize risk.
- **Keep software updated**: Ensure you're using the latest version of JuliaOS and the Wormhole SDK.
- **Monitor transactions**: Always monitor your transactions on block explorers to ensure they complete successfully.
