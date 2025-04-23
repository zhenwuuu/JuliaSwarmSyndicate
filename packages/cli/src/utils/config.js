/**
 * Configuration system for EnhancedJuliaBridge
 */

const { LOG_LEVELS } = require('./logger');

// Default configuration
const DEFAULT_CONFIG = {
  // Connection settings
  connection: {
    checkInterval: 30000, // 30 seconds
    healthEndpoint: '/health',
    fallbackPort: 8052,
    timeout: 10000, // 10 seconds
  },
  
  // Command execution settings
  commands: {
    maxRetries: 3,
    retryDelay: 1000, // 1 second
    timeout: 30000, // 30 seconds
    fallbackToMock: true,
  },
  
  // Mock settings
  mocks: {
    enabled: true,
    directory: null, // Will use built-in mocks if null
    dynamicData: true, // Generate dynamic data based on input params
  },
  
  // Logging settings
  logging: {
    level: LOG_LEVELS.INFO,
    enableColors: true,
    timestamps: true,
    prefix: 'JuliaBridge',
  },
  
  // UI settings
  ui: {
    showSpinners: true,
    spinnerColor: 'blue',
  }
};

/**
 * Merge configuration objects
 * @param {Object} target - Target configuration object
 * @param {Object} source - Source configuration object
 * @returns {Object} - Merged configuration
 */
function mergeConfig(target, source) {
  const result = { ...target };
  
  if (!source) {
    return result;
  }
  
  Object.keys(source).forEach(key => {
    if (typeof source[key] === 'object' && source[key] !== null && !Array.isArray(source[key])) {
      // If the key exists in target and is an object, merge recursively
      if (target[key] && typeof target[key] === 'object' && !Array.isArray(target[key])) {
        result[key] = mergeConfig(target[key], source[key]);
      } else {
        // Otherwise, just assign
        result[key] = { ...source[key] };
      }
    } else {
      // For non-objects, just assign
      result[key] = source[key];
    }
  });
  
  return result;
}

/**
 * Create a configuration object with defaults
 * @param {Object} userConfig - User-provided configuration
 * @returns {Object} - Complete configuration with defaults
 */
function createConfig(userConfig = {}) {
  return mergeConfig(DEFAULT_CONFIG, userConfig);
}

module.exports = {
  DEFAULT_CONFIG,
  createConfig,
  mergeConfig
};
