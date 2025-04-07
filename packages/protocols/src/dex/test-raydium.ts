import { RaydiumDEXService } from './chains/solana/raydium-dex';

// Test tokens (using actual Solana token addresses)
const USDC = 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v';
const RAY = '4k3Dyjzvzp8eMZWUXbBCjEvwSkkk59S5iCNLY3QrkX6R';
const SOL = 'So11111111111111111111111111111111111111112';

async function testRaydiumIntegration() {
  try {
    console.log('Testing Raydium DEX Integration...\n');
    
    const raydium = new RaydiumDEXService();
    
    // Test price fetching
    console.log('Testing price fetching...');
    const rayPrice = await raydium.getPrice(RAY);
    console.log('RAY/SOL Price:', rayPrice);
    
    const usdcPrice = await raydium.getPrice(USDC);
    console.log('USDC/SOL Price:', usdcPrice);
    
    // Test liquidity fetching
    console.log('\nTesting liquidity fetching...');
    const rayLiquidity = await raydium.getLiquidity(RAY);
    console.log('RAY/SOL Liquidity:', rayLiquidity);
    
    const usdcLiquidity = await raydium.getLiquidity(USDC);
    console.log('USDC/SOL Liquidity:', usdcLiquidity);
    
    // Test pool information
    console.log('\nTesting pool information...');
    const pools = await (raydium as any).getPoolKeys(RAY);
    console.log('RAY Pool Info:', {
      baseMint: pools?.baseMint.toString(),
      quoteMint: pools?.quoteMint.toString(),
      lpMint: pools?.lpMint.toString(),
    });
    
    console.log('\nRaydium integration test completed successfully! ✅');
    
  } catch (error) {
    console.error('\nRaydium integration test failed! ❌');
    console.error('Error:', error);
    process.exit(1);
  }
}

// Run the test
testRaydiumIntegration().catch((error) => {
  console.error('Unhandled error:', error);
  process.exit(1);
}); 