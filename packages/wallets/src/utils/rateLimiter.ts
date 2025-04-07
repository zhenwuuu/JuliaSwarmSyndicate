import { WalletLogger, LogLevel } from './logger';

interface RateLimitConfig {
  maxRequests: number;
  timeWindow: number; // in milliseconds
  queueSize: number;
}

export class RateLimiter {
  private static instance: RateLimiter;
  private logger: WalletLogger;
  private requestTimestamps: number[] = [];
  private requestQueue: Array<() => Promise<any>> = [];
  private isProcessing: boolean = false;
  private config: RateLimitConfig;

  private constructor(config: RateLimitConfig = {
    maxRequests: 50, // 50 requests
    timeWindow: 1000, // per second
    queueSize: 100
  }) {
    this.logger = WalletLogger.getInstance();
    this.config = config;
  }

  static getInstance(config?: RateLimitConfig): RateLimiter {
    if (!RateLimiter.instance) {
      RateLimiter.instance = new RateLimiter(config);
    }
    return RateLimiter.instance;
  }

  private async processQueue(): Promise<void> {
    if (this.isProcessing || this.requestQueue.length === 0) {
      return;
    }

    this.isProcessing = true;
    const startTime = Date.now();

    try {
      while (this.requestQueue.length > 0) {
        const request = this.requestQueue.shift();
        if (!request) break;

        await this.waitForRateLimit();
        await request();
      }
    } catch (error) {
      this.logger.error('Error processing request queue', error as Error);
    } finally {
      this.isProcessing = false;
      const duration = Date.now() - startTime;
      this.logger.recordMetric('queueProcessingTime', duration);
    }
  }

  private async waitForRateLimit(): Promise<void> {
    const now = Date.now();
    this.requestTimestamps = this.requestTimestamps.filter(
      timestamp => now - timestamp < this.config.timeWindow
    );

    if (this.requestTimestamps.length >= this.config.maxRequests) {
      const oldestRequest = this.requestTimestamps[0];
      const waitTime = this.config.timeWindow - (now - oldestRequest);
      await new Promise(resolve => setTimeout(resolve, waitTime));
    }

    this.requestTimestamps.push(now);
  }

  async enqueue<T>(request: () => Promise<T>): Promise<T> {
    if (this.requestQueue.length >= this.config.queueSize) {
      throw new Error('Request queue is full');
    }

    return new Promise((resolve, reject) => {
      this.requestQueue.push(async () => {
        try {
          const result = await request();
          resolve(result);
        } catch (error) {
          reject(error);
        }
      });

      this.processQueue();
    });
  }

  getQueueSize(): number {
    return this.requestQueue.length;
  }

  clearQueue(): void {
    this.requestQueue = [];
    this.requestTimestamps = [];
    this.isProcessing = false;
  }

  updateConfig(config: Partial<RateLimitConfig>): void {
    this.config = { ...this.config, ...config };
    this.logger.info('Rate limiter config updated', { config: this.config });
  }
} 