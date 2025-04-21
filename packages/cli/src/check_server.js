#!/usr/bin/env node

/**
 * JuliaOS Server Connection Check
 * 
 * This script checks if the Julia server is running and can be connected to.
 */

const chalk = require('chalk');
const ora = require('ora');
const { JuliaBridge } = require('../../julia-bridge');

async function main() {
  console.log(chalk.bold.blue('JuliaOS Server Connection Check'));
  console.log(chalk.blue('===============================\n'));
  
  const spinner = ora('Connecting to Julia server...').start();
  
  // Initialize Julia bridge
  const bridge = new JuliaBridge({
    useExistingServer: true,
    serverPort: 8052,
    apiUrl: 'http://localhost:8052/api/v1',
    healthUrl: 'http://localhost:8052/health',
    wsUrl: 'ws://localhost:8052',
    debug: false
  });
  
  try {
    // Try to get server health
    const health = await bridge.getHealth();
    
    if (health && health.status === 'ok') {
      spinner.succeed('Server connection successful');
      console.log(chalk.green('\nServer is running and responding to health checks.'));
      console.log(chalk.green('You can now run the interactive CLI with:'));
      console.log(chalk.green('node scripts/interactive.cjs'));
    } else {
      spinner.fail('Server returned unexpected health status');
      console.log(chalk.yellow('\nServer is running but returned an unexpected health status:'));
      console.log(health);
      console.log(chalk.yellow('\nThis might indicate issues with the server configuration.'));
    }
  } catch (error) {
    spinner.fail(`Server connection failed: ${error.message}`);
    console.log(chalk.red('\nCould not connect to the Julia server. Please ensure:'));
    console.log(chalk.red('1. The server is running (cd julia && julia julia_server.jl)'));
    console.log(chalk.red('2. The server is listening on port 8052'));
    console.log(chalk.red('3. There are no firewall issues blocking the connection'));
    console.log(chalk.red('\nError details:'));
    console.log(chalk.red(error.message));
    
    // Check if the error is related to ECONNREFUSED
    if (error.message.includes('ECONNREFUSED')) {
      console.log(chalk.yellow('\nTrying to start the server automatically...'));
      
      const { spawn } = require('child_process');
      const serverProcess = spawn('julia', ['julia/julia_server.jl'], {
        cwd: process.cwd(),
        detached: true,
        stdio: 'inherit'
      });
      
      console.log(chalk.yellow('\nServer process started. Please wait a moment for it to initialize.'));
      console.log(chalk.yellow('Then run this script again to check the connection.'));
    }
  }
}

// Run the main function
main().catch(error => {
  console.error(chalk.red(`Error: ${error.message}`));
  process.exit(1);
});
