import { Keypair } from '@solana/web3.js';
import bs58 from 'bs58';

// Generate a new Solana keypair
const keypair = Keypair.generate();

// Get the public key (address)
const publicKey = keypair.publicKey.toString();

// Get the private key in different formats
const privateKeyArray = Array.from(keypair.secretKey);
const privateKeyBase58 = bs58.encode(keypair.secretKey);
const privateKeyHex = Buffer.from(keypair.secretKey).toString('hex');

console.log('Generated Solana Keypair:');
console.log('=======================');
console.log(`Public Key (Address): ${publicKey}`);
console.log('\nPrivate Key Formats:');
console.log('------------------');
console.log('1. JSON Array:');
console.log(JSON.stringify(privateKeyArray));
console.log('\n2. Base58:');
console.log(privateKeyBase58);
console.log('\n3. Hex:');
console.log(privateKeyHex);
console.log('\nUse one of these formats in your .env file for SOLANA_PRIVATE_KEY');
