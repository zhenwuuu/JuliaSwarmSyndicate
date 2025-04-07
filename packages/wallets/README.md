# Wallet Integration Package

A robust, production-ready wallet integration package for Web3 applications, supporting multiple chains including Base, Ethereum, and Solana.

## Features

- Multi-chain wallet support (Base, Ethereum, Solana)
- Cross-chain transactions and bridging
- Comprehensive error handling
- Rate limiting and request queuing
- Structured logging and monitoring
- TypeScript support
- Production-ready security features

## Installation

```bash
npm install @juliaos/wallets
# or
yarn add @juliaos/wallets
```

## Quick Start

```typescript
import { WalletManager } from '@juliaos/wallets';

const walletManager = new WalletManager();

// Connect to wallet
await walletManager.connect();

// Get wallet address
const address = await walletManager.getAddress();

// Send transaction
const tx = await walletManager.sendTransaction({
  to: '0x...',
  value: ethers.parseEther('1.0')
});

// Disconnect
await walletManager.disconnect();
```

## API Reference

### WalletManager

The main class for managing wallet connections and transactions.

#### Methods

##### `connect(): Promise<void>`
Connects to the user's wallet.

##### `disconnect(): Promise<void>`
Disconnects from the wallet.

##### `getAddress(): Promise<string>`
Returns the connected wallet address.

##### `getBalance(): Promise<string>`
Returns the wallet balance in native token.

##### `sendTransaction(transaction: TransactionRequest): Promise<TransactionResponse>`
Sends a transaction.

##### `signMessage(message: string): Promise<string>`
Signs a message using the connected wallet.

##### `switchNetwork(chainId: number): Promise<void>`
Switches to the specified network.

### Cross-Chain Features

#### Methods

##### `sendCrossChainTransaction(tx: CrossChainTransaction): Promise<string>`
Initiates a cross-chain transaction.

##### `getBridgeTransactionStatus(depositId: string): Promise<BridgeStatus>`
Gets the status of a bridge transaction.

##### `withdrawFromBridge(toAddress: string, amount: string): Promise<string>`
Initiates a withdrawal from the bridge.

##### `estimateBridgeFee(fromChain: number, toChain: number, amount: string): Promise<BridgeFeeEstimate>`
Estimates bridge fees for a cross-chain transaction.

## Error Handling

The package includes comprehensive error handling for common scenarios:

- Network connection issues
- Transaction failures
- Insufficient funds
- Invalid parameters
- Chain switching errors

```typescript
try {
  await walletManager.connect();
} catch (error) {
  if (error instanceof WalletError) {
    // Handle specific wallet errors
    console.error(error.message);
  } else {
    // Handle other errors
    console.error('Unexpected error:', error);
  }
}
```

## Events

The WalletManager emits various events that you can listen to:

```typescript
walletManager.on('connect', ({ address, chainId }) => {
  console.log('Connected:', address, 'on chain:', chainId);
});

walletManager.on('disconnect', () => {
  console.log('Disconnected');
});

walletManager.on('chainChanged', (chainId) => {
  console.log('Chain changed:', chainId);
});

walletManager.on('accountsChanged', (address) => {
  console.log('Account changed:', address);
});
```

## Rate Limiting

The package includes built-in rate limiting to prevent RPC node overload:

```typescript
// Configure rate limiting
const rateLimiter = RateLimiter.getInstance({
  maxRequests: 50,    // requests per time window
  timeWindow: 1000,   // time window in milliseconds
  queueSize: 100      // maximum queue size
});
```

## Logging

Structured logging is available for debugging and monitoring:

```typescript
const logger = WalletLogger.getInstance();

// Log levels
logger.debug('Debug message');
logger.info('Info message');
logger.warn('Warning message');
logger.error('Error message', error);

// Transaction logging
logger.logTransaction(
  'Transaction sent',
  txHash,
  chainId,
  address,
  { amount: '1.0' }
);
```

## Security Considerations

1. Never store private keys
2. Always validate transaction parameters
3. Use proper error handling
4. Implement rate limiting
5. Monitor for suspicious activity

## Best Practices

1. Always check wallet connection status before operations
2. Implement proper error handling
3. Use appropriate gas limits
4. Monitor transaction status
5. Implement proper cleanup on disconnect

## Troubleshooting

Common issues and solutions:

1. **Connection Issues**
   - Check if MetaMask/other wallet is installed
   - Ensure proper network configuration
   - Check for network connectivity

2. **Transaction Failures**
   - Verify sufficient funds
   - Check gas limits
   - Validate transaction parameters

3. **Chain Switching Issues**
   - Ensure chain is supported
   - Check network configuration
   - Verify RPC endpoint availability

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

MIT 