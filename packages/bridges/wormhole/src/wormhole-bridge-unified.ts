import {
  Chain,
  Network,
  TokenId,
  amount,
  toNative,
  wormhole,
  TokenBridge
} from '@wormhole-foundation/sdk';
import solana from '@wormhole-foundation/sdk/solana';
import evm from '@wormhole-foundation/sdk/evm';
import { ethers } from 'ethers';
import {
  Connection,
  PublicKey,
  Keypair
} from '@solana/web3.js';
import bs58 from 'bs58';
import {
  BridgeConfig,
  TokenBridgeParams,
  TransferResult,
  RedeemResult,
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
  private chainProviders: Map<string, any> = new Map();
  private tokenCache: Map<string, any> = new Map();

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
      
      // Initialize the Wormhole SDK
      const network = this.config.network === 'mainnet' ? 'Mainnet' : 'Testnet';
      this.wormholeInstance = await wormhole(network, [solana, evm]);
      
      // Initialize chain providers
      await this.initializeChainProviders();
      
      this.initialized = true;
      this.logger.info('Wormhole SDK initialized successfully');
    } catch (error) {
      this.logger.error(`Failed to initialize Wormhole SDK: ${error}`);
      throw error;
    }
  }

  /**
   * Initialize chain providers
   */
  private async initializeChainProviders(): Promise<void> {
    // Initialize EVM providers
    for (const chain of ['ethereum', 'bsc', 'avalanche', 'fantom', 'arbitrum', 'base']) {
      if (this.config.networks[chain]?.rpcUrl) {
        const provider = new ethers.JsonRpcProvider(this.config.networks[chain].rpcUrl);
        this.chainProviders.set(chain, provider);
      }
    }

    // Initialize Solana provider
    if (this.config.networks['solana']?.rpcUrl) {
      const connection = new Connection(this.config.networks['solana'].rpcUrl);
      this.chainProviders.set('solana', connection);
    }
  }

  /**
   * Get the Wormhole chain name for a chain
   * @param chain The chain name
   * @returns The Wormhole chain name
   */
  private getWormholeChain(chain: string): string {
    const chainMap: Record<string, string> = {
      'ethereum': 'Ethereum',
      'solana': 'Solana',
      'bsc': 'Bsc',
      'avalanche': 'Avalanche',
      'fantom': 'Fantom',
      'arbitrum': 'Arbitrum',
      'base': 'Base'
    };

    const wormholeChain = chainMap[chain];
    if (!wormholeChain) {
      throw new Error(`Unsupported chain: ${chain}`);
    }

    return wormholeChain;
  }

  /**
   * Create a signer for a chain
   * @param chain The chain name
   * @param privateKey The private key
   * @returns The signer
   */
  private async createSigner(chain: string, privateKey: string): Promise<any> {
    if (chain === 'solana') {
      // Create Solana signer
      const keypair = Keypair.fromSecretKey(bs58.decode(privateKey));
      return keypair;
    } else {
      // Create EVM signer
      const provider = this.chainProviders.get(chain);
      if (!provider) {
        throw new Error(`No provider available for chain: ${chain}`);
      }
      return new ethers.Wallet(privateKey, provider);
    }
  }

  /**
   * Get the available chains for bridging
   * @returns An array of available chains
   */
  public async getAvailableChains(): Promise<string[]> {
    await this.initialize();
    return Object.keys(this.config.networks).filter(chain => 
      this.config.networks[chain]?.enabled
    );
  }

  /**
   * Get the available tokens for a chain
   * @param chain The chain name
   * @returns An array of available tokens
   */
  public async getAvailableTokens(chain: string): Promise<any[]> {
    await this.initialize();
    
    // Get the chain configuration
    const chainConfig = this.config.networks[chain];
    if (!chainConfig || !chainConfig.enabled) {
      throw new Error(`Chain ${chain} is not enabled`);
    }

    // Get the chain's token list
    const tokenList = chainConfig.tokens || [];
    
    // Fetch additional token information
    const tokensWithInfo = await Promise.all(
      tokenList.map(async (token: any) => {
        try {
          // Get token info from chain
          let tokenInfo;
          if (chain === 'solana') {
            tokenInfo = await this.getSolanaTokenInfo(token.address);
          } else {
            tokenInfo = await this.getEVMTokenInfo(chain, token.address);
          }
          
          return {
            ...token,
            ...tokenInfo
          };
        } catch (error) {
          this.logger.error(`Error fetching token info for ${token.address} on ${chain}: ${error}`);
          return token;
        }
      })
    );
    
    return tokensWithInfo;
  }

  /**
   * Get token information for a Solana token
   * @param tokenAddress The token address
   * @returns The token information
   */
  private async getSolanaTokenInfo(tokenAddress: string): Promise<any> {
    // Cache key
    const cacheKey = `solana:${tokenAddress}`;
    if (this.tokenCache.has(cacheKey)) {
      return this.tokenCache.get(cacheKey);
    }
    
    try {
      const connection = this.chainProviders.get('solana') as Connection;
      const publicKey = new PublicKey(tokenAddress);
      
      // Get token info from Solana
      // In a real implementation, you would use the Token program to get token info
      // For now, we'll return placeholder data
      const tokenInfo = {
        decimals: 9,
        symbol: 'TOKEN',
        name: 'Unknown Token',
        logo: ''
      };
      
      // Cache the result
      this.tokenCache.set(cacheKey, tokenInfo);
      
      return tokenInfo;
    } catch (error) {
      this.logger.error(`Error getting Solana token info: ${error}`);
      return {
        decimals: 9,
        symbol: 'UNKNOWN',
        name: 'Unknown Token',
        logo: ''
      };
    }
  }

  /**
   * Get token information for an EVM token
   * @param chain The chain name
   * @param tokenAddress The token address
   * @returns The token information
   */
  private async getEVMTokenInfo(chain: string, tokenAddress: string): Promise<any> {
    // Cache key
    const cacheKey = `${chain}:${tokenAddress}`;
    if (this.tokenCache.has(cacheKey)) {
      return this.tokenCache.get(cacheKey);
    }
    
    try {
      const provider = this.chainProviders.get(chain);
      if (!provider) {
        throw new Error(`No provider available for chain: ${chain}`);
      }
      
      // ERC20 ABI for name, symbol, decimals
      const erc20Abi = [
        'function name() view returns (string)',
        'function symbol() view returns (string)',
        'function decimals() view returns (uint8)'
      ];
      
      const tokenContract = new ethers.Contract(tokenAddress, erc20Abi, provider);
      
      // Get token info
      const [name, symbol, decimals] = await Promise.all([
        tokenContract.name(),
        tokenContract.symbol(),
        tokenContract.decimals()
      ]);
      
      const tokenInfo = {
        decimals,
        symbol,
        name,
        logo: ''
      };
      
      // Cache the result
      this.tokenCache.set(cacheKey, tokenInfo);
      
      return tokenInfo;
    } catch (error) {
      this.logger.error(`Error getting EVM token info: ${error}`);
      return {
        decimals: 18,
        symbol: 'UNKNOWN',
        name: 'Unknown Token',
        logo: ''
      };
    }
  }

  /**
   * Bridge tokens from one chain to another
   * @param params The bridge parameters
   * @returns The transfer result
   */
  public async bridgeTokens(params: TokenBridgeParams): Promise<TransferResult> {
    const { sourceChain, targetChain, token, amount, recipient, privateKey, relayerFee = 0 } = params;
    
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
      
      // Get the token ID
      const tokenId = await this.getTokenId(sourceChain, token);
      
      // Create a token transfer
      const amountBigInt = BigInt(amount);
      const xfer = await this.wormholeInstance.tokenTransfer(
        tokenId,
        amountBigInt,
        sourceWormholeChain,
        targetWormholeChain,
        recipient,
        false // automatic
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
   * Get a token ID for the Wormhole SDK
   * @param chain The chain name
   * @param tokenAddress The token address
   * @returns The token ID
   */
  private async getTokenId(chain: string, tokenAddress: string): Promise<TokenId> {
    const wormholeChain = this.getWormholeChain(chain);
    const chainObj = this.wormholeInstance.getChain(wormholeChain);
    
    // Get the token ID
    return await chainObj.parseTokenId(tokenAddress);
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
      
      return {
        status: status.status,
        confirmations: status.confirmations,
        targetChain: status.targetChain,
        attestation: status.attestation
      };
    } catch (error) {
      this.logger.error(`Error checking transaction status: ${error}`);
      throw error;
    }
  }

  /**
   * Get information about a wrapped asset
   * @param sourceChain The source chain
   * @param sourceAsset The source asset address
   * @param targetChain The target chain
   * @returns Information about the wrapped asset
   */
  public async getWrappedAssetInfo(sourceChain: string, sourceAsset: string, targetChain: string): Promise<TokenInfo> {
    try {
      // Initialize Wormhole SDK if not already initialized
      await this.initialize();
      
      // Get Wormhole chain objects
      const sourceWormholeChain = this.getWormholeChain(sourceChain);
      const targetWormholeChain = this.getWormholeChain(targetChain);
      
      // Get chain objects
      const sourceChainObj = this.wormholeInstance.getChain(sourceWormholeChain);
      const targetChainObj = this.wormholeInstance.getChain(targetWormholeChain);
      
      // Get the token ID
      const tokenId = await sourceChainObj.parseTokenId(sourceAsset);
      
      // Get the token bridge module
      const tokenBridge = targetChainObj.getModule<TokenBridge>('TokenBridge');
      
      // Get the wrapped asset address
      const wrappedAddress = await tokenBridge.getWrappedAsset(tokenId);
      
      // Get token info
      let tokenInfo;
      if (targetChain === 'solana') {
        tokenInfo = await this.getSolanaTokenInfo(wrappedAddress);
      } else {
        tokenInfo = await this.getEVMTokenInfo(targetChain, wrappedAddress);
      }
      
      return {
        address: wrappedAddress,
        chainId: targetChain,
        decimals: tokenInfo.decimals,
        symbol: tokenInfo.symbol,
        name: tokenInfo.name,
        isNative: false
      };
    } catch (error) {
      this.logger.error(`Error getting wrapped asset info: ${error}`);
      throw error;
    }
  }
}

/**
 * Load the bridge configuration from environment variables
 * @returns The bridge configuration
 */
export function loadConfig(): BridgeConfig {
  // Load configuration from environment variables
  const config: BridgeConfig = {
    network: process.env.WORMHOLE_NETWORK || 'mainnet',
    networks: {}
  };
  
  // Configure Ethereum
  if (process.env.ETHEREUM_RPC_URL) {
    config.networks.ethereum = {
      rpcUrl: process.env.ETHEREUM_RPC_URL,
      enabled: true,
      tokens: []
    };
  }
  
  // Configure Solana
  if (process.env.SOLANA_RPC_URL) {
    config.networks.solana = {
      rpcUrl: process.env.SOLANA_RPC_URL,
      enabled: true,
      tokens: []
    };
  }
  
  // Configure BSC
  if (process.env.BSC_RPC_URL) {
    config.networks.bsc = {
      rpcUrl: process.env.BSC_RPC_URL,
      enabled: true,
      tokens: []
    };
  }
  
  // Configure Avalanche
  if (process.env.AVALANCHE_RPC_URL) {
    config.networks.avalanche = {
      rpcUrl: process.env.AVALANCHE_RPC_URL,
      enabled: true,
      tokens: []
    };
  }
  
  // Configure Fantom
  if (process.env.FANTOM_RPC_URL) {
    config.networks.fantom = {
      rpcUrl: process.env.FANTOM_RPC_URL,
      enabled: true,
      tokens: []
    };
  }
  
  // Configure Arbitrum
  if (process.env.ARBITRUM_RPC_URL) {
    config.networks.arbitrum = {
      rpcUrl: process.env.ARBITRUM_RPC_URL,
      enabled: true,
      tokens: []
    };
  }
  
  // Configure Base
  if (process.env.BASE_RPC_URL) {
    config.networks.base = {
      rpcUrl: process.env.BASE_RPC_URL,
      enabled: true,
      tokens: []
    };
  }
  
  return config;
}
