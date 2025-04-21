/**
 * Error utilities for JuliaOS CLI
 * 
 * This module provides standardized error formatting, handling, and recovery suggestions
 * for the JuliaOS command-line interface.
 */

const chalk = require('chalk');
const boxen = require('boxen');
const { EOL } = require('os');

// Error categories with matching colors and icons
const ERROR_CATEGORIES = {
  VALIDATION: {
    color: 'yellow',
    icon: '⚠️',
    title: 'VALIDATION ERROR'
  },
  CONNECTION: {
    color: 'red',
    icon: '🔌',
    title: 'CONNECTION ERROR'
  },
  BACKEND: {
    color: 'magenta',
    icon: '🔧',
    title: 'BACKEND ERROR'
  },
  BLOCKCHAIN: {
    color: 'cyan',
    icon: '⛓️',
    title: 'BLOCKCHAIN ERROR'
  },
  WALLET: {
    color: 'blue',
    icon: '👛',
    title: 'WALLET ERROR'
  },
  PERMISSION: {
    color: 'red',
    icon: '🔒',
    title: 'PERMISSION ERROR'
  },
  CONFIG: {
    color: 'yellow',
    icon: '⚙️',
    title: 'CONFIGURATION ERROR'
  },
  GENERIC: {
    color: 'red',
    icon: '❌',
    title: 'ERROR'
  }
};

// Common recovery suggestions by error type
const RECOVERY_SUGGESTIONS = {
  // Connection errors
  'ECONNREFUSED': [
    'Ensure the JuliaOS server is running with: julia run_server.jl',
    'Check the server address in your .env file',
    'Make sure your network connection is active'
  ],
  'TIMEOUT': [
    'The server is taking too long to respond',
    'Check if the server is under heavy load',
    'Try restarting the Julia server'
  ],
  
  // Backend errors
  'JULIA_ERROR': [
    'An error occurred in the Julia backend',
    'Check the Julia server logs for more details',
    'Try restarting the Julia server'
  ],
  
  // Blockchain errors
  'GAS_ESTIMATION': [
    'Transaction gas estimation failed',
    'Check your wallet has sufficient funds for gas',
    'The transaction may be invalid or the network congested'
  ],
  'RPC_ERROR': [
    'Blockchain RPC connection error',
    'Check your RPC endpoint configuration',
    'The blockchain node may be down or unreachable'
  ],
  
  // Wallet errors
  'INSUFFICIENT_FUNDS': [
    'Your wallet has insufficient funds for this operation',
    'Fund your wallet with the required tokens',
    'Check if you have enough for both the transaction and gas fees'
  ],
  'WALLET_NOT_CONNECTED': [
    'No wallet is currently connected',
    'Use the wallet menu to connect a wallet',
    'Check your private key or mnemonic if using direct connection'
  ],
  
  // Permission errors
  'ACCESS_DENIED': [
    'You do not have permission to perform this action',
    'Check your authentication credentials',
    'Contact the administrator if you need access'
  ],
  
  // Config errors
  'MISSING_CONFIG': [
    'Configuration file is missing or invalid',
    'Ensure your .env file is set up correctly',
    'Run setup wizard with: npm run setup'
  ],
  
  // Generic fallback
  'GENERIC': [
    'Try restarting the CLI application',
    'Check the logs for more details',
    'Run with --debug flag for verbose logging'
  ]
};

/**
 * Format an error message with standardized styling
 * 
 * @param {string} message - The main error message
 * @param {string} category - Error category from ERROR_CATEGORIES
 * @param {string} code - Specific error code
 * @param {Object} details - Additional error details
 * @param {string[]} [suggestions] - Custom recovery suggestions
 * @returns {string} Formatted error message
 */
function formatError(message, category = 'GENERIC', code = 'GENERIC', details = {}, suggestions = []) {
  const errorCategory = ERROR_CATEGORIES[category] || ERROR_CATEGORIES.GENERIC;
  const color = errorCategory.color;
  const icon = errorCategory.icon;
  const title = errorCategory.title;
  
  // Get recovery suggestions (custom or from predefined list)
  const recoverySuggestions = suggestions.length > 0 
    ? suggestions 
    : (RECOVERY_SUGGESTIONS[code] || RECOVERY_SUGGESTIONS.GENERIC);
  
  // Format details if present
  let detailsText = '';
  if (Object.keys(details).length > 0) {
    detailsText = EOL + EOL + chalk.bold('Details:') + EOL + 
      Object.entries(details)
        .map(([key, value]) => `  ${chalk.bold(key)}: ${value}`)
        .join(EOL);
  }
  
  // Format recovery suggestions
  const suggestionsText = EOL + EOL + chalk.bold('Suggested Actions:') + EOL +
    recoverySuggestions
      .map((suggestion, index) => `  ${index + 1}. ${suggestion}`)
      .join(EOL);
  
  // Build the full error message
  const errorHeader = chalk[color].bold(`${icon} ${title}: ${code}`);
  const errorMessage = chalk.white(message);
  const fullMessage = `${errorHeader}${EOL}${EOL}${errorMessage}${detailsText}${suggestionsText}`;
  
  // Use boxen to create a nice box around the error
  return boxen(fullMessage, {
    padding: 1,
    margin: 1,
    borderStyle: 'round',
    borderColor: color,
    backgroundColor: '#000'
  });
}

/**
 * Log an error to the console with standardized formatting
 * 
 * @param {string} message - The main error message
 * @param {string} category - Error category from ERROR_CATEGORIES
 * @param {string} code - Specific error code
 * @param {Object} details - Additional error details
 * @param {string[]} [suggestions] - Custom recovery suggestions
 */
function logError(message, category = 'GENERIC', code = 'GENERIC', details = {}, suggestions = []) {
  console.error(formatError(message, category, code, details, suggestions));
}

/**
 * Handle an error by categorizing it and providing appropriate recovery suggestions
 * 
 * @param {Error} error - The error object
 * @param {Object} options - Additional options
 * @param {boolean} [options.exit=false] - Whether to exit the process
 * @param {number} [options.exitCode=1] - Exit code to use when exiting
 */
function handleError(error, options = {}) {
  const { exit = false, exitCode = 1 } = options;
  
  // Default values
  let category = 'GENERIC';
  let code = 'GENERIC';
  let message = error.message || 'An unexpected error occurred';
  let details = {};
  let suggestions = [];
  
  // Enhanced error object from backend
  if (error.category && error.code) {
    category = error.category;
    code = error.code;
    if (error.details) {
      details = error.details;
    }
  } 
  // Handle network errors
  else if (error.code === 'ECONNREFUSED') {
    category = 'CONNECTION';
    code = 'ECONNREFUSED';
  }
  else if (error.code === 'ETIMEDOUT') {
    category = 'CONNECTION';
    code = 'TIMEOUT';
  }
  // Handle Julia backend errors
  else if (error.message && error.message.includes('Julia')) {
    category = 'BACKEND';
    code = 'JULIA_ERROR';
    if (error.stack) {
      details.stack = error.stack.split('\n').slice(0, 3).join('\n');
    }
  }
  // Handle wallet errors
  else if (error.message && error.message.includes('funds')) {
    category = 'WALLET';
    code = 'INSUFFICIENT_FUNDS';
  }
  else if (error.message && error.message.includes('wallet')) {
    category = 'WALLET';
    code = 'WALLET_NOT_CONNECTED';
  }
  // Handle blockchain errors
  else if (error.message && error.message.includes('gas')) {
    category = 'BLOCKCHAIN';
    code = 'GAS_ESTIMATION';
  }
  else if (error.message && error.message.includes('RPC')) {
    category = 'BLOCKCHAIN';
    code = 'RPC_ERROR';
  }
  
  // Log the formatted error
  logError(message, category, code, details, suggestions);
  
  // Exit if requested
  if (exit) {
    process.exit(exitCode);
  }
}

/**
 * Format a validation error for a specific field
 * 
 * @param {string} field - The field that failed validation
 * @param {string} message - The validation error message
 * @param {Object} [details={}] - Additional validation details
 * @returns {string} Formatted validation error
 */
function formatValidationError(field, message, details = {}) {
  const fullMessage = `Validation failed for field: ${chalk.bold(field)}${EOL}${message}`;
  return formatError(fullMessage, 'VALIDATION', 'FIELD_VALIDATION', details);
}

/**
 * Check if an object has required fields and format appropriate error if not
 * 
 * @param {Object} obj - The object to check
 * @param {string[]} requiredFields - List of required field names
 * @param {string} contextName - Name of the context (for error messages)
 * @returns {string|null} Error message or null if validation passed
 */
function validateRequiredFields(obj, requiredFields, contextName) {
  const missingFields = requiredFields.filter(field => !obj[field]);
  
  if (missingFields.length > 0) {
    const fieldList = missingFields.map(f => chalk.bold(f)).join(', ');
    const message = `Missing required ${missingFields.length > 1 ? 'fields' : 'field'} for ${contextName}: ${fieldList}`;
    return formatError(message, 'VALIDATION', 'MISSING_REQUIRED_FIELDS');
  }
  
  return null;
}

/**
 * Display a warning message that doesn't interrupt flow
 * 
 * @param {string} message - Warning message
 * @param {string} title - Warning title
 */
function showWarning(message, title = 'WARNING') {
  const formattedMessage = `${chalk.yellow.bold(`⚠️ ${title}`)}${EOL}${EOL}${message}`;
  
  console.warn(boxen(formattedMessage, {
    padding: 1,
    margin: 1,
    borderStyle: 'round',
    borderColor: 'yellow',
    backgroundColor: '#000'
  }));
}

/**
 * Show a help message with next steps
 * 
 * @param {string} message - The help message
 * @param {string[]} steps - List of next steps
 */
function showNextSteps(message, steps) {
  const stepsText = steps
    .map((step, index) => `  ${index + 1}. ${step}`)
    .join(EOL);
  
  const fullMessage = `${chalk.blue.bold('💡 NEXT STEPS')}${EOL}${EOL}${message}${EOL}${EOL}${stepsText}`;
  
  console.log(boxen(fullMessage, {
    padding: 1,
    margin: 1,
    borderStyle: 'round',
    borderColor: 'blue',
    backgroundColor: '#000'
  }));
}

/**
 * Format a success message
 * 
 * @param {string} message - The success message
 * @param {Object} [details={}] - Additional details about the success
 * @returns {string} Formatted success message
 */
function formatSuccess(message, details = {}) {
  let detailsText = '';
  
  if (Object.keys(details).length > 0) {
    detailsText = EOL + EOL + 
      Object.entries(details)
        .map(([key, value]) => `  ${chalk.bold(key)}: ${value}`)
        .join(EOL);
  }
  
  const fullMessage = `${chalk.green.bold('✅ SUCCESS')}${EOL}${EOL}${message}${detailsText}`;
  
  return boxen(fullMessage, {
    padding: 1,
    margin: 1,
    borderStyle: 'round',
    borderColor: 'green',
    backgroundColor: '#000'
  });
}

module.exports = {
  formatError,
  logError,
  handleError,
  formatValidationError,
  validateRequiredFields,
  showWarning,
  showNextSteps,
  formatSuccess,
  ERROR_CATEGORIES
};
