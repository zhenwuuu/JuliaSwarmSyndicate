import { ethers } from 'ethers';
import { MetaMaskProvider } from './MetaMaskProvider';

export class RabbyProvider extends MetaMaskProvider {
  protected checkAvailability(): boolean {
    return typeof window !== 'undefined' && 
           !!window.ethereum && 
           window.ethereum.isRabby;
  }

  public async connect(): Promise<void> {
    if (!this.checkAvailability()) {
      throw new Error('Rabby wallet is not available');
    }

    try {
      this.setState({ isConnecting: true });
      
      // Request account access
      await window.ethereum.request({ method: 'eth_requestAccounts' });
      
      // Initialize provider and signer
      this.provider = new ethers.BrowserProvider(window.ethereum);
      if (!this.provider) {
        throw new Error('Failed to initialize provider');
      }
      
      this.signer = await this.provider.getSigner();
      if (!this.signer) {
        throw new Error('Failed to get signer');
      }
      
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

  public async switchNetwork(chainId: number): Promise<void> {
    if (!window.ethereum) {
      throw new Error('Rabby wallet is not available');
    }

    try {
      // Rabby supports both EIP-155 and legacy chain switching
      await window.ethereum.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: `0x${chainId.toString(16)}` }],
      });
    } catch (error: any) {
      if (error.code === 4902) {
        // If network is not added, try to add it
        try {
          await window.ethereum.request({
            method: 'wallet_addEthereumChain',
            params: [{
              chainId: `0x${chainId.toString(16)}`,
              chainName: 'Custom Network',
              nativeCurrency: {
                name: 'ETH',
                symbol: 'ETH',
                decimals: 18
              },
              rpcUrls: ['https://custom-rpc-url.com'],
              blockExplorerUrls: ['https://custom-explorer.com']
            }]
          });
        } catch (addError) {
          throw new Error('Failed to add network');
        }
      } else {
        throw error;
      }
    }
  }
} 