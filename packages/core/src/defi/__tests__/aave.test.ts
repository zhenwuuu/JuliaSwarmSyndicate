import { AaveProtocol, AaveConfig } from '../aave';
import { WalletAdapter } from '../../../wallets/common/src/types';
import { ethers } from 'ethers';

// Mock wallet adapter
const mockWallet: WalletAdapter = {
  connect: jest.fn(),
  disconnect: jest.fn(),
  signTransaction: jest.fn(),
  signMessage: jest.fn(),
  getAddress: jest.fn().mockResolvedValue('0x1234567890123456789012345678901234567890')
};

// Mock config
const mockConfig: AaveConfig = {
  chainId: 1,
  rpcUrl: 'https://mainnet.example.com',
  lendingPoolAddress: '0xB53C1a33016B2DC2fF3653530bfF1848a515c8c5',
  dataProviderAddress: '0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d'
};

describe('AaveProtocol', () => {
  let aave: AaveProtocol;
  let mockProvider: jest.Mocked<ethers.JsonRpcProvider>;
  let mockSigner: jest.Mocked<ethers.Signer>;

  beforeEach(() => {
    // Mock provider and signer
    mockSigner = {
      provider: mockProvider,
      getAddress: jest.fn().mockResolvedValue('0x1234567890123456789012345678901234567890')
    } as unknown as jest.Mocked<ethers.Signer>;

    mockProvider = {
      getSigner: jest.fn().mockResolvedValue(mockSigner)
    } as unknown as jest.Mocked<ethers.JsonRpcProvider>;

    // Create instance
    aave = new AaveProtocol(mockConfig, mockWallet);
  });

  describe('deposit', () => {
    it('should deposit tokens successfully', async () => {
      const asset = '0xTokenAddress';
      const amount = '1000000000000000000'; // 1 ETH
      const txHash = '0xTransactionHash';

      // Mock contract call
      const mockContract = {
        deposit: jest.fn().mockResolvedValue({ hash: txHash })
      };

      (aave as any).lendingPool = mockContract;

      const result = await aave.deposit(asset, amount);
      expect(result).toBe(txHash);
      expect(mockContract.deposit).toHaveBeenCalledWith(
        asset,
        amount,
        await mockWallet.getAddress(),
        0
      );
    });
  });

  describe('borrow', () => {
    it('should borrow tokens successfully', async () => {
      const asset = '0xTokenAddress';
      const amount = '1000000000000000000'; // 1 ETH
      const interestRateMode = 2; // Variable rate
      const txHash = '0xTransactionHash';

      // Mock contract call
      const mockContract = {
        borrow: jest.fn().mockResolvedValue({ hash: txHash })
      };

      (aave as any).lendingPool = mockContract;

      const result = await aave.borrow(asset, amount, interestRateMode);
      expect(result).toBe(txHash);
      expect(mockContract.borrow).toHaveBeenCalledWith(
        asset,
        amount,
        interestRateMode,
        0,
        await mockWallet.getAddress()
      );
    });
  });

  describe('getReserveData', () => {
    it('should return reserve data successfully', async () => {
      const asset = '0xTokenAddress';
      const mockData = [
        '1000', // availableLiquidity
        '200',  // totalStableDebt
        '300',  // totalVariableDebt
        '400',  // liquidityRate
        '500',  // variableBorrowRate
        '600',  // stableBorrowRate
        '700'   // utilizationRate
      ];

      // Mock contract call
      const mockContract = {
        getReserveData: jest.fn().mockResolvedValue(mockData)
      };

      (aave as any).dataProvider = mockContract;

      const result = await aave.getReserveData(asset);
      expect(result).toEqual({
        availableLiquidity: '1000',
        totalStableDebt: '200',
        totalVariableDebt: '300',
        liquidityRate: '400',
        variableBorrowRate: '500',
        stableBorrowRate: '600',
        utilizationRate: '700'
      });
      expect(mockContract.getReserveData).toHaveBeenCalledWith(asset);
    });
  });

  describe('getUserAccountData', () => {
    it('should return user account data successfully', async () => {
      const user = '0xUserAddress';
      const mockData = [
        '1000', // totalCollateralETH
        '200',  // totalDebtETH
        '300',  // availableBorrowsETH
        '400',  // currentLiquidationThreshold
        '500',  // ltv
        '600'   // healthFactor
      ];

      // Mock contract call
      const mockContract = {
        getUserAccountData: jest.fn().mockResolvedValue(mockData)
      };

      (aave as any).lendingPool = mockContract;

      const result = await aave.getUserAccountData(user);
      expect(result).toEqual({
        totalCollateralETH: '1000',
        totalDebtETH: '200',
        availableBorrowsETH: '300',
        currentLiquidationThreshold: '400',
        ltv: '500',
        healthFactor: '600'
      });
      expect(mockContract.getUserAccountData).toHaveBeenCalledWith(user);
    });
  });
}); 