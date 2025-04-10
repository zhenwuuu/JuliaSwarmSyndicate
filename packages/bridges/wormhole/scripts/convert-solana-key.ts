import bs58 from 'bs58';

// Get the Base58 encoded private key from command line argument
const base58PrivateKey = process.argv[2];

if (!base58PrivateKey) {
  console.error('Please provide your Base58 encoded private key as a command line argument');
  console.error('Example: npx ts-node scripts/convert-solana-key.ts YOUR_BASE58_PRIVATE_KEY');
  process.exit(1);
}

try {
  // Decode the Base58 private key to a buffer
  const privateKeyBuffer = bs58.decode(base58PrivateKey);

  // Convert the buffer to an array of numbers
  const privateKeyArray = Array.from(privateKeyBuffer);

  // Convert to JSON format
  const jsonFormat = JSON.stringify(privateKeyArray);

  console.log('Your private key in JSON array format:');
  console.log(jsonFormat);

  console.log('\nYou can copy this entire string (including the square brackets) into your .env file');
  console.log('for the SOLANA_PRIVATE_KEY value.');
} catch (error) {
  console.error('Error converting private key:', error);
  console.log('Please make sure you entered a valid Base58 encoded private key.');
}
