import { Connection, Keypair, PublicKey } from '@solana/web3.js';
import { TOKEN_PROGRAM_ID, createMint, getOrCreateAssociatedTokenAccount } from '@solana/spl-token';
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

    console.log('Creating test token mint...');
    
    // Create new token mint
    const mint = await createMint(
        connection,
        keypair,
        keypair.publicKey, // mint authority
        keypair.publicKey, // freeze authority
        9 // decimals
    );

    console.log('Token mint created:', mint.toBase58());

    // Create associated token account for the keypair
    const tokenAccount = await getOrCreateAssociatedTokenAccount(
        connection,
        keypair,
        mint,
        keypair.publicKey
    );

    console.log('Token account created:', tokenAccount.address.toBase58());

    // Update .env file with the new token mint address
    const envPath = path.join(__dirname, '../.env');
    let envContent = fs.readFileSync(envPath, 'utf-8');
    envContent = envContent.replace(
        /SOLANA_TEST_TOKEN_MINT=.*/,
        `SOLANA_TEST_TOKEN_MINT=${mint.toBase58()}`
    );
    fs.writeFileSync(envPath, envContent);

    console.log('Updated .env file with new token mint address');
}

main().catch(console.error); 