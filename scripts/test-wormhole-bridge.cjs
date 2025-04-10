const { JuliaBridge } = require('../packages/julia-bridge/dist/index');

const juliaBridge = new JuliaBridge({
  apiUrl: process.env.JULIA_API_URL || 'http://localhost:8052/api',
  healthUrl: process.env.JULIA_HEALTH_URL || 'http://localhost:8052/health',
  useWebSocket: false,
  useExistingServer: true
});

// Initialize the JuliaBridge
juliaBridge.initialize();

async function testWormholeBridge() {
  console.log('Testing Wormhole Bridge Implementation...');

  try {
    // Test getting available chains
    console.log('\nTesting get_available_chains...');
    const chainsResult = await juliaBridge.runJuliaCommand('WormholeBridge.get_available_chains', []);
    console.log('Result:', JSON.stringify(chainsResult, null, 2));

    // Test getting available tokens
    console.log('\nTesting get_available_tokens...');
    const tokensResult = await juliaBridge.runJuliaCommand('WormholeBridge.get_available_tokens', ['ethereum']);
    console.log('Result:', JSON.stringify(tokensResult, null, 2));

    // Test wallet connection
    console.log('\nTesting wallet connection...');
    const walletResult = await juliaBridge.runJuliaCommand('WalletIntegration.connect_wallet',
      ['0x1234567890123456789012345678901234567890', 'ethereum']);
    console.log('Wallet connection result:', JSON.stringify(walletResult, null, 2));

    // Test bridging tokens
    console.log('\nTesting bridge_tokens_wormhole...');
    const bridgeParams = {
      sourceChain: 'ethereum',
      targetChain: 'solana',
      token: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
      amount: '1000000',
      recipient: '0x1234567890123456789012345678901234567890',
      wallet: '0x0987654321098765432109876543210987654321'
    };
    const bridgeResult = await juliaBridge.runJuliaCommand('WormholeBridge.bridge_tokens_wormhole', [bridgeParams]);
    console.log('Result:', JSON.stringify(bridgeResult, null, 2));

    // Test checking bridge status
    console.log('\nTesting check_bridge_status_wormhole...');
    const statusParams = {
      sourceChain: 'ethereum',
      transactionHash: '0x1234567890123456789012345678901234567890123456789012345678901234'
    };
    const statusResult = await juliaBridge.runJuliaCommand('WormholeBridge.check_bridge_status_wormhole', [statusParams]);
    console.log('Result:', JSON.stringify(statusResult, null, 2));

    // Test redeeming tokens
    console.log('\nTesting redeem_tokens_wormhole...');
    const redeemParams = {
      attestation: '0x1234567890123456789012345678901234567890123456789012345678901234',
      targetChain: 'solana',
      wallet: '0x0987654321098765432109876543210987654321'
    };
    const redeemResult = await juliaBridge.runJuliaCommand('WormholeBridge.redeem_tokens_wormhole', [redeemParams]);
    console.log('Result:', JSON.stringify(redeemResult, null, 2));

    // Test getting wrapped asset info
    console.log('\nTesting get_wrapped_asset_info_wormhole...');
    const infoParams = {
      originalChain: 'ethereum',
      originalAsset: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48',
      targetChain: 'solana'
    };
    const infoResult = await juliaBridge.runJuliaCommand('WormholeBridge.get_wrapped_asset_info_wormhole', [infoParams]);
    console.log('Result:', JSON.stringify(infoResult, null, 2));

    // Test wallet disconnection
    console.log('\nTesting wallet disconnection...');
    const disconnectResult = await juliaBridge.runJuliaCommand('WalletIntegration.disconnect_wallet',
      ['0x1234567890123456789012345678901234567890', 'ethereum']);
    console.log('Wallet disconnection result:', JSON.stringify(disconnectResult, null, 2));

    console.log('\nAll tests completed successfully!');
  } catch (error) {
    console.error('Error testing Wormhole bridge:', error);
  }
}

// Run the test
testWormholeBridge();
