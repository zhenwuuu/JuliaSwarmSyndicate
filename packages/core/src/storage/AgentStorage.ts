import { EventEmitter } from 'events';
import { z } from 'zod';
import * as fs from 'fs';
import * as path from 'path';

export interface AgentState {
  id: string;
  type: string;
  status: 'active' | 'inactive' | 'error';
  lastUpdate: number;
  data: Record<string, any>;
  metadata: {
    version: string;
    createdAt: number;
    updatedAt: number;
  };
}

const AgentStateSchema = z.object({
  id: z.string(),
  type: z.string(),
  status: z.enum(['active', 'inactive', 'error']),
  lastUpdate: z.number(),
  data: z.record(z.any()),
  metadata: z.object({
    version: z.string(),
    createdAt: z.number(),
    updatedAt: z.number()
  })
});

export interface StorageConfig {
  baseDir: string;
  backupInterval?: number;
  maxBackups?: number;
  compression?: boolean;
}

export class AgentStorage extends EventEmitter {
  private config: StorageConfig;
  private states: Map<string, AgentState> = new Map();
  private backupTimer: NodeJS.Timeout | null = null;
  private isInitialized: boolean = false;

  constructor(config: StorageConfig) {
    super();
    this.config = {
      backupInterval: 3600000, // 1 hour
      maxBackups: 5,
      compression: true,
      ...config
    };
  }

  async initialize(): Promise<void> {
    if (this.isInitialized) return;

    try {
      // Create base directory if it doesn't exist
      if (!fs.existsSync(this.config.baseDir)) {
        fs.mkdirSync(this.config.baseDir, { recursive: true });
      }

      // Load existing states
      await this.loadStates();

      // Start backup timer
      this.startBackupTimer();

      this.isInitialized = true;
      this.emit('initialized');
    } catch (error) {
      console.error('Failed to initialize AgentStorage:', error);
      throw error;
    }
  }

  async saveState(state: AgentState): Promise<void> {
    if (!this.isInitialized) {
      throw new Error('AgentStorage not initialized');
    }

    try {
      // Validate state
      const validatedState = AgentStateSchema.parse(state);

      // Update metadata
      validatedState.metadata.updatedAt = Date.now();
      validatedState.lastUpdate = Date.now();

      // Save to memory
      this.states.set(state.id, validatedState);

      // Save to disk
      await this.saveStateToDisk(validatedState);

      this.emit('stateUpdated', validatedState);
    } catch (error) {
      console.error(`Failed to save state for agent ${state.id}:`, error);
      throw error;
    }
  }

  async getState(id: string): Promise<AgentState | null> {
    if (!this.isInitialized) {
      throw new Error('AgentStorage not initialized');
    }

    return this.states.get(id) || null;
  }

  async deleteState(id: string): Promise<void> {
    if (!this.isInitialized) {
      throw new Error('AgentStorage not initialized');
    }

    try {
      // Delete from memory
      this.states.delete(id);

      // Delete from disk
      const filePath = this.getStateFilePath(id);
      if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }

      this.emit('stateDeleted', id);
    } catch (error) {
      console.error(`Failed to delete state for agent ${id}:`, error);
      throw error;
    }
  }

  async updateState(id: string, updates: Partial<AgentState>): Promise<void> {
    if (!this.isInitialized) {
      throw new Error('AgentStorage not initialized');
    }

    try {
      const currentState = await this.getState(id);
      if (!currentState) {
        throw new Error(`State not found for agent ${id}`);
      }

      const updatedState = {
        ...currentState,
        ...updates,
        metadata: {
          ...currentState.metadata,
          updatedAt: Date.now()
        },
        lastUpdate: Date.now()
      };

      await this.saveState(updatedState);
    } catch (error) {
      console.error(`Failed to update state for agent ${id}:`, error);
      throw error;
    }
  }

  async backup(): Promise<void> {
    if (!this.isInitialized) {
      throw new Error('AgentStorage not initialized');
    }

    try {
      const backupDir = path.join(this.config.baseDir, 'backups');
      if (!fs.existsSync(backupDir)) {
        fs.mkdirSync(backupDir, { recursive: true });
      }

      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const backupPath = path.join(backupDir, `backup-${timestamp}.json`);

      // Create backup
      const backup = {
        timestamp: Date.now(),
        states: Array.from(this.states.values())
      };

      fs.writeFileSync(backupPath, JSON.stringify(backup, null, 2));

      // Clean up old backups
      await this.cleanupOldBackups();

      this.emit('backupCreated', backupPath);
    } catch (error) {
      console.error('Failed to create backup:', error);
      throw error;
    }
  }

  async restore(backupPath: string): Promise<void> {
    if (!this.isInitialized) {
      throw new Error('AgentStorage not initialized');
    }

    try {
      const backup = JSON.parse(fs.readFileSync(backupPath, 'utf-8'));
      
      // Validate backup
      if (!backup.timestamp || !Array.isArray(backup.states)) {
        throw new Error('Invalid backup format');
      }

      // Clear current states
      this.states.clear();

      // Restore states
      for (const state of backup.states) {
        const validatedState = AgentStateSchema.parse(state);
        this.states.set(state.id, validatedState);
        await this.saveStateToDisk(validatedState);
      }

      this.emit('restored', backupPath);
    } catch (error) {
      console.error('Failed to restore backup:', error);
      throw error;
    }
  }

  async stop(): Promise<void> {
    if (!this.isInitialized) return;

    try {
      // Stop backup timer
      if (this.backupTimer) {
        clearInterval(this.backupTimer);
        this.backupTimer = null;
      }

      // Create final backup
      await this.backup();

      this.isInitialized = false;
      this.emit('stopped');
    } catch (error) {
      console.error('Failed to stop AgentStorage:', error);
      throw error;
    }
  }

  private async loadStates(): Promise<void> {
    const files = fs.readdirSync(this.config.baseDir)
      .filter(file => file.endsWith('.json'));

    for (const file of files) {
      try {
        const filePath = path.join(this.config.baseDir, file);
        const state = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
        const validatedState = AgentStateSchema.parse(state);
        this.states.set(state.id, validatedState);
      } catch (error) {
        console.error(`Failed to load state from file ${file}:`, error);
      }
    }
  }

  private async saveStateToDisk(state: AgentState): Promise<void> {
    const filePath = this.getStateFilePath(state.id);
    fs.writeFileSync(filePath, JSON.stringify(state, null, 2));
  }

  private getStateFilePath(id: string): string {
    return path.join(this.config.baseDir, `${id}.json`);
  }

  private startBackupTimer(): void {
    if (this.backupTimer) {
      clearInterval(this.backupTimer);
    }

    this.backupTimer = setInterval(() => {
      this.backup().catch(error => {
        console.error('Failed to create scheduled backup:', error);
      });
    }, this.config.backupInterval);
  }

  private async cleanupOldBackups(): Promise<void> {
    const backupDir = path.join(this.config.baseDir, 'backups');
    const files = fs.readdirSync(backupDir)
      .filter(file => file.startsWith('backup-') && file.endsWith('.json'))
      .map(file => ({
        name: file,
        path: path.join(backupDir, file),
        time: fs.statSync(path.join(backupDir, file)).mtime.getTime()
      }))
      .sort((a, b) => b.time - a.time);

    // Remove old backups
    for (const file of files.slice(this.config.maxBackups!)) {
      fs.unlinkSync(file.path);
    }
  }
} 