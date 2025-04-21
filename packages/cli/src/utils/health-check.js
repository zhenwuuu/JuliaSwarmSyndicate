/**
 * Health check utilities for JuliaOS CLI
 * 
 * This module provides pre-flight checks to validate the environment and dependencies
 * before starting the CLI.
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const chalk = require('chalk');
const { logError, showWarning } = require('./error-utils');
const { withSpinner, logSection } = require('./progress-utils');

/**
 * Dependency version requirements
 */
const DEPENDENCIES = {
  node: {
    command: 'node --version',
    minVersion: '16.0.0',
    recommended: '18.0.0',
    extract: (output) => output.trim().replace('v', '')
  },
  npm: {
    command: 'npm --version',
    minVersion: '7.0.0',
    recommended: '9.0.0',
    extract: (output) => output.trim()
  },
  julia: {
    command: 'julia --version',
    minVersion: '1.8.0',
    recommended: '1.10.0',
    extract: (output) => {
      const match = output.match(/julia version (\d+\.\d+\.\d+)/i);
      return match ? match[1] : null;
    }
  },
  python: {
    command: 'python --version || python3 --version',
    minVersion: '3.8.0',
    recommended: '3.10.0',
    extract: (output) => {
      const match = output.match(/python (\d+\.\d+\.\d+)/i);
      return match ? match[1] : null;
    },
    optional: true
  }
};

/**
 * Environment variables that should be set
 */
const REQUIRED_ENV_VARS = [
  {
    name: 'JULIAOS_SERVER_URL',
    description: 'URL to the JuliaOS server',
    default: 'http://localhost:8000'
  },
  {
    name: 'JULIAOS_LOG_LEVEL',
    description: 'Logging level',
    default: 'info'
  }
];

const OPTIONAL_ENV_VARS = [
  {
    name: 'JULIAOS_API_KEY',
    description: 'API key for authenticated operations',
    secure: true
  },
  {
    name: 'ETHEREUM_RPC_URL',
    description: 'Ethereum RPC URL'
  },
  {
    name: 'POLYGON_RPC_URL',
    description: 'Polygon RPC URL'
  },
  {
    name: 'SOLANA_RPC_URL',
    description: 'Solana RPC URL'
  }
];

/**
 * Required files that should exist
 */
const REQUIRED_FILES = [
  {
    path: 'julia/run_server.jl',
    description: 'Julia server script'
  },
  {
    path: 'julia/Project.toml',
    description: 'Julia project file'
  }
];

/**
 * Compare two version strings
 * 
 * @param {string} version1 - First version
 * @param {string} version2 - Second version
 * @returns {number} -1 if version1 < version2, 0 if equal, 1 if version1 > version2
 */
function compareVersions(version1, version2) {
  const parts1 = version1.split('.').map(Number);
  const parts2 = version2.split('.').map(Number);
  
  for (let i = 0; i < Math.max(parts1.length, parts2.length); i++) {
    const part1 = parts1[i] || 0;
    const part2 = parts2[i] || 0;
    
    if (part1 < part2) return -1;
    if (part1 > part2) return 1;
  }
  
  return 0;
}

/**
 * Check if a command exists and meets version requirements
 * 
 * @param {string} name - Dependency name
 * @param {Object} config - Dependency configuration
 * @returns {Object} Check result with status and details
 */
function checkDependency(name, config) {
  try {
    const output = execSync(config.command, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
    const version = config.extract(output);
    
    if (!version) {
      return {
        name,
        status: 'error',
        message: `Could not determine ${name} version`
      };
    }
    
    const meetsMinimum = compareVersions(version, config.minVersion) >= 0;
    const meetsRecommended = compareVersions(version, config.recommended) >= 0;
    
    if (!meetsMinimum) {
      return {
        name,
        status: config.optional ? 'warning' : 'error',
        message: `${name} version ${version} is below minimum required version ${config.minVersion}`,
        version,
        minVersion: config.minVersion,
        recommended: config.recommended
      };
    }
    
    if (!meetsRecommended) {
      return {
        name,
        status: 'warning',
        message: `${name} version ${version} is below recommended version ${config.recommended}`,
        version,
        minVersion: config.minVersion,
        recommended: config.recommended
      };
    }
    
    return {
      name,
      status: 'success',
      message: `${name} version ${version} meets requirements`,
      version,
      minVersion: config.minVersion,
      recommended: config.recommended
    };
  } catch (error) {
    return {
      name,
      status: config.optional ? 'warning' : 'error',
      message: `${name} not found or not executable: ${error.message}`,
      error
    };
  }
}

/**
 * Check if environment variables are set
 * 
 * @param {Array<Object>} envVars - Environment variables to check
 * @param {boolean} required - Whether the variables are required
 * @returns {Array<Object>} Check results
 */
function checkEnvironmentVariables(envVars, required = true) {
  return envVars.map(envVar => {
    const value = process.env[envVar.name];
    const hasValue = value !== undefined && value !== '';
    
    if (!hasValue && required) {
      return {
        name: envVar.name,
        status: 'error',
        message: `Environment variable ${envVar.name} is not set`,
        description: envVar.description,
        required
      };
    }
    
    if (!hasValue && !required) {
      return {
        name: envVar.name,
        status: 'warning',
        message: `Optional environment variable ${envVar.name} is not set`,
        description: envVar.description,
        required
      };
    }
    
    return {
      name: envVar.name,
      status: 'success',
      message: `Environment variable ${envVar.name} is set`,
      description: envVar.description,
      value: envVar.secure ? '********' : value,
      required
    };
  });
}

/**
 * Check if required files exist
 * 
 * @param {Array<Object>} files - Files to check
 * @returns {Array<Object>} Check results
 */
function checkRequiredFiles(files) {
  return files.map(file => {
    const rootDir = path.resolve(__dirname, '../..');
    const filePath = path.join(rootDir, file.path);
    const exists = fs.existsSync(filePath);
    
    return {
      path: file.path,
      status: exists ? 'success' : 'error',
      message: exists ? 
        `Required file ${file.path} exists` : 
        `Required file ${file.path} does not exist`,
      description: file.description
    };
  });
}

/**
 * Check if JuliaOS server is running
 * 
 * @returns {Promise<Object>} Check result
 */
async function checkServerStatus() {
  const serverUrl = process.env.JULIAOS_SERVER_URL || 'http://localhost:8000';
  const healthEndpoint = `${serverUrl}/health`;
  
  try {
    const response = await fetch(healthEndpoint, { 
      method: 'GET',
      headers: { 'Accept': 'application/json' },
      timeout: 5000
    });
    
    if (!response.ok) {
      return {
        status: 'error',
        message: `JuliaOS server returned status ${response.status}`,
        url: healthEndpoint
      };
    }
    
    const data = await response.json();
    
    return {
      status: 'success',
      message: 'JuliaOS server is running',
      url: healthEndpoint,
      version: data.version,
      uptime: data.uptime
    };
  } catch (error) {
    return {
      status: 'error',
      message: `Could not connect to JuliaOS server: ${error.message}`,
      url: healthEndpoint,
      error
    };
  }
}

/**
 * Run all health checks
 * 
 * @param {Object} options - Options
 * @returns {Promise<Object>} Health check results
 */
async function runHealthChecks(options = {}) {
  const results = {
    dependencies: {},
    environmentVariables: {
      required: [],
      optional: []
    },
    files: [],
    server: null,
    timestamp: new Date().toISOString(),
    summary: {
      errors: 0,
      warnings: 0,
      success: 0
    }
  };
  
  // Show section header
  if (!options.silent) {
    logSection('JuliaOS Health Check');
  }
  
  // Check dependencies
  for (const [name, config] of Object.entries(DEPENDENCIES)) {
    const result = await withSpinner(
      `Checking ${name}...`,
      () => Promise.resolve(checkDependency(name, config)),
      (result) => `${name}: ${result.version || 'not found'}`
    ).catch(error => ({
      name,
      status: config.optional ? 'warning' : 'error',
      message: `Failed to check ${name}: ${error.message}`,
      error
    }));
    
    results.dependencies[name] = result;
    results.summary[result.status] = (results.summary[result.status] || 0) + 1;
  }
  
  // Check environment variables
  results.environmentVariables.required = await withSpinner(
    'Checking required environment variables...',
    () => Promise.resolve(checkEnvironmentVariables(REQUIRED_ENV_VARS, true)),
    (results) => `Environment variables: ${results.filter(r => r.status === 'success').length}/${results.length} set`
  );
  
  results.environmentVariables.optional = await withSpinner(
    'Checking optional environment variables...',
    () => Promise.resolve(checkEnvironmentVariables(OPTIONAL_ENV_VARS, false)),
    (results) => `Optional environment variables: ${results.filter(r => r.status === 'success').length}/${results.length} set`
  );
  
  // Update summary counts
  results.environmentVariables.required.forEach(result => {
    results.summary[result.status] = (results.summary[result.status] || 0) + 1;
  });
  
  results.environmentVariables.optional.forEach(result => {
    results.summary[result.status] = (results.summary[result.status] || 0) + 1;
  });
  
  // Check required files
  results.files = await withSpinner(
    'Checking required files...',
    () => Promise.resolve(checkRequiredFiles(REQUIRED_FILES)),
    (results) => `Required files: ${results.filter(r => r.status === 'success').length}/${results.length} found`
  );
  
  // Update summary counts
  results.files.forEach(result => {
    results.summary[result.status] = (results.summary[result.status] || 0) + 1;
  });
  
  // Check server status
  if (!options.skipServer) {
    results.server = await withSpinner(
      'Checking JuliaOS server status...',
      () => checkServerStatus(),
      (result) => result.status === 'success' ? 
        `Server is running (version ${result.version})` : 
        'Server is not running'
    ).catch(error => ({
      status: 'error',
      message: `Failed to check server: ${error.message}`,
      error
    }));
    
    results.summary[results.server.status] = (results.summary[results.server.status] || 0) + 1;
  }
  
  // Show summary
  if (!options.silent) {
    console.log();
    console.log(chalk.bold('Summary:'));
    console.log(`  ${chalk.green('✓')} ${results.summary.success || 0} checks passed`);
    
    if (results.summary.warning > 0) {
      console.log(`  ${chalk.yellow('⚠')} ${results.summary.warning} warnings`);
    }
    
    if (results.summary.error > 0) {
      console.log(`  ${chalk.red('✗')} ${results.summary.error} errors`);
    }
    
    console.log();
  }
  
  return results;
}

/**
 * Validate health check results and exit if critical errors are found
 * 
 * @param {Object} results - Health check results
 * @param {Object} options - Options
 * @returns {boolean} True if all critical checks passed
 */
function validateHealthCheckResults(results, options = {}) {
  const { exitOnError = true, showWarnings = true } = options;
  
  // Check for critical errors
  const criticalErrors = [];
  
  // Dependency errors
  Object.entries(results.dependencies).forEach(([name, result]) => {
    if (result.status === 'error') {
      criticalErrors.push(`Dependency check failed: ${result.message}`);
    }
  });
  
  // Required environment variables
  results.environmentVariables.required.forEach(result => {
    if (result.status === 'error') {
      criticalErrors.push(`Environment variable check failed: ${result.message}`);
    }
  });
  
  // Required files
  results.files.forEach(result => {
    if (result.status === 'error') {
      criticalErrors.push(`File check failed: ${result.message}`);
    }
  });
  
  // Server status (if checked)
  if (results.server && results.server.status === 'error' && !options.skipServer) {
    criticalErrors.push(`Server check failed: ${results.server.message}`);
  }
  
  // Show errors if any
  if (criticalErrors.length > 0) {
    logError(
      'Health check found critical errors that prevent JuliaOS from starting.',
      'CONFIG',
      'HEALTH_CHECK_FAILED',
      { errors: criticalErrors.length },
      [
        'Fix the reported errors before trying again',
        'Run with --debug for more detailed information',
        'Check the documentation for dependency requirements'
      ]
    );
    
    if (exitOnError) {
      process.exit(1);
    }
    
    return false;
  }
  
  // Show warnings
  if (showWarnings) {
    const warnings = [];
    
    // Dependency warnings
    Object.entries(results.dependencies).forEach(([name, result]) => {
      if (result.status === 'warning') {
        warnings.push(`${name}: ${result.message}`);
      }
    });
    
    // Optional environment variables
    results.environmentVariables.optional.forEach(result => {
      if (result.status === 'warning') {
        warnings.push(`${result.name}: ${result.message}`);
      }
    });
    
    if (warnings.length > 0) {
      showWarning(
        `Health check found ${warnings.length} non-critical issues:\n\n` + 
        warnings.map(w => `• ${w}`).join('\n'),
        'NON-CRITICAL ISSUES'
      );
    }
  }
  
  return true;
}

module.exports = {
  runHealthChecks,
  validateHealthCheckResults,
  checkDependency,
  checkEnvironmentVariables,
  checkRequiredFiles,
  checkServerStatus,
  DEPENDENCIES,
  REQUIRED_ENV_VARS,
  OPTIONAL_ENV_VARS,
  REQUIRED_FILES
};
