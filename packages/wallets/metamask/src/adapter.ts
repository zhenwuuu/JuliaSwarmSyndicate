import { WalletAdapter } from '../../common/src/types';
import { ethers } from 'ethers';

export class MetaMaskWalletAdapter implements WalletAdapter {
  private provider: any;
  private signer: ethers.Signer | null = null;
  private address: string | null = null;
  private providerInstance: ethers.providers.Web3Provider | null = null;

  constructor() {
    if (typeof window !== 'undefined') {
      this.provider = (window as any).ethereum;
    }
  }

  async connect(): Promise<void> {
    try {
      if (!this.provider) {
        throw new Error('MetaMask not found');
      }

      const accounts = await this.provider.request({
        method: 'eth_requestAccounts'
      });

      this.address = accounts[0];
      this.providerInstance = new ethers.providers.Web3Provider(this.provider);
      this.signer = await this.providerInstance.getSigner();
    } catch (error) {
      throw new Error(`Failed to connect to MetaMask: ${error}`);
    }
  }

  async disconnect(): Promise<void> {
    this.signer = null;
    this.address = null;
    this.providerInstance = null;
  }

  async signTransaction(transaction: any): Promise<any> {
    try {
      if (!this.signer) {
        throw new Error('Wallet not connected');
      }
      const signedTx = await this.signer.signTransaction(transaction);
      return signedTx;
    } catch (error) {
      throw new Error(`Failed to sign transaction: ${error}`);
    }
  }

  async signMessage(message: string): Promise<string> {
    try {
      if (!this.signer) {
        throw new Error('Wallet not connected');
      }
      const signature = await this.signer.signMessage(message);
      return signature;
    } catch (error) {
      throw new Error(`Failed to sign message: ${error}`);
    }
  }

  async getAddress(): Promise<string> {
    if (!this.address) {
      throw new Error('Wallet not connected');
    }
    return this.address;
  }

  async getBalance(tokenAddress?: string): Promise<string> {
    try {
      if (!this.providerInstance || !this.address) {
        throw new Error('Wallet not connected');
      }

      if (tokenAddress) {
        // ERC20 token balance
        const tokenContract = new ethers.Contract(
          tokenAddress,
          ['function balanceOf(address) view returns (uint256)'],
          this.providerInstance
        );
        const balance = await tokenContract.balanceOf(this.address);
        return balance.toString();
      } else {
        // Native token balance
        const balance = await this.providerInstance.getBalance(this.address);
        return balance.toString();
      }
    } catch (error) {
      throw new Error(`Failed to get balance: ${error}`);
    }
  }

  async sendTransaction(transaction: any): Promise<string> {
    try {
      if (!this.signer) {
        throw new Error('Wallet not connected');
      }
      
      // Estimate gas if not provided
      if (!transaction.gasLimit) {
        const gasEstimate = await this.signer.estimateGas(transaction);
        transaction.gasLimit = gasEstimate;
      }
      
      // Get current gas price if not provided
      if (!transaction.gasPrice && !transaction.maxFeePerGas) {
        const feeData = await this.providerInstance!.getFeeData();
        transaction.maxFeePerGas = feeData.maxFeePerGas;
        transaction.maxPriorityFeePerGas = feeData.maxPriorityFeePerGas;
      }
      
      const tx = await this.signer.sendTransaction(transaction);
      return tx.hash;
    } catch (error) {
      throw new Error(`Failed to send transaction: ${error}`);
    }
  }

  async switchChain(chainId: string): Promise<void> {
    try {
      if (!this.provider) {
        throw new Error('MetaMask not found');
      }
      
      await this.provider.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId }],
      });
    } catch (error: any) {
      // If the chain doesn't exist, add it
      if (error.code === 4902) {
        throw new Error(`Chain ${chainId} not found. Please add it first.`);
      }
      throw new Error(`Failed to switch chain: ${error.message}`);
    }
  }

  async addChain(chainConfig: { chainId: string, chainName: string, nativeCurrency: any, rpcUrls: string[], blockExplorerUrls?: string[] }): Promise<void> {
    try {
      if (!this.provider) {
        throw new Error('MetaMask not found');
      }
      
      await this.provider.request({
        method: 'wallet_addEthereumChain',
        params: [chainConfig],
      });
    } catch (error) {
      throw new Error(`Failed to add chain: ${error}`);
    }
  }
} 