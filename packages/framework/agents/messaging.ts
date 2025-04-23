/**
 * JuliaOS Framework - Agent Messaging Module
 * 
 * This module provides interfaces for agent communication and collaboration.
 */

import { JuliaBridge } from '@juliaos/julia-bridge';
import { EventEmitter } from 'events';

/**
 * Agent messaging events
 */
export enum AgentMessagingEvent {
  MESSAGE_SENT = 'agent:messaging:message:sent',
  MESSAGE_RECEIVED = 'agent:messaging:message:received',
  MESSAGE_READ = 'agent:messaging:message:read',
  CHANNEL_CREATED = 'agent:messaging:channel:created',
  CHANNEL_JOINED = 'agent:messaging:channel:joined',
  CHANNEL_LEFT = 'agent:messaging:channel:left',
  CHANNEL_MESSAGE = 'agent:messaging:channel:message',
  ERROR = 'agent:messaging:error'
}

/**
 * Message content
 */
export interface MessageContent {
  type: string;
  text?: string;
  data?: Record<string, any>;
  [key: string]: any;
}

/**
 * Message
 */
export interface Message {
  id: string;
  sender_id: string;
  recipient_id: string;
  content: MessageContent;
  timestamp: string;
  read: boolean;
}

/**
 * Channel message
 */
export interface ChannelMessage {
  id: string;
  sender_id: string;
  channel_id: string;
  content: MessageContent;
  timestamp: string;
}

/**
 * Channel
 */
export interface Channel {
  id: string;
  name: string;
  description: string;
  creator_id: string;
  members: string[];
  created_at: string;
  messages: ChannelMessage[];
}

/**
 * AgentMessaging class for agent communication
 */
export class AgentMessaging extends EventEmitter {
  private bridge: JuliaBridge;
  private agentId: string;

  /**
   * Create a new AgentMessaging
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
   * Send a message to another agent
   * 
   * @param recipientId - Recipient agent ID
   * @param content - Message content
   * @returns Promise with message sending result
   */
  async sendMessage(recipientId: string, content: MessageContent): Promise<Record<string, any>> {
    try {
      const result = await this.bridge.execute('AgentMessaging.send_message', [
        this.agentId,
        recipientId,
        content
      ]);

      if (result.success) {
        this.emit(AgentMessagingEvent.MESSAGE_SENT, {
          agentId: this.agentId,
          recipientId,
          messageId: result.message_id,
          content
        });
      }

      return result;
    } catch (error) {
      this.emit(AgentMessagingEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Get messages for the agent
   * 
   * @param options - Options for getting messages
   * @returns Promise with messages
   */
  async getMessages(options: {
    unreadOnly?: boolean;
    limit?: number;
    offset?: number;
  } = {}): Promise<Record<string, any>> {
    try {
      const result = await this.bridge.execute('AgentMessaging.get_messages', [
        this.agentId,
        options.unreadOnly || false,
        options.limit || 50,
        options.offset || 0
      ]);

      if (result.success && result.messages.length > 0) {
        this.emit(AgentMessagingEvent.MESSAGE_RECEIVED, {
          agentId: this.agentId,
          messages: result.messages
        });
      }

      return result;
    } catch (error) {
      this.emit(AgentMessagingEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Mark a message as read
   * 
   * @param messageId - Message ID
   * @returns Promise with mark as read result
   */
  async markAsRead(messageId: string): Promise<Record<string, any>> {
    try {
      const result = await this.bridge.execute('AgentMessaging.mark_as_read', [
        this.agentId,
        messageId
      ]);

      if (result.success) {
        this.emit(AgentMessagingEvent.MESSAGE_READ, {
          agentId: this.agentId,
          messageId
        });
      }

      return result;
    } catch (error) {
      this.emit(AgentMessagingEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Create a communication channel
   * 
   * @param name - Channel name
   * @param description - Channel description
   * @returns Promise with channel creation result
   */
  async createChannel(name: string, description: string): Promise<Record<string, any>> {
    try {
      const result = await this.bridge.execute('AgentMessaging.create_channel', [
        this.agentId,
        name,
        description
      ]);

      if (result.success) {
        this.emit(AgentMessagingEvent.CHANNEL_CREATED, {
          agentId: this.agentId,
          channelId: result.channel_id,
          channel: result.channel
        });
      }

      return result;
    } catch (error) {
      this.emit(AgentMessagingEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Join a communication channel
   * 
   * @param channelId - Channel ID
   * @returns Promise with channel joining result
   */
  async joinChannel(channelId: string): Promise<Record<string, any>> {
    try {
      const result = await this.bridge.execute('AgentMessaging.join_channel', [
        this.agentId,
        channelId
      ]);

      if (result.success) {
        this.emit(AgentMessagingEvent.CHANNEL_JOINED, {
          agentId: this.agentId,
          channelId,
          channel: result.channel
        });
      }

      return result;
    } catch (error) {
      this.emit(AgentMessagingEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Leave a communication channel
   * 
   * @param channelId - Channel ID
   * @returns Promise with channel leaving result
   */
  async leaveChannel(channelId: string): Promise<Record<string, any>> {
    try {
      const result = await this.bridge.execute('AgentMessaging.leave_channel', [
        this.agentId,
        channelId
      ]);

      if (result.success) {
        this.emit(AgentMessagingEvent.CHANNEL_LEFT, {
          agentId: this.agentId,
          channelId
        });
      }

      return result;
    } catch (error) {
      this.emit(AgentMessagingEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Get messages from a channel
   * 
   * @param channelId - Channel ID
   * @param options - Options for getting messages
   * @returns Promise with channel messages
   */
  async getChannelMessages(
    channelId: string,
    options: {
      limit?: number;
      offset?: number;
    } = {}
  ): Promise<Record<string, any>> {
    try {
      return await this.bridge.execute('AgentMessaging.get_channel_messages', [
        this.agentId,
        channelId,
        options.limit || 50,
        options.offset || 0
      ]);
    } catch (error) {
      this.emit(AgentMessagingEvent.ERROR, error);
      throw error;
    }
  }

  /**
   * Broadcast a message to a channel
   * 
   * @param channelId - Channel ID
   * @param content - Message content
   * @returns Promise with message broadcasting result
   */
  async broadcastToChannel(channelId: string, content: MessageContent): Promise<Record<string, any>> {
    try {
      const result = await this.bridge.execute('AgentMessaging.broadcast_to_channel', [
        this.agentId,
        channelId,
        content
      ]);

      if (result.success) {
        this.emit(AgentMessagingEvent.CHANNEL_MESSAGE, {
          agentId: this.agentId,
          channelId,
          messageId: result.message_id,
          content
        });
      }

      return result;
    } catch (error) {
      this.emit(AgentMessagingEvent.ERROR, error);
      throw error;
    }
  }
}
