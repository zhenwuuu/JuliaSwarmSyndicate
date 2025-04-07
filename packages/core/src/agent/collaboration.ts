import { Agent, ActionContext } from './runtime';
import { EventEmitter } from 'events';

export interface CollaborationConfig {
  id: string;
  name: string;
  agents: Agent[];
  roles: { [agentId: string]: string[] };
}

export interface Task {
  id: string;
  type: string;
  data: any;
  requiredRoles: string[];
  assignedAgents?: Agent[];
  status: 'pending' | 'in_progress' | 'completed' | 'failed';
  result?: any;
}

export class AgentCollaboration extends EventEmitter {
  private config: CollaborationConfig;
  private tasks: Map<string, Task>;
  private roleAssignments: Map<string, Set<Agent>>;

  constructor(config: CollaborationConfig) {
    super();
    this.config = config;
    this.tasks = new Map();
    this.roleAssignments = new Map();

    // Initialize role assignments
    this.initializeRoles();
  }

  private initializeRoles() {
    // Create role assignments based on config
    Object.entries(this.config.roles).forEach(([agentId, roles]) => {
      const agent = this.config.agents.find(a => a.id === agentId);
      if (agent) {
        roles.forEach(role => {
          if (!this.roleAssignments.has(role)) {
            this.roleAssignments.set(role, new Set());
          }
          this.roleAssignments.get(role)?.add(agent);
        });
      }
    });
  }

  async createTask(task: Omit<Task, 'id' | 'status' | 'assignedAgents'>): Promise<string> {
    const taskId = `task-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    const newTask: Task = {
      ...task,
      id: taskId,
      status: 'pending',
      assignedAgents: []
    };

    // Find suitable agents for the task
    const assignedAgents = this.findSuitableAgents(task.requiredRoles);
    if (assignedAgents.length < task.requiredRoles.length) {
      throw new Error('Not enough agents available for required roles');
    }

    newTask.assignedAgents = assignedAgents;
    this.tasks.set(taskId, newTask);
    this.emit('taskCreated', newTask);

    return taskId;
  }

  private findSuitableAgents(requiredRoles: string[]): Agent[] {
    const assignedAgents: Agent[] = [];
    const usedAgents = new Set<Agent>();

    for (const role of requiredRoles) {
      const availableAgents = this.roleAssignments.get(role) || new Set();
      const unusedAgent = Array.from(availableAgents).find(agent => !usedAgents.has(agent));

      if (unusedAgent) {
        assignedAgents.push(unusedAgent);
        usedAgents.add(unusedAgent);
      }
    }

    return assignedAgents;
  }

  async executeTask(taskId: string): Promise<any> {
    const task = this.tasks.get(taskId);
    if (!task) {
      throw new Error('Task not found');
    }

    task.status = 'in_progress';
    this.emit('taskStarted', task);

    try {
      // Execute task with all assigned agents
      const results = await Promise.all(
        task.assignedAgents!.map(async (agent, index) => {
          const context: ActionContext = {
            agent,
            parameters: {
              task: task.data,
              role: task.requiredRoles[index],
              collaboration: {
                id: this.config.id,
                taskId: task.id
              }
            }
          };

          return agent.executeAction('collaborate', context);
        })
      );

      // Combine results
      task.result = this.combineResults(results);
      task.status = 'completed';
      this.emit('taskCompleted', task);

      return task.result;
    } catch (error) {
      task.status = 'failed';
      this.emit('taskFailed', { task, error });
      throw error;
    }
  }

  private combineResults(results: any[]): any {
    // Default implementation - override as needed
    return results.reduce((combined, result) => {
      return {
        ...combined,
        ...result
      };
    }, {});
  }

  getTaskStatus(taskId: string): Task['status'] {
    const task = this.tasks.get(taskId);
    if (!task) {
      throw new Error('Task not found');
    }
    return task.status;
  }

  getActiveTasks(): Task[] {
    return Array.from(this.tasks.values()).filter(
      task => task.status === 'pending' || task.status === 'in_progress'
    );
  }

  getAgentsByRole(role: string): Agent[] {
    return Array.from(this.roleAssignments.get(role) || []);
  }
} 