export * from './wormhole-bridge-unified';
export * from './wormhole-bridge-service';
export * from './register-service';
export * from './types';
export * from './config';
export * from './utils/logger';
export * from './bridge-service';
export * from './wallet-integration';

// Start the bridge API server if this file is executed directly
if (require.main === module) {
  // Import the API servers
  require('./bridge-api');
  require('./wallet-api');

  console.log('Wormhole Bridge services started');
}
