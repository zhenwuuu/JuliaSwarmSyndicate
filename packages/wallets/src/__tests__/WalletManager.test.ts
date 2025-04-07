import { WalletManager } from '../WalletManager';
import { MetaMaskProvider } from '../providers/MetaMaskProvider';
import { RabbyProvider } from '../providers/RabbyProvider';
import { PhantomProvider } from '../providers/PhantomProvider';

// Mock window.ethereum
const mockEthereum = {
  isMetaMask: true,
  isRabby: false,
  request: jest.fn(),
  on: jest.fn(),
  removeListener: jest.fn(),
};

// Mock window.solana
const mockSolana = {
  isPhantom: true,
  connect: jest.fn(),
  disconnect: jest.fn(),
  signMessage: jest.fn(),
  signTransaction: jest.fn(),
  signAllTransactions: jest.fn(),
  on: jest.fn(),
  removeListener: jest.fn(),
};

describe('WalletManager', () => {
  let walletManager: WalletManager;
  let mockMetaMaskProvider: jest.Mocked<MetaMaskProvider>;
  let mockRabbyProvider: jest.Mocked<RabbyProvider>;
  let mockPhantomProvider: jest.Mocked<PhantomProvider>;

  beforeEach(() => {
    // Reset mocks
    jest.clearAllMocks();

    // Mock window object
    global.window = {
      ethereum: mockEthereum,
      solana: mockSolana,
    } as any;

    // Create mock providers
    mockMetaMaskProvider = {
      connect: jest.fn(),
      disconnect: jest.fn(),
      signMessage: jest.fn(),
      getAddress: jest.fn(),
      getBalance: jest.fn(),
      switchNetwork: jest.fn(),
      getChainId: jest.fn(),
      isAvailable: jest.fn(),
      getState: jest.fn(),
    } as any;

    mockRabbyProvider = {
      connect: jest.fn(),
      disconnect: jest.fn(),
      signMessage: jest.fn(),
      getAddress: jest.fn(),
      getBalance: jest.fn(),
      switchNetwork: jest.fn(),
      getChainId: jest.fn(),
      isAvailable: jest.fn(),
      getState: jest.fn(),
    } as any;

    mockPhantomProvider = {
      connect: jest.fn(),
      disconnect: jest.fn(),
      signMessage: jest.fn(),
      getAddress: jest.fn(),
      getBalance: jest.fn(),
      switchNetwork: jest.fn(),
      getChainId: jest.fn(),
      isAvailable: jest.fn(),
      getState: jest.fn(),
      getPublicKey: jest.fn(),
      signTransaction: jest.fn(),
      signAllTransactions: jest.fn(),
    } as any;

    // Create wallet manager with mock providers
    walletManager = new WalletManager();
    (walletManager as any).providers.set('metamask', mockMetaMaskProvider);
    (walletManager as any).providers.set('rabby', mockRabbyProvider);
    (walletManager as any).providers.set('phantom', mockPhantomProvider);
  });

  describe('connect', () => {
    it('should connect to MetaMask successfully', async () => {
      mockMetaMaskProvider.isAvailable.mockReturnValue(true);
      mockMetaMaskProvider.connect.mockResolvedValue(undefined);
      mockMetaMaskProvider.getAddress.mockResolvedValue('0x123');
      mockMetaMaskProvider.getBalance.mockResolvedValue('1.0');
      mockMetaMaskProvider.getChainId.mockResolvedValue(1);

      await walletManager.connect('metamask');

      expect(mockMetaMaskProvider.connect).toHaveBeenCalled();
      expect(mockMetaMaskProvider.getAddress).toHaveBeenCalled();
      expect(mockMetaMaskProvider.getBalance).toHaveBeenCalled();
      expect(mockMetaMaskProvider.getChainId).toHaveBeenCalled();
    });

    it('should throw error if provider is not available', async () => {
      mockMetaMaskProvider.isAvailable.mockReturnValue(false);

      await expect(walletManager.connect('metamask')).rejects.toThrow('Provider metamask is not available');
    });

    it('should disconnect current provider before connecting to new one', async () => {
      mockMetaMaskProvider.isAvailable.mockReturnValue(true);
      mockMetaMaskProvider.connect.mockResolvedValue(undefined);
      mockRabbyProvider.isAvailable.mockReturnValue(true);
      mockRabbyProvider.connect.mockResolvedValue(undefined);

      // Connect to MetaMask first
      await walletManager.connect('metamask');
      expect(mockMetaMaskProvider.connect).toHaveBeenCalled();

      // Connect to Rabby
      await walletManager.connect('rabby');
      expect(mockMetaMaskProvider.disconnect).toHaveBeenCalled();
      expect(mockRabbyProvider.connect).toHaveBeenCalled();
    });
  });

  describe('disconnect', () => {
    it('should disconnect current provider', async () => {
      mockMetaMaskProvider.isAvailable.mockReturnValue(true);
      mockMetaMaskProvider.connect.mockResolvedValue(undefined);
      await walletManager.connect('metamask');

      await walletManager.disconnect();
      expect(mockMetaMaskProvider.disconnect).toHaveBeenCalled();
    });

    it('should do nothing if no provider is connected', async () => {
      await walletManager.disconnect();
      expect(mockMetaMaskProvider.disconnect).not.toHaveBeenCalled();
      expect(mockRabbyProvider.disconnect).not.toHaveBeenCalled();
      expect(mockPhantomProvider.disconnect).not.toHaveBeenCalled();
    });
  });

  describe('getProvider', () => {
    it('should return provider if it exists', () => {
      const provider = walletManager.getProvider('metamask');
      expect(provider).toBe(mockMetaMaskProvider);
    });

    it('should return null if provider does not exist', () => {
      const provider = walletManager.getProvider('nonexistent');
      expect(provider).toBeNull();
    });
  });

  describe('getCurrentProvider', () => {
    it('should return current provider when connected', async () => {
      mockMetaMaskProvider.isAvailable.mockReturnValue(true);
      mockMetaMaskProvider.connect.mockResolvedValue(undefined);
      await walletManager.connect('metamask');

      const provider = walletManager.getCurrentProvider();
      expect(provider).toBe(mockMetaMaskProvider);
    });

    it('should return null when not connected', () => {
      const provider = walletManager.getCurrentProvider();
      expect(provider).toBeNull();
    });
  });

  describe('getState', () => {
    it('should return provider state when connected', async () => {
      const mockState = {
        address: '0x123',
        chainId: 1,
        isConnected: true,
        isConnecting: false,
        error: null,
      };

      mockMetaMaskProvider.isAvailable.mockReturnValue(true);
      mockMetaMaskProvider.connect.mockResolvedValue(undefined);
      mockMetaMaskProvider.getState.mockReturnValue(mockState);
      await walletManager.connect('metamask');

      const state = walletManager.getState();
      expect(state).toEqual(mockState);
    });

    it('should return default state when not connected', () => {
      const state = walletManager.getState();
      expect(state).toEqual({
        address: null,
        chainId: null,
        isConnected: false,
        isConnecting: false,
        error: null,
      });
    });
  });

  describe('isAvailable', () => {
    it('should check provider availability', () => {
      mockMetaMaskProvider.isAvailable.mockReturnValue(true);
      mockRabbyProvider.isAvailable.mockReturnValue(false);

      expect(walletManager.isAvailable('metamask')).toBe(true);
      expect(walletManager.isAvailable('rabby')).toBe(false);
      expect(walletManager.isAvailable('nonexistent')).toBe(false);
    });
  });

  describe('common operations', () => {
    beforeEach(async () => {
      mockMetaMaskProvider.isAvailable.mockReturnValue(true);
      mockMetaMaskProvider.connect.mockResolvedValue(undefined);
      await walletManager.connect('metamask');
    });

    it('should sign message', async () => {
      const message = 'Hello, World!';
      const signature = '0x123';
      mockMetaMaskProvider.signMessage.mockResolvedValue(signature);

      const result = await walletManager.signMessage(message);
      expect(result).toBe(signature);
      expect(mockMetaMaskProvider.signMessage).toHaveBeenCalledWith(message);
    });

    it('should get address', async () => {
      const address = '0x123';
      mockMetaMaskProvider.getAddress.mockResolvedValue(address);

      const result = await walletManager.getAddress();
      expect(result).toBe(address);
      expect(mockMetaMaskProvider.getAddress).toHaveBeenCalled();
    });

    it('should get balance', async () => {
      const balance = '1.0';
      mockMetaMaskProvider.getBalance.mockResolvedValue(balance);

      const result = await walletManager.getBalance();
      expect(result).toBe(balance);
      expect(mockMetaMaskProvider.getBalance).toHaveBeenCalled();
    });

    it('should switch network', async () => {
      const chainId = 1;
      mockMetaMaskProvider.switchNetwork.mockResolvedValue(undefined);

      await walletManager.switchNetwork(chainId);
      expect(mockMetaMaskProvider.switchNetwork).toHaveBeenCalledWith(chainId);
    });

    it('should get chain ID', async () => {
      const chainId = 1;
      mockMetaMaskProvider.getChainId.mockResolvedValue(chainId);

      const result = await walletManager.getChainId();
      expect(result).toBe(chainId);
      expect(mockMetaMaskProvider.getChainId).toHaveBeenCalled();
    });
  });
}); 