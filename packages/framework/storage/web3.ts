/**
 * JuliaOS Framework - Web3 Storage Module
 * 
 * Provides an interface to the Web3 storage system (Ceramic Network + IPFS)
 */

import { JuliaBridge } from '@juliaos/julia-bridge';
import { Agent, Swarm, StorageInfo } from './local';

/**
 * Web3Storage class for interacting with Ceramic Network and IPFS
 */
export class Web3Storage {
  private bridge: JuliaBridge;

  constructor(bridge: JuliaBridge) {
    this.bridge = bridge;
  }

  // =====================
  // Configuration
  // =====================

  /**
   * Configure Web3 storage with Ceramic and IPFS connection details
   */
  async configure(options: {
    ceramicNodeUrl?: string;
    ipfsApiUrl?: string;
    ipfsApiKey?: string;
  }): Promise<{
    ceramic_url: string;
    ipfs_api_url: string;
    ipfs_api_key_configured: boolean;
  }> {
    const result = await this.bridge.execute('Web3Storage.configure', [
      options.ceramicNodeUrl,
      options.ipfsApiUrl,
      options.ipfsApiKey
    ]);
    return result;
  }

  // =====================
  // Agent Storage
  // =====================

  /**
   * Store agent in Web3 storage (Ceramic + IPFS)
   */
  async storeAgent(agentData: Agent): Promise<{
    success: boolean;
    ceramic_doc_id?: string;
    large_data?: Record<string, string>;
    error?: string;
  }> {
    const result = await this.bridge.execute('Web3Storage.store_agent', [agentData]);
    return result;
  }

  /**
   * Retrieve agent from Web3 storage
   */
  async retrieveAgent(ceramicDocId: string): Promise<{
    success: boolean;
    agent?: Agent;
    error?: string;
  }> {
    const result = await this.bridge.execute('Web3Storage.retrieve_agent', [ceramicDocId]);
    return result;
  }

  /**
   * Update agent in Web3 storage
   */
  async updateAgent(
    ceramicDocId: string,
    updates: Partial<Agent>
  ): Promise<{
    success: boolean;
    document_id?: string;
    content?: any;
    error?: string;
  }> {
    const result = await this.bridge.execute('Web3Storage.update_agent', [ceramicDocId, updates]);
    return result;
  }

  // =====================
  // Swarm Storage
  // =====================

  /**
   * Store swarm in Web3 storage
   */
  async storeSwarm(swarmData: Swarm): Promise<{
    success: boolean;
    ceramic_doc_id?: string;
    large_data?: Record<string, string>;
    error?: string;
  }> {
    const result = await this.bridge.execute('Web3Storage.store_swarm', [swarmData]);
    return result;
  }

  /**
   * Retrieve swarm from Web3 storage
   */
  async retrieveSwarm(ceramicDocId: string): Promise<{
    success: boolean;
    swarm?: Swarm;
    error?: string;
  }> {
    const result = await this.bridge.execute('Web3Storage.retrieve_swarm', [ceramicDocId]);
    return result;
  }

  /**
   * Update swarm in Web3 storage
   */
  async updateSwarm(
    ceramicDocId: string,
    updates: Partial<Swarm>
  ): Promise<{
    success: boolean;
    document_id?: string;
    content?: any;
    error?: string;
  }> {
    const result = await this.bridge.execute('Web3Storage.update_swarm', [ceramicDocId, updates]);
    return result;
  }

  // =====================
  // Marketplace Functions
  // =====================

  /**
   * Publish agent to marketplace
   */
  async publishAgentToMarketplace(
    agentData: Agent,
    description: string,
    price: string = '0',
    category: string = 'general'
  ): Promise<{
    success: boolean;
    listing_id?: string;
    storage_info?: any;
    error?: string;
  }> {
    const result = await this.bridge.execute('Web3Storage.publish_agent_to_marketplace', [
      agentData,
      description,
      price,
      category
    ]);
    return result;
  }

  /**
   * Publish swarm to marketplace
   */
  async publishSwarmToMarketplace(
    swarmData: Swarm,
    description: string,
    price: string = '0',
    category: string = 'general'
  ): Promise<{
    success: boolean;
    listing_id?: string;
    storage_info?: any;
    error?: string;
  }> {
    const result = await this.bridge.execute('Web3Storage.publish_swarm_to_marketplace', [
      swarmData,
      description,
      price,
      category
    ]);
    return result;
  }

  /**
   * List agents in marketplace
   */
  async listMarketplaceAgents(category?: string): Promise<{
    success: boolean;
    listings?: Array<{
      listing_id: string;
      agent_id: string;
      name: string;
      description: string;
      price: string;
      category: string;
      creator: string;
      created_at: string;
      rating: number;
      downloads: number;
    }>;
    error?: string;
  }> {
    const result = await this.bridge.execute('Web3Storage.list_marketplace_agents', [category]);
    return result;
  }

  // =====================
  // IPFS Direct Operations
  // =====================

  /**
   * Upload data to IPFS
   */
  async uploadToIPFS(
    fileData: string | Uint8Array,
    filename: string = 'file.bin',
    mimeType: string = 'application/octet-stream'
  ): Promise<{
    success: boolean;
    cid?: string;
    url?: string;
    error?: string;
  }> {
    const result = await this.bridge.execute('Web3Storage.upload_to_ipfs', [
      fileData,
      filename,
      mimeType
    ]);
    return result;
  }

  /**
   * Get data from IPFS by CID
   */
  async getFromIPFS(cid: string): Promise<{
    success: boolean;
    data?: Uint8Array;
    error?: string;
  }> {
    const result = await this.bridge.execute('Web3Storage.get_from_ipfs', [cid]);
    return result;
  }

  /**
   * Upload JSON data to IPFS
   */
  async uploadJSONToIPFS(
    jsonData: any,
    filename: string = 'data.json'
  ): Promise<{
    success: boolean;
    cid?: string;
    url?: string;
    error?: string;
  }> {
    const result = await this.bridge.execute('Web3Storage.upload_json_to_ipfs', [
      jsonData,
      filename
    ]);
    return result;
  }

  /**
   * Get JSON data from IPFS
   */
  async getJSONFromIPFS(cid: string): Promise<{
    success: boolean;
    data?: any;
    error?: string;
  }> {
    const result = await this.bridge.execute('Web3Storage.get_json_from_ipfs', [cid]);
    return result;
  }
}

/**
 * StorageSync class for managing synchronization between local and Web3 storage
 */
export class StorageSync {
  private bridge: JuliaBridge;

  constructor(bridge: JuliaBridge) {
    this.bridge = bridge;
  }

  /**
   * Initialize synchronization configuration
   */
  async initSync(): Promise<{
    sync_enabled: boolean;
    auto_sync_interval: number;
    sync_preferences: Record<string, boolean>;
  }> {
    const result = await this.bridge.execute('Sync.init_sync', []);
    return result;
  }

  /**
   * Enable or disable synchronization
   */
  async enableSync(enabled: boolean = true): Promise<{
    success: boolean;
    sync_enabled: boolean;
  }> {
    const result = await this.bridge.execute('Sync.enable_sync', [enabled]);
    return result;
  }

  /**
   * Set synchronization preferences
   */
  async setSyncPreferences(prefs: Record<string, boolean>): Promise<{
    success: boolean;
    sync_preferences: Record<string, boolean>;
  }> {
    const result = await this.bridge.execute('Sync.set_sync_preferences', [prefs]);
    return result;
  }

  /**
   * Set auto-sync interval (in seconds)
   */
  async setAutoSyncInterval(interval: number): Promise<{
    success: boolean;
    auto_sync_interval: number;
  }> {
    const result = await this.bridge.execute('Sync.set_auto_sync_interval', [interval]);
    return result;
  }

  /**
   * Synchronize a single agent
   */
  async syncAgent(
    agentId: string,
    direction: 'both' | 'local_to_web3' | 'web3_to_local' = 'both'
  ): Promise<{
    success: boolean;
    action?: string;
    storage_info?: StorageInfo;
    error?: string;
  }> {
    const result = await this.bridge.execute('Sync.sync_agent', [agentId, direction]);
    return result;
  }

  /**
   * Synchronize all agents
   */
  async syncAllAgents(
    direction: 'both' | 'local_to_web3' | 'web3_to_local' = 'both'
  ): Promise<{
    success: boolean;
    results?: Record<string, any>;
    error?: string;
  }> {
    const result = await this.bridge.execute('Sync.sync_all_agents', [direction]);
    return result;
  }

  /**
   * Synchronize a single swarm
   */
  async syncSwarm(
    swarmId: string,
    direction: 'both' | 'local_to_web3' | 'web3_to_local' = 'both'
  ): Promise<{
    success: boolean;
    action?: string;
    storage_info?: StorageInfo;
    error?: string;
  }> {
    const result = await this.bridge.execute('Sync.sync_swarm', [swarmId, direction]);
    return result;
  }

  /**
   * Synchronize all swarms
   */
  async syncAllSwarms(
    direction: 'both' | 'local_to_web3' | 'web3_to_local' = 'both'
  ): Promise<{
    success: boolean;
    results?: Record<string, any>;
    error?: string;
  }> {
    const result = await this.bridge.execute('Sync.sync_all_swarms', [direction]);
    return result;
  }

  /**
   * Synchronize settings
   */
  async syncSettings(
    direction: 'both' | 'local_to_web3' | 'web3_to_local' = 'both'
  ): Promise<{
    success: boolean;
    action?: string;
    storage_info?: StorageInfo;
    error?: string;
  }> {
    const result = await this.bridge.execute('Sync.sync_settings', [direction]);
    return result;
  }

  /**
   * Synchronize everything
   */
  async syncAll(
    direction: 'both' | 'local_to_web3' | 'web3_to_local' = 'both'
  ): Promise<{
    success: boolean;
    results?: Record<string, any>;
    last_sync_time?: string;
    error?: string;
  }> {
    const result = await this.bridge.execute('Sync.sync_all', [direction]);
    return result;
  }

  /**
   * Get synchronization status
   */
  async getSyncStatus(): Promise<{
    sync_enabled: boolean;
    auto_sync_interval: number;
    sync_preferences: Record<string, boolean>;
    last_sync_time?: string;
    auto_sync_due: boolean;
  }> {
    const result = await this.bridge.execute('Sync.get_sync_status', []);
    return result;
  }
} 