import * as fs from 'fs';
import * as path from 'path';
import { Keypair } from '@solana/web3.js';
import bs58 from 'bs58';

// Path to .env file
const envPath = path.resolve(__dirname, '../.env');

// Read the .env file
let envContent = fs.readFileSync(envPath, 'utf8');

// Check if the Solana private key is still the placeholder
if (envContent.includes('SOLANA_PRIVATE_KEY=your_solana_private_key_as_json_array')) {
  console.log('The SOLANA_PRIVATE_KEY in your .env file is still set to the placeholder value.');
  console.log('Please update it with your actual private key.');
  
  // Generate a new keypair for demonstration
  const keypair = Keypair.generate();
  const privateKeyArray = Array.from(keypair.secretKey);
  
  console.log('\nFor testing purposes, you can use this newly generated keypair:');
  console.log(`Public Key (Address): ${keypair.publicKey.toString()}`);
  console.log('Private Key (JSON Array):');
  console.log(JSON.stringify(privateKeyArray));
  
  console.log('\nTo update your .env file, replace the line:');
  console.log('SOLANA_PRIVATE_KEY=your_solana_private_key_as_json_array');
  console.log('\nWith:');
  console.log(`SOLANA_PRIVATE_KEY=${JSON.stringify(privateKeyArray)}`);
  
  console.log('\nWould you like to update the .env file automatically? (y/n)');
  process.stdin.once('data', (data) => {
    const input = data.toString().trim().toLowerCase();
    if (input === 'y' || input === 'yes') {
      // Update the .env file
      envContent = envContent.replace(
        'SOLANA_PRIVATE_KEY=your_solana_private_key_as_json_array',
        `SOLANA_PRIVATE_KEY=${JSON.stringify(privateKeyArray)}`
      );
      fs.writeFileSync(envPath, envContent);
      console.log('\n.env file updated successfully!');
      console.log(`Your new Solana wallet address is: ${keypair.publicKey.toString()}`);
      console.log('Note: This is a newly generated wallet with no funds. You will need to fund it before testing.');
    } else {
      console.log('\nNo changes made to the .env file.');
    }
    process.exit(0);
  });
} else {
  console.log('The SOLANA_PRIVATE_KEY in your .env file has been updated from the placeholder value.');
  console.log('Let\'s check if it\'s in a valid format...');
  
  // Extract the private key value
  const match = envContent.match(/SOLANA_PRIVATE_KEY=(.+)(\r?\n|$)/);
  if (match && match[1]) {
    let privateKeyStr = match[1].trim();
    
    // Remove quotes if present
    if ((privateKeyStr.startsWith('"') && privateKeyStr.endsWith('"')) ||
        (privateKeyStr.startsWith('\'') && privateKeyStr.endsWith('\''))) {
      privateKeyStr = privateKeyStr.slice(1, -1);
    }
    
    try {
      // Try to parse as JSON
      const parsedKey = JSON.parse(privateKeyStr);
      if (Array.isArray(parsedKey) && parsedKey.length === 64) {
        const keypair = Keypair.fromSecretKey(Buffer.from(parsedKey));
        console.log('Successfully parsed private key as JSON array.');
        console.log(`Your Solana wallet address is: ${keypair.publicKey.toString()}`);
        console.log('The private key is in the correct format.');
      } else {
        console.log('The private key is in JSON format but not a valid Solana keypair (should be an array of 64 numbers).');
      }
    } catch (e) {
      console.log('The private key is not in JSON format. Let\'s try other formats...');
      
      try {
        // Try to parse as base58
        const decoded = bs58.decode(privateKeyStr);
        if (decoded.length === 64) {
          const keypair = Keypair.fromSecretKey(decoded);
          console.log('Successfully parsed private key as base58.');
          console.log(`Your Solana wallet address is: ${keypair.publicKey.toString()}`);
          console.log('The private key is in the correct format.');
        } else {
          console.log('The private key is in base58 format but not a valid Solana keypair (wrong length).');
        }
      } catch (e2) {
        try {
          // Try to parse as hex
          const decoded = Buffer.from(privateKeyStr, 'hex');
          if (decoded.length === 64) {
            const keypair = Keypair.fromSecretKey(decoded);
            console.log('Successfully parsed private key as hex.');
            console.log(`Your Solana wallet address is: ${keypair.publicKey.toString()}`);
            console.log('The private key is in the correct format.');
          } else {
            console.log('The private key is in hex format but not a valid Solana keypair (wrong length).');
          }
        } catch (e3) {
          console.log('Could not parse the private key in any format.');
          console.log('Please make sure your private key is in one of these formats:');
          console.log('1. JSON array of numbers: [1,2,3,...]');
          console.log('2. Base58 encoded string');
          console.log('3. Hex string');
        }
      }
    }
  } else {
    console.log('Could not find SOLANA_PRIVATE_KEY in the .env file.');
  }
}
