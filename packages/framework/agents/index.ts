/**
 * JuliaOS Framework - Agents Module
 *
 * This module provides interfaces for creating and managing agents in the JuliaOS framework.
 */

// Export specialized agent types
export * from './specialized';

// Export blockchain integration
export * from './blockchain';

// Export messaging system
export * from './messaging';

// Export collaboration system
export * from './collaboration';

import { JuliaBridge } from '@juliaos/julia-bridge';
import { EventEmitter } from 'events';

/**
 * Agent types
 */
export enum AgentType {
  TRADING = 'TRADING',
  MONITOR = 'MONITOR',
  ARBITRAGE = 'ARBITRAGE',
  DATA_COLLECTION = 'DATA_COLLECTION',
  NOTIFICATION = 'NOTIFICATION',
  CUSTOM = 'CUSTOM'
}

/**
 * Agent status
 */
export enum AgentStatus {
  CREATED = 'CREATED',
  INITIALIZING = 'INITIALIZING',
  RUNNING = 'RUNNING',
  PAUSED = 'PAUSED',
  STOPPED = 'STOPPED',
  ERROR = 'ERROR'
}

/**
 * Agent configuration
 */
export interface AgentConfig {
  name: string;
  type: AgentType;
  abilities?: string[];
  chains?: string[];
  parameters?: Record<string, any>;
  llmConfig?: {
    provider: string;
    model: string;
    temperature?: number;
    maxTokens?: number;
    [key: string]: any;
  };
  memoryConfig?: {
    maxSize?: number;
    retentionPolicy?: 'lru' | 'fifo';
    [key: string]: any;
  };
}

/**
 * Agent interface
 */
export interface Agent {
  id: string;
  name: string;
  type: AgentType;
  status: AgentStatus;
  created: string;
  updated: string;
  config: AgentConfig;
  memory?: Record<string, any>;
  task_history?: Array<Record<string, any>>;
}

/**
 * Agent task
 */
export interface AgentTask {
  id: string;
  agentId: string;
  type: string;
  input: Record<string, any>;
  output?: Record<string, any>;
  status: 'pending' | 'running' | 'completed' | 'error';
  error?: string;
  created: string;
  updated: string;
}

/**
 * Agent events
 */
export enum AgentEvent {
  CREATED = 'agent:created',
  UPDATED = 'agent:updated',
  DELETED = 'agent:deleted',
  STARTED = 'agent:started',
  STOPPED = 'agent:stopped',
  PAUSED = 'agent:paused',
  RESUMED = 'agent:resumed',
  TASK_CREATED = 'agent:task:created',
  TASK_COMPLETED = 'agent:task:completed',
  TASK_ERROR = 'agent:task:error',
  ERROR = 'agent:error'
}

/**
 * AgentManager class for interacting with the Julia agent system
 */
export class AgentManager extends EventEmitter {
  private bridge: JuliaBridge;

  /**
   * Create a new AgentManager
   *
   * @param bridge - JuliaBridge instance for communicating with the Julia backend
   */
  constructor(bridge: JuliaBridge) {
    super();
    this.bridge = bridge;
  }

  /**
   * Create a new agent
   *
   * @param config - Agent configuration
   * @returns Promise with the created agent
   */
  async createAgent(config: AgentConfig): Promise<Agent> {
    try {
      const result = await this.bridge.execute('Agents.createAgent', [
        config.name,
        config.type,
        config.abilities || [],
        config.chains || [],
        config.parameters || {},
        config.llmConfig || {},
        config.memoryConfig || {}
      ]);

      this.emit(AgentEvent.CREATED, result);
      return result;
    } catch (error) {
      this.emit(AgentEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Get an agent by ID
   *
   * @param id - Agent ID
   * @returns Promise with the agent or null if not found
   */
  async getAgent(id: string): Promise<Agent | null> {
    try {
      return await this.bridge.execute('Agents.getAgent', [id]);
    } catch (error) {
      this.emit(AgentEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * List all agents, optionally filtered by type or status
   *
   * @param options - Filter options
   * @returns Promise with array of agents
   */
  async listAgents(options: { type?: AgentType; status?: AgentStatus } = {}): Promise<Agent[]> {
    try {
      return await this.bridge.execute('Agents.listAgents', [options.type, options.status]);
    } catch (error) {
      this.emit(AgentEvent.ERROR, error);
      return [];
    }
  }

  /**
   * Update an agent
   *
   * @param id - Agent ID
   * @param updates - Fields to update
   * @returns Promise with the updated agent
   */
  async updateAgent(id: string, updates: Partial<AgentConfig>): Promise<Agent | null> {
    try {
      const result = await this.bridge.execute('Agents.updateAgent', [id, updates]);

      if (result) {
        this.emit(AgentEvent.UPDATED, result);
      }

      return result;
    } catch (error) {
      this.emit(AgentEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Delete an agent
   *
   * @param id - Agent ID
   * @returns Promise with success status
   */
  async deleteAgent(id: string): Promise<boolean> {
    try {
      const result = await this.bridge.execute('Agents.deleteAgent', [id]);

      if (result) {
        this.emit(AgentEvent.DELETED, { id });
      }

      return result;
    } catch (error) {
      this.emit(AgentEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Start an agent
   *
   * @param id - Agent ID
   * @returns Promise with success status
   */
  async startAgent(id: string): Promise<boolean> {
    try {
      const result = await this.bridge.execute('Agents.startAgent', [id]);

      if (result) {
        this.emit(AgentEvent.STARTED, { id });
      }

      return result;
    } catch (error) {
      this.emit(AgentEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Stop an agent
   *
   * @param id - Agent ID
   * @returns Promise with success status
   */
  async stopAgent(id: string): Promise<boolean> {
    try {
      const result = await this.bridge.execute('Agents.stopAgent', [id]);

      if (result) {
        this.emit(AgentEvent.STOPPED, { id });
      }

      return result;
    } catch (error) {
      this.emit(AgentEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Pause an agent
   *
   * @param id - Agent ID
   * @returns Promise with success status
   */
  async pauseAgent(id: string): Promise<boolean> {
    try {
      const result = await this.bridge.execute('Agents.pauseAgent', [id]);

      if (result) {
        this.emit(AgentEvent.PAUSED, { id });
      }

      return result;
    } catch (error) {
      this.emit(AgentEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Resume an agent
   *
   * @param id - Agent ID
   * @returns Promise with success status
   */
  async resumeAgent(id: string): Promise<boolean> {
    try {
      const result = await this.bridge.execute('Agents.resumeAgent', [id]);

      if (result) {
        this.emit(AgentEvent.RESUMED, { id });
      }

      return result;
    } catch (error) {
      this.emit(AgentEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Get agent status
   *
   * @param id - Agent ID
   * @returns Promise with agent status
   */
  async getAgentStatus(id: string): Promise<Record<string, any>> {
    try {
      return await this.bridge.execute('Agents.getAgentStatus', [id]);
    } catch (error) {
      this.emit(AgentEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Execute a task with an agent
   *
   * @param id - Agent ID
   * @param task - Task data
   * @returns Promise with task result
   */
  async executeAgentTask(id: string, task: Record<string, any>): Promise<Record<string, any>> {
    try {
      const result = await this.bridge.execute('Agents.executeAgentTask', [id, task]);

      if (result.success) {
        this.emit(AgentEvent.TASK_COMPLETED, {
          agentId: id,
          taskId: result.data?.task_id,
          result
        });
      } else {
        this.emit(AgentEvent.TASK_ERROR, {
          agentId: id,
          error: result.error
        });
      }

      return result;
    } catch (error) {
      this.emit(AgentEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Get a value from agent memory
   *
   * @param id - Agent ID
   * @param key - Memory key
   * @returns Promise with memory value
   */
  async getAgentMemory(id: string, key: string): Promise<any> {
    try {
      return await this.bridge.execute('Agents.getAgentMemory', [id, key]);
    } catch (error) {
      this.emit(AgentEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Set a value in agent memory
   *
   * @param id - Agent ID
   * @param key - Memory key
   * @param value - Memory value
   * @returns Promise with success status
   */
  async setAgentMemory(id: string, key: string, value: any): Promise<boolean> {
    try {
      return await this.bridge.execute('Agents.setAgentMemory', [id, key, value]);
    } catch (error) {
      this.emit(AgentEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Clear agent memory
   *
   * @param id - Agent ID
   * @returns Promise with success status
   */
  async clearAgentMemory(id: string): Promise<boolean> {
    try {
      return await this.bridge.execute('Agents.clearAgentMemory', [id]);
    } catch (error) {
      this.emit(AgentEvent.ERROR, error);
      throw error;
    }
  }
}
