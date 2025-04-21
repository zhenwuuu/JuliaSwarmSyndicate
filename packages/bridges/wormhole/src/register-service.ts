import { WormholeBridgeService } from './wormhole-bridge-service';
import { JuliaBridge } from '@juliaos/framework';

/**
 * Register the Wormhole bridge service with the JuliaOS bridge
 */
export function registerWormholeBridgeService() {
  const wormholeBridgeService = new WormholeBridgeService();

  // Register the service with the JuliaOS bridge
  JuliaBridge.registerService('WormholeBridge', {
    getAvailableChains: async () => {
      try {
        const chains = await wormholeBridgeService.getAvailableChains();
        return { chains };
      } catch (error) {
        console.error('Error getting available chains:', error);
        return { error: error.message };
      }
    },

    getAvailableTokens: async ({ chain }) => {
      try {
        const tokens = await wormholeBridgeService.getAvailableTokens(chain);
        return { tokens };
      } catch (error) {
        console.error('Error getting available tokens:', error);
        return { error: error.message };
      }
    },

    bridgeTokens: async ({ sourceChain, targetChain, token, amount, recipient, wallet, relayerFee }) => {
      try {
        // Get the private key for the source chain
        let privateKey;

        // First try to get the private key from the wallet parameter
        if (wallet && wallet.privateKey) {
          privateKey = wallet.privateKey;
        } else {
          // Try to get the private key from environment variables as a fallback
          privateKey = process.env[`${sourceChain.toUpperCase()}_PRIVATE_KEY`];

          // If still not found, try to get from a secure wallet manager
          if (!privateKey) {
            try {
              // In a production environment, you would use a secure wallet manager
              // For now, we'll use a simple approach with known test keys
              const testKeys: Record<string, string> = {
                'ethereum': '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // Test key, not real
                'solana': 'ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890abcdefghijklmnopqrstuvwxyz', // Test key, not real
                'bsc': '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // Test key, not real
                'avalanche': '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // Test key, not real
                'fantom': '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // Test key, not real
                'arbitrum': '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // Test key, not real
                'base': '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef' // Test key, not real
              };

              privateKey = testKeys[sourceChain];
            } catch (walletError) {
              console.error(`Error getting private key from wallet manager: ${walletError}`);
            }
          }
        }

        if (!privateKey) {
          throw new Error(`Private key not found for ${sourceChain}. Please provide a wallet with a private key.`);
        }

        const result = await wormholeBridgeService.bridgeTokens({
          sourceChain,
          targetChain,
          token,
          amount,
          recipient,
          relayerFee,
          privateKey
        });

        return result;
      } catch (error) {
        console.error('Error bridging tokens:', error);
        return { error: error.message };
      }
    },

    checkTransactionStatus: async ({ sourceChain, transactionHash }) => {
      try {
        const status = await wormholeBridgeService.checkTransactionStatus(sourceChain, transactionHash);
        return status;
      } catch (error) {
        console.error('Error checking transaction status:', error);
        return { error: error.message };
      }
    },

    redeemTokens: async ({ attestation, targetChain, wallet }) => {
      try {
        // Get the private key for the target chain
        let privateKey;

        // First try to get the private key from the wallet parameter
        if (wallet && wallet.privateKey) {
          privateKey = wallet.privateKey;
        } else {
          // Try to get the private key from environment variables as a fallback
          privateKey = process.env[`${targetChain.toUpperCase()}_PRIVATE_KEY`];

          // If still not found, try to get from a secure wallet manager
          if (!privateKey) {
            try {
              // In a production environment, you would use a secure wallet manager
              // For now, we'll use a simple approach with known test keys
              const testKeys: Record<string, string> = {
                'ethereum': '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // Test key, not real
                'solana': 'ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890abcdefghijklmnopqrstuvwxyz', // Test key, not real
                'bsc': '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // Test key, not real
                'avalanche': '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // Test key, not real
                'fantom': '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // Test key, not real
                'arbitrum': '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // Test key, not real
                'base': '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef' // Test key, not real
              };

              privateKey = testKeys[targetChain];
            } catch (walletError) {
              console.error(`Error getting private key from wallet manager: ${walletError}`);
            }
          }
        }

        if (!privateKey) {
          throw new Error(`Private key not found for ${targetChain}. Please provide a wallet with a private key.`);
        }

        const result = await wormholeBridgeService.redeemTokens(attestation, targetChain, privateKey);
        return result;
      } catch (error) {
        console.error('Error redeeming tokens:', error);
        return { error: error.message };
      }
    },

    getWrappedAssetInfo: async ({ originalChain, originalAsset, targetChain }) => {
      try {
        const info = await wormholeBridgeService.getWrappedAssetInfo(originalChain, originalAsset, targetChain);
        return info;
      } catch (error) {
        console.error('Error getting wrapped asset info:', error);
        return { error: error.message };
      }
    }
  });

  console.log('Wormhole bridge service registered successfully');
}
