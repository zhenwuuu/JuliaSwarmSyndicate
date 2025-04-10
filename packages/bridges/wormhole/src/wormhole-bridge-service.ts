import { WormholeBridge, loadConfig } from './wormhole-bridge-unified';
import { Logger } from './utils/logger';
import { TokenBridgeParams } from './types';

/**
 * WormholeBridgeService class for handling bridge operations
 * This class is used by the JuliaOS bridge to communicate with the Wormhole bridge
 */
export class WormholeBridgeService {
  private bridge: WormholeBridge;
  private logger: Logger;

  constructor() {
    const config = loadConfig();
    this.bridge = new WormholeBridge(config);
    this.logger = new Logger('WormholeBridgeService');
  }

  /**
   * Get the available chains for bridging
   * @returns An array of available chains
   */
  async getAvailableChains(): Promise<string[]> {
    try {
      return await this.bridge.getAvailableChains();
    } catch (error) {
      this.logger.error(`Error getting available chains: ${error}`);
      return [];
    }
  }

  /**
   * Get the available tokens for a chain
   * @param chain The chain name
   * @returns An array of available tokens
   */
  async getAvailableTokens(chain: string): Promise<any[]> {
    try {
      return await this.bridge.getAvailableTokens(chain);
    } catch (error) {
      this.logger.error(`Error getting available tokens: ${error}`);
      return [];
    }
  }

  /**
   * Bridge tokens from one chain to another
   * @param params The token bridge parameters
   * @returns The transfer result
   */
  async bridgeTokens(params: TokenBridgeParams): Promise<any> {
    try {
      return await this.bridge.bridgeTokens(params);
    } catch (error) {
      this.logger.error(`Error bridging tokens: ${error}`);
      return {
        status: 'failed',
        message: `Error: ${error}`
      };
    }
  }

  /**
   * Check the status of a bridge transaction
   * @param sourceChain The source chain
   * @param transactionHash The transaction hash
   * @returns The transaction status
   */
  async checkTransactionStatus(sourceChain: string, transactionHash: string): Promise<any> {
    try {
      return await this.bridge.checkTransactionStatus(sourceChain, transactionHash);
    } catch (error) {
      this.logger.error(`Error checking transaction status: ${error}`);
      return {
        status: 'unknown',
        message: `Error: ${error}`
      };
    }
  }

  /**
   * Redeem tokens on the target chain
   * @param attestation The attestation (VAA) from the source chain
   * @param targetChain The target chain
   * @param privateKey The private key for the target chain
   * @returns The redeem result
   */
  async redeemTokens(attestation: string, targetChain: string, privateKey: string): Promise<any> {
    try {
      return await this.bridge.redeemTokens(attestation, targetChain, privateKey);
    } catch (error) {
      this.logger.error(`Error redeeming tokens: ${error}`);
      return {
        status: 'failed',
        message: `Error: ${error}`
      };
    }
  }

  /**
   * Get information about a wrapped token
   * @param originalChain The original chain of the token
   * @param originalAsset The original asset address
   * @param targetChain The target chain where the wrapped token exists
   * @returns Information about the wrapped token
   */
  async getWrappedAssetInfo(originalChain: string, originalAsset: string, targetChain: string): Promise<any> {
    try {
      return await this.bridge.getWrappedAssetInfo(originalChain, originalAsset, targetChain);
    } catch (error) {
      this.logger.error(`Error getting wrapped asset info: ${error}`);
      return {
        isNative: false,
        address: '',
        chainId: targetChain,
        decimals: 18,
        symbol: 'UNKNOWN',
        name: 'Unknown Token'
      };
    }
  }
}
