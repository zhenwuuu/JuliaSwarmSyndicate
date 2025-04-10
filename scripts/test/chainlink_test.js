// Chainlink Data Feed Test Script
import { ethers } from 'ethers';

// Configuration
const CHAINLINK_API_KEY = '3be84fe924323c5ce041de97dddfdd707f78d9b6285c28598ef2d4572fee6b1e';
const RPC_ENDPOINTS = {
  ethereum: 'https://dry-capable-wildflower.quiknode.pro/2c509d168dcf3f71d49a4341f650c4b427be5b30',
  base: 'https://withered-boldest-waterfall.base-mainnet.quiknode.pro/38ed3b981b066d4bd33984e96f6809e54d6c71b8',
  bsc: 'https://still-magical-orb.bsc.quiknode.pro/e14cb1f002c159ce0eb678a480698dc2abd7846c',
  arbitrum: 'https://wiser-thrilling-pool.arbitrum-mainnet.quiknode.pro/f7b7ccfade9f3ac53e01aaaff329dd5565239945',
  avalanche: 'https://green-cosmological-glade.avalanche-mainnet.quiknode.pro/aa5db7aa86b1576f08e44c51054d709f6698d485/ext/bc/C/rpc/',
  fantom: 'https://distinguished-icy-meme.fantom.quiknode.pro/69343151a0265c018d02ecfbca4b62a6c011fe1b',
  solana: 'https://cosmopolitan-restless-sunset.solana-mainnet.quiknode.pro/ca360edea8156bd1629813a9aaabbfceb5cc9d05'
};

// Chainlink Data Feed Addresses (Ethereum Mainnet)
const CHAINLINK_FEEDS = {
  'ETH/USD': '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419',
  'BTC/USD': '0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c',
  'LINK/USD': '0x2c1d072e956AFFC0D435Cb7AC38EF18d24d9127c',
  'AAVE/USD': '0x547a514d5e3769680Ce22B2361c10Ea13619e8a9',
  'UNI/USD': '0x553303d460EE0afB37EdFf9bE42922D8FF63220e'
};

// Chainlink Data Feed ABI
const CHAINLINK_FEED_ABI = [
  'function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)',
  'function decimals() external view returns (uint8)'
];

// Main function
async function testChainlinkDataFeeds() {
  console.log('Testing Chainlink Data Feeds');
  console.log('============================');

  try {
    // Initialize Ethereum provider
    const provider = new ethers.JsonRpcProvider(RPC_ENDPOINTS.ethereum);

    // Test connection
    const blockNumber = await provider.getBlockNumber();
    console.log(`Connected to Ethereum Mainnet. Current block: ${blockNumber}`);

    // Test each data feed
    for (const [pair, address] of Object.entries(CHAINLINK_FEEDS)) {
      console.log(`\nFetching ${pair} price...`);

      try {
        // Create contract instance
        const feedContract = new ethers.Contract(address, CHAINLINK_FEED_ABI, provider);

        // Get latest round data
        const roundData = await feedContract.latestRoundData();

        // Get decimals
        const decimals = await feedContract.decimals();

        // Calculate price
        const price = Number(roundData.answer) / Math.pow(10, decimals);

        // If price is too large for Number, handle it differently
        if (!isFinite(price)) {
          const answerStr = roundData.answer.toString();
          const scaleFactor = Math.pow(10, decimals);
          const priceStr = (BigInt(answerStr) * BigInt(100) / BigInt(scaleFactor)) / 100;
          console.log(`Price: $${priceStr} (calculated with BigInt)`);
        } else {
          console.log(`Price: $${price.toFixed(2)}`);
        }

        // Calculate data age
        const updatedAt = Number(roundData.updatedAt) * 1000; // Convert to milliseconds
        const now = Date.now();
        const dataAge = now - updatedAt;
        const dataAgeMinutes = Math.floor(dataAge / 60000);

        // Calculate confidence based on data age
        const confidence = Math.max(0.5, 1.0 - (dataAge / 7200000)); // Minimum 0.5 confidence, decreasing over 2 hours

        // Display results
        console.log(`Last updated: ${new Date(updatedAt).toLocaleString()} (${dataAgeMinutes} minutes ago)`);
        console.log(`Round ID: ${roundData.roundId}`);
        console.log(`Confidence: ${(confidence * 100).toFixed(1)}%`);
      } catch (error) {
        console.error(`Error fetching ${pair} price:`, error.message);
      }
    }

    console.log('\nChainlink Data Feed test completed.');
  } catch (error) {
    console.error('Test failed with error:', error.message);
  }
}

// Run the test
testChainlinkDataFeeds().catch(console.error);
