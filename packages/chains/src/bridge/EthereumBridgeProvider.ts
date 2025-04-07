import { ethers, BigNumberish } from 'ethers';
import { ChainId } from '../types';
import { BaseBridgeProvider } from './BaseBridgeProvider';
import { BridgeTransaction, BridgeConfig } from './types';

export class EthereumBridgeProvider extends BaseBridgeProvider {
  private providers: Map<ChainId, ethers.JsonRpcProvider> = new Map();
  private bridgeContracts: Map<ChainId, ethers.Contract> = new Map();
  private signer: ethers.Signer;

  constructor(
    configs: BridgeConfig[],
    providerUrls: Map<ChainId, string>,
    signer: ethers.Signer
  ) {
    super();
    this.signer = signer;
    this.initializeProviders(providerUrls);
    this.initializeConfigs(configs);
  }

  private initializeProviders(providerUrls: Map<ChainId, string>) {
    for (const [chainId, url] of providerUrls.entries()) {
      this.providers.set(chainId, new ethers.JsonRpcProvider(url));
    }
  }

  private initializeConfigs(configs: BridgeConfig[]) {
    for (const config of configs) {
      const key = this.getConfigKey(config.sourceChainId, config.targetChainId);
      this.configs.set(key, config);
    }
  }

  protected async validateTransaction(
    sourceChainId: ChainId,
    targetChainId: ChainId,
    amount: BigNumberish,
    targetAddress: string
  ): Promise<void> {
    const config = await this.getConfig(sourceChainId, targetChainId);
    
    if (!ethers.isAddress(targetAddress)) {
      throw new Error('Invalid target address');
    }

    const amountBN = ethers.getBigInt(amount);
    const minAmountBN = ethers.getBigInt(config.minAmount);
    const maxAmountBN = ethers.getBigInt(config.maxAmount);

    if (amountBN < minAmountBN) {
      throw new Error(`Amount is below minimum (${config.minAmount})`);
    }

    if (amountBN > maxAmountBN) {
      throw new Error(`Amount is above maximum (${config.maxAmount})`);
    }
  }

  protected async executeSourceChainTransaction(
    transaction: BridgeTransaction
  ): Promise<string> {
    const config = await this.getConfig(
      transaction.sourceChainId,
      transaction.targetChainId
    );

    const sourceProvider = this.providers.get(transaction.sourceChainId);
    if (!sourceProvider) {
      throw new Error(`Provider not found for chain ${transaction.sourceChainId}`);
    }

    const bridgeContract = new ethers.Contract(
      config.bridgeContractAddress,
      [
        'function bridge(address token, uint256 amount, address recipient, uint256 targetChainId) payable returns (uint256)',
      ],
      this.signer.connect(sourceProvider)
    );

    const tx = await bridgeContract.bridge(
      config.sourceTokenAddress,
      transaction.amount,
      transaction.targetAddress,
      transaction.targetChainId,
      { value: ethers.getBigInt(0) }
    );

    return tx.hash;
  }

  protected async executeTargetChainTransaction(
    transaction: BridgeTransaction
  ): Promise<string> {
    const config = await this.getConfig(
      transaction.sourceChainId,
      transaction.targetChainId
    );

    const targetProvider = this.providers.get(transaction.targetChainId);
    if (!targetProvider) {
      throw new Error(`Provider not found for chain ${transaction.targetChainId}`);
    }

    const bridgeContract = new ethers.Contract(
      config.bridgeContractAddress,
      [
        'function claim(bytes32 messageHash, address recipient, uint256 amount, address token) returns (bool)',
      ],
      this.signer.connect(targetProvider)
    );

    const messageHash = ethers.keccak256(
      ethers.AbiCoder.defaultAbiCoder().encode(
        ['address', 'uint256', 'uint256', 'address'],
        [
          transaction.sourceAddress,
          transaction.amount,
          transaction.sourceChainId,
          transaction.targetAddress,
        ]
      )
    );

    const tx = await bridgeContract.claim(
      messageHash,
      transaction.targetAddress,
      transaction.amount,
      config.targetTokenAddress
    );

    return tx.hash;
  }

  async getSupportedChains(): Promise<ChainId[]> {
    const chains = new Set<ChainId>();
    for (const config of this.configs.values()) {
      chains.add(config.sourceChainId);
      chains.add(config.targetChainId);
    }
    return Array.from(chains);
  }
} 