import { Connection, Keypair, PublicKey } from '@solana/web3.js';
import { TOKEN_PROGRAM_ID, getAccount, getOrCreateAssociatedTokenAccount } from '@solana/spl-token';
import * as fs from 'fs';
import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config();

async function main() {
    // Connect to Solana devnet
    const connection = new Connection(process.env.SOLANA_RPC_URL!, 'confirmed');
    
    // Load the keypair
    const keypairPath = path.join(__dirname, '../solana-keypair.json');
    const keypairData = JSON.parse(fs.readFileSync(keypairPath, 'utf-8'));
    const keypair = Keypair.fromSecretKey(new Uint8Array(keypairData));

    // Get the token mint
    const mint = new PublicKey(process.env.SOLANA_TEST_TOKEN_MINT!);
    
    console.log('Checking token balance...');
    // Get the token account
    const tokenAccount = await getOrCreateAssociatedTokenAccount(
        connection,
        keypair,
        mint,
        keypair.publicKey
    );

    // Get the token account info
    const accountInfo = await getAccount(connection, tokenAccount.address);
    
    console.log('Token Mint:', mint.toBase58());
    console.log('Token Account:', tokenAccount.address.toBase58());
    console.log('Balance:', Number(accountInfo.amount) / Math.pow(10, 9), 'tokens'); // Divide by 10^9 because we used 9 decimals
}

main().catch(console.error); 