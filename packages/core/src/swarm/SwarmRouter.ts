import { BaseAgent } from '../agent/BaseAgent';
import { EventEmitter } from 'events';
import { Task, SwarmResult } from './Swarm';
import { LLMProvider, LLMConfig } from '../llm/LLMProvider';

export interface RouterConfig {
  name: string;
  strategy: 'round-robin' | 'load-balanced' | 'skill-based' | 'llm-assisted';
  llmConfig?: LLMConfig;
  parameters?: Record<string, any>;
}

export interface RouterMetrics {
  totalTasks: number;
  routedTasks: number;
  failedTasks: number;
  averageRoutingTime: number;
  lastUpdated: number;
}

/**
 * SwarmRouter is responsible for routing tasks to the most appropriate agents
 * based on different strategies.
 */
export class SwarmRouter extends EventEmitter {
  private name: string;
  private strategy: RouterConfig['strategy'];
  private metrics: RouterMetrics;
  private llmProvider?: LLMProvider;
  private parameters: Record<string, any>;
  
  /**
   * Create a new SwarmRouter
   * @param config Configuration options for the router
   */
  constructor(config: RouterConfig) {
    super();
    this.name = config.name;
    this.strategy = config.strategy;
    this.parameters = config.parameters || {};
    this.metrics = {
      totalTasks: 0,
      routedTasks: 0,
      failedTasks: 0,
      averageRoutingTime: 0,
      lastUpdated: Date.now()
    };
  }
  
  /**
   * Initialize the router
   * @param llmConfig Configuration for the LLM if using LLM-assisted routing
   */
  async initialize(llmConfig?: LLMConfig): Promise<void> {
    if (this.strategy === 'llm-assisted' && llmConfig) {
      await this.initializeLLM(llmConfig);
    }
  }
  
  /**
   * Initialize the LLM for assisted routing
   * @param config LLM configuration
   */
  private async initializeLLM(config: LLMConfig): Promise<void> {
    // Implementation would initialize the appropriate LLM provider
    // This is a placeholder
  }
  
  /**
   * Route a task to the most appropriate agent
   * @param task The task to route
   * @param agents The available agents
   */
  async routeTask(task: Task, agents: BaseAgent[]): Promise<BaseAgent | null> {
    if (agents.length === 0) {
      return null;
    }
    
    const startTime = Date.now();
    this.metrics.totalTasks++;
    
    try {
      let selectedAgent: BaseAgent | null = null;
      
      switch (this.strategy) {
        case 'round-robin':
          selectedAgent = this.roundRobinRoute(task, agents);
          break;
        case 'load-balanced':
          selectedAgent = await this.loadBalancedRoute(task, agents);
          break;
        case 'skill-based':
          selectedAgent = await this.skillBasedRoute(task, agents);
          break;
        case 'llm-assisted':
          selectedAgent = await this.llmAssistedRoute(task, agents);
          break;
        default:
          throw new Error(`Unknown routing strategy: ${this.strategy}`);
      }
      
      if (selectedAgent) {
        this.metrics.routedTasks++;
      } else {
        this.metrics.failedTasks++;
      }
      
      const endTime = Date.now();
      const routingTime = endTime - startTime;
      
      // Update metrics
      this.metrics.averageRoutingTime = 
        (this.metrics.averageRoutingTime * (this.metrics.routedTasks - 1) + routingTime) / 
        this.metrics.routedTasks;
      this.metrics.lastUpdated = endTime;
      
      return selectedAgent;
    } catch (error) {
      this.metrics.failedTasks++;
      this.emit('routingError', { task, error });
      return null;
    }
  }
  
  /**
   * Route a task using round-robin strategy
   * @param task The task to route
   * @param agents The available agents
   */
  private roundRobinRoute(task: Task, agents: BaseAgent[]): BaseAgent {
    // Simple round-robin through randomization
    const activeAgents = agents.filter(agent => agent.isActive());
    if (activeAgents.length === 0) {
      throw new Error('No active agents available for routing');
    }
    
    return activeAgents[Math.floor(Math.random() * activeAgents.length)];
  }
  
  /**
   * Route a task using load-balanced strategy
   * @param task The task to route
   * @param agents The available agents
   */
  private async loadBalancedRoute(task: Task, agents: BaseAgent[]): Promise<BaseAgent> {
    // Choose the agent with the lowest load
    // For now, just consider if the agent is active
    const activeAgents = agents.filter(agent => agent.isActive());
    if (activeAgents.length === 0) {
      throw new Error('No active agents available for routing');
    }
    
    // In a real implementation, we would track agent load metrics
    // and choose the agent with the lowest load
    return activeAgents[0];
  }
  
  /**
   * Route a task using skill-based strategy
   * @param task The task to route
   * @param agents The available agents
   */
  private async skillBasedRoute(task: Task, agents: BaseAgent[]): Promise<BaseAgent> {
    // Choose the agent with the most relevant skills for the task
    const activeAgents = agents.filter(agent => agent.isActive());
    if (activeAgents.length === 0) {
      throw new Error('No active agents available for routing');
    }
    
    // In a real implementation, we would match task requirements
    // with agent skills and choose the best match
    return activeAgents[0];
  }
  
  /**
   * Route a task using LLM-assisted strategy
   * @param task The task to route
   * @param agents The available agents
   */
  private async llmAssistedRoute(task: Task, agents: BaseAgent[]): Promise<BaseAgent> {
    // Use LLM to choose the best agent based on task description and agent capabilities
    const activeAgents = agents.filter(agent => agent.isActive());
    if (activeAgents.length === 0) {
      throw new Error('No active agents available for routing');
    }
    
    if (!this.llmProvider) {
      // Fall back to round-robin if LLM is not available
      return this.roundRobinRoute(task, activeAgents);
    }
    
    // In a real implementation, we would use the LLM to analyze the task
    // and agent capabilities to choose the best match
    // This is a placeholder
    return activeAgents[0];
  }
  
  /**
   * Get the current metrics for the router
   */
  getMetrics(): RouterMetrics {
    return { ...this.metrics };
  }
  
  /**
   * Get the name of the router
   */
  getName(): string {
    return this.name;
  }
  
  /**
   * Get the routing strategy
   */
  getStrategy(): RouterConfig['strategy'] {
    return this.strategy;
  }
} 