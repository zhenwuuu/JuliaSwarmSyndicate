/**
 * JuliaOS Framework - Storage Package
 *
 * This package provides storage interfaces for the JuliaOS framework.
 * It includes local storage (SQLite), web3 storage (Ceramic/IPFS), and Arweave storage.
 */

// Export all storage modules
export * from './local';
export * from './web3';
export * from './arweave';

// Export a unified storage interface
import { LocalStorage, StorageOptions, StorageEvent } from './local';
import { Web3Storage } from './web3';
import { ArweaveStorage, ArweaveConfig } from './arweave';
import { JuliaBridge } from '@juliaos/julia-bridge';
import { EventEmitter } from 'events';

export interface UnifiedStorageOptions extends StorageOptions {
  web3?: {
    ceramicNodeUrl?: string;
    ipfsApiUrl?: string;
    ipfsApiKey?: string;
  };
  arweave?: ArweaveConfig;
}

/**
 * Storage backend types
 */
export enum StorageBackend {
  LOCAL = 'local',
  WEB3 = 'web3',
  ARWEAVE = 'arweave'
}

/**
 * UnifiedStorage provides a single interface to all storage backends
 */
export class UnifiedStorage extends EventEmitter {
  private bridge: JuliaBridge;
  private options: UnifiedStorageOptions;
  private defaultBackend: StorageBackend = StorageBackend.LOCAL;

  public local: LocalStorage;
  public web3: Web3Storage;
  public arweave: ArweaveStorage;

  /**
   * Create a new UnifiedStorage instance
   *
   * @param bridge - JuliaBridge instance for communicating with the Julia backend
   * @param options - Configuration options
   */
  constructor(bridge: JuliaBridge, options: UnifiedStorageOptions = {}) {
    super();
    this.bridge = bridge;
    this.options = options;

    // Initialize storage backends
    this.local = new LocalStorage(bridge, options);
    this.web3 = new Web3Storage(bridge);
    this.arweave = new ArweaveStorage(bridge, options.arweave);

    // Forward events from storage backends
    this.local.on(StorageEvent.DATA_CHANGED, (data) => this.emit('data_changed', { source: 'local', ...data }));
    this.local.on(StorageEvent.ERROR, (error) => this.emit('error', { source: 'local', error }));
  }

  /**
   * Set the default storage backend
   *
   * @param backend - Storage backend to use by default
   */
  setDefaultBackend(backend: StorageBackend): void {
    this.defaultBackend = backend;
  }

  /**
   * Initialize all storage backends
   */
  async initialize(): Promise<{
    local: boolean;
    web3?: {
      ceramic_url: string;
      ipfs_api_url: string;
      ipfs_api_key_configured: boolean;
    };
    arweave?: {
      gateway: string;
      wallet_configured: boolean;
      connected: boolean;
    };
  }> {
    const results: any = {
      local: false
    };

    // Initialize local storage
    results.local = await this.local.initialize();

    // Initialize web3 storage if configured
    if (this.options.web3) {
      try {
        results.web3 = await this.web3.configure(this.options.web3);
      } catch (error) {
        this.emit('error', { source: 'web3', error });
      }
    }

    // Initialize arweave storage if configured
    if (this.options.arweave) {
      try {
        results.arweave = await this.arweave.configure(this.options.arweave);
      } catch (error) {
        this.emit('error', { source: 'arweave', error });
      }
    }

    return results;
  }

  /**
   * Store agent data in the specified storage backend
   *
   * @param agent - Agent data to store
   * @param backend - Storage backend to use (defaults to the default backend)
   * @returns Promise with storage result
   */
  async storeAgent(agent: Agent, backend?: StorageBackend): Promise<{
    success: boolean;
    storage_info?: StorageInfo;
    error?: string;
  }> {
    const targetBackend = backend || this.defaultBackend;

    try {
      switch (targetBackend) {
        case StorageBackend.LOCAL:
          const localResult = await this.local.createAgent(
            agent.id,
            agent.name,
            agent.type,
            agent.config || {}
          );
          return {
            success: !!localResult,
            storage_info: { type: 'local' }
          };

        case StorageBackend.WEB3:
          const web3Result = await this.web3.storeAgent(agent);
          return {
            success: web3Result.success,
            storage_info: web3Result.success ? {
              type: 'web3',
              ceramic_doc_id: web3Result.ceramic_doc_id,
              large_data: web3Result.large_data
            } : undefined,
            error: web3Result.error
          };

        case StorageBackend.ARWEAVE:
          const arweaveResult = await this.arweave.storeAgent(agent);
          return {
            success: arweaveResult.success,
            storage_info: arweaveResult.success ? {
              type: 'arweave',
              arweave_tx_id: arweaveResult.arweave_tx_id!,
              arweave_owner: arweaveResult.arweave_owner!
            } : undefined,
            error: arweaveResult.error
          };

        default:
          throw new Error(`Unknown storage backend: ${targetBackend}`);
      }
    } catch (error) {
      this.emit('error', { source: targetBackend, error });
      return {
        success: false,
        error: String(error)
      };
    }
  }

  /**
   * Store swarm data in the specified storage backend
   *
   * @param swarm - Swarm data to store
   * @param backend - Storage backend to use (defaults to the default backend)
   * @returns Promise with storage result
   */
  async storeSwarm(swarm: Swarm, backend?: StorageBackend): Promise<{
    success: boolean;
    storage_info?: StorageInfo;
    error?: string;
  }> {
    const targetBackend = backend || this.defaultBackend;

    try {
      switch (targetBackend) {
        case StorageBackend.LOCAL:
          const localResult = await this.local.createSwarm(
            swarm.id,
            swarm.name,
            swarm.type,
            swarm.algorithm || 'default',
            swarm.config || {}
          );
          return {
            success: !!localResult,
            storage_info: { type: 'local' }
          };

        case StorageBackend.WEB3:
          const web3Result = await this.web3.storeSwarm(swarm);
          return {
            success: web3Result.success,
            storage_info: web3Result.success ? {
              type: 'web3',
              ceramic_doc_id: web3Result.ceramic_doc_id,
              large_data: web3Result.large_data
            } : undefined,
            error: web3Result.error
          };

        case StorageBackend.ARWEAVE:
          const arweaveResult = await this.arweave.storeSwarm(swarm);
          return {
            success: arweaveResult.success,
            storage_info: arweaveResult.success ? {
              type: 'arweave',
              arweave_tx_id: arweaveResult.arweave_tx_id!,
              arweave_owner: arweaveResult.arweave_owner!
            } : undefined,
            error: arweaveResult.error
          };

        default:
          throw new Error(`Unknown storage backend: ${targetBackend}`);
      }
    } catch (error) {
      this.emit('error', { source: targetBackend, error });
      return {
        success: false,
        error: String(error)
      };
    }
  }
}