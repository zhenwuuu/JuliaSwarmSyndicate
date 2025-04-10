import { Logger } from './utils/logger';
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
  Keypair
} from '@solana/web3.js';
import bs58 from 'bs58';
import { TokenInfo } from './types';

// Chain ID mapping
const CHAIN_ID_MAP: Record<string, number> = {
  'ethereum': 1,
  'solana': 1399811149,
  'bsc': 56,
  'avalanche': 43114,
  'fantom': 250,
  'arbitrum': 42161,
  'base': 8453
};

// RPC endpoints
const RPC_ENDPOINTS: Record<string, string> = {
  'ethereum': process.env.ETH_RPC_URL || 'https://eth-mainnet.g.alchemy.com/v2/your-api-key',
  'solana': process.env.SOLANA_RPC_URL || 'https://api.mainnet-beta.solana.com',
  'bsc': process.env.BSC_RPC_URL || 'https://bsc-dataseed.binance.org',
  'avalanche': process.env.AVAX_RPC_URL || 'https://api.avax.network/ext/bc/C/rpc',
  'fantom': process.env.FANTOM_RPC_URL || 'https://rpcapi.fantom.network',
  'arbitrum': process.env.ARBITRUM_RPC_URL || 'https://arb1.arbitrum.io/rpc',
  'base': process.env.BASE_RPC_URL || 'https://mainnet.base.org'
};

// Token Bridge addresses
const TOKEN_BRIDGE_ADDRESSES: Record<string, string> = {
  'ethereum': '0x3ee18B2214AFF97000D974cf647E7C347E8fa585',
  'solana': 'wormDTUJ6AWPNvk59vGQbDvGJmqbDTdgWgAqcLBCgUb',
  'bsc': '0xB6F6D86a8f9879A9c87f643768d9efc38c1Da6E7',
  'avalanche': '0x0e082F06FF657D94310cB8cE8B0D9a04541d8052',
  'fantom': '0x7C9Fc5741288cDFdD83CeB07f3ea7e22618D79D2',
  'arbitrum': '0x0b2402144Bb366A632D14B83F244D2e0e21bD39c',
  'base': '0x8d2de8d2f73F1F4cAB472AC9A881C9b123C79627'
};

// Wormhole Bridge addresses
const WORMHOLE_BRIDGE_ADDRESSES: Record<string, string> = {
  'ethereum': '0x98f3c9e6E3fAce36bAAd05FE09d375Ef1464288B',
  'solana': 'worm2ZoG2kUd4vFXhvjh93UUH596ayRfgQ2MgjNMTth',
  'bsc': '0x98f3c9e6E3fAce36bAAd05FE09d375Ef1464288B',
  'avalanche': '0x54a8e5f9c4CbA08F9943965859F6c34eAF03E26c',
  'fantom': '0x126783A6Cb203a3E35344528B26ca3a0489a1485',
  'arbitrum': '0xa5f208e072434bC67592E4C49C1B991BA79BCA46',
  'base': '0xbebdb6C8ddC678FfA9f8748f85C815C556Dd8ac6'
};

// Mock token data
const tokensByChain: Record<string, any[]> = {
  ethereum: [
    { symbol: 'USDC', address: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', decimals: 6 },
    { symbol: 'USDT', address: '0xdAC17F958D2ee523a2206206994597C13D831ec7', decimals: 6 },
    { symbol: 'WETH', address: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2', decimals: 18 }
  ],
  solana: [
    { symbol: 'USDC', address: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v', decimals: 6 },
    { symbol: 'USDT', address: 'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB', decimals: 6 },
    { symbol: 'SOL', address: 'So11111111111111111111111111111111111111112', decimals: 9 }
  ],
  bsc: [
    { symbol: 'USDC', address: '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d', decimals: 18 },
    { symbol: 'USDT', address: '0x55d398326f99059fF775485246999027B3197955', decimals: 18 },
    { symbol: 'WBNB', address: '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c', decimals: 18 }
  ],
  avalanche: [
    { symbol: 'USDC', address: '0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E', decimals: 6 },
    { symbol: 'USDT', address: '0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7', decimals: 6 },
    { symbol: 'WAVAX', address: '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7', decimals: 18 }
  ],
  fantom: [
    { symbol: 'USDC', address: '0x04068DA6C83AFCFA0e13ba15A6696662335D5B75', decimals: 6 },
    { symbol: 'WFTM', address: '0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83', decimals: 18 }
  ],
  arbitrum: [
    { symbol: 'USDC', address: '0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8', decimals: 6 },
    { symbol: 'USDT', address: '0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9', decimals: 6 },
    { symbol: 'WETH', address: '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1', decimals: 18 }
  ],
  base: [
    { symbol: 'USDC', address: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913', decimals: 6 },
    { symbol: 'WETH', address: '0x4200000000000000000000000000000000000006', decimals: 18 }
  ]
};

export class WormholeBridgeService {
  private logger: Logger;
  private wormholeInstance: any;
  private initialized: boolean = false;

  constructor() {
    this.logger = new Logger('WormholeBridgeService');
    this.logger.info('Initializing Wormhole Bridge Service');
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
      const provider = new ethers.JsonRpcProvider(RPC_ENDPOINTS[chainName]);
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
   * Get available chains for bridging
   */
  public getAvailableChains() {
    return [
      { id: 'ethereum', name: 'Ethereum', chainId: CHAIN_ID_MAP['ethereum'] },
      { id: 'solana', name: 'Solana', chainId: CHAIN_ID_MAP['solana'] },
      { id: 'bsc', name: 'Binance Smart Chain', chainId: CHAIN_ID_MAP['bsc'] },
      { id: 'avalanche', name: 'Avalanche', chainId: CHAIN_ID_MAP['avalanche'] },
      { id: 'fantom', name: 'Fantom', chainId: CHAIN_ID_MAP['fantom'] },
      { id: 'arbitrum', name: 'Arbitrum', chainId: CHAIN_ID_MAP['arbitrum'] },
      { id: 'base', name: 'Base', chainId: CHAIN_ID_MAP['base'] }
    ];
  }

  /**
   * Get available tokens for a specific chain
   */
  public getAvailableTokens(chain: string) {
    this.logger.info(`Getting available tokens for chain: ${chain}`);
    return tokensByChain[chain] || [];
  }

  /**
   * Bridge tokens from one chain to another
   */
  public async bridgeTokens(
    sourceChain: string,
    targetChain: string,
    token: string,
    amount: string,
    recipient: string,
    wallet: string,
    relayerFee: string = '0',
    privateKey?: string
  ) {
    this.logger.info(`Bridging tokens from ${sourceChain} to ${targetChain}`);
    this.logger.info(`Token: ${token}, Amount: ${amount}, Recipient: ${recipient}`);

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
        success: true,
        transactionHash: srcTxids[0],
        status: 'pending',
        attestation: attestIds[0],
        sourceChain,
        targetChain
      };
    } catch (error) {
      this.logger.error(`Error bridging tokens: ${error}`);
      return {
        success: false,
        error: `Error bridging tokens: ${error}`,
        sourceChain,
        targetChain
      };
    }
  }

  /**
   * Check the status of a bridge transaction
   */
  public async checkTransactionStatus(sourceChain: string, transactionHash: string) {
    this.logger.info(`Checking transaction status for ${transactionHash} on ${sourceChain}`);

    try {
      // Initialize Wormhole SDK if not already initialized
      await this.initialize();

      // Get Wormhole chain object
      const sourceWormholeChain = this.getWormholeChain(sourceChain);

      // Get the source chain object
      const sourceChainObj = this.wormholeInstance.getChain(sourceWormholeChain);

      // Check transaction status
      const status = await sourceChainObj.getTransactionStatus(transactionHash);

      // Check if the transaction has a VAA
      let attestation = null;
      try {
        // Try to get the VAA from the transaction
        const tokenBridge = sourceChainObj.getTokenBridge();
        const emitterAddress = tokenBridge.emitterAddress;
        const sequence = await tokenBridge.parseSequenceFromTx(transactionHash);

        if (sequence) {
          // Get the VAA
          const vaa = await this.wormholeInstance.getVaa(
            sourceWormholeChain,
            emitterAddress,
            sequence
          );

          if (vaa) {
            attestation = vaa;
          }
        }
      } catch (error) {
        this.logger.warn(`Failed to get VAA for transaction: ${error}`);
      }

      return {
        success: true,
        status: status.status,
        attestation,
        targetChain: null // This would need to be determined from the VAA
      };
    } catch (error) {
      this.logger.error(`Error checking transaction status: ${error}`);
      return {
        success: false,
        error: `Error checking transaction status: ${error}`
      };
    }
  }

  /**
   * Redeem tokens on the target chain
   */
  public async redeemTokens(attestation: string, targetChain: string, wallet: string, privateKey?: string) {
    this.logger.info(`Redeeming tokens on ${targetChain} with attestation: ${attestation.substring(0, 10)}...`);

    try {
      // Initialize Wormhole SDK if not already initialized
      await this.initialize();

      // Get Wormhole chain object
      const targetWormholeChain = this.getWormholeChain(targetChain);

      // Create a signer for the target chain
      if (!privateKey) {
        throw new Error('Private key is required for redeeming tokens');
      }

      const signer = await this.createSigner(targetChain, privateKey);

      // Parse the VAA
      const vaa = attestation;

      // Create a token transfer from the VAA
      const xfer = await this.wormholeInstance.parseTokenTransferVaa(vaa);

      // Complete the transfer
      const txids = await xfer.completeTransfer(signer);
      this.logger.info(`Transfer completed: ${JSON.stringify(txids)}`);

      return {
        success: true,
        transactionHash: txids[0],
        status: 'confirmed',
        targetChain
      };
    } catch (error) {
      this.logger.error(`Error redeeming tokens: ${error}`);
      return {
        success: false,
        error: `Error redeeming tokens: ${error}`,
        targetChain
      };
    }
  }

  /**
   * Get information about a wrapped asset
   */
  public async getWrappedAssetInfo(originalChain: string, originalAsset: string, targetChain: string) {
    this.logger.info(`Getting wrapped asset info for ${originalAsset} from ${originalChain} on ${targetChain}`);

    try {
      // Initialize Wormhole SDK if not already initialized
      await this.initialize();

      // Get Wormhole chain objects
      const sourceWormholeChain = this.getWormholeChain(originalChain);
      const targetWormholeChain = this.getWormholeChain(targetChain);

      // Create a token ID for the original asset
      const tokenId = TokenId.fromChainAddress(
        sourceWormholeChain,
        originalAsset
      );

      // Get the token bridge for the target chain
      const targetChainObj = this.wormholeInstance.getChain(targetWormholeChain);
      const tokenBridge = targetChainObj.getTokenBridge();

      // Get the wrapped asset address
      const wrappedAddress = await tokenBridge.getWrappedAssetAddress(tokenId);

      // Get token details
      let decimals = 8; // Default
      let symbol = `w${originalAsset.substring(0, 4).toUpperCase()}`;
      let name = `Wrapped ${originalAsset.substring(0, 4).toUpperCase()}`;

      try {
        // Try to get token details from the chain
        const tokenDetails = await targetChainObj.getTokenDetails(wrappedAddress);
        if (tokenDetails) {
          decimals = tokenDetails.decimals;
          symbol = tokenDetails.symbol;
          name = tokenDetails.name;
        }
      } catch (error) {
        this.logger.warn(`Failed to get token details: ${error}`);
      }

      const wrappedAsset = {
        address: wrappedAddress,
        chainId: CHAIN_ID_MAP[targetChain],
        decimals,
        symbol,
        name,
        isNative: false
      };

      return {
        success: true,
        wrappedAsset
      };
    } catch (error) {
      this.logger.error(`Error getting wrapped asset info: ${error}`);

      // Fallback to mock data in case of error
      const wrappedAsset = {
        address: `0x${Math.random().toString(16).substring(2, 42)}`,
        chainId: CHAIN_ID_MAP[targetChain],
        decimals: 8,
        symbol: `w${originalAsset.substring(0, 4).toUpperCase()}`,
        name: `Wrapped ${originalAsset.substring(0, 4).toUpperCase()}`,
        isNative: false
      };

      return {
        success: false,
        error: `Error getting wrapped asset info: ${error}`,
        wrappedAsset // Return mock data as fallback
      };
    }
  }
}
