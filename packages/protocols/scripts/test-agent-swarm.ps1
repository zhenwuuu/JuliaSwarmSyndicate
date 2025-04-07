# Set environment variables
$env:MAINNET_RPC_URL = "https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY"

# Run the test
npx ts-node src/dex/test-agent-swarm.ts 