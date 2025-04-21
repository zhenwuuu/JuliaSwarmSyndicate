/**
 * Utility functions for the JuliaOS CLI
 */

const chalk = require('chalk');
const ora = require('ora');
const inquirer = require('inquirer');
const { JuliaBridge } = require('../../julia-bridge');

/**
 * Display a header with the current menu path
 * @param {string} title - The title to display
 */
function displayHeader(title) {
  console.clear();
  const width = process.stdout.columns || 80;
  const padding = Math.max(0, Math.floor((width - title.length - 4) / 2));

  console.log(chalk.blue('='.repeat(width)));
  console.log(chalk.blue('=') + ' '.repeat(padding) + chalk.bold.white(title) + ' '.repeat(padding) + chalk.blue('='));
  console.log(chalk.blue('='.repeat(width)));
  console.log('');
}

/**
 * Format error messages with color and context
 * @param {Error} error - The error object
 * @param {string} context - Context where the error occurred
 * @returns {string} Formatted error message
 */
function formatError(error, context = '') {
  const contextStr = context ? ` [${context}]` : '';
  return chalk.red(`Error${contextStr}: ${error.message}`);
}

/**
 * Create a spinner with the given text
 * @param {string} text - Spinner text
 * @returns {ora.Ora} Spinner instance
 */
function createSpinner(text) {
  return ora(text);
}

/**
 * Validate that input is not empty
 * @param {string} input - User input
 * @returns {boolean|string} True if valid, error message if invalid
 */
function validateNotEmpty(input) {
  return input.trim() !== '' || 'This field cannot be empty';
}

/**
 * Validate that input is a number
 * @param {string} input - User input
 * @returns {boolean|string} True if valid, error message if invalid
 */
function validateNumber(input) {
  return !isNaN(Number(input)) || 'Please enter a valid number';
}

/**
 * Validate that input is a positive number
 * @param {string} input - User input
 * @returns {boolean|string} True if valid, error message if invalid
 */
function validatePositiveNumber(input) {
  const num = Number(input);
  return (!isNaN(num) && num > 0) || 'Please enter a positive number';
}

/**
 * Validate that input is a valid JSON string
 * @param {string} input - User input
 * @returns {boolean|string} True if valid, error message if invalid
 */
function validateJSON(input) {
  try {
    if (input.trim() === '') return true;
    JSON.parse(input);
    return true;
  } catch (error) {
    return 'Please enter valid JSON';
  }
}

/**
 * Prompt user for confirmation
 * @param {string} message - Confirmation message
 * @returns {Promise<boolean>} User's response
 */
async function confirm(message) {
  const { confirmed } = await inquirer.prompt([
    {
      type: 'confirm',
      name: 'confirmed',
      message,
      default: false
    }
  ]);

  return confirmed;
}

/**
 * Format a date object as a string
 * @param {Date} date - Date object
 * @returns {string} Formatted date string
 */
function formatDate(date) {
  return date.toISOString();
}

/**
 * Format a duration in milliseconds as a human-readable string
 * @param {number} ms - Duration in milliseconds
 * @returns {string} Formatted duration string
 */
function formatDuration(ms) {
  const seconds = Math.floor(ms / 1000);
  const minutes = Math.floor(seconds / 60);
  const hours = Math.floor(minutes / 60);

  if (hours > 0) {
    return `${hours}h ${minutes % 60}m ${seconds % 60}s`;
  } else if (minutes > 0) {
    return `${minutes}m ${seconds % 60}s`;
  } else {
    return `${seconds}s`;
  }
}

/**
 * Truncate a string to a maximum length
 * @param {string} str - String to truncate
 * @param {number} maxLength - Maximum length
 * @returns {string} Truncated string
 */
function truncate(str, maxLength = 100) {
  if (str.length <= maxLength) return str;
  return str.substring(0, maxLength - 3) + '...';
}

/**
 * Sleep for a specified duration
 * @param {number} ms - Duration in milliseconds
 * @returns {Promise<void>} Promise that resolves after the duration
 */
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Create a bridge to the Julia server
 * @param {string} host - Server host
 * @param {number} port - Server port
 * @returns {JuliaBridge} Bridge instance
 */
function createBridge(host = 'localhost', port = 8052) {
  return new JuliaBridge({
    useExistingServer: true,
    serverPort: port,
    apiUrl: `http://${host}:${port}/api/v1`,
    healthUrl: `http://${host}:${port}/health`,
    wsUrl: `ws://${host}:${port}`,
    debug: true
  });
}

/**
 * Parse command line arguments
 * @param {string[]} args - Command line arguments
 * @returns {Object} Parsed arguments
 */
function parseArgs(args) {
  const result = {};

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];

    if (arg.startsWith('--')) {
      const key = arg.substring(2);

      if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
        result[key] = args[i + 1];
        i++;
      } else {
        result[key] = true;
      }
    }
  }

  return result;
}

/**
 * Format an error object for display
 * @param {Error} error - Error object
 * @returns {string} Formatted error string
 */
function formatErrorObject(error) {
  if (!error) return 'Unknown error';

  let message = error.message || 'Unknown error';

  // Add stack trace if available
  if (error.stack) {
    message += '\n\n' + chalk.gray(error.stack);
  }

  // Add additional properties if available
  if (error.code) {
    message += '\n' + chalk.yellow(`Error code: ${error.code}`);
  }

  if (error.response) {
    message += '\n' + chalk.yellow(`Response: ${JSON.stringify(error.response)}`);
  }

  return message;
}

/**
 * Get error category based on error message or code
 * @param {Error} error - Error object
 * @returns {string} Error category
 */
function getErrorCategory(error) {
  if (!error) return 'Unknown';

  const message = error.message || '';
  const code = error.code || '';

  if (message.includes('connect') || code.includes('ECONNREFUSED') || code.includes('ENOTFOUND')) {
    return 'Connection';
  }

  if (message.includes('timeout') || code.includes('TIMEOUT')) {
    return 'Timeout';
  }

  if (message.includes('auth') || message.includes('permission') || code.includes('AUTH')) {
    return 'Authentication';
  }

  if (message.includes('valid') || message.includes('parse')) {
    return 'Validation';
  }

  if (message.includes('not found') || code.includes('ENOENT')) {
    return 'Not Found';
  }

  return 'General';
}

/**
 * Get troubleshooting tips based on error category
 * @param {string} category - Error category
 * @returns {string[]} Array of troubleshooting tips
 */
function getTroubleshootingTips(category) {
  switch (category) {
    case 'Connection':
      return [
        'Check if the Julia server is running',
        'Verify the server host and port are correct',
        'Check for firewall or network issues',
        'Try restarting the server'
      ];
    case 'Timeout':
      return [
        'The operation took too long to complete',
        'Try again with a longer timeout',
        'Check if the server is under heavy load',
        'Consider optimizing the operation'
      ];
    case 'Authentication':
      return [
        'Check your API key or credentials',
        'Verify you have the necessary permissions',
        'Try regenerating your API key',
        'Check if authentication is enabled on the server'
      ];
    case 'Validation':
      return [
        'Check the format of your input',
        'Ensure all required fields are provided',
        'Verify the data types of your input',
        'Check for any special characters that might need escaping'
      ];
    case 'Not Found':
      return [
        'Check if the resource exists',
        'Verify the path or identifier is correct',
        'The resource might have been deleted',
        'Check if you have access to the resource'
      ];
    default:
      return [
        'Try the operation again',
        'Check the server logs for more information',
        'Restart the CLI and try again',
        'Contact support if the issue persists'
      ];
  }
}

// Export all utility functions directly
module.exports = {
  displayHeader,
  formatError,
  createSpinner,
  validateNotEmpty,
  validateNumber,
  validatePositiveNumber,
  validateJSON,
  confirm,
  formatDate,
  formatDuration,
  truncate,
  sleep,
  createBridge,
  parseArgs,
  formatErrorObject,
  getErrorCategory,
  getTroubleshootingTips
};

// Also export a factory function to match the expected pattern
module.exports.createUtils = function(deps) {
  // Return the same utility functions
  return module.exports;
};
