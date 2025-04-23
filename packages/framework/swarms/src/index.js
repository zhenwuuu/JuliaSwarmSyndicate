/**
 * JuliaOS Framework - Swarms Module
 *
 * This module provides interfaces to interact with swarms and swarm algorithms in the Julia backend.
 */

const SwarmAlgorithms = require('./SwarmAlgorithms');

/**
 * Swarms class for interacting with swarms in the Julia backend
 */
class Swarms {
  /**
   * Create a new Swarms instance
   *
   * @param {Object} bridge - JuliaBridge instance
   */
  constructor(bridge) {
    this.bridge = bridge;
  }

  /**
   * Get available swarm algorithms
   *
   * @returns {Promise<Array>} - List of available algorithms
   */
  async getAvailableAlgorithms() {
    return SwarmAlgorithms.getAvailableAlgorithms(this.bridge);
  }

  /**
   * Get details of a specific algorithm
   *
   * @param {string} algorithmId - ID of the algorithm
   * @returns {Promise<Object>} - Algorithm details
   */
  async getAlgorithmDetails(algorithmId) {
    return SwarmAlgorithms.getAlgorithmDetails(this.bridge, algorithmId);
  }

  /**
   * Configure a swarm algorithm with specific parameters
   *
   * @param {string} algorithmId - ID of the algorithm
   * @param {Object} parameters - Configuration parameters
   * @returns {Promise<Object>} - Configuration result
   */
  async configureAlgorithm(algorithmId, parameters) {
    return SwarmAlgorithms.configureAlgorithm(this.bridge, algorithmId, parameters);
  }

  /**
   * Run a benchmark for a specific algorithm
   *
   * @param {string} algorithmId - ID of the algorithm
   * @param {Object} benchmarkParams - Benchmark parameters
   * @returns {Promise<Object>} - Benchmark results
   */
  async runBenchmark(algorithmId, benchmarkParams) {
    return SwarmAlgorithms.runBenchmark(this.bridge, algorithmId, benchmarkParams);
  }

  /**
   * Compare multiple algorithms
   *
   * @param {Array<string>} algorithmIds - IDs of the algorithms to compare
   * @param {Object} compareParams - Comparison parameters
   * @returns {Promise<Object>} - Comparison results
   */
  async compareAlgorithms(algorithmIds, compareParams) {
    return SwarmAlgorithms.compareAlgorithms(this.bridge, algorithmIds, compareParams);
  }

  /**
   * Test an algorithm with specific test cases
   *
   * @param {string} algorithmId - ID of the algorithm
   * @param {Object} testParams - Test parameters
   * @returns {Promise<Object>} - Test results
   */
  async testAlgorithm(algorithmId, testParams) {
    return SwarmAlgorithms.testAlgorithm(this.bridge, algorithmId, testParams);
  }

  /**
   * Optimize an algorithm's parameters
   *
   * @param {string} algorithmId - ID of the algorithm
   * @param {Object} optimizeParams - Optimization parameters
   * @returns {Promise<Object>} - Optimization results
   */
  async optimizeAlgorithm(algorithmId, optimizeParams) {
    return SwarmAlgorithms.optimizeAlgorithm(this.bridge, algorithmId, optimizeParams);
  }

  /**
   * Create a new swarm
   *
   * @param {Object} config - Swarm configuration
   * @returns {Promise<Object>} - Created swarm
   */
  async createSwarm(config) {
    try {
      const result = await this.bridge.runJuliaCommand('Swarm.create_swarm', config);
      return {
        success: result.success,
        swarm: result.data && result.data.swarm ? result.data.swarm : (result.swarm || {}),
        error: result.error
      };
    } catch (error) {
      return {
        success: false,
        swarm: {},
        error: error.message || 'Failed to create swarm'
      };
    }
  }

  /**
   * Get a swarm by ID
   *
   * @param {string} swarmId - ID of the swarm
   * @returns {Promise<Object>} - Swarm details
   */
  async getSwarm(swarmId) {
    try {
      const result = await this.bridge.runJuliaCommand('Swarm.get_swarm', { swarm_id: swarmId });
      return {
        success: result.success,
        swarm: result.data && result.data.swarm ? result.data.swarm : (result.swarm || {}),
        error: result.error
      };
    } catch (error) {
      return {
        success: false,
        swarm: {},
        error: error.message || 'Failed to get swarm'
      };
    }
  }

  /**
   * List all swarms
   *
   * @param {Object} filters - Optional filters
   * @returns {Promise<Array>} - List of swarms
   */
  async listSwarms(filters = {}) {
    try {
      const result = await this.bridge.runJuliaCommand('Swarm.list_swarms', { filters });
      return {
        success: result.success,
        swarms: result.data && result.data.swarms ? result.data.swarms : (result.swarms || []),
        error: result.error
      };
    } catch (error) {
      return {
        success: false,
        swarms: [],
        error: error.message || 'Failed to list swarms'
      };
    }
  }

  /**
   * Start a swarm
   *
   * @param {string} swarmId - ID of the swarm
   * @returns {Promise<Object>} - Start result
   */
  async startSwarm(swarmId) {
    try {
      const result = await this.bridge.runJuliaCommand('Swarm.start_swarm', { swarm_id: swarmId });
      return {
        success: result.success,
        status: result.data && result.data.status ? result.data.status : (result.status || {}),
        error: result.error
      };
    } catch (error) {
      return {
        success: false,
        status: {},
        error: error.message || 'Failed to start swarm'
      };
    }
  }

  /**
   * Stop a swarm
   *
   * @param {string} swarmId - ID of the swarm
   * @returns {Promise<Object>} - Stop result
   */
  async stopSwarm(swarmId) {
    try {
      const result = await this.bridge.runJuliaCommand('Swarm.stop_swarm', { swarm_id: swarmId });
      return {
        success: result.success,
        status: result.data && result.data.status ? result.data.status : (result.status || {}),
        error: result.error
      };
    } catch (error) {
      return {
        success: false,
        status: {},
        error: error.message || 'Failed to stop swarm'
      };
    }
  }
}

module.exports = Swarms;
