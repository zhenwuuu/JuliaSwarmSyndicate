import { ethers } from 'ethers';
import { WalletAdapter } from '../../wallets/common/src/types';

export interface DeFiProtocolConfig {
  name: string;
  chainId: number;
  rpcUrl: string;
  contractAddress: string;
  abi: any[];
}

export interface SwapParams {
  tokenIn: string;
  tokenOut: string;
  amountIn: string;
  minAmountOut: string;
  deadline: number;
}

export interface LendingParams {
  asset: string;
  amount: string;
  interestRateMode: number;
}

export class DeFiProtocol {
  private config: DeFiProtocolConfig;
  private contract!: ethers.Contract;
  private wallet: WalletAdapter;

  constructor(config: DeFiProtocolConfig, wallet: WalletAdapter) {
    this.config = config;
    this.wallet = wallet;
  }

  async connect() {
    const provider = new ethers.JsonRpcProvider(this.config.rpcUrl);
    const signer = await provider.getSigner(await this.wallet.getAddress());
    this.contract = new ethers.Contract(
      this.config.contractAddress,
      this.config.abi,
      signer
    );
  }

  async swap(params: SwapParams): Promise<string> {
    const tx = await this.contract.swap(
      params.tokenIn,
      params.tokenOut,
      params.amountIn,
      params.minAmountOut,
      params.deadline
    );
    return tx.hash;
  }

  async supply(params: LendingParams): Promise<string> {
    const tx = await this.contract.supply(
      params.asset,
      params.amount,
      await this.wallet.getAddress(),
      0 // referralCode
    );
    return tx.hash;
  }

  async borrow(params: LendingParams): Promise<string> {
    const tx = await this.contract.borrow(
      params.asset,
      params.amount,
      params.interestRateMode,
      0, // referralCode
      await this.wallet.getAddress()
    );
    return tx.hash;
  }

  async getPrice(token: string): Promise<string> {
    return await this.contract.getAssetPrice(token);
  }

  async getLiquidityData(token: string): Promise<{
    totalSupply: string;
    availableLiquidity: string;
    utilizationRate: string;
  }> {
    const data = await this.contract.getReserveData(token);
    return {
      totalSupply: data.totalSupply.toString(),
      availableLiquidity: data.availableLiquidity.toString(),
      utilizationRate: data.utilizationRate.toString()
    };
  }
} 