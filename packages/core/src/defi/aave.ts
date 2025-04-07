import { ethers } from 'ethers';
import { WalletAdapter } from '../../wallets/common/src/types';

export interface AaveConfig {
  chainId: number;
  rpcUrl: string;
  lendingPoolAddress: string;
  dataProviderAddress: string;
}

export interface ReserveData {
  availableLiquidity: string;
  totalStableDebt: string;
  totalVariableDebt: string;
  liquidityRate: string;
  variableBorrowRate: string;
  stableBorrowRate: string;
  utilizationRate: string;
}

export interface UserAccountData {
  totalCollateralETH: string;
  totalDebtETH: string;
  availableBorrowsETH: string;
  currentLiquidationThreshold: string;
  ltv: string;
  healthFactor: string;
}

export class AaveProtocol {
  private config: AaveConfig;
  private lendingPool: ethers.Contract;
  private dataProvider: ethers.Contract;
  private wallet: WalletAdapter;

  constructor(config: AaveConfig, wallet: WalletAdapter) {
    this.config = config;
    this.wallet = wallet;
  }

  async connect() {
    const provider = new ethers.JsonRpcProvider(this.config.rpcUrl);
    const signer = await provider.getSigner(await this.wallet.getAddress());

    // Initialize contracts with minimal ABIs for the functions we need
    this.lendingPool = new ethers.Contract(
      this.config.lendingPoolAddress,
      [
        'function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode)',
        'function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf)',
        'function repay(address asset, uint256 amount, uint256 rateMode, address onBehalfOf)',
        'function withdraw(address asset, uint256 amount, address to)',
        'function getUserAccountData(address user) view returns (uint256, uint256, uint256, uint256, uint256, uint256)'
      ],
      signer
    );

    this.dataProvider = new ethers.Contract(
      this.config.dataProviderAddress,
      [
        'function getReserveData(address asset) view returns (tuple(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256))'
      ],
      provider
    );
  }

  async deposit(asset: string, amount: string): Promise<string> {
    const tx = await this.lendingPool.deposit(
      asset,
      amount,
      await this.wallet.getAddress(),
      0 // referralCode
    );
    return tx.hash;
  }

  async borrow(asset: string, amount: string, interestRateMode: number): Promise<string> {
    const tx = await this.lendingPool.borrow(
      asset,
      amount,
      interestRateMode,
      0, // referralCode
      await this.wallet.getAddress()
    );
    return tx.hash;
  }

  async repay(asset: string, amount: string, interestRateMode: number): Promise<string> {
    const tx = await this.lendingPool.repay(
      asset,
      amount,
      interestRateMode,
      await this.wallet.getAddress()
    );
    return tx.hash;
  }

  async withdraw(asset: string, amount: string): Promise<string> {
    const tx = await this.lendingPool.withdraw(
      asset,
      amount,
      await this.wallet.getAddress()
    );
    return tx.hash;
  }

  async getReserveData(asset: string): Promise<ReserveData> {
    const data = await this.dataProvider.getReserveData(asset);
    return {
      availableLiquidity: data[0].toString(),
      totalStableDebt: data[1].toString(),
      totalVariableDebt: data[2].toString(),
      liquidityRate: data[3].toString(),
      variableBorrowRate: data[4].toString(),
      stableBorrowRate: data[5].toString(),
      utilizationRate: data[6].toString()
    };
  }

  async getUserAccountData(user: string): Promise<UserAccountData> {
    const data = await this.lendingPool.getUserAccountData(user);
    return {
      totalCollateralETH: data[0].toString(),
      totalDebtETH: data[1].toString(),
      availableBorrowsETH: data[2].toString(),
      currentLiquidationThreshold: data[3].toString(),
      ltv: data[4].toString(),
      healthFactor: data[5].toString()
    };
  }
} 