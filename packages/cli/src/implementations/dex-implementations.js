/**
 * Real implementations for DEX-related commands
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
 * Real implementations for DEX commands
 */
const dexImplementations = {
  // List supported DEXes
  'list_dexes': async (params, juliaBridge) => {
    try {
      const result = await juliaBridge.runJuliaCommand('dex.list_dexes', params);
      return processResult(result, 'list_dexes', params);
    } catch (error) {
      // If that fails, try the alternative format
      try {
        const result = await juliaBridge.runJuliaCommand('DEX.list_dexes', params);
        return processResult(result, 'list_dexes', params);
      } catch (secondError) {
        // If both fail, throw the original error
        throw error;
      }
    }
  },

  // Get DEX details
  'get_dex': async (params, juliaBridge) => {
    if (!params.dex) {
      throw new JuliaBridgeError('DEX name is required', { params });
    }
    
    try {
      const result = await juliaBridge.runJuliaCommand('dex.get_dex', params);
      return processResult(result, 'get_dex', params);
    } catch (error) {
      // If that fails, try the alternative format
      try {
        const result = await juliaBridge.runJuliaCommand('DEX.get_dex', params);
        return processResult(result, 'get_dex', params);
      } catch (secondError) {
        // If both fail, throw the original error
        throw error;
      }
    }
  },

  // Get token price
  'get_token_price': async (params, juliaBridge) => {
    if (!params.token) {
      throw new JuliaBridgeError('Token symbol is required', { params });
    }
    
    if (!params.dex) {
      throw new JuliaBridgeError('DEX name is required', { params });
    }
    
    try {
      const result = await juliaBridge.runJuliaCommand('dex.get_token_price', params);
      return processResult(result, 'get_token_price', params);
    } catch (error) {
      // If that fails, try the alternative format
      try {
        const result = await juliaBridge.runJuliaCommand('DEX.get_token_price', params);
        return processResult(result, 'get_token_price', params);
      } catch (secondError) {
        // If both fail, throw the original error
        throw error;
      }
    }
  },

  // Get token pair price
  'get_token_pair_price': async (params, juliaBridge) => {
    if (!params.base_token) {
      throw new JuliaBridgeError('Base token symbol is required', { params });
    }
    
    if (!params.quote_token) {
      throw new JuliaBridgeError('Quote token symbol is required', { params });
    }
    
    if (!params.dex) {
      throw new JuliaBridgeError('DEX name is required', { params });
    }
    
    try {
      const result = await juliaBridge.runJuliaCommand('dex.get_token_pair_price', params);
      return processResult(result, 'get_token_pair_price', params);
    } catch (error) {
      // If that fails, try the alternative format
      try {
        const result = await juliaBridge.runJuliaCommand('DEX.get_token_pair_price', params);
        return processResult(result, 'get_token_pair_price', params);
      } catch (secondError) {
        // If both fail, throw the original error
        throw error;
      }
    }
  },

  // Get swap quote
  'get_swap_quote': async (params, juliaBridge) => {
    if (!params.from_token) {
      throw new JuliaBridgeError('From token symbol is required', { params });
    }
    
    if (!params.to_token) {
      throw new JuliaBridgeError('To token symbol is required', { params });
    }
    
    if (!params.amount) {
      throw new JuliaBridgeError('Amount is required', { params });
    }
    
    if (!params.dex) {
      throw new JuliaBridgeError('DEX name is required', { params });
    }
    
    try {
      const result = await juliaBridge.runJuliaCommand('dex.get_swap_quote', params);
      return processResult(result, 'get_swap_quote', params);
    } catch (error) {
      // If that fails, try the alternative format
      try {
        const result = await juliaBridge.runJuliaCommand('DEX.get_swap_quote', params);
        return processResult(result, 'get_swap_quote', params);
      } catch (secondError) {
        // If both fail, throw the original error
        throw error;
      }
    }
  },

  // Execute swap
  'execute_swap': async (params, juliaBridge) => {
    if (!params.from_token) {
      throw new JuliaBridgeError('From token symbol is required', { params });
    }
    
    if (!params.to_token) {
      throw new JuliaBridgeError('To token symbol is required', { params });
    }
    
    if (!params.amount) {
      throw new JuliaBridgeError('Amount is required', { params });
    }
    
    if (!params.dex) {
      throw new JuliaBridgeError('DEX name is required', { params });
    }
    
    if (!params.wallet) {
      throw new JuliaBridgeError('Wallet address is required', { params });
    }
    
    try {
      const result = await juliaBridge.runJuliaCommand('dex.execute_swap', params);
      return processResult(result, 'execute_swap', params);
    } catch (error) {
      // If that fails, try the alternative format
      try {
        const result = await juliaBridge.runJuliaCommand('DEX.execute_swap', params);
        return processResult(result, 'execute_swap', params);
      } catch (secondError) {
        // If both fail, throw the original error
        throw error;
      }
    }
  },

  // Get liquidity pools
  'get_liquidity_pools': async (params, juliaBridge) => {
    if (!params.dex) {
      throw new JuliaBridgeError('DEX name is required', { params });
    }
    
    try {
      const result = await juliaBridge.runJuliaCommand('dex.get_liquidity_pools', params);
      return processResult(result, 'get_liquidity_pools', params);
    } catch (error) {
      // If that fails, try the alternative format
      try {
        const result = await juliaBridge.runJuliaCommand('DEX.get_liquidity_pools', params);
        return processResult(result, 'get_liquidity_pools', params);
      } catch (secondError) {
        // If both fail, throw the original error
        throw error;
      }
    }
  },

  // Get pool details
  'get_pool_details': async (params, juliaBridge) => {
    if (!params.pool_id) {
      throw new JuliaBridgeError('Pool ID is required', { params });
    }
    
    if (!params.dex) {
      throw new JuliaBridgeError('DEX name is required', { params });
    }
    
    try {
      const result = await juliaBridge.runJuliaCommand('dex.get_pool_details', params);
      return processResult(result, 'get_pool_details', params);
    } catch (error) {
      // If that fails, try the alternative format
      try {
        const result = await juliaBridge.runJuliaCommand('DEX.get_pool_details', params);
        return processResult(result, 'get_pool_details', params);
      } catch (secondError) {
        // If both fail, throw the original error
        throw error;
      }
    }
  }
};

// Add aliases for commands
const aliases = {
  'dex.list_dexes': dexImplementations.list_dexes,
  'dex.get_dex': dexImplementations.get_dex,
  'dex.get_token_price': dexImplementations.get_token_price,
  'dex.get_token_pair_price': dexImplementations.get_token_pair_price,
  'dex.get_swap_quote': dexImplementations.get_swap_quote,
  'dex.execute_swap': dexImplementations.execute_swap,
  'dex.get_liquidity_pools': dexImplementations.get_liquidity_pools,
  'dex.get_pool_details': dexImplementations.get_pool_details,
  'DEX.list_dexes': dexImplementations.list_dexes,
  'DEX.get_dex': dexImplementations.get_dex,
  'DEX.get_token_price': dexImplementations.get_token_price,
  'DEX.get_token_pair_price': dexImplementations.get_token_pair_price,
  'DEX.get_swap_quote': dexImplementations.get_swap_quote,
  'DEX.execute_swap': dexImplementations.execute_swap,
  'DEX.get_liquidity_pools': dexImplementations.get_liquidity_pools,
  'DEX.get_pool_details': dexImplementations.get_pool_details
};

// Add all aliases to the exports
Object.assign(dexImplementations, aliases);

module.exports = dexImplementations;
