/**
 * JuliaOS Framework - Agent Collaboration Module
 * 
 * This module provides interfaces for agent collaboration and teamwork.
 */

import { JuliaBridge } from '@juliaos/julia-bridge';
import { EventEmitter } from 'events';

/**
 * Agent collaboration events
 */
export enum AgentCollaborationEvent {
  TEAM_CREATED = 'agent:collaboration:team:created',
  TEAM_JOINED = 'agent:collaboration:team:joined',
  TEAM_LEFT = 'agent:collaboration:team:left',
  TASK_ASSIGNED = 'agent:collaboration:task:assigned',
  TASK_UPDATED = 'agent:collaboration:task:updated',
  DATA_SHARED = 'agent:collaboration:data:shared',
  ERROR = 'agent:collaboration:error'
}

/**
 * Task status
 */
export enum TaskStatus {
  PENDING = 1,
  IN_PROGRESS = 2,
  COMPLETED = 3,
  FAILED = 4
}

/**
 * Team
 */
export interface Team {
  id: string;
  name: string;
  description: string;
  creator_id: string;
  members: string[];
  created_at: string;
  tasks: Task[];
  shared_data: Record<string, SharedData>;
  channel_id?: string;
}

/**
 * Task
 */
export interface Task {
  id: string;
  team_id: string;
  title: string;
  description: string;
  assigner_id: string;
  assignee_id: string;
  status: TaskStatus;
  created_at: string;
  due_date: string;
  priority: number;
  updates: TaskUpdate[];
}

/**
 * Task update
 */
export interface TaskUpdate {
  status: TaskStatus;
  previous_status: TaskStatus;
  agent_id: string;
  comment: string;
  timestamp: string;
}

/**
 * Shared data
 */
export interface SharedData {
  data: any;
  agent_id: string;
  timestamp: string;
}

/**
 * AgentCollaboration class for agent teamwork
 */
export class AgentCollaboration extends EventEmitter {
  private bridge: JuliaBridge;
  private agentId: string;

  /**
   * Create a new AgentCollaboration
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
   * Create a team
   * 
   * @param name - Team name
   * @param description - Team description
   * @param agentIds - IDs of agents to add to the team
   * @returns Promise with team creation result
   */
  async createTeam(name: string, description: string, agentIds: string[]): Promise<Record<string, any>> {
    try {
      const result = await this.bridge.execute('AgentCollaboration.create_team', [
        this.agentId,
        name,
        description,
        agentIds
      ]);

      if (result.success) {
        this.emit(AgentCollaborationEvent.TEAM_CREATED, {
          agentId: this.agentId,
          teamId: result.team_id,
          team: result.team
        });
      }

      return result;
    } catch (error) {
      this.emit(AgentCollaborationEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Add an agent to a team
   * 
   * @param teamId - Team ID
   * @param agentId - Agent ID to add
   * @returns Promise with result of adding agent to team
   */
  async addAgentToTeam(teamId: string, agentId: string): Promise<Record<string, any>> {
    try {
      const result = await this.bridge.execute('AgentCollaboration.add_agent_to_team', [
        teamId,
        agentId
      ]);

      if (result.success) {
        this.emit(AgentCollaborationEvent.TEAM_JOINED, {
          agentId,
          teamId,
          team: result.team
        });
      }

      return result;
    } catch (error) {
      this.emit(AgentCollaborationEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Remove an agent from a team
   * 
   * @param teamId - Team ID
   * @param agentId - Agent ID to remove
   * @returns Promise with result of removing agent from team
   */
  async removeAgentFromTeam(teamId: string, agentId: string): Promise<Record<string, any>> {
    try {
      const result = await this.bridge.execute('AgentCollaboration.remove_agent_from_team', [
        teamId,
        agentId
      ]);

      if (result.success) {
        this.emit(AgentCollaborationEvent.TEAM_LEFT, {
          agentId,
          teamId
        });
      }

      return result;
    } catch (error) {
      this.emit(AgentCollaborationEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Get information about a team
   * 
   * @param teamId - Team ID
   * @returns Promise with team information
   */
  async getTeam(teamId: string): Promise<Record<string, any>> {
    try {
      return await this.bridge.execute('AgentCollaboration.get_team', [teamId]);
    } catch (error) {
      this.emit(AgentCollaborationEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Assign a task to an agent in a team
   * 
   * @param teamId - Team ID
   * @param assigneeId - Assignee agent ID
   * @param title - Task title
   * @param description - Task description
   * @param dueDate - Due date (ISO format)
   * @param priority - Task priority (1-5)
   * @returns Promise with task assignment result
   */
  async assignTask(
    teamId: string,
    assigneeId: string,
    title: string,
    description: string,
    dueDate: string,
    priority: number
  ): Promise<Record<string, any>> {
    try {
      const result = await this.bridge.execute('AgentCollaboration.assign_task', [
        teamId,
        this.agentId,
        assigneeId,
        title,
        description,
        dueDate,
        priority
      ]);

      if (result.success) {
        this.emit(AgentCollaborationEvent.TASK_ASSIGNED, {
          agentId: this.agentId,
          assigneeId,
          teamId,
          taskId: result.task_id,
          task: result.task
        });
      }

      return result;
    } catch (error) {
      this.emit(AgentCollaborationEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Get information about a task
   * 
   * @param teamId - Team ID
   * @param taskId - Task ID
   * @returns Promise with task information
   */
  async getTask(teamId: string, taskId: string): Promise<Record<string, any>> {
    try {
      return await this.bridge.execute('AgentCollaboration.get_task', [teamId, taskId]);
    } catch (error) {
      this.emit(AgentCollaborationEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Update the status of a task
   * 
   * @param teamId - Team ID
   * @param taskId - Task ID
   * @param status - New status
   * @param comment - Comment about the status update
   * @returns Promise with task status update result
   */
  async updateTaskStatus(
    teamId: string,
    taskId: string,
    status: TaskStatus,
    comment: string
  ): Promise<Record<string, any>> {
    try {
      const result = await this.bridge.execute('AgentCollaboration.update_task_status', [
        teamId,
        taskId,
        this.agentId,
        status,
        comment
      ]);

      if (result.success) {
        this.emit(AgentCollaborationEvent.TASK_UPDATED, {
          agentId: this.agentId,
          teamId,
          taskId,
          status,
          comment,
          task: result.task
        });
      }

      return result;
    } catch (error) {
      this.emit(AgentCollaborationEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Get tasks assigned to the agent
   * 
   * @param status - Filter by status (optional)
   * @returns Promise with agent tasks
   */
  async getAgentTasks(status?: TaskStatus): Promise<Record<string, any>> {
    try {
      return await this.bridge.execute('AgentCollaboration.get_agent_tasks', [
        this.agentId,
        status
      ]);
    } catch (error) {
      this.emit(AgentCollaborationEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Share data with a team
   * 
   * @param teamId - Team ID
   * @param key - Data key
   * @param data - Data to share
   * @returns Promise with data sharing result
   */
  async shareData(teamId: string, key: string, data: any): Promise<Record<string, any>> {
    try {
      const result = await this.bridge.execute('AgentCollaboration.share_data', [
        teamId,
        this.agentId,
        key,
        data
      ]);

      if (result.success) {
        this.emit(AgentCollaborationEvent.DATA_SHARED, {
          agentId: this.agentId,
          teamId,
          key,
          data
        });
      }

      return result;
    } catch (error) {
      this.emit(AgentCollaborationEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Get shared data from a team
   * 
   * @param teamId - Team ID
   * @param key - Data key
   * @returns Promise with shared data
   */
  async getSharedData(teamId: string, key: string): Promise<Record<string, any>> {
    try {
      return await this.bridge.execute('AgentCollaboration.get_shared_data', [
        teamId,
        this.agentId,
        key
      ]);
    } catch (error) {
      this.emit(AgentCollaborationEvent.ERROR, error);
      throw error;
    }
  }
}
