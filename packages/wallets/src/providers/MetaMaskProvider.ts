import { ethers } from 'ethers';
import { BaseWalletProvider } from './BaseWalletProvider';
import { EthereumWalletProvider, CrossChainTransaction } from '../types';

declare global {
  interface Window {
    ethereum?: any;
  }
}

export class MetaMaskProvider extends BaseWalletProvider implements EthereumWalletProvider {
  protected provider: ethers.BrowserProvider | null = null;
  protected signer: ethers.JsonRpcSigner | null = null;

  protected checkAvailability(): boolean {
    return typeof window !== 'undefined' && !!window.ethereum;
  }

  protected setupEventListeners(): void {
    if (!window.ethereum) return;

    window.ethereum.on('accountsChanged', (accounts: string[]) => {
      if (accounts.length === 0) {
        this.disconnect();
      } else {
        this.setState({ address: accounts[0] });
        this.emitEvent('accountsChanged', accounts[0]);
      }
    });

    window.ethereum.on('chainChanged', (chainId: string) => {
      this.setState({ chainId: parseInt(chainId, 16) });
      this.emitEvent('chainChanged', parseInt(chainId, 16));
    });

    window.ethereum.on('disconnect', () => {
      this.disconnect();
    });
  }

  public async connect(): Promise<void> {
    if (!this.checkAvailability()) {
      throw new Error('MetaMask is not available');
    }

    try {
      this.setState({ isConnecting: true });
      
      this.provider = new ethers.BrowserProvider(window.ethereum);
      await this.provider.send('eth_requestAccounts', []);
      
      this.signer = await this.provider.getSigner();
      const address = await this.signer.getAddress();
      const network = await this.provider.getNetwork();

      this.setState({
        address,
        chainId: Number(network.chainId),
        isConnected: true,
        isConnecting: false
      });

      this.emitEvent('connect', { address, chainId: Number(network.chainId) });
    } catch (error) {
      this.handleError(error as Error);
      throw error;
    }
  }

  public async disconnect(): Promise<void> {
    this.setState({
      address: null,
      chainId: null,
      isConnected: false,
      isConnecting: false
    });
    this.emitEvent('disconnect');
  }

  public async signMessage(message: string): Promise<string> {
    if (!this.signer) {
      throw new Error('Wallet not connected');
    }
    return this.signer.signMessage(message);
  }

  public async getAddress(): Promise<string> {
    if (!this.signer) {
      throw new Error('Wallet not connected');
    }
    return this.signer.getAddress();
  }

  public async getBalance(): Promise<string> {
    if (!this.provider) {
      throw new Error('Wallet not connected');
    }
    const address = await this.getAddress();
    const balance = await this.provider.getBalance(address);
    return ethers.formatEther(balance);
  }

  public async switchNetwork(chainId: number): Promise<void> {
    if (!window.ethereum) {
      throw new Error('MetaMask is not available');
    }

    try {
      await window.ethereum.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: `0x${chainId.toString(16)}` }],
      });
    } catch (error: any) {
      if (error.code === 4902) {
        throw new Error('Network not supported');
      }
      throw error;
    }
  }

  public async getChainId(): Promise<number> {
    if (!this.provider) {
      throw new Error('Wallet not connected');
    }
    const network = await this.provider.getNetwork();
    return Number(network.chainId);
  }

  public async getSigner(): Promise<ethers.JsonRpcSigner> {
    if (!this.signer) {
      throw new Error('Wallet not connected');
    }
    return this.signer;
  }

  public async sendTransaction(transaction: any): Promise<any> {
    if (!this.signer) {
      throw new Error('Wallet not connected');
    }
    return this.signer.sendTransaction(transaction);
  }
  
  // Implement the abstract method from BaseWalletProvider
  public async sendCrossChainTransaction(tx: CrossChainTransaction): Promise<string> {
    // Validate the cross-chain transaction
    await this.validateCrossChainTransaction(tx);
    
    // Ensure wallet is connected
    if (!this.signer) {
      throw new Error('Wallet not connected');
    }
    
    // Ensure we're on the correct source chain
    const currentChainId = await this.getChainId();
    if (currentChainId !== tx.fromChain) {
      await this.switchNetwork(tx.fromChain);
    }
    
    // In a real implementation, this would interact with a cross-chain bridge
    // For now, we'll just simulate sending a transaction
    try {
      // Create an appropriate transaction for the cross-chain transfer
      const transaction = {
        to: tx.toAddress,
        value: ethers.parseEther(tx.amount),
        data: tx.token ? ethers.solidityPacked(['address'], [tx.token]) : '0x',
      };
      
      // Send the transaction
      const result = await this.sendTransaction(transaction);
      return result.hash;
    } catch (error) {
      this.handleError(error as Error);
      throw error;
    }
  }
} 