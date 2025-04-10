import { ethers } from 'ethers';
import dotenv from 'dotenv';
import { Connection, PublicKey, Keypair } from '@solana/web3.js';
import bs58 from 'bs58';

// Load environment variables
dotenv.config();

/**
 * This script checks the balances of your Solana and Ethereum wallets
 * to verify they are properly set up for bridging.
 */
async function main() {
  console.log('Wormhole Bridge Balance Check');
  console.log('============================');
  
  // Step 1: Set up wallets and connections
  console.log('\nSetting up wallets and connections...');
  
  // Parse Solana private key
  let solanaWallet;
  try {
    // Try to parse as JSON array first
    let privateKeyData = process.env.SOLANA_PRIVATE_KEY || '';
    
    // Clean up the string if needed
    privateKeyData = privateKeyData.trim();
    
    // If it starts with a quote and ends with a quote, remove them
    if (privateKeyData.startsWith('"') && privateKeyData.endsWith('"')) {
      privateKeyData = privateKeyData.slice(1, -1);
    }
    if (privateKeyData.startsWith('\'') && privateKeyData.endsWith('\'')) {
      privateKeyData = privateKeyData.slice(1, -1);
    }
    
    // Try to parse as JSON
    let parsedKey;
    try {
      parsedKey = JSON.parse(privateKeyData);
      solanaWallet = Keypair.fromSecretKey(Buffer.from(parsedKey));
      console.log('Successfully parsed Solana private key as JSON array');
    } catch (error) {
      const jsonError = error as Error;
      // If it's not valid JSON but looks like an array, try to parse it manually
      if (privateKeyData.startsWith('[') && privateKeyData.endsWith(']')) {
        try {
          const arrayStr = privateKeyData.slice(1, -1);
          const numbers = arrayStr.split(',').map(num => parseInt(num.trim(), 10));
          solanaWallet = Keypair.fromSecretKey(Buffer.from(numbers));
          console.log('Successfully parsed Solana private key as manual array');
        } catch (error) {
          const arrayError = error as Error;
          throw new Error('Failed to parse as array: ' + arrayError.message);
        }
      } else {
        throw new Error('Not a JSON array: ' + jsonError.message);
      }
    }
  } catch (error) {
    const e = error as Error;
    console.log('JSON parsing failed, trying base58...');
    // If that fails, try to parse as base58 encoded string
    try {
      solanaWallet = Keypair.fromSecretKey(
        Buffer.from(bs58.decode(process.env.SOLANA_PRIVATE_KEY?.trim() || ''))
      );
      console.log('Successfully parsed Solana private key as base58');
    } catch (error2) {
      const e2 = error2 as Error;
      console.log('Base58 parsing failed, trying hex...');
      // If that fails too, try to parse as hex string
      try {
        solanaWallet = Keypair.fromSecretKey(
          Buffer.from(process.env.SOLANA_PRIVATE_KEY?.trim() || '', 'hex')
        );
        console.log('Successfully parsed Solana private key as hex');
      } catch (error3) {
        const e3 = error3 as Error;
        console.error('ERROR: Could not parse SOLANA_PRIVATE_KEY');
        console.error('Please provide a valid Solana private key in one of these formats:');
        console.error('1. JSON array of numbers');
        console.error('2. Base58 encoded string');
        console.error('3. Hex string');
        console.error('Detailed error:');
        console.error(e.message);
        console.error(e2.message);
        console.error(e3.message);
        process.exit(1);
      }
    }
  }
  
  // Set up Ethereum wallet
  const ethereumPrivateKey = process.env.ETHEREUM_PRIVATE_KEY;
  if (!ethereumPrivateKey) {
    console.error('ERROR: ETHEREUM_PRIVATE_KEY is required in .env file');
    process.exit(1);
  }
  
  // Create Ethereum provider and wallet
  const ethereumRpcUrl = process.env.ETHEREUM_RPC_URL || process.env.MAINNET_RPC_URL || 'https://dry-capable-wildflower.quiknode.pro/2c509d168dcf3f71d49a4341f650c4b427be5b30';
  const ethereumProvider = new ethers.JsonRpcProvider(ethereumRpcUrl);
  const ethereumWallet = new ethers.Wallet(ethereumPrivateKey, ethereumProvider);
  
  // Create Solana connection
  const solanaRpcUrl = process.env.SOLANA_RPC_URL || process.env.SOLANA_MAINNET_RPC_URL || 'https://cosmopolitan-restless-sunset.solana-mainnet.quiknode.pro/ca360edea8156bd1629813a9aaabbfceb5cc9d05';
  const solanaConnection = new Connection(solanaRpcUrl);
  
  // Display wallet addresses
  console.log(`Solana wallet address: ${solanaWallet.publicKey.toString()}`);
  console.log(`Ethereum wallet address: ${ethereumWallet.address}`);
  
  // Step 2: Check balances
  console.log('\nChecking balances...');
  
  // Check Solana SOL balance
  const solBalance = await solanaConnection.getBalance(solanaWallet.publicKey);
  console.log(`Solana balance: ${solBalance / 10**9} SOL`);
  
  // Check Ethereum ETH balance
  const ethBalance = await ethereumProvider.getBalance(ethereumWallet.address);
  console.log(`Ethereum balance: ${ethers.formatEther(ethBalance)} ETH`);
  
  // Check USDC balance on Solana
  const usdcMint = new PublicKey('EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v'); // USDC on Solana
  const tokenAccounts = await solanaConnection.getParsedTokenAccountsByOwner(
    solanaWallet.publicKey,
    { mint: usdcMint }
  );
  
  if (tokenAccounts.value.length === 0) {
    console.log('No USDC token account found on Solana');
  } else {
    const tokenAccount = tokenAccounts.value[0].pubkey;
    const tokenAccountInfo = await solanaConnection.getParsedAccountInfo(tokenAccount);
    
    // @ts-ignore
    const tokenBalance = tokenAccountInfo.value.data.parsed.info.tokenAmount.uiAmount;
    console.log(`USDC balance on Solana: ${tokenBalance} USDC`);
  }
  
  // Check USDC balance on Ethereum
  const usdcAddress = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48'; // USDC on Ethereum
  const usdcAbi = ['function balanceOf(address) view returns (uint256)', 'function decimals() view returns (uint8)'];
  
  try {
    const usdcContract = new ethers.Contract(usdcAddress, usdcAbi, ethereumProvider);
    const usdcDecimals = await usdcContract.decimals();
    const usdcBalance = await usdcContract.balanceOf(ethereumWallet.address);
    console.log(`USDC balance on Ethereum: ${ethers.formatUnits(usdcBalance, usdcDecimals)} USDC`);
  } catch (error) {
    console.log('Error checking USDC balance on Ethereum:', error);
  }
  
  // Step 3: Check Wormhole contract addresses
  console.log('\nWormhole contract addresses:');
  console.log(`Solana Wormhole Bridge: worm2ZoG2kUd4vFXhvjh93UUH596ayRfgQ2MgjNMTth`);
  console.log(`Solana Token Bridge: wormDTUJ6AWPNvk59vGQbDvGJmqbDTdgWgAqcLBCgUb`);
  console.log(`Ethereum Wormhole Bridge: 0x98f3c9e6E3fAce36bAAd05FE09d375Ef1464288B`);
  console.log(`Ethereum Token Bridge: 0x3ee18B2214AFF97000D974cf647E7C347E8fa585`);
  
  console.log('\nBalance check completed successfully!');
  console.log('\nTo bridge tokens using Wormhole:');
  console.log('1. You need SOL on Solana for transaction fees');
  console.log('2. You need ETH on Ethereum for transaction fees');
  console.log('3. You need USDC on the source chain to bridge');
  
  if (solBalance < 10000000) { // 0.01 SOL
    console.log('\nWARNING: Insufficient SOL balance for transaction fees');
    console.log('Please fund your Solana wallet with at least 0.01 SOL for transaction fees');
  }
  
  if (ethBalance < ethers.parseEther('0.01')) {
    console.log('\nWARNING: Insufficient ETH balance for transaction fees');
    console.log('Please fund your Ethereum wallet with at least 0.01 ETH for transaction fees');
  }
}

main().catch(console.error);
