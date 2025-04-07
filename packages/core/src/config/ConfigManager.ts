import { z } from 'zod';
import * as path from 'path';
import * as fs from 'fs';

// Configuration schemas
const EnvironmentSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  JULIA_PATH: z.string(),
  JULIA_PROJECT: z.string().optional(),
  JULIA_DEPOT_PATH: z.string().optional(),
  JULIA_BRIDGE_PORT: z.string().transform(Number).default('8080'),
  JULIA_BRIDGE_DEBUG: z.string().transform(val => val === 'true').default('false'),
  JULIA_BRIDGE_TIMEOUT: z.string().transform(Number).default('30000'),
  JULIA_BRIDGE_MAX_RETRIES: z.string().transform(Number).default('3'),
  JULIA_BRIDGE_RECONNECT_INTERVAL: z.string().transform(Number).default('5000'),
  JULIA_BRIDGE_HEARTBEAT_INTERVAL: z.string().transform(Number).default('30000'),
  JULIA_BRIDGE_HEARTBEAT_TIMEOUT: z.string().transform(Number).default('10000'),
  JULIA_BRIDGE_MAX_QUEUE_SIZE: z.string().transform(Number).default('1000'),
  JULIA_BRIDGE_BACKOFF_MULTIPLIER: z.string().transform(Number).default('1.5'),
});

const ConfigSchema = z.object({
  environment: EnvironmentSchema,
  paths: z.object({
    baseDir: z.string(),
    juliaScripts: z.string(),
    storage: z.string(),
    logs: z.string(),
  }),
  bridge: z.object({
    port: z.number(),
    debug: z.boolean(),
    timeout: z.number(),
    maxRetries: z.number(),
    reconnectInterval: z.number(),
    heartbeatInterval: z.number(),
    heartbeatTimeout: z.number(),
    maxQueueSize: z.number(),
    backoffMultiplier: z.number(),
  }),
  storage: z.object({
    backupInterval: z.number(),
    maxBackups: z.number(),
    compression: z.boolean(),
  }),
});

export type Config = z.infer<typeof ConfigSchema>;

export class ConfigManager {
  private static instance: ConfigManager;
  private config: Config;

  private constructor() {
    this.config = this.loadConfig();
  }

  static getInstance(): ConfigManager {
    if (!ConfigManager.instance) {
      ConfigManager.instance = new ConfigManager();
    }
    return ConfigManager.instance;
  }

  private loadConfig(): Config {
    try {
      // Load environment variables
      const env = EnvironmentSchema.parse(process.env);

      // Define base paths
      const baseDir = process.cwd();
      const paths = {
        baseDir,
        juliaScripts: path.join(baseDir, 'julia', 'src'),
        storage: path.join(baseDir, 'storage'),
        logs: path.join(baseDir, 'logs'),
      };

      // Create necessary directories
      Object.values(paths).forEach(dir => {
        if (!fs.existsSync(dir)) {
          fs.mkdirSync(dir, { recursive: true });
        }
      });

      // Construct configuration
      const config = {
        environment: env,
        paths,
        bridge: {
          port: env.JULIA_BRIDGE_PORT,
          debug: env.JULIA_BRIDGE_DEBUG,
          timeout: env.JULIA_BRIDGE_TIMEOUT,
          maxRetries: env.JULIA_BRIDGE_MAX_RETRIES,
          reconnectInterval: env.JULIA_BRIDGE_RECONNECT_INTERVAL,
          heartbeatInterval: env.JULIA_BRIDGE_HEARTBEAT_INTERVAL,
          heartbeatTimeout: env.JULIA_BRIDGE_HEARTBEAT_TIMEOUT,
          maxQueueSize: env.JULIA_BRIDGE_MAX_QUEUE_SIZE,
          backoffMultiplier: env.JULIA_BRIDGE_BACKOFF_MULTIPLIER,
        },
        storage: {
          backupInterval: 3600000, // 1 hour
          maxBackups: 5,
          compression: true,
        },
      };

      // Validate configuration
      return ConfigSchema.parse(config);
    } catch (error) {
      console.error('Failed to load configuration:', error);
      throw error;
    }
  }

  getConfig(): Config {
    return this.config;
  }

  getBridgeConfig() {
    return {
      juliaPath: this.config.environment.JULIA_PATH,
      scriptPath: this.config.paths.juliaScripts,
      port: this.config.bridge.port,
      options: {
        debug: this.config.bridge.debug,
        timeout: this.config.bridge.timeout,
        maxRetries: this.config.bridge.maxRetries,
        reconnectInterval: this.config.bridge.reconnectInterval,
        heartbeatInterval: this.config.bridge.heartbeatInterval,
        heartbeatTimeout: this.config.bridge.heartbeatTimeout,
        maxQueueSize: this.config.bridge.maxQueueSize,
        backoffMultiplier: this.config.bridge.backoffMultiplier,
        projectPath: this.config.environment.JULIA_PROJECT,
        depotPath: this.config.environment.JULIA_DEPOT_PATH,
      },
    };
  }

  getStorageConfig() {
    return {
      baseDir: this.config.paths.storage,
      ...this.config.storage,
    };
  }

  getLogPath(): string {
    return path.join(
      this.config.paths.logs,
      `${this.config.environment.NODE_ENV}.log`
    );
  }

  reload(): void {
    this.config = this.loadConfig();
  }
} 