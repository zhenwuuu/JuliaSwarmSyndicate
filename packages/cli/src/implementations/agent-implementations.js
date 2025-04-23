/**
 * Real implementations for agent-related commands
 */

const { JuliaBridgeError, BackendError } = require('../errors/bridge-errors');

/**
 * Format agent parameters for create_agent command
 * @param {Object|Array} params - Agent parameters
 * @returns {Object} - Formatted agent parameters
 */
function formatAgentParams(params) {
  // Define agent type mapping
  const AGENT_TYPES = {
    'trading': 1,
    'monitor': 2,
    'arbitrage': 3,
    'data_collection': 4,
    'notification': 5,
    'custom': 99 // Default
  };

  let name, agentTypeInput, configInput;

  // Detect if params is old array format or new object format
  if (Array.isArray(params) && params.length >= 2) {
    [name, agentTypeInput, configInput] = params;
  } else if (typeof params === 'object' && params !== null && params.name && params.type) {
    name = params.name;
    agentTypeInput = params.type;
    // Config can be directly within params or nested under 'config'
    configInput = params.config || params;
  } else {
    throw new JuliaBridgeError('Invalid parameters for create_agent. Expected [name, type, config?] or {name, type, ...config}.', { params });
  }

  let config = {};
  // Parse config if it's a string (from array format)
  if (typeof configInput === 'string') {
    try {
      config = JSON.parse(configInput);
    } catch (e) {
      // Proceed with default config
    }
  } else if (typeof configInput === 'object' && configInput !== null) {
    config = configInput; // Already an object
  }

  // Map agent type string to numeric enum value, default to CUSTOM
  let typeValue = typeof agentTypeInput === 'number'
    ? agentTypeInput
    : (AGENT_TYPES[agentTypeInput?.toLowerCase()] ?? AGENT_TYPES['custom']);

  // Construct the standardized parameters expected by the enhanced backend
  const formattedParams = {
    name: name,
    type: typeValue,
    config: { // Ensure nested config structure
      abilities: config.abilities || [],
      chains: config.chains || [],
      parameters: {
        max_memory: config.max_memory || config.parameters?.max_memory || 1024,
        max_skills: config.max_skills || config.parameters?.max_skills || 10,
        update_interval: config.update_interval || config.parameters?.update_interval || 60,
        capabilities: config.capabilities || config.parameters?.capabilities || ['basic'],
        recovery_attempts: config.recovery_attempts || config.parameters?.recovery_attempts || 0
      },
      llm_config: config.llm_config || { // Provide defaults
        provider: "openai",
        model: "gpt-4o-mini",
        temperature: 0.7,
        max_tokens: 1024
      },
      memory_config: config.memory_config || { // Provide defaults
        max_size: 1000,
        retention_policy: "lru"
      },
      max_task_history: config.max_task_history || 100
    }
  };

  // Pass through id if specified in the original config/params
  if (config.id || params?.id) {
    formattedParams.id = config.id || params.id;
  }

  return formattedParams;
}

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
 * Normalize agent parameters to ensure agent_id is set correctly
 * @param {Object} params - Original parameters
 * @returns {Object} - Normalized parameters
 */
function normalizeAgentParams(params) {
  // Check for agent_id first, then fall back to id
  if (!params.agent_id && !params.id) {
    throw new JuliaBridgeError('Agent ID is required', { params });
  }

  // Convert id to agent_id as expected by the backend if needed
  const backendParams = { ...params };
  if (!backendParams.agent_id && backendParams.id) {
    backendParams.agent_id = backendParams.id;
    delete backendParams.id; // Remove the original id parameter
  }

  return backendParams;
}

/**
 * Real implementations for agent commands
 */
const agentImplementations = {
  // List agents
  'list_agents': async (params, juliaBridge) => {
    const result = await juliaBridge.runJuliaCommand('agents.list_agents', params);
    return processResult(result, 'list_agents', params);
  },

  // Get agent details
  'get_agent': async (params, juliaBridge) => {
    const backendParams = normalizeAgentParams(params);
    const result = await juliaBridge.runJuliaCommand('agents.get_agent', backendParams);
    return processResult(result, 'get_agent', backendParams);
  },

  // Create agent
  'create_agent': async (params, juliaBridge) => {
    const formattedParams = formatAgentParams(params);
    const result = await juliaBridge.runJuliaCommand('agents.create_agent', formattedParams);
    return processResult(result, 'create_agent', formattedParams);
  },

  // Update agent
  'update_agent': async (params, juliaBridge) => {
    const backendParams = normalizeAgentParams(params);
    const result = await juliaBridge.runJuliaCommand('agents.update_agent', backendParams);
    return processResult(result, 'update_agent', backendParams);
  },

  // Delete agent
  'delete_agent': async (params, juliaBridge) => {
    const backendParams = normalizeAgentParams(params);
    const result = await juliaBridge.runJuliaCommand('agents.delete_agent', backendParams);
    return processResult(result, 'delete_agent', backendParams);
  },

  // Start agent
  'start_agent': async (params, juliaBridge) => {
    const backendParams = normalizeAgentParams(params);
    const result = await juliaBridge.runJuliaCommand('agents.start_agent', backendParams);
    return processResult(result, 'start_agent', backendParams);
  },

  // Stop agent
  'stop_agent': async (params, juliaBridge) => {
    const backendParams = normalizeAgentParams(params);
    const result = await juliaBridge.runJuliaCommand('agents.stop_agent', backendParams);
    return processResult(result, 'stop_agent', backendParams);
  },

  // Pause agent
  'pause_agent': async (params, juliaBridge) => {
    const backendParams = normalizeAgentParams(params);
    const result = await juliaBridge.runJuliaCommand('agents.pause_agent', backendParams);
    return processResult(result, 'pause_agent', backendParams);
  },

  // Resume agent
  'resume_agent': async (params, juliaBridge) => {
    const backendParams = normalizeAgentParams(params);
    const result = await juliaBridge.runJuliaCommand('agents.resume_agent', backendParams);
    return processResult(result, 'resume_agent', backendParams);
  },

  // Get agent status
  'get_agent_status': async (params, juliaBridge) => {
    const backendParams = normalizeAgentParams(params);
    const result = await juliaBridge.runJuliaCommand('agents.get_agent_status', backendParams);
    return processResult(result, 'get_agent_status', backendParams);
  },

  // Execute agent task
  'execute_agent_task': async (params, juliaBridge) => {
    const backendParams = normalizeAgentParams(params);
    const result = await juliaBridge.runJuliaCommand('agents.execute_task', backendParams);
    return processResult(result, 'execute_agent_task', backendParams);
  },

  // Get agent memory
  'get_agent_memory': async (params, juliaBridge) => {
    const backendParams = normalizeAgentParams(params);
    const result = await juliaBridge.runJuliaCommand('agents.get_memory', backendParams);
    return processResult(result, 'get_agent_memory', backendParams);
  },

  // Set agent memory
  'set_agent_memory': async (params, juliaBridge) => {
    if (!params.key) {
      throw new JuliaBridgeError('Memory key is required', { params });
    }

    const backendParams = normalizeAgentParams(params);
    const result = await juliaBridge.runJuliaCommand('agents.set_memory', backendParams);
    return processResult(result, 'set_agent_memory', backendParams);
  },

  // Clear agent memory
  'clear_agent_memory': async (params, juliaBridge) => {
    const backendParams = normalizeAgentParams(params);
    const result = await juliaBridge.runJuliaCommand('agents.clear_memory', backendParams);
    return processResult(result, 'clear_agent_memory', backendParams);
  },

  // Get agent metrics
  'get_agent_metrics': async (params, juliaBridge) => {
    const result = await juliaBridge.runJuliaCommand('agents.get_metrics', params);
    return processResult(result, 'get_agent_metrics', params);
  },

  // Get agent health
  'get_agent_health': async (params, juliaBridge) => {
    const result = await juliaBridge.runJuliaCommand('agents.get_health_status', params);
    return processResult(result, 'get_agent_health', params);
  }
};

// Add aliases for commands
const aliases = {
  'agents.list_agents': agentImplementations.list_agents,
  'agents.get_agent': agentImplementations.get_agent,
  'agents.create_agent': agentImplementations.create_agent,
  'agents.update_agent': agentImplementations.update_agent,
  'agents.delete_agent': agentImplementations.delete_agent,
  'agents.start_agent': agentImplementations.start_agent,
  'agents.stop_agent': agentImplementations.stop_agent,
  'agents.pause_agent': agentImplementations.pause_agent,
  'agents.resume_agent': agentImplementations.resume_agent,
  'agents.get_status': agentImplementations.get_agent_status,
  'agents.execute_task': agentImplementations.execute_agent_task,
  'agents.get_memory': agentImplementations.get_agent_memory,
  'agents.set_memory': agentImplementations.set_agent_memory,
  'agents.clear_memory': agentImplementations.clear_agent_memory,
  'agents.get_metrics': agentImplementations.get_agent_metrics,
  'agents.get_health_status': agentImplementations.get_agent_health
};

// Add all aliases to the exports
Object.assign(agentImplementations, aliases);

module.exports = agentImplementations;
