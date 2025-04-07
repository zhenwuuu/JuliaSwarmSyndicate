import { EventEmitter } from 'events';

export interface PlatformConfig {
  name: string;
  type: string;
  parameters?: Record<string, any>;
}

export interface MessageData {
  content: string;
  sender: string;
  channelId?: string;
  chatId?: string;
  timestamp: Date;
}

export abstract class Platform extends EventEmitter {
  protected name: string;
  protected type: string;
  protected parameters: Record<string, any>;
  protected isConnected: boolean;

  constructor(config: PlatformConfig) {
    super();
    this.name = config.name;
    this.type = config.type;
    this.parameters = config.parameters || {};
    this.isConnected = false;
  }

  abstract connect(): Promise<void>;
  abstract disconnect(): Promise<void>;
  abstract start(): Promise<void>;
  abstract stop(): Promise<void>;
  abstract sendMessage(message: string, target: string): Promise<void>;

  getName(): string {
    return this.name;
  }

  getType(): string {
    return this.type;
  }

  getParameters(): Record<string, any> {
    return this.parameters;
  }

  isActive(): boolean {
    return this.isConnected;
  }

  protected setConnected(connected: boolean): void {
    this.isConnected = connected;
    if (connected) {
      this.emit('connected');
    } else {
      this.emit('disconnected');
    }
  }
} 