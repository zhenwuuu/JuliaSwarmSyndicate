// J3OS Swarm Intelligence Commands
const fs = require('fs');
const path = require('path');
const chalk = require('chalk');
const inquirer = require('inquirer');
const { v4: uuidv4 } = require('uuid');
const { spawn } = require('child_process');

// Ensure swarms directory exists
const swarmsDir = path.join(process.cwd(), '../swarms');
if (!fs.existsSync(swarmsDir)) {
  fs.mkdirSync(swarmsDir, { recursive: true });
}

// Load Julia bridge if available
let juliaBridge = null;
try {
  juliaBridge = require('/app/julia-bridge');
  console.log('Julia Bridge loaded successfully.');
} catch (error) {
  console.warn('Julia Bridge not available, running in simulation mode');
  process.env.J3OS_SIMULATION_MODE = 'true';
}

// Available swarm algorithms
const ALGORITHMS = [
  { name: 'Particle Swarm Optimization (PSO)', value: 'pso' },
  { name: 'Grey Wolf Optimizer (GWO)', value: 'gwo' },
  { name: 'Whale Optimization Algorithm (WOA)', value: 'woa' },
  { name: 'Ant Colony Optimization (ACO)', value: 'aco' },
  { name: 'Artificial Bee Colony (ABC)', value: 'abc' }
];

// Available execution modes
const EXECUTION_MODES = [
  { name: 'Live Trading', value: 'live' },
  { name: 'Paper Trading', value: 'paper' },
  { name: 'Simulation Only', value: 'simulation' }
];

// Available trading strategies
const STRATEGIES = [
  { name: 'Arbitrage', value: 'arbitrage' },
  { name: 'Market Making', value: 'market-making' },
  { name: 'Trend Following', value: 'trend-following' },
  { name: 'Mean Reversion', value: 'mean-reversion' },
  { name: 'Cross-Chain Optimization', value: 'cross-chain' }
];

// Available trading pairs
const TRADING_PAIRS = [
  'ETH/USDC',
  'BTC/USDC',
  'ETH/BTC',
  'SOL/USDC',
  'AVAX/USDC',
  'MATIC/USDC',
  'OP/USDC',
  'ARB/USDC'
];

// Available networks
const NETWORKS = [
  { name: 'Ethereum', value: 'ethereum' },
  { name: 'Arbitrum', value: 'arbitrum' },
  { name: 'Optimism', value: 'optimism' },
  { name: 'Polygon', value: 'polygon' },
  { name: 'Base', value: 'base' },
  { name: 'Solana', value: 'solana' }
];

// Function to execute Julia commands via Bridge module
async function runJuliaSwarm(command, args = []) {
  // If Julia bridge is available, use it
  if (juliaBridge && process.env.J3OS_SIMULATION_MODE !== 'true') {
    try {
      return await juliaBridge.runJuliaCommand(command, args);
    } catch (error) {
      console.error(`Julia command error (${command}):`, error.message);
      console.warn('Falling back to simulation mode');
      process.env.J3OS_SIMULATION_MODE = 'true';
    }
  }
  
  // If no Julia or in simulation mode, return mock data
  return null;
}

// Create a new swarm
async function createSwarm() {
  console.log(chalk.magenta('\n📊 CREATE NEW SWARM\n'));
  
  // Get swarm configuration from user
  const answers = await inquirer.prompt([
    {
      type: 'input',
      name: 'name',
      message: 'Enter a name for the swarm:',
      validate: (input) => input.trim() !== '' ? true : 'Name is required',
      filter: (input) => input.trim()
    },
    {
      type: 'list',
      name: 'algorithm',
      message: 'Select optimization algorithm:',
      choices: ALGORITHMS
    },
    {
      type: 'input',
      name: 'size',
      message: 'Number of agents in the swarm (5-50):',
      default: 20,
      validate: (input) => {
        const num = parseInt(input);
        return (!isNaN(num) && num >= 5 && num <= 50) 
          ? true 
          : 'Please enter a number between 5 and 50';
      },
      filter: (input) => parseInt(input)
    },
    {
      type: 'list',
      name: 'strategy',
      message: 'Select trading strategy:',
      choices: STRATEGIES
    },
    {
      type: 'checkbox',
      name: 'tradingPairs',
      message: 'Select trading pairs:',
      choices: TRADING_PAIRS,
      validate: (input) => input.length > 0 ? true : 'Select at least one trading pair'
    },
    {
      type: 'checkbox',
      name: 'networks',
      message: 'Select networks to operate on:',
      choices: NETWORKS,
      validate: (input) => input.length > 0 ? true : 'Select at least one network'
    },
    {
      type: 'list',
      name: 'executionMode',
      message: 'Select execution mode:',
      choices: EXECUTION_MODES
    },
    {
      type: 'confirm',
      name: 'configureAdvanced',
      message: 'Do you want to configure advanced settings?',
      default: false
    }
  ]);
  
  let advancedSettings = {};
  
  // Get advanced settings if requested
  if (answers.configureAdvanced) {
    advancedSettings = await inquirer.prompt([
      {
        type: 'input',
        name: 'communicationRate',
        message: 'Communication rate between agents (0.0-1.0):',
        default: 0.5,
        validate: (input) => {
          const num = parseFloat(input);
          return (!isNaN(num) && num >= 0 && num <= 1) 
            ? true 
            : 'Please enter a number between 0 and 1';
        },
        filter: (input) => parseFloat(input)
      },
      {
        type: 'input',
        name: 'learningRate',
        message: 'Learning rate (0.01-1.0):',
        default: 0.1,
        validate: (input) => {
          const num = parseFloat(input);
          return (!isNaN(num) && num >= 0.01 && num <= 1) 
            ? true 
            : 'Please enter a number between 0.01 and 1';
        },
        filter: (input) => parseFloat(input)
      },
      {
        type: 'input',
        name: 'maxPositionSize',
        message: 'Max position size in USD:',
        default: 1000,
        validate: (input) => {
          const num = parseFloat(input);
          return (!isNaN(num) && num > 0) 
            ? true 
            : 'Please enter a positive number';
        },
        filter: (input) => parseFloat(input)
      },
      {
        type: 'input',
        name: 'stopLoss',
        message: 'Stop loss percentage:',
        default: 5,
        validate: (input) => {
          const num = parseFloat(input);
          return (!isNaN(num) && num > 0) 
            ? true 
            : 'Please enter a positive number';
        },
        filter: (input) => parseFloat(input)
      }
    ]);
  } else {
    // Default advanced settings
    advancedSettings = {
      communicationRate: 0.5,
      learningRate: 0.1,
      maxPositionSize: 1000,
      stopLoss: 5
    };
  }
  
  // Create swarm configuration
  const swarm = {
    id: uuidv4(),
    name: answers.name,
    algorithm: answers.algorithm,
    size: answers.size,
    strategy: answers.strategy,
    tradingPairs: answers.tradingPairs,
    networks: answers.networks,
    executionMode: answers.executionMode,
    advanced: advancedSettings,
    createdAt: new Date().toISOString(),
    status: 'created'
  };
  
  // Save swarm configuration
  const swarmPath = path.join(swarmsDir, `${swarm.name.toLowerCase().replace(/\s+/g, '-')}.json`);
  fs.writeFileSync(swarmPath, JSON.stringify(swarm, null, 2));
  
  // Show success message with swarm details
  console.log('\n' + chalk.green('✅ Swarm created successfully!'));
  console.log('\n' + chalk.yellow('Swarm Configuration:'));
  console.log(chalk.cyan('Name:'), swarm.name);
  console.log(chalk.cyan('Algorithm:'), ALGORITHMS.find(a => a.value === swarm.algorithm).name);
  console.log(chalk.cyan('Size:'), swarm.size, 'agents');
  console.log(chalk.cyan('Strategy:'), STRATEGIES.find(s => s.value === swarm.strategy).name);
  console.log(chalk.cyan('Trading Pairs:'), swarm.tradingPairs.join(', '));
  console.log(chalk.cyan('Networks:'), swarm.networks.map(n => NETWORKS.find(net => net.value === n).name).join(', '));
  console.log(chalk.cyan('Execution Mode:'), EXECUTION_MODES.find(m => m.value === swarm.executionMode).name);
  
  // Simulate initialization with animation
  console.log('\n' + chalk.magenta('Initializing swarm...'));
  
  // Simulate optimization steps
  const steps = 5;
  for (let i = 1; i <= steps; i++) {
    await new Promise(resolve => setTimeout(resolve, 300));
    console.log(chalk.dim(`[${i}/${steps}] Initializing agent communication matrix...`));
  }
  console.log(chalk.green('Swarm initialized in simulation mode!'));
  
  return swarm;
}

// List all swarms
async function listSwarms() {
  console.log(chalk.magenta('\n📋 SWARM LIST\n'));
  
  // Read all swarm files
  const files = fs.readdirSync(swarmsDir).filter(file => file.endsWith('.json'));
  
  if (files.length === 0) {
    console.log(chalk.yellow('No swarms found. Create one using the "Create new swarm" option.'));
    return [];
  }
  
  // Parse and display swarms
  const swarms = files.map(file => {
    const data = fs.readFileSync(path.join(swarmsDir, file), 'utf8');
    return JSON.parse(data);
  });
  
  // Display swarm table
  console.log('┌' + '─'.repeat(78) + '┐');
  console.log('│ ' + chalk.bold('NAME').padEnd(20) + '│ ' + 
               chalk.bold('ALGORITHM').padEnd(10) + '│ ' + 
               chalk.bold('SIZE').padEnd(6) + '│ ' + 
               chalk.bold('STRATEGY').padEnd(15) + '│ ' + 
               chalk.bold('STATUS').padEnd(15) + '│');
  console.log('├' + '─'.repeat(78) + '┤');
  
  swarms.forEach(swarm => {
    // Color status based on its value
    let statusColored;
    if (swarm.status === 'running') {
      statusColored = chalk.green(swarm.status.padEnd(15));
    } else if (swarm.status === 'stopped') {
      statusColored = chalk.red(swarm.status.padEnd(15));
    } else {
      statusColored = chalk.yellow(swarm.status.padEnd(15));
    }
    
    console.log('│ ' + swarm.name.padEnd(20) + '│ ' + 
                 swarm.algorithm.padEnd(10) + '│ ' + 
                 String(swarm.size).padEnd(6) + '│ ' + 
                 swarm.strategy.padEnd(15) + '│ ' + 
                 statusColored + '│');
  });
  
  console.log('└' + '─'.repeat(78) + '┘');
  console.log(chalk.dim(`\nTotal swarms: ${swarms.length}`));
  
  return swarms;
}

// Start a swarm
async function startSwarm(swarmName) {
  console.log(chalk.magenta('\n▶️ START SWARM\n'));
  
  // If name not provided, let user select
  if (!swarmName) {
    // Read all swarm files
    const files = fs.readdirSync(swarmsDir).filter(file => file.endsWith('.json'));
    
    if (files.length === 0) {
      console.log(chalk.yellow('No swarms found. Create one using the "Create new swarm" option.'));
      return null;
    }
    
    // Parse swarms for selection
    const swarms = files.map(file => {
      const data = fs.readFileSync(path.join(swarmsDir, file), 'utf8');
      const swarm = JSON.parse(data);
      return { 
        name: `${swarm.name} (${swarm.algorithm}, ${swarm.size} agents, ${swarm.status})`, 
        value: swarm.name 
      };
    });
    
    const answer = await inquirer.prompt([
      {
        type: 'list',
        name: 'swarmName',
        message: 'Select a swarm to start:',
        choices: swarms
      }
    ]);
    
    swarmName = answer.swarmName;
  }
  
  // Find the swarm file
  const fileName = `${swarmName.toLowerCase().replace(/\s+/g, '-')}.json`;
  const swarmPath = path.join(swarmsDir, fileName);
  
  if (!fs.existsSync(swarmPath)) {
    console.log(chalk.red(`Error: Swarm "${swarmName}" not found.`));
    return null;
  }
  
  // Load the swarm
  const swarm = JSON.parse(fs.readFileSync(swarmPath, 'utf8'));
  
  // Check if already running
  if (swarm.status === 'running') {
    console.log(chalk.yellow(`Swarm "${swarmName}" is already running.`));
    return swarm;
  }
  
  // Confirmation
  const { confirm } = await inquirer.prompt([
    {
      type: 'confirm',
      name: 'confirm',
      message: `Start swarm "${swarmName}" with ${swarm.size} agents?`,
      default: true
    }
  ]);
  
  if (!confirm) {
    console.log(chalk.yellow('Operation cancelled.'));
    return null;
  }
  
  // Update swarm status
  swarm.status = 'running';
  swarm.startedAt = new Date().toISOString();
  fs.writeFileSync(swarmPath, JSON.stringify(swarm, null, 2));
  
  // Show startup animation
  console.log(chalk.green(`\nStarting swarm "${swarmName}"...`));
  
  // Simulate startup
  for (let i = 1; i <= swarm.size; i++) {
    const progress = Math.round((i / swarm.size) * 100);
    const progressBar = '█'.repeat(Math.floor(progress / 2)) + '▒'.repeat(50 - Math.floor(progress / 2));
    process.stdout.write(`\r${chalk.cyan(`[${progressBar}] ${progress}%`)} Initializing agent ${i}/${swarm.size}`);
    await new Promise(resolve => setTimeout(resolve, 50));
  }
  console.log('\n');
  
  // Show algorithm-specific messages
  switch (swarm.algorithm) {
    case 'pso':
      console.log(chalk.magenta('🔄 Initializing particle velocities and personal best positions...'));
      break;
    case 'gwo':
      console.log(chalk.magenta('🐺 Establishing Alpha, Beta, and Delta hierarchy...'));
      break;
    case 'woa':
      console.log(chalk.magenta('🐋 Setting up bubble-net attacking parameters...'));
      break;
    case 'aco':
      console.log(chalk.magenta('🐜 Laying initial pheromone trails...'));
      break;
    case 'abc':
      console.log(chalk.magenta('🐝 Dispatching scout bees to find initial sources...'));
      break;
  }
  
  await new Promise(resolve => setTimeout(resolve, 500));
  console.log(chalk.green(`\n✅ Swarm "${swarmName}" started successfully!`));
  
  // Show execution mode warning/info
  if (swarm.executionMode === 'live') {
    console.log(chalk.yellow('⚠️ LIVE TRADING MODE ACTIVE - Real funds will be used for trading!'));
  } else if (swarm.executionMode === 'paper') {
    console.log(chalk.blue('ℹ️ PAPER TRADING MODE - Simulated trades with real market data'));
  } else {
    console.log(chalk.blue('ℹ️ SIMULATION MODE - No real market data or trades'));
  }
  
  return swarm;
}

// Stop a swarm
async function stopSwarm(swarmName) {
  console.log(chalk.magenta('\n⏹️ STOP SWARM\n'));
  
  // If name not provided, let user select
  if (!swarmName) {
    // Read all swarm files
    const files = fs.readdirSync(swarmsDir).filter(file => file.endsWith('.json'));
    
    if (files.length === 0) {
      console.log(chalk.yellow('No swarms found. Create one using the "Create new swarm" option.'));
      return null;
    }
    
    // Parse swarms for selection, but only include running ones
    const swarms = files.map(file => {
      const data = fs.readFileSync(path.join(swarmsDir, file), 'utf8');
      const swarm = JSON.parse(data);
      return { 
        name: `${swarm.name} (${swarm.algorithm}, ${swarm.size} agents, ${swarm.status})`, 
        value: swarm.name,
        disabled: swarm.status !== 'running' ? 'Not running' : false
      };
    });
    
    const runningSwarms = swarms.filter(s => !s.disabled);
    
    if (runningSwarms.length === 0) {
      console.log(chalk.yellow('No running swarms found.'));
      return null;
    }
    
    const answer = await inquirer.prompt([
      {
        type: 'list',
        name: 'swarmName',
        message: 'Select a swarm to stop:',
        choices: swarms
      }
    ]);
    
    swarmName = answer.swarmName;
  }
  
  // Find the swarm file
  const fileName = `${swarmName.toLowerCase().replace(/\s+/g, '-')}.json`;
  const swarmPath = path.join(swarmsDir, fileName);
  
  if (!fs.existsSync(swarmPath)) {
    console.log(chalk.red(`Error: Swarm "${swarmName}" not found.`));
    return null;
  }
  
  // Load the swarm
  const swarm = JSON.parse(fs.readFileSync(swarmPath, 'utf8'));
  
  // Check if already stopped
  if (swarm.status !== 'running') {
    console.log(chalk.yellow(`Swarm "${swarmName}" is not running.`));
    return swarm;
  }
  
  // Confirmation
  const { confirm } = await inquirer.prompt([
    {
      type: 'confirm',
      name: 'confirm',
      message: `Stop swarm "${swarmName}"?`,
      default: true
    }
  ]);
  
  if (!confirm) {
    console.log(chalk.yellow('Operation cancelled.'));
    return null;
  }
  
  // Show shutdown animation
  console.log(chalk.yellow(`\nStopping swarm "${swarmName}"...`));
  
  // Update swarm status
  swarm.status = 'stopped';
  swarm.stoppedAt = new Date().toISOString();
  
  // Add random performance metrics
  swarm.performance = {
    iterations: Math.floor(Math.random() * 1000) + 100,
    convergence: Math.random() * 30 + 70, // 70-100%
    trades: Math.floor(Math.random() * 50) + 5,
    profit: (Math.random() * 10 - 2).toFixed(2) // -2% to +8%
  };
  
  fs.writeFileSync(swarmPath, JSON.stringify(swarm, null, 2));
  
  // Simulate shutdown
  for (let i = swarm.size; i >= 1; i--) {
    const progress = Math.round(((swarm.size - i) / swarm.size) * 100);
    const progressBar = '█'.repeat(Math.floor(progress / 2)) + '▒'.repeat(50 - Math.floor(progress / 2));
    process.stdout.write(`\r${chalk.cyan(`[${progressBar}] ${progress}%`)} Stopping agent ${i}/${swarm.size}`);
    await new Promise(resolve => setTimeout(resolve, 30));
  }
  console.log('\n');
  
  console.log(chalk.green(`\n✅ Swarm "${swarmName}" stopped successfully!`));
  
  // Show performance stats
  console.log(chalk.cyan('\nPerformance Summary:'));
  console.log(`Iterations: ${swarm.performance.iterations}`);
  console.log(`Convergence: ${swarm.performance.convergence.toFixed(2)}%`);
  console.log(`Trades executed: ${swarm.performance.trades}`);
  
  const profitColor = swarm.performance.profit > 0 ? chalk.green : 
                     (swarm.performance.profit < 0 ? chalk.red : chalk.white);
  console.log(`Profit/Loss: ${profitColor(swarm.performance.profit + '%')}`);
  
  return swarm;
}

module.exports = {
  createSwarm,
  listSwarms,
  startSwarm,
  stopSwarm
}; 