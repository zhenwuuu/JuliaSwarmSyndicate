import { ethers } from 'ethers';
import dotenv from 'dotenv';
import {
  Chain,
  Network,
  TokenId,
  amount,
  toNative,
  Wormhole,
  WormholeConfig
} from '@wormhole-foundation/sdk';
import { 
  Connection, 
  PublicKey, 
  Keypair 
} from '@solana/web3.js';

// Load environment variables
dotenv.config();

/**
 * This script demonstrates how to use the new Wormhole SDK to bridge tokens
 * from Solana to Ethereum.
 */
async function main() {
  console.log('Wormhole Bridge Demo (New SDK)');
  console.log('=============================');
  
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
      const bs58 = require('bs58');
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
  
  if (solBalance < 10000000) { // 0.01 SOL
    console.error('ERROR: Insufficient SOL balance for transaction fees');
    console.log('Please fund your Solana wallet with at least 0.01 SOL for transaction fees');
    process.exit(1);
  }
  
  // Check USDC balance on Solana
  const usdcMint = new PublicKey('EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v'); // USDC on Solana
  const tokenAccounts = await solanaConnection.getParsedTokenAccountsByOwner(
    solanaWallet.publicKey,
    { mint: usdcMint }
  );
  
  if (tokenAccounts.value.length === 0) {
    console.error('ERROR: No USDC token account found');
    console.log('Please fund your Solana wallet with USDC');
    process.exit(1);
  }
  
  const tokenAccount = tokenAccounts.value[0].pubkey;
  const tokenAccountInfo = await solanaConnection.getParsedAccountInfo(tokenAccount);
  
  // @ts-ignore
  const tokenBalance = tokenAccountInfo.value.data.parsed.info.tokenAmount.uiAmount;
  console.log(`USDC balance: ${tokenBalance} USDC`);
  
  const transferAmount = 0.1; // 0.1 USDC
  
  if (tokenBalance < transferAmount) {
    console.error('ERROR: Insufficient USDC balance');
    console.log(`Please fund your Solana wallet with at least ${transferAmount} USDC`);
    process.exit(1);
  }
  
  // Step 3: Initialize Wormhole SDK
  console.log('\nInitializing Wormhole SDK...');
  
  // Create a custom config with our RPC endpoints
  const config: WormholeConfig = {
    rpcs: {
      [Chain.Ethereum]: ethereumRpcUrl,
      [Chain.Solana]: solanaRpcUrl
    }
  };
  
  // Initialize Wormhole with mainnet network and custom config
  const wormhole = new Wormhole(Network.MAINNET, config);
  
  // Get chain objects
  const solanaChain = wormhole.getChain(Chain.Solana);
  const ethereumChain = wormhole.getChain(Chain.Ethereum);
  
  console.log('Wormhole SDK initialized successfully');
  
  // Step 4: Set up the token bridge
  console.log('\nSetting up token bridge...');
  
  // Get token bridge for Solana
  const solanaTokenBridge = solanaChain.getTokenBridge();
  
  // Define the token (USDC on Solana)
  const tokenId = TokenId.fromChainAddress(
    Chain.Solana, 
    'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v'
  );
  
  // Define the amount to transfer (0.1 USDC with 6 decimals)
  const bridgeAmount = amount.units(transferAmount, 6);
  
  console.log(`Ready to bridge ${transferAmount} USDC from Solana to Ethereum`);
  console.log(`From: ${solanaWallet.publicKey.toString()}`);
  console.log(`To: ${ethereumWallet.address}`);
  
  // Step 5: Simulate the bridge operation
  console.log('\nSimulating bridge operation...');
  console.log('In a real implementation, we would:');
  console.log('1. Create a transfer using solanaTokenBridge.transfer()');
  console.log('2. Sign and send the transaction using the Solana wallet');
  console.log('3. Wait for the VAA to be generated');
  console.log('4. Redeem the tokens on Ethereum using ethereumTokenBridge.redeem()');
  
  console.log('\nThis simulation demonstrates that:');
  console.log('1. Your wallets are properly set up');
  console.log('2. You have sufficient balances for the bridge operation');
  console.log('3. The Wormhole SDK is properly initialized');
  
  console.log('\nTo perform an actual bridge operation, you would need to:');
  console.log('1. Implement the wallet signing for both chains');
  console.log('2. Handle error cases and retries');
  console.log('3. Provide feedback to the user throughout the process');
  
  console.log('\nSimulation completed successfully!');
}

main().catch(console.error);
