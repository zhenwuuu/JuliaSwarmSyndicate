import { EventEmitter } from 'events';

/**
 * Configuration interface for skills
 * 
 * @interface SkillConfig
 */
export interface SkillConfig {
  /** Unique name of the skill */
  name: string;
  
  /** Type of skill (e.g., 'utility', 'data-processing', 'trading', etc.) */
  type: string;
  
  /** Optional parameters to configure the skill's behavior */
  parameters?: Record<string, any>;
}

/**
 * Abstract base class for all skills
 * 
 * Skills are reusable capabilities that can be attached to agents.
 * They provide modular functionality that agents can use without
 * having to implement that functionality themselves.
 * 
 * Skill lifecycle:
 * 1. Initialization (initialize): Set up resources and connections
 * 2. Execution (execute): Perform the skill's core functionality
 * 3. Stopping (stop): Clean up resources and connections
 * 
 * Skills emit events during their lifecycle:
 * - 'initialized': When initialization is complete
 * - 'started': When execution starts
 * - 'stopped': When execution stops
 * - 'error': When an error occurs
 * 
 * Skills can define their own custom events.
 * 
 * @abstract
 * @class Skill
 * @extends {EventEmitter}
 */
export abstract class Skill extends EventEmitter {
  /** Parameters for configuring the skill's behavior */
  protected parameters: Record<string, any>;
  
  /** Unique name of the skill */
  protected name: string;
  
  /** Type of skill */
  protected type: string;
  
  /** Whether the skill has completed initialization */
  protected isInitialized: boolean;
  
  /** Whether the skill is currently running */
  protected isRunning: boolean;
  
  /** Timestamp when the skill was last executed */
  protected lastExecutionTime: number = 0;
  
  /** Error information from the last execution, if any */
  protected lastError: Error | null = null;

  /**
   * Creates an instance of Skill.
   * 
   * @param {Record<string, any>} parameters - Parameters for the skill
   * @param {string} [name=''] - Unique name of the skill
   * @param {string} [type=''] - Type of skill
   */
  constructor(parameters: Record<string, any> = {}, name: string = '', type: string = '') {
    super();
    this.parameters = parameters;
    this.name = name;
    this.type = type;
    this.isInitialized = false;
    this.isRunning = false;
  }

  /**
   * Initialize the skill
   * This should set up any resources or connections needed by the skill
   * 
   * @abstract
   * @returns {Promise<void>}
   */
  abstract initialize(): Promise<void>;
  
  /**
   * Execute the skill's core functionality
   * 
   * @abstract
   * @returns {Promise<void>}
   */
  abstract execute(): Promise<void>;
  
  /**
   * Stop the skill and clean up resources
   * 
   * @abstract
   * @returns {Promise<void>}
   */
  abstract stop(): Promise<void>;

  /**
   * Get the name of the skill
   * 
   * @returns {string} The skill's name
   */
  getName(): string {
    return this.name;
  }

  /**
   * Get the type of the skill
   * 
   * @returns {string} The skill's type
   */
  getType(): string {
    return this.type;
  }

  /**
   * Get the parameters used to configure the skill
   * 
   * @returns {Record<string, any>} The skill's parameters
   */
  getParameters(): Record<string, any> {
    return { ...this.parameters };
  }

  /**
   * Check if the skill is currently running
   * 
   * @returns {boolean} True if the skill is running, false otherwise
   */
  isActive(): boolean {
    return this.isRunning;
  }

  /**
   * Check if the skill has been initialized
   * 
   * @returns {boolean} True if the skill is initialized, false otherwise
   */
  isReady(): boolean {
    return this.isInitialized;
  }
  
  /**
   * Get the timestamp of the last execution
   * 
   * @returns {number} Timestamp in milliseconds
   */
  getLastExecutionTime(): number {
    return this.lastExecutionTime;
  }
  
  /**
   * Get the last error that occurred during execution, if any
   * 
   * @returns {Error | null} The last error or null if no error occurred
   */
  getLastError(): Error | null {
    return this.lastError;
  }
  
  /**
   * Update a parameter value
   * 
   * @param {string} key - The parameter key
   * @param {any} value - The new parameter value
   */
  updateParameter(key: string, value: any): void {
    this.parameters[key] = value;
  }

  /**
   * Set the initialization state of the skill
   * 
   * @protected
   * @param {boolean} initialized - Whether the skill is initialized
   */
  protected setInitialized(initialized: boolean): void {
    this.isInitialized = initialized;
    if (initialized) {
      this.emit('initialized');
    }
  }

  /**
   * Set the running state of the skill
   * 
   * @protected
   * @param {boolean} running - Whether the skill is running
   */
  protected setRunning(running: boolean): void {
    this.isRunning = running;
    if (running) {
      this.emit('started');
    } else {
      this.emit('stopped');
    }
  }
  
  /**
   * Handle an error that occurred during execution
   * 
   * @protected
   * @param {Error} error - The error that occurred
   */
  protected handleError(error: Error): void {
    this.lastError = error;
    this.emit('error', error);
  }
  
  /**
   * Update the last execution time
   * 
   * @protected
   */
  protected updateExecutionTime(): void {
    this.lastExecutionTime = Date.now();
  }
} 