/**
 * Mock Registry Index
 * 
 * Exports all mock implementations and provides a function to initialize the registry
 */

const MockRegistry = require('./mock-registry');
const agentMocks = require('./agent-mocks');
const swarmMocks = require('./swarm-mocks');
const systemMocks = require('./system-mocks');

/**
 * Initialize the mock registry with all available mock implementations
 * @param {Object} logger - Logger instance
 * @param {Object} config - Configuration object
 * @returns {MockRegistry} - Initialized mock registry
 */
function initializeMockRegistry(logger, config = {}) {
  const registry = new MockRegistry(logger);
  
  // Set dynamic data based on config
  if (config.mocks && typeof config.mocks.dynamicData === 'boolean') {
    registry.setDynamicData(config.mocks.dynamicData);
  }
  
  // Register all mock implementations
  registry.registerBulk(agentMocks);
  registry.registerBulk(swarmMocks);
  registry.registerBulk(systemMocks);
  
  logger.info('Mock registry initialized with default implementations');
  
  return registry;
}

module.exports = {
  MockRegistry,
  initializeMockRegistry,
  agentMocks,
  swarmMocks,
  systemMocks
};
