import { BigNumberish } from 'ethers';
import { ChainId } from '../types';
import {
  BridgeConfig,
  BridgeTransaction,
  BridgeTransactionStatus,
  IBridgeProvider
} from './types';

export abstract class BaseBridgeProvider implements IBridgeProvider {
  protected transactions: Map<string, BridgeTransaction> = new Map();
  protected configs: Map<string, BridgeConfig> = new Map();

  protected abstract validateTransaction(
    sourceChainId: ChainId,
    targetChainId: ChainId,
    amount: BigNumberish,
    targetAddress: string
  ): Promise<void>;

  protected abstract executeSourceChainTransaction(
    transaction: BridgeTransaction
  ): Promise<string>;

  protected abstract executeTargetChainTransaction(
    transaction: BridgeTransaction
  ): Promise<string>;

  protected getConfigKey(sourceChainId: ChainId, targetChainId: ChainId): string {
    return `${sourceChainId}-${targetChainId}`;
  }

  async initiate(
    sourceChainId: ChainId,
    targetChainId: ChainId,
    amount: BigNumberish,
    targetAddress: string
  ): Promise<BridgeTransaction> {
    // Validate the transaction
    await this.validateTransaction(sourceChainId, targetChainId, amount, targetAddress);

    // Create transaction object
    const transaction: BridgeTransaction = {
      id: `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      sourceChainId,
      targetChainId,
      sourceAddress: '', // Will be set during execution
      targetAddress,
      amount,
      status: BridgeTransactionStatus.PENDING,
      timestamp: Date.now()
    };

    // Store transaction
    this.transactions.set(transaction.id, transaction);

    try {
      // Execute source chain transaction
      const sourceHash = await this.executeSourceChainTransaction(transaction);
      
      // Update transaction status
      transaction.sourceTransactionHash = sourceHash;
      transaction.status = BridgeTransactionStatus.SOURCE_CONFIRMED;
      this.transactions.set(transaction.id, transaction);

      return transaction;
    } catch (error: any) {
      transaction.status = BridgeTransactionStatus.FAILED;
      transaction.error = error?.message || 'Unknown error';
      this.transactions.set(transaction.id, transaction);
      throw error;
    }
  }

  async confirm(transactionId: string): Promise<BridgeTransaction> {
    const transaction = this.transactions.get(transactionId);
    if (!transaction) {
      throw new Error(`Transaction ${transactionId} not found`);
    }

    if (transaction.status !== BridgeTransactionStatus.SOURCE_CONFIRMED) {
      throw new Error(`Transaction ${transactionId} is not ready for confirmation`);
    }

    try {
      // Execute target chain transaction
      transaction.status = BridgeTransactionStatus.TARGET_INITIATED;
      const targetHash = await this.executeTargetChainTransaction(transaction);

      // Update transaction status
      transaction.targetTransactionHash = targetHash;
      transaction.status = BridgeTransactionStatus.TARGET_CONFIRMED;
      this.transactions.set(transaction.id, transaction);

      return transaction;
    } catch (error: any) {
      transaction.status = BridgeTransactionStatus.FAILED;
      transaction.error = error?.message || 'Unknown error';
      this.transactions.set(transaction.id, transaction);
      throw error;
    }
  }

  async getStatus(transactionId: string): Promise<BridgeTransactionStatus> {
    const transaction = this.transactions.get(transactionId);
    if (!transaction) {
      throw new Error(`Transaction ${transactionId} not found`);
    }
    return transaction.status;
  }

  abstract getSupportedChains(): Promise<ChainId[]>;

  async getConfig(sourceChainId: ChainId, targetChainId: ChainId): Promise<BridgeConfig> {
    const key = this.getConfigKey(sourceChainId, targetChainId);
    const config = this.configs.get(key);
    if (!config) {
      throw new Error(`Bridge configuration not found for chains ${sourceChainId} -> ${targetChainId}`);
    }
    return config;
  }
} 