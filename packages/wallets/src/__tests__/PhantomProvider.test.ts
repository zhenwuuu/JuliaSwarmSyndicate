import { PhantomProvider } from '../providers/PhantomProvider';
import { Connection, PublicKey, Transaction, VersionedTransaction } from '@solana/web3.js';

// Mock @solana/web3.js
jest.mock('@solana/web3.js', () => ({
  Connection: jest.fn(),
  PublicKey: jest.fn(),
  Transaction: jest.fn(),
  VersionedTransaction: jest.fn(),
}));

describe('PhantomProvider', () => {
  let provider: PhantomProvider;
  let mockConnection: any;
  let mockPublicKey: any;

  beforeEach(() => {
    // Reset mocks
    jest.clearAllMocks();

    // Mock window.solana
    global.window = {
      solana: {
        isPhantom: true,
        connect: jest.fn(),
        disconnect: jest.fn(),
        signMessage: jest.fn(),
        signTransaction: jest.fn(),
        signAllTransactions: jest.fn(),
        on: jest.fn(),
        removeListener: jest.fn(),
      },
    } as any;

    // Mock Solana connection and public key
    mockPublicKey = {
      toString: jest.fn(),
    };

    mockConnection = {
      getBalance: jest.fn(),
    };

    (Connection as jest.Mock).mockImplementation(() => mockConnection);
    (PublicKey as jest.Mock).mockImplementation(() => mockPublicKey);

    provider = new PhantomProvider();
  });

  describe('checkAvailability', () => {
    it('should return true if Phantom is available', () => {
      expect(provider.isAvailable()).toBe(true);
    });

    it('should return false if window.solana is not available', () => {
      delete (global.window as any).solana;
      expect(provider.isAvailable()).toBe(false);
    });

    it('should return false if Phantom is not detected', () => {
      (global.window as any).solana.isPhantom = false;
      expect(provider.isAvailable()).toBe(false);
    });
  });

  describe('connect', () => {
    it('should connect successfully', async () => {
      const address = 'ABC123';
      const balance = 1000000000; // 1 SOL in lamports

      mockPublicKey.toString.mockReturnValue(address);
      mockConnection.getBalance.mockResolvedValue(balance);

      await provider.connect();

      expect(window.solana.connect).toHaveBeenCalled();
      expect(mockConnection.getBalance).toHaveBeenCalledWith(mockPublicKey);
    });

    it('should throw error if Phantom is not available', async () => {
      delete (global.window as any).solana;
      await expect(provider.connect()).rejects.toThrow('Phantom wallet is not available');
    });

    it('should handle connection errors', async () => {
      const error = new Error('Connection failed');
      window.solana.connect.mockRejectedValue(error);

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
      const signature = new Uint8Array([1, 2, 3]);
      window.solana.signMessage.mockResolvedValue({ signature });

      const result = await provider.signMessage(message);
      expect(result).toBe('010203');
      expect(window.solana.signMessage).toHaveBeenCalledWith(new TextEncoder().encode(message));
    });

    it('should throw error if not connected', async () => {
      await expect(provider.signMessage('test')).rejects.toThrow('Wallet not connected');
    });
  });

  describe('getAddress', () => {
    it('should return address', async () => {
      const address = 'ABC123';
      mockPublicKey.toString.mockReturnValue(address);

      const result = await provider.getAddress();
      expect(result).toBe(address);
      expect(mockPublicKey.toString).toHaveBeenCalled();
    });

    it('should throw error if not connected', async () => {
      await expect(provider.getAddress()).rejects.toThrow('Wallet not connected');
    });
  });

  describe('getBalance', () => {
    it('should return balance in SOL', async () => {
      const balance = 1000000000; // 1 SOL in lamports
      mockConnection.getBalance.mockResolvedValue(balance);

      const result = await provider.getBalance();
      expect(result).toBe('1');
      expect(mockConnection.getBalance).toHaveBeenCalledWith(mockPublicKey);
    });

    it('should throw error if not connected', async () => {
      await expect(provider.getBalance()).rejects.toThrow('Wallet not connected');
    });
  });

  describe('switchNetwork', () => {
    it('should throw error as network switching is not supported', async () => {
      await expect(provider.switchNetwork(1)).rejects.toThrow('Network switching not supported for Solana');
    });
  });

  describe('getChainId', () => {
    it('should return 0 as Solana does not use chain IDs', async () => {
      const result = await provider.getChainId();
      expect(result).toBe(0);
    });
  });

  describe('getPublicKey', () => {
    it('should return public key', async () => {
      const result = await provider.getPublicKey();
      expect(result).toBe(mockPublicKey);
    });

    it('should throw error if not connected', async () => {
      await expect(provider.getPublicKey()).rejects.toThrow('Wallet not connected');
    });
  });

  describe('signTransaction', () => {
    it('should sign transaction successfully', async () => {
      const transaction = new Transaction();
      window.solana.signTransaction.mockResolvedValue(transaction);

      const result = await provider.signTransaction(transaction);
      expect(result).toBe(transaction);
      expect(window.solana.signTransaction).toHaveBeenCalledWith(transaction);
    });

    it('should throw error if not connected', async () => {
      await expect(provider.signTransaction(new Transaction())).rejects.toThrow('Wallet not connected');
    });
  });

  describe('signAllTransactions', () => {
    it('should sign all transactions successfully', async () => {
      const transactions = [new Transaction(), new Transaction()];
      window.solana.signAllTransactions.mockResolvedValue(transactions);

      const result = await provider.signAllTransactions(transactions);
      expect(result).toBe(transactions);
      expect(window.solana.signAllTransactions).toHaveBeenCalledWith(transactions);
    });

    it('should throw error if not connected', async () => {
      await expect(provider.signAllTransactions([new Transaction()])).rejects.toThrow('Wallet not connected');
    });
  });
}); 