/**
 * JuliaOS CLI - Interactive Mode
 * 
 * This is the main implementation of the interactive CLI.
 * It's a simplified version to begin with, and will be expanded
 * in the proprietary JuliaOSCLI repository.
 */

const inquirer = require('inquirer');
const chalk = require('chalk');
const ora = require('ora');

// Display a nice header
function displayHeader() {
  console.clear();
  console.log(chalk.cyan(`
    ╔════════════════════════════════════════════════╗
    ║                                                ║
    ║             JuliaOS CLI v0.1.0                 ║
    ║                                                ║
    ╚════════════════════════════════════════════════╝
  `));
}

// Main menu
async function mainMenu() {
  while (true) {
    displayHeader();
    
    const { choice } = await inquirer.prompt([
      {
        type: 'list',
        name: 'choice',
        message: 'Select an option:',
        choices: [
          'Agent Management',
          'Swarm Management',
          'System Information',
          'Exit'
        ]
      }
    ]);
    
    switch (choice) {
      case 'Agent Management':
        await agentManagement();
        break;
      case 'Swarm Management':
        await swarmManagement();
        break;
      case 'System Information':
        await systemInfo();
        break;
      case 'Exit':
        console.log(chalk.green('Goodbye!'));
        process.exit(0);
    }
  }
}

// Agent Management
async function agentManagement() {
  displayHeader();
  console.log(chalk.blue('Agent Management\n'));
  
  const { action } = await inquirer.prompt([
    {
      type: 'list',
      name: 'action',
      message: 'Select an action:',
      choices: [
        'List Agents',
        'Create Agent',
        'Back to Main Menu'
      ]
    }
  ]);
  
  switch (action) {
    case 'List Agents':
      await listAgents();
      break;
    case 'Create Agent':
      await createAgent();
      break;
  }
}

// List Agents
async function listAgents() {
  const spinner = ora('Fetching agents...').start();
  
  try {
    const response = await global.juliaBridge.execute('list_agents');
    spinner.stop();
    
    if (response.success && response.agents) {
      console.log(chalk.green('\nAgents:'));
      
      if (response.agents.length === 0) {
        console.log(chalk.yellow('No agents found. Create one to get started!'));
      } else {
        response.agents.forEach(agent => {
          console.log(chalk.cyan(`- ${agent.name} (${agent.id}): ${agent.type} - ${agent.status || 'Idle'}`));
        });
      }
    } else {
      console.log(chalk.red('Failed to fetch agents:', response.error || 'Unknown error'));
    }
  } catch (error) {
    spinner.stop();
    console.error(chalk.red('Error fetching agents:', error.message));
  }
  
  await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// Create Agent
async function createAgent() {
  const { name, type, config } = await inquirer.prompt([
    {
      type: 'input',
      name: 'name',
      message: 'Agent name:',
      validate: input => input.trim() !== '' ? true : 'Name cannot be empty'
    },
    {
      type: 'list',
      name: 'type',
      message: 'Agent type:',
      choices: ['Trading', 'Analysis', 'Monitor', 'Custom']
    },
    {
      type: 'input',
      name: 'config',
      message: 'Agent configuration (JSON):',
      default: '{}',
      validate: input => {
        try {
          JSON.parse(input);
          return true;
        } catch (e) {
          return 'Invalid JSON';
        }
      }
    }
  ]);
  
  const spinner = ora('Creating agent...').start();
  
  try {
    const response = await global.juliaBridge.execute('create_agent', [name, type, config]);
    spinner.stop();
    
    if (response.success) {
      console.log(chalk.green(`\nAgent created successfully with ID: ${response.id}`));
    } else {
      console.log(chalk.red('Failed to create agent:', response.error || 'Unknown error'));
    }
  } catch (error) {
    spinner.stop();
    console.error(chalk.red('Error creating agent:', error.message));
  }
  
  await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// Swarm Management
async function swarmManagement() {
  displayHeader();
  console.log(chalk.green('Swarm Management\n'));
  
  const { action } = await inquirer.prompt([
    {
      type: 'list',
      name: 'action',
      message: 'Select an action:',
      choices: [
        'List Swarms',
        'Create Swarm',
        'Back to Main Menu'
      ]
    }
  ]);
  
  switch (action) {
    case 'List Swarms':
      await listSwarms();
      break;
    case 'Create Swarm':
      await createSwarm();
      break;
  }
}

// List Swarms
async function listSwarms() {
  const spinner = ora('Fetching swarms...').start();
  
  try {
    const response = await global.juliaBridge.execute('list_swarms');
    spinner.stop();
    
    if (response.success && response.swarms) {
      console.log(chalk.green('\nSwarms:'));
      
      if (response.swarms.length === 0) {
        console.log(chalk.yellow('No swarms found. Create one to get started!'));
      } else {
        response.swarms.forEach(swarm => {
          console.log(chalk.cyan(`- ${swarm.name} (${swarm.id}): ${swarm.type} - Agents: ${swarm.agent_count || 0}`));
        });
      }
    } else {
      console.log(chalk.red('Failed to fetch swarms:', response.error || 'Unknown error'));
    }
  } catch (error) {
    spinner.stop();
    console.error(chalk.red('Error fetching swarms:', error.message));
  }
  
  await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// Create Swarm
async function createSwarm() {
  const { name, type, algorithm, config } = await inquirer.prompt([
    {
      type: 'input',
      name: 'name',
      message: 'Swarm name:',
      validate: input => input.trim() !== '' ? true : 'Name cannot be empty'
    },
    {
      type: 'list',
      name: 'type',
      message: 'Swarm type:',
      choices: ['Trading', 'Analysis', 'Monitor', 'Custom']
    },
    {
      type: 'list',
      name: 'algorithm',
      message: 'Swarm algorithm:',
      choices: ['PSO', 'GWO', 'ACO', 'Custom']
    },
    {
      type: 'input',
      name: 'config',
      message: 'Swarm configuration (JSON):',
      default: '{}',
      validate: input => {
        try {
          JSON.parse(input);
          return true;
        } catch (e) {
          return 'Invalid JSON';
        }
      }
    }
  ]);
  
  const spinner = ora('Creating swarm...').start();
  
  try {
    const response = await global.juliaBridge.execute('create_swarm', [name, type, config, algorithm]);
    spinner.stop();
    
    if (response.success) {
      console.log(chalk.green(`\nSwarm created successfully with ID: ${response.id}`));
    } else {
      console.log(chalk.red('Failed to create swarm:', response.error || 'Unknown error'));
    }
  } catch (error) {
    spinner.stop();
    console.error(chalk.red('Error creating swarm:', error.message));
  }
  
  await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// System Information
async function systemInfo() {
  displayHeader();
  console.log(chalk.yellow('System Information\n'));
  
  const spinner = ora('Fetching system information...').start();
  
  try {
    const health = await global.juliaBridge.getHealth();
    spinner.stop();
    
    console.log(chalk.green('JuliaOS Status:'));
    console.log(chalk.cyan(`- Julia Server: ${health.status === 'healthy' ? 'Running' : 'Not Running'}`));
    console.log(chalk.cyan(`- Version: ${health.version || 'Unknown'}`));
    console.log(chalk.cyan(`- Timestamp: ${health.timestamp || 'Unknown'}`));
    
    if (health.storage) {
      console.log(chalk.green('\nStorage:'));
      console.log(chalk.cyan(`- Local DB: ${health.storage.local_db || 'Unknown'}`));
      console.log(chalk.cyan(`- Web3 Storage: ${health.storage.web3_storage || 'Not configured'}`));
    }
  } catch (error) {
    spinner.stop();
    console.error(chalk.red('Error fetching system information:', error.message));
  }
  
  await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// Start the interactive CLI
mainMenu().catch(console.error);

module.exports = { mainMenu }; 