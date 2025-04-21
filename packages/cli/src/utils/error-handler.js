/**
 * Enhanced error handling utility for JuliaOS CLI
 * Provides consistent error formatting, contextual troubleshooting tips,
 * and automatic error categorization.
 */
const chalk = require('chalk');
const fs = require('fs-extra');
const path = require('path');
const os = require('os');

// Define error categories and their troubleshooting tips
const ERROR_CATEGORIES = {
    CONNECTION: {
        patterns: ['ECONNREFUSED', 'socket hang up', 'connection refused', 'network error', 'timeout'],
        title: 'Connection Error',
        color: 'red',
        icon: '🔌',
        tips: [
            'Check if the Julia backend server is running',
            'Verify the backend URL is correct in your .env file',
            'Ensure there are no firewall or network issues blocking the connection',
            'Try restarting the Julia server with: cd /path/to/JuliaOS && julia julia/julia_server.jl'
        ]
    },
    AUTHENTICATION: {
        patterns: ['unauthorized', 'forbidden', 'auth', 'token', 'permission denied', '401', '403'],
        title: 'Authentication Error',
        color: 'yellow',
        icon: '🔒',
        tips: [
            'Check if your API keys are correctly configured',
            'Verify your wallet is properly connected',
            'Ensure you have the necessary permissions for this operation',
            'Try reconnecting your wallet or refreshing your API keys'
        ]
    },
    VALIDATION: {
        patterns: ['invalid', 'validation', 'required', 'schema', 'constraint', 'not found', '400', '404'],
        title: 'Validation Error',
        color: 'yellow',
        icon: '⚠️',
        tips: [
            'Check the format and values of your input parameters',
            'Ensure all required fields are provided',
            'Verify that referenced resources (agents, swarms, etc.) exist',
            'Check for typos in IDs or names'
        ]
    },
    BACKEND: {
        patterns: ['internal server error', 'backend error', 'julia error', '500', 'exception'],
        title: 'Backend Error',
        color: 'red',
        icon: '⚙️',
        tips: [
            'Check the Julia server logs for more details',
            'Ensure all required Julia packages are installed',
            'Verify the backend server has sufficient resources',
            'Try restarting the Julia server'
        ]
    },
    BLOCKCHAIN: {
        patterns: ['blockchain', 'transaction', 'gas', 'nonce', 'contract', 'wallet', 'web3'],
        title: 'Blockchain Error',
        color: 'magenta',
        icon: '⛓️',
        tips: [
            'Check if your wallet has sufficient funds for the operation',
            'Verify the RPC endpoint for the blockchain is accessible',
            'Ensure gas settings are appropriate for current network conditions',
            'Check if the blockchain network is experiencing congestion'
        ]
    },
    DATA: {
        patterns: ['data', 'parse', 'json', 'format', 'unexpected', 'syntax'],
        title: 'Data Error',
        color: 'blue',
        icon: '📊',
        tips: [
            'Check the format of your input data',
            'Ensure JSON data is properly formatted',
            'Verify that data sources are available and returning expected formats',
            'Check for encoding issues in your data'
        ]
    },
    UNKNOWN: {
        patterns: [],
        title: 'Unknown Error',
        color: 'gray',
        icon: '❓',
        tips: [
            'Check the CLI and server logs for more details',
            'Try restarting both the CLI and the server',
            'Verify your JuliaOS installation is up to date',
            'Check for any system resource constraints (memory, disk space)'
        ]
    }
};

// Error log file path
const ERROR_LOG_PATH = path.join(os.homedir(), '.juliaos', 'error_logs.json');

/**
 * Categorize an error based on its message
 * @param {string} errorMessage - The error message to categorize
 * @returns {Object} The error category
 */
function categorizeError(errorMessage) {
    if (!errorMessage) return ERROR_CATEGORIES.UNKNOWN;
    
    const lowerMessage = errorMessage.toLowerCase();
    
    for (const [key, category] of Object.entries(ERROR_CATEGORIES)) {
        if (key === 'UNKNOWN') continue;
        
        if (category.patterns.some(pattern => lowerMessage.includes(pattern.toLowerCase()))) {
            return category;
        }
    }
    
    return ERROR_CATEGORIES.UNKNOWN;
}

/**
 * Format and display an error with contextual troubleshooting tips
 * @param {Error|string} error - The error object or message
 * @param {string} context - The context in which the error occurred
 * @param {boolean} verbose - Whether to show verbose error details
 */
function handleError(error, context = 'Operation', verbose = false) {
    const errorMessage = error instanceof Error ? error.message : error;
    const errorCategory = categorizeError(errorMessage);
    
    // Log the error
    logError(error, context, errorCategory);
    
    // Display formatted error
    console.error(`\n${chalk[errorCategory.color](errorCategory.icon + ' ' + errorCategory.title)}: ${errorMessage}`);
    
    if (context) {
        console.error(chalk.cyan(`Context: ${context}`));
    }
    
    // Display stack trace in verbose mode
    if (verbose && error instanceof Error && error.stack) {
        console.error(chalk.gray('\nStack Trace:'));
        console.error(chalk.gray(error.stack.split('\n').slice(1).join('\n')));
    }
    
    // Display troubleshooting tips
    console.error(chalk.cyan('\nTroubleshooting Tips:'));
    errorCategory.tips.forEach((tip, index) => {
        console.error(chalk.white(`${index + 1}. ${tip}`));
    });
    
    // Add development mode tip
    if (!verbose && process.env.NODE_ENV !== 'development') {
        console.error(chalk.yellow('\nFor more detailed error information, run with NODE_ENV=development'));
    }
}

/**
 * Log the error to a file for later analysis
 * @param {Error|string} error - The error object or message
 * @param {string} context - The context in which the error occurred
 * @param {Object} category - The error category
 */
async function logError(error, context, category) {
    try {
        // Ensure the log directory exists
        await fs.ensureDir(path.dirname(ERROR_LOG_PATH));
        
        // Read existing logs or create new log array
        let logs = [];
        try {
            if (await fs.pathExists(ERROR_LOG_PATH)) {
                logs = await fs.readJson(ERROR_LOG_PATH);
            }
        } catch (e) {
            // If file exists but can't be read, start with empty logs
        }
        
        // Add new log entry
        logs.push({
            timestamp: new Date().toISOString(),
            context,
            category: category.title,
            message: error instanceof Error ? error.message : error,
            stack: error instanceof Error ? error.stack : null,
            os: {
                platform: os.platform(),
                release: os.release(),
                type: os.type()
            },
            node: process.version
        });
        
        // Limit log size (keep last 100 entries)
        if (logs.length > 100) {
            logs = logs.slice(-100);
        }
        
        // Write logs back to file
        await fs.writeJson(ERROR_LOG_PATH, logs, { spaces: 2 });
    } catch (e) {
        // Silent fail for logging errors
        console.error(chalk.red('Failed to log error:'), e.message);
    }
}

/**
 * Get the path to the error log file
 * @returns {string} The path to the error log file
 */
function getErrorLogPath() {
    return ERROR_LOG_PATH;
}

/**
 * Clear the error log file
 */
async function clearErrorLogs() {
    try {
        await fs.writeJson(ERROR_LOG_PATH, [], { spaces: 2 });
        return true;
    } catch (e) {
        console.error(chalk.red('Failed to clear error logs:'), e.message);
        return false;
    }
}

/**
 * Get recent error logs
 * @param {number} count - Number of recent logs to retrieve
 * @returns {Array} Array of recent error logs
 */
async function getRecentErrorLogs(count = 10) {
    try {
        if (await fs.pathExists(ERROR_LOG_PATH)) {
            const logs = await fs.readJson(ERROR_LOG_PATH);
            return logs.slice(-count);
        }
        return [];
    } catch (e) {
        console.error(chalk.red('Failed to read error logs:'), e.message);
        return [];
    }
}

module.exports = {
    handleError,
    categorizeError,
    getErrorLogPath,
    clearErrorLogs,
    getRecentErrorLogs
};
