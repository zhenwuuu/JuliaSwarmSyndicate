import { 
  JsonRpcProvider, 
  Wallet, 
  Contract, 
  ContractEventPayload,
  LogDescription,
  ContractTransactionResponse,
  Interface,
  InterfaceAbi,
  Log
} from 'ethers';
import config from '../config/config';
import logger from '../utils/logger';

type TokensLockedArgs = [token: string, amount: bigint, recipient: string] & { 
  token: string;
  amount: bigint;
  recipient: string;
};

type TokensReleasedArgs = [token: string, amount: bigint, recipient: string] & {
  token: string;
  amount: bigint;
  recipient: string;
};

// Custom event type that includes properties we need
interface EventWithMetadata {
  args?: unknown;
  transactionHash: string;
  blockNumber: number;
}

export class BaseService {
  private provider: JsonRpcProvider;
  private wallet: Wallet;
  private bridgeContract: Contract;
  private isRunning: boolean = false;
  private reconnectTimeout?: NodeJS.Timeout;
  private pollInterval?: NodeJS.Timeout;
  private lastProcessedBlock: number = 0;

  constructor() {
    this.provider = new JsonRpcProvider(config.base.rpcUrl);
    this.wallet = new Wallet(config.base.privateKey, this.provider);

    const bridgeAbi = [
      "event TokensLocked(address indexed token, uint256 amount, address indexed recipient)",
      "event TokensReleased(address indexed token, uint256 amount, address indexed recipient)",
      "function lockTokens(address token, uint256 amount, address recipient)",
      "function releaseTokens(address token, uint256 amount, address recipient)"
    ];

    this.bridgeContract = new Contract(
      config.base.bridgeContract,
      bridgeAbi,
      this.wallet
    );
  }

  private async pollEvents() {
    try {
      const latestBlock = await this.provider.getBlockNumber();
      
      if (this.lastProcessedBlock === 0) {
        // On first run, start from current block
        this.lastProcessedBlock = latestBlock;
        return;
      }

      // Don't query more than 1000 blocks at a time to avoid timeout
      const fromBlock = this.lastProcessedBlock + 1;
      const toBlock = Math.min(latestBlock, fromBlock + 999);
      
      if (fromBlock > toBlock) {
        return;
      }

      logger.debug('Polling for events...', {
        fromBlock,
        toBlock,
        contractAddress: this.bridgeContract.target
      });

      // Get TokensLocked events
      const lockedEvents = await this.bridgeContract.queryFilter(
        this.bridgeContract.filters.TokensLocked(),
        fromBlock,
        toBlock
      );

      // Get TokensReleased events
      const releasedEvents = await this.bridgeContract.queryFilter(
        this.bridgeContract.filters.TokensReleased(),
        fromBlock,
        toBlock
      );

      // Process TokensLocked events
      for (const event of lockedEvents) {
        const eventWithMeta = event as unknown as EventWithMetadata;
        const { args, transactionHash, blockNumber } = eventWithMeta;
        if (!args) continue;

        const { token, amount, recipient } = args as unknown as TokensLockedArgs;
        logger.info('TokensLocked event detected', {
          token,
          amount: amount.toString(),
          recipient,
          transactionHash,
          blockNumber
        });
      }

      // Process TokensReleased events
      for (const event of releasedEvents) {
        const eventWithMeta = event as unknown as EventWithMetadata;
        const { args, transactionHash, blockNumber } = eventWithMeta;
        if (!args) continue;

        const { token, amount, recipient } = args as unknown as TokensReleasedArgs;
        logger.info('TokensReleased event detected', {
          token,
          amount: amount.toString(),
          recipient,
          transactionHash,
          blockNumber
        });
      }

      this.lastProcessedBlock = toBlock;
    } catch (error) {
      logger.error('Error polling events', { error });
      await this.reconnect();
    }
  }

  private startEventPolling() {
    this.pollInterval = setInterval(
      () => this.pollEvents(),
      config.pollingInterval
    );
  }

  private async reconnect() {
    if (!this.isRunning) return;

    logger.info('Attempting to reconnect...');
    
    if (this.reconnectTimeout) {
      clearTimeout(this.reconnectTimeout);
    }

    if (this.pollInterval) {
      clearInterval(this.pollInterval);
    }

    this.reconnectTimeout = setTimeout(async () => {
      try {
        // Create new provider and wallet
        this.provider = new JsonRpcProvider(config.base.rpcUrl);
        this.wallet = new Wallet(config.base.privateKey, this.provider);
        
        // Create new contract instance with the same ABI
        const abi = this.bridgeContract.interface.format() as InterfaceAbi;
        this.bridgeContract = new Contract(
          config.base.bridgeContract,
          abi,
          this.wallet
        );

        // Wait for provider to be ready
        await this.provider.ready;

        // Start polling again
        this.startEventPolling();

        logger.info('Successfully reconnected');
      } catch (error) {
        logger.error('Reconnection failed', { error });
        // Try again in 5 seconds
        await this.reconnect();
      }
    }, 5000);
  }

  async start() {
    logger.info('Starting Base service...', {
      chainId: config.base.chainId,
      bridgeContract: config.base.bridgeContract
    });

    this.isRunning = true;

    // Initial connection check
    try {
      await this.provider.ready;
      const network = await this.provider.getNetwork();
      logger.info('Connected to network', {
        chainId: network.chainId,
        name: network.name
      });

      // Start polling for events
      this.startEventPolling();
    } catch (error) {
      logger.error('Initial connection failed', { error });
      await this.reconnect();
    }
  }

  stop() {
    logger.info('Stopping Base service...');
    this.isRunning = false;
    if (this.reconnectTimeout) {
      clearTimeout(this.reconnectTimeout);
    }
    if (this.pollInterval) {
      clearInterval(this.pollInterval);
    }
  }
}