import { Skill, SkillConfig } from './Skill';

export interface EchoSkillConfig extends SkillConfig {
  prefix?: string;
}

export class EchoSkill extends Skill {
  private prefix: string;
  private input: string = '';

  constructor(config: EchoSkillConfig) {
    super(config.parameters || {}, config.name, config.type);
    this.prefix = config.prefix || 'Echo: ';
  }

  async initialize(): Promise<void> {
    // No initialization needed for echo skill
    this.setInitialized(true);
  }

  /**
   * Sets the input to be echoed
   * @param input The text to echo
   */
  setInput(input: string): void {
    this.input = input;
  }
  
  /**
   * Get the last echoed result
   * @returns The last echo result
   */
  getLastResult(): string {
    return `${this.prefix}${this.input || 'No input provided'}`;
  }

  /**
   * Execute the echo skill
   * Call setInput() before calling this method to set what will be echoed
   */
  async execute(): Promise<void> {
    if (!this.isInitialized) {
      throw new Error('Echo skill is not initialized');
    }
    
    this.setRunning(true);
    const result = this.getLastResult();
    
    // Emit a completed event with the result
    this.emit('executionComplete', {
      result,
      timestamp: Date.now()
    });
    
    this.setRunning(false);
  }

  async stop(): Promise<void> {
    this.setRunning(false);
  }
} 