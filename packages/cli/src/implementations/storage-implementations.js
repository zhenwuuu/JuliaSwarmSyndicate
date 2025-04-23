/**
 * Real implementations for storage-related commands
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
 * Real implementations for storage commands
 */
const storageImplementations = {
  // List storage providers
  'list_storage_providers': async (params, juliaBridge) => {
    // Try both command formats to ensure compatibility
    try {
      const result = await juliaBridge.runJuliaCommand('storage.list_providers', params);
      return processResult(result, 'list_storage_providers', params);
    } catch (error) {
      // If that fails, try the alternative format
      try {
        const result = await juliaBridge.runJuliaCommand('Storage.list_providers', params);
        return processResult(result, 'list_storage_providers', params);
      } catch (secondError) {
        // If both fail, throw the original error
        throw error;
      }
    }
  },

  // Get storage provider details
  'get_storage_provider': async (params, juliaBridge) => {
    if (!params.provider) {
      throw new JuliaBridgeError('Storage provider name is required', { params });
    }
    
    try {
      const result = await juliaBridge.runJuliaCommand('storage.get_provider', params);
      return processResult(result, 'get_storage_provider', params);
    } catch (error) {
      // If that fails, try the alternative format
      try {
        const result = await juliaBridge.runJuliaCommand('Storage.get_provider', params);
        return processResult(result, 'get_storage_provider', params);
      } catch (secondError) {
        // If both fail, throw the original error
        throw error;
      }
    }
  },

  // Store data
  'store_data': async (params, juliaBridge) => {
    if (!params.data) {
      throw new JuliaBridgeError('Data is required', { params });
    }
    
    if (!params.provider) {
      params.provider = 'sqlite'; // Default provider
    }
    
    try {
      const result = await juliaBridge.runJuliaCommand('storage.store', params);
      return processResult(result, 'store_data', params);
    } catch (error) {
      // If that fails, try the alternative format
      try {
        const result = await juliaBridge.runJuliaCommand('Storage.store', params);
        return processResult(result, 'store_data', params);
      } catch (secondError) {
        // If both fail, throw the original error
        throw error;
      }
    }
  },

  // Retrieve data
  'retrieve_data': async (params, juliaBridge) => {
    if (!params.id) {
      throw new JuliaBridgeError('Data ID is required', { params });
    }
    
    if (!params.provider) {
      params.provider = 'sqlite'; // Default provider
    }
    
    try {
      const result = await juliaBridge.runJuliaCommand('storage.retrieve', params);
      return processResult(result, 'retrieve_data', params);
    } catch (error) {
      // If that fails, try the alternative format
      try {
        const result = await juliaBridge.runJuliaCommand('Storage.retrieve', params);
        return processResult(result, 'retrieve_data', params);
      } catch (secondError) {
        // If both fail, throw the original error
        throw error;
      }
    }
  },

  // Delete data
  'delete_data': async (params, juliaBridge) => {
    if (!params.id) {
      throw new JuliaBridgeError('Data ID is required', { params });
    }
    
    if (!params.provider) {
      params.provider = 'sqlite'; // Default provider
    }
    
    try {
      const result = await juliaBridge.runJuliaCommand('storage.delete', params);
      return processResult(result, 'delete_data', params);
    } catch (error) {
      // If that fails, try the alternative format
      try {
        const result = await juliaBridge.runJuliaCommand('Storage.delete', params);
        return processResult(result, 'delete_data', params);
      } catch (secondError) {
        // If both fail, throw the original error
        throw error;
      }
    }
  },

  // List data
  'list_data': async (params, juliaBridge) => {
    if (!params.provider) {
      params.provider = 'sqlite'; // Default provider
    }
    
    try {
      const result = await juliaBridge.runJuliaCommand('storage.list', params);
      return processResult(result, 'list_data', params);
    } catch (error) {
      // If that fails, try the alternative format
      try {
        const result = await juliaBridge.runJuliaCommand('Storage.list', params);
        return processResult(result, 'list_data', params);
      } catch (secondError) {
        // If both fail, throw the original error
        throw error;
      }
    }
  }
};

// Add aliases for commands
const aliases = {
  'storage.list_providers': storageImplementations.list_storage_providers,
  'storage.get_provider': storageImplementations.get_storage_provider,
  'storage.store': storageImplementations.store_data,
  'storage.retrieve': storageImplementations.retrieve_data,
  'storage.delete': storageImplementations.delete_data,
  'storage.list': storageImplementations.list_data,
  'Storage.list_providers': storageImplementations.list_storage_providers,
  'Storage.get_provider': storageImplementations.get_storage_provider,
  'Storage.store': storageImplementations.store_data,
  'Storage.retrieve': storageImplementations.retrieve_data,
  'Storage.delete': storageImplementations.delete_data,
  'Storage.list': storageImplementations.list_data
};

// Add all aliases to the exports
Object.assign(storageImplementations, aliases);

module.exports = storageImplementations;
