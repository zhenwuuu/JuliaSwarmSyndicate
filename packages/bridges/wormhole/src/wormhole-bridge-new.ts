import {
  Chain,
  Network,
  TokenId,
  amount,
  toNative,
  wormhole
} from '@wormhole-foundation/sdk';
import solana from '@wormhole-foundation/sdk/solana';
import evm from '@wormhole-foundation/sdk/evm';
import { ethers } from 'ethers';
import {
  Connection,
  PublicKey,
  Keypair,
  Transaction,
  sendAndConfirmTransaction
} from '@solana/web3.js';
import bs58 from 'bs58';
import {
  BridgeConfig,
  TokenBridgeParams,
  TransferResult,
  RedeemResult,
  WormholeMessage,
  TokenInfo
} from './types';
import { Logger } from './utils/logger';

/**
 * WormholeBridge class for cross-chain token transfers using the Wormhole protocol.
 * This implementation uses the latest Wormhole SDK (@wormhole-foundation/sdk).
 */
export class WormholeBridge {
  private config: BridgeConfig;
  private logger: Logger;
  private wormholeInstance: any;
  private initialized: boolean = false;

  /**
   * Create a new WormholeBridge instance
   * @param config The bridge configuration
   */
  constructor(config: BridgeConfig) {
    this.config = config;
    this.logger = new Logger('WormholeBridge');
  }

  /**
   * Initialize the Wormhole SDK
   * This is done lazily to avoid unnecessary initialization
   */
  private async initialize(): Promise<void> {
    if (this.initialized) return;

    try {
      this.logger.info('Initializing Wormhole SDK');
      this.wormholeInstance = await wormhole('Mainnet', [solana, evm]);
      this.initialized = true;
      this.logger.info('Wormhole SDK initialized successfully');
    } catch (error) {
      this.logger.error(`Failed to initialize Wormhole SDK: ${error}`);
      throw error;
    }
  }

  /**
   * Get the Wormhole chain name for a given chain
   * @param chainName The chain name in JuliaOS format
   * @returns The chain name in Wormhole format
   */
  private getWormholeChain(chainName: string): Chain {
    const chainMap: Record<string, Chain> = {
      'ethereum': 'Ethereum' as Chain,
      'solana': 'Solana' as Chain,
      'bsc': 'Bsc' as Chain,
      'avalanche': 'Avalanche' as Chain,
      'fantom': 'Fantom' as Chain,
      'arbitrum': 'Arbitrum' as Chain,
      'base': 'Base' as Chain
    };

    const wormholeChain = chainMap[chainName.toLowerCase()];
    if (!wormholeChain) {
      throw new Error(`Unsupported chain: ${chainName}`);
    }

    return wormholeChain;
  }

  /**
   * Create a signer for a given chain
   * @param chainName The chain name
   * @param privateKey The private key
   * @returns A signer object for the chain
   */
  private async createSigner(chainName: string, privateKey: string): Promise<any> {
    const chain = this.getWormholeChain(chainName);

    if (chain === 'Solana' as Chain) {
      // Parse Solana private key
      let solanaPrivateKey: Uint8Array;
      
      try {
        // Try to parse as JSON array
        solanaPrivateKey = Buffer.from(JSON.parse(privateKey));
      } catch (e) {
        try {
          // Try to parse as base58 encoded string
          solanaPrivateKey = bs58.decode(privateKey);
        } catch (e2) {
          try {
            // Try to parse as hex string
            solanaPrivateKey = Buffer.from(privateKey, 'hex');
          } catch (e3) {
            throw new Error('Invalid Solana private key format');
          }
        }
      }

      const solanaWallet = Keypair.fromSecretKey(solanaPrivateKey);
      
      return {
        signTransaction: async (tx: any) => {
          tx.partialSign(solanaWallet);
          return tx;
        },
        publicKey: solanaWallet.publicKey,
      };
    } else {
      // EVM chain
      const provider = new ethers.JsonRpcProvider(this.config.networks[chainName].rpcUrl);
      const wallet = new ethers.Wallet(privateKey, provider);
      
      return {
        signTransaction: async (tx: any) => {
          return await wallet.signTransaction(tx);
        },
        address: wallet.address,
      };
    }
  }

  /**
   * Bridge tokens from one chain to another
   * @param params The token bridge parameters
   * @returns The transfer result
   */
  public async bridgeTokens(params: TokenBridgeParams): Promise<TransferResult> {
    const { sourceChain, targetChain, token, amount, recipient, relayerFee = 0, privateKey } = params;
    
    this.logger.info(`Bridging ${amount} of token ${token} from ${sourceChain} to ${targetChain}`);
    
    try {
      // Initialize Wormhole SDK if not already initialized
      await this.initialize();
      
      // Get Wormhole chain objects
      const sourceWormholeChain = this.getWormholeChain(sourceChain);
      const targetWormholeChain = this.getWormholeChain(targetChain);
      
      // Create a signer for the source chain
      if (!privateKey) {
        throw new Error('Private key is required for bridging tokens');
      }
      
      const signer = await this.createSigner(sourceChain, privateKey);
      
      // Create a token ID
      const tokenId = TokenId.fromChainAddress(
        sourceWormholeChain,
        token
      );
      
      // Create a token transfer
      const xfer = await this.wormholeInstance.tokenTransfer(
        tokenId,
        BigInt(amount.toString()),
        { chain: sourceWormholeChain, address: sourceChain === 'solana' ? signer.publicKey.toString() : signer.address },
        { chain: targetWormholeChain, address: recipient },
        false // manual transfer (not automatic)
      );
      
      // Get a quote for the transfer
      const quote = await xfer.getQuote();
      this.logger.info(`Transfer quote: ${JSON.stringify(quote)}`);
      
      // Initiate the transfer
      const srcTxids = await xfer.initiateTransfer(signer);
      this.logger.info(`Transfer initiated: ${JSON.stringify(srcTxids)}`);
      
      // Wait for the attestation (VAA)
      this.logger.info('Waiting for attestation (VAA)...');
      const attestIds = await xfer.fetchAttestation(60000); // 60 seconds timeout
      this.logger.info(`Attestation received: ${JSON.stringify(attestIds)}`);
      
      return {
        transactionHash: srcTxids[0],
        amount: amount.toString(),
        fee: relayerFee.toString(),
        sourceChain,
        targetChain,
        token,
        recipient,
        status: 'pending',
        attestation: attestIds[0]
      };
    } catch (error) {
      this.logger.error(`Error bridging tokens: ${error}`);
      return {
        transactionHash: '',
        amount: amount.toString(),
        fee: relayerFee.toString(),
        sourceChain,
        targetChain,
        token,
        recipient,
        status: 'failed',
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
  public async redeemTokens(attestation: string, targetChain: string, privateKey: string): Promise<RedeemResult> {
    this.logger.info(`Redeeming tokens on ${targetChain}`);
    
    try {
      // Initialize Wormhole SDK if not already initialized
      await this.initialize();
      
      // Get Wormhole chain object
      const targetWormholeChain = this.getWormholeChain(targetChain);
      
      // Create a signer for the target chain
      const signer = await this.createSigner(targetChain, privateKey);
      
      // Get the transfer from the attestation
      const xfer = await this.wormholeInstance.parseAttestation(attestation);
      
      // Complete the transfer
      const dstTxids = await xfer.completeTransfer(signer);
      this.logger.info(`Transfer completed: ${JSON.stringify(dstTxids)}`);
      
      return {
        transactionHash: dstTxids[0],
        status: 'completed'
      };
    } catch (error) {
      this.logger.error(`Error redeeming tokens: ${error}`);
      return {
        transactionHash: '',
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
  public async getWrappedAssetInfo(
    originalChain: string,
    originalAsset: string,
    targetChain: string
  ): Promise<TokenInfo> {
    try {
      // Initialize Wormhole SDK if not already initialized
      await this.initialize();
      
      // Get Wormhole chain objects
      const originalWormholeChain = this.getWormholeChain(originalChain);
      const targetWormholeChain = this.getWormholeChain(targetChain);
      
      // Create a token ID
      const tokenId = TokenId.fromChainAddress(
        originalWormholeChain,
        originalAsset
      );
      
      // Get the target chain object
      const targetChainObj = this.wormholeInstance.getChain(targetWormholeChain);
      
      // Get the token bridge
      const tokenBridge = targetChainObj.getTokenBridge();
      
      // Get the wrapped asset
      const wrappedAsset = await tokenBridge.getWrappedAsset(tokenId);
      
      // Get token info
      let decimals = 18;
      let symbol = 'WRAPPED';
      let name = 'Wrapped Asset';
      
      try {
        if (targetChain !== 'solana') {
          // For EVM chains, we can get token info from the contract
          const provider = new ethers.JsonRpcProvider(this.config.networks[targetChain].rpcUrl);
          const tokenContract = new ethers.Contract(
            wrappedAsset,
            [
              'function decimals() view returns (uint8)',
              'function symbol() view returns (string)',
              'function name() view returns (string)'
            ],
            provider
          );
          
          decimals = await tokenContract.decimals();
          symbol = await tokenContract.symbol();
          name = await tokenContract.name();
        } else {
          // For Solana, we would need to use the SPL token program
          // This is a simplified implementation
          decimals = 9;
          symbol = `w${tokenId.chain}`;
          name = `Wrapped ${tokenId.chain} Asset`;
        }
      } catch (error) {
        this.logger.warn(`Failed to get token info: ${error}`);
      }
      
      return {
        address: wrappedAsset,
        chainId: this.config.networks[targetChain].wormholeChainId,
        decimals,
        symbol,
        name,
        isNative: false
      };
    } catch (error) {
      this.logger.error(`Error getting wrapped asset info: ${error}`);
      throw error;
    }
  }

  /**
   * Check the status of a bridge transaction
   * @param sourceChain The source chain
   * @param transactionHash The transaction hash
   * @returns The transaction status
   */
  public async checkTransactionStatus(sourceChain: string, transactionHash: string): Promise<any> {
    try {
      // Initialize Wormhole SDK if not already initialized
      await this.initialize();
      
      // Get Wormhole chain object
      const sourceWormholeChain = this.getWormholeChain(sourceChain);
      
      // Get the source chain object
      const sourceChainObj = this.wormholeInstance.getChain(sourceWormholeChain);
      
      // Check transaction status
      const status = await sourceChainObj.getTransactionStatus(transactionHash);
      
      return status;
    } catch (error) {
      this.logger.error(`Error checking transaction status: ${error}`);
      throw error;
    }
  }

  /**
   * Get the available chains for bridging
   * @returns An array of available chains
   */
  public getAvailableChains(): string[] {
    return Object.keys(this.config.networks);
  }

  /**
   * Get the available tokens for a chain
   * @param chainName The chain name
   * @returns An array of available tokens
   */
  public async getAvailableTokens(chainName: string): Promise<TokenInfo[]> {
    try {
      // Initialize Wormhole SDK if not already initialized
      await this.initialize();
      
      // Get Wormhole chain object
      const wormholeChain = this.getWormholeChain(chainName);
      
      // Get the chain object
      const chainObj = this.wormholeInstance.getChain(wormholeChain);
      
      // Get the token bridge
      const tokenBridge = chainObj.getTokenBridge();
      
      // Get the available tokens
      // This is a simplified implementation
      // In a real implementation, you would query the token bridge for all registered tokens
      return [
        {
          address: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', // USDC on Ethereum
          chainId: this.config.networks[chainName].wormholeChainId,
          decimals: 6,
          symbol: 'USDC',
          name: 'USD Coin',
          isNative: false
        },
        {
          address: '0xdAC17F958D2ee523a2206206994597C13D831ec7', // USDT on Ethereum
          chainId: this.config.networks[chainName].wormholeChainId,
          decimals: 6,
          symbol: 'USDT',
          name: 'Tether USD',
          isNative: false
        }
      ];
    } catch (error) {
      this.logger.error(`Error getting available tokens: ${error}`);
      throw error;
    }
  }
}
