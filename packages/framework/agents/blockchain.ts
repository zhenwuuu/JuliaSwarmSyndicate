/**
 * JuliaOS Framework - Agent Blockchain Integration Module
 * 
 * This module provides interfaces for agents to interact with blockchains and wallets.
 */

import { JuliaBridge } from '@juliaos/julia-bridge';
import { EventEmitter } from 'events';

/**
 * Agent blockchain integration events
 */
export enum AgentBlockchainEvent {
  WALLET_ASSIGNED = 'agent:blockchain:wallet:assigned',
  TRANSACTION_SENT = 'agent:blockchain:transaction:sent',
  TRANSACTION_CONFIRMED = 'agent:blockchain:transaction:confirmed',
  TRANSACTION_FAILED = 'agent:blockchain:transaction:failed',
  BALANCE_UPDATED = 'agent:blockchain:balance:updated',
  ERROR = 'agent:blockchain:error'
}

/**
 * Transaction parameters
 */
export interface TransactionParams {
  to: string;
  value?: string;
  data?: string;
  gasLimit?: string;
  gasPrice?: string;
  maxFeePerGas?: string;
  maxPriorityFeePerGas?: string;
  nonce?: number;
  [key: string]: any;
}

/**
 * Transaction record
 */
export interface TransactionRecord {
  hash: string;
  from: string;
  to: string;
  value: string;
  data: string;
  timestamp: string;
  status: 'pending' | 'confirmed' | 'failed';
  confirmations?: number;
  blockNumber?: number;
  gasUsed?: number;
  effectiveGasPrice?: string;
  [key: string]: any;
}

/**
 * Wallet assignment
 */
export interface WalletAssignment {
  walletId: string;
  address: string;
  assignedAt: string;
}

/**
 * AgentBlockchainIntegration class for interacting with blockchains and wallets
 */
export class AgentBlockchainIntegration extends EventEmitter {
  private bridge: JuliaBridge;
  private agentId: string;

  /**
   * Create a new AgentBlockchainIntegration
   * 
   * @param bridge - JuliaBridge instance for communicating with the Julia backend
   * @param agentId - ID of the agent
   */
  constructor(bridge: JuliaBridge, agentId: string) {
    super();
    this.bridge = bridge;
    this.agentId = agentId;
  }

  /**
   * Initialize blockchain integration for the agent
   * 
   * @returns Promise with initialization result
   */
  async initialize(): Promise<Record<string, any>> {
    try {
      return await this.bridge.execute('AgentBlockchainIntegration.initialize', [this.agentId]);
    } catch (error) {
      this.emit(AgentBlockchainEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Assign a wallet to the agent for a specific blockchain
   * 
   * @param walletId - Wallet ID
   * @param chain - Blockchain network
   * @returns Promise with assignment result
   */
  async assignWallet(walletId: string, chain: string): Promise<Record<string, any>> {
    try {
      const result = await this.bridge.execute('AgentBlockchainIntegration.assign_wallet', [
        this.agentId,
        walletId,
        chain
      ]);

      if (result.success) {
        this.emit(AgentBlockchainEvent.WALLET_ASSIGNED, {
          agentId: this.agentId,
          walletId,
          chain,
          address: result.address
        });
      }

      return result;
    } catch (error) {
      this.emit(AgentBlockchainEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Get the wallet assigned to the agent for a specific blockchain
   * 
   * @param chain - Blockchain network
   * @returns Promise with wallet information
   */
  async getAgentWallet(chain: string): Promise<Record<string, any>> {
    try {
      return await this.bridge.execute('AgentBlockchainIntegration.get_agent_wallet', [
        this.agentId,
        chain
      ]);
    } catch (error) {
      this.emit(AgentBlockchainEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Get the balance of the agent's wallet on a specific blockchain
   * 
   * @param chain - Blockchain network
   * @returns Promise with balance information
   */
  async getBalance(chain: string): Promise<Record<string, any>> {
    try {
      const result = await this.bridge.execute('AgentBlockchainIntegration.get_balance', [
        this.agentId,
        chain
      ]);

      if (result.success) {
        this.emit(AgentBlockchainEvent.BALANCE_UPDATED, {
          agentId: this.agentId,
          chain,
          address: result.address,
          balance: result.balance
        });
      }

      return result;
    } catch (error) {
      this.emit(AgentBlockchainEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Get the token balance of the agent's wallet on a specific blockchain
   * 
   * @param chain - Blockchain network
   * @param tokenAddress - Token contract address
   * @returns Promise with token balance information
   */
  async getTokenBalance(chain: string, tokenAddress: string): Promise<Record<string, any>> {
    try {
      const result = await this.bridge.execute('AgentBlockchainIntegration.get_token_balance', [
        this.agentId,
        chain,
        tokenAddress
      ]);

      if (result.success) {
        this.emit(AgentBlockchainEvent.BALANCE_UPDATED, {
          agentId: this.agentId,
          chain,
          address: result.address,
          tokenAddress,
          balance: result.balance
        });
      }

      return result;
    } catch (error) {
      this.emit(AgentBlockchainEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Execute a blockchain transaction
   * 
   * @param chain - Blockchain network
   * @param transaction - Transaction parameters
   * @returns Promise with transaction result
   */
  async executeTransaction(chain: string, transaction: TransactionParams): Promise<Record<string, any>> {
    try {
      const result = await this.bridge.execute('AgentBlockchainIntegration.execute_transaction', [
        this.agentId,
        chain,
        transaction
      ]);

      if (result.success) {
        this.emit(AgentBlockchainEvent.TRANSACTION_SENT, {
          agentId: this.agentId,
          chain,
          transactionHash: result.transaction_hash,
          from: result.from,
          to: result.to
        });
      }

      return result;
    } catch (error) {
      this.emit(AgentBlockchainEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Transfer native tokens (ETH, SOL, etc.)
   * 
   * @param chain - Blockchain network
   * @param to - Recipient address
   * @param amount - Amount to transfer
   * @returns Promise with transfer result
   */
  async transferNative(chain: string, to: string, amount: number): Promise<Record<string, any>> {
    try {
      const result = await this.bridge.execute('AgentBlockchainIntegration.transfer_native', [
        this.agentId,
        chain,
        to,
        amount
      ]);

      if (result.success) {
        this.emit(AgentBlockchainEvent.TRANSACTION_SENT, {
          agentId: this.agentId,
          chain,
          transactionHash: result.transaction_hash,
          from: result.from,
          to: result.to,
          amount
        });
      }

      return result;
    } catch (error) {
      this.emit(AgentBlockchainEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Transfer tokens
   * 
   * @param chain - Blockchain network
   * @param tokenAddress - Token contract address
   * @param to - Recipient address
   * @param amount - Amount to transfer
   * @returns Promise with transfer result
   */
  async transferTokens(
    chain: string,
    tokenAddress: string,
    to: string,
    amount: number
  ): Promise<Record<string, any>> {
    try {
      const result = await this.bridge.execute('AgentBlockchainIntegration.transfer_tokens', [
        this.agentId,
        chain,
        tokenAddress,
        to,
        amount
      ]);

      if (result.success) {
        this.emit(AgentBlockchainEvent.TRANSACTION_SENT, {
          agentId: this.agentId,
          chain,
          transactionHash: result.transaction_hash,
          from: result.from,
          to,
          tokenAddress,
          amount
        });
      }

      return result;
    } catch (error) {
      this.emit(AgentBlockchainEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Sign a message
   * 
   * @param chain - Blockchain network
   * @param message - Message to sign
   * @returns Promise with signature information
   */
  async signMessage(chain: string, message: string): Promise<Record<string, any>> {
    try {
      return await this.bridge.execute('AgentBlockchainIntegration.sign_message', [
        this.agentId,
        chain,
        message
      ]);
    } catch (error) {
      this.emit(AgentBlockchainEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Monitor blockchain events
   * 
   * @param chain - Blockchain network
   * @param eventTypes - Types of events to monitor
   * @returns Promise with monitoring result
   */
  async monitorBlockchain(chain: string, eventTypes: string[]): Promise<Record<string, any>> {
    try {
      return await this.bridge.execute('AgentBlockchainIntegration.monitor_blockchain', [
        this.agentId,
        chain,
        eventTypes
      ]);
    } catch (error) {
      this.emit(AgentBlockchainEvent.ERROR, error);
      throw error;
    }
  }
}
