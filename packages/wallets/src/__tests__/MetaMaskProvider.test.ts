import { MetaMaskProvider } from '../providers/MetaMaskProvider';
import { ethers } from 'ethers';

// Mock ethers
jest.mock('ethers', () => ({
  BrowserProvider: jest.fn(),
  formatEther: jest.fn(),
}));

describe('MetaMaskProvider', () => {
  let provider: MetaMaskProvider;
  let mockProvider: any;
  let mockSigner: any;

  beforeEach(() => {
    // Reset mocks
    jest.clearAllMocks();

    // Mock window.ethereum
    global.window = {
      ethereum: {
        request: jest.fn(),
        on: jest.fn(),
        removeListener: jest.fn(),
      },
    } as any;

    // Mock ethers provider and signer
    mockSigner = {
      getAddress: jest.fn(),
      signMessage: jest.fn(),
      sendTransaction: jest.fn(),
    };

    mockProvider = {
      getSigner: jest.fn(),
      getNetwork: jest.fn(),
      getBalance: jest.fn(),
    };

    (ethers.BrowserProvider as jest.Mock).mockImplementation(() => mockProvider);
    mockProvider.getSigner.mockResolvedValue(mockSigner);

    provider = new MetaMaskProvider();
  });

  describe('checkAvailability', () => {
    it('should return true if MetaMask is available', () => {
      expect(provider.isAvailable()).toBe(true);
    });

    it('should return false if window.ethereum is not available', () => {
      delete (global.window as any).ethereum;
      expect(provider.isAvailable()).toBe(false);
    });
  });

  describe('connect', () => {
    it('should connect successfully', async () => {
      const address = '0x123';
      const chainId = 1;
      const balance = ethers.parseEther('1.0');

      mockProvider.getNetwork.mockResolvedValue({ chainId });
      mockSigner.getAddress.mockResolvedValue(address);
      mockProvider.getBalance.mockResolvedValue(balance);
      (ethers.formatEther as jest.Mock).mockReturnValue('1.0');

      await provider.connect();

      expect(window.ethereum.request).toHaveBeenCalledWith({
        method: 'eth_requestAccounts',
        params: [],
      });
      expect(mockProvider.getSigner).toHaveBeenCalled();
      expect(mockSigner.getAddress).toHaveBeenCalled();
      expect(mockProvider.getNetwork).toHaveBeenCalled();
      expect(mockProvider.getBalance).toHaveBeenCalledWith(address);
    });

    it('should throw error if MetaMask is not available', async () => {
      delete (global.window as any).ethereum;
      await expect(provider.connect()).rejects.toThrow('MetaMask is not available');
    });

    it('should handle connection errors', async () => {
      const error = new Error('Connection failed');
      window.ethereum.request.mockRejectedValue(error);

      await expect(provider.connect()).rejects.toThrow('Connection failed');
    });
  });

  describe('disconnect', () => {
    it('should reset state', async () => {
      await provider.disconnect();
      const state = provider.getState();
      expect(state).toEqual({
        address: null,
        chainId: null,
        isConnected: false,
        isConnecting: false,
        error: null,
      });
    });
  });

  describe('signMessage', () => {
    it('should sign message successfully', async () => {
      const message = 'Hello, World!';
      const signature = '0x123';
      mockSigner.signMessage.mockResolvedValue(signature);

      const result = await provider.signMessage(message);
      expect(result).toBe(signature);
      expect(mockSigner.signMessage).toHaveBeenCalledWith(message);
    });

    it('should throw error if not connected', async () => {
      await expect(provider.signMessage('test')).rejects.toThrow('Wallet not connected');
    });
  });

  describe('getAddress', () => {
    it('should return address', async () => {
      const address = '0x123';
      mockSigner.getAddress.mockResolvedValue(address);

      const result = await provider.getAddress();
      expect(result).toBe(address);
      expect(mockSigner.getAddress).toHaveBeenCalled();
    });

    it('should throw error if not connected', async () => {
      await expect(provider.getAddress()).rejects.toThrow('Wallet not connected');
    });
  });

  describe('getBalance', () => {
    it('should return balance', async () => {
      const address = '0x123';
      const balance = ethers.parseEther('1.0');
      mockSigner.getAddress.mockResolvedValue(address);
      mockProvider.getBalance.mockResolvedValue(balance);
      (ethers.formatEther as jest.Mock).mockReturnValue('1.0');

      const result = await provider.getBalance();
      expect(result).toBe('1.0');
      expect(mockProvider.getBalance).toHaveBeenCalledWith(address);
    });

    it('should throw error if not connected', async () => {
      await expect(provider.getBalance()).rejects.toThrow('Wallet not connected');
    });
  });

  describe('switchNetwork', () => {
    it('should switch network successfully', async () => {
      const chainId = 1;
      await provider.switchNetwork(chainId);

      expect(window.ethereum.request).toHaveBeenCalledWith({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: '0x1' }],
      });
    });

    it('should throw error if MetaMask is not available', async () => {
      delete (global.window as any).ethereum;
      await expect(provider.switchNetwork(1)).rejects.toThrow('MetaMask is not available');
    });

    it('should handle network not supported error', async () => {
      const error = { code: 4902 };
      window.ethereum.request.mockRejectedValue(error);

      await expect(provider.switchNetwork(1)).rejects.toThrow('Network not supported');
    });
  });

  describe('getChainId', () => {
    it('should return chain ID', async () => {
      const chainId = 1;
      mockProvider.getNetwork.mockResolvedValue({ chainId });

      const result = await provider.getChainId();
      expect(result).toBe(chainId);
      expect(mockProvider.getNetwork).toHaveBeenCalled();
    });

    it('should throw error if not connected', async () => {
      await expect(provider.getChainId()).rejects.toThrow('Wallet not connected');
    });
  });

  describe('getSigner', () => {
    it('should return signer', async () => {
      const result = await provider.getSigner();
      expect(result).toBe(mockSigner);
      expect(mockProvider.getSigner).toHaveBeenCalled();
    });

    it('should throw error if not connected', async () => {
      await expect(provider.getSigner()).rejects.toThrow('Wallet not connected');
    });
  });

  describe('sendTransaction', () => {
    it('should send transaction successfully', async () => {
      const transaction = { to: '0x123', value: ethers.parseEther('1.0') };
      const receipt = { hash: '0x456' };
      mockSigner.sendTransaction.mockResolvedValue(receipt);

      const result = await provider.sendTransaction(transaction);
      expect(result).toBe(receipt);
      expect(mockSigner.sendTransaction).toHaveBeenCalledWith(transaction);
    });

    it('should throw error if not connected', async () => {
      await expect(provider.sendTransaction({})).rejects.toThrow('Wallet not connected');
    });
  });
}); 