import { WalletManager } from '@juliaos/wallets';
import { ethers } from 'ethers';
import { Connection, PublicKey, Keypair } from '@solana/web3.js';
import { Logger } from './bridge-service';

export class WalletIntegration {
  private walletManager: WalletManager;
  private logger: Logger;
  private connectedWallets: Map<string, boolean> = new Map();

  constructor() {
    this.walletManager = new WalletManager();
    this.logger = new Logger('WalletIntegration');
  }

  /**
   * Connect to a wallet
   * @param address Wallet address
   * @param chain Chain name
   * @param privateKey Optional private key for non-interactive wallet connection
   */
  public async connectWallet(address: string, chain: string, privateKey?: string): Promise<{ success: boolean, error?: string }> {
    try {
      const walletKey = `${address}-${chain}`;
      
      // Check if wallet is already connected
      if (this.connectedWallets.get(walletKey)) {
        return { success: true };
      }
      
      if (privateKey) {
        // Connect with private key
        const chainId = this.getChainId(chain);
        await this.walletManager.connectWithPrivateKey(privateKey, chainId);
      } else {
        // Connect with browser wallet
        if (chain === 'solana') {
          await this.walletManager.connect('phantom');
        } else {
          await this.walletManager.connect('metamask');
          
          // Switch to the correct network if needed
          const chainConfig = this.walletManager.getState().supportedChains.find(
            c => c.name.toLowerCase().includes(chain.toLowerCase())
          );
          
          if (chainConfig) {
            await this.walletManager.switchNetwork(chainConfig.chainId);
          }
        }
      }
      
      // Verify the connected address matches the requested address
      const connectedAddress = await this.walletManager.getAddress();
      if (connectedAddress.toLowerCase() !== address.toLowerCase()) {
        await this.walletManager.disconnect();
        return { 
          success: false, 
          error: `Connected address ${connectedAddress} does not match requested address ${address}` 
        };
      }
      
      // Mark wallet as connected
      this.connectedWallets.set(walletKey, true);
      
      return { success: true };
    } catch (error) {
      this.logger.error(`Failed to connect wallet: ${error}`);
      return { success: false, error: `Failed to connect wallet: ${error}` };
    }
  }

  /**
   * Check if a wallet is connected
   * @param address Wallet address
   * @param chain Chain name
   */
  public isWalletConnected(address: string, chain: string): boolean {
    const walletKey = `${address}-${chain}`;
    return this.connectedWallets.get(walletKey) || false;
  }

  /**
   * Disconnect a wallet
   * @param address Wallet address
   * @param chain Chain name
   */
  public async disconnectWallet(address: string, chain: string): Promise<{ success: boolean, error?: string }> {
    try {
      const walletKey = `${address}-${chain}`;
      
      // Check if wallet is connected
      if (!this.connectedWallets.get(walletKey)) {
        return { success: true };
      }
      
      // Disconnect wallet
      await this.walletManager.disconnect();
      
      // Mark wallet as disconnected
      this.connectedWallets.set(walletKey, false);
      
      return { success: true };
    } catch (error) {
      this.logger.error(`Failed to disconnect wallet: ${error}`);
      return { success: false, error: `Failed to disconnect wallet: ${error}` };
    }
  }

  /**
   * Get wallet balance
   * @param address Wallet address
   * @param chain Chain name
   */
  public async getWalletBalance(address: string, chain: string): Promise<{ success: boolean, balance?: string, error?: string }> {
    try {
      const walletKey = `${address}-${chain}`;
      
      // Check if wallet is connected
      if (!this.connectedWallets.get(walletKey)) {
        const connectResult = await this.connectWallet(address, chain);
        if (!connectResult.success) {
          return { success: false, error: connectResult.error };
        }
      }
      
      // Get balance
      const balance = await this.walletManager.getBalance();
      
      return { success: true, balance };
    } catch (error) {
      this.logger.error(`Failed to get wallet balance: ${error}`);
      return { success: false, error: `Failed to get wallet balance: ${error}` };
    }
  }

  /**
   * Sign a message
   * @param address Wallet address
   * @param chain Chain name
   * @param message Message to sign
   */
  public async signMessage(address: string, chain: string, message: string): Promise<{ success: boolean, signature?: string, error?: string }> {
    try {
      const walletKey = `${address}-${chain}`;
      
      // Check if wallet is connected
      if (!this.connectedWallets.get(walletKey)) {
        const connectResult = await this.connectWallet(address, chain);
        if (!connectResult.success) {
          return { success: false, error: connectResult.error };
        }
      }
      
      // Sign message
      const signature = await this.walletManager.signMessage(message);
      
      return { success: true, signature };
    } catch (error) {
      this.logger.error(`Failed to sign message: ${error}`);
      return { success: false, error: `Failed to sign message: ${error}` };
    }
  }

  /**
   * Get chain ID for a chain name
   * @param chain Chain name
   */
  private getChainId(chain: string): number {
    const chainMap: Record<string, number> = {
      'ethereum': 1,
      'bsc': 56,
      'avalanche': 43114,
      'fantom': 250,
      'arbitrum': 42161,
      'base': 8453
    };
    
    const chainId = chainMap[chain.toLowerCase()];
    if (!chainId) {
      throw new Error(`Unsupported chain: ${chain}`);
    }
    
    return chainId;
  }
}
