import { ethers } from 'ethers';
import dotenv from 'dotenv';
import { 
  Chain,
  Network,
  TokenId,
  amount,
  encoding,
  signSendWait,
  wormhole
} from '@wormhole-foundation/sdk';
import evm from '@wormhole-foundation/sdk/evm';
import solana from '@wormhole-foundation/sdk/solana';
import { Connection, PublicKey, Keypair } from '@solana/web3.js';
import bs58 from 'bs58';

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
  
  // Initialize Wormhole with mainnet network
  const wh = await wormhole('Mainnet', [solana, evm]);
  
  // Get chain objects
  const solanaChain = wh.getChain('Solana');
  const ethereumChain = wh.getChain('Ethereum');
  
  console.log('Wormhole SDK initialized successfully');
  
  // Step 4: Create a token transfer
  console.log('\nCreating token transfer...');
  
  // Define the token (USDC on Solana)
  const tokenId = TokenId.fromChainAddress(
    'Solana' as Chain, 
    'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v'
  );
  
  // Create a signer object for Solana
  const solanaSigner = {
    signTransaction: async (tx: any) => {
      tx.partialSign(solanaWallet);
      return tx;
    },
    publicKey: solanaWallet.publicKey,
  };
  
  // Create a signer object for Ethereum
  const ethereumSigner = {
    signTransaction: async (tx: any) => {
      return await ethereumWallet.signTransaction(tx);
    },
    address: ethereumWallet.address,
  };
  
  // Step 5: Simulate the token transfer
  console.log('\nSimulating token transfer...');
  
  try {
    // Create a token transfer
    const xfer = await wh.tokenTransfer(
      tokenId,
      BigInt(Math.floor(transferAmount * 10**6)), // Convert to USDC base units (6 decimals)
      { chain: 'Solana' as Chain, address: solanaWallet.publicKey.toString() },
      { chain: 'Ethereum' as Chain, address: ethereumWallet.address },
      false // manual transfer (not automatic)
    );
    
    // Get a quote for the transfer
    const quote = await xfer.getQuote();
    console.log('Transfer quote:', quote);
    
    console.log('\nThis is a simulation only. In a real transfer, we would:');
    console.log('1. Initiate the transfer on Solana');
    console.log('2. Wait for the VAA to be generated');
    console.log('3. Redeem the tokens on Ethereum');
    
    console.log('\nTo perform an actual transfer, you would need to:');
    console.log('1. Call xfer.initiateTransfer(solanaSigner)');
    console.log('2. Call xfer.fetchAttestation(timeout)');
    console.log('3. Call xfer.completeTransfer(ethereumSigner)');
    
  } catch (error) {
    console.error('Error simulating token transfer:', error);
  }
  
  console.log('\nSimulation completed successfully!');
}

main().catch(console.error);
