import { ethers } from 'ethers';
import { BridgeTransaction, BridgeStatus, BRIDGE_EVENTS, BRIDGE_CONFIG } from '../constants/bridge';
import { SUPPORTED_CHAINS } from '../types';

export class BridgeMonitor {
  private provider: ethers.Provider;
  private bridgeContract: ethers.Contract;
  private monitoringInterval: NodeJS.Timeout | null = null;
  private monitoredTransactions: Map<string, BridgeTransaction> = new Map();

  constructor(provider: ethers.Provider, bridgeContract: ethers.Contract) {
    this.provider = provider;
    this.bridgeContract = bridgeContract;
  }

  public startMonitoring(intervalMs: number = 30000): void {
    if (this.monitoringInterval) {
      return;
    }

    this.monitoringInterval = setInterval(() => {
      this.checkTransactions();
    }, intervalMs);
  }

  public stopMonitoring(): void {
    if (this.monitoringInterval) {
      clearInterval(this.monitoringInterval);
      this.monitoringInterval = null;
    }
  }

  public addTransaction(tx: BridgeTransaction): void {
    this.monitoredTransactions.set(tx.depositId || tx.withdrawalId || '', tx);
  }

  public removeTransaction(id: string): void {
    this.monitoredTransactions.delete(id);
  }

  public getTransaction(id: string): BridgeTransaction | undefined {
    return this.monitoredTransactions.get(id);
  }

  public getAllTransactions(): BridgeTransaction[] {
    return Array.from(this.monitoredTransactions.values());
  }

  private async checkTransactions(): Promise<void> {
    for (const [id, tx] of this.monitoredTransactions) {
      try {
        const status = await this.getTransactionStatus(tx);
        if (status !== tx.status) {
          tx.status = status;
          this.monitoredTransactions.set(id, tx);
          this.emitStatusUpdate(tx);
        }
      } catch (error) {
        console.error(`Error checking transaction ${id}:`, error);
        tx.status = BridgeStatus.FAILED;
        this.monitoredTransactions.set(id, tx);
        this.emitStatusUpdate(tx);
      }
    }
  }

  private async getTransactionStatus(tx: BridgeTransaction): Promise<BridgeStatus> {
    if (tx.depositId) {
      const isCompleted = await this.bridgeContract.getDepositStatus(tx.depositId);
      return isCompleted ? BridgeStatus.COMPLETED : BridgeStatus.PENDING;
    }
    if (tx.withdrawalId) {
      const isCompleted = await this.bridgeContract.getWithdrawalStatus(tx.withdrawalId);
      return isCompleted ? BridgeStatus.COMPLETED : BridgeStatus.PENDING;
    }
    return BridgeStatus.FAILED;
  }

  private emitStatusUpdate(tx: BridgeTransaction): void {
    // Emit event for status update
    this.bridgeContract.emit('bridgeTransactionStatusUpdate', tx);
  }

  public async estimateBridgeFee(
    fromChain: number,
    toChain: number,
    amount: string
  ): Promise<{
    bridgeFee: string;
    gasFee: string;
    totalFee: string;
  }> {
    const fromChainConfig = SUPPORTED_CHAINS[fromChain];
    const toChainConfig = SUPPORTED_CHAINS[toChain];

    if (!fromChainConfig || !toChainConfig) {
      throw new Error('Unsupported chain');
    }

    // Get bridge fee
    const bridgeFee = ethers.parseEther(BRIDGE_CONFIG[fromChain].fee);

    // Estimate gas fee
    const gasPrice = await this.provider.getFeeData();
    const estimatedGas = ethers.parseUnits('200000', 'wei'); // Estimated gas limit for bridge transaction
    const gasFee = (gasPrice.gasPrice || ethers.parseUnits('50', 'gwei')) * estimatedGas;

    // Calculate total fee
    const totalFee = bridgeFee + gasFee;

    return {
      bridgeFee: ethers.formatEther(bridgeFee),
      gasFee: ethers.formatEther(gasFee),
      totalFee: ethers.formatEther(totalFee)
    };
  }

  public async getBridgeTransactionHistory(
    address: string,
    fromBlock?: number,
    toBlock?: number
  ): Promise<BridgeTransaction[]> {
    const currentBlock = await this.provider.getBlockNumber();
    const from = fromBlock || currentBlock - 1000; // Default to last 1000 blocks
    const to = toBlock || currentBlock;

    const depositFilter = this.bridgeContract.filters.DepositInitiated(address);
    const withdrawalFilter = this.bridgeContract.filters.WithdrawalInitiated(address);

    const [depositLogs, withdrawalLogs] = await Promise.all([
      this.bridgeContract.queryFilter(depositFilter, from, to),
      this.bridgeContract.queryFilter(withdrawalFilter, from, to)
    ]);

    const transactions: BridgeTransaction[] = [];

    // Process deposit logs
    for (const log of depositLogs) {
      const eventLog = log as ethers.EventLog;
      const args = eventLog.args as any;
      const block = await this.provider.getBlock(eventLog.blockNumber);
      
      if (!block) {
        console.warn(`Block ${eventLog.blockNumber} not found`);
        continue;
      }

      transactions.push({
        fromChain: await this.provider.getNetwork().then(n => Number(n.chainId)),
        toChain: args.toChain,
        fromAddress: args.from,
        toAddress: args.to,
        amount: ethers.formatEther(args.amount),
        status: BridgeStatus.PENDING,
        depositId: args.depositId,
        timestamp: block.timestamp
      });
    }

    // Process withdrawal logs
    for (const log of withdrawalLogs) {
      const eventLog = log as ethers.EventLog;
      const args = eventLog.args as any;
      const block = await this.provider.getBlock(eventLog.blockNumber);
      
      if (!block) {
        console.warn(`Block ${eventLog.blockNumber} not found`);
        continue;
      }

      transactions.push({
        fromChain: await this.provider.getNetwork().then(n => Number(n.chainId)),
        toChain: args.toChain,
        fromAddress: args.from,
        toAddress: args.to,
        amount: ethers.formatEther(args.amount),
        status: BridgeStatus.PENDING,
        withdrawalId: args.withdrawalId,
        timestamp: block.timestamp
      });
    }

    return transactions;
  }
} 