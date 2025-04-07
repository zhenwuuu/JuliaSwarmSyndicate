import { MCPBridge, MCPConfig } from '../index';
import { ethers } from 'ethers';
import { MerkleTree } from 'merkletreejs';
import { keccak256 } from 'ethers/lib/utils';

jest.mock('ethers', () => ({
  JsonRpcProvider: jest.fn(),
  Contract: jest.fn(),
}));

describe('MCPBridge', () => {
  let bridge: MCPBridge;
  let mockConfig: MCPConfig;
  let mockContract: any;

  beforeEach(() => {
    mockConfig = {
      supportedChains: ['ethereum', 'base'],
      rpcEndpoints: {
        ethereum: 'https://eth-mainnet.alchemyapi.io/v2/test',
        base: 'https://mainnet.base.org'
      },
      bridgeContracts: {
        ethereum: '0x1234...5678',
        base: '0x8765...4321'
      },
      merkleRoots: {
        ethereum: ['0xabc...def'],
        base: ['0xdef...abc']
      }
    };

    mockContract = {
      bridge: jest.fn(),
      claim: jest.fn(),
      updateMerkleRoot: jest.fn(),
      on: jest.fn(),
      off: jest.fn()
    };

    (ethers.Contract as jest.Mock).mockImplementation(() => mockContract);
    (ethers.JsonRpcProvider as jest.Mock).mockImplementation(() => ({}));

    bridge = new MCPBridge(mockConfig);
  });

  describe('sendCrossChainMessage', () => {
    it('should send a cross-chain message successfully', async () => {
      const mockTx = {
        wait: jest.fn().mockResolvedValue({
          events: [{
            event: 'TokensBridged',
            args: {
              messageHash: '0x123...456'
            }
          }]
        })
      };

      mockContract.bridge.mockResolvedValue(mockTx);

      const result = await bridge.sendCrossChainMessage(
        'ethereum',
        'base',
        '0x123...token',
        BigInt(1000000),
        '0x123...sender',
        '0x456...recipient'
      );

      expect(result).toBe('0x123...456');
      expect(mockContract.bridge).toHaveBeenCalledWith(
        '0x123...token',
        BigInt(1000000),
        '0x456...recipient',
        1 // base chain index
      );
    });

    it('should throw error for unsupported target chain', async () => {
      await expect(
        bridge.sendCrossChainMessage(
          'ethereum',
          'unsupported',
          '0x123...token',
          BigInt(1000000),
          '0x123...sender',
          '0x456...recipient'
        )
      ).rejects.toThrow('Target chain unsupported not supported');
    });
  });

  describe('verifyMessage', () => {
    it('should verify a valid message proof', async () => {
      const messageHash = '0x123...456';
      const proof = ['0xabc...def', '0xdef...abc'];
      
      const result = await bridge.verifyMessage(messageHash, proof, 'ethereum');
      expect(result).toBe(true);
    });

    it('should reject an invalid message proof', async () => {
      const messageHash = '0x123...456';
      const proof = ['0xinvalid...proof'];
      
      const result = await bridge.verifyMessage(messageHash, proof, 'ethereum');
      expect(result).toBe(false);
    });
  });

  describe('claimTokens', () => {
    it('should claim tokens successfully', async () => {
      const mockTx = {
        wait: jest.fn().mockResolvedValue({
          events: [{
            event: 'TokensClaimed',
            args: {
              token: '0x123...token',
              recipient: '0x456...recipient',
              amount: BigInt(1000000)
            }
          }]
        })
      };

      mockContract.claim.mockResolvedValue(mockTx);

      const result = await bridge.claimTokens(
        'base',
        '0x123...messageHash',
        '0x456...recipient',
        BigInt(1000000),
        '0x123...token',
        ['0xabc...def']
      );

      expect(result).toBe(true);
      expect(mockContract.claim).toHaveBeenCalledWith(
        '0x123...messageHash',
        '0x456...recipient',
        BigInt(1000000),
        '0x123...token'
      );
    });

    it('should throw error for invalid proof', async () => {
      mockContract.claim.mockRejectedValue(new Error('Invalid message proof'));

      await expect(
        bridge.claimTokens(
          'base',
          '0x123...messageHash',
          '0x456...recipient',
          BigInt(1000000),
          '0x123...token',
          ['0xinvalid...proof']
        )
      ).rejects.toThrow('Invalid message proof');
    });
  });

  describe('updateMerkleRoot', () => {
    it('should update merkle root successfully', async () => {
      const newRoot = '0xnew...root';
      mockContract.updateMerkleRoot.mockResolvedValue(undefined);

      await bridge.updateMerkleRoot('ethereum', newRoot);

      expect(mockContract.updateMerkleRoot).toHaveBeenCalledWith(newRoot);
      expect(mockConfig.merkleRoots.ethereum).toContain(newRoot);
    });

    it('should throw error for unsupported chain', async () => {
      await expect(
        bridge.updateMerkleRoot('unsupported', '0xnew...root')
      ).rejects.toThrow('Contract not found for chain unsupported');
    });
  });
}); 