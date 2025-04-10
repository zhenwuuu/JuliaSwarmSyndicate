/**
 * JuliaOS Framework - Arweave Storage Module
 * 
 * Provides an interface to the Arweave permanent storage network
 */

import { JuliaBridge } from '@juliaos/julia-bridge';
import { Agent, Swarm, StorageInfo, Transaction } from './local';

export interface ArweaveConfig {
  gateway?: string;
  port?: number;
  protocol?: string;
  timeout?: number;
  logging?: boolean;
  arweaveWallet?: string; // JWK wallet file path or key
}

export interface ArweaveStorageInfo extends StorageInfo {
  arweave_tx_id: string;
  arweave_owner: string;
  arweave_tags?: Record<string, string>;
}

/**
 * ArweaveStorage class for interacting with the Arweave permanent storage network
 */
export class ArweaveStorage {
  private bridge: JuliaBridge;
  private config: ArweaveConfig;

  constructor(bridge: JuliaBridge, config: ArweaveConfig = {}) {
    this.bridge = bridge;
    this.config = {
      gateway: 'arweave.net',
      port: 443,
      protocol: 'https',
      timeout: 20000,
      logging: false,
      ...config
    };
  }

  // =====================
  // Configuration
  // =====================

  /**
   * Configure Arweave storage connection
   */
  async configure(options: ArweaveConfig): Promise<{
    gateway: string;
    wallet_configured: boolean;
    connected: boolean;
  }> {
    this.config = { ...this.config, ...options };
    const result = await this.bridge.execute('ArweaveStorage.configure', [
      this.config.gateway,
      this.config.port,
      this.config.protocol,
      this.config.timeout,
      this.config.logging,
      this.config.arweaveWallet
    ]);
    return result;
  }

  /**
   * Get current Arweave network info
   */
  async getNetworkInfo(): Promise<{
    network: string;
    version: string;
    height: number;
    current: string;
    release: number;
    blocks: number;
    peers: number;
    queue_length: number;
    node_state_latency: number;
  }> {
    const result = await this.bridge.execute('ArweaveStorage.get_network_info', []);
    return result;
  }

  /**
   * Get wallet address and balance
   */
  async getWalletInfo(): Promise<{
    address: string;
    balance: string;
    balance_ar: string;
  }> {
    const result = await this.bridge.execute('ArweaveStorage.get_wallet_info', []);
    return result;
  }

  // =====================
  // Agent Storage
  // =====================

  /**
   * Store agent in Arweave permanent storage
   */
  async storeAgent(agentData: Agent, tags: Record<string, string> = {}): Promise<{
    success: boolean;
    arweave_tx_id?: string;
    arweave_owner?: string;
    error?: string;
  }> {
    // Add default tags
    const defaultTags = {
      'Content-Type': 'application/json',
      'App-Name': 'JuliaOS',
      'Type': 'Agent',
      'Agent-ID': agentData.id,
      'Agent-Name': agentData.name,
      'Agent-Type': agentData.type,
      ...tags
    };

    const result = await this.bridge.execute('ArweaveStorage.store_agent', [
      agentData,
      defaultTags
    ]);
    return result;
  }

  /**
   * Retrieve agent from Arweave by transaction ID
   */
  async retrieveAgent(txId: string): Promise<{
    success: boolean;
    agent?: Agent;
    error?: string;
  }> {
    const result = await this.bridge.execute('ArweaveStorage.retrieve_agent', [txId]);
    return result;
  }

  /**
   * Search for agents in Arweave by tags
   */
  async searchAgents(tags: Record<string, string>): Promise<{
    success: boolean;
    results: Array<{
      id: string;
      tx_id: string;
      owner: string;
      tags: Record<string, string>;
      timestamp: number;
    }>;
    error?: string;
  }> {
    const result = await this.bridge.execute('ArweaveStorage.search_agents', [tags]);
    return result;
  }

  // =====================
  // Swarm Storage
  // =====================

  /**
   * Store swarm in Arweave permanent storage
   */
  async storeSwarm(swarmData: Swarm, tags: Record<string, string> = {}): Promise<{
    success: boolean;
    arweave_tx_id?: string;
    arweave_owner?: string;
    error?: string;
  }> {
    // Add default tags
    const defaultTags = {
      'Content-Type': 'application/json',
      'App-Name': 'JuliaOS',
      'Type': 'Swarm',
      'Swarm-ID': swarmData.id,
      'Swarm-Name': swarmData.name,
      'Swarm-Type': swarmData.type,
      ...tags
    };

    const result = await this.bridge.execute('ArweaveStorage.store_swarm', [
      swarmData,
      defaultTags
    ]);
    return result;
  }

  /**
   * Retrieve swarm from Arweave by transaction ID
   */
  async retrieveSwarm(txId: string): Promise<{
    success: boolean;
    swarm?: Swarm;
    error?: string;
  }> {
    const result = await this.bridge.execute('ArweaveStorage.retrieve_swarm', [txId]);
    return result;
  }

  /**
   * Search for swarms in Arweave by tags
   */
  async searchSwarms(tags: Record<string, string>): Promise<{
    success: boolean;
    results: Array<{
      id: string;
      tx_id: string;
      owner: string;
      tags: Record<string, string>;
      timestamp: number;
    }>;
    error?: string;
  }> {
    const result = await this.bridge.execute('ArweaveStorage.search_swarms', [tags]);
    return result;
  }

  // =====================
  // General Data Storage
  // =====================

  /**
   * Store arbitrary data in Arweave
   */
  async storeData(
    data: string | object | Buffer,
    tags: Record<string, string> = {},
    contentType: string = 'application/json'
  ): Promise<{
    success: boolean;
    arweave_tx_id?: string;
    arweave_owner?: string;
    error?: string;
  }> {
    // Add default tags
    const defaultTags = {
      'Content-Type': contentType,
      'App-Name': 'JuliaOS',
      'Type': 'Data',
      ...tags
    };

    // Convert object to string if needed
    const dataToStore = typeof data === 'object' && !(data instanceof Buffer)
      ? JSON.stringify(data)
      : data;

    const result = await this.bridge.execute('ArweaveStorage.store_data', [
      dataToStore,
      defaultTags,
      contentType
    ]);
    return result;
  }

  /**
   * Retrieve data from Arweave by transaction ID
   */
  async retrieveData(txId: string): Promise<{
    success: boolean;
    data?: any;
    content_type?: string;
    tags?: Record<string, string>;
    error?: string;
  }> {
    const result = await this.bridge.execute('ArweaveStorage.retrieve_data', [txId]);
    return result;
  }

  /**
   * Get transaction status
   */
  async getTransactionStatus(txId: string): Promise<{
    status: string;
    confirmed?: {
      block_height: number;
      block_indep_hash: string;
      number_of_confirmations: number;
    };
    pending?: boolean;
  }> {
    const result = await this.bridge.execute('ArweaveStorage.get_transaction_status', [txId]);
    return result;
  }
}
