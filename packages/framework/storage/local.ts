/**
 * JuliaOS Framework - Local Storage Module
 *
 * Provides an interface to the local SQLite database in the Julia backend.
 * This module handles persistent storage of agents, swarms, transactions, and other data.
 */

import { JuliaBridge } from '@juliaos/julia-bridge';
import { EventEmitter } from 'events';

export interface Agent {
  id: string;
  name: string;
  type: string;
  config?: Record<string, any>;
  status?: string;
  created_at?: string;
  updated_at?: string;
  storage?: string | StorageInfo;
}

export interface Swarm {
  id: string;
  name: string;
  type: string;
  algorithm?: string;
  config?: Record<string, any>;
  status?: string;
  agent_count?: number;
  created_at?: string;
  updated_at?: string;
  storage?: string | StorageInfo;
}

export interface StorageInfo {
  type: string;
  ceramic_doc_id?: string;
  ipfs_cid?: string;
  large_data?: Record<string, string>;
  last_synced?: string;
}

export interface Transaction {
  id: string;
  chain: string;
  tx_hash: string;
  from_address?: string;
  to_address?: string;
  amount?: string;
  token?: string;
  status?: string;
  created_at?: string;
  confirmed_at?: string;
}

export interface ApiKey {
  id: string;
  service: string;
  is_valid?: boolean;
  last_used?: string;
  created_at?: string;
}

/**
 * Options for configuring the LocalStorage
 */
export interface StorageOptions {
  /** Path to the SQLite database file */
  dbPath?: string;
  /** Whether to automatically backup the database */
  autoBackup?: boolean;
  /** Interval between automatic backups in milliseconds */
  backupInterval?: number;
  /** Maximum number of backups to keep */
  maxBackups?: number;
  /** Encryption key for the database (if supported) */
  encryptionKey?: string;
  /** Whether to compress the database */
  compressionEnabled?: boolean;
}

/**
 * Events emitted by LocalStorage
 */
export enum StorageEvent {
  /** Emitted when the storage is connected */
  CONNECTED = 'connected',
  /** Emitted when the storage is disconnected */
  DISCONNECTED = 'disconnected',
  /** Emitted when a backup is created */
  BACKUP_CREATED = 'backup_created',
  /** Emitted when a backup is restored */
  BACKUP_RESTORED = 'backup_restored',
  /** Emitted when an error occurs */
  ERROR = 'error',
  /** Emitted when data is changed */
  DATA_CHANGED = 'data_changed'
}

/**
 * LocalStorage class for interacting with the local SQLite database
 */
export class LocalStorage extends EventEmitter {
  private bridge: JuliaBridge;
  private options: StorageOptions;
  private connected: boolean = false;
  private backupTimer?: NodeJS.Timeout;

  /**
   * Create a new LocalStorage instance
   *
   * @param bridge - JuliaBridge instance for communicating with the Julia backend
   * @param options - Configuration options
   */
  constructor(bridge: JuliaBridge, options: StorageOptions = {}) {
    super();
    this.bridge = bridge;
    this.options = {
      dbPath: './data/juliaos.db',
      autoBackup: true,
      backupInterval: 3600000, // 1 hour
      maxBackups: 5,
      compressionEnabled: true,
      ...options
    };
  }

  /**
   * Initialize the storage system
   *
   * @returns Promise that resolves to true if initialization was successful
   */
  async initialize(): Promise<boolean> {
    try {
      const result = await this.bridge.execute('Storage.initialize', [
        this.options.dbPath,
        this.options.encryptionKey,
        this.options.compressionEnabled
      ]);

      this.connected = result?.success || false;

      if (this.connected) {
        this.emit(StorageEvent.CONNECTED);

        // Set up auto-backup if enabled
        if (this.options.autoBackup) {
          this.setupAutoBackup();
        }

        // Log successful connection
        console.log(`Connected to SQLite database at ${this.options.dbPath}`);
      } else {
        console.error(`Failed to connect to SQLite database at ${this.options.dbPath}`);
      }

      return this.connected;
    } catch (error) {
      this.emit(StorageEvent.ERROR, error);
      console.error(`Error initializing SQLite database: ${error}`);
      return false;
    }
  }

  /**
   * Set up automatic backups
   *
   * @private
   */
  private setupAutoBackup(): void {
    if (this.backupTimer) {
      clearInterval(this.backupTimer);
    }

    this.backupTimer = setInterval(async () => {
      try {
        // Create a backup with a timestamp label
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const result = await this.createBackup(`auto-${timestamp}`);

        if (result.success) {
          console.log(`Auto backup created: ${result.backup_path}`);

          // Clean up old backups if we have too many
          if (this.options.maxBackups) {
            await this.cleanupOldBackups();
          }
        }
      } catch (error) {
        this.emit(StorageEvent.ERROR, error);
        console.error(`Auto backup failed: ${error}`);
      }
    }, this.options.backupInterval);

    console.log(`Auto backup scheduled every ${this.options.backupInterval / 1000} seconds`);
  }

  /**
   * Clean up old backups, keeping only the most recent ones
   *
   * @private
   */
  private async cleanupOldBackups(): Promise<void> {
    try {
      // Get list of backups
      const result = await this.listBackups();

      if (!result.success || !result.backups || result.backups.length <= this.options.maxBackups!) {
        return;
      }

      // Sort backups by timestamp (newest first)
      const sortedBackups = result.backups.sort((a, b) => {
        return new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime();
      });

      // Delete old backups
      const backupsToDelete = sortedBackups.slice(this.options.maxBackups!);

      for (const backup of backupsToDelete) {
        try {
          await this.bridge.execute('Storage.delete_backup', [backup.path]);
          console.log(`Deleted old backup: ${backup.path}`);
        } catch (error) {
          console.error(`Failed to delete backup ${backup.path}: ${error}`);
        }
      }
    } catch (error) {
      console.error(`Error cleaning up old backups: ${error}`);
    }
  }

  /**
   * Create a backup of the database
   *
   * @param label - Optional label for the backup
   * @returns Promise with backup information
   */
  async createBackup(label?: string): Promise<{
    success: boolean;
    backup_path?: string;
    timestamp?: string;
    size?: number;
    error?: string;
  }> {
    try {
      const result = await this.bridge.execute('Storage.create_backup', [label]);

      if (result?.success) {
        this.emit(StorageEvent.BACKUP_CREATED, result);
      }

      return result;
    } catch (error) {
      this.emit(StorageEvent.ERROR, error);
      console.error(`Failed to create backup: ${error}`);
      return { success: false, error: String(error) };
    }
  }

  /**
   * Restore from a backup
   *
   * @param backupPath - Path to the backup file
   * @returns Promise with restore result
   */
  async restoreBackup(backupPath: string): Promise<{
    success: boolean;
    error?: string;
  }> {
    try {
      // Confirm the backup exists
      const backups = await this.listBackups();
      const backupExists = backups.success && backups.backups?.some(b => b.path === backupPath);

      if (!backupExists) {
        return { success: false, error: `Backup not found: ${backupPath}` };
      }

      // Create a safety backup before restoring
      const safetyBackup = await this.createBackup('pre-restore-safety');

      if (!safetyBackup.success) {
        console.warn(`Failed to create safety backup before restore: ${safetyBackup.error}`);
      }

      // Restore the backup
      const result = await this.bridge.execute('Storage.restore_backup', [backupPath]);

      if (result?.success) {
        this.emit(StorageEvent.BACKUP_RESTORED, result);
        console.log(`Restored database from backup: ${backupPath}`);
      } else {
        console.error(`Failed to restore backup: ${result?.error}`);
      }

      return result;
    } catch (error) {
      this.emit(StorageEvent.ERROR, error);
      console.error(`Error restoring backup: ${error}`);
      return { success: false, error: String(error) };
    }
  }

  /**
   * List available backups
   *
   * @returns Promise with list of backups
   */
  async listBackups(): Promise<{
    success: boolean;
    backups?: Array<{
      path: string;
      timestamp: string;
      size: number;
      label?: string;
    }>;
    error?: string;
  }> {
    try {
      const result = await this.bridge.execute('Storage.list_backups', []);
      return result || { success: false, backups: [] };
    } catch (error) {
      this.emit(StorageEvent.ERROR, error);
      console.error(`Error listing backups: ${error}`);
      return { success: false, error: String(error) };
    }
  }

  // =====================
  // Agent CRUD Operations
  // =====================

  /**
   * Create a new agent in local storage
   */
  async createAgent(id: string, name: string, type: string, config: Record<string, any>): Promise<Agent> {
    try {
      const result = await this.bridge.execute('Storage.create_agent', [
        id,
        name,
        type,
        JSON.stringify(config)
      ]);

      if (result) {
        this.emit(StorageEvent.DATA_CHANGED, { type: 'agent', action: 'create', id });
      }

      return result;
    } catch (error) {
      this.emit(StorageEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Get agent by ID
   */
  async getAgent(id: string): Promise<Agent | null> {
    try {
      const result = await this.bridge.execute('Storage.get_agent', [id]);
      return result || null;
    } catch (error) {
      this.emit(StorageEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * List all agents
   */
  async listAgents(filters?: { type?: string, status?: string }): Promise<Agent[]> {
    try {
      const result = await this.bridge.execute('Storage.list_agents', [filters]);
      return result || [];
    } catch (error) {
      this.emit(StorageEvent.ERROR, error);
      return [];
    }
  }

  /**
   * Update an agent in local storage
   */
  async updateAgent(id: string, updates: Partial<Agent>): Promise<{
    success: boolean;
    agent?: Agent;
    error?: string;
  }> {
    try {
      const result = await this.bridge.execute('Storage.update_agent', [id, updates]);

      if (result?.success) {
        this.emit(StorageEvent.DATA_CHANGED, { type: 'agent', action: 'update', id });
      }

      return result;
    } catch (error) {
      this.emit(StorageEvent.ERROR, error);
      return { success: false, error: String(error) };
    }
  }

  /**
   * Delete an agent from local storage
   */
  async deleteAgent(id: string): Promise<{
    success: boolean;
    error?: string;
  }> {
    try {
      const result = await this.bridge.execute('Storage.delete_agent', [id]);

      if (result?.success) {
        this.emit(StorageEvent.DATA_CHANGED, { type: 'agent', action: 'delete', id });
      }

      return result;
    } catch (error) {
      this.emit(StorageEvent.ERROR, error);
      return { success: false, error: String(error) };
    }
  }

  // Swarm CRUD Operations are below

  // =====================
  // Swarm CRUD Operations
  // =====================

  /**
   * Create a new swarm in local storage
   */
  async createSwarm(
    id: string,
    name: string,
    type: string,
    algorithm: string,
    config: Record<string, any>
  ): Promise<Swarm> {
    try {
      const result = await this.bridge.execute(
        'Storage.create_swarm',
        [id, name, type, algorithm, JSON.stringify(config)]
      );

      if (result) {
        this.emit(StorageEvent.DATA_CHANGED, { type: 'swarm', action: 'create', id });
      }

      return result;
    } catch (error) {
      this.emit(StorageEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Get swarm by ID
   */
  async getSwarm(id: string): Promise<Swarm | null> {
    try {
      const result = await this.bridge.execute('Storage.get_swarm', [id]);
      return result || null;
    } catch (error) {
      this.emit(StorageEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * List all swarms
   */
  async listSwarms(filters?: { type?: string, algorithm?: string, status?: string }): Promise<Swarm[]> {
    try {
      const result = await this.bridge.execute('Storage.list_swarms', [filters]);
      return result || [];
    } catch (error) {
      this.emit(StorageEvent.ERROR, error);
      return [];
    }
  }

  /**
   * Update a swarm in local storage
   */
  async updateSwarm(id: string, updates: Partial<Swarm>): Promise<{
    success: boolean;
    swarm?: Swarm;
    error?: string;
  }> {
    try {
      const result = await this.bridge.execute('Storage.update_swarm', [id, updates]);

      if (result?.success) {
        this.emit(StorageEvent.DATA_CHANGED, { type: 'swarm', action: 'update', id });
      }

      return result;
    } catch (error) {
      this.emit(StorageEvent.ERROR, error);
      return { success: false, error: String(error) };
    }
  }

  /**
   * Delete a swarm from local storage
   */
  async deleteSwarm(id: string): Promise<{
    success: boolean;
    error?: string;
  }> {
    try {
      const result = await this.bridge.execute('Storage.delete_swarm', [id]);

      if (result?.success) {
        this.emit(StorageEvent.DATA_CHANGED, { type: 'swarm', action: 'delete', id });
      }

      return result;
    } catch (error) {
      this.emit(StorageEvent.ERROR, error);
      return { success: false, error: String(error) };
    }
  }

  /**
   * Add agent to swarm
   */
  async addAgentToSwarm(swarmId: string, agentId: string): Promise<{
    success: boolean;
    error?: string;
  }> {
    try {
      const result = await this.bridge.execute('Storage.add_agent_to_swarm', [swarmId, agentId]);

      if (result?.success) {
        this.emit(StorageEvent.DATA_CHANGED, {
          type: 'swarm_agent',
          action: 'add',
          swarmId,
          agentId
        });
      }

      return result;
    } catch (error) {
      this.emit(StorageEvent.ERROR, error);
      return { success: false, error: String(error) };
    }
  }

  /**
   * Remove agent from swarm
   */
  async removeAgentFromSwarm(swarmId: string, agentId: string): Promise<{
    success: boolean;
    error?: string;
  }> {
    try {
      const result = await this.bridge.execute('Storage.remove_agent_from_swarm', [swarmId, agentId]);

      if (result?.success) {
        this.emit(StorageEvent.DATA_CHANGED, {
          type: 'swarm_agent',
          action: 'remove',
          swarmId,
          agentId
        });
      }

      return result;
    } catch (error) {
      this.emit(StorageEvent.ERROR, error);
      return { success: false, error: String(error) };
    }
  }

  // The following methods are already implemented above

  /**
   * Get agents in swarm
   */
  async getSwarmAgents(swarmId: string): Promise<Agent[]> {
    try {
      const result = await this.bridge.execute('Storage.get_swarm_agents', [swarmId]);
      return result || [];
    } catch (error) {
      this.emit(StorageEvent.ERROR, error);
      return [];
    }
  }

  // =====================
  // Settings Operations
  // =====================

  /**
   * Save setting
   */
  async saveSetting(key: string, value: any): Promise<{ success: boolean; key: string; error?: string }> {
    try {
      const result = await this.bridge.execute('Storage.save_setting', [key, value]);

      if (result?.success) {
        this.emit(StorageEvent.DATA_CHANGED, { type: 'setting', action: 'save', key });
      }

      return result;
    } catch (error) {
      this.emit(StorageEvent.ERROR, error);
      return { success: false, key, error: String(error) };
    }
  }

  /**
   * Get setting
   */
  async getSetting<T = any>(key: string, defaultValue?: T): Promise<T> {
    try {
      const result = await this.bridge.execute('Storage.get_setting', [key]);
      return (result?.value !== undefined) ? result.value : defaultValue;
    } catch (error) {
      this.emit(StorageEvent.ERROR, error);
      return defaultValue as T;
    }
  }

  /**
   * List all settings
   */
  async listSettings(prefix?: string): Promise<Array<{ key: string; value: any; updated_at?: string }>> {
    try {
      const result = await this.bridge.execute('Storage.list_settings', [prefix]);
      return result || [];
    } catch (error) {
      this.emit(StorageEvent.ERROR, error);
      return [];
    }
  }

  /**
   * Delete setting
   */
  async deleteSetting(key: string): Promise<{ success: boolean; key: string; error?: string }> {
    try {
      const result = await this.bridge.execute('Storage.delete_setting', [key]);

      if (result?.success) {
        this.emit(StorageEvent.DATA_CHANGED, { type: 'setting', action: 'delete', key });
      }

      return result;
    } catch (error) {
      this.emit(StorageEvent.ERROR, error);
      return { success: false, key, error: String(error) };
    }
  }

  // =====================
  // Transaction Operations
  // =====================

  /**
   * Record a new transaction
   */
  async recordTransaction(
    chain: string,
    txHash: string,
    fromAddress: string,
    toAddress: string,
    amount: string,
    token: string,
    status: string = 'Pending'
  ): Promise<{ id: string; tx_hash: string; status: string; error?: string }> {
    try {
      const result = await this.bridge.execute(
        'Storage.record_transaction',
        [chain, txHash, fromAddress, toAddress, amount, token, status]
      );

      if (result?.id) {
        this.emit(StorageEvent.DATA_CHANGED, {
          type: 'transaction',
          action: 'create',
          id: result.id,
          txHash
        });
      }

      return result;
    } catch (error) {
      this.emit(StorageEvent.ERROR, error);
      return {
        id: '',
        tx_hash: txHash,
        status: 'Failed',
        error: String(error)
      };
    }
  }

  /**
   * Update transaction status
   */
  async updateTransactionStatus(
    id: string,
    status: string,
    metadata?: Record<string, any>
  ): Promise<{ success: boolean; id: string; status: string; error?: string }> {
    try {
      const result = await this.bridge.execute('Storage.update_transaction_status', [id, status, metadata]);

      if (result?.success) {
        this.emit(StorageEvent.DATA_CHANGED, {
          type: 'transaction',
          action: 'update',
          id,
          status
        });
      }

      return result;
    } catch (error) {
      this.emit(StorageEvent.ERROR, error);
      return {
        success: false,
        id,
        status: 'Error',
        error: String(error)
      };
    }
  }

  /**
   * Get transaction by ID
   */
  async getTransaction(id: string): Promise<Transaction | null> {
    try {
      const result = await this.bridge.execute('Storage.get_transaction', [id]);
      return result || null;
    } catch (error) {
      this.emit(StorageEvent.ERROR, error);
      return null;
    }
  }

  /**
   * Get transaction by hash
   */
  async getTransactionByHash(txHash: string): Promise<Transaction | null> {
    try {
      const result = await this.bridge.execute('Storage.get_transaction_by_hash', [txHash]);
      return result || null;
    } catch (error) {
      this.emit(StorageEvent.ERROR, error);
      return null;
    }
  }

  /**
   * List transactions
   */
  async listTransactions(filters?: {
    chain?: string;
    status?: string;
    fromAddress?: string;
    toAddress?: string;
    token?: string;
    startDate?: string;
    endDate?: string;
    limit?: number;
    offset?: number;
  }): Promise<Transaction[]> {
    try {
      const result = await this.bridge.execute('Storage.list_transactions', [filters]);
      return result || [];
    } catch (error) {
      this.emit(StorageEvent.ERROR, error);
      return [];
    }
  }

  // Database Maintenance methods are below

  // =====================
  // Database Maintenance
  // =====================

  /**
   * Backup the database
   *
   * This is a lower-level method than createBackup() and doesn't emit events
   */
  async backupDatabase(backupPath?: string): Promise<{
    success: boolean;
    backup_path: string;
    error?: string;
  }> {
    try {
      const result = await this.bridge.execute('Storage.backup_database', [backupPath]);
      return result;
    } catch (error) {
      return {
        success: false,
        backup_path: '',
        error: String(error)
      };
    }
  }

  /**
   * Vacuum the database to reclaim space
   */
  async vacuumDatabase(): Promise<{
    success: boolean;
    space_saved?: number; // in bytes
    error?: string;
  }> {
    try {
      const result = await this.bridge.execute('Storage.vacuum_database', []);
      return result;
    } catch (error) {
      return {
        success: false,
        error: String(error)
      };
    }
  }

  /**
   * Get database statistics
   */
  async getDatabaseStats(): Promise<{
    size: number; // in bytes
    tables: number;
    rows: Record<string, number>; // table name -> row count
    last_vacuum?: string; // timestamp
    last_backup?: string; // timestamp
  }> {
    try {
      const result = await this.bridge.execute('Storage.get_database_stats', []);
      return result;
    } catch (error) {
      this.emit(StorageEvent.ERROR, error);
      return {
        size: 0,
        tables: 0,
        rows: {}
      };
    }
  }
}