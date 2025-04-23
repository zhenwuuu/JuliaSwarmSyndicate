/**
 * Implementation Registry Index
 *
 * Exports all real implementations and provides a function to initialize the registry
 */

const ImplementationRegistry = require('./implementation-registry');
const agentImplementations = require('./agent-implementations');
const swarmImplementations = require('./swarm-implementations');
const systemImplementations = require('./system-implementations');
const storageImplementations = require('./storage-implementations');
const blockchainImplementations = require('./blockchain-implementations');
const dexImplementations = require('./dex-implementations');

/**
 * Initialize the implementation registry with all available implementations
 * @param {Object} logger - Logger instance
 * @param {Object} juliaBridge - JuliaBridge instance
 * @returns {ImplementationRegistry} - Initialized implementation registry
 */
function initializeImplementationRegistry(logger, juliaBridge) {
  const registry = new ImplementationRegistry(logger, juliaBridge);

  // Register all implementations
  registry.registerBulk(agentImplementations);
  registry.registerBulk(swarmImplementations);
  registry.registerBulk(systemImplementations);
  registry.registerBulk(storageImplementations);
  registry.registerBulk(blockchainImplementations);
  registry.registerBulk(dexImplementations);

  logger.info('Implementation registry initialized with real implementations');

  return registry;
}

module.exports = {
  ImplementationRegistry,
  initializeImplementationRegistry,
  agentImplementations,
  swarmImplementations,
  systemImplementations,
  storageImplementations,
  blockchainImplementations,
  dexImplementations
};
