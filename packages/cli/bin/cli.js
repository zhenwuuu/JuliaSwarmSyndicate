#!/usr/bin/env node

/**
 * JuliaOS CLI - Enhanced Entry Point with Robust Path Resolution
 *
 * This script handles path resolution and launches the interactive CLI.
 * The path resolution logic has been enhanced to address the directory
 * navigation issues visible in the error logs.
 */

const fs = require('fs-extra');
const path = require('path');
const { execSync, spawn } = require('child_process');
const os = require('os');

// Enhanced path resolution for the Julia server
function findJuliaServer() {
  console.log('Current working directory:', process.cwd());

  // Check an extensive list of possible locations
  const locations = [
    // Current directory variations
    path.resolve(process.cwd(), 'standalone_server.jl'),
    path.resolve(process.cwd(), 'julia_server.jl'),
    path.resolve(process.cwd(), 'julia/standalone_server.jl'),
    path.resolve(process.cwd(), 'julia/julia_server.jl'),

    // Parent directory variations
    path.resolve(process.cwd(), '../standalone_server.jl'),
    path.resolve(process.cwd(), '../julia_server.jl'),
    path.resolve(process.cwd(), '../julia/standalone_server.jl'),
    path.resolve(process.cwd(), '../julia/julia_server.jl'),
    path.resolve(process.cwd(), '../../julia/standalone_server.jl'),
    path.resolve(process.cwd(), '../../julia/julia_server.jl'),

    // Sibling directory variations
    path.resolve(process.cwd(), '../JuliaOS/julia/standalone_server.jl'),
    path.resolve(process.cwd(), '../JuliaOS/julia/julia_server.jl'),
    path.resolve(process.cwd(), '../juliaos/julia/standalone_server.jl'),
    path.resolve(process.cwd(), '../juliaos/julia/julia_server.jl'),

    // Common absolute paths (for desktop installs)
    path.resolve(os.homedir(), 'JuliaOS/julia/standalone_server.jl'),
    path.resolve(os.homedir(), 'JuliaOS/julia/julia_server.jl'),
    path.resolve(os.homedir(), 'Desktop/JuliaOS/julia/standalone_server.jl'),
    path.resolve(os.homedir(), 'Desktop/JuliaOS/julia/julia_server.jl'),
    path.resolve(os.homedir(), 'Documents/JuliaOS/julia/standalone_server.jl'),
    path.resolve(os.homedir(), 'Documents/JuliaOS/julia/julia_server.jl'),

    // Packaged version location
    path.resolve(__dirname, '../server/standalone_server.jl'),
    path.resolve(__dirname, '../server/julia_server.jl'),

    // Global installation location
    path.resolve(os.homedir(), '.juliaos/server/standalone_server.jl'),
    path.resolve(os.homedir(), '.juliaos/server/julia_server.jl')
  ];

  // Try each location and return the first that exists
  for (const location of locations) {
    if (fs.existsSync(location)) {
      console.log(`Found Julia server at: ${location}`);
      return location;
    }
  }

  // If not found in common locations, recursively search up the directory tree
  let currentDir = process.cwd();
  const rootDir = path.parse(currentDir).root;

  while (currentDir !== rootDir) {
    // Check for julia subdirectory
    const juliaDir = path.join(currentDir, 'julia');
    const serverFiles = [
      path.join(juliaDir, 'standalone_server.jl'),
      path.join(juliaDir, 'julia_server.jl')
    ];

    for (const serverFile of serverFiles) {
      if (fs.existsSync(serverFile)) {
        console.log(`Found Julia server at: ${serverFile}`);
        return serverFile;
      }
    }

    // Move up one directory
    currentDir = path.dirname(currentDir);
  }

  console.error('Error: Could not find Julia server file (standalone_server.jl or julia_server.jl)');
  console.error('Please run this command from the JuliaOS repository or install the CLI globally');
  return null;
}

// Check if Julia is installed and accessible
function checkJuliaInstallation() {
  try {
    const output = execSync('julia --version').toString().trim();
    console.log(`Julia is installed: ${output}`);
    return true;
  } catch (error) {
    console.error('Error: Julia is not installed or not in PATH');
    console.error('Please install Julia 1.8 or later from https://julialang.org/downloads/');
    return false;
  }
}

// Start the Julia server as a child process
function startJuliaServer(serverPath) {
  if (!serverPath) return null;

  console.log(`Starting Julia server from ${serverPath}`);

  try {
    const juliaProcess = spawn('julia', [serverPath], {
      stdio: 'inherit',
      detached: false
    });

    juliaProcess.on('error', (err) => {
      console.error(`Failed to start Julia server: ${err.message}`);
    });

    return juliaProcess;
  } catch (error) {
    console.error(`Error starting Julia server: ${error.message}`);
    return null;
  }
}

// Main function
async function main() {
  // Check Julia installation
  if (!checkJuliaInstallation()) {
    process.exit(1);
  }

  // Find Julia server
  const serverPath = findJuliaServer();
  if (!serverPath) {
    process.exit(1);
  }

  // Configure Julia bridge
  const { JuliaBridge } = require('@juliaos/julia-bridge');

  try {
    // Start server (if it's not already running)
    const useExistingServer = process.argv.includes('--use-existing-server');
    let juliaProcess = null;

    if (!useExistingServer) {
      juliaProcess = startJuliaServer(serverPath);

      // Give the server a moment to start
      await new Promise(resolve => setTimeout(resolve, 2000));
    }

    // Initialize JuliaBridge
    global.juliaBridge = new JuliaBridge({
      apiUrl: 'http://localhost:8052/api',
      useExistingServer: true
    });

    // Launch interactive CLI
    require('../src/interactive');

    // Clean up on exit
    process.on('exit', () => {
      if (juliaProcess) {
        console.log('Shutting down Julia server...');
        juliaProcess.kill();
      }
    });

    // Handle signals
    process.on('SIGINT', () => {
      console.log('\nCLI interrupted. Shutting down...');
      if (juliaProcess) juliaProcess.kill();
      process.exit(0);
    });

  } catch (error) {
    console.error(`Error initializing JuliaBridge: ${error.message}`);
    process.exit(1);
  }
}

// Run the main function
main().catch(err => {
  console.error('Unhandled error:', err);
  process.exit(1);
});