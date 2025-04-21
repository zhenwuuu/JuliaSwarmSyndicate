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

      // Handle native SOL
      if (tokenAddress === 'native' || tokenAddress.toLowerCase() === 'sol') {
        const tokenInfo = {
          decimals: 9,
          symbol: 'SOL',
          name: 'Solana',
          logo: ''
        };
        this.tokenCache.set(cacheKey, tokenInfo);
        return tokenInfo;
      }

      const publicKey = new PublicKey(tokenAddress);

      // Get token account info
      const accountInfo = await connection.getAccountInfo(publicKey);
      if (!accountInfo) {
        throw new Error(`Token account not found: ${tokenAddress}`);
      }

      // Get token mint info
      // In a production environment, you would use the Token program to get token info
      // For SPL tokens, we need to use the Token program to get decimals, symbol, and name
      // This requires the @solana/spl-token package

      // For now, we'll use a more robust approach with known tokens
      const knownTokens: Record<string, any> = {
        'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v': { symbol: 'USDC', name: 'USD Coin', decimals: 6 },
        'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB': { symbol: 'USDT', name: 'Tether USD', decimals: 6 },
        'So11111111111111111111111111111111111111112': { symbol: 'WSOL', name: 'Wrapped SOL', decimals: 9 },
        'mSoLzYCxHdYgdzU16g5QSh3i5K3z3KZK7ytfqcJm7So': { symbol: 'mSOL', name: 'Marinade staked SOL', decimals: 9 },
        'DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263': { symbol: 'BONK', name: 'Bonk', decimals: 5 }
      };

      let tokenInfo;
      if (knownTokens[tokenAddress]) {
        tokenInfo = knownTokens[tokenAddress];
      } else {
        // For unknown tokens, try to fetch metadata or use default values
        try {
          // In a real implementation, you would fetch token metadata from the chain
          // For now, we'll use default values with a warning
          this.logger.warn(`Unknown token: ${tokenAddress}, using default values`);
          tokenInfo = {
            decimals: 9, // Most Solana tokens use 9 decimals
            symbol: tokenAddress.substring(0, 5),
            name: `Token ${tokenAddress.substring(0, 8)}`,
            logo: ''
          };
        } catch (metadataError) {
          this.logger.error(`Error fetching token metadata: ${metadataError}`);
          tokenInfo = {
            decimals: 9,
            symbol: 'UNKNOWN',
            name: 'Unknown Token',
            logo: ''
          };
        }
      }

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
      // Validate parameters
      if (!sourceChain) throw new Error('Source chain is required');
      if (!targetChain) throw new Error('Target chain is required');
      if (!token) throw new Error('Token address is required');
      if (!amount) throw new Error('Amount is required');
      if (!recipient) throw new Error('Recipient address is required');
      if (!privateKey) throw new Error('Private key is required for bridging tokens');

      // Check if chains are supported
      const availableChains = await this.getAvailableChains();
      if (!availableChains.includes(sourceChain)) {
        throw new Error(`Source chain ${sourceChain} is not supported. Supported chains: ${availableChains.join(', ')}`);
      }
      if (!availableChains.includes(targetChain)) {
        throw new Error(`Target chain ${targetChain} is not supported. Supported chains: ${availableChains.join(', ')}`);
      }

      // Initialize Wormhole SDK if not already initialized
      await this.initialize();

      // Get Wormhole chain objects
      const sourceWormholeChain = this.getWormholeChain(sourceChain);
      const targetWormholeChain = this.getWormholeChain(targetChain);

      // Create a signer for the source chain
      let signer;
      try {
        signer = await this.createSigner(sourceChain, privateKey);
      } catch (signerError) {
        this.logger.error(`Error creating signer: ${signerError}`);
        throw new Error(`Failed to create signer for ${sourceChain}: ${signerError.message}`);
      }

      // Get the token ID
      let tokenId;
      try {
        tokenId = await this.getTokenId(sourceChain, token);
      } catch (tokenError) {
        this.logger.error(`Error getting token ID: ${tokenError}`);
        throw new Error(`Failed to get token ID for ${token} on ${sourceChain}: ${tokenError.message}`);
      }

      // Create a token transfer
      let amountBigInt;
      try {
        amountBigInt = BigInt(amount);
      } catch (amountError) {
        throw new Error(`Invalid amount: ${amount}. Amount must be a valid number.`);
      }

      let xfer;
      try {
        xfer = await this.wormholeInstance.tokenTransfer(
          tokenId,
          amountBigInt,
          sourceWormholeChain,
          targetWormholeChain,
          recipient,
          false // automatic
        );
      } catch (transferError) {
        this.logger.error(`Error creating token transfer: ${transferError}`);
        throw new Error(`Failed to create token transfer: ${transferError.message}`);
      }

      // Get a quote for the transfer
      let quote;
      try {
        quote = await xfer.getQuote();
        this.logger.info(`Transfer quote: ${JSON.stringify(quote)}`);
      } catch (quoteError) {
        this.logger.error(`Error getting transfer quote: ${quoteError}`);
        // Continue even if quote fails
      }

      // Initiate the transfer
      let srcTxids;
      try {
        srcTxids = await xfer.initiateTransfer(signer);
        this.logger.info(`Transfer initiated: ${JSON.stringify(srcTxids)}`);
      } catch (initiateError) {
        this.logger.error(`Error initiating transfer: ${initiateError}`);
        throw new Error(`Failed to initiate transfer: ${initiateError.message}`);
      }

      // Wait for the attestation (VAA)
      let attestIds;
      try {
        this.logger.info('Waiting for attestation (VAA)...');
        attestIds = await xfer.fetchAttestation(60000); // 60 seconds timeout
        this.logger.info(`Attestation received: ${JSON.stringify(attestIds)}`);
      } catch (attestationError) {
        this.logger.error(`Error fetching attestation: ${attestationError}`);
        // Return partial success even if attestation fails
        return {
          transactionHash: srcTxids[0],
          amount: amount.toString(),
          fee: relayerFee.toString(),
          sourceChain,
          targetChain,
          token,
          recipient,
          status: 'pending_attestation',
          message: `Transaction submitted, but attestation not yet available: ${attestationError.message}`
        };
      }

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
        amount: amount ? amount.toString() : '0',
        fee: relayerFee.toString(),
        sourceChain: sourceChain || '',
        targetChain: targetChain || '',
        token: token || '',
        recipient: recipient || '',
        status: 'failed',
        message: `Error: ${error.message || error}`
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
      // Validate parameters
      if (!attestation) throw new Error('Attestation (VAA) is required');
      if (!targetChain) throw new Error('Target chain is required');
      if (!privateKey) throw new Error('Private key is required for redeeming tokens');

      // Check if chain is supported
      const availableChains = await this.getAvailableChains();
      if (!availableChains.includes(targetChain)) {
        throw new Error(`Target chain ${targetChain} is not supported. Supported chains: ${availableChains.join(', ')}`);
      }

      // Initialize Wormhole SDK if not already initialized
      await this.initialize();

      // Create a signer for the target chain
      let signer;
      try {
        signer = await this.createSigner(targetChain, privateKey);
      } catch (signerError) {
        this.logger.error(`Error creating signer: ${signerError}`);
        throw new Error(`Failed to create signer for ${targetChain}: ${signerError.message}`);
      }

      // Get the transfer from the attestation
      let xfer;
      try {
        xfer = await this.wormholeInstance.parseAttestation(attestation);
      } catch (parseError) {
        this.logger.error(`Error parsing attestation: ${parseError}`);
        throw new Error(`Failed to parse attestation: ${parseError.message}`);
      }

      // Complete the transfer
      let dstTxids;
      try {
        dstTxids = await xfer.completeTransfer(signer);
        this.logger.info(`Transfer completed: ${JSON.stringify(dstTxids)}`);
      } catch (completeError) {
        this.logger.error(`Error completing transfer: ${completeError}`);

        // Check if the error is due to the transfer already being completed
        if (completeError.message && completeError.message.includes('already claimed')) {
          return {
            transactionHash: '',
            status: 'already_completed',
            message: 'This transfer has already been completed.'
          };
        }

        throw new Error(`Failed to complete transfer: ${completeError.message}`);
      }

      return {
        transactionHash: dstTxids[0],
        status: 'completed'
      };
    } catch (error) {
      this.logger.error(`Error redeeming tokens: ${error}`);
      return {
        transactionHash: '',
        status: 'failed',
        message: `Error: ${error.message || error}`
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
      // Validate parameters
      if (!sourceChain) throw new Error('Source chain is required');
      if (!transactionHash) throw new Error('Transaction hash is required');

      // Check if chain is supported
      const availableChains = await this.getAvailableChains();
      if (!availableChains.includes(sourceChain)) {
        throw new Error(`Source chain ${sourceChain} is not supported. Supported chains: ${availableChains.join(', ')}`);
      }

      // Initialize Wormhole SDK if not already initialized
      await this.initialize();

      // Get Wormhole chain object
      let sourceWormholeChain;
      try {
        sourceWormholeChain = this.getWormholeChain(sourceChain);
      } catch (chainError) {
        this.logger.error(`Error getting Wormhole chain: ${chainError}`);
        throw new Error(`Failed to get Wormhole chain for ${sourceChain}: ${chainError.message}`);
      }

      // Get the source chain object
      let sourceChainObj;
      try {
        sourceChainObj = this.wormholeInstance.getChain(sourceWormholeChain);
      } catch (chainObjError) {
        this.logger.error(`Error getting chain object: ${chainObjError}`);
        throw new Error(`Failed to get chain object for ${sourceChain}: ${chainObjError.message}`);
      }

      // Check transaction status
      let status;
      try {
        status = await sourceChainObj.getTransactionStatus(transactionHash);
      } catch (statusError) {
        this.logger.error(`Error getting transaction status: ${statusError}`);

        // Check if the error is due to the transaction not being found
        if (statusError.message && statusError.message.includes('not found')) {
          return {
            status: 'not_found',
            message: `Transaction ${transactionHash} not found on ${sourceChain}.`
          };
        }

        throw new Error(`Failed to get transaction status: ${statusError.message}`);
      }

      // Return the status with additional information
      return {
        status: status.status || 'unknown',
        confirmations: status.confirmations || 0,
        targetChain: status.targetChain || '',
        attestation: status.attestation || '',
        sourceChain: sourceChain,
        transactionHash: transactionHash,
        timestamp: new Date().toISOString()
      };
    } catch (error) {
      this.logger.error(`Error checking transaction status: ${error}`);

      // Return a structured error response instead of throwing
      return {
        status: 'error',
        sourceChain: sourceChain || '',
        transactionHash: transactionHash || '',
        message: `Error: ${error.message || error}`,
        timestamp: new Date().toISOString()
      };
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
      // Validate parameters
      if (!sourceChain) throw new Error('Source chain is required');
      if (!sourceAsset) throw new Error('Source asset address is required');
      if (!targetChain) throw new Error('Target chain is required');

      // Check if chains are supported
      const availableChains = await this.getAvailableChains();
      if (!availableChains.includes(sourceChain)) {
        throw new Error(`Source chain ${sourceChain} is not supported. Supported chains: ${availableChains.join(', ')}`);
      }
      if (!availableChains.includes(targetChain)) {
        throw new Error(`Target chain ${targetChain} is not supported. Supported chains: ${availableChains.join(', ')}`);
      }

      // Initialize Wormhole SDK if not already initialized
      await this.initialize();

      // Get Wormhole chain objects
      let sourceWormholeChain, targetWormholeChain;
      try {
        sourceWormholeChain = this.getWormholeChain(sourceChain);
        targetWormholeChain = this.getWormholeChain(targetChain);
      } catch (chainError) {
        this.logger.error(`Error getting Wormhole chain: ${chainError}`);
        throw new Error(`Failed to get Wormhole chain: ${chainError.message}`);
      }

      // Get chain objects
      let sourceChainObj, targetChainObj;
      try {
        sourceChainObj = this.wormholeInstance.getChain(sourceWormholeChain);
        targetChainObj = this.wormholeInstance.getChain(targetWormholeChain);
      } catch (chainObjError) {
        this.logger.error(`Error getting chain object: ${chainObjError}`);
        throw new Error(`Failed to get chain object: ${chainObjError.message}`);
      }

      // Get the token ID
      let tokenId;
      try {
        tokenId = await sourceChainObj.parseTokenId(sourceAsset);
      } catch (tokenError) {
        this.logger.error(`Error parsing token ID: ${tokenError}`);
        throw new Error(`Failed to parse token ID for ${sourceAsset} on ${sourceChain}: ${tokenError.message}`);
      }

      // Get the token bridge module
      let tokenBridge;
      try {
        tokenBridge = targetChainObj.getModule<TokenBridge>('TokenBridge');
      } catch (moduleError) {
        this.logger.error(`Error getting token bridge module: ${moduleError}`);
        throw new Error(`Failed to get token bridge module for ${targetChain}: ${moduleError.message}`);
      }

      // Get the wrapped asset address
      let wrappedAddress;
      try {
        wrappedAddress = await tokenBridge.getWrappedAsset(tokenId);
      } catch (wrappedError) {
        this.logger.error(`Error getting wrapped asset address: ${wrappedError}`);
        throw new Error(`Failed to get wrapped asset address for ${sourceAsset} on ${targetChain}: ${wrappedError.message}`);
      }

      // Get token info
      let tokenInfo;
      try {
        if (targetChain === 'solana') {
          tokenInfo = await this.getSolanaTokenInfo(wrappedAddress);
        } else {
          tokenInfo = await this.getEVMTokenInfo(targetChain, wrappedAddress);
        }
      } catch (infoError) {
        this.logger.error(`Error getting token info: ${infoError}`);
        // Use default values if token info retrieval fails
        tokenInfo = {
          decimals: targetChain === 'solana' ? 9 : 18,
          symbol: 'WRAPPED',
          name: `Wrapped ${sourceAsset.substring(0, 8)}`,
          logo: ''
        };
      }

      return {
        address: wrappedAddress,
        chainId: targetChain,
        decimals: tokenInfo.decimals,
        symbol: tokenInfo.symbol,
        name: tokenInfo.name,
        isNative: false,
        originalChain: sourceChain,
        originalAsset: sourceAsset
      };
    } catch (error) {
      this.logger.error(`Error getting wrapped asset info: ${error}`);

      // Return a default token info object with error information
      return {
        address: '',
        chainId: targetChain || '',
        decimals: 18,
        symbol: 'ERROR',
        name: 'Error Token',
        isNative: false,
        originalChain: sourceChain || '',
        originalAsset: sourceAsset || '',
        error: error.message || String(error)
      };
    }
  }
}

/**
 * Load the bridge configuration from environment variables or use defaults
 * @param customConfig Optional custom configuration to override defaults
 * @returns The bridge configuration
 */
export function loadConfig(customConfig?: Partial<BridgeConfig>): BridgeConfig {
  // Default RPC endpoints for testnet
  const defaultTestnetRpcUrls: Record<string, string> = {
    ethereum: 'https://goerli.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161', // Goerli testnet
    solana: 'https://api.devnet.solana.com', // Solana devnet
    bsc: 'https://data-seed-prebsc-1-s1.binance.org:8545', // BSC testnet
    avalanche: 'https://api.avax-test.network/ext/bc/C/rpc', // Avalanche testnet
    fantom: 'https://rpc.testnet.fantom.network', // Fantom testnet
    arbitrum: 'https://goerli-rollup.arbitrum.io/rpc', // Arbitrum testnet
    base: 'https://goerli.base.org' // Base testnet
  };

  // Default RPC endpoints for mainnet
  const defaultMainnetRpcUrls: Record<string, string> = {
    ethereum: 'https://mainnet.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161', // Ethereum mainnet
    solana: 'https://api.mainnet-beta.solana.com', // Solana mainnet
    bsc: 'https://bsc-dataseed.binance.org', // BSC mainnet
    avalanche: 'https://api.avax.network/ext/bc/C/rpc', // Avalanche mainnet
    fantom: 'https://rpcapi.fantom.network', // Fantom mainnet
    arbitrum: 'https://arb1.arbitrum.io/rpc', // Arbitrum mainnet
    base: 'https://mainnet.base.org' // Base mainnet
  };

  // Default tokens for testnet
  const defaultTestnetTokens: Record<string, any[]> = {
    ethereum: [
      { address: '0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6', symbol: 'WETH', name: 'Wrapped Ether', decimals: 18 },
      { address: '0x07865c6e87b9f70255377e024ace6630c1eaa37f', symbol: 'USDC', name: 'USD Coin', decimals: 6 }
    ],
    solana: [
      { address: 'native', symbol: 'SOL', name: 'Solana', decimals: 9 },
      { address: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v', symbol: 'USDC', name: 'USD Coin', decimals: 6 }
    ],
    bsc: [
      { address: '0xae13d989dac2f0debff460ac112a837c89baa7cd', symbol: 'WBNB', name: 'Wrapped BNB', decimals: 18 }
    ],
    avalanche: [
      { address: '0xd00ae08403b9bbb9124bb305c09058e32c39a48c', symbol: 'WAVAX', name: 'Wrapped AVAX', decimals: 18 }
    ]
  };

  // Default tokens for mainnet
  const defaultMainnetTokens: Record<string, any[]> = {
    ethereum: [
      { address: '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2', symbol: 'WETH', name: 'Wrapped Ether', decimals: 18 },
      { address: '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48', symbol: 'USDC', name: 'USD Coin', decimals: 6 },
      { address: '0xdac17f958d2ee523a2206206994597c13d831ec7', symbol: 'USDT', name: 'Tether USD', decimals: 6 }
    ],
    solana: [
      { address: 'native', symbol: 'SOL', name: 'Solana', decimals: 9 },
      { address: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v', symbol: 'USDC', name: 'USD Coin', decimals: 6 },
      { address: 'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB', symbol: 'USDT', name: 'Tether USD', decimals: 6 }
    ],
    bsc: [
      { address: '0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c', symbol: 'WBNB', name: 'Wrapped BNB', decimals: 18 },
      { address: '0x55d398326f99059ff775485246999027b3197955', symbol: 'USDT', name: 'Tether USD', decimals: 18 }
    ],
    avalanche: [
      { address: '0xb31f66aa3c1e785363f0875a1b74e27b85fd66c7', symbol: 'WAVAX', name: 'Wrapped AVAX', decimals: 18 },
      { address: '0xa7d7079b0fead91f3e65f86e8915cb59c1a4c664', symbol: 'USDC.e', name: 'USD Coin', decimals: 6 }
    ]
  };

  // Determine network from environment or custom config
  const networkType = customConfig?.network || process.env.WORMHOLE_NETWORK || 'testnet';
  const isMainnet = networkType.toLowerCase() === 'mainnet';

  // Select default RPC URLs and tokens based on network type
  const defaultRpcUrls = isMainnet ? defaultMainnetRpcUrls : defaultTestnetRpcUrls;
  const defaultTokens = isMainnet ? defaultMainnetTokens : defaultTestnetTokens;

  // Initialize config with network type
  const config: BridgeConfig = {
    network: isMainnet ? 'mainnet' : 'testnet',
    networks: {}
  };

  // Configure networks
  const networks = ['ethereum', 'solana', 'bsc', 'avalanche', 'fantom', 'arbitrum', 'base'];

  for (const network of networks) {
    // Get RPC URL from environment, custom config, or default
    const envRpcUrl = process.env[`${network.toUpperCase()}_RPC_URL`];
    const customRpcUrl = customConfig?.networks?.[network]?.rpcUrl;
    const defaultRpcUrl = defaultRpcUrls[network];

    const rpcUrl = customRpcUrl || envRpcUrl || defaultRpcUrl;

    if (rpcUrl) {
      // Get tokens from custom config or default
      const customTokens = customConfig?.networks?.[network]?.tokens || [];
      const envTokensEnabled = process.env[`${network.toUpperCase()}_TOKENS_ENABLED`] === 'true';

      config.networks[network] = {
        rpcUrl,
        enabled: customConfig?.networks?.[network]?.enabled ?? true,
        tokens: customTokens.length > 0 ? customTokens : (envTokensEnabled ? defaultTokens[network] || [] : [])
      };
    }
  }

  // Apply any additional custom configuration
  if (customConfig) {
    // Merge custom networks with default networks
    if (customConfig.networks) {
      for (const [network, networkConfig] of Object.entries(customConfig.networks)) {
        if (config.networks[network]) {
          // Merge with existing network config
          config.networks[network] = {
            ...config.networks[network],
            ...networkConfig,
            // Merge tokens if both exist
            tokens: [
              ...(config.networks[network].tokens || []),
              ...(networkConfig.tokens || [])
            ]
          };
        } else {
          // Add new network config
          config.networks[network] = networkConfig;
        }
      }
    }
  }

  return config;
}
