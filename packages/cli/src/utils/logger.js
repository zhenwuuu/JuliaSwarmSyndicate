/**
 * Enhanced logger utility for EnhancedJuliaBridge
 *
 * Supports both direct usage and wrapping an existing logger
 */

const chalk = require('chalk');

// Log levels
const LOG_LEVELS = {
  DEBUG: 0,
  INFO: 1,
  WARN: 2,
  ERROR: 3,
  NONE: 4
};

class Logger {
  /**
   * Create a new Logger instance
   * @param {Object} options - Logger options
   * @param {number|string} options.level - Log level (DEBUG, INFO, WARN, ERROR, NONE)
   * @param {string} options.prefix - Prefix for log messages
   * @param {boolean} options.enableColors - Whether to enable colored output
   * @param {boolean} options.timestamps - Whether to include timestamps
   * @param {Function} options.outputFn - Function to use for output (default: console.log)
   * @param {Function} options.errorFn - Function to use for errors (default: console.error)
   * @param {Object} options.existingLogger - Existing logger to wrap (must implement log, info, warn, error, debug)
   */
  constructor(options = {}) {
    // If an existing logger is provided, wrap it
    this.existingLogger = options.existingLogger;

    // Set up logger properties
    this.level = this._parseLevel(options.level || LOG_LEVELS.INFO);
    this.prefix = options.prefix || 'JuliaBridge';
    this.enableColors = options.enableColors !== false;
    this.timestamps = options.timestamps !== false;
    this.outputFn = options.outputFn || console.log;
    this.errorFn = options.errorFn || console.error;
  }

  /**
   * Parse a level string or number into a level number
   * @param {string|number} level - Level to parse
   * @returns {number} - Parsed level
   * @private
   */
  _parseLevel(level) {
    if (typeof level === 'string') {
      return LOG_LEVELS[level.toUpperCase()] || LOG_LEVELS.INFO;
    }
    return level;
  }

  /**
   * Set the log level
   * @param {string|number} level - New log level
   */
  setLevel(level) {
    this.level = this._parseLevel(level);
  }

  /**
   * Format a message with timestamp and prefix
   * @param {string} message - Message to format
   * @returns {string} - Formatted message
   * @private
   */
  _formatMessage(message) {
    let formattedMessage = '';

    if (this.timestamps) {
      formattedMessage += `[${new Date().toISOString()}] `;
    }

    formattedMessage += `[${this.prefix}] ${message}`;
    return formattedMessage;
  }

  /**
   * Log a debug message
   * @param {string} message - Message to log
   * @param {...any} args - Additional arguments
   */
  debug(message, ...args) {
    // If using an existing logger, delegate to it
    if (this.existingLogger && typeof this.existingLogger.debug === 'function') {
      this.existingLogger.debug(message, ...args);
      return;
    }

    if (this.level <= LOG_LEVELS.DEBUG) {
      const formattedMessage = this._formatMessage(message);
      this.outputFn(
        this.enableColors ? chalk.gray(formattedMessage) : formattedMessage,
        ...args
      );
    }
  }

  /**
   * Log an info message
   * @param {string} message - Message to log
   * @param {...any} args - Additional arguments
   */
  info(message, ...args) {
    // If using an existing logger, delegate to it
    if (this.existingLogger && typeof this.existingLogger.info === 'function') {
      this.existingLogger.info(message, ...args);
      return;
    }

    if (this.level <= LOG_LEVELS.INFO) {
      const formattedMessage = this._formatMessage(message);
      this.outputFn(
        this.enableColors ? chalk.blue(formattedMessage) : formattedMessage,
        ...args
      );
    }
  }

  /**
   * Log a warning message
   * @param {string} message - Message to log
   * @param {...any} args - Additional arguments
   */
  warn(message, ...args) {
    // If using an existing logger, delegate to it
    if (this.existingLogger && typeof this.existingLogger.warn === 'function') {
      this.existingLogger.warn(message, ...args);
      return;
    }

    if (this.level <= LOG_LEVELS.WARN) {
      const formattedMessage = this._formatMessage(message);
      this.outputFn(
        this.enableColors ? chalk.yellow(formattedMessage) : formattedMessage,
        ...args
      );
    }
  }

  /**
   * Log an error message
   * @param {string} message - Message to log
   * @param {...any} args - Additional arguments
   */
  error(message, ...args) {
    // If using an existing logger, delegate to it
    if (this.existingLogger && typeof this.existingLogger.error === 'function') {
      this.existingLogger.error(message, ...args);
      return;
    }

    if (this.level <= LOG_LEVELS.ERROR) {
      const formattedMessage = this._formatMessage(message);
      this.errorFn(
        this.enableColors ? chalk.red(formattedMessage) : formattedMessage,
        ...args
      );
    }
  }

  /**
   * Log a success message
   * @param {string} message - Message to log
   * @param {...any} args - Additional arguments
   */
  success(message, ...args) {
    // If using an existing logger, delegate to it
    if (this.existingLogger && typeof this.existingLogger.success === 'function') {
      this.existingLogger.success(message, ...args);
      return;
    } else if (this.existingLogger && typeof this.existingLogger.info === 'function') {
      // Fall back to info if success is not available
      this.existingLogger.info(`✅ ${message}`, ...args);
      return;
    }

    if (this.level <= LOG_LEVELS.INFO) {
      const formattedMessage = this._formatMessage(message);
      this.outputFn(
        this.enableColors ? chalk.green(formattedMessage) : formattedMessage,
        ...args
      );
    }
  }

  /**
   * Log a message (compatibility with console.log)
   * @param {string} message - Message to log
   * @param {...any} args - Additional arguments
   */
  log(message, ...args) {
    // If using an existing logger, delegate to it
    if (this.existingLogger && typeof this.existingLogger.log === 'function') {
      this.existingLogger.log(message, ...args);
      return;
    }

    // Default to info level
    this.info(message, ...args);
  }
}

module.exports = {
  Logger,
  LOG_LEVELS
};
