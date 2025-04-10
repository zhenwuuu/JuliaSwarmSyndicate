import { WormholeBridgeService } from './simplified-bridge-service';

/**
 * Register the Wormhole bridge service with the JuliaOS bridge
 */
export function registerWormholeBridgeService() {
  const wormholeBridgeService = new WormholeBridgeService();
  
  // Register the service with the JuliaOS bridge
  const juliaCommands = {
    'WormholeBridge.get_available_chains': async () => {
      try {
        const chains = wormholeBridgeService.getAvailableChains();
        return { success: true, chains };
      } catch (error: any) {
        console.error('Error getting available chains:', error);
        return { success: false, error: error.message };
      }
    },
    
    'WormholeBridge.get_available_tokens': async (params: any[]) => {
      try {
        const chain = params[0];
        if (!chain) {
          return { success: false, error: 'Chain parameter is required' };
        }
        
        const tokens = wormholeBridgeService.getAvailableTokens(chain);
        return { success: true, tokens };
      } catch (error: any) {
        console.error('Error getting available tokens:', error);
        return { success: false, error: error.message };
      }
    },
    
    'WormholeBridge.bridge_tokens_wormhole': async (params: any[]) => {
      try {
        const { sourceChain, targetChain, token, amount, recipient, wallet, relayerFee } = params[0];
        
        // Validate required parameters
        if (!sourceChain || !targetChain || !token || !amount || !recipient || !wallet) {
          return { 
            success: false, 
            error: 'Missing required parameters. Required: sourceChain, targetChain, token, amount, recipient, wallet' 
          };
        }
        
        const result = await wormholeBridgeService.bridgeTokens(
          sourceChain,
          targetChain,
          token,
          amount,
          recipient,
          wallet,
          relayerFee
        );
        
        return { 
          success: true, 
          transactionHash: result.transactionHash,
          status: result.status,
          attestation: result.attestation,
          sourceChain: result.sourceChain,
          targetChain: result.targetChain
        };
      } catch (error: any) {
        console.error('Error bridging tokens:', error);
        return { success: false, error: error.message };
      }
    },
    
    'WormholeBridge.check_bridge_status_wormhole': async (params: any[]) => {
      try {
        const { sourceChain, transactionHash } = params[0];
        
        // Validate required parameters
        if (!sourceChain || !transactionHash) {
          return { 
            success: false, 
            error: 'Missing required parameters. Required: sourceChain, transactionHash' 
          };
        }
        
        const result = await wormholeBridgeService.checkTransactionStatus(sourceChain, transactionHash);
        
        return { 
          success: true, 
          status: result.status,
          attestation: result.attestation,
          targetChain: result.targetChain
        };
      } catch (error: any) {
        console.error('Error checking transaction status:', error);
        return { success: false, error: error.message };
      }
    },
    
    'WormholeBridge.redeem_tokens_wormhole': async (params: any[]) => {
      try {
        const { attestation, targetChain, wallet } = params[0];
        
        // Validate required parameters
        if (!attestation || !targetChain || !wallet) {
          return { 
            success: false, 
            error: 'Missing required parameters. Required: attestation, targetChain, wallet' 
          };
        }
        
        const result = await wormholeBridgeService.redeemTokens(attestation, targetChain, wallet);
        
        return { 
          success: true, 
          transactionHash: result.transactionHash,
          status: result.status
        };
      } catch (error: any) {
        console.error('Error redeeming tokens:', error);
        return { success: false, error: error.message };
      }
    },
    
    'WormholeBridge.get_wrapped_asset_info_wormhole': async (params: any[]) => {
      try {
        const { originalChain, originalAsset, targetChain } = params[0];
        
        // Validate required parameters
        if (!originalChain || !originalAsset || !targetChain) {
          return { 
            success: false, 
            error: 'Missing required parameters. Required: originalChain, originalAsset, targetChain' 
          };
        }
        
        const result = await wormholeBridgeService.getWrappedAssetInfo(originalChain, originalAsset, targetChain);
        
        return { 
          success: true, 
          wrappedAsset: result.wrappedAsset
        };
      } catch (error: any) {
        console.error('Error getting wrapped asset info:', error);
        return { success: false, error: error.message };
      }
    }
  };
  
  // Register all commands with the Julia server
  for (const [command, handler] of Object.entries(juliaCommands)) {
    // In a real implementation, this would register with the Julia server
    console.log(`Registered command: ${command}`);
    
    // Mock registration with the Julia server
    global[command] = handler;
  }
  
  console.log('Wormhole Bridge Service registered successfully');
  
  return juliaCommands;
}
