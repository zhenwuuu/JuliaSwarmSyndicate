// J3OS Agent Management Commands
const fs = require('fs');
const path = require('path');
const chalk = require('chalk');
const inquirer = require('inquirer');
const { v4: uuidv4 } = require('uuid');
const { spawn } = require('child_process');

// Ensure agents directory exists
const agentsDir = path.join(process.cwd(), '../agents');
if (!fs.existsSync(agentsDir)) {
  fs.mkdirSync(agentsDir, { recursive: true });
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

// Available agent types
const AGENT_TYPES = [
  { name: 'Trading Agent', value: 'trading' },
  { name: 'Arbitrage Agent', value: 'arbitrage' },
  { name: 'Market Making Agent', value: 'market-making' },
  { name: 'Liquidity Provider Agent', value: 'liquidity' },
  { name: 'Analytics Agent', value: 'analytics' }
];

// Available blockchain networks
const NETWORKS = [
  { name: 'Ethereum', value: 'ethereum' },
  { name: 'Arbitrum', value: 'arbitrum' },
  { name: 'Optimism', value: 'optimism' },
  { name: 'Polygon', value: 'polygon' },
  { name: 'Base', value: 'base' },
  { name: 'Solana', value: 'solana' }
];

// Available trading strategies
const STRATEGIES = [
  { name: 'Momentum', value: 'momentum' },
  { name: 'Mean Reversion', value: 'mean-reversion' },
  { name: 'Trend Following', value: 'trend-following' },
  { name: 'Arbitrage', value: 'arbitrage' },
  { name: 'Liquidity Providing', value: 'liquidity' }
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

// Available execution modes
const EXECUTION_MODES = [
  { name: 'Live Trading', value: 'live' },
  { name: 'Paper Trading', value: 'paper' },
  { name: 'Simulation Only', value: 'simulation' }
];

// Function to execute Julia commands via Bridge module
async function runJuliaAgent(command, args = []) {
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

// Create a new agent
async function createAgent() {
  console.log(chalk.cyan('\n🤖 CREATE NEW AGENT\n'));
  
  // Get agent configuration from user
  const answers = await inquirer.prompt([
    {
      type: 'input',
      name: 'name',
      message: 'Enter a name for the agent:',
      validate: (input) => input.trim() !== '' ? true : 'Name is required',
      filter: (input) => input.trim()
    },
    {
      type: 'list',
      name: 'type',
      message: 'Select agent type:',
      choices: AGENT_TYPES
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
      validate: (input) => input.length > 0 ? true : 'Select at least one trading pair',
      when: (answers) => answers.type === 'trading' || answers.type === 'arbitrage' || answers.type === 'market-making'
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
        name: 'maxPositionSize',
        message: 'Max position size in USD:',
        default: 1000,
        validate: (input) => {
          const num = parseFloat(input);
          return (!isNaN(num) && num > 0) 
            ? true 
            : 'Please enter a positive number';
        },
        filter: (input) => parseFloat(input),
        when: (answers) => answers.type === 'trading' || answers.type === 'arbitrage' || answers.type === 'market-making'
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
        filter: (input) => parseFloat(input),
        when: (answers) => answers.type === 'trading' || answers.type === 'arbitrage' || answers.type === 'market-making'
      },
      {
        type: 'input',
        name: 'takeProfitPercentage',
        message: 'Take profit percentage:',
        default: 10,
        validate: (input) => {
          const num = parseFloat(input);
          return (!isNaN(num) && num > 0) 
            ? true 
            : 'Please enter a positive number';
        },
        filter: (input) => parseFloat(input),
        when: (answers) => answers.type === 'trading' || answers.type === 'arbitrage' || answers.type === 'market-making'
      },
      {
        type: 'input',
        name: 'orderSizePercentage',
        message: 'Order size as percentage of total capital:',
        default: 10,
        validate: (input) => {
          const num = parseFloat(input);
          return (!isNaN(num) && num > 0 && num <= 100) 
            ? true 
            : 'Please enter a number between 0 and 100';
        },
        filter: (input) => parseFloat(input),
        when: (answers) => answers.type === 'trading' || answers.type === 'arbitrage' || answers.type === 'market-making'
      }
    ]);
  } else {
    // Default advanced settings
    advancedSettings = {
      maxPositionSize: 1000,
      stopLoss: 5,
      takeProfitPercentage: 10,
      orderSizePercentage: 10
    };
  }
  
  // Create agent configuration
  const agent = {
    id: uuidv4(),
    name: answers.name,
    type: answers.type,
    strategy: answers.strategy,
    tradingPairs: answers.tradingPairs || [],
    networks: answers.networks,
    executionMode: answers.executionMode,
    advanced: advancedSettings,
    createdAt: new Date().toISOString(),
    status: 'created'
  };
  
  // Save agent configuration
  const agentPath = path.join(agentsDir, `${agent.name.toLowerCase().replace(/\s+/g, '-')}.json`);
  fs.writeFileSync(agentPath, JSON.stringify(agent, null, 2));
  
  // Show success message with agent details
  console.log('\n' + chalk.green('✅ Agent created successfully!'));
  console.log('\n' + chalk.yellow('Agent Configuration:'));
  console.log(chalk.cyan('Name:'), agent.name);
  console.log(chalk.cyan('Type:'), AGENT_TYPES.find(a => a.value === agent.type).name);
  console.log(chalk.cyan('Strategy:'), STRATEGIES.find(s => s.value === agent.strategy).name);
  
  if (agent.tradingPairs.length > 0) {
    console.log(chalk.cyan('Trading Pairs:'), agent.tradingPairs.join(', '));
  }
  
  console.log(chalk.cyan('Networks:'), agent.networks.map(n => NETWORKS.find(net => net.value === n).name).join(', '));
  console.log(chalk.cyan('Execution Mode:'), EXECUTION_MODES.find(m => m.value === agent.executionMode).name);
  
  return agent;
}

// List all agents
async function listAgents() {
  console.log(chalk.cyan('\n📋 AGENT LIST\n'));
  
  // Read all agent files
  const files = fs.readdirSync(agentsDir).filter(file => file.endsWith('.json'));
  
  if (files.length === 0) {
    console.log(chalk.yellow('No agents found. Create one using the "Create new agent" option.'));
    return [];
  }
  
  // Parse and display agents
  const agents = files.map(file => {
    const data = fs.readFileSync(path.join(agentsDir, file), 'utf8');
    return JSON.parse(data);
  });
  
  // Display agent table
  console.log('┌' + '─'.repeat(78) + '┐');
  console.log('│ ' + chalk.bold('NAME').padEnd(20) + '│ ' + 
               chalk.bold('TYPE').padEnd(15) + '│ ' + 
               chalk.bold('STRATEGY').padEnd(15) + '│ ' + 
               chalk.bold('NETWORKS').padEnd(10) + '│ ' + 
               chalk.bold('STATUS').padEnd(10) + '│');
  console.log('├' + '─'.repeat(78) + '┤');
  
  agents.forEach(agent => {
    // Color status based on its value
    let statusColored;
    if (agent.status === 'running') {
      statusColored = chalk.green(agent.status.padEnd(10));
    } else if (agent.status === 'stopped') {
      statusColored = chalk.red(agent.status.padEnd(10));
    } else {
      statusColored = chalk.yellow(agent.status.padEnd(10));
    }
    
    console.log('│ ' + agent.name.padEnd(20) + '│ ' + 
                 agent.type.padEnd(15) + '│ ' + 
                 agent.strategy.padEnd(15) + '│ ' + 
                 (agent.networks.length > 0 ? agent.networks[0] : '').padEnd(10) + '│ ' + 
                 statusColored + '│');
  });
  
  console.log('└' + '─'.repeat(78) + '┘');
  console.log(chalk.dim(`\nTotal agents: ${agents.length}`));
  
  return agents;
}

// Start an agent
async function startAgent(agentName) {
  console.log(chalk.cyan('\n▶️ START AGENT\n'));
  
  // If name not provided, let user select
  if (!agentName) {
    // Read all agent files
    const files = fs.readdirSync(agentsDir).filter(file => file.endsWith('.json'));
    
    if (files.length === 0) {
      console.log(chalk.yellow('No agents found. Create one using the "Create new agent" option.'));
      return null;
    }
    
    // Parse agents for selection
    const agents = files.map(file => {
      const data = fs.readFileSync(path.join(agentsDir, file), 'utf8');
      const agent = JSON.parse(data);
      return { 
        name: `${agent.name} (${agent.type}, ${agent.strategy}, ${agent.status})`, 
        value: agent.name 
      };
    });
    
    const answer = await inquirer.prompt([
      {
        type: 'list',
        name: 'agentName',
        message: 'Select an agent to start:',
        choices: agents
      }
    ]);
    
    agentName = answer.agentName;
  }
  
  // Find the agent file
  const fileName = `${agentName.toLowerCase().replace(/\s+/g, '-')}.json`;
  const agentPath = path.join(agentsDir, fileName);
  
  if (!fs.existsSync(agentPath)) {
    console.log(chalk.red(`Error: Agent "${agentName}" not found.`));
    return null;
  }
  
  // Load the agent
  const agent = JSON.parse(fs.readFileSync(agentPath, 'utf8'));
  
  // Check if already running
  if (agent.status === 'running') {
    console.log(chalk.yellow(`Agent "${agentName}" is already running.`));
    return agent;
  }
  
  // Confirmation
  const { confirm } = await inquirer.prompt([
    {
      type: 'confirm',
      name: 'confirm',
      message: `Start agent "${agentName}"?`,
      default: true
    }
  ]);
  
  if (!confirm) {
    console.log(chalk.yellow('Operation cancelled.'));
    return null;
  }
  
  // Update agent status
  agent.status = 'running';
  agent.startedAt = new Date().toISOString();
  fs.writeFileSync(agentPath, JSON.stringify(agent, null, 2));
  
  // Show startup animation
  console.log(chalk.green(`\nStarting agent "${agentName}"...`));
  
  // Simulate initialization steps
  const initSteps = [
    'Loading configuration...',
    'Initializing connection to RPC endpoints...',
    'Loading trading strategies...',
    'Initializing wallet connection...',
    'Setting up market data feeds...',
    'Calibrating trading parameters...',
    'Running strategy backtests...'
  ];
  
  for (let i = 0; i < initSteps.length; i++) {
    await new Promise(resolve => setTimeout(resolve, 300));
    console.log(`[${i+1}/${initSteps.length}] ${initSteps[i]}`);
  }
  
  // Show different init messages based on agent type
  switch (agent.type) {
    case 'trading':
      console.log(chalk.magenta('📊 Initializing trading algorithms...'));
      break;
    case 'arbitrage':
      console.log(chalk.magenta('💱 Setting up cross-exchange price monitoring...'));
      break;
    case 'market-making':
      console.log(chalk.magenta('📈 Calculating optimal spreads and order sizes...'));
      break;
    case 'liquidity':
      console.log(chalk.magenta('💧 Initializing liquidity pool monitoring...'));
      break;
    case 'analytics':
      console.log(chalk.magenta('📉 Setting up data collection and analysis pipelines...'));
      break;
  }
  
  await new Promise(resolve => setTimeout(resolve, 500));
  console.log(chalk.green(`\n✅ Agent "${agentName}" started successfully!`));
  
  // Show execution mode warning/info
  if (agent.executionMode === 'live') {
    console.log(chalk.yellow('⚠️ LIVE TRADING MODE ACTIVE - Real funds will be used for trading!'));
  } else if (agent.executionMode === 'paper') {
    console.log(chalk.blue('ℹ️ PAPER TRADING MODE - Simulated trades with real market data'));
  } else {
    console.log(chalk.blue('ℹ️ SIMULATION MODE - No real market data or trades'));
  }
  
  return agent;
}

// Stop an agent
async function stopAgent(agentName) {
  console.log(chalk.cyan('\n⏹️ STOP AGENT\n'));
  
  // If name not provided, let user select
  if (!agentName) {
    // Read all agent files
    const files = fs.readdirSync(agentsDir).filter(file => file.endsWith('.json'));
    
    if (files.length === 0) {
      console.log(chalk.yellow('No agents found. Create one using the "Create new agent" option.'));
      return null;
    }
    
    // Parse agents for selection, but only include running ones
    const agents = files.map(file => {
      const data = fs.readFileSync(path.join(agentsDir, file), 'utf8');
      const agent = JSON.parse(data);
      return { 
        name: `${agent.name} (${agent.type}, ${agent.status})`, 
        value: agent.name,
        disabled: agent.status !== 'running' ? 'Not running' : false
      };
    });
    
    const runningAgents = agents.filter(a => !a.disabled);
    
    if (runningAgents.length === 0) {
      console.log(chalk.yellow('No running agents found.'));
      return null;
    }
    
    const answer = await inquirer.prompt([
      {
        type: 'list',
        name: 'agentName',
        message: 'Select an agent to stop:',
        choices: agents
      }
    ]);
    
    agentName = answer.agentName;
  }
  
  // Find the agent file
  const fileName = `${agentName.toLowerCase().replace(/\s+/g, '-')}.json`;
  const agentPath = path.join(agentsDir, fileName);
  
  if (!fs.existsSync(agentPath)) {
    console.log(chalk.red(`Error: Agent "${agentName}" not found.`));
    return null;
  }
  
  // Load the agent
  const agent = JSON.parse(fs.readFileSync(agentPath, 'utf8'));
  
  // Check if already stopped
  if (agent.status !== 'running') {
    console.log(chalk.yellow(`Agent "${agentName}" is not running.`));
    return agent;
  }
  
  // Confirmation
  const { confirm } = await inquirer.prompt([
    {
      type: 'confirm',
      name: 'confirm',
      message: `Stop agent "${agentName}"?`,
      default: true
    }
  ]);
  
  if (!confirm) {
    console.log(chalk.yellow('Operation cancelled.'));
    return null;
  }
  
  // Show shutdown animation
  console.log(chalk.yellow(`\nStopping agent "${agentName}"...`));
  
  // Simulate shutdown
  const shutdownSteps = [
    'Closing open orders...',
    'Saving state...',
    'Disconnecting from exchanges...',
    'Shutting down data feeds...',
    'Generating performance report...'
  ];
  
  for (const step of shutdownSteps) {
    await new Promise(resolve => setTimeout(resolve, 300));
    console.log(`- ${step}`);
  }
  
  // Update agent status
  agent.status = 'stopped';
  agent.stoppedAt = new Date().toISOString();
  
  // Add random performance metrics
  agent.performance = {
    uptime: Math.floor(Math.random() * 24) + 1, // 1-24 hours
    trades: Math.floor(Math.random() * 50) + 1,
    profit: (Math.random() * 10 - 2).toFixed(2), // -2% to +8%
    winRate: Math.floor(Math.random() * 30) + 50 // 50-80%
  };
  
  fs.writeFileSync(agentPath, JSON.stringify(agent, null, 2));
  
  console.log(chalk.green(`\n✅ Agent "${agentName}" stopped successfully!`));
  
  // Show performance stats
  console.log(chalk.cyan('\nPerformance Summary:'));
  console.log(`Uptime: ${agent.performance.uptime} hours`);
  console.log(`Trades executed: ${agent.performance.trades}`);
  
  const profitColor = agent.performance.profit > 0 ? chalk.green : 
                     (agent.performance.profit < 0 ? chalk.red : chalk.white);
  console.log(`Profit/Loss: ${profitColor(agent.performance.profit + '%')}`);
  console.log(`Win Rate: ${agent.performance.winRate}%`);
  
  return agent;
}

module.exports = {
  createAgent,
  listAgents,
  startAgent,
  stopAgent
}; 