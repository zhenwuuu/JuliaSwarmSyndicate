import { AgentProfile, CollaborationRequest, CollaborationResponse, AgentFeedback } from './types';
import { EventEmitter } from 'events';

export class CollaborationNetwork extends EventEmitter {
  private agents: Map<string, AgentProfile>;
  private collaborations: Map<string, CollaborationRequest>;
  private feedback: Map<string, AgentFeedback[]>;

  constructor() {
    super();
    this.agents = new Map();
    this.collaborations = new Map();
    this.feedback = new Map();
  }

  registerAgent(agent: AgentProfile): void {
    this.agents.set(agent.id, agent);
    this.feedback.set(agent.id, []);
    this.emit('agentRegistered', agent);
  }

  unregisterAgent(agentId: string): void {
    this.agents.delete(agentId);
    this.feedback.delete(agentId);
    this.emit('agentUnregistered', agentId);
  }

  async requestCollaboration(request: CollaborationRequest): Promise<CollaborationResponse> {
    const toAgent = this.agents.get(request.toAgentId);
    if (!toAgent) {
      return {
        requestId: request.taskId,
        accepted: false,
        reason: 'Target agent not found'
      };
    }

    // Check if agent has required capabilities
    const hasCapabilities = request.requiredCapabilities.every(cap => 
      toAgent.capabilities.includes(cap)
    );

    if (!hasCapabilities) {
      return {
        requestId: request.taskId,
        accepted: false,
        reason: 'Agent lacks required capabilities'
      };
    }

    this.collaborations.set(request.taskId, request);
    this.emit('collaborationRequested', request);

    // Simulate agent decision-making
    const response: CollaborationResponse = {
      requestId: request.taskId,
      accepted: true,
      estimatedCompletionTime: new Date(Date.now() + 3600000) // 1 hour from now
    };

    if (response.accepted) {
      this.emit('collaborationAccepted', {
        request,
        response
      });
    }

    return response;
  }

  async submitFeedback(feedback: AgentFeedback): Promise<void> {
    const agentFeedback = this.feedback.get(feedback.toAgentId) || [];
    agentFeedback.push(feedback);
    this.feedback.set(feedback.toAgentId, agentFeedback);
    this.emit('feedbackSubmitted', feedback);
  }

  getAgentFeedback(agentId: string): AgentFeedback[] {
    return this.feedback.get(agentId) || [];
  }

  findCapableAgents(capabilities: string[]): AgentProfile[] {
    return Array.from(this.agents.values()).filter(agent =>
      capabilities.every(cap => agent.capabilities.includes(cap))
    );
  }

  getActiveCollaborations(agentId: string): CollaborationRequest[] {
    return Array.from(this.collaborations.values()).filter(collab =>
      collab.fromAgentId === agentId || collab.toAgentId === agentId
    );
  }

  async endCollaboration(taskId: string, success: boolean): Promise<void> {
    const collaboration = this.collaborations.get(taskId);
    if (collaboration) {
      this.collaborations.delete(taskId);
      this.emit('collaborationEnded', {
        taskId,
        success,
        collaboration
      });
    }
  }
} 