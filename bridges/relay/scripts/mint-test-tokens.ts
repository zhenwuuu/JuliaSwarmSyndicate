import { Connection, Keypair, PublicKey } from '@solana/web3.js';
import { TOKEN_PROGRAM_ID, mintTo, getOrCreateAssociatedTokenAccount } from '@solana/spl-token';
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
    
    console.log('Getting token account...');
    // Get the token account
    const tokenAccount = await getOrCreateAssociatedTokenAccount(
        connection,
        keypair,
        mint,
        keypair.publicKey
    );

    console.log('Minting tokens...');
    // Mint 1000 tokens (with 9 decimals)
    await mintTo(
        connection,
        keypair,
        mint,
        tokenAccount.address,
        keypair,
        1000_000_000_000 // 1000 tokens with 9 decimals
    );

    console.log('Successfully minted 1000 tokens to:', tokenAccount.address.toBase58());
}

main().catch(console.error); 