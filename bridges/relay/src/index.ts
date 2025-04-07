import { BaseService } from './services/base';
import { SolanaService } from './services/solana';
import logger from './utils/logger';

class BridgeRelay {
  private baseService: BaseService;
  private solanaService: SolanaService;

  constructor() {
    this.baseService = new BaseService();
    this.solanaService = new SolanaService();
  }

  async start() {
    logger.info('Starting bridge relay service...');

    try {
      await this.baseService.start();
      await this.solanaService.start();

      process.on('SIGINT', () => this.stop());
      process.on('SIGTERM', () => this.stop());
    } catch (error) {
      logger.error('Error starting relay service:', error);
      this.stop();
    }
  }

  stop() {
    logger.info('Stopping bridge relay service...');
    this.baseService.stop();
    this.solanaService.stop();
    process.exit(0);
  }
}

process.on('unhandledRejection', (error) => {
  logger.error('Unhandled promise rejection:', error);
  process.exit(1);
});

const relay = new BridgeRelay();
relay.start(); 