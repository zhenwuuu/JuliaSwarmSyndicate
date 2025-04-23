/**
 * Real implementations for swarm-related commands
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
 * Normalize swarm parameters to ensure swarm_id is set correctly
 * @param {Object} params - Original parameters
 * @returns {Object} - Normalized parameters
 */
function normalizeSwarmParams(params) {
  // Check for swarm_id first, then fall back to id
  if (!params.swarm_id && !params.id) {
    throw new JuliaBridgeError('Swarm ID is required', { params });
  }

  // Convert id to swarm_id as expected by the backend if needed
  const backendParams = { ...params };
  if (!backendParams.swarm_id && backendParams.id) {
    backendParams.swarm_id = backendParams.id;
    delete backendParams.id; // Remove the original id parameter
  }

  return backendParams;
}

/**
 * Real implementations for swarm commands
 */
const swarmImplementations = {
  // List swarms
  'list_swarms': async (params, juliaBridge) => {
    const result = await juliaBridge.runJuliaCommand('swarms.list_swarms', params);
    return processResult(result, 'list_swarms', params);
  },

  // Get swarm details
  'get_swarm': async (params, juliaBridge) => {
    const backendParams = normalizeSwarmParams(params);
    const result = await juliaBridge.runJuliaCommand('swarms.get_swarm', backendParams);
    return processResult(result, 'get_swarm', backendParams);
  },

  // Create swarm
  'create_swarm': async (params, juliaBridge) => {
    if (!params.name) {
      throw new JuliaBridgeError('Swarm name is required', { params });
    }

    if (!params.algorithm) {
      throw new JuliaBridgeError('Swarm algorithm is required', { params });
    }

    const result = await juliaBridge.runJuliaCommand('swarms.create_swarm', params);
    return processResult(result, 'create_swarm', params);
  },

  // Update swarm
  'update_swarm': async (params, juliaBridge) => {
    const backendParams = normalizeSwarmParams(params);
    const result = await juliaBridge.runJuliaCommand('swarms.update_swarm', backendParams);
    return processResult(result, 'update_swarm', backendParams);
  },

  // Delete swarm
  'delete_swarm': async (params, juliaBridge) => {
    const backendParams = normalizeSwarmParams(params);
    const result = await juliaBridge.runJuliaCommand('swarms.delete_swarm', backendParams);
    return processResult(result, 'delete_swarm', backendParams);
  },

  // Start swarm
  'start_swarm': async (params, juliaBridge) => {
    const backendParams = normalizeSwarmParams(params);
    backendParams.status = 'active';

    const result = await juliaBridge.runJuliaCommand('swarms.start_swarm', backendParams);
    return processResult(result, 'start_swarm', backendParams);
  },

  // Stop swarm
  'stop_swarm': async (params, juliaBridge) => {
    const backendParams = normalizeSwarmParams(params);
    backendParams.status = 'inactive';

    const result = await juliaBridge.runJuliaCommand('swarms.stop_swarm', backendParams);
    return processResult(result, 'stop_swarm', backendParams);
  },

  // List swarm algorithms
  'list_algorithms': async (params, juliaBridge) => {
    // Special case: The server.jl file has special handling for swarm.list_algorithms
    // Try both command formats to ensure compatibility
    try {
      // First try the standard format
      const result = await juliaBridge.runJuliaCommand('swarms.list_algorithms', params);
      return processResult(result, 'list_algorithms', params);
    } catch (error) {
      // If that fails, try the alternative format
      try {
        const result = await juliaBridge.runJuliaCommand('swarm.list_algorithms', params);
        return processResult(result, 'list_algorithms', params);
      } catch (secondError) {
        // If both fail, try the special case format from server.jl
        try {
          const result = await juliaBridge.runJuliaCommand('Swarm.get_available_algorithms', params);
          return processResult(result, 'list_algorithms', params);
        } catch (thirdError) {
          // If all attempts fail, throw the original error
          throw error;
        }
      }
    }
  },

  // Create OpenAI swarm
  'create_openai_swarm': async (params, juliaBridge) => {
    if (!params.name) {
      throw new JuliaBridgeError('Swarm name is required', { params });
    }

    const result = await juliaBridge.runJuliaCommand('swarms.create_openai_swarm', params);
    return processResult(result, 'create_openai_swarm', params);
  },

  // Run OpenAI task
  'run_openai_task': async (params, juliaBridge) => {
    if (!params.swarm_id) {
      throw new JuliaBridgeError('Swarm ID is required', { params });
    }

    if (!params.prompt) {
      throw new JuliaBridgeError('Prompt is required', { params });
    }

    const result = await juliaBridge.runJuliaCommand('swarms.run_openai_task', params);
    return processResult(result, 'run_openai_task', params);
  },

  // Get OpenAI response
  'get_openai_response': async (params, juliaBridge) => {
    if (!params.task_id) {
      throw new JuliaBridgeError('Task ID is required', { params });
    }

    const result = await juliaBridge.runJuliaCommand('swarms.get_openai_response', params);
    return processResult(result, 'get_openai_response', params);
  },

  // Connect agent to swarm
  'connect_swarm': async (params, juliaBridge) => {
    if (!params.agent_id) {
      throw new JuliaBridgeError('Agent ID is required', { params });
    }

    if (!params.swarm_id) {
      throw new JuliaBridgeError('Swarm ID is required', { params });
    }

    // Try both command formats to ensure compatibility
    try {
      // First try the standard format
      const result = await juliaBridge.runJuliaCommand('agents.connect_swarm', params);
      return processResult(result, 'connect_swarm', params);
    } catch (error) {
      // If that fails, try the alternative format
      try {
        const result = await juliaBridge.runJuliaCommand('swarms.add_agent_to_swarm', {
          agent_id: params.agent_id,
          swarm_id: params.swarm_id
        });
        return processResult(result, 'connect_swarm', params);
      } catch (secondError) {
        // If both fail, throw the original error
        throw error;
      }
    }
  },

  // Disconnect agent from swarm
  'disconnect_swarm': async (params, juliaBridge) => {
    if (!params.agent_id) {
      throw new JuliaBridgeError('Agent ID is required', { params });
    }

    if (!params.swarm_id) {
      throw new JuliaBridgeError('Swarm ID is required', { params });
    }

    // Try both command formats to ensure compatibility
    try {
      // First try the standard format
      const result = await juliaBridge.runJuliaCommand('agents.disconnect_swarm', params);
      return processResult(result, 'disconnect_swarm', params);
    } catch (error) {
      // If that fails, try the alternative format
      try {
        const result = await juliaBridge.runJuliaCommand('swarms.remove_agent_from_swarm', {
          agent_id: params.agent_id,
          swarm_id: params.swarm_id
        });
        return processResult(result, 'disconnect_swarm', params);
      } catch (secondError) {
        // If both fail, throw the original error
        throw error;
      }
    }
  },

  // Publish message to swarm
  'publish_to_swarm': async (params, juliaBridge) => {
    if (!params.swarm_id) {
      throw new JuliaBridgeError('Swarm ID is required', { params });
    }

    if (!params.message) {
      throw new JuliaBridgeError('Message is required', { params });
    }

    const result = await juliaBridge.runJuliaCommand('agents.publish_to_swarm', params);
    return processResult(result, 'publish_to_swarm', params);
  },

  // Subscribe to swarm messages
  'subscribe_to_swarm': async (params, juliaBridge) => {
    if (!params.swarm_id) {
      throw new JuliaBridgeError('Swarm ID is required', { params });
    }

    if (!params.agent_id) {
      throw new JuliaBridgeError('Agent ID is required', { params });
    }

    const result = await juliaBridge.runJuliaCommand('agents.subscribe_swarm', params);
    return processResult(result, 'subscribe_to_swarm', params);
  }
};

// Add aliases for commands
const aliases = {
  'swarms.list_swarms': swarmImplementations.list_swarms,
  'swarms.get_swarm': swarmImplementations.get_swarm,
  'swarms.create_swarm': swarmImplementations.create_swarm,
  'swarms.update_swarm': swarmImplementations.update_swarm,
  'swarms.delete_swarm': swarmImplementations.delete_swarm,
  'swarms.list_algorithms': swarmImplementations.list_algorithms,
  'swarms.create_openai_swarm': swarmImplementations.create_openai_swarm,
  'swarms.run_openai_task': swarmImplementations.run_openai_task,
  'swarms.get_openai_response': swarmImplementations.get_openai_response,
  'agents.connect_swarm': swarmImplementations.connect_swarm,
  'agents.disconnect_swarm': swarmImplementations.disconnect_swarm,
  'agents.publish_to_swarm': swarmImplementations.publish_to_swarm,
  'agents.subscribe_swarm': swarmImplementations.subscribe_to_swarm,
  'swarm.list_algorithms': swarmImplementations.list_algorithms
};

// Add all aliases to the exports
Object.assign(swarmImplementations, aliases);

module.exports = swarmImplementations;
