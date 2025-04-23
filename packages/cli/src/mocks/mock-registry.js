/**
 * Mock Registry for EnhancedJuliaBridge
 * 
 * Manages mock implementations for Julia commands
 */

const { MockImplementationError } = require('../errors/bridge-errors');

class MockRegistry {
  constructor(logger) {
    this.mocks = new Map();
    this.logger = logger;
    this.dynamicData = true;
  }

  /**
   * Register a mock implementation for a command
   * @param {string} command - Command name
   * @param {Function} implementation - Mock implementation function
   */
  register(command, implementation) {
    if (typeof implementation !== 'function') {
      throw new Error(`Mock implementation for ${command} must be a function`);
    }
    
    this.mocks.set(command, implementation);
    this.logger.debug(`Registered mock implementation for ${command}`);
  }

  /**
   * Register multiple mock implementations
   * @param {Object} implementations - Map of command names to implementation functions
   */
  registerBulk(implementations) {
    Object.entries(implementations).forEach(([command, implementation]) => {
      this.register(command, implementation);
    });
  }

  /**
   * Check if a mock implementation exists for a command
   * @param {string} command - Command name
   * @returns {boolean} - True if a mock implementation exists
   */
  has(command) {
    return this.mocks.has(command);
  }

  /**
   * Get a mock implementation for a command
   * @param {string} command - Command name
   * @param {Object} params - Command parameters
   * @returns {*} - Mock implementation result
   */
  execute(command, params = {}) {
    const implementation = this.mocks.get(command);
    
    if (!implementation) {
      this.logger.warn(`No mock implementation found for ${command}`);
      return {
        success: true,
        message: `Generic mock result for ${command}`,
        timestamp: new Date().toISOString()
      };
    }
    
    try {
      this.logger.debug(`Executing mock implementation for ${command}`, params);
      return implementation(params, this.dynamicData);
    } catch (error) {
      this.logger.error(`Error executing mock implementation for ${command}:`, error);
      throw new MockImplementationError(`Failed to execute mock for ${command}: ${error.message}`, command, params);
    }
  }

  /**
   * Set whether to use dynamic data in mock responses
   * @param {boolean} enabled - Whether to enable dynamic data
   */
  setDynamicData(enabled) {
    this.dynamicData = enabled;
  }
}

module.exports = MockRegistry;
