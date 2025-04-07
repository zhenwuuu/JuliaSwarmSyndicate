import { ethers } from 'ethers';
import { BaseProvider } from '../providers/BaseProvider';
import { SUPPORTED_CHAINS } from '../types';
import { WalletLogger } from '../utils/logger';
import { RateLimiter } from '../utils/rateLimiter';

// Mock ethers
jest.mock('ethers', () => ({
  ...jest.requireActual('ethers'),
  BrowserProvider: jest.fn(),
  Contract: jest.fn(),
  formatEther: jest.fn(),
  parseEther: jest.fn(),
  parseUnits: jest.fn()
}));

// Mock window.ethereum
const mockEthereum = {
  request: jest.fn(),
  on: jest.fn(),
  removeListener: jest.fn(),
  isConnected: jest.fn(),
  selectedAddress: null,
  networkVersion: null
};

Object.defineProperty(window, 'ethereum', {
  value: mockEthereum,
  writable: true
});

describe('BaseProvider', () => {
  let provider: BaseProvider;
  let mockSigner: any;
  let mockContract: any;
  let mockBrowserProvider: any;

  beforeEach(() => {
    // Reset mocks
    jest.clearAllMocks();

    // Setup mock signer
    mockSigner = {
      getAddress: jest.fn(),
      signMessage: jest.fn(),
      sendTransaction: jest.fn(),
      getBalance: jest.fn()
    };

    // Setup mock contract
    mockContract = {
      deposit: jest.fn(),
      withdraw: jest.fn(),
      getWithdrawalStatus: jest.fn(),
      on: jest.fn(),
      removeAllListeners: jest.fn()
    };

    // Setup mock browser provider
    mockBrowserProvider = {
      getSigner: jest.fn(),
      getNetwork: jest.fn(),
      getBalance: jest.fn(),
      waitForTransaction: jest.fn(),
      getFeeData: jest.fn()
    };

    // Setup ethers mocks
    (ethers.BrowserProvider as jest.Mock).mockImplementation(() => mockBrowserProvider);
    (ethers.Contract as jest.Mock).mockImplementation(() => mockContract);
    (ethers.formatEther as jest.Mock).mockImplementation((value) => value.toString());
    (ethers.parseEther as jest.Mock).mockImplementation((value) => BigInt(value));
    (ethers.parseUnits as jest.Mock).mockImplementation((value) => BigInt(value));

    provider = new BaseProvider();
  });

  describe('Initialization', () => {
    it('should initialize with correct state', () => {
      expect(provider['state']).toEqual({
        address: null,
        chainId: null,
        isConnected: false,
        isConnecting: false,
        error: null,
        supportedChains: expect.any(Array)
      });
    });

    it('should validate Base chain configuration', () => {
      const baseChains = [SUPPORTED_CHAINS.base, SUPPORTED_CHAINS.baseGoerli];
      expect(provider['state'].supportedChains).toEqual(
        expect.arrayContaining(baseChains)
      );
    });
  });

  describe('Connection', () => {
    it('should connect successfully', async () => {
      const mockAddress = '0x123';
      const mockChainId = SUPPORTED_CHAINS.base.chainId;

      mockEthereum.isConnected.mockReturnValue(true);
      mockBrowserProvider.getSigner.mockResolvedValue(mockSigner);
      mockBrowserProvider.getNetwork.mockResolvedValue({ chainId: mockChainId });
      mockSigner.getAddress.mockResolvedValue(mockAddress);

      await provider.connect();

      expect(provider['state']).toEqual({
        address: mockAddress,
        chainId: mockChainId,
        isConnected: true,
        isConnecting: false,
        error: null,
        supportedChains: expect.any(Array)
      });
    });

    it('should handle connection errors', async () => {
      const error = new Error('Connection failed');
      mockEthereum.isConnected.mockImplementation(() => {
        throw error;
      });

      await expect(provider.connect()).rejects.toThrow(error);
      expect(provider['state'].error).toBe(error);
    });
  });

  describe('Transaction Handling', () => {
    beforeEach(async () => {
      // Setup connected state
      mockEthereum.isConnected.mockReturnValue(true);
      mockBrowserProvider.getSigner.mockResolvedValue(mockSigner);
      mockBrowserProvider.getNetwork.mockResolvedValue({ chainId: SUPPORTED_CHAINS.base.chainId });
      mockSigner.getAddress.mockResolvedValue('0x123');
      await provider.connect();
    });

    it('should send transaction successfully', async () => {
      const mockTx = {
        to: '0x456',
        value: '1.0'
      };

      const mockResponse = {
        hash: '0x789',
        wait: jest.fn().mockResolvedValue({ hash: '0x789' })
      };

      mockSigner.sendTransaction.mockResolvedValue(mockResponse);
      mockBrowserProvider.waitForTransaction.mockResolvedValue({ hash: '0x789' });

      const result = await provider.sendTransaction(mockTx);

      expect(result).toEqual({ hash: '0x789' });
      expect(mockSigner.sendTransaction).toHaveBeenCalledWith(expect.objectContaining(mockTx));
    });

    it('should handle transaction errors', async () => {
      const error = new Error('Transaction failed');
      mockSigner.sendTransaction.mockRejectedValue(error);

      await expect(provider.sendTransaction({})).rejects.toThrow(error);
    });
  });

  describe('Cross-Chain Transactions', () => {
    beforeEach(async () => {
      // Setup connected state
      mockEthereum.isConnected.mockReturnValue(true);
      mockBrowserProvider.getSigner.mockResolvedValue(mockSigner);
      mockBrowserProvider.getNetwork.mockResolvedValue({ chainId: SUPPORTED_CHAINS.base.chainId });
      mockSigner.getAddress.mockResolvedValue('0x123');
      await provider.connect();
    });

    it('should send cross-chain transaction successfully', async () => {
      const mockTx = {
        fromChain: SUPPORTED_CHAINS.base.chainId,
        toChain: SUPPORTED_CHAINS.ethereum.chainId,
        fromAddress: '0x123',
        toAddress: '0x456',
        amount: '1.0'
      };

      const mockResponse = {
        hash: '0x789',
        wait: jest.fn().mockResolvedValue({
          hash: '0x789',
          logs: [{
            eventName: 'DepositInitiated',
            args: { depositId: 'deposit123' }
          }]
        })
      };

      mockContract.deposit.mockResolvedValue(mockResponse);
      mockBrowserProvider.waitForTransaction.mockResolvedValue({ hash: '0x789' });

      const result = await provider.sendCrossChainTransaction(mockTx);

      expect(result).toBe('deposit123');
      expect(mockContract.deposit).toHaveBeenCalled();
    });

    it('should validate bridge transaction parameters', async () => {
      const mockTx = {
        fromChain: SUPPORTED_CHAINS.base.chainId,
        toChain: SUPPORTED_CHAINS.ethereum.chainId,
        fromAddress: '0x123',
        toAddress: '0x456',
        amount: '0.0001' // Below minimum
      };

      await expect(provider.sendCrossChainTransaction(mockTx))
        .rejects
        .toThrow('Amount below minimum deposit');
    });
  });

  describe('Rate Limiting', () => {
    it('should respect rate limits for RPC calls', async () => {
      const rateLimiter = RateLimiter.getInstance();
      const startTime = Date.now();

      // Make multiple requests
      const requests = Array(10).fill(null).map(() => 
        rateLimiter.enqueue(() => Promise.resolve())
      );

      await Promise.all(requests);
      const duration = Date.now() - startTime;

      // Should take at least 200ms (10 requests at 50 requests per second)
      expect(duration).toBeGreaterThanOrEqual(200);
    });
  });

  describe('Logging', () => {
    it('should log important events', async () => {
      const logger = WalletLogger.getInstance();
      const mockAddress = '0x123';
      const mockChainId = SUPPORTED_CHAINS.base.chainId;

      mockEthereum.isConnected.mockReturnValue(true);
      mockBrowserProvider.getSigner.mockResolvedValue(mockSigner);
      mockBrowserProvider.getNetwork.mockResolvedValue({ chainId: mockChainId });
      mockSigner.getAddress.mockResolvedValue(mockAddress);

      await provider.connect();

      const logs = logger.getLogs();
      expect(logs).toContainEqual(
        expect.objectContaining({
          message: expect.stringContaining('Connected'),
          address: mockAddress,
          chainId: mockChainId
        })
      );
    });
  });

  describe('Error Handling', () => {
    it('should handle network errors gracefully', async () => {
      const error = new Error('Network error');
      mockBrowserProvider.getNetwork.mockRejectedValue(error);

      await expect(provider.connect()).rejects.toThrow(error);
      expect(provider['state'].error).toBe(error);
    });

    it('should handle provider errors gracefully', async () => {
      const error = new Error('Provider error');
      mockEthereum.request.mockRejectedValue(error);

      await expect(provider.switchNetwork(1)).rejects.toThrow(error);
      expect(provider['state'].error).toBe(error);
    });
  });

  describe('Cleanup', () => {
    it('should clean up event listeners on disconnect', async () => {
      await provider.connect();
      await provider.disconnect();

      expect(mockEthereum.removeListener).toHaveBeenCalledWith('accountsChanged', expect.any(Function));
      expect(mockEthereum.removeListener).toHaveBeenCalledWith('chainChanged', expect.any(Function));
      expect(mockEthereum.removeListener).toHaveBeenCalledWith('disconnect', expect.any(Function));
    });
  });
}); 