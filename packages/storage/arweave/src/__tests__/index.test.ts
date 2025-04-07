import { ArweaveStorage } from '../index';
import Arweave from 'arweave';
import { JWKInterface } from 'arweave/node/lib/wallet';
import { ApiConfig } from 'arweave/node/lib/api';

interface ArweaveConfig {
  host: string;
  port: number;
  protocol: string;
  timeout: number;
  logging: boolean;
}

interface QueryOptions {
  first?: number;
  after?: string;
  minBlockHeight?: number;
  maxBlockHeight?: number;
  sortBy?: string;
}

interface QueryResult<T> {
  items: T[];
  pageInfo: {
    hasNextPage: boolean;
    endCursor?: string;
  };
}

const mockArweaveInstance = {
  transactions: {
    sign: jest.fn(),
    post: jest.fn(),
    get: jest.fn(),
    getData: jest.fn(),
    createTransaction: jest.fn()
  },
  wallets: {
    jwkToAddress: jest.fn(),
    getBalance: jest.fn()
  },
  ar: {
    winstonToAr: jest.fn(),
    artoWinston: jest.fn()
  },
  arql: jest.fn(),
  api: {
    post: jest.fn()
  }
};

jest.mock('arweave', () => {
  return jest.fn().mockImplementation(() => mockArweaveInstance);
});

jest.mock('tweetnacl', () => ({
  box: {
    keyPair: () => ({
      publicKey: new Uint8Array([1, 2, 3]),
      secretKey: new Uint8Array([4, 5, 6])
    }),
    before: () => new Uint8Array([7, 8, 9]),
    open: () => new Uint8Array([10, 11, 12])
  },
  randomBytes: (size: number) => new Uint8Array(size).fill(1)
}));

describe('ArweaveStorage', () => {
  let storage: ArweaveStorage;
  let mockWallet: JWKInterface;

  beforeEach(() => {
    mockWallet = { kty: 'RSA', n: 'test', e: 'test' };
    
    // Reset mock calls
    jest.clearAllMocks();

    storage = new ArweaveStorage({
      host: 'localhost',
      port: 1984,
      protocol: 'http',
      timeout: 20000,
      logging: false
    });
  });

  describe('Encryption', () => {
    it('should generate encryption keys', async () => {
      const publicKey = await storage.generateEncryptionKeys();
      expect(publicKey).toBeDefined();
    });

    it('should set encryption keys', async () => {
      await storage.setEncryptionKeys('base64PublicKey', 'base64SecretKey');
      // No error means success
    });
  });

  describe('Data Storage', () => {
    beforeEach(() => {
      mockArweaveInstance.transactions.createTransaction.mockResolvedValue({
        id: 'test-tx-id',
        addTag: jest.fn()
      });
      mockArweaveInstance.transactions.sign.mockResolvedValue(undefined);
      mockArweaveInstance.transactions.post.mockResolvedValue({ status: 200 });
      storage.setWallet(mockWallet);
    });

    it('should store data', async () => {
      const data = 'test data';
      const metadata = { contentType: 'text/plain', timestamp: Date.now().toString() };
      
      const txId = await storage.store(data, metadata);
      expect(txId).toBe('test-tx-id');
      expect(mockArweaveInstance.transactions.createTransaction).toHaveBeenCalled();
    });

    it('should store data bundle', async () => {
      const items = [
        { data: 'item1', metadata: { contentType: 'text/plain' } },
        { data: 'item2', metadata: { contentType: 'text/plain' } }
      ];

      const txId = await storage.storeBundle(items);
      expect(txId).toBe('test-tx-id');
    });
  });

  describe('Data Retrieval and Querying', () => {
    beforeEach(() => {
      mockArweaveInstance.transactions.getData.mockResolvedValue('test data');
      mockArweaveInstance.transactions.get.mockResolvedValue({
        id: 'test-tx-id',
        get: jest.fn().mockImplementation((key) => {
          if (key === 'data') return 'test data';
          if (key === 'tags') return [];
          return null;
        })
      });
    });

    it('should retrieve data', async () => {
      const result = await storage.retrieve('test-tx-id');
      expect(result.data).toBeDefined();
      expect(result.metadata).toBeDefined();
    });

    it('should query data', async () => {
      const tags = [{ name: 'Content-Type', value: 'text/plain' }];
      mockArweaveInstance.api.post.mockResolvedValue({
        status: 200,
        data: {
          data: {
            transactions: {
              edges: [
                { node: { id: 'tx1' }, cursor: 'cursor1' },
                { node: { id: 'tx2' }, cursor: 'cursor2' }
              ],
              pageInfo: {
                hasNextPage: false
              }
            }
          }
        }
      });

      const result = await storage.query(tags);
      expect(result.items).toHaveLength(2);
      expect(result.pageInfo.hasNextPage).toBe(false);
    });
  });

  describe('Specialized Methods', () => {
    beforeEach(() => {
      mockArweaveInstance.api.post.mockResolvedValue({
        status: 200,
        data: {
          data: {
            transactions: {
              edges: [
                { node: { id: 'tx1' }, cursor: 'cursor1' },
                { node: { id: 'tx2' }, cursor: 'cursor2' }
              ],
              pageInfo: {
                hasNextPage: false
              }
            }
          }
        }
      });
    });

    it('should get agent configs', async () => {
      const result = await storage.getAgentConfigs('agent-1');
      expect(result.items).toHaveLength(2);
      expect(result.pageInfo.hasNextPage).toBe(false);
    });

    it('should get training data', async () => {
      const result = await storage.getTrainingData('model-1');
      expect(result.items).toHaveLength(2);
      expect(result.pageInfo.hasNextPage).toBe(false);
    });
  });
}); 