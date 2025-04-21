#!/usr/bin/env node

/**
 * Start Julia Server
 *
 * This script starts the Julia server and waits for it to be ready
 * before returning control to the caller.
 */

const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');
const chalk = require('chalk');
const ora = require('ora');

// Configuration
const JULIA_SERVER_PATH = path.join(__dirname, '..', 'julia', 'server', 'julia_server.jl');
const JULIA_SERVER_PORT = process.env.JULIA_SERVER_PORT || 8052;
const JULIA_SERVER_HOST = process.env.JULIA_SERVER_HOST || 'localhost';
const HEALTH_CHECK_URL = process.env.JULIA_SERVER_URL || `http://${JULIA_SERVER_HOST}:${JULIA_SERVER_PORT}/health`;
const MAX_STARTUP_TIME = 60000; // 60 seconds
const HEALTH_CHECK_INTERVAL = 1000; // 1 second

/**
 * Find Julia executable on the system
 */
function findJuliaExecutable() {
  // Check common paths based on OS
  const platform = process.platform;
  const possiblePaths = [];

  if (platform === 'win32') {
    possiblePaths.push(
      'C:\\Program Files\\Julia\\bin\\julia.exe',
      'C:\\Program Files (x86)\\Julia\\bin\\julia.exe'
    );
  } else if (platform === 'darwin') {
    possiblePaths.push(
      '/Applications/Julia-1.9.app/Contents/Resources/julia/bin/julia',
      '/usr/local/bin/julia',
      '/opt/homebrew/bin/julia'
    );
  } else {
    // Linux and other Unix-like systems
    possiblePaths.push(
      '/usr/bin/julia',
      '/usr/local/bin/julia'
    );
  }

  // Check if Julia is in PATH
  try {
    const { execSync } = require('child_process');
    const juliaPath = execSync('which julia', { encoding: 'utf8' }).trim();
    if (juliaPath) {
      return juliaPath;
    }
  } catch (error) {
    // which command failed, continue with other checks
  }

  // Check if any of the possible paths exist
  for (const juliaPath of possiblePaths) {
    if (fs.existsSync(juliaPath)) {
      return juliaPath;
    }
  }

  // Default to 'julia' and hope it's in the PATH
  return 'julia';
}

/**
 * Check if the Julia server is running
 */
async function checkServerHealth() {
  try {
    console.log(`Checking Julia server health at ${HEALTH_CHECK_URL}...`);
    const response = await fetch(HEALTH_CHECK_URL, { timeout: 5000 });
    if (response.ok) {
      const data = await response.json();
      const isHealthy = data.status === 'healthy';
      console.log(`Julia server health check: ${isHealthy ? 'healthy' : 'unhealthy'}`);
      return isHealthy;
    }
    console.log('Julia server health check failed: server responded with an error');
    return false;
  } catch (error) {
    console.log(`Julia server health check failed: ${error.message}`);

    // Try a direct API request as a fallback
    try {
      const apiUrl = HEALTH_CHECK_URL.replace('/health', '/api');
      console.log(`Trying API endpoint at ${apiUrl}...`);
      const apiResponse = await fetch(apiUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          command: 'system.ping',
          params: {}
        }),
        timeout: 5000
      });

      if (apiResponse.ok) {
        console.log('API endpoint responded successfully');
        return true;
      }
      console.log('API endpoint check failed: server responded with an error');
      return false;
    } catch (apiError) {
      console.log(`API endpoint check failed: ${apiError.message}`);
      return false;
    }
  }
}

/**
 * Start the Julia server
 */
async function startJuliaServer() {
  const spinner = ora('Starting Julia server...').start();

  // Check if server is already running
  const serverRunning = await checkServerHealth();
  if (serverRunning) {
    spinner.succeed('Julia server is already running');
    return true;
  }

  // Find Julia executable
  const juliaPath = findJuliaExecutable();
  spinner.text = `Starting Julia server using ${juliaPath}...`;

  // Check if server script exists
  if (!fs.existsSync(JULIA_SERVER_PATH)) {
    spinner.fail(`Julia server script not found at ${JULIA_SERVER_PATH}`);
    return false;
  }

  // Check if the julia directory exists
  const juliaDir = path.dirname(JULIA_SERVER_PATH);
  if (!fs.existsSync(juliaDir)) {
    spinner.fail(`Julia directory not found at ${juliaDir}`);
    return false;
  }

  // Check if the Julia project has the required files
  const projectFile = path.join(juliaDir, 'Project.toml');
  if (!fs.existsSync(projectFile)) {
    spinner.warn(`Julia project file not found at ${projectFile}. The server may not start correctly.`);
  }

  // Start the server with improved error handling
  let serverProcess;
  try {
    // Start the server with improved environment variables
    const env = { ...process.env };
    env.JULIA_PROJECT = juliaDir; // Ensure Julia uses the correct project
    env.JULIA_LOAD_PATH = `${juliaDir}:${env.JULIA_LOAD_PATH || ''}`; // Add project to load path

    serverProcess = spawn(juliaPath, [JULIA_SERVER_PATH], {
      cwd: juliaDir,
      stdio: 'pipe',
      env: env
    });
  } catch (spawnError) {
    spinner.fail(`Failed to start Julia server: ${spawnError.message}`);
    return false;
  }

  // Handle server output with improved logging
  let serverOutput = '';
  serverProcess.stdout.on('data', (data) => {
    const output = data.toString();
    serverOutput += output;
    spinner.text = `Julia server output: ${output.trim()}`;
    if (output.includes('Server started successfully') ||
        output.includes('Simple HTTP server started successfully') ||
        output.includes('Server is running') ||
        output.includes('HTTP server listening')) {
      spinner.text = 'Julia server started, waiting for it to be ready...';
    }
  });

  let serverErrors = '';
  serverProcess.stderr.on('data', (data) => {
    const error = data.toString();
    serverErrors += error;
    spinner.text = `Julia server error: ${error.trim()}`;
  });

  // Handle process errors
  serverProcess.on('error', (error) => {
    spinner.fail(`Julia server process error: ${error.message}`);
  });

  // Wait for server to be ready with improved timeout handling
  const startTime = Date.now();
  let lastCheckTime = 0;
  let checkCount = 0;
  const maxChecks = 30; // Maximum number of health checks before giving up

  while (Date.now() - startTime < MAX_STARTUP_TIME) {
    // Only check health every HEALTH_CHECK_INTERVAL milliseconds
    if (Date.now() - lastCheckTime >= HEALTH_CHECK_INTERVAL) {
      lastCheckTime = Date.now();
      checkCount++;

      spinner.text = `Checking server health (attempt ${checkCount}/${maxChecks})...`;
      const healthy = await checkServerHealth();

      if (healthy) {
        spinner.succeed('Julia server is running and healthy');
        return true;
      }

      // If we've made too many checks, try restarting the server
      if (checkCount >= maxChecks / 2 && checkCount < maxChecks) {
        spinner.warn('Server not responding to health checks. Continuing to wait...');
      } else if (checkCount >= maxChecks) {
        spinner.fail('Maximum health check attempts reached');
        break;
      }
    }

    // Check if the process has exited
    if (serverProcess.exitCode !== null) {
      spinner.fail(`Julia server process exited with code ${serverProcess.exitCode}`);
      console.log('Server output:', serverOutput);
      console.log('Server errors:', serverErrors);
      return false;
    }

    // Wait before checking again
    await new Promise(resolve => setTimeout(resolve, 100)); // Short delay to avoid CPU spinning
    spinner.text = `Waiting for Julia server to be ready... (${Math.round((Date.now() - startTime) / 1000)}s)`;
  }

  // If we get here, we've timed out
  spinner.fail('Timeout waiting for Julia server to be ready');
  console.log('Server output:', serverOutput);
  console.log('Server errors:', serverErrors);

  // Try to kill the process if it's still running
  try {
    if (serverProcess.exitCode === null) {
      serverProcess.kill();
      spinner.text = 'Killed Julia server process due to timeout';
    }
  } catch (error) {
    spinner.text = `Error killing Julia server process: ${error.message}`;
  }

  return false;
}

// If this script is run directly, start the server
if (require.main === module) {
  startJuliaServer()
    .then(success => {
      if (!success) {
        console.error(chalk.red('Failed to start Julia server'));
        process.exit(1);
      }
    })
    .catch(error => {
      console.error(chalk.red(`Error starting Julia server: ${error.message}`));
      process.exit(1);
    });
}

module.exports = { startJuliaServer, checkServerHealth };
