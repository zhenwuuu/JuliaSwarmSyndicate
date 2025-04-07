# Set environment variables
$env:MAINNET_RPC_URL = "https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY"
$env:PRIVATE_KEY = "YOUR_PRIVATE_KEY"
$env:NETWORK = "mainnet" # or "testnet"

# Run the trading system
npx ts-node src/dex/run-trading-system.ts 