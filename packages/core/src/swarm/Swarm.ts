import { EventEmitter } from 'events';
import { BaseAgent } from '../agent/BaseAgent';
import { LLMConfig } from '../llm/LLMProvider';

export interface SwarmConfig {
  name: string;
  type: string;
  coordinationStrategy: 'independent' | 'coordinated' | 'hierarchical' | 'consensus';
  maxAgents: number;
  minAgents: number;
  autoScale: boolean;
  llmConfig?: LLMConfig;
  parameters?: Record<string, any>;
}

export interface SwarmMetrics {
  activeAgents: number;
  totalTasks: number;
  completedTasks: number;
  failedTasks: number;
  averageResponseTime: number;
  consensusEvents: number;
  lastUpdated: number;
}

export interface Task {
  id: string;
  type: string;
  priority: number;
  data: Record<string, any>;
  agentId?: string;
  deadline?: number;
  retries?: number;
  maxRetries?: number;
}

export interface SwarmResult {
  taskId: string;
  success: boolean;
  result?: any;
  error?: Error;
  agentId?: string;
  processingTime: number;
}

/**
 * Base Swarm class that serves as the foundation for all swarm implementations
 * A swarm manages a collection of agents that work together towards a common goal.
 */
export abstract class Swarm extends EventEmitter {
  protected name: string;
  protected type: string;
  protected coordinationStrategy: SwarmConfig['coordinationStrategy'];
  protected agents: Map<string, BaseAgent>;
  protected taskQueue: Task[];
  protected metrics: SwarmMetrics;
  protected isRunning: boolean;
  protected maxAgents: number;
  protected minAgents: number;
  protected autoScale: boolean;
  protected parameters: Record<string, any>;
  protected llmConfig?: LLMConfig;
  
  /**
   * Create a new Swarm
   * @param config Configuration options for the swarm
   */
  constructor(config: SwarmConfig) {
    super();
    this.name = config.name;
    this.type = config.type;
    this.coordinationStrategy = config.coordinationStrategy;
    this.maxAgents = config.maxAgents;
    this.minAgents = config.minAgents;
    this.autoScale = config.autoScale;
    this.parameters = config.parameters || {};
    this.llmConfig = config.llmConfig;
    
    this.agents = new Map();
    this.taskQueue = [];
    this.isRunning = false;
    this.metrics = {
      activeAgents: 0,
      totalTasks: 0,
      completedTasks: 0,
      failedTasks: 0,
      averageResponseTime: 0,
      consensusEvents: 0,
      lastUpdated: Date.now()
    };
    
    // Set up event listeners
    this.on('taskCompleted', this.handleTaskCompleted.bind(this));
    this.on('taskFailed', this.handleTaskFailed.bind(this));
    this.on('agentAdded', this.handleAgentAdded.bind(this));
    this.on('agentRemoved', this.handleAgentRemoved.bind(this));
  }
  
  /**
   * Initialize the swarm and its agents
   */
  abstract initialize(): Promise<void>;
  
  /**
   * Start the swarm's operations
   */
  abstract start(): Promise<void>;
  
  /**
   * Stop the swarm's operations
   */
  abstract stop(): Promise<void>;
  
  /**
   * Add an agent to the swarm
   * @param agent The agent to add
   */
  async addAgent(agent: BaseAgent): Promise<void> {
    if (this.agents.size >= this.maxAgents) {
      throw new Error(`Cannot add more agents. Swarm ${this.name} already has maximum number of agents (${this.maxAgents}).`);
    }
    
    if (this.agents.has(agent.getName())) {
      throw new Error(`Agent with name ${agent.getName()} already exists in swarm ${this.name}.`);
    }
    
    // Add agent to the swarm
    this.agents.set(agent.getName(), agent);
    
    // Listen for agent events
    agent.on('error', (error) => this.emit('agentError', { agent, error }));
    agent.on('started', () => this.emit('agentStarted', { agent }));
    agent.on('stopped', () => this.emit('agentStopped', { agent }));
    
    // Update metrics
    this.metrics.activeAgents = this.agents.size;
    this.metrics.lastUpdated = Date.now();
    
    // Emit event
    this.emit('agentAdded', { agent });
  }
  
  /**
   * Remove an agent from the swarm
   * @param agentName The name of the agent to remove
   */
  async removeAgent(agentName: string): Promise<boolean> {
    if (this.agents.size <= this.minAgents) {
      throw new Error(`Cannot remove agent. Swarm ${this.name} already has minimum number of agents (${this.minAgents}).`);
    }
    
    const agent = this.agents.get(agentName);
    if (!agent) {
      return false;
    }
    
    // Stop agent if it's running
    if (agent.isActive()) {
      await agent.stop();
    }
    
    // Remove agent from the swarm
    this.agents.delete(agentName);
    
    // Update metrics
    this.metrics.activeAgents = this.agents.size;
    this.metrics.lastUpdated = Date.now();
    
    // Emit event
    this.emit('agentRemoved', { agentName });
    
    return true;
  }
  
  /**
   * Submit a task to the swarm
   * @param task The task to submit
   */
  async submitTask(task: Task): Promise<SwarmResult> {
    if (!this.isRunning) {
      throw new Error(`Cannot submit task. Swarm ${this.name} is not running.`);
    }
    
    // Add to metrics
    this.metrics.totalTasks++;
    this.metrics.lastUpdated = Date.now();
    
    // Check if we should assign the task to a specific agent
    if (task.agentId) {
      const agent = this.agents.get(task.agentId);
      if (!agent) {
        throw new Error(`Specified agent ${task.agentId} not found in swarm ${this.name}.`);
      }
      
      return this.executeTaskWithAgent(task, agent);
    }
    
    // Otherwise, route the task based on the coordination strategy
    switch (this.coordinationStrategy) {
      case 'independent':
        return this.routeTaskIndependent(task);
      case 'coordinated':
        return this.routeTaskCoordinated(task);
      case 'hierarchical':
        return this.routeTaskHierarchical(task);
      case 'consensus':
        return this.routeTaskConsensus(task);
      default:
        throw new Error(`Unknown coordination strategy: ${this.coordinationStrategy}`);
    }
  }
  
  /**
   * Route a task for independent execution (round robin)
   * @param task The task to route
   */
  protected async routeTaskIndependent(task: Task): Promise<SwarmResult> {
    // Find the least busy agent
    const availableAgents = Array.from(this.agents.values())
      .filter(agent => agent.isActive())
      .sort((a, b) => 0.5 - Math.random()); // Simple round robin through randomization
    
    if (availableAgents.length === 0) {
      // Queue the task if no agents are available
      return new Promise((resolve, reject) => {
        this.taskQueue.push({
          ...task,
          retries: 0,
          maxRetries: task.maxRetries || 3
        });
        this.processTaskQueue();
      });
    }
    
    // Execute the task with the selected agent
    return this.executeTaskWithAgent(task, availableAgents[0]);
  }
  
  /**
   * Route a task for coordinated execution (agents share information)
   * @param task The task to route
   */
  protected abstract routeTaskCoordinated(task: Task): Promise<SwarmResult>;
  
  /**
   * Route a task for hierarchical execution (leader assigns to followers)
   * @param task The task to route
   */
  protected abstract routeTaskHierarchical(task: Task): Promise<SwarmResult>;
  
  /**
   * Route a task for consensus execution (agents vote on approach)
   * @param task The task to route
   */
  protected abstract routeTaskConsensus(task: Task): Promise<SwarmResult>;
  
  /**
   * Execute a task with a specific agent
   * @param task The task to execute
   * @param agent The agent to execute the task
   */
  protected async executeTaskWithAgent(task: Task, agent: BaseAgent): Promise<SwarmResult> {
    const startTime = Date.now();
    
    try {
      // Execute task with the agent
      // Note: This is a simplified implementation. In practice, you would map the task
      // to specific agent actions, skills, or execution patterns.
      const result = await agent.executeTask(task.data);
      
      const endTime = Date.now();
      const processingTime = endTime - startTime;
      
      // Update metrics
      this.metrics.completedTasks++;
      this.metrics.averageResponseTime = 
        (this.metrics.averageResponseTime * (this.metrics.completedTasks - 1) + processingTime) / 
        this.metrics.completedTasks;
      this.metrics.lastUpdated = endTime;
      
      // Create result
      const swarmResult: SwarmResult = {
        taskId: task.id,
        success: true,
        result,
        agentId: agent.getName(),
        processingTime
      };
      
      // Emit event
      this.emit('taskCompleted', swarmResult);
      
      return swarmResult;
    } catch (error) {
      const endTime = Date.now();
      const processingTime = endTime - startTime;
      
      // Update metrics
      this.metrics.failedTasks++;
      this.metrics.lastUpdated = endTime;
      
      // Create result
      const swarmResult: SwarmResult = {
        taskId: task.id,
        success: false,
        error: error as Error,
        agentId: agent.getName(),
        processingTime
      };
      
      // Emit event
      this.emit('taskFailed', swarmResult);
      
      return swarmResult;
    }
  }
  
  /**
   * Process tasks in the queue
   */
  protected async processTaskQueue(): Promise<void> {
    if (this.taskQueue.length === 0) {
      return;
    }
    
    // Get the next task
    const task = this.taskQueue.shift();
    if (!task) {
      return;
    }
    
    // Find an available agent
    const availableAgents = Array.from(this.agents.values())
      .filter(agent => agent.isActive());
    
    if (availableAgents.length === 0) {
      // Put the task back in the queue if no agents are available
      this.taskQueue.unshift(task);
      return;
    }
    
    // Execute the task
    try {
      await this.routeTaskIndependent(task);
    } catch (error) {
      // If the task fails, retry if retries are available
      if ((task.retries || 0) < (task.maxRetries || 3)) {
        this.taskQueue.push({
          ...task,
          retries: (task.retries || 0) + 1
        });
      } else {
        // Otherwise, emit a task failed event
        this.emit('taskFailed', {
          taskId: task.id,
          success: false,
          error: error as Error,
          processingTime: 0
        });
      }
    }
    
    // Process the next task
    await this.processTaskQueue();
  }
  
  /**
   * Get the current metrics for the swarm
   */
  getMetrics(): SwarmMetrics {
    return { ...this.metrics };
  }
  
  /**
   * Get the name of the swarm
   */
  getName(): string {
    return this.name;
  }
  
  /**
   * Get the type of the swarm
   */
  getType(): string {
    return this.type;
  }
  
  /**
   * Check if the swarm is running
   */
  isActive(): boolean {
    return this.isRunning;
  }
  
  /**
   * Get the number of active agents in the swarm
   */
  getAgentCount(): number {
    return this.agents.size;
  }
  
  /**
   * Event handler for task completed events
   */
  protected handleTaskCompleted(result: SwarmResult): void {
    // This method can be overridden by subclasses to provide custom behavior
  }
  
  /**
   * Event handler for task failed events
   */
  protected handleTaskFailed(result: SwarmResult): void {
    // This method can be overridden by subclasses to provide custom behavior
  }
  
  /**
   * Event handler for agent added events
   */
  protected handleAgentAdded(data: { agent: BaseAgent }): void {
    // This method can be overridden by subclasses to provide custom behavior
  }
  
  /**
   * Event handler for agent removed events
   */
  protected handleAgentRemoved(data: { agentName: string }): void {
    // This method can be overridden by subclasses to provide custom behavior
  }
} 