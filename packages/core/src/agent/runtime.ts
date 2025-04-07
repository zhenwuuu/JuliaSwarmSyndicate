import { EventEmitter } from 'events';

export interface AgentConfig {
  id: string;
  name: string;
  model: string;
  platforms: string[];
  actions: string[];
  parameters: Record<string, any>;
}

export interface ActionContext {
  agent: Agent;
  parameters: Record<string, any>;
}

export type ActionFunction = (context: ActionContext) => Promise<any>;

export class Agent extends EventEmitter {
  private config: AgentConfig;
  private actions: Map<string, ActionFunction>;
  private state: Record<string, any>;

  constructor(config: AgentConfig) {
    super();
    this.config = config;
    this.actions = new Map();
    this.state = {};
  }

  registerAction(name: string, action: ActionFunction) {
    this.actions.set(name, action);
  }

  async executeAction(name: string, parameters: Record<string, any> = {}) {
    const action = this.actions.get(name);
    if (!action) {
      throw new Error(`Action ${name} not found`);
    }

    const context: ActionContext = {
      agent: this,
      parameters
    };

    try {
      const result = await action(context);
      this.emit('actionComplete', { name, result });
      return result;
    } catch (error) {
      this.emit('actionError', { name, error });
      throw error;
    }
  }

  setState(key: string, value: any) {
    this.state[key] = value;
    this.emit('stateChange', { key, value });
  }

  getState(key: string) {
    return this.state[key];
  }

  get id(): string {
    return this.config.id;
  }

  get name(): string {
    return this.config.name;
  }
}

export class AgentRuntime {
  private agents: Map<string, Agent>;

  constructor() {
    this.agents = new Map();
  }

  createAgent(config: AgentConfig): Agent {
    const agent = new Agent(config);
    this.agents.set(agent.id, agent);
    return agent;
  }

  getAgent(id: string): Agent | undefined {
    return this.agents.get(id);
  }

  removeAgent(id: string) {
    this.agents.delete(id);
  }

  get activeAgents(): Agent[] {
    return Array.from(this.agents.values());
  }
} 