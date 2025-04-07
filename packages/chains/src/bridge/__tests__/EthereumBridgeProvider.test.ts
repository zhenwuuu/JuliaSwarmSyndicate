import { ethers } from 'ethers';
import { EthereumBridgeProvider } from '../EthereumBridgeProvider';
import { BridgeConfig, BridgeTransactionStatus } from '../types';

describe('EthereumBridgeProvider', () => {
  const mockConfigs: BridgeConfig[] = [
    {
      sourceChainId: 1,
      targetChainId: 137,
      sourceTokenAddress: '0x1234567890123456789012345678901234567890',
      targetTokenAddress: '0x0987654321098765432109876543210987654321',
      bridgeContractAddress: '0xabcdefabcdefabcdefabcdefabcdefabcdefabcd',
      minAmount: ethers.parseEther('0.1'),
      maxAmount: ethers.parseEther('100'),
      fees: {
        percentage: 0.1,
        fixed: ethers.parseEther('0.01')
      }
    }
  ];

  const mockProviderUrls = new Map([
    [1, 'https://mainnet.example.com'],
    [137, 'https://polygon.example.com']
  ]);

  let mockSigner: ethers.Signer;
  let bridgeProvider: EthereumBridgeProvider;

  beforeEach(() => {
    mockSigner = {
      connect: jest.fn().mockReturnThis(),
      getAddress: jest.fn().mockResolvedValue('0x1234567890123456789012345678901234567890')
    } as unknown as ethers.Signer;

    bridgeProvider = new EthereumBridgeProvider(
      mockConfigs,
      mockProviderUrls,
      mockSigner
    );
  });

  describe('getSupportedChains', () => {
    it('should return all supported chains', async () => {
      const chains = await bridgeProvider.getSupportedChains();
      expect(chains).toContain(1);
      expect(chains).toContain(137);
      expect(chains.length).toBe(2);
    });
  });

  describe('getConfig', () => {
    it('should return config for supported chain pair', async () => {
      const config = await bridgeProvider.getConfig(1, 137);
      expect(config).toEqual(mockConfigs[0]);
    });

    it('should throw error for unsupported chain pair', async () => {
      await expect(bridgeProvider.getConfig(1, 56))
        .rejects
        .toThrow('Bridge configuration not found for chains 1 -> 56');
    });
  });

  describe('initiate', () => {
    it('should validate transaction parameters', async () => {
      const amount = ethers.parseEther('0.05'); // Below minimum
      await expect(
        bridgeProvider.initiate(
          1,
          137,
          amount,
          '0x1234567890123456789012345678901234567890'
        )
      ).rejects.toThrow('Amount is below minimum');
    });

    it('should validate target address', async () => {
      const amount = ethers.parseEther('1');
      await expect(
        bridgeProvider.initiate(
          1,
          137,
          amount,
          'invalid-address'
        )
      ).rejects.toThrow('Invalid target address');
    });
  });

  describe('getStatus', () => {
    it('should throw error for non-existent transaction', async () => {
      await expect(bridgeProvider.getStatus('non-existent-id'))
        .rejects
        .toThrow('Transaction non-existent-id not found');
    });
  });
}); 