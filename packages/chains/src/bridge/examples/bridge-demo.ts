import { ethers } from 'ethers';
import { EthereumBridgeProvider } from '../EthereumBridgeProvider';
import { BridgeConfig } from '../types';

async function main() {
  // Set up configs for Ethereum (Goerli) -> Polygon (Mumbai) bridge
  const configs: BridgeConfig[] = [
    {
      sourceChainId: 5, // Goerli testnet
      targetChainId: 80001, // Mumbai testnet
      sourceTokenAddress: '0x7ea6eA49B0b0Ae9c5db7907d139D9Cd3439862a1', // Test USDC on Goerli
      targetTokenAddress: '0x0FA8781a83E46826621b3BC094Ea2A0212e71B23', // Test USDC on Mumbai
      bridgeContractAddress: '0xYourBridgeContractAddress', // Replace with actual bridge contract
      minAmount: ethers.parseEther('0.1'),
      maxAmount: ethers.parseEther('100'),
      fees: {
        percentage: 0.1, // 0.1%
        fixed: ethers.parseEther('0.01')
      }
    }
  ];

  // Set up provider URLs
  const providerUrls = new Map([
    [5, process.env.GOERLI_RPC_URL || 'https://goerli.infura.io/v3/your-api-key'],
    [80001, process.env.MUMBAI_RPC_URL || 'https://polygon-mumbai.infura.io/v3/your-api-key']
  ]);

  // Set up wallet
  const privateKey = process.env.PRIVATE_KEY || 'your-private-key';
  const provider = new ethers.JsonRpcProvider(providerUrls.get(5));
  const signer = new ethers.Wallet(privateKey, provider);

  // Initialize bridge provider
  const bridgeProvider = new EthereumBridgeProvider(
    configs,
    providerUrls,
    signer
  );

  try {
    // Check supported chains
    const supportedChains = await bridgeProvider.getSupportedChains();
    console.log('Supported chains:', supportedChains);

    // Get bridge configuration
    const config = await bridgeProvider.getConfig(5, 80001);
    console.log('Bridge configuration:', config);

    // Initiate bridge transaction
    const amount = ethers.parseEther('0.5');
    const targetAddress = await signer.getAddress(); // Bridge to same address on target chain
    
    console.log('Initiating bridge transaction...');
    const transaction = await bridgeProvider.initiate(
      5, // Goerli
      80001, // Mumbai
      amount,
      targetAddress
    );
    console.log('Transaction initiated:', transaction);

    // Wait for source chain confirmation
    console.log('Waiting for source chain confirmation...');
    let status = await bridgeProvider.getStatus(transaction.id);
    while (status !== 'SOURCE_CONFIRMED' && status !== 'FAILED') {
      await new Promise(resolve => setTimeout(resolve, 5000)); // Wait 5 seconds
      status = await bridgeProvider.getStatus(transaction.id);
      console.log('Current status:', status);
    }

    if (status === 'FAILED') {
      throw new Error('Transaction failed on source chain');
    }

    // Confirm transaction on target chain
    console.log('Confirming transaction on target chain...');
    const confirmedTx = await bridgeProvider.confirm(transaction.id);
    console.log('Transaction confirmed:', confirmedTx);

  } catch (error) {
    console.error('Error:', error);
  }
}

main().catch(console.error); 