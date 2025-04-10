import {
  CHAIN_ID_ETH,
  CHAIN_ID_SOLANA,
  CHAIN_ID_BSC,
  CHAIN_ID_AVAX,
  CHAIN_ID_FANTOM,
  CHAIN_ID_ARBITRUM,
  CHAIN_ID_BASE,
  getEmitterAddressEth,
  getEmitterAddressSolana,
  parseSequenceFromLogEth,
  parseSequenceFromLogSolana,
  getSignedVAAWithRetry,
  redeemOnEth,
  redeemOnSolana,
  transferFromEth,
  transferFromSolana,
  postVaaSolana,
  getOriginalAssetEth,
  getOriginalAssetSolana,
  hexToUint8Array,
  uint8ArrayToHex,
  parseTransferPayload
} from '@certusone/wormhole-sdk';
import { ethers, Wallet, Contract, JsonRpcProvider } from 'ethers';
import {
  Connection,
  PublicKey,
  Keypair,
  Transaction,
  sendAndConfirmTransaction
} from '@solana/web3.js';
import {
  BridgeConfig,
  TokenBridgeParams,
  TransferResult,
  RedeemResult,
  WormholeMessage,
  TokenInfo
} from './types';
import { Logger } from './utils/logger';

// Token Bridge ABI (simplified)
const TOKEN_BRIDGE_ABI = [
  'function transferTokens(address token, uint256 amount, uint16 recipientChain, bytes32 recipient, uint256 arbiterFee, uint32 nonce) external payable returns (uint64 sequence)',
  'function completeTransfer(bytes calldata encodedVm) external',
  'function wrappedAsset(uint16 tokenChainId, bytes32 tokenAddress) external view returns (address)'
];

// Wormhole Bridge ABI (simplified)
const WORMHOLE_BRIDGE_ABI = [
  'function publishMessage(uint32 nonce, bytes payload, uint8 consistencyLevel) external payable returns (uint64 sequence)',
  'function parseAndVerifyVM(bytes calldata encodedVM) external view returns (tuple(uint8 version, uint32 timestamp, uint32 nonce, uint16 emitterChainId, bytes32 emitterAddress, uint64 sequence, uint8 consistencyLevel, bytes payload, uint32 guardianSetIndex, bytes signatures) vm, bool valid, string reason)'
];

export class WormholeBridge {
  private config: BridgeConfig;
  private logger: Logger;
  private providers: Record<string, JsonRpcProvider> = {};
  private wallets: Record<string, Wallet> = {};
  private tokenBridgeContracts: Record<string, Contract> = {};
  private wormholeBridgeContracts: Record<string, Contract> = {};
  private solanaConnection?: Connection;
  private solanaWallet?: Keypair;

  constructor(config: BridgeConfig) {
    this.config = config;
    this.logger = new Logger('WormholeBridge');
    this.initialize();
  }

  private initialize() {
    // Initialize providers and wallets for each chain
    for (const [chainName, chainConfig] of Object.entries(this.config.networks)) {
      if (chainName === 'solana') {
        this.solanaConnection = new Connection(chainConfig.rpcUrl);
        this.solanaWallet = Keypair.fromSecretKey(
          Buffer.from(JSON.parse(this.config.privateKeys[chainName]))
        );
        continue;
      }

      // Initialize EVM providers and wallets
      const provider = new JsonRpcProvider(chainConfig.rpcUrl);
      const wallet = new Wallet(this.config.privateKeys[chainName], provider);
      
      this.providers[chainName] = provider;
      this.wallets[chainName] = wallet;
      
      // Initialize token bridge contracts
      this.tokenBridgeContracts[chainName] = new Contract(
        chainConfig.tokenBridgeAddress,
        TOKEN_BRIDGE_ABI,
        wallet
      );
      
      // Initialize wormhole bridge contracts
      this.wormholeBridgeContracts[chainName] = new Contract(
        chainConfig.bridgeAddress,
        WORMHOLE_BRIDGE_ABI,
        wallet
      );
    }
  }

  /**
   * Get the Wormhole chain ID for a given chain name
   */
  private getWormholeChainId(chainName: string): number {
    const chainConfig = this.config.networks[chainName];
    if (!chainConfig) {
      throw new Error(`Chain ${chainName} not configured`);
    }
    return chainConfig.wormholeChainId;
  }

  /**
   * Convert an Ethereum address to a Wormhole format
   */
  private ethAddressToWormhole(address: string): string {
    return ethers.zeroPadValue(address, 32).substring(2);
  }

  /**
   * Bridge tokens from one chain to another using Wormhole
   */
  public async bridgeTokens(params: TokenBridgeParams): Promise<TransferResult> {
    const { sourceChain, targetChain, token, amount, recipient, relayerFee = 0 } = params;
    
    this.logger.info(`Bridging ${amount} of token ${token} from ${sourceChain} to ${targetChain}`);
    
    try {
      // Handle different source chains
      if (sourceChain === 'ethereum' || 
          sourceChain === 'bsc' || 
          sourceChain === 'avalanche' || 
          sourceChain === 'fantom' || 
          sourceChain === 'arbitrum' ||
          sourceChain === 'base') {
        return await this.bridgeFromEVM(params);
      } else if (sourceChain === 'solana') {
        return await this.bridgeFromSolana(params);
      } else {
        throw new Error(`Unsupported source chain: ${sourceChain}`);
      }
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
   * Bridge tokens from an EVM chain
   */
  private async bridgeFromEVM(params: TokenBridgeParams): Promise<TransferResult> {
    const { sourceChain, targetChain, token, amount, recipient, relayerFee = 0 } = params;
    
    const sourceChainId = this.getWormholeChainId(sourceChain);
    const targetChainId = this.getWormholeChainId(targetChain);
    
    const wallet = this.wallets[sourceChain];
    const tokenBridgeContract = this.tokenBridgeContracts[sourceChain];
    
    // Format recipient address based on target chain
    let recipientAddress: string;
    if (targetChain === 'solana') {
      recipientAddress = new PublicKey(recipient).toBuffer().toString('hex');
    } else {
      recipientAddress = this.ethAddressToWormhole(recipient);
    }
    
    // Transfer tokens
    const nonce = Math.floor(Math.random() * 100000);
    const overrides = { 
      value: ethers.parseEther('0.001') // Fee for Wormhole message
    };
    
    const tx = await tokenBridgeContract.transferTokens(
      token,
      amount,
      targetChainId,
      `0x${recipientAddress}`,
      relayerFee,
      nonce,
      overrides
    );
    
    const receipt = await tx.wait();
    
    // Get the sequence number from the logs
    const sequence = parseSequenceFromLogEth(receipt, this.config.networks[sourceChain].bridgeAddress);
    
    // Get the emitter address
    const emitterAddress = getEmitterAddressEth(this.config.networks[sourceChain].tokenBridgeAddress);
    
    return {
      transactionHash: tx.hash,
      amount: amount.toString(),
      fee: relayerFee.toString(),
      sourceChain,
      targetChain,
      token,
      recipient,
      status: 'pending',
      sequence: sequence.toString(),
      emitterAddress
    };
  }

  /**
   * Bridge tokens from Solana
   */
  private async bridgeFromSolana(params: TokenBridgeParams): Promise<TransferResult> {
    const { sourceChain, targetChain, token, amount, recipient, relayerFee = 0 } = params;
    
    if (!this.solanaConnection || !this.solanaWallet) {
      throw new Error('Solana connection not initialized');
    }
    
    const targetChainId = this.getWormholeChainId(targetChain);
    
    // Format recipient address based on target chain
    let recipientAddress: Uint8Array;
    if (targetChain === 'solana') {
      recipientAddress = new PublicKey(recipient).toBuffer();
    } else {
      recipientAddress = hexToUint8Array(this.ethAddressToWormhole(recipient));
    }
    
    // Transfer tokens from Solana
    const tokenPublicKey = new PublicKey(token);
    const payerPublicKey = this.solanaWallet.publicKey;
    
    const transferResult = await transferFromSolana(
      this.solanaConnection,
      this.config.networks['solana'].bridgeAddress,
      this.config.networks['solana'].tokenBridgeAddress,
      payerPublicKey,
      tokenPublicKey,
      BigInt(amount.toString()),
      recipientAddress,
      targetChainId,
      BigInt(relayerFee.toString())
    );
    
    // Sign and send the transaction
    const transaction = new Transaction().add(...transferResult.transaction);
    const signature = await sendAndConfirmTransaction(
      this.solanaConnection,
      transaction,
      [this.solanaWallet, ...transferResult.signers]
    );
    
    // Get the sequence number from the logs
    const sequence = parseSequenceFromLogSolana(transferResult.signature);
    
    // Get the emitter address
    const emitterAddress = getEmitterAddressSolana(this.config.networks['solana'].tokenBridgeAddress);
    
    return {
      transactionHash: signature,
      amount: amount.toString(),
      fee: relayerFee.toString(),
      sourceChain,
      targetChain,
      token,
      recipient,
      status: 'pending',
      sequence: sequence.toString(),
      emitterAddress
    };
  }

  /**
   * Redeem tokens on the target chain
   */
  public async redeemTokens(vaa: string, targetChain: string): Promise<RedeemResult> {
    this.logger.info(`Redeeming tokens on ${targetChain}`);
    
    try {
      if (targetChain === 'ethereum' || 
          targetChain === 'bsc' || 
          targetChain === 'avalanche' || 
          targetChain === 'fantom' || 
          targetChain === 'arbitrum' ||
          targetChain === 'base') {
        return await this.redeemOnEVM(vaa, targetChain);
      } else if (targetChain === 'solana') {
        return await this.redeemOnSolanaChain(vaa);
      } else {
        throw new Error(`Unsupported target chain: ${targetChain}`);
      }
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
   * Redeem tokens on an EVM chain
   */
  private async redeemOnEVM(vaa: string, targetChain: string): Promise<RedeemResult> {
    const tokenBridgeContract = this.tokenBridgeContracts[targetChain];
    
    // Complete the transfer
    const tx = await tokenBridgeContract.completeTransfer(
      `0x${vaa}`
    );
    
    await tx.wait();
    
    return {
      transactionHash: tx.hash,
      status: 'completed'
    };
  }

  /**
   * Redeem tokens on Solana
   */
  private async redeemOnSolanaChain(vaa: string): Promise<RedeemResult> {
    if (!this.solanaConnection || !this.solanaWallet) {
      throw new Error('Solana connection not initialized');
    }
    
    // Post VAA to Solana
    await postVaaSolana(
      this.solanaConnection,
      this.solanaWallet,
      this.config.networks['solana'].bridgeAddress,
      this.solanaWallet.publicKey,
      Buffer.from(vaa, 'hex')
    );
    
    // Redeem on Solana
    const redeemResult = await redeemOnSolana(
      this.solanaConnection,
      this.config.networks['solana'].bridgeAddress,
      this.config.networks['solana'].tokenBridgeAddress,
      this.solanaWallet.publicKey,
      Buffer.from(vaa, 'hex')
    );
    
    // Sign and send the transaction
    const transaction = new Transaction().add(...redeemResult.transaction);
    const signature = await sendAndConfirmTransaction(
      this.solanaConnection,
      transaction,
      [this.solanaWallet, ...redeemResult.signers]
    );
    
    return {
      transactionHash: signature,
      status: 'completed'
    };
  }

  /**
   * Get the VAA for a transfer
   */
  public async getVAA(
    sourceChain: string,
    emitterAddress: string,
    sequence: string
  ): Promise<string> {
    const sourceChainId = this.getWormholeChainId(sourceChain);
    
    // Get the signed VAA
    const { vaaBytes } = await getSignedVAAWithRetry(
      [this.config.networks[sourceChain].rpcUrl],
      sourceChainId,
      emitterAddress,
      sequence
    );
    
    return uint8ArrayToHex(vaaBytes);
  }

  /**
   * Get token info for a wrapped asset
   */
  public async getWrappedAssetInfo(
    originalChain: string,
    originalAsset: string,
    targetChain: string
  ): Promise<TokenInfo> {
    const originalChainId = this.getWormholeChainId(originalChain);
    
    let wrappedAddress: string;
    
    if (targetChain === 'solana') {
      if (!this.solanaConnection) {
        throw new Error('Solana connection not initialized');
      }
      
      // Get wrapped asset on Solana
      const wrappedAddressResult = await getOriginalAssetSolana(
        this.solanaConnection,
        this.config.networks['solana'].tokenBridgeAddress,
        originalChainId,
        hexToUint8Array(originalAsset)
      );
      
      wrappedAddress = wrappedAddressResult.address;
    } else {
      // Get wrapped asset on EVM chain
      const tokenBridgeContract = this.tokenBridgeContracts[targetChain];
      
      wrappedAddress = await tokenBridgeContract.wrappedAsset(
        originalChainId,
        `0x${originalAsset}`
      );
    }
    
    // For simplicity, we're returning minimal info
    // In a real implementation, you would fetch more details about the token
    return {
      address: wrappedAddress,
      chainId: this.getWormholeChainId(targetChain),
      decimals: 18, // This should be fetched from the token contract
      symbol: 'WRAPPED', // This should be fetched from the token contract
      name: 'Wrapped Asset', // This should be fetched from the token contract
      isNative: false
    };
  }

  /**
   * Parse a VAA to extract transfer details
   */
  public parseTransferVAA(vaa: string): any {
    const vaaBytes = hexToUint8Array(vaa);
    return parseTransferPayload(vaaBytes);
  }
}
