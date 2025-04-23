/**
 * Real implementations for system-related commands
 */

const { JuliaBridgeError, BackendError } = require('../errors/bridge-errors');

/**
 * Process the result from the Julia backend
 * @param {Object} result - Result from the Julia backend
 * @param {string} command - Command name
 * @param {Object} params - Command parameters
 * @returns {*} - Processed result
 */
function processResult(result, command, params) {
  if (!result) {
    throw new JuliaBridgeError(`No response received for ${command}`, { command, params });
  }

  // Check for explicit backend error structure ({ success: false, error: '...' })
  if (result && result.success === false && result.error) {
    throw new BackendError(result.error, { command, params, backendResponse: result });
  }

  // Check for other potential implicit error formats
  if (result && result.error && !result.success) {
    throw new BackendError(result.error.message || result.error, { command, params, backendResponse: result });
  }

  // Extract data from the result if it exists
  if (result && result.data) {
    return result.data;
  }

  return result;
}

/**
 * Real implementations for system commands
 */
const systemImplementations = {
  // Check system health
  'check_system_health': async (params, juliaBridge) => {
    const result = await juliaBridge.runJuliaCommand('system.health', params);
    return processResult(result, 'check_system_health', params);
  },

  // Get system overview
  'get_system_overview': async (params, juliaBridge) => {
    const result = await juliaBridge.runJuliaCommand('metrics.get_system_overview', params);
    return processResult(result, 'get_system_overview', params);
  },

  // Get realtime metrics
  'get_realtime_metrics': async (params, juliaBridge) => {
    const result = await juliaBridge.runJuliaCommand('metrics.get_realtime_metrics', params);
    return processResult(result, 'get_realtime_metrics', params);
  },

  // Get resource usage
  'get_resource_usage': async (params, juliaBridge) => {
    const result = await juliaBridge.runJuliaCommand('metrics.get_resource_usage', params);
    return processResult(result, 'get_resource_usage', params);
  },

  // Run performance test
  'run_performance_test': async (params, juliaBridge) => {
    const result = await juliaBridge.runJuliaCommand('metrics.run_performance_test', params);
    return processResult(result, 'run_performance_test', params);
  },

  // Get system config
  'get_system_config': async (params, juliaBridge) => {
    const result = await juliaBridge.runJuliaCommand('system.get_config', params);
    return processResult(result, 'get_system_config', params);
  },

  // Update system config
  'update_system_config': async (params, juliaBridge) => {
    const result = await juliaBridge.runJuliaCommand('system.update_config', params);
    return processResult(result, 'update_system_config', params);
  }
};

// Add aliases for commands
const aliases = {
  'system.health': systemImplementations.check_system_health,
  'metrics.get_system_overview': systemImplementations.get_system_overview,
  'metrics.get_realtime_metrics': systemImplementations.get_realtime_metrics,
  'metrics.get_resource_usage': systemImplementations.get_resource_usage,
  'metrics.run_performance_test': systemImplementations.run_performance_test,
  'system.get_config': systemImplementations.get_system_config,
  'system.update_config': systemImplementations.update_system_config
};

// Add all aliases to the exports
Object.assign(systemImplementations, aliases);

module.exports = systemImplementations;
