import dotenv from 'dotenv';
import { ethers } from 'ethers';
import { Connection } from '@solana/web3.js';

dotenv.config();

const requiredEnvVars = [
  'BASE_SEPOLIA_RPC_URL',
  'SOLANA_RPC_URL',
  'BASE_BRIDGE_CONTRACT',
  'SOLANA_PROGRAM_ID',
  'PRIVATE_KEY',
  'SOLANA_PRIVATE_KEY',
  'BASE_CHAIN_ID',
  'SOLANA_CHAIN_ID'
];

for (const envVar of requiredEnvVars) {
  if (!process.env[envVar]) {
    throw new Error(`Missing required environment variable: ${envVar}`);
  }
}

const config = {
  base: {
    rpcUrl: process.env.BASE_SEPOLIA_RPC_URL!,
    chainId: parseInt(process.env.BASE_CHAIN_ID!),
    bridgeContract: process.env.BASE_BRIDGE_CONTRACT!,
    privateKey: process.env.PRIVATE_KEY!
  },
  solana: {
    rpcUrl: process.env.SOLANA_RPC_URL!,
    chainId: parseInt(process.env.SOLANA_CHAIN_ID!),
    programId: process.env.SOLANA_PROGRAM_ID!,
    privateKey: process.env.SOLANA_PRIVATE_KEY!
  },
  pollingInterval: parseInt(process.env.POLLING_INTERVAL || '5000'),
  logLevel: process.env.LOG_LEVEL || 'info'
};

export default config; 