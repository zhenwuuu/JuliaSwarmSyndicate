/**
 * Enhanced JuliaBridge Wrapper
 *
 * This module provides a standardized interface for communicating with the Julia backend,
 * with improved error handling, connection status monitoring, and consistent command formatting.
 */

const EventEmitter = require('events');
const chalk = require('chalk');
const ora = require('ora');

const { createConfig } = require('./utils/config');
const { Logger, LOG_LEVELS } = require('./utils/logger');
const { initializeMockRegistry } = require('./mocks');
const { initializeImplementationRegistry } = require('./implementations');
const {
  JuliaBridgeError,
  ConnectionError,
  CommandError,
  InitializationError,
  BackendError,
  MockImplementationError
} = require('./errors/bridge-errors');

class EnhancedJuliaBridge extends EventEmitter {
  /**
   * Create a new EnhancedJuliaBridge instance
   * @param {Object} juliaBridge - The underlying JuliaBridge instance
   * @param {Object} options - Configuration options
   */
  constructor(juliaBridge, options = {}) {
    super();

    // Initialize configuration
    this.config = createConfig(options);

    // Initialize logger
    this.logger = new Logger({
      level: this.config.logging.level,
      prefix: this.config.logging.prefix,
      enableColors: this.config.logging.enableColors,
      timestamps: this.config.logging.timestamps
    });

    // Store the underlying JuliaBridge
    this.juliaBridge = juliaBridge;

    // Initialize state
    this.isConnected = false;
    this.isConnecting = false; // Flag to prevent concurrent connection checks
    this.lastConnectionCheck = 0;
    this.initialized = false;
    this.backendCapabilities = {};
    this.backendCapabilitiesChecked = false;

    // Initialize command mappings
    this.commandMappings = this._initializeCommandMappings();

    // Initialize implementation registry with real implementations
    this.implementationRegistry = initializeImplementationRegistry(this.logger, this.juliaBridge);

    // Initialize mock registry for fallbacks
    this.mockRegistry = initializeMockRegistry(this.logger, this.config);

    // Initialize the bridge
    this._initialize();
  }

  /**
   * Initialize the bridge
   */
  async _initialize() {
    try {
      this.logger.info('Initializing EnhancedJuliaBridge');

      // Initialize the underlying JuliaBridge
      await this.juliaBridge.initialize();
      this.initialized = true;
      this.logger.success('EnhancedJuliaBridge initialized successfully');
      this.emit('initialized');

      // Check connection
      await this.checkConnection();
    } catch (error) {
      this.logger.error('Error initializing EnhancedJuliaBridge:', error.message);
      this.emit('initialization_error', error);

      // Even if initialization fails, we'll set initialized to true
      // so that we can fall back to mock implementations
      this.initialized = true;

      throw new InitializationError(`Failed to initialize EnhancedJuliaBridge: ${error.message}`, {
        originalError: error
      });
    }
  }

  /**
   * Initialize command mappings to ensure consistent format
   */
  _initializeCommandMappings() {
    return {
      // Agent commands - updated for enhanced Agents.jl
      'create_agent': 'agents.create_agent',
      'update_agent': 'agents.update_agent',
      'delete_agent': 'agents.delete_agent',
      'get_agent': 'agents.get_agent',
      'list_agents': 'agents.list_agents',
      'start_agent': 'agents.start_agent',
      'stop_agent': 'agents.stop_agent',
      'pause_agent': 'agents.pause_agent',
      'resume_agent': 'agents.resume_agent',
      'get_agent_status': 'agents.get_status',
      'execute_agent_task': 'agents.execute_task',
      'get_agent_memory': 'agents.get_memory',
      'set_agent_memory': 'agents.set_memory',
      'clear_agent_memory': 'agents.clear_memory',
      'register_ability': 'agents.register_ability',
      'register_skill': 'agents.register_skill',

      // Agent metrics commands
      'get_agent_metrics': 'agents.get_metrics',
      'record_agent_metric': 'agents.record_metric',
      'reset_agent_metrics': 'agents.reset_metrics',

      // Agent monitoring commands
      'get_agent_health': 'agents.get_health_status',
      'start_agent_monitor': 'agents.start_monitor',
      'stop_agent_monitor': 'agents.stop_monitor',

      // Swarm commands
      'connect_swarm': 'agents.connect_swarm',
      'disconnect_swarm': 'agents.disconnect_swarm',
      'publish_to_swarm': 'agents.publish_to_swarm',
      'subscribe_to_swarm': 'agents.subscribe_swarm',

      // Swarm commands
      'create_swarm': 'swarms.create_swarm',
      'update_swarm': 'swarms.update_swarm',
      'delete_swarm': 'swarms.delete_swarm',
      'get_swarm': 'swarms.get_swarm',
      'list_swarms': 'swarms.list_swarms',
      'start_swarm': 'swarms.update_swarm', // with status=active
      'stop_swarm': 'swarms.update_swarm',  // with status=inactive
      'create_openai_swarm': 'swarms.create_openai_swarm',
      'run_openai_task': 'swarms.run_openai_task',
      'get_openai_response': 'swarms.get_openai_response',

      // Trading commands
      'execute_trade': 'Bridge.execute_trade',
      'submit_signed_transaction': 'Bridge.submit_signed_transaction',
      'get_transaction_status': 'Bridge.get_transaction_status',

      // Bridge commands
      'bridge_tokens_wormhole': 'WormholeBridge.bridge_tokens_wormhole',
      'check_bridge_status_wormhole': 'WormholeBridge.check_bridge_status_wormhole',
      'redeem_tokens_wormhole': 'WormholeBridge.redeem_tokens_wormhole',
      'get_wrapped_asset_info_wormhole': 'WormholeBridge.get_wrapped_asset_info_wormhole',
      'get_available_chains': 'WormholeBridge.get_available_chains',
      'get_available_tokens': 'WormholeBridge.get_available_tokens',

      // System commands
      'check_system_health': 'system.health',

      // Metrics commands
      'get_system_overview': 'metrics.get_system_overview',
      'get_realtime_metrics': 'metrics.get_realtime_metrics',
      'get_resource_usage': 'metrics.get_resource_usage',
      'run_performance_test': 'metrics.run_performance_test',

      // Task queue commands
      'enqueue_task': 'tasks.enqueue',
      'get_task_status': 'tasks.get_status',
      'cancel_task': 'tasks.cancel',
      'list_tasks': 'tasks.list',
      'get_task_result': 'tasks.get_result',

      // Error tracking commands
      'get_error_stats': 'errors.get_stats',
      'reset_error_stats': 'errors.reset_stats',
      'create_circuit_breaker': 'errors.create_circuit_breaker',
      'get_circuit_breaker_state': 'errors.get_circuit_breaker_state',
      'open_circuit': 'errors.open_circuit',
      'close_circuit': 'errors.close_circuit',
      'half_open_circuit': 'errors.half_open_circuit',

      // Connection pool commands
      'get_pool_stats': 'connections.get_stats',
      'get_connection': 'connections.get_connection',
      'release_connection': 'connections.release_connection',
      'close_connection': 'connections.close_connection',
      'clear_idle_connections': 'connections.clear_idle',

      // Cache commands
      'get_cache_stats': 'cache.get_stats',
      'get_cached': 'cache.get',
      'set_cached': 'cache.set',
      'invalidate_cache': 'cache.invalidate',
      'clear_cache': 'cache.clear',
      'configure_cache': 'cache.configure',

      // Algorithm commands
      'list_algorithms': 'algorithms.list',
      'get_algorithm_details': 'algorithms.get_details',
      'run_algorithm': 'algorithms.run',

      // Neural network commands
      'create_neural_network': 'neural_networks.create',
      'train_neural_network': 'neural_networks.train',
      'predict_neural_network': 'neural_networks.predict',

      // Portfolio optimization commands
      'optimize_portfolio': 'portfolio.optimize',
      'get_portfolio_metrics': 'portfolio.get_metrics',

      // API key commands
      'set_api_key': 'apikeys.set',
      'get_api_keys': 'apikeys.list',
      'delete_api_key': 'apikeys.delete',

      // System configuration commands
      'get_system_config': 'system.get_config',
      'update_system_config': 'system.update_config',

      // DEX commands
      'get_dex_list': 'dex.list',
      'get_dex_pairs': 'dex.get_pairs',
      'get_dex_liquidity': 'dex.get_liquidity',

      // Wallet commands
      'list_wallets': 'wallets.list',
      'create_wallet': 'wallets.create',
      'import_wallet': 'wallets.import',
      'get_wallet_balance': 'wallets.get_balance',
      'send_transaction': 'wallets.send_transaction'
    };
  }

  /**
   * Checks the connection status to the Julia backend using multiple strategies.
   * Emits 'connected' or 'disconnected' events on status change.
   * @param {boolean} [force=false] - Force check even if within interval.
   * @returns {Promise<boolean>} - Current connection status.
   */
  async checkConnection(force = false) {
    const now = Date.now();
    if (!force && now - this.lastConnectionCheck < this.config.connection.checkInterval && this.isConnected) {
      return this.isConnected; // Return cached status if within interval and connected
    }

    // Prevent concurrent connection checks
    if (this.isConnecting) {
      this.logger.debug('Connection check already in progress.');
      // Wait briefly for ongoing check to potentially finish, or return current known status
      await new Promise(resolve => setTimeout(resolve, 100));
      return this.isConnected;
    }

    this.isConnecting = true;
    this.lastConnectionCheck = now;
    const previousStatus = this.isConnected;
    this.logger.info('Performing connection check...');

    let currentStatus = false;
    try {
      // Strategy 1: Primary health endpoint method
      currentStatus = await this._tryHealthEndpoint();

      // Strategy 2: system.health command (if Strategy 1 failed)
      if (!currentStatus) {
        currentStatus = await this._trySystemHealthCommand();
      }

      // Strategy 3: Direct fetch (if Strategy 1 & 2 failed)
      if (!currentStatus) {
        currentStatus = await this._tryDirectFetch();
      }

      this.isConnected = currentStatus;

      if (this.isConnected) {
        this.logger.info(chalk.green('Connection check PASSED. Backend is healthy.'));
        // Check capabilities only once after connecting
        if (!this.backendCapabilitiesChecked) {
          await this._checkBackendCapabilities();
        }
      } else {
        this.logger.warn(chalk.yellow('Connection check FAILED. Backend is unreachable or unhealthy.'));
      }

      // Emit events only if status changed
      if (previousStatus !== this.isConnected) {
        this.emit(this.isConnected ? 'connected' : 'disconnected');
        this.logger.info(`Connection status changed to: ${this.isConnected ? 'Connected' : 'Disconnected'}`);
      }

    } catch (error) {
      // Catch unexpected errors during the checking process itself
      this.logger.error(`Unexpected error during connection check: ${error.message}`, { error });
      this.isConnected = false;
      if (previousStatus !== this.isConnected) {
        this.emit('disconnected');
        this.logger.info(`Connection status changed to: Disconnected due to error.`);
      }
    } finally {
      this.isConnecting = false;
    }

    return this.isConnected;
  }

  /**
   * Tries the primary health endpoint of the underlying bridge.
   * @returns {Promise<boolean>} - True if healthy, false otherwise.
   * @private
   */
  async _tryHealthEndpoint() {
    if (typeof this.juliaBridge.getHealth !== 'function') {
      this.logger.debug('Underlying bridge does not have a getHealth method.');
      return false;
    }
    try {
      this.logger.debug(chalk.blue('Checking health endpoint via getHealth()...'));
      const healthResult = await this.juliaBridge.getHealth();
      this.logger.debug(chalk.blue(`Health check result: ${JSON.stringify(healthResult)}`));

      if (healthResult && typeof healthResult === 'object') {
        // Handle potential stringified JSON within the object
        if (typeof healthResult === 'string') {
          try {
            const parsedHealth = JSON.parse(healthResult);
            return parsedHealth && parsedHealth.status === 'healthy';
          } catch (parseError) {
            this.logger.warn(chalk.yellow('Health check result was a string, but failed to parse as JSON.'));
            return healthResult.includes('healthy'); // Best effort guess
          }
        } else {
          // Assume standard object response
          return healthResult.status === 'healthy';
        }
      } else if (typeof healthResult === 'string') {
        // Handle direct string response (less ideal)
        try {
          const parsedHealth = JSON.parse(healthResult);
          return parsedHealth && parsedHealth.status === 'healthy';
        } catch (parseError) {
          this.logger.debug(chalk.blue('Health check result was a non-JSON string. Checking content...'));
          return healthResult.includes('healthy'); // Best effort guess
        }
      } else {
        this.logger.warn(chalk.yellow('Health check failed: Invalid response format from getHealth()'));
        return false;
      }
    } catch (healthError) {
      this.logger.warn(chalk.yellow(`Health check via getHealth() failed: ${healthError.message}`));
      return false;
    }
  }

  /**
   * Tries the system.health command via runJuliaCommand.
   * @returns {Promise<boolean>} - True if healthy, false otherwise.
   * @private
   */
  async _trySystemHealthCommand() {
    if (typeof this.juliaBridge.runJuliaCommand !== 'function') {
      this.logger.debug('Underlying bridge does not have a runJuliaCommand method.');
      return false;
    }
    try {
      this.logger.debug(chalk.blue('Trying system.health command...'));
      // Use direct command to avoid loops
      const systemHealth = await this.juliaBridge.runJuliaCommand('system.health', {});

      // Check if the command itself succeeded AND the result indicates health
      const isHealthy = systemHealth && (systemHealth.success === true || systemHealth.status === 'healthy');
      this.logger.debug(`System health command result: ${JSON.stringify(systemHealth)}, Healthy: ${isHealthy}`);
      return isHealthy;
    } catch (cmdError) {
      // Catch errors from executeCommand itself
      this.logger.warn(chalk.yellow(`System health command failed: ${cmdError.message}`));
      return false;
    }
  }

  /**
   * Tries a direct fetch to the health endpoint URL.
   * @returns {Promise<boolean>} - True if healthy, false otherwise.
   * @private
   */
  async _tryDirectFetch() {
    const apiUrl = this.config.connection?.apiUrl || this.juliaBridge.config?.apiUrl;
    if (!apiUrl) {
      this.logger.warn(chalk.yellow('No API URL configured for direct health check.'));
      return false;
    }

    try {
      const apiUrlObj = new URL(apiUrl);
      const host = apiUrlObj.hostname;
      // Use configured health check port, fallback to API port if needed
      const port = this.config.connection.fallbackPort || apiUrlObj.port;
      const protocol = apiUrlObj.protocol === 'https:' ? 'https' : 'http'; // Respect protocol
      const healthUrl = `${protocol}://${host}:${port}${this.config.connection.healthEndpoint}`;

      this.logger.debug(chalk.blue(`Trying direct fetch to health endpoint: ${healthUrl}`));
      // Use dynamic import for fetch to support environments where it's not global
      const response = await fetch(healthUrl, { timeout: 5000 }); // Add timeout

      if (response.ok) {
        const healthData = await response.json();
        this.logger.debug(chalk.blue(`Direct health check response: ${JSON.stringify(healthData)}`));
        return healthData && healthData.status === 'healthy';
      } else {
        this.logger.warn(chalk.yellow(`Direct health check failed: ${response.status} ${response.statusText}`));
        return false;
      }
    } catch (fetchError) {
      this.logger.warn(chalk.yellow(`Direct health check error: ${fetchError.message}`));
      return false;
    }
  }

  /**
   * Check what capabilities the backend supports
   */
  async _checkBackendCapabilities() {
    try {
      // Try to get system overview which should contain capability information
      this.logger.debug('Checking backend capabilities');
      const systemOverview = await this.executeCommand('get_system_overview', {});

      if (systemOverview && systemOverview.modules) {
        this.backendCapabilities = systemOverview.modules;
        this.logger.debug(`Backend capabilities: ${JSON.stringify(this.backendCapabilities)}`);
      }

      this.backendCapabilitiesChecked = true;
    } catch (error) {
      // If this fails, we'll just continue without capabilities information
      this.logger.warn('Could not determine backend capabilities');
    }
  }

  /**
   * Check if a specific capability is supported by the backend
   * @param {string} capability - Capability name
   * @returns {boolean} - Whether the capability is supported
   */
  hasCapability(capability) {
    return this.backendCapabilities[capability] === true;
  }

  /**
   * Get a formatted connection status string
   * @returns {string} - Formatted connection status string
   */
  getConnectionStatusString() {
    if (this.isConnected) {
      return chalk.green('Connected to Julia backend ✅');
    } else {
      return chalk.yellow('Not connected to Julia backend ⚠️ (using mock implementations)');
    }
  }

  /**
   * Prepare command and parameters for execution
   * @param {string} command - Command name
   * @param {Object} params - Command parameters
   * @returns {Object} - Prepared command and parameters
   */
  _prepareCommand(command, params) {
    // Map the command to the standardized format
    const mappedCommand = this.commandMappings[command] || command;

    // Clone params to avoid modifying the original
    let formattedParams = { ...params };

    // Special handling for agent creation
    if (command === 'create_agent' || mappedCommand === 'agents.create_agent') {
      formattedParams = this._formatAgentParams(formattedParams);
    }

    return { mappedCommand, formattedParams };
  }

  /**
   * Format agent parameters for create_agent command
   * @param {Object|Array} params - Agent parameters
   * @returns {Object} - Formatted agent parameters
   */
  _formatAgentParams(params) {
    this.logger.debug('Formatting parameters for create_agent:', params);

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
      this.logger.debug('Detected array format for create_agent params.');
    } else if (typeof params === 'object' && params !== null && params.name && params.type) {
      name = params.name;
      agentTypeInput = params.type;
      // Config can be directly within params or nested under 'config'
      configInput = params.config || params;
      this.logger.debug('Detected object format for create_agent params.');
    } else {
      throw new JuliaBridgeError('Invalid parameters for create_agent. Expected [name, type, config?] or {name, type, ...config}.', { params });
    }

    let config = {};
    // Parse config if it's a string (from array format)
    if (typeof configInput === 'string') {
      try {
        config = JSON.parse(configInput);
      } catch (e) {
        this.logger.warn(`Could not parse config string for agent "${name}": ${configInput}`);
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
          // Add any other expected parameters with defaults
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
        // Add other config sections if needed
      }
    };

    // Pass through id if specified in the original config/params
    if (config.id || params?.id) {
      formattedParams.id = config.id || params.id;
      this.logger.debug(`Using provided ID for agent creation: ${formattedParams.id}`);
    }

    this.logger.debug(`Formatted parameters for ${this.commandMappings['create_agent']}: ${JSON.stringify(formattedParams)}`);
    return formattedParams;
  }

  // Note: The _ensureConnection method has been removed as its functionality
  // is now integrated directly into the executeCommand method for better error handling
  // and more consistent behavior.

  // Note: The _executeWithRetries method has been removed as its functionality
  // is now integrated directly into the executeCommand method for better error handling
  // and more consistent behavior.

  /**
   * Execute a command against the Julia backend with retry logic and mock fallback.
   * Emits 'commandSuccess' or 'commandError' events.
   *
   * @param {string} command - The high-level command name (e.g., 'list_agents').
   * @param {object|array} params - Parameters for the command.
   * @param {object} [options={}] - Execution options.
   * @param {boolean} [options.showSpinner=true] - Show CLI spinner.
   * @param {string} [options.spinnerText] - Custom spinner text.
   * @param {boolean} [options.fallbackToMock=true] - Use mock implementation if backend fails or is disconnected.
   * @param {boolean} [options.useMockOnly=false] - Force use of mock implementation.
   * @param {number} [options.maxRetries] - Override default max retries.
   * @param {number} [options.retryDelay] - Override default retry delay.
   * @returns {Promise<any>} - The result from the Julia backend or mock.
   * @throws {JuliaBridgeError|ConnectionError|BackendError|MockImplementationError}
   */
  async executeCommand(command, params, options = {}) {
    // Merge options with defaults
    const execOptions = {
      showSpinner: options.showSpinner !== false && this.config.ui.showSpinners,
      spinnerText: options.spinnerText || `Executing ${command}...`,
      fallbackToMock: options.fallbackToMock !== false && this.config.commands.fallbackToMock,
      maxRetries: options.maxRetries || this.config.commands.maxRetries,
      retryDelay: options.retryDelay || this.config.commands.retryDelay,
      useMockOnly: options.useMockOnly || false,
      originalCommand: command
    };

    // Prepare command and parameters
    const { mappedCommand, formattedParams } = this._prepareCommand(command, params);

    // Create spinner if needed
    let spinner = null;
    if (execOptions.showSpinner) {
      spinner = ora({
        text: execOptions.spinnerText,
        color: this.config.ui.spinnerColor
      }).start();
      execOptions.spinner = spinner;
    }

    const stopSpinner = (method, text) => {
      if (spinner) {
        spinner[method](text);
      }
    };

    // Emit command start event
    this.emit('command_start', { command, params });

    try {
      // --- Mock Only Execution ---
      if (execOptions.useMockOnly) {
        stopSpinner('info', `Using mock implementation for ${command} (forced)`);
        try {
          const mockResult = await this.mockRegistry.execute(command, formattedParams);
          this.emit('command_success', { command, params, result: mockResult, source: 'mock' });
          return mockResult;
        } catch (mockError) {
          stopSpinner('fail', `Mock implementation error for ${command}: ${mockError.message}`);
          this.emit('command_error', { command, params, error: mockError, source: 'mock' });
          throw mockError; // Re-throw mock error
        }
      }

      // --- Use Real Implementation If Available ---
      if (this.implementationRegistry.has(command) && !execOptions.useMockOnly) {
        try {
          stopSpinner('info', `Using real implementation for ${command}`);
          const result = await this.implementationRegistry.execute(command, formattedParams);
          stopSpinner('succeed', `${command} executed successfully.`);
          this.emit('command_success', { command, params, result, source: 'implementation' });
          return result;
        } catch (error) {
          // If real implementation fails and not connected, continue to connection check
          // Otherwise, handle the error based on fallback settings
          if (this.isConnected || error instanceof BackendError) {
            if (execOptions.fallbackToMock) {
              this.logger.warn(`Real implementation failed for ${command}, falling back to mock.`);
              stopSpinner('warn', `Real implementation failed, using mock fallback.`);
              try {
                const mockResult = await this.mockRegistry.execute(command, formattedParams);
                this.emit('command_success', { command, params, result: mockResult, source: 'mock-fallback' });
                return mockResult;
              } catch (mockError) {
                stopSpinner('fail', `Mock fallback also failed for ${command}: ${mockError.message}`);
                this.emit('command_error', { command, params, error: mockError, source: 'mock-fallback' });
                throw mockError;
              }
            } else {
              // No fallback, re-throw the error
              stopSpinner('fail', `Error executing ${command}: ${error.message}`);
              this.emit('command_error', { command, params, error, source: 'implementation' });
              throw error;
            }
          }
          // If not connected, continue to connection check below
          this.logger.warn(`Implementation failed, checking connection: ${error.message}`);
        }
      }

      // --- Check Connection (unless using mock only) ---
      if (!this.isConnected) {
        const connected = await this.checkConnection(); // Attempt connection if not already connected
        if (!connected) {
          if (execOptions.fallbackToMock) {
            stopSpinner('warn', `Backend not connected for ${command}, using mock fallback.`);
            this.logger.warn(`Backend not connected. Using mock fallback for: ${command}`);
            try {
              const mockResult = await this.mockRegistry.execute(command, formattedParams);
              this.emit('command_success', { command, params, result: mockResult, source: 'mock' });
              return mockResult;
            } catch (mockError) {
              stopSpinner('fail', `Mock fallback error for ${command}: ${mockError.message}`);
              this.emit('command_error', { command, params, error: mockError, source: 'mock' });
              throw mockError;
            }
          } else {
            stopSpinner('fail', `Backend not connected for ${command}, fallback disabled.`);
            const connError = new ConnectionError(`Backend not connected. Cannot execute command: ${command}`);
            this.emit('command_error', { command, params, error: connError, source: 'connection' });
            throw connError;
          }
        }
        // If checkConnection succeeded, continue to normal execution
        stopSpinner('info', `Connection established, executing ${command}...`); // Update spinner if needed
      }

      // --- Execute with Retries ---
      let lastError = null;
      for (let attempt = 0; attempt <= execOptions.maxRetries; attempt++) {
        try {
          if (attempt > 0) {
            stopSpinner('info', `Retrying ${command} (attempt ${attempt}/${execOptions.maxRetries})...`);
            await new Promise(resolve => setTimeout(resolve, execOptions.retryDelay * attempt));
          }

          this.logger.debug(`Executing command: ${mappedCommand} (Attempt ${attempt + 1})`, { params: formattedParams });
          // Actual call to the underlying bridge
          const result = await this.juliaBridge.runJuliaCommand(mappedCommand, formattedParams);
          this.logger.debug(`Raw result from ${mappedCommand}:`, { result });

          // --- Process Result ---
          // Check for explicit backend error structure ({ success: false, error: '...' })
          if (result && result.success === false && result.error) {
            throw new BackendError(result.error, { command, mappedCommand, params: formattedParams, backendResponse: result });
          }
          // Check for other potential implicit error formats
          if (result && result.error && !result.success) {
            throw new BackendError(result.error.message || result.error, { command, mappedCommand, params: formattedParams, backendResponse: result });
          }

          // Handle non-response or null result (might indicate an issue)
          if (result === null || typeof result === 'undefined') {
            this.logger.warn(`Received null or undefined response from ${mappedCommand}.`);
            // Let's consider it a retryable issue for now
            throw new JuliaBridgeError(`Null or undefined response received from ${mappedCommand}`, { command, mappedCommand, params: formattedParams });
          }

          // Successful execution
          stopSpinner('succeed', `${command} executed successfully.`);
          // Extract data if structure is { success: true, data: ... }
          const finalResult = (result && result.success === true && typeof result.data !== 'undefined') ? result.data : result;
          this.emit('command_success', { command, params: formattedParams, result: finalResult, source: 'backend' });
          return finalResult;

        } catch (error) {
          lastError = error; // Store error for potential re-throw or fallback
          this.logger.warn(`Attempt ${attempt + 1} for ${command} failed: ${error.message}`);

          // If it's a backend error, log more details
          if (error instanceof BackendError) {
            this.logger.error(`Backend error executing ${command}: ${error.message}`, error.details);
            // Backend errors are still retryable in this implementation
          }

          // If max retries reached, break loop and handle below
          if (attempt >= execOptions.maxRetries) {
            this.logger.error(`Command ${command} failed after ${execOptions.maxRetries + 1} attempts.`);
            break; // Exit retry loop
          }
          // Update spinner text for retry
          stopSpinner('info', `Retrying ${command} (${attempt + 1}/${execOptions.maxRetries}): ${error.message}`);
        }
      } // End retry loop

      // --- Handle Failure After Retries ---
      if (lastError) {
        stopSpinner('fail', `Error executing ${command} after retries: ${lastError.message}`);
        this.logger.error(`Failed to execute ${command} after ${execOptions.maxRetries} retries. Last error: ${lastError.message}`);

        if (execOptions.fallbackToMock) {
          this.logger.warn(`Falling back to mock implementation for ${command} after failed backend attempts.`);
          stopSpinner('info', `Falling back to mock for ${command}...`); // Update spinner
          try {
            const mockResult = await this.mockRegistry.execute(command, formattedParams);
            this.emit('command_success', { command, params, result: mockResult, source: 'mock-fallback' });
            stopSpinner('warn', `Used mock fallback for ${command}.`); // Indicate mock was used
            return mockResult;
          } catch (mockError) {
            // If mock fails too, throw the mock error
            stopSpinner('fail', `Mock fallback also failed for ${command}: ${mockError.message}`);
            this.emit('command_error', { command, params, error: mockError, source: 'mock-fallback' });
            throw mockError;
          }
        } else {
          // No fallback, emit and throw the last error from backend interaction
          this.emit('command_error', { command, params: formattedParams, error: lastError, source: 'backend' });
          throw lastError;
        }
      } else {
        // Should not happen if loop finishes, but handle defensively
        const unknownError = new JuliaBridgeError(`Command ${command} failed with no specific error after retries.`);
        stopSpinner('fail', `Command ${command} failed with no specific error.`);
        this.emit('command_error', { command, params: formattedParams, error: unknownError, source: 'unknown' });
        throw unknownError;
      }

    } catch (error) {
      // Catch errors thrown outside the retry loop (e.g., initial connection errors, mock errors)
      // Ensure the error is one of our custom types if possible
      const finalError = error instanceof JuliaBridgeError ? error : new JuliaBridgeError(`Unhandled error during executeCommand: ${error.message}`, { originalError: error });

      this.logger.error(`Critical error executing ${command}: ${finalError.message}`, finalError.details);
      stopSpinner('fail', `Critical error: ${finalError.message}`);
      // Avoid emitting duplicate errors if already emitted
      if (!this.eventNames().includes('command_error') || !finalError.details?.emitted) {
        finalError.details = { ...finalError.details, emitted: true };
        this.emit('command_error', { command, params, error: finalError, source: 'critical' });
      }
      throw finalError;
    }
  }
  /**
   * Gracefully shuts down the bridge connection if applicable.
   * @returns {Promise<void>}
   */
  async shutdown() {
    this.logger.info('Shutting down EnhancedJuliaBridge...');
    this.removeAllListeners(); // Remove event listeners

    if (this.isConnected && typeof this.juliaBridge.disconnect === 'function') {
      try {
        await this.juliaBridge.disconnect();
        this.logger.info('Underlying JuliaBridge disconnected.');
      } catch (error) {
        this.logger.error(`Error disconnecting underlying JuliaBridge: ${error.message}`);
      }
    }

    this.isConnected = false;
    this.isConnecting = false;
    this.logger.info('EnhancedJuliaBridge shutdown complete.');
  }
}

module.exports = EnhancedJuliaBridge;
