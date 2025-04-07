/**
 * JuliaOS Framework - Local Storage Module
 * 
 * Provides an interface to the local SQLite database in the Julia backend.
 */

import { JuliaBridge } from '@juliaos/julia-bridge';

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
 * LocalStorage class for interacting with the local SQLite database
 */
export class LocalStorage {
  private bridge: JuliaBridge;

  constructor(bridge: JuliaBridge) {
    this.bridge = bridge;
  }

  // =====================
  // Agent CRUD Operations
  // =====================

  /**
   * Create a new agent in local storage
   */
  async createAgent(id: string, name: string, type: string, config: Record<string, any>): Promise<Agent> {
    const result = await this.bridge.execute('Storage.create_agent', [id, name, type, JSON.stringify(config)]);
    return result;
  }

  /**
   * Get agent by ID
   */
  async getAgent(id: string): Promise<Agent | null> {
    const result = await this.bridge.execute('Storage.get_agent', [id]);
    return result || null;
  }

  /**
   * List all agents
   */
  async listAgents(): Promise<Agent[]> {
    const result = await this.bridge.execute('Storage.list_agents', []);
    return result || [];
  }

  /**
   * Update agent
   */
  async updateAgent(id: string, updates: Partial<Agent>): Promise<Agent> {
    const result = await this.bridge.execute('Storage.update_agent', [id, updates]);
    return result;
  }

  /**
   * Delete agent
   */
  async deleteAgent(id: string): Promise<{ success: boolean; id: string }> {
    const result = await this.bridge.execute('Storage.delete_agent', [id]);
    return result;
  }

  // =====================
  // Swarm CRUD Operations
  // =====================

  /**
   * Create a new swarm
   */
  async createSwarm(
    id: string,
    name: string,
    type: string,
    algorithm: string,
    config: Record<string, any>
  ): Promise<Swarm> {
    const result = await this.bridge.execute(
      'Storage.create_swarm',
      [id, name, type, algorithm, JSON.stringify(config)]
    );
    return result;
  }

  /**
   * Get swarm by ID
   */
  async getSwarm(id: string): Promise<Swarm | null> {
    const result = await this.bridge.execute('Storage.get_swarm', [id]);
    return result || null;
  }

  /**
   * List all swarms
   */
  async listSwarms(): Promise<Swarm[]> {
    const result = await this.bridge.execute('Storage.list_swarms', []);
    return result || [];
  }

  /**
   * Update swarm
   */
  async updateSwarm(id: string, updates: Partial<Swarm>): Promise<Swarm> {
    const result = await this.bridge.execute('Storage.update_swarm', [id, updates]);
    return result;
  }

  /**
   * Delete swarm
   */
  async deleteSwarm(id: string): Promise<{ success: boolean; id: string }> {
    const result = await this.bridge.execute('Storage.delete_swarm', [id]);
    return result;
  }

  /**
   * Add agent to swarm
   */
  async addAgentToSwarm(swarmId: string, agentId: string): Promise<{ success: boolean }> {
    const result = await this.bridge.execute('Storage.add_agent_to_swarm', [swarmId, agentId]);
    return result;
  }

  /**
   * Remove agent from swarm
   */
  async removeAgentFromSwarm(swarmId: string, agentId: string): Promise<{ success: boolean }> {
    const result = await this.bridge.execute('Storage.remove_agent_from_swarm', [swarmId, agentId]);
    return result;
  }

  /**
   * Get agents in swarm
   */
  async getSwarmAgents(swarmId: string): Promise<Agent[]> {
    const result = await this.bridge.execute('Storage.get_swarm_agents', [swarmId]);
    return result || [];
  }

  // =====================
  // Settings Operations
  // =====================

  /**
   * Save setting
   */
  async saveSetting(key: string, value: any): Promise<{ success: boolean; key: string }> {
    const result = await this.bridge.execute('Storage.save_setting', [key, value]);
    return result;
  }

  /**
   * Get setting
   */
  async getSetting(key: string, defaultValue: any = null): Promise<any> {
    const result = await this.bridge.execute('Storage.get_setting', [key, defaultValue]);
    return result;
  }

  /**
   * List all settings
   */
  async listSettings(): Promise<Array<{ key: string; value: any; updated_at?: string }>> {
    const result = await this.bridge.execute('Storage.list_settings', []);
    return result || [];
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
  ): Promise<{ id: string; tx_hash: string; status: string }> {
    const result = await this.bridge.execute(
      'Storage.record_transaction',
      [chain, txHash, fromAddress, toAddress, amount, token, status]
    );
    return result;
  }

  /**
   * Update transaction status
   */
  async updateTransactionStatus(
    id: string,
    status: string
  ): Promise<{ success: boolean; id: string; status: string }> {
    const result = await this.bridge.execute('Storage.update_transaction_status', [id, status]);
    return result;
  }

  /**
   * Get transaction by ID
   */
  async getTransaction(id: string): Promise<Transaction | null> {
    const result = await this.bridge.execute('Storage.get_transaction', [id]);
    return result || null;
  }

  /**
   * List transactions with optional filters
   */
  async listTransactions(options: {
    chain?: string;
    status?: string;
    address?: string;
    limit?: number;
  } = {}): Promise<Transaction[]> {
    const result = await this.bridge.execute('Storage.list_transactions', [
      options.chain,
      options.status,
      options.address,
      options.limit || 50
    ]);
    return result || [];
  }

  // =====================
  // Database Maintenance
  // =====================

  /**
   * Backup the database
   */
  async backupDatabase(backupPath?: string): Promise<{ success: boolean; backup_path: string }> {
    const result = await this.bridge.execute('Storage.backup_database', [backupPath]);
    return result;
  }

  /**
   * Vacuum the database to reclaim space
   */
  async vacuumDatabase(): Promise<{ success: boolean }> {
    const result = await this.bridge.execute('Storage.vacuum_database', []);
    return result;
  }
} 