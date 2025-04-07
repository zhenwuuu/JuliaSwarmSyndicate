import { IWalletManager, WalletProvider, WalletState, EthereumWalletProvider } from './types';
import { MetaMaskProvider } from './providers/MetaMaskProvider';
import { RabbyProvider } from './providers/RabbyProvider';
import { PhantomProvider } from './providers/PhantomProvider';
import { BaseProvider } from './providers/BaseProvider';
import { PrivateKeyProvider } from './providers/PrivateKeyProvider';
import { TransactionRequest } from '@ethersproject/providers';
import { TransactionResponse, TransactionReceipt } from '@ethersproject/abstract-provider';

export class WalletManager implements IWalletManager {
  private providers: Map<string, WalletProvider>;
  private currentProvider: WalletProvider | null = null;
  private nodeProviderInstance: PrivateKeyProvider;

  constructor() {
    this.providers = new Map<string, WalletProvider>();
    
    this.providers.set('metamask', new MetaMaskProvider() as WalletProvider);
    this.providers.set('rabby', new RabbyProvider() as WalletProvider);
    this.providers.set('phantom', new PhantomProvider() as WalletProvider);
    this.providers.set('base', new BaseProvider() as WalletProvider);

    this.nodeProviderInstance = new PrivateKeyProvider();
    this.providers.set('node', this.nodeProviderInstance as WalletProvider);
  }

  public async connect(providerName: string): Promise<void> {
    if (providerName === 'node') {
        throw new Error('Use connectWithPrivateKey for the node provider.');
    }
    const provider = this.getProvider(providerName);
    if (!provider) {
      throw new Error(`Provider ${providerName} not found`);
    }
    if (!provider.isAvailable()) {
        throw new Error(`Provider ${providerName} is not available (e.g., extension not installed).`);
    }

    if (this.currentProvider) {
      await this.disconnect();
    }

    try {
        await provider.connect();
        this.currentProvider = provider;
    } catch (error) {
        console.error(`Failed to connect to ${providerName}:`, error);
        this.currentProvider = null;
        throw error;
    }
  }

  public async connectWithPrivateKey(privateKey: string, chainId: number): Promise<void> {
    if (this.currentProvider) {
        await this.disconnect();
    }
    try {
        await this.nodeProviderInstance.connectWithKey(privateKey, chainId);
        this.currentProvider = this.nodeProviderInstance;
    } catch (error) {
        console.error(`Failed to connect with private key:`, error);
        this.currentProvider = null;
        throw error;
    }
  }

  public async disconnect(): Promise<void> {
    if (this.currentProvider) {
      try {
          await this.currentProvider.disconnect();
      } catch (error) {
          console.error("Error during disconnect:", error);
      }
      this.currentProvider = null;
    }
  }

  public getProvider(providerName: string): WalletProvider | null {
    return this.providers.get(providerName.toLowerCase()) || null;
  }

  public getNodeProvider(): PrivateKeyProvider {
    return this.nodeProviderInstance;
  }

  public getCurrentProvider(): WalletProvider | null {
    return this.currentProvider;
  }

  public getState(): WalletState {
    return this.currentProvider ? this.currentProvider.getState() : {
      address: null,
      chainId: null,
      isConnected: false,
      isConnecting: false,
      error: null,
      supportedChains: this.nodeProviderInstance.getSupportedChains()
    };
  }

  public isAvailable(providerName: string): boolean {
    const provider = this.getProvider(providerName.toLowerCase());
    if (providerName.toLowerCase() === 'node') return true;
    return provider ? provider.isAvailable() : false;
  }

  public async signMessage(message: string): Promise<string> {
    if (!this.currentProvider) {
      throw new Error('No wallet connected');
    }
    return await this.currentProvider.signMessage(message);
  }

  public async getAddress(): Promise<string> {
    if (!this.currentProvider) {
      throw new Error('No wallet connected');
    }
    return await this.currentProvider.getAddress();
  }

  public async getBalance(): Promise<string> {
    if (!this.currentProvider) {
      throw new Error('No wallet connected');
    }
    return await this.currentProvider.getBalance();
  }

  public async switchNetwork(chainId: number): Promise<void> {
    if (!this.currentProvider) {
      throw new Error('No wallet connected');
    }
    await this.currentProvider.switchNetwork(chainId);
  }

  public async getChainId(): Promise<number> {
    if (!this.currentProvider) {
      throw new Error('No wallet connected');
    }
    return await this.currentProvider.getChainId();
  }

  public async sendTransaction(transaction: TransactionRequest): Promise<TransactionResponse> {
    if (!this.currentProvider) {
        throw new Error('No wallet connected');
    }
    const providerWithSend = this.currentProvider as Partial<EthereumWalletProvider>;
    if (typeof providerWithSend.sendTransaction === 'function') {
         return await providerWithSend.sendTransaction(transaction);
    } else {
        throw new Error(`sendTransaction is not supported by the current provider: ${this.currentProvider.constructor.name}`);
    }
  }

  public async signTransactionRequest(transaction: TransactionRequest): Promise<string> {
    if (!this.currentProvider) {
        throw new Error('No wallet connected');
    }
    if (this.currentProvider instanceof PrivateKeyProvider) {
         return await this.currentProvider.signTransactionRequest(transaction);
    }
    else {
         throw new Error(`signTransactionRequest is not supported or implemented securely by the current provider: ${this.currentProvider.constructor.name}`);
    }
  }

  public async waitForTransaction(txHash: string, confirmations: number = 1): Promise<TransactionReceipt | null> {
    if (!this.currentProvider) {
        throw new Error('No wallet connected');
    }
    if (this.currentProvider instanceof PrivateKeyProvider) {
       return await this.currentProvider.waitForTransaction(txHash, confirmations);
    }
    else {
        console.warn(`waitForTransaction may not be directly available or implemented for the current provider: ${this.currentProvider.constructor.name}. Returning null.`);
        return null;
    }
  }
} 