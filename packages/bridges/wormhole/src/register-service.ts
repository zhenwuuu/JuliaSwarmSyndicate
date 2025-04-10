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
        // In a real implementation, this would be securely retrieved from a wallet or keystore
        const privateKey = process.env[`${sourceChain.toUpperCase()}_PRIVATE_KEY`];
        if (!privateKey) {
          throw new Error(`Private key not found for ${sourceChain}`);
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
        // In a real implementation, this would be securely retrieved from a wallet or keystore
        const privateKey = process.env[`${targetChain.toUpperCase()}_PRIVATE_KEY`];
        if (!privateKey) {
          throw new Error(`Private key not found for ${targetChain}`);
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
