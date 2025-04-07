/**
 * JuliaOS CLI - Server Helper Module
 * 
 * Provides functions for managing the Julia server process.
 */

const { spawn } = require('child_process');
const { execSync } = require('child_process');
const fs = require('fs-extra');
const path = require('path');
const os = require('os');

/**
 * Find the Julia executable
 * @returns {string} Path to the Julia executable
 */
function findJuliaExecutable() {
  try {
    // Check if julia is in PATH
    execSync('julia --version');
    return 'julia';
  } catch (e) {
    // Try common installation locations
    const locations = [
      '/usr/bin/julia',
      '/usr/local/bin/julia',
      '/opt/julia/bin/julia',
      'C:\\Julia\\bin\\julia.exe',
      'C:\\Program Files\\Julia\\bin\\julia.exe',
      path.join(os.homedir(), 'AppData', 'Local', 'Programs', 'Julia', 'bin', 'julia.exe')
    ];
    
    for (const location of locations) {
      if (fs.existsSync(location)) {
        return location;
      }
    }
    
    throw new Error('Julia executable not found. Please install Julia 1.8 or later.');
  }
}

/**
 * Start the Julia server
 * @param {string} serverPath - Path to the standalone_server.jl file
 * @returns {ChildProcess|null} The server process or null if failed
 */
function startServer(serverPath) {
  if (!serverPath || !fs.existsSync(serverPath)) {
    console.error(`Error: Server file not found at ${serverPath}`);
    return null;
  }
  
  try {
    const juliaExecutable = findJuliaExecutable();
    console.log(`Starting Julia server from ${serverPath} using ${juliaExecutable}`);
    
    const serverProcess = spawn(juliaExecutable, [serverPath], {
      stdio: 'inherit',
      detached: false
    });
    
    serverProcess.on('error', (err) => {
      console.error(`Failed to start Julia server: ${err.message}`);
    });
    
    return serverProcess;
  } catch (error) {
    console.error(`Error starting Julia server: ${error.message}`);
    return null;
  }
}

/**
 * Stop the Julia server
 * @param {ChildProcess} serverProcess - The server process to stop
 */
function stopServer(serverProcess) {
  if (serverProcess && !serverProcess.killed) {
    console.log('Stopping Julia server...');
    serverProcess.kill();
  }
}

/**
 * Check if the Julia server is running
 * @param {number} port - Port number to check (default: 8052)
 * @returns {Promise<boolean>} True if the server is running
 */
async function isServerRunning(port = 8052) {
  try {
    const response = await fetch(`http://localhost:${port}/health`);
    return response.ok;
  } catch (error) {
    return false;
  }
}

module.exports = {
  startServer,
  stopServer,
  isServerRunning,
  findJuliaExecutable
}; 