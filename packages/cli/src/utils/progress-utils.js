/**
 * Progress utilities for JuliaOS CLI
 * 
 * This module provides standardized progress indicators, loading spinners,
 * and startup feedback for the JuliaOS command-line interface.
 */

const chalk = require('chalk');
const ora = require('ora');
const cliProgress = require('cli-progress');
const { EOL } = require('os');

/**
 * Creates a spinner with standardized formatting
 * 
 * @param {string} text - Initial spinner text
 * @param {Object} options - Spinner options
 * @returns {Object} Ora spinner instance
 */
function createSpinner(text, options = {}) {
  const defaultOptions = {
    color: 'cyan',
    spinner: 'dots',
    text: text
  };
  
  return ora({...defaultOptions, ...options});
}

/**
 * Creates a progress bar with standardized formatting
 * 
 * @param {string} format - Progress bar format string
 * @param {Object} options - Progress bar options
 * @returns {Object} CLI progress bar instance
 */
function createProgressBar(format, options = {}) {
  const defaultFormat = format || 
    `${chalk.cyan('{bar}')} ${chalk.cyan('{percentage}%')} | ${chalk.yellow('ETA: {eta}s')} | {value}/{total}`;
  
  const defaultOptions = {
    format: defaultFormat,
    barCompleteChar: '█',
    barIncompleteChar: '░',
    hideCursor: true,
    clearOnComplete: false,
    barsize: 30
  };
  
  return new cliProgress.SingleBar({...defaultOptions, ...options});
}

/**
 * Create a multi-bar container for multiple progress bars
 * 
 * @param {Object} options - Multi-bar options
 * @returns {Object} CLI multi-progress bar instance
 */
function createMultiProgressBar(options = {}) {
  const defaultOptions = {
    hideCursor: true,
    clearOnComplete: false,
    format: `${chalk.cyan('{bar}')} ${chalk.cyan('{percentage}%')} | {task} | {value}/{total}`
  };
  
  return new cliProgress.MultiBar({...defaultOptions, ...options});
}

/**
 * Execute a task with a loading spinner
 * 
 * @param {string} initialText - Initial spinner text
 * @param {Function} task - Async function to execute
 * @param {Function} formatResult - Function to format success message (optional)
 * @returns {Promise<any>} Task result
 */
async function withSpinner(initialText, task, formatResult = null) {
  const spinner = createSpinner(initialText);
  spinner.start();
  
  try {
    const result = await task();
    
    if (formatResult) {
      const successText = formatResult(result);
      spinner.succeed(successText);
    } else {
      spinner.succeed('Operation completed successfully');
    }
    
    return result;
  } catch (error) {
    spinner.fail(error.message || 'Operation failed');
    throw error;
  }
}

/**
 * Execute a task with a progress bar
 * 
 * @param {string} title - Progress bar title
 * @param {number} total - Total steps
 * @param {Function} task - Async function that updates progress
 * @param {Object} options - Progress bar options
 * @returns {Promise<any>} Task result
 */
async function withProgressBar(title, total, task, options = {}) {
  const bar = createProgressBar(
    options.format || `${chalk.bold(title)} | ${chalk.cyan('{bar}')} ${chalk.cyan('{percentage}%')} | {value}/{total}`,
    options
  );
  
  bar.start(total, 0);
  
  try {
    const result = await task((current) => {
      bar.update(current);
    }, bar);
    
    bar.stop();
    return result;
  } catch (error) {
    bar.stop();
    throw error;
  }
}

/**
 * Display a startup sequence with progress indicators
 * 
 * @param {Array<Object>} steps - Array of {text, task} objects
 * @param {Object} options - Options
 * @returns {Promise<Object>} Results from each step
 */
async function runStartupSequence(steps, options = {}) {
  const results = {};
  const indent = options.indent || 2;
  const indentStr = ' '.repeat(indent);
  
  console.log(chalk.bold.blue('▶ Starting JuliaOS...'));
  console.log();
  
  for (let i = 0; i < steps.length; i++) {
    const step = steps[i];
    const spinner = createSpinner(step.text);
    
    // Print step number and details
    process.stdout.write(`${indentStr}${chalk.bold.blue(`(${i+1}/${steps.length})`)} `);
    spinner.start();
    
    try {
      results[step.id] = await step.task();
      spinner.succeed();
      
      // If step has verification or additional info
      if (step.verify) {
        const verifyResult = await step.verify(results[step.id]);
        if (verifyResult.success) {
          console.log(`${indentStr}${indentStr}${chalk.green('✓')} ${verifyResult.message}`);
        } else {
          console.log(`${indentStr}${indentStr}${chalk.yellow('⚠')} ${verifyResult.message}`);
        }
      }
      
      if (step.info && results[step.id]) {
        if (typeof step.info === 'function') {
          const infoText = step.info(results[step.id]);
          if (infoText) {
            console.log(`${indentStr}${indentStr}${chalk.dim(infoText)}`);
          }
        } else {
          console.log(`${indentStr}${indentStr}${chalk.dim(step.info)}`);
        }
      }
      
    } catch (error) {
      spinner.fail();
      
      if (step.required === false) {
        console.log(`${indentStr}${indentStr}${chalk.yellow('⚠')} Non-critical error: ${error.message}`);
        // Continue despite error
      } else {
        console.error(`${indentStr}${indentStr}${chalk.red('✗')} ${error.message}`);
        if (options.exitOnError) {
          process.exit(1);
        }
        throw error; // Re-throw to stop sequence
      }
    }
    
    // Add spacing between steps
    console.log();
  }
  
  // Print startup complete message
  console.log(chalk.bold.green('✅ JuliaOS started successfully!'));
  console.log();
  
  return results;
}

/**
 * Update console title with current operation
 * 
 * @param {string} title - Title to display
 */
function setConsoleTitle(title) {
  const prefix = 'JuliaOS CLI';
  process.stdout.write(`\x1b]0;${prefix}${title ? ` - ${title}` : ''}\x07`);
}

/**
 * Log a step in a multi-step process
 * 
 * @param {string} message - Step message
 * @param {number} step - Current step number
 * @param {number} totalSteps - Total number of steps
 * @param {string} status - Status indicator (success, pending, error)
 */
function logStep(message, step, totalSteps, status = 'pending') {
  const icons = {
    pending: chalk.blue('○'),
    active: chalk.blue('◉'),
    success: chalk.green('✓'),
    error: chalk.red('✗'),
    warning: chalk.yellow('⚠'),
    info: chalk.blue('ℹ')
  };
  
  const stepText = `[${step}/${totalSteps}]`;
  const icon = icons[status] || icons.pending;
  
  console.log(`${icon} ${chalk.bold(stepText)} ${message}`);
}

/**
 * Log a section header
 * 
 * @param {string} title - Section title
 */
function logSection(title) {
  const line = '─'.repeat(Math.max(0, 80 - title.length - 4));
  console.log();
  console.log(chalk.bold.blue(`┌─ ${title} ${line}`));
  console.log();
}

/**
 * Create a pretty table for data display
 * 
 * @param {Array<Object>} data - Array of objects to display
 * @param {Array<Object>} columns - Column definitions with header and key
 * @returns {string} Formatted table string
 */
function createTable(data, columns) {
  if (!data || data.length === 0) {
    return 'No data available';
  }
  
  // Get maximum width for each column
  const widths = columns.map(col => {
    const headerLength = col.header.length;
    
    // Find the maximum data length for this column
    const maxDataLength = data.reduce((max, row) => {
      const value = row[col.key];
      const strValue = value === undefined || value === null 
        ? '' 
        : String(value);
      return Math.max(max, strValue.length);
    }, 0);
    
    // Return the greater of header length and max data length
    return Math.max(headerLength, maxDataLength, col.minWidth || 0);
  });
  
  // Create header row
  const headerRow = columns.map((col, i) => 
    chalk.bold(col.header.padEnd(widths[i]))
  ).join(' │ ');
  
  // Create separator
  const separator = columns.map((_, i) => 
    '─'.repeat(widths[i])
  ).join('─┼─');
  
  // Create data rows
  const rows = data.map(row => {
    return columns.map((col, i) => {
      const value = row[col.key];
      const strValue = value === undefined || value === null 
        ? '' 
        : String(value);
        
      // Apply custom formatter if provided
      const formatted = col.formatter 
        ? col.formatter(value, row)
        : strValue;
        
      return formatted.padEnd(widths[i]);
    }).join(' │ ');
  });
  
  // Combine header, separator, and rows
  return `┌─${separator.replace(/─/g, '─').replace(/┼/g, '┬')}─┐${EOL}` +
         `│ ${headerRow} │${EOL}` +
         `├─${separator}─┤${EOL}` +
         rows.map(row => `│ ${row} │`).join(EOL) +
         `${EOL}└─${separator.replace(/─/g, '─').replace(/┼/g, '┴')}─┘`;
}

/**
 * Format an operation summary for display after completion
 * 
 * @param {string} title - Operation title
 * @param {Object} stats - Operation statistics
 * @param {Array<Object>} details - Operation details
 * @returns {string} Formatted summary
 */
function formatOperationSummary(title, stats, details = []) {
  let summary = chalk.bold.blue(title) + EOL + EOL;
  
  // Add statistics
  if (stats && Object.keys(stats).length > 0) {
    summary += chalk.bold('Statistics:') + EOL;
    for (const [key, value] of Object.entries(stats)) {
      summary += `  ${chalk.dim(key)}: ${value}${EOL}`;
    }
    summary += EOL;
  }
  
  // Add details if provided
  if (details && details.length > 0) {
    summary += chalk.bold('Details:') + EOL;
    for (const detail of details) {
      if (typeof detail === 'string') {
        summary += `  ${detail}${EOL}`;
      } else if (detail.label && detail.value !== undefined) {
        const label = detail.important 
          ? chalk.yellow(detail.label)
          : chalk.dim(detail.label);
          
        summary += `  ${label}: ${detail.value}${EOL}`;
      }
    }
  }
  
  return summary;
}

module.exports = {
  createSpinner,
  createProgressBar,
  createMultiProgressBar,
  withSpinner,
  withProgressBar,
  runStartupSequence,
  setConsoleTitle,
  logStep,
  logSection,
  createTable,
  formatOperationSummary
};
