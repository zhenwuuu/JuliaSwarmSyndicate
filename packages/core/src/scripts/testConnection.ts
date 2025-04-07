import { Connection, Keypair } from '@solana/web3.js';
import { logger } from '../utils/logger';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config();

async function main() {
  try {
    // Initialize connection
    const connection = new Connection(process.env.SOLANA_RPC_URL!, 'confirmed');
    
    // Test connection
    const slot = await connection.getSlot();
    logger.info(`Connected to Solana mainnet! Current slot: ${slot}`);

    // Test wallet
    if (process.env.PRIVATE_KEY) {
      // Convert private key from array format to Uint8Array
      const privateKeyArray = JSON.parse(process.env.PRIVATE_KEY);
      const secretKey = new Uint8Array(privateKeyArray);
      const keypair = Keypair.fromSecretKey(secretKey);
      
      // Get wallet info
      const balance = await connection.getBalance(keypair.publicKey);
      logger.info(`Wallet address: ${keypair.publicKey.toString()}`);
      logger.info(`Balance: ${balance / 1e9} SOL`);
    } else {
      logger.warn('No private key found in environment variables');
    }

  } catch (error) {
    logger.error('Error testing connection:', error);
  }
}

main().catch(console.error); 