/**
 * Real implementations for blockchain-related commands
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
 * Real implementations for blockchain commands
 */
const blockchainImplementations = {
  // List supported chains
  'list_chains': async (params, juliaBridge) => {
    try {
      const result = await juliaBridge.runJuliaCommand('blockchain.list_chains', params);
      return processResult(result, 'list_chains', params);
    } catch (error) {
      // If that fails, try the alternative format
      try {
        const result = await juliaBridge.runJuliaCommand('Blockchain.list_chains', params);
        return processResult(result, 'list_chains', params);
      } catch (secondError) {
        // If both fail, throw the original error
        throw error;
      }
    }
  },

  // Get chain details
  'get_chain': async (params, juliaBridge) => {
    if (!params.chain) {
      throw new JuliaBridgeError('Chain name is required', { params });
    }
    
    try {
      const result = await juliaBridge.runJuliaCommand('blockchain.get_chain', params);
      return processResult(result, 'get_chain', params);
    } catch (error) {
      // If that fails, try the alternative format
      try {
        const result = await juliaBridge.runJuliaCommand('Blockchain.get_chain', params);
        return processResult(result, 'get_chain', params);
      } catch (secondError) {
        // If both fail, throw the original error
        throw error;
      }
    }
  },

  // Get account balance
  'get_balance': async (params, juliaBridge) => {
    if (!params.address) {
      throw new JuliaBridgeError('Address is required', { params });
    }
    
    if (!params.chain) {
      throw new JuliaBridgeError('Chain name is required', { params });
    }
    
    try {
      const result = await juliaBridge.runJuliaCommand('blockchain.get_balance', params);
      return processResult(result, 'get_balance', params);
    } catch (error) {
      // If that fails, try the alternative format
      try {
        const result = await juliaBridge.runJuliaCommand('Blockchain.get_balance', params);
        return processResult(result, 'get_balance', params);
      } catch (secondError) {
        // If both fail, throw the original error
        throw error;
      }
    }
  },

  // Get token balance
  'get_token_balance': async (params, juliaBridge) => {
    if (!params.address) {
      throw new JuliaBridgeError('Address is required', { params });
    }
    
    if (!params.token) {
      throw new JuliaBridgeError('Token address is required', { params });
    }
    
    if (!params.chain) {
      throw new JuliaBridgeError('Chain name is required', { params });
    }
    
    try {
      const result = await juliaBridge.runJuliaCommand('blockchain.get_token_balance', params);
      return processResult(result, 'get_token_balance', params);
    } catch (error) {
      // If that fails, try the alternative format
      try {
        const result = await juliaBridge.runJuliaCommand('Blockchain.get_token_balance', params);
        return processResult(result, 'get_token_balance', params);
      } catch (secondError) {
        // If both fail, throw the original error
        throw error;
      }
    }
  },

  // Send transaction
  'send_transaction': async (params, juliaBridge) => {
    if (!params.from) {
      throw new JuliaBridgeError('From address is required', { params });
    }
    
    if (!params.to) {
      throw new JuliaBridgeError('To address is required', { params });
    }
    
    if (!params.amount) {
      throw new JuliaBridgeError('Amount is required', { params });
    }
    
    if (!params.chain) {
      throw new JuliaBridgeError('Chain name is required', { params });
    }
    
    try {
      const result = await juliaBridge.runJuliaCommand('blockchain.send_transaction', params);
      return processResult(result, 'send_transaction', params);
    } catch (error) {
      // If that fails, try the alternative format
      try {
        const result = await juliaBridge.runJuliaCommand('Blockchain.send_transaction', params);
        return processResult(result, 'send_transaction', params);
      } catch (secondError) {
        // If both fail, throw the original error
        throw error;
      }
    }
  },

  // Get transaction status
  'get_transaction_status': async (params, juliaBridge) => {
    if (!params.tx_hash) {
      throw new JuliaBridgeError('Transaction hash is required', { params });
    }
    
    if (!params.chain) {
      throw new JuliaBridgeError('Chain name is required', { params });
    }
    
    try {
      const result = await juliaBridge.runJuliaCommand('blockchain.get_transaction_status', params);
      return processResult(result, 'get_transaction_status', params);
    } catch (error) {
      // If that fails, try the alternative format
      try {
        const result = await juliaBridge.runJuliaCommand('Blockchain.get_transaction_status', params);
        return processResult(result, 'get_transaction_status', params);
      } catch (secondError) {
        // If both fail, throw the original error
        throw error;
      }
    }
  },

  // Get gas price
  'get_gas_price': async (params, juliaBridge) => {
    if (!params.chain) {
      throw new JuliaBridgeError('Chain name is required', { params });
    }
    
    try {
      const result = await juliaBridge.runJuliaCommand('blockchain.get_gas_price', params);
      return processResult(result, 'get_gas_price', params);
    } catch (error) {
      // If that fails, try the alternative format
      try {
        const result = await juliaBridge.runJuliaCommand('Blockchain.get_gas_price', params);
        return processResult(result, 'get_gas_price', params);
      } catch (secondError) {
        // If both fail, throw the original error
        throw error;
      }
    }
  }
};

// Add aliases for commands
const aliases = {
  'blockchain.list_chains': blockchainImplementations.list_chains,
  'blockchain.get_chain': blockchainImplementations.get_chain,
  'blockchain.get_balance': blockchainImplementations.get_balance,
  'blockchain.get_token_balance': blockchainImplementations.get_token_balance,
  'blockchain.send_transaction': blockchainImplementations.send_transaction,
  'blockchain.get_transaction_status': blockchainImplementations.get_transaction_status,
  'blockchain.get_gas_price': blockchainImplementations.get_gas_price,
  'Blockchain.list_chains': blockchainImplementations.list_chains,
  'Blockchain.get_chain': blockchainImplementations.get_chain,
  'Blockchain.get_balance': blockchainImplementations.get_balance,
  'Blockchain.get_token_balance': blockchainImplementations.get_token_balance,
  'Blockchain.send_transaction': blockchainImplementations.send_transaction,
  'Blockchain.get_transaction_status': blockchainImplementations.get_transaction_status,
  'Blockchain.get_gas_price': blockchainImplementations.get_gas_price
};

// Add all aliases to the exports
Object.assign(blockchainImplementations, aliases);

module.exports = blockchainImplementations;
