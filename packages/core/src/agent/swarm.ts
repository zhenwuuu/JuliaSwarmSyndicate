import { Agent, AgentConfig, ActionContext } from './runtime';
import { EventEmitter } from 'events';

export interface SwarmConfig {
  id: string;
  name: string;
  maxAgents: number;
  minAgents: number;
  scalingRules: ScalingRule[];
}

export interface ScalingRule {
  metric: string;
  threshold: number;
  action: 'scale_up' | 'scale_down';
  amount: number;
}

export interface SwarmMetrics {
  activeAgents: number;
  totalTasks: number;
  completedTasks: number;
  failedTasks: number;
  averageResponseTime: number;
}

export class SwarmAgent extends EventEmitter {
  private config: SwarmConfig;
  private agents: Map<string, Agent>;
  private metrics: SwarmMetrics;
  private taskQueue: Task[];
  private isProcessing: boolean;

  constructor(config: SwarmConfig) {
    super();
    this.config = config;
    this.agents = new Map();
    this.taskQueue = [];
    this.isProcessing = false;
    this.metrics = {
      activeAgents: 0,
      totalTasks: 0,
      completedTasks: 0,
      failedTasks: 0,
      averageResponseTime: 0
    };

    // Start monitoring metrics
    this.startMetricsMonitoring();
  }

  private startMetricsMonitoring() {
    setInterval(() => {
      this.evaluateScaling();
    }, 30000); // Check every 30 seconds
  }

  private async evaluateScaling() {
    for (const rule of this.config.scalingRules) {
      const metricValue = this.metrics[rule.metric as keyof SwarmMetrics];
      
      if (rule.action === 'scale_up' && metricValue > rule.threshold) {
        await this.scaleUp(rule.amount);
      } else if (rule.action === 'scale_down' && metricValue < rule.threshold) {
        await this.scaleDown(rule.amount);
      }
    }
  }

  async addAgent(agentConfig: AgentConfig): Promise<Agent> {
    const agent = new Agent(agentConfig);
    this.agents.set(agent.id, agent);
    this.metrics.activeAgents = this.agents.size;

    // Monitor agent events
    agent.on('actionComplete', ({ name, result }) => {
      this.metrics.completedTasks++;
      this.emit('agentActionComplete', { agentId: agent.id, name, result });
    });

    agent.on('actionError', ({ name, error }) => {
      this.metrics.failedTasks++;
      this.emit('agentActionError', { agentId: agent.id, name, error });
    });

    return agent;
  }

  async removeAgent(agentId: string) {
    const agent = this.agents.get(agentId);
    if (agent) {
      // Clean up agent resources
      agent.removeAllListeners();
      this.agents.delete(agentId);
      this.metrics.activeAgents = this.agents.size;
      this.emit('agentRemoved', { agentId });
    }
  }

  private async scaleUp(amount: number) {
    if (this.agents.size >= this.config.maxAgents) {
      return;
    }

    const toAdd = Math.min(amount, this.config.maxAgents - this.agents.size);
    for (let i = 0; i < toAdd; i++) {
      const agentConfig: AgentConfig = {
        id: `${this.config.id}-worker-${Date.now()}-${i}`,
        name: `${this.config.name} Worker ${this.agents.size + 1}`,
        model: 'gpt-4', // Default model, can be configured
        platforms: [],
        actions: [],
        parameters: {}
      };
      await this.addAgent(agentConfig);
    }
  }

  private async scaleDown(amount: number) {
    if (this.agents.size <= this.config.minAgents) {
      return;
    }

    const toRemove = Math.min(amount, this.agents.size - this.config.minAgents);
    const agentIds = Array.from(this.agents.keys()).slice(-toRemove);
    
    for (const agentId of agentIds) {
      await this.removeAgent(agentId);
    }
  }

  async executeTask(task: Task): Promise<any> {
    this.metrics.totalTasks++;
    const startTime = Date.now();

    try {
      // Find least busy agent
      const availableAgents = Array.from(this.agents.values())
        .filter(agent => agent.getState('busy') !== true)
        .sort((a, b) => 
          (a.getState('taskCount') || 0) - (b.getState('taskCount') || 0)
        );

      if (availableAgents.length === 0) {
        // Queue task if no agents available
        return new Promise((resolve, reject) => {
          this.taskQueue.push({ ...task, resolve, reject });
        });
      }

      const agent = availableAgents[0];
      agent.setState('busy', true);
      agent.setState('taskCount', (agent.getState('taskCount') || 0) + 1);

      const result = await agent.executeAction(task.action, task.parameters);
      
      agent.setState('busy', false);
      
      // Update metrics
      const duration = Date.now() - startTime;
      this.metrics.averageResponseTime = 
        (this.metrics.averageResponseTime * (this.metrics.completedTasks - 1) + duration) 
        / this.metrics.completedTasks;

      return result;
    } catch (error) {
      this.metrics.failedTasks++;
      throw error;
    }
  }

  private async processTaskQueue() {
    if (this.isProcessing || this.taskQueue.length === 0) {
      return;
    }

    this.isProcessing = true;
    
    while (this.taskQueue.length > 0) {
      const task = this.taskQueue[0];
      
      try {
        const result = await this.executeTask({
          action: task.action,
          parameters: task.parameters
        });
        if (task.resolve) {
          task.resolve(result);
        }
      } catch (error) {
        if (task.reject) {
          task.reject(error);
        }
      }

      this.taskQueue.shift();
    }

    this.isProcessing = false;
  }

  getMetrics(): SwarmMetrics {
    return { ...this.metrics };
  }

  get activeAgentCount(): number {
    return this.agents.size;
  }
}

interface Task {
  action: string;
  parameters: Record<string, any>;
  resolve?: (value: any) => void;
  reject?: (error: any) => void;
} 