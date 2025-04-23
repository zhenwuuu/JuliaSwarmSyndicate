/**
 * Implementation Registry for EnhancedJuliaBridge
 * 
 * Manages real implementations for Julia commands
 */

const { JuliaBridgeError } = require('../errors/bridge-errors');

class ImplementationRegistry {
  constructor(logger, juliaBridge) {
    this.implementations = new Map();
    this.logger = logger;
    this.juliaBridge = juliaBridge;
  }

  /**
   * Register an implementation for a command
   * @param {string} command - Command name
   * @param {Function} implementation - Implementation function
   */
  register(command, implementation) {
    if (typeof implementation !== 'function') {
      throw new Error(`Implementation for ${command} must be a function`);
    }
    
    this.implementations.set(command, implementation);
    this.logger.debug(`Registered implementation for ${command}`);
  }

  /**
   * Register multiple implementations
   * @param {Object} implementations - Map of command names to implementation functions
   */
  registerBulk(implementations) {
    Object.entries(implementations).forEach(([command, implementation]) => {
      this.register(command, implementation);
    });
  }

  /**
   * Check if an implementation exists for a command
   * @param {string} command - Command name
   * @returns {boolean} - True if an implementation exists
   */
  has(command) {
    return this.implementations.has(command);
  }

  /**
   * Execute an implementation for a command
   * @param {string} command - Command name
   * @param {Object} params - Command parameters
   * @returns {Promise<*>} - Implementation result
   */
  async execute(command, params = {}) {
    const implementation = this.implementations.get(command);
    
    if (!implementation) {
      this.logger.warn(`No implementation found for ${command}`);
      throw new JuliaBridgeError(`No implementation found for ${command}`);
    }
    
    try {
      this.logger.debug(`Executing implementation for ${command}`, params);
      return await implementation(params, this.juliaBridge);
    } catch (error) {
      this.logger.error(`Error executing implementation for ${command}:`, error);
      throw error;
    }
  }
}

module.exports = ImplementationRegistry;
