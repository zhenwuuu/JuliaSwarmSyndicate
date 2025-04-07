import { BaseProvider } from '../providers/BaseProvider';
import { SUPPORTED_CHAINS } from '../types';
import { WalletLogger } from '../utils/logger';

// Skip these tests in CI/CD unless explicitly enabled
const SKIP_INTEGRATION_TESTS = process.env.SKIP_INTEGRATION_TESTS === 'true';

describe('Real Wallet Integration Tests', () => {
  let provider: BaseProvider;
  let logger: WalletLogger;

  beforeAll(() => {
    provider = new BaseProvider();
    logger = WalletLogger.getInstance();
  });

  afterAll(async () => {
    await provider.disconnect();
  });

  // Only run these tests if explicitly enabled
  if (!SKIP_INTEGRATION_TESTS) {
    it('should connect to real wallet', async () => {
      try {
        await provider.connect();
        const address = await provider.getAddress();
        const chainId = await provider.getChainId();
        
        expect(address).toBeTruthy();
        expect(chainId).toBeTruthy();
        
        logger.info('Successfully connected to real wallet', {
          address,
          chainId
        });
      } catch (error) {
        logger.error('Failed to connect to real wallet', error as Error);
        throw error;
      }
    });

    it('should switch networks', async () => {
      try {
        // Switch to Base Goerli
        await provider.switchNetwork(SUPPORTED_CHAINS.baseGoerli.chainId);
        let chainId = await provider.getChainId();
        expect(chainId).toBe(SUPPORTED_CHAINS.baseGoerli.chainId);

        // Switch to Base Mainnet
        await provider.switchNetwork(SUPPORTED_CHAINS.base.chainId);
        chainId = await provider.getChainId();
        expect(chainId).toBe(SUPPORTED_CHAINS.base.chainId);

        logger.info('Successfully switched networks');
      } catch (error) {
        logger.error('Failed to switch networks', error as Error);
        throw error;
      }
    });

    it('should get wallet balance', async () => {
      try {
        const balance = await provider.getBalance();
        expect(balance).toBeTruthy();
        
        logger.info('Successfully retrieved wallet balance', { balance });
      } catch (error) {
        logger.error('Failed to get wallet balance', error as Error);
        throw error;
      }
    });

    it('should sign message', async () => {
      try {
        const message = 'Test message for signing';
        const signature = await provider.signMessage(message);
        
        expect(signature).toBeTruthy();
        expect(signature.length).toBeGreaterThan(0);
        
        logger.info('Successfully signed message', { signature });
      } catch (error) {
        logger.error('Failed to sign message', error as Error);
        throw error;
      }
    });

    // Only run this test if TEST_AMOUNT environment variable is set
    if (process.env.TEST_AMOUNT) {
      it('should send test transaction', async () => {
        try {
          const testAmount = process.env.TEST_AMOUNT;
          const testAddress = process.env.TEST_ADDRESS;
          
          if (!testAddress) {
            throw new Error('TEST_ADDRESS environment variable not set');
          }

          const tx = await provider.sendTransaction({
            to: testAddress,
            value: testAmount
          });

          expect(tx.hash).toBeTruthy();
          
          logger.info('Successfully sent test transaction', {
            hash: tx.hash,
            amount: testAmount,
            to: testAddress
          });
        } catch (error) {
          logger.error('Failed to send test transaction', error as Error);
          throw error;
        }
      });
    }
  } else {
    it('skipping integration tests', () => {
      console.log('Integration tests skipped. Set SKIP_INTEGRATION_TESTS=false to run them.');
    });
  }
}); 