import { JsonRpcProvider, Wallet, Contract, hexlify } from 'ethers';
import { Connection, PublicKey, Keypair } from '@solana/web3.js';
import { Program, AnchorProvider, web3 } from '@project-serum/anchor';
import { BridgeEvent } from './types';
import dotenv from 'dotenv';

// Define the token program ID
const TOKEN_PROGRAM_ID = new PublicKey('TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA');

dotenv.config();

// Base Sepolia configuration
const baseProvider = new JsonRpcProvider(process.env.BASE_SEPOLIA_RPC_URL);
const baseWallet = new Wallet(process.env.BASE_SEPOLIA_PRIVATE_KEY!, baseProvider);
const baseBridge = new Contract(
  process.env.BASE_SEPOLIA_BRIDGE_ADDRESS!,
  ['event BridgeInitiated(address indexed from, address indexed token, uint256 amount, bytes32 recipient, uint256 targetChainId)'],
  baseProvider
);

// Solana configuration
const solanaConnection = new Connection(process.env.SOLANA_RPC_URL!);
const solanaWallet = Keypair.fromSecretKey(
  Buffer.from(JSON.parse(process.env.SOLANA_PRIVATE_KEY!))
);
const provider = new AnchorProvider(solanaConnection, solanaWallet as any, {});
const program = new Program(
  require('./idl/julia_bridge.json'),
  new PublicKey(process.env.SOLANA_BRIDGE_PROGRAM_ID!),
  provider
);

async function handleBaseSepoliaEvent(event: BridgeEvent) {
  try {
    console.log('Processing Base Sepolia bridge event:', event);
    
    // Verify the event is for Solana
    if (event.targetChainId !== Number(process.env.SOLANA_CHAIN_ID)) {
      console.log('Event not for Solana, skipping');
      return;
    }

    // Convert recipient address to Solana public key
    const recipientPubkey = new PublicKey(event.recipient);

    // Get bridge state account
    const bridgeState = await program.account.bridgeState.fetch(
      new PublicKey(process.env.SOLANA_BRIDGE_PROGRAM_ID!)
    );

    // Get bridge token account
    const bridgeTokenAccount = await program.account.bridgeTokenAccount.fetch(
      new PublicKey(process.env.SOLANA_BRIDGE_PROGRAM_ID!)
    );

    // Get recipient token account
    const recipientTokenAccount = await program.account.recipientTokenAccount.fetch(
      new PublicKey(process.env.SOLANA_BRIDGE_PROGRAM_ID!)
    );

    // Call Solana program to bridge tokens
    const tx = await program.methods
      .bridgeToSolana(
        event.amount,
        event.recipient,
        event.sourceChainId
      )
      .accounts({
        bridgeState,
        bridgeTokenAccount,
        recipientTokenAccount,
        authority: solanaWallet.publicKey,
        tokenProgram: TOKEN_PROGRAM_ID,
      })
      .rpc();

    console.log('Solana bridge transaction:', tx);
  } catch (error) {
    console.error('Error processing Base Sepolia event:', error);
  }
}

async function handleSolanaEvent(event: BridgeEvent) {
  try {
    console.log('Processing Solana bridge event:', event);
    
    // Verify the event is for Base Sepolia
    if (event.targetChainId !== Number(process.env.BASE_SEPOLIA_CHAIN_ID)) {
      console.log('Event not for Base Sepolia, skipping');
      return;
    }

    // Convert recipient address to Base Sepolia address
    const recipientAddress = hexlify(event.recipient);

    // Call Base Sepolia bridge to release tokens
    const tx = await baseBridge.bridge(
      process.env.BASE_SEPOLIA_TEST_TOKEN_ADDRESS,
      event.amount,
      recipientAddress,
      event.targetChainId,
      { gasLimit: 500000 }
    );

    console.log('Base Sepolia bridge transaction:', tx.hash);
  } catch (error) {
    console.error('Error processing Solana event:', error);
  }
}

async function startRelay() {
  console.log('Starting relay service...');

  // Listen for Base Sepolia events
  baseBridge.on('BridgeInitiated', async (from, token, amount, recipient, targetChainId) => {
    const event: BridgeEvent = {
      from,
      token,
      amount: BigInt(amount),
      recipient: new Uint8Array(recipient),
      sourceChainId: Number(process.env.BASE_SEPOLIA_CHAIN_ID),
      targetChainId,
    };
    await handleBaseSepoliaEvent(event);
  });

  // Listen for Solana events
  program.addEventListener('BridgeEvent', async (event) => {
    await handleSolanaEvent(event as unknown as BridgeEvent);
  });

  console.log('Relay service started');
}

startRelay().catch(console.error); 