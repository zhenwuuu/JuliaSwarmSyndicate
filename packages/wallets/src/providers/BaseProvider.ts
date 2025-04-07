import { ethers, Signer, Contract } from 'ethers';
import { EthereumWalletProvider, WalletError, CrossChainTransaction, SUPPORTED_CHAINS } from '../types';
import { BaseWalletProvider } from './BaseWalletProvider';
import { BRIDGE_CONTRACTS, BRIDGE_CONFIG, BRIDGE_EVENTS, BridgeStatus, BridgeTransaction } from '../constants/bridge';
import { BridgeMonitor } from '../services/BridgeMonitor';

const MAX_RETRIES = 3;
const RETRY_DELAY = 1000; // 1 second
const DEFAULT_CONFIRMATIONS = 1;

export class BaseProvider extends BaseWalletProvider implements EthereumWalletProvider {
  private provider: ethers.BrowserProvider | null = null;
  private signer: Signer | null = null;
  private bridgeContract: Contract | null = null;
  private bridgeMonitor: BridgeMonitor | null = null;
  private transactionQueue: Map<string, Promise<any>> = new Map();

  constructor() {
    super();
    this.validateBaseChainConfig();
  }

  private validateBaseChainConfig(): void {
    const baseChains = [SUPPORTED_CHAINS.base, SUPPORTED_CHAINS.baseGoerli];
    if (!baseChains.every(chain => this.state.supportedChains.includes(chain))) {
      throw new Error('Base chain configuration is missing');
    }
  }

  protected setupEventListeners(): void {
    if (typeof window !== 'undefined' && window.ethereum) {
      window.ethereum.on('accountsChanged', this.handleAccountsChanged.bind(this));
      window.ethereum.on('chainChanged', this.handleChainChanged.bind(this));
      window.ethereum.on('disconnect', this.handleDisconnect.bind(this));
    }
  }

  private handleAccountsChanged(accounts: string[]): void {
    if (accounts.length === 0) {
      this.handleDisconnect();
    } else {
      this.setState({ address: accounts[0] });
      this.emitEvent('accountsChanged', accounts[0]);
    }
  }

  private handleChainChanged(chainId: string): void {
    const numericChainId = parseInt(chainId, 16);
    this.setState({ chainId: numericChainId });
    this.emitEvent('chainChanged', numericChainId);
  }

  private handleDisconnect(): void {
    this.setState({
      address: null,
      chainId: null,
      isConnected: false
    });
    this.emitEvent('disconnect');
  }

  protected checkAvailability(): boolean {
    return typeof window !== 'undefined' && !!window.ethereum;
  }

  private async initializeBridgeMonitor(): Promise<void> {
    if (!this.provider || !this.bridgeContract) {
      throw new Error('Provider or bridge contract not initialized');
    }

    this.bridgeMonitor = new BridgeMonitor(this.provider, this.bridgeContract);
    this.bridgeMonitor.startMonitoring();

    // Listen for bridge transaction status updates
    this.bridgeContract.on('bridgeTransactionStatusUpdate', (tx: BridgeTransaction) => {
      this.emitEvent('bridgeTransactionStatusUpdate', tx);
    });
  }

  public async connect(): Promise<void> {
    try {
      this.setState({ isConnecting: true });

      if (!this.checkAvailability()) {
        throw new Error('Base provider is not available');
      }

      this.provider = new ethers.BrowserProvider(window.ethereum);
      const network = await this.provider.getNetwork();
      const chainId = Number(network.chainId);

      // Check if we're on a Base chain
      if (chainId !== SUPPORTED_CHAINS.base.chainId && chainId !== SUPPORTED_CHAINS.baseGoerli.chainId) {
        await this.switchNetwork(SUPPORTED_CHAINS.base.chainId);
      }

      this.signer = await this.provider.getSigner();
      const address = await this.signer.getAddress();

      // Initialize bridge contract and monitor
      this.bridgeContract = await this.getBridgeContract();
      await this.initializeBridgeMonitor();

      this.setState({
        address,
        chainId,
        isConnected: true,
        isConnecting: false,
        error: null
      });

      this.emitEvent('connect', { address, chainId });
    } catch (error: any) {
      this.handleError(error);
      throw error;
    } finally {
      this.setState({ isConnecting: false });
    }
  }

  public async disconnect(): Promise<void> {
    if (this.bridgeMonitor) {
      this.bridgeMonitor.stopMonitoring();
      this.bridgeMonitor = null;
    }
    this.provider = null;
    this.signer = null;
    this.bridgeContract = null;
    this.handleDisconnect();
  }

  public async signMessage(message: string): Promise<string> {
    try {
      if (!this.signer) {
        throw new Error('Not connected to Base');
      }
      return await this.signer.signMessage(message);
    } catch (error: any) {
      this.handleError(error);
      throw error;
    }
  }

  public async getAddress(): Promise<string> {
    if (!this.signer) {
      throw new Error('Not connected to Base');
    }
    return this.signer.getAddress();
  }

  public async getBalance(): Promise<string> {
    if (!this.signer || !this.provider) {
      throw new Error('Not connected to Base');
    }
    const address = await this.signer.getAddress();
    const balance = await this.provider.getBalance(address);
    return ethers.formatEther(balance);
  }

  public async switchNetwork(chainId: number): Promise<void> {
    if (!this.provider) {
      throw new Error('Provider not initialized');
    }

    const targetChain = Object.values(SUPPORTED_CHAINS).find(chain => chain.chainId === chainId);
    if (!targetChain) {
      throw new Error('Unsupported chain');
    }

    try {
      await window.ethereum.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: `0x${chainId.toString(16)}` }],
      });
    } catch (error: any) {
      if (error.code === 4902) {
        await window.ethereum.request({
          method: 'wallet_addEthereumChain',
          params: [{
            chainId: `0x${chainId.toString(16)}`,
            chainName: targetChain.name,
            nativeCurrency: targetChain.nativeCurrency,
            rpcUrls: [targetChain.rpcUrl],
            blockExplorerUrls: targetChain.blockExplorerUrl ? [targetChain.blockExplorerUrl] : undefined
          }],
        });
      } else {
        this.handleError(error);
        throw error;
      }
    }
  }

  public async getChainId(): Promise<number> {
    if (!this.provider) {
      throw new Error('Provider not initialized');
    }
    const network = await this.provider.getNetwork();
    return Number(network.chainId);
  }

  public async getSigner(): Promise<Signer> {
    if (!this.signer) {
      throw new Error('Not connected to Base');
    }
    return this.signer;
  }

  public async sendTransaction(transaction: any): Promise<any> {
    if (!this.signer) {
      throw new Error('Not connected to Base');
    }

    try {
      // Add Base-specific optimizations
      const chainId = await this.getChainId();
      if (chainId === SUPPORTED_CHAINS.base.chainId || chainId === SUPPORTED_CHAINS.baseGoerli.chainId) {
        // Optimize gas settings for Base
        transaction = {
          ...transaction,
          gasPrice: await this.provider!.getFeeData().then(fees => fees.gasPrice),
          maxPriorityFeePerGas: ethers.parseUnits('0.001', 'gwei'), // Base-specific priority fee
        };
      }

      const tx = await this.signer.sendTransaction(transaction);
      return await tx.wait();
    } catch (error: any) {
      this.handleError(error);
      throw error;
    }
  }

  private async getBridgeContract(): Promise<Contract> {
    if (!this.provider || !this.signer) {
      throw new Error('Provider or signer not initialized');
    }

    const chainId = await this.getChainId();
    const bridgeConfig = BRIDGE_CONTRACTS[chainId];
    
    if (!bridgeConfig) {
      throw new Error('Bridge contract not found for current chain');
    }

    return new Contract(
      bridgeConfig.address,
      bridgeConfig.abi,
      this.signer
    );
  }

  private async validateBridgeTransaction(tx: CrossChainTransaction): Promise<void> {
    const chainId = await this.getChainId();
    const bridgeConfig = BRIDGE_CONFIG[chainId];
    
    if (!bridgeConfig) {
      throw new Error('Bridge configuration not found for current chain');
    }

    const amount = ethers.parseEther(tx.amount);
    const minAmount = ethers.parseEther(bridgeConfig.minDepositAmount);
    const maxAmount = ethers.parseEther(bridgeConfig.maxDepositAmount);

    if (amount < minAmount) {
      throw new Error(`Amount below minimum deposit of ${bridgeConfig.minDepositAmount} ETH`);
    }

    if (amount > maxAmount) {
      throw new Error(`Amount above maximum deposit of ${bridgeConfig.maxDepositAmount} ETH`);
    }
  }

  private async waitForConfirmation(txHash: string, confirmations: number = DEFAULT_CONFIRMATIONS): Promise<void> {
    if (!this.provider) {
      throw new Error('Provider not initialized');
    }

    try {
      await this.provider.waitForTransaction(txHash, confirmations);
    } catch (error) {
      console.error(`Error waiting for confirmation of transaction ${txHash}:`, error);
      throw error;
    }
  }

  private async retryOperation<T>(
    operation: () => Promise<T>,
    maxRetries: number = MAX_RETRIES
  ): Promise<T> {
    let lastError: Error | null = null;
    
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await operation();
      } catch (error: any) {
        lastError = error;
        console.warn(`Attempt ${attempt} failed:`, error);
        
        if (attempt === maxRetries) {
          break;
        }
        
        // Exponential backoff
        await new Promise(resolve => 
          setTimeout(resolve, RETRY_DELAY * Math.pow(2, attempt - 1))
        );
      }
    }
    
    throw lastError || new Error('Operation failed after all retries');
  }

  private async estimateGasForTransaction(
    contract: Contract,
    method: string,
    args: any[],
    value?: bigint
  ): Promise<bigint> {
    try {
      // Type-safe way to access contract methods
      const contractMethod = (contract as any)[method];
      if (!contractMethod) {
        throw new Error(`Method ${method} not found on contract`);
      }
      const gasEstimate = await contractMethod.estimateGas(...args, { value });
      // Add 20% buffer for safety
      return (gasEstimate * BigInt(120)) / BigInt(100);
    } catch (error) {
      console.error(`Error estimating gas for ${method}:`, error);
      throw error;
    }
  }

  public async sendCrossChainTransaction(tx: CrossChainTransaction): Promise<string> {
    await this.validateCrossChainTransaction(tx);
    await this.validateBridgeTransaction(tx);

    // Ensure we're on the correct source chain
    if (this.state.chainId !== tx.fromChain) {
      await this.switchNetwork(tx.fromChain);
    }

    const bridgeContract = await this.getBridgeContract();
    const amount = ethers.parseEther(tx.amount);
    const fee = ethers.parseEther(BRIDGE_CONFIG[tx.fromChain].fee);
    const totalAmount = amount + fee;

    return this.retryOperation(async () => {
      try {
        // Estimate gas for the transaction
        const gasLimit = await this.estimateGasForTransaction(
          bridgeContract,
          'deposit',
          [tx.toAddress, amount],
          totalAmount
        );

        // For Base -> Ethereum
        if (tx.fromChain === SUPPORTED_CHAINS.base.chainId && tx.toChain === SUPPORTED_CHAINS.ethereum.chainId) {
          const bridgeTx = await bridgeContract.deposit(tx.toAddress, amount, {
            value: totalAmount,
            gasLimit
          });

          const receipt = await bridgeTx.wait();
          await this.waitForConfirmation(receipt.hash);

          const depositEvent = receipt.logs.find(
            (log: any) => log.eventName === BRIDGE_EVENTS.DEPOSIT_INITIATED
          );

          if (!depositEvent) {
            throw new Error('Deposit event not found');
          }

          const bridgeTransaction: BridgeTransaction = {
            fromChain: tx.fromChain,
            toChain: tx.toChain,
            fromAddress: tx.fromAddress,
            toAddress: tx.toAddress,
            amount: tx.amount,
            status: BridgeStatus.PENDING,
            depositId: depositEvent.args.depositId,
            timestamp: Date.now()
          };

          this.emitEvent('bridgeTransactionInitiated', bridgeTransaction);
          return depositEvent.args.depositId;
        }

        // For Ethereum -> Base
        if (tx.fromChain === SUPPORTED_CHAINS.ethereum.chainId && tx.toChain === SUPPORTED_CHAINS.base.chainId) {
          const bridgeTx = await bridgeContract.deposit(tx.toAddress, amount, {
            value: totalAmount,
            gasLimit
          });

          const receipt = await bridgeTx.wait();
          await this.waitForConfirmation(receipt.hash);

          const depositEvent = receipt.logs.find(
            (log: any) => log.eventName === BRIDGE_EVENTS.DEPOSIT_INITIATED
          );

          if (!depositEvent) {
            throw new Error('Deposit event not found');
          }

          const bridgeTransaction: BridgeTransaction = {
            fromChain: tx.fromChain,
            toChain: tx.toChain,
            fromAddress: tx.fromAddress,
            toAddress: tx.toAddress,
            amount: tx.amount,
            status: BridgeStatus.PENDING,
            depositId: depositEvent.args.depositId,
            timestamp: Date.now()
          };

          this.emitEvent('bridgeTransactionInitiated', bridgeTransaction);
          return depositEvent.args.depositId;
        }

        throw new Error('Unsupported cross-chain route');
      } catch (error: any) {
        this.handleError(error);
        throw error;
      }
    });
  }

  public async getBridgeTransactionStatus(depositId: string): Promise<BridgeStatus> {
    if (!this.bridgeMonitor) {
      throw new Error('Bridge monitor not initialized');
    }
    const tx = this.bridgeMonitor.getTransaction(depositId);
    if (!tx) {
      throw new Error('Transaction not found');
    }
    return tx.status;
  }

  public async withdrawFromBridge(toAddress: string, amount: string): Promise<string> {
    if (!this.provider || !this.signer) {
      throw new Error('Provider or signer not initialized');
    }

    const chainId = await this.getChainId();
    if (chainId !== SUPPORTED_CHAINS.base.chainId) {
      throw new Error('Withdrawals can only be initiated on Base chain');
    }

    const bridgeContract = await this.getBridgeContract();
    const parsedAmount = ethers.parseEther(amount);

    return this.retryOperation(async () => {
      try {
        // Estimate gas for the withdrawal
        const gasLimit = await this.estimateGasForTransaction(
          bridgeContract,
          'withdraw',
          [toAddress, parsedAmount]
        );

        const bridgeTx = await bridgeContract.withdraw(toAddress, parsedAmount, {
          gasLimit
        });

        const receipt = await bridgeTx.wait();
        await this.waitForConfirmation(receipt.hash);
        
        const withdrawalEvent = receipt.logs.find(
          (log: any) => log.eventName === BRIDGE_EVENTS.WITHDRAWAL_INITIATED
        );

        if (!withdrawalEvent) {
          throw new Error('Withdrawal event not found');
        }

        return withdrawalEvent.args.withdrawalId;
      } catch (error: any) {
        this.handleError(error);
        throw error;
      }
    });
  }

  public async getWithdrawalStatus(withdrawalId: string): Promise<BridgeStatus> {
    const bridgeContract = await this.getBridgeContract();
    const isCompleted = await bridgeContract.getWithdrawalStatus(withdrawalId);
    return isCompleted ? BridgeStatus.COMPLETED : BridgeStatus.PENDING;
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
    if (!this.bridgeMonitor) {
      throw new Error('Bridge monitor not initialized');
    }
    return this.bridgeMonitor.estimateBridgeFee(fromChain, toChain, amount);
  }

  public async getBridgeTransactionHistory(
    address: string,
    fromBlock?: number,
    toBlock?: number
  ): Promise<BridgeTransaction[]> {
    if (!this.bridgeMonitor) {
      throw new Error('Bridge monitor not initialized');
    }
    return this.bridgeMonitor.getBridgeTransactionHistory(address, fromBlock, toBlock);
  }
} 