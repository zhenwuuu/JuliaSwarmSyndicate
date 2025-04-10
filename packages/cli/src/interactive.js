/**
 * JuliaOS CLI - Interactive Mode
 *
 * This is the main implementation of the interactive CLI.
 * It provides a user-friendly interface to interact with the JuliaOS Framework.
 */

const inquirer = require('inquirer');
const chalk = require('chalk');
const ora = require('ora');
const fs = require('fs-extra');
const path = require('path');
const { execSync } = require('child_process');

// Create a simple color function
const colors = {
  cyan: (text) => text,
  green: (text) => text,
  yellow: (text) => text,
  red: (text) => text,
  blue: (text) => text,
  magenta: (text) => text,
  gray: (text) => text,
  white: (text) => text
};

// Use colors instead of chalk
const colorize = colors;

// Helper function to generate UUID
function generateUUID() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

// Display a nice header
function displayHeader() {
  console.clear();
  console.log(`
    ┌──────────────────────────────────────────────────┐
    │                                                  │
    │             JuliaOS CLI v1.0.0                   │
    │                                                  │
    └──────────────────────────────────────────────────┘
  `);
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
          'Wallet Management',
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
      case 'Wallet Management':
        await walletManagement();
        break;
      case 'System Information':
        await systemInfo();
        break;
      case 'Exit':
        console.log(colorize.green('Goodbye!'));
        process.exit(0);
    }
  }
}

// Agent Management
async function agentManagement() {
  displayHeader();
  console.log(colorize.blue('Agent Management\n'));

  const { action } = await inquirer.prompt([
    {
      type: 'list',
      name: 'action',
      message: 'Select an action:',
      choices: [
        'List Agents',
        'Create Agent',
        'View Agent Details',
        'Start Agent',
        'Stop Agent',
        'Pause Agent',
        'Resume Agent',
        'Delete Agent',
        'Execute Agent Task',
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
    case 'View Agent Details':
      await viewAgentDetails();
      break;
    case 'Start Agent':
      await startAgent();
      break;
    case 'Stop Agent':
      await stopAgent();
      break;
    case 'Pause Agent':
      await pauseAgent();
      break;
    case 'Resume Agent':
      await resumeAgent();
      break;
    case 'Delete Agent':
      await deleteAgent();
      break;
    case 'Execute Agent Task':
      await executeAgentTask();
      break;
  }
}

// List Agents
async function listAgents() {
  const spinner = ora('Fetching agents...').start();

  try {
    const response = await global.juliaBridge.execute('Agents.listAgents', []);
    spinner.stop();

    if (response.agents) {
      console.log(colorize.green('\nAgents:'));

      if (response.agents.length === 0) {
        console.log(colorize.yellow('No agents found. Create one to get started!'));
      } else {
        response.agents.forEach(agent => {
          console.log(colorize.cyan(`- ${agent.name} (${agent.id}): ${agent.type} - ${agent.status || 'CREATED'}`));
        });
      }
    } else {
      console.log(colorize.red('Failed to fetch agents:', response.error || 'Unknown error'));
    }
  } catch (error) {
    spinner.stop();
    console.error(colorize.red('Error fetching agents:', error.message));
  }

  await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// Create Agent
async function createAgent() {
  const { name, type } = await inquirer.prompt([
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
      choices: ['TRADING', 'MONITOR', 'ARBITRAGE', 'GENERIC']
    }
  ]);

  // Get agent-specific configuration based on type
  let config = { parameters: {} };

  if (type === 'TRADING') {
    const tradingConfig = await inquirer.prompt([
      {
        type: 'number',
        name: 'risk_tolerance',
        message: 'Risk tolerance (0.0-1.0):',
        default: 0.5,
        validate: input => (input >= 0 && input <= 1) ? true : 'Risk tolerance must be between 0 and 1'
      },
      {
        type: 'number',
        name: 'max_position_size',
        message: 'Maximum position size:',
        default: 1000.0
      },
      {
        type: 'number',
        name: 'take_profit',
        message: 'Take profit percentage:',
        default: 0.05
      },
      {
        type: 'number',
        name: 'stop_loss',
        message: 'Stop loss percentage:',
        default: 0.03
      }
    ]);

    config.parameters = tradingConfig;
  } else if (type === 'MONITOR') {
    const monitorConfig = await inquirer.prompt([
      {
        type: 'number',
        name: 'check_interval',
        message: 'Check interval (seconds):',
        default: 60
      },
      {
        type: 'input',
        name: 'alert_channels',
        message: 'Alert channels (comma-separated):',
        default: 'console',
        filter: input => input.split(',').map(c => c.trim())
      },
      {
        type: 'number',
        name: 'max_alerts_per_hour',
        message: 'Maximum alerts per hour:',
        default: 10
      }
    ]);

    config.parameters = monitorConfig;
  } else if (type === 'ARBITRAGE') {
    const arbitrageConfig = await inquirer.prompt([
      {
        type: 'number',
        name: 'min_profit_threshold',
        message: 'Minimum profit threshold:',
        default: 0.01
      },
      {
        type: 'number',
        name: 'max_position_size',
        message: 'Maximum position size:',
        default: 1000.0
      },
      {
        type: 'number',
        name: 'gas_cost_buffer',
        message: 'Gas cost buffer:',
        default: 0.005
      },
      {
        type: 'input',
        name: 'chains',
        message: 'Chains to monitor (comma-separated):',
        default: 'ethereum,solana',
        filter: input => input.split(',').map(c => c.trim())
      }
    ]);

    config.parameters = arbitrageConfig;
  } else {
    // Generic agent - ask for custom JSON config
    const { customConfig } = await inquirer.prompt([
      {
        type: 'input',
        name: 'customConfig',
        message: 'Agent configuration (JSON):',
        default: '{}',
        validate: input => {
          try {
            JSON.parse(input);
            return true;
          } catch (e) {
            return 'Invalid JSON';
          }
        },
        filter: input => JSON.parse(input)
      }
    ]);

    config.parameters = customConfig;
  }

  const spinner = ora('Creating agent...').start();

  try {
    // Generate a UUID for the agent
    const agent_id = generateUUID();

    const response = await global.juliaBridge.execute('Agents.createAgent', [
      agent_id,
      name,
      type,
      config
    ]);

    spinner.stop();

    if (response.success) {
      console.log(colorize.green(`\nAgent created successfully with ID: ${agent_id}`));
    } else {
      console.log(colorize.red('Failed to create agent:', response.error || 'Unknown error'));
    }
  } catch (error) {
    spinner.stop();
    console.error(colorize.red('Error creating agent:', error.message));
  }

  await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// Helper function to generate UUID
function generateUUID() {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

// View Agent Details
async function viewAgentDetails() {
  // First get the list of agents
  const spinner = ora('Fetching agents...').start();

  try {
    const response = await global.juliaBridge.execute('Agents.listAgents', []);
    spinner.stop();

    if (!response.agents || response.agents.length === 0) {
      console.log(colorize.yellow('No agents found. Create one to get started!'));
      await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
      return;
    }

    // Let user select an agent
    const { agentId } = await inquirer.prompt([
      {
        type: 'list',
        name: 'agentId',
        message: 'Select an agent:',
        choices: response.agents.map(agent => ({
          name: `${agent.name} (${agent.type}) - ${agent.status || 'CREATED'}`,
          value: agent.id
        }))
      }
    ]);

    // Get agent details
    spinner.text = 'Fetching agent details...';
    spinner.start();

    const agentDetails = await global.juliaBridge.execute('Agents.getAgent', [agentId]);
    spinner.stop();

    if (agentDetails) {
      console.log(colorize.green('\nAgent Details:'));
      console.log(colorize.cyan(`ID: ${agentDetails.id}`));
      console.log(colorize.cyan(`Name: ${agentDetails.name}`));
      console.log(colorize.cyan(`Type: ${agentDetails.type}`));
      console.log(colorize.cyan(`Status: ${agentDetails.status || 'CREATED'}`));
      console.log(colorize.cyan('Configuration:'));
      console.log(JSON.stringify(agentDetails.config, null, 2));

      if (agentDetails.created_at) {
        console.log(colorize.cyan(`Created: ${new Date(agentDetails.created_at).toLocaleString()}`));
      }

      if (agentDetails.updated_at) {
        console.log(colorize.cyan(`Updated: ${new Date(agentDetails.updated_at).toLocaleString()}`));
      }
    } else {
      console.log(colorize.red(`Failed to get agent details for ID: ${agentId}`));
    }
  } catch (error) {
    spinner.stop();
    console.error(colorize.red('Error:', error.message));
  }

  await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// Start Agent
async function startAgent() {
  // First get the list of agents
  const spinner = ora('Fetching agents...').start();

  try {
    const response = await global.juliaBridge.execute('Agents.listAgents', []);
    spinner.stop();

    if (!response.agents || response.agents.length === 0) {
      console.log(colorize.yellow('No agents found. Create one to get started!'));
      await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
      return;
    }

    // Filter agents that are not already running
    const availableAgents = response.agents.filter(agent => agent.status !== 'RUNNING');

    if (availableAgents.length === 0) {
      console.log(colorize.yellow('No agents available to start. All agents are already running.'));
      await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
      return;
    }

    // Let user select an agent
    const { agentId } = await inquirer.prompt([
      {
        type: 'list',
        name: 'agentId',
        message: 'Select an agent to start:',
        choices: availableAgents.map(agent => ({
          name: `${agent.name} (${agent.type}) - ${agent.status || 'CREATED'}`,
          value: agent.id
        }))
      }
    ]);

    // Start the agent
    spinner.text = 'Starting agent...';
    spinner.start();

    const result = await global.juliaBridge.execute('Agents.startAgent', [agentId]);
    spinner.stop();

    if (result.success) {
      console.log(colorize.green(`\nAgent ${agentId} started successfully!`));
    } else {
      console.log(colorize.red(`Failed to start agent: ${result.error || 'Unknown error'}`));
    }
  } catch (error) {
    spinner.stop();
    console.error(colorize.red('Error:', error.message));
  }

  await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// Stop Agent
async function stopAgent() {
  // First get the list of agents
  const spinner = ora('Fetching agents...').start();

  try {
    const response = await global.juliaBridge.execute('Agents.listAgents', []);
    spinner.stop();

    if (!response.agents || response.agents.length === 0) {
      console.log(colorize.yellow('No agents found. Create one to get started!'));
      await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
      return;
    }

    // Filter agents that are running
    const runningAgents = response.agents.filter(agent => agent.status === 'RUNNING');

    if (runningAgents.length === 0) {
      console.log(colorize.yellow('No running agents found. Start an agent first.'));
      await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
      return;
    }

    // Let user select an agent
    const { agentId } = await inquirer.prompt([
      {
        type: 'list',
        name: 'agentId',
        message: 'Select an agent to stop:',
        choices: runningAgents.map(agent => ({
          name: `${agent.name} (${agent.type}) - ${agent.status}`,
          value: agent.id
        }))
      }
    ]);

    // Stop the agent
    spinner.text = 'Stopping agent...';
    spinner.start();

    const result = await global.juliaBridge.execute('Agents.stopAgent', [agentId]);
    spinner.stop();

    if (result.success) {
      console.log(colorize.green(`\nAgent ${agentId} stopped successfully!`));
    } else {
      console.log(colorize.red(`Failed to stop agent: ${result.error || 'Unknown error'}`));
    }
  } catch (error) {
    spinner.stop();
    console.error(colorize.red('Error:', error.message));
  }

  await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// Pause Agent
async function pauseAgent() {
  // First get the list of agents
  const spinner = ora('Fetching agents...').start();

  try {
    const response = await global.juliaBridge.execute('Agents.listAgents', []);
    spinner.stop();

    if (!response.agents || response.agents.length === 0) {
      console.log(colorize.yellow('No agents found. Create one to get started!'));
      await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
      return;
    }

    // Filter agents that are running
    const runningAgents = response.agents.filter(agent => agent.status === 'RUNNING');

    if (runningAgents.length === 0) {
      console.log(colorize.yellow('No running agents found. Start an agent first.'));
      await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
      return;
    }

    // Let user select an agent
    const { agentId } = await inquirer.prompt([
      {
        type: 'list',
        name: 'agentId',
        message: 'Select an agent to pause:',
        choices: runningAgents.map(agent => ({
          name: `${agent.name} (${agent.type}) - ${agent.status}`,
          value: agent.id
        }))
      }
    ]);

    // Pause the agent
    spinner.text = 'Pausing agent...';
    spinner.start();

    const result = await global.juliaBridge.execute('Agents.pauseAgent', [agentId]);
    spinner.stop();

    if (result.success) {
      console.log(colorize.green(`\nAgent ${agentId} paused successfully!`));
    } else {
      console.log(colorize.red(`Failed to pause agent: ${result.error || 'Unknown error'}`));
    }
  } catch (error) {
    spinner.stop();
    console.error(colorize.red('Error:', error.message));
  }

  await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// Resume Agent
async function resumeAgent() {
  // First get the list of agents
  const spinner = ora('Fetching agents...').start();

  try {
    const response = await global.juliaBridge.execute('Agents.listAgents', []);
    spinner.stop();

    if (!response.agents || response.agents.length === 0) {
      console.log(colorize.yellow('No agents found. Create one to get started!'));
      await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
      return;
    }

    // Filter agents that are paused
    const pausedAgents = response.agents.filter(agent => agent.status === 'PAUSED');

    if (pausedAgents.length === 0) {
      console.log(colorize.yellow('No paused agents found. Pause an agent first.'));
      await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
      return;
    }

    // Let user select an agent
    const { agentId } = await inquirer.prompt([
      {
        type: 'list',
        name: 'agentId',
        message: 'Select an agent to resume:',
        choices: pausedAgents.map(agent => ({
          name: `${agent.name} (${agent.type}) - ${agent.status}`,
          value: agent.id
        }))
      }
    ]);

    // Resume the agent
    spinner.text = 'Resuming agent...';
    spinner.start();

    const result = await global.juliaBridge.execute('Agents.resumeAgent', [agentId]);
    spinner.stop();

    if (result.success) {
      console.log(colorize.green(`\nAgent ${agentId} resumed successfully!`));
    } else {
      console.log(colorize.red(`Failed to resume agent: ${result.error || 'Unknown error'}`));
    }
  } catch (error) {
    spinner.stop();
    console.error(colorize.red('Error:', error.message));
  }

  await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// Delete Agent
async function deleteAgent() {
  // First get the list of agents
  const spinner = ora('Fetching agents...').start();

  try {
    const response = await global.juliaBridge.execute('Agents.listAgents', []);
    spinner.stop();

    if (!response.agents || response.agents.length === 0) {
      console.log(colorize.yellow('No agents found. Create one to get started!'));
      await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
      return;
    }

    // Let user select an agent
    const { agentId } = await inquirer.prompt([
      {
        type: 'list',
        name: 'agentId',
        message: 'Select an agent to delete:',
        choices: response.agents.map(agent => ({
          name: `${agent.name} (${agent.type}) - ${agent.status || 'CREATED'}`,
          value: agent.id
        }))
      }
    ]);

    // Confirm deletion
    const { confirm } = await inquirer.prompt([
      {
        type: 'confirm',
        name: 'confirm',
        message: `Are you sure you want to delete agent ${agentId}?`,
        default: false
      }
    ]);

    if (!confirm) {
      console.log(colorize.yellow('Deletion cancelled.'));
      await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
      return;
    }

    // Delete the agent
    spinner.text = 'Deleting agent...';
    spinner.start();

    const result = await global.juliaBridge.execute('Agents.deleteAgent', [agentId]);
    spinner.stop();

    if (result.success) {
      console.log(colorize.green(`\nAgent ${agentId} deleted successfully!`));
    } else {
      console.log(colorize.red(`Failed to delete agent: ${result.error || 'Unknown error'}`));
    }
  } catch (error) {
    spinner.stop();
    console.error(colorize.red('Error:', error.message));
  }

  await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// Execute Agent Task
async function executeAgentTask() {
  // First get the list of agents
  const spinner = ora('Fetching agents...').start();

  try {
    const response = await global.juliaBridge.execute('Agents.listAgents', []);
    spinner.stop();

    if (!response.agents || response.agents.length === 0) {
      console.log(colorize.yellow('No agents found. Create one to get started!'));
      await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
      return;
    }

    // Filter agents that are running
    const runningAgents = response.agents.filter(agent => agent.status === 'RUNNING');

    if (runningAgents.length === 0) {
      console.log(colorize.yellow('No running agents found. Start an agent first.'));
      await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
      return;
    }

    // Let user select an agent
    const { agentId, agentType } = await inquirer.prompt([
      {
        type: 'list',
        name: 'agentId',
        message: 'Select an agent to execute a task:',
        choices: runningAgents.map(agent => ({
          name: `${agent.name} (${agent.type}) - ${agent.status}`,
          value: agent.id
        }))
      }
    ]);

    // Get the agent type
    const selectedAgent = runningAgents.find(agent => agent.id === agentId);

    // Define task based on agent type
    let taskData = {};

    if (selectedAgent.type === 'TRADING') {
      const { taskType } = await inquirer.prompt([
        {
          type: 'list',
          name: 'taskType',
          message: 'Select task type:',
          choices: ['analyze_market', 'execute_trade', 'get_portfolio']
        }
      ]);

      if (taskType === 'analyze_market') {
        const { asset, timeframe } = await inquirer.prompt([
          {
            type: 'input',
            name: 'asset',
            message: 'Asset to analyze:',
            default: 'BTC'
          },
          {
            type: 'list',
            name: 'timeframe',
            message: 'Timeframe:',
            choices: ['1m', '5m', '15m', '1h', '4h', '1d']
          }
        ]);

        taskData = {
          type: 'analyze_market',
          parameters: { asset, timeframe }
        };
      } else if (taskType === 'execute_trade') {
        const { asset, action, amount } = await inquirer.prompt([
          {
            type: 'input',
            name: 'asset',
            message: 'Asset to trade:',
            default: 'BTC'
          },
          {
            type: 'list',
            name: 'action',
            message: 'Trade action:',
            choices: ['buy', 'sell']
          },
          {
            type: 'number',
            name: 'amount',
            message: 'Amount:',
            default: 0.01
          }
        ]);

        taskData = {
          type: 'execute_trade',
          parameters: { asset, action, amount }
        };
      } else if (taskType === 'get_portfolio') {
        taskData = {
          type: 'get_portfolio',
          parameters: {}
        };
      }
    } else if (selectedAgent.type === 'MONITOR') {
      const { taskType } = await inquirer.prompt([
        {
          type: 'list',
          name: 'taskType',
          message: 'Select task type:',
          choices: ['check_conditions', 'get_alerts']
        }
      ]);

      if (taskType === 'check_conditions') {
        taskData = {
          type: 'check_conditions',
          parameters: {
            market_data: {
              BTC: { price: 50000, volume: 1000 },
              ETH: { price: 3000, volume: 2000 }
            }
          }
        };
      } else if (taskType === 'get_alerts') {
        taskData = {
          type: 'get_alerts',
          parameters: {}
        };
      }
    } else if (selectedAgent.type === 'ARBITRAGE') {
      const { taskType } = await inquirer.prompt([
        {
          type: 'list',
          name: 'taskType',
          message: 'Select task type:',
          choices: ['find_opportunities', 'execute_arbitrage']
        }
      ]);

      if (taskType === 'find_opportunities') {
        taskData = {
          type: 'find_opportunities',
          parameters: {
            assets: ['BTC', 'ETH', 'SOL'],
            exchanges: ['binance', 'coinbase', 'kraken']
          }
        };
      } else if (taskType === 'execute_arbitrage') {
        taskData = {
          type: 'execute_arbitrage',
          parameters: {
            opportunity_id: generateUUID()
          }
        };
      }
    } else {
      // Generic agent
      const { taskType, taskParams } = await inquirer.prompt([
        {
          type: 'input',
          name: 'taskType',
          message: 'Task type:',
          default: 'generic_task'
        },
        {
          type: 'input',
          name: 'taskParams',
          message: 'Task parameters (JSON):',
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

      taskData = {
        type: taskType,
        parameters: JSON.parse(taskParams)
      };
    }

    // Execute the task
    spinner.text = 'Executing task...';
    spinner.start();

    const result = await global.juliaBridge.execute('Agents.executeTask', [agentId, taskData]);
    spinner.stop();

    if (result.success) {
      console.log(colorize.green(`\nTask executed successfully!`));
      console.log(colorize.cyan(`Task ID: ${result.task_id}`));

      // Wait for task completion
      const { waitForCompletion } = await inquirer.prompt([
        {
          type: 'confirm',
          name: 'waitForCompletion',
          message: 'Wait for task completion?',
          default: true
        }
      ]);

      if (waitForCompletion) {
        spinner.text = 'Waiting for task completion...';
        spinner.start();

        let taskCompleted = false;
        let taskResult = null;
        let attempts = 0;

        while (!taskCompleted && attempts < 30) {
          const taskStatus = await global.juliaBridge.execute('Agents.getTaskStatus', [agentId, result.task_id]);

          if (taskStatus.status === 'completed' || taskStatus.status === 'failed') {
            taskCompleted = true;
            taskResult = taskStatus;
          } else {
            await new Promise(resolve => setTimeout(resolve, 1000));
            attempts++;
          }
        }

        spinner.stop();

        if (taskCompleted) {
          if (taskResult.status === 'completed') {
            console.log(colorize.green('\nTask completed successfully!'));
            console.log(colorize.cyan('Result:'));
            console.log(JSON.stringify(taskResult.result, null, 2));
          } else {
            console.log(colorize.red(`\nTask failed: ${taskResult.error || 'Unknown error'}`));
          }
        } else {
          console.log(colorize.yellow('\nTask is still running. Check status later.'));
        }
      }
    } else {
      console.log(colorize.red(`Failed to execute task: ${result.error || 'Unknown error'}`));
    }
  } catch (error) {
    spinner.stop();
    console.error(colorize.red('Error:', error.message));
  }

  await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// Swarm Management
async function swarmManagement() {
  displayHeader();
  console.log(colorize.green('Swarm Management\n'));

  const { action } = await inquirer.prompt([
    {
      type: 'list',
      name: 'action',
      message: 'Select an action:',
      choices: [
        'List Swarms',
        'Create Swarm',
        'View Swarm Details',
        'Run Optimization',
        'Get Optimization Result',
        'Stop Swarm',
        'Reset Swarm',
        'Delete Swarm',
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
    case 'View Swarm Details':
      await viewSwarmDetails();
      break;
    case 'Run Optimization':
      await runOptimization();
      break;
    case 'Get Optimization Result':
      await getOptimizationResult();
      break;
    case 'Stop Swarm':
      await stopSwarm();
      break;
    case 'Reset Swarm':
      await resetSwarm();
      break;
    case 'Delete Swarm':
      await deleteSwarm();
      break;
  }
}



// List Swarms
async function listSwarms() {
  const spinner = ora('Fetching swarms...').start();

  try {
    const response = await global.juliaBridge.execute('Swarms.list_swarms', []);
    spinner.stop();

    if (response.swarms) {
      console.log(colorize.green('\nSwarms:'));

      if (response.swarms.length === 0) {
        console.log(colorize.yellow('No swarms found. Create one to get started!'));
      } else {
        response.swarms.forEach(swarm => {
          console.log(colorize.cyan(`- ${swarm.name} (${swarm.id}): ${swarm.type} - Algorithm: ${swarm.algorithm}`));
        });
      }
    } else {
      console.log(colorize.red('Failed to fetch swarms:', response.error || 'Unknown error'));
    }
  } catch (error) {
    spinner.stop();
    console.error(colorize.red('Error fetching swarms:', error.message));
  }

  await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// Create Swarm
async function createSwarm() {
  const { name, type, algorithm } = await inquirer.prompt([
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
      choices: ['OPTIMIZATION', 'TRADING', 'RESEARCH', 'MONITORING']
    },
    {
      type: 'list',
      name: 'algorithm',
      message: 'Algorithm:',
      choices: ['DE', 'PSO']
    }
  ]);

  // Get dimensions and bounds for optimization
  let dimensions = 2;
  let bounds = [];
  let config = {};

  if (type === 'OPTIMIZATION') {
    const dimensionsInput = await inquirer.prompt([
      {
        type: 'number',
        name: 'dimensions',
        message: 'Number of dimensions:',
        default: 2,
        validate: input => (input > 0 && input <= 100) ? true : 'Dimensions must be between 1 and 100'
      }
    ]);

    dimensions = dimensionsInput.dimensions;

    // Get bounds for each dimension
    console.log(colorize.cyan('\nEnter bounds for each dimension:'));

    for (let i = 0; i < dimensions; i++) {
      const { min, max } = await inquirer.prompt([
        {
          type: 'number',
          name: 'min',
          message: `Dimension ${i+1} - Minimum value:`,
          default: -10.0
        },
        {
          type: 'number',
          name: 'max',
          message: `Dimension ${i+1} - Maximum value:`,
          default: 10.0
        }
      ]);

      bounds.push([min, max]);
    }

    // Get algorithm-specific configuration
    if (algorithm === 'DE') {
      const deConfig = await inquirer.prompt([
        {
          type: 'number',
          name: 'population_size',
          message: 'Population size:',
          default: 20
        },
        {
          type: 'number',
          name: 'max_generations',
          message: 'Maximum generations:',
          default: 100
        },
        {
          type: 'number',
          name: 'crossover_probability',
          message: 'Crossover probability:',
          default: 0.7,
          validate: input => (input >= 0 && input <= 1) ? true : 'Probability must be between 0 and 1'
        },
        {
          type: 'number',
          name: 'differential_weight',
          message: 'Differential weight:',
          default: 0.8,
          validate: input => (input >= 0 && input <= 2) ? true : 'Weight must be between 0 and 2'
        }
      ]);

      config = deConfig;
    } else if (algorithm === 'PSO') {
      const psoConfig = await inquirer.prompt([
        {
          type: 'number',
          name: 'swarm_size',
          message: 'Swarm size:',
          default: 20
        },
        {
          type: 'number',
          name: 'max_iterations',
          message: 'Maximum iterations:',
          default: 100
        },
        {
          type: 'number',
          name: 'cognitive_coefficient',
          message: 'Cognitive coefficient:',
          default: 2.0
        },
        {
          type: 'number',
          name: 'social_coefficient',
          message: 'Social coefficient:',
          default: 2.0
        },
        {
          type: 'number',
          name: 'inertia_weight',
          message: 'Inertia weight:',
          default: 0.7,
          validate: input => (input >= 0 && input <= 1) ? true : 'Weight must be between 0 and 1'
        }
      ]);

      config = psoConfig;
    }
  } else {
    // For non-optimization swarms, get generic config
    const { customConfig } = await inquirer.prompt([
      {
        type: 'input',
        name: 'customConfig',
        message: 'Swarm configuration (JSON):',
        default: '{}',
        validate: input => {
          try {
            JSON.parse(input);
            return true;
          } catch (e) {
            return 'Invalid JSON';
          }
        },
        filter: input => JSON.parse(input)
      }
    ]);

    config = customConfig;
    bounds = [[-10, 10], [-10, 10]];
  }

  const spinner = ora('Creating swarm...').start();

  try {
    // Generate a UUID for the swarm
    const swarm_id = generateUUID();

    const response = await global.juliaBridge.execute('Swarms.create_swarm', [
      algorithm,
      dimensions,
      bounds,
      {
        id: swarm_id,
        name: name,
        type: type,
        ...config
      }
    ]);

    spinner.stop();

    if (response.success) {
      console.log(colorize.green(`\nSwarm created successfully with ID: ${swarm_id}`));
    } else {
      console.log(colorize.red('Failed to create swarm:', response.error || 'Unknown error'));
    }
  } catch (error) {
    spinner.stop();
    console.error(colorize.red('Error creating swarm:', error.message));
  }

  await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// View Swarm Details
async function viewSwarmDetails() {
  // First get the list of swarms
  const spinner = ora('Fetching swarms...').start();

  try {
    const response = await global.juliaBridge.execute('Swarms.list_swarms', []);
    spinner.stop();

    if (!response.swarms || response.swarms.length === 0) {
      console.log(colorize.yellow('No swarms found. Create one to get started!'));
      await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
      return;
    }

    // Let user select a swarm
    const { swarmId } = await inquirer.prompt([
      {
        type: 'list',
        name: 'swarmId',
        message: 'Select a swarm:',
        choices: response.swarms.map(swarm => ({
          name: `${swarm.name} (${swarm.type}) - ${swarm.algorithm}`,
          value: swarm.id
        }))
      }
    ]);

    // Get swarm details
    spinner.text = 'Fetching swarm details...';
    spinner.start();

    const swarmDetails = await global.juliaBridge.execute('Swarms.get_swarm_status', [swarmId]);
    spinner.stop();

    if (swarmDetails.success) {
      console.log(colorize.green('\nSwarm Details:'));
      console.log(colorize.cyan(`ID: ${swarmDetails.id}`));
      console.log(colorize.cyan(`Name: ${swarmDetails.name}`));
      console.log(colorize.cyan(`Type: ${swarmDetails.type}`));
      console.log(colorize.cyan(`Algorithm: ${swarmDetails.algorithm}`));
      console.log(colorize.cyan(`Dimensions: ${swarmDetails.dimensions}`));
      console.log(colorize.cyan(`Status: ${swarmDetails.status || 'CREATED'}`));
      console.log(colorize.cyan('Configuration:'));
      console.log(JSON.stringify(swarmDetails.config, null, 2));

      if (swarmDetails.created_at) {
        console.log(colorize.cyan(`Created: ${new Date(swarmDetails.created_at).toLocaleString()}`));
      }

      if (swarmDetails.updated_at) {
        console.log(colorize.cyan(`Updated: ${new Date(swarmDetails.updated_at).toLocaleString()}`));
      }
    } else {
      console.log(colorize.red(`Failed to get swarm details for ID: ${swarmId}`));
    }
  } catch (error) {
    spinner.stop();
    console.error(colorize.red('Error:', error.message));
  }

  await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// Run Optimization
async function runOptimization() {
  // First get the list of swarms
  const spinner = ora('Fetching swarms...').start();

  try {
    const response = await global.juliaBridge.execute('Swarms.list_swarms', []);
    spinner.stop();

    if (!response.swarms || response.swarms.length === 0) {
      console.log(colorize.yellow('No swarms found. Create one to get started!'));
      await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
      return;
    }

    // Filter optimization swarms
    const optimizationSwarms = response.swarms.filter(swarm => swarm.type === 'OPTIMIZATION');

    if (optimizationSwarms.length === 0) {
      console.log(colorize.yellow('No optimization swarms found. Create one first.'));
      await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
      return;
    }

    // Let user select a swarm
    const { swarmId } = await inquirer.prompt([
      {
        type: 'list',
        name: 'swarmId',
        message: 'Select a swarm for optimization:',
        choices: optimizationSwarms.map(swarm => ({
          name: `${swarm.name} (${swarm.algorithm}) - ${swarm.dimensions} dimensions`,
          value: swarm.id
        }))
      }
    ]);

    // Get objective function
    const { functionType } = await inquirer.prompt([
      {
        type: 'list',
        name: 'functionType',
        message: 'Select objective function type:',
        choices: ['Built-in', 'Custom']
      }
    ]);

    let functionId;

    if (functionType === 'Built-in') {
      const { builtInFunction } = await inquirer.prompt([
        {
          type: 'list',
          name: 'builtInFunction',
          message: 'Select a built-in function:',
          choices: ['sphere', 'rosenbrock', 'rastrigin', 'ackley']
        }
      ]);

      functionId = builtInFunction;
    } else {
      // Custom function
      const { customFunction } = await inquirer.prompt([
        {
          type: 'input',
          name: 'customFunction',
          message: 'Enter Julia function code:',
          default: 'function(x) return sum(x.^2) end',
          validate: input => input.trim() !== '' ? true : 'Function cannot be empty'
        }
      ]);

      // Register the function
      functionId = `custom_${generateUUID()}`;
      const registerResult = await global.juliaBridge.execute('Swarms.set_objective_function', [
        functionId,
        customFunction,
        'julia'
      ]);

      if (!registerResult.success) {
        console.log(colorize.red(`Failed to register function: ${registerResult.error || 'Unknown error'}`));
        await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
        return;
      }
    }

    // Get optimization parameters
    const { maxIterations, maxTimeSeconds, tolerance } = await inquirer.prompt([
      {
        type: 'number',
        name: 'maxIterations',
        message: 'Maximum iterations:',
        default: 100,
        validate: input => input > 0 ? true : 'Must be greater than 0'
      },
      {
        type: 'number',
        name: 'maxTimeSeconds',
        message: 'Maximum time (seconds):',
        default: 60,
        validate: input => input > 0 ? true : 'Must be greater than 0'
      },
      {
        type: 'number',
        name: 'tolerance',
        message: 'Convergence tolerance:',
        default: 1e-6,
        validate: input => input > 0 ? true : 'Must be greater than 0'
      }
    ]);

    // Run optimization
    spinner.text = 'Running optimization...';
    spinner.start();

    const result = await global.juliaBridge.execute('Swarms.run_optimization', [
      swarmId,
      functionId,
      {
        max_iterations: maxIterations,
        max_time_seconds: maxTimeSeconds,
        tolerance: tolerance
      }
    ]);

    spinner.stop();

    if (result.success) {
      console.log(colorize.green(`\nOptimization started successfully!`));
      console.log(colorize.cyan(`Optimization ID: ${result.optimization_id}`));

      // Ask if user wants to wait for completion
      const { waitForCompletion } = await inquirer.prompt([
        {
          type: 'confirm',
          name: 'waitForCompletion',
          message: 'Wait for optimization to complete?',
          default: true
        }
      ]);

      if (waitForCompletion) {
        await waitForOptimizationResult(swarmId, result.optimization_id);
      }
    } else {
      console.log(colorize.red(`Failed to run optimization: ${result.error || 'Unknown error'}`));
    }
  } catch (error) {
    spinner.stop();
    console.error(colorize.red('Error:', error.message));
  }

  await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// Helper function to wait for optimization result
async function waitForOptimizationResult(swarmId, optimizationId) {
  const spinner = ora('Waiting for optimization to complete...').start();

  let completed = false;
  let attempts = 0;
  const maxAttempts = 60; // 1 minute with 1-second intervals

  while (!completed && attempts < maxAttempts) {
    try {
      const result = await global.juliaBridge.execute('Swarms.get_optimization_result', [optimizationId]);

      if (result.status === 'completed' || result.status === 'failed') {
        completed = true;
        spinner.stop();

        if (result.status === 'completed') {
          console.log(colorize.green('\nOptimization completed successfully!'));
          console.log(colorize.cyan('Result:'));

          if (result.result.best_individual) {
            console.log(colorize.cyan('Best solution:'), result.result.best_individual);
            console.log(colorize.cyan('Best fitness:'), result.result.best_fitness);
          } else if (result.result.best_position) {
            console.log(colorize.cyan('Best position:'), result.result.best_position);
            console.log(colorize.cyan('Best fitness:'), result.result.best_fitness);
          }
        } else {
          console.log(colorize.red(`\nOptimization failed: ${result.error || 'Unknown error'}`));
        }
      } else {
        // Update spinner with progress if available
        if (result.progress) {
          spinner.text = `Waiting for optimization to complete... ${result.progress}%`;
        }

        await new Promise(resolve => setTimeout(resolve, 1000));
        attempts++;
      }
    } catch (error) {
      await new Promise(resolve => setTimeout(resolve, 1000));
      attempts++;
    }
  }

  if (!completed) {
    spinner.stop();
    console.log(colorize.yellow('\nOptimization is still running. Check result later.'));
  }
}

// Get Optimization Result
async function getOptimizationResult() {
  // First get the list of swarms
  const spinner = ora('Fetching swarms...').start();

  try {
    const response = await global.juliaBridge.execute('Swarms.list_swarms', []);
    spinner.stop();

    if (!response.swarms || response.swarms.length === 0) {
      console.log(colorize.yellow('No swarms found. Create one to get started!'));
      await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
      return;
    }

    // Let user select a swarm
    const { swarmId } = await inquirer.prompt([
      {
        type: 'list',
        name: 'swarmId',
        message: 'Select a swarm:',
        choices: response.swarms.map(swarm => ({
          name: `${swarm.name} (${swarm.type}) - ${swarm.algorithm}`,
          value: swarm.id
        }))
      }
    ]);

    // Get optimization history
    spinner.text = 'Fetching optimization history...';
    spinner.start();

    const historyResult = await global.juliaBridge.execute('Swarms.get_optimization_history', [swarmId]);
    spinner.stop();

    if (historyResult.success && historyResult.history && historyResult.history.length > 0) {
      console.log(colorize.green(`\nOptimization history for swarm ${swarmId}:`));

      // Let user select an optimization
      const { optimizationId } = await inquirer.prompt([
        {
          type: 'list',
          name: 'optimizationId',
          message: 'Select an optimization:',
          choices: historyResult.history.map(opt => ({
            name: `${opt.id} - ${opt.status} - ${new Date(opt.timestamp).toLocaleString()}`,
            value: opt.id
          }))
        }
      ]);

      // Get optimization result
      spinner.text = 'Fetching optimization result...';
      spinner.start();

      const result = await global.juliaBridge.execute('Swarms.get_optimization_result', [optimizationId]);
      spinner.stop();

      if (result.status === 'completed') {
        console.log(colorize.green('\nOptimization result:'));

        if (result.result.best_individual) {
          console.log(colorize.cyan('Best solution:'), result.result.best_individual);
          console.log(colorize.cyan('Best fitness:'), result.result.best_fitness);
        } else if (result.result.best_position) {
          console.log(colorize.cyan('Best position:'), result.result.best_position);
          console.log(colorize.cyan('Best fitness:'), result.result.best_fitness);
        }

        console.log(colorize.cyan('Iterations:'), result.result.iterations);
        console.log(colorize.cyan('Function evaluations:'), result.result.evaluations);
        console.log(colorize.cyan('Time elapsed:'), result.result.time_elapsed, 'seconds');
      } else if (result.status === 'failed') {
        console.log(colorize.red(`\nOptimization failed: ${result.error || 'Unknown error'}`));
      } else {
        console.log(colorize.yellow(`\nOptimization status: ${result.status}`));
        console.log(colorize.yellow('Optimization is still running.'));
      }
    } else {
      console.log(colorize.yellow('No optimization history found for this swarm.'));
    }
  } catch (error) {
    spinner.stop();
    console.error(colorize.red('Error:', error.message));
  }

  await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// Stop Swarm
async function stopSwarm() {
  // First get the list of swarms
  const spinner = ora('Fetching swarms...').start();

  try {
    const response = await global.juliaBridge.execute('Swarms.list_swarms', []);
    spinner.stop();

    if (!response.swarms || response.swarms.length === 0) {
      console.log(colorize.yellow('No swarms found. Create one to get started!'));
      await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
      return;
    }

    // Filter running swarms
    const runningSwarms = response.swarms.filter(swarm => swarm.status === 'RUNNING');

    if (runningSwarms.length === 0) {
      console.log(colorize.yellow('No running swarms found.'));
      await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
      return;
    }

    // Let user select a swarm
    const { swarmId } = await inquirer.prompt([
      {
        type: 'list',
        name: 'swarmId',
        message: 'Select a swarm to stop:',
        choices: runningSwarms.map(swarm => ({
          name: `${swarm.name} (${swarm.type}) - ${swarm.algorithm}`,
          value: swarm.id
        }))
      }
    ]);

    // Stop the swarm
    spinner.text = 'Stopping swarm...';
    spinner.start();

    const result = await global.juliaBridge.execute('Swarms.stop_swarm', [swarmId]);
    spinner.stop();

    if (result.success) {
      console.log(colorize.green(`\nSwarm ${swarmId} stopped successfully!`));
    } else {
      console.log(colorize.red(`Failed to stop swarm: ${result.error || 'Unknown error'}`));
    }
  } catch (error) {
    spinner.stop();
    console.error(colorize.red('Error:', error.message));
  }

  await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// Reset Swarm
async function resetSwarm() {
  // First get the list of swarms
  const spinner = ora('Fetching swarms...').start();

  try {
    const response = await global.juliaBridge.execute('Swarms.list_swarms', []);
    spinner.stop();

    if (!response.swarms || response.swarms.length === 0) {
      console.log(colorize.yellow('No swarms found. Create one to get started!'));
      await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
      return;
    }

    // Let user select a swarm
    const { swarmId } = await inquirer.prompt([
      {
        type: 'list',
        name: 'swarmId',
        message: 'Select a swarm to reset:',
        choices: response.swarms.map(swarm => ({
          name: `${swarm.name} (${swarm.type}) - ${swarm.algorithm}`,
          value: swarm.id
        }))
      }
    ]);

    // Reset the swarm
    spinner.text = 'Resetting swarm...';
    spinner.start();

    const result = await global.juliaBridge.execute('Swarms.reset_swarm', [swarmId]);
    spinner.stop();

    if (result.success) {
      console.log(colorize.green(`\nSwarm ${swarmId} reset successfully!`));
    } else {
      console.log(colorize.red(`Failed to reset swarm: ${result.error || 'Unknown error'}`));
    }
  } catch (error) {
    spinner.stop();
    console.error(colorize.red('Error:', error.message));
  }

  await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// Delete Swarm
async function deleteSwarm() {
  // First get the list of swarms
  const spinner = ora('Fetching swarms...').start();

  try {
    const response = await global.juliaBridge.execute('Swarms.list_swarms', []);
    spinner.stop();

    if (!response.swarms || response.swarms.length === 0) {
      console.log(colorize.yellow('No swarms found. Create one to get started!'));
      await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
      return;
    }

    // Let user select a swarm
    const { swarmId } = await inquirer.prompt([
      {
        type: 'list',
        name: 'swarmId',
        message: 'Select a swarm to delete:',
        choices: response.swarms.map(swarm => ({
          name: `${swarm.name} (${swarm.type}) - ${swarm.algorithm}`,
          value: swarm.id
        }))
      }
    ]);

    // Confirm deletion
    const { confirm } = await inquirer.prompt([
      {
        type: 'confirm',
        name: 'confirm',
        message: `Are you sure you want to delete swarm ${swarmId}?`,
        default: false
      }
    ]);

    if (!confirm) {
      console.log(colorize.yellow('Deletion cancelled.'));
      await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
      return;
    }

    // Delete the swarm
    spinner.text = 'Deleting swarm...';
    spinner.start();

    const result = await global.juliaBridge.execute('Swarms.delete_swarm', [swarmId]);
    spinner.stop();

    if (result.success) {
      console.log(colorize.green(`\nSwarm ${swarmId} deleted successfully!`));
    } else {
      console.log(colorize.red(`Failed to delete swarm: ${result.error || 'Unknown error'}`));
    }
  } catch (error) {
    spinner.stop();
    console.error(colorize.red('Error:', error.message));
  }

  await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// Wallet Management
async function walletManagement() {
  displayHeader();
  console.log(colorize.magenta('Wallet Management\n'));

  const { action } = await inquirer.prompt([
    {
      type: 'list',
      name: 'action',
      message: 'Select an action:',
      choices: [
        'Connect Wallet',
        'View Wallet Status',
        'View Balance',
        'Send Transaction',
        'View Transaction History',
        'Disconnect Wallet',
        'Back to Main Menu'
      ]
    }
  ]);

  switch (action) {
    case 'Connect Wallet':
      await connectWallet();
      break;
    case 'View Wallet Status':
      await viewWalletStatus();
      break;
    case 'View Balance':
      await viewWalletBalance();
      break;
    case 'Send Transaction':
      await sendTransaction();
      break;
    case 'View Transaction History':
      await viewTransactionHistory();
      break;
    case 'Disconnect Wallet':
      await disconnectWallet();
      break;
  }
}

// Connect Wallet
async function connectWallet() {
  const { walletType } = await inquirer.prompt([
    {
      type: 'list',
      name: 'walletType',
      message: 'Select wallet type:',
      choices: ['Private Key', 'Read-only Address']
    }
  ]);

  if (walletType === 'Private Key') {
    // Get private key
    const { privateKey } = await inquirer.prompt([
      {
        type: 'password',
        name: 'privateKey',
        message: 'Enter private key:',
        validate: input => input.trim() !== '' ? true : 'Private key cannot be empty'
      }
    ]);

    // Get chain
    const { chain } = await inquirer.prompt([
      {
        type: 'list',
        name: 'chain',
        message: 'Select blockchain:',
        choices: ['ethereum', 'solana', 'base', 'arbitrum', 'optimism', 'avalanche']
      }
    ]);

    const spinner = ora('Connecting wallet...').start();

    try {
      const result = await global.juliaBridge.execute('Wallet.connect_with_private_key', [
        privateKey,
        chain
      ]);

      spinner.stop();

      if (result.success) {
        console.log(colorize.green('\nWallet connected successfully!'));
        console.log(colorize.cyan(`Address: ${result.address}`));
        console.log(colorize.cyan(`Chain: ${chain}`));
      } else {
        console.log(colorize.red(`Failed to connect wallet: ${result.error || 'Unknown error'}`));
      }
    } catch (error) {
      spinner.stop();
      console.error(colorize.red('Error connecting wallet:', error.message));
    }
  } else {
    // Read-only address
    const { address } = await inquirer.prompt([
      {
        type: 'input',
        name: 'address',
        message: 'Enter wallet address:',
        validate: input => input.trim() !== '' ? true : 'Address cannot be empty'
      }
    ]);

    // Get chain
    const { chain } = await inquirer.prompt([
      {
        type: 'list',
        name: 'chain',
        message: 'Select blockchain:',
        choices: ['ethereum', 'solana', 'base', 'arbitrum', 'optimism', 'avalanche']
      }
    ]);

    const spinner = ora('Connecting wallet in read-only mode...').start();

    try {
      const result = await global.juliaBridge.execute('Wallet.connect_readonly', [
        address,
        chain
      ]);

      spinner.stop();

      if (result.success) {
        console.log(colorize.green('\nWallet connected in read-only mode!'));
        console.log(colorize.cyan(`Address: ${address}`));
        console.log(colorize.cyan(`Chain: ${chain}`));
      } else {
        console.log(colorize.red(`Failed to connect wallet: ${result.error || 'Unknown error'}`));
      }
    } catch (error) {
      spinner.stop();
      console.error(colorize.red('Error connecting wallet:', error.message));
    }
  }

  await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// View Wallet Status
async function viewWalletStatus() {
  const spinner = ora('Fetching wallet status...').start();

  try {
    const result = await global.juliaBridge.execute('Wallet.get_status', []);
    spinner.stop();

    if (result.connected) {
      console.log(colorize.green('\nWallet Status:'));
      console.log(colorize.cyan(`Connected: ${result.connected ? 'Yes' : 'No'}`));
      console.log(colorize.cyan(`Address: ${result.address}`));
      console.log(colorize.cyan(`Chain: ${result.chain}`));
      console.log(colorize.cyan(`Type: ${result.read_only ? 'Read-only' : 'Full Access'}`));
    } else {
      console.log(colorize.yellow('\nNo wallet connected.'));
    }
  } catch (error) {
    spinner.stop();
    console.error(colorize.red('Error fetching wallet status:', error.message));
  }

  await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// View Wallet Balance
async function viewWalletBalance() {
  const spinner = ora('Fetching wallet balance...').start();

  try {
    const statusResult = await global.juliaBridge.execute('Wallet.get_status', []);

    if (!statusResult.connected) {
      spinner.stop();
      console.log(colorize.yellow('\nNo wallet connected. Please connect a wallet first.'));
      await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
      return;
    }

    const result = await global.juliaBridge.execute('Wallet.get_balance', []);
    spinner.stop();

    if (result.success) {
      console.log(colorize.green('\nWallet Balance:'));
      console.log(colorize.cyan(`Native Balance: ${result.native_balance} ${result.native_symbol}`));

      if (result.tokens && result.tokens.length > 0) {
        console.log(colorize.green('\nToken Balances:'));
        result.tokens.forEach(token => {
          console.log(colorize.cyan(`${token.symbol}: ${token.balance}`));
        });
      }
    } else {
      console.log(colorize.red(`Failed to fetch balance: ${result.error || 'Unknown error'}`));
    }
  } catch (error) {
    spinner.stop();
    console.error(colorize.red('Error fetching wallet balance:', error.message));
  }

  await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// Send Transaction
async function sendTransaction() {
  try {
    const statusResult = await global.juliaBridge.execute('Wallet.get_status', []);

    if (!statusResult.connected) {
      console.log(colorize.yellow('\nNo wallet connected. Please connect a wallet first.'));
      await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
      return;
    }

    if (statusResult.read_only) {
      console.log(colorize.yellow('\nCannot send transactions with a read-only wallet.'));
      await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
      return;
    }

    // Get transaction details
    const { recipient, amount, token } = await inquirer.prompt([
      {
        type: 'input',
        name: 'recipient',
        message: 'Recipient address:',
        validate: input => input.trim() !== '' ? true : 'Recipient address cannot be empty'
      },
      {
        type: 'number',
        name: 'amount',
        message: 'Amount to send:',
        validate: input => input > 0 ? true : 'Amount must be greater than 0'
      },
      {
        type: 'list',
        name: 'token',
        message: 'Select token:',
        choices: ['Native', 'USDC', 'USDT', 'DAI', 'Other']
      }
    ]);

    let tokenAddress = null;

    if (token === 'Other') {
      const { customToken } = await inquirer.prompt([
        {
          type: 'input',
          name: 'customToken',
          message: 'Token address:',
          validate: input => input.trim() !== '' ? true : 'Token address cannot be empty'
        }
      ]);

      tokenAddress = customToken;
    } else if (token !== 'Native') {
      // Use predefined token addresses based on the chain
      const tokenAddresses = {
        'ethereum': {
          'USDC': '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48',
          'USDT': '0xdac17f958d2ee523a2206206994597c13d831ec7',
          'DAI': '0x6b175474e89094c44da98b954eedeac495271d0f'
        },
        'solana': {
          'USDC': 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v',
          'USDT': 'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB',
          'DAI': 'EjmyN6qEC1Tf1JxiG1ae7UTJhUxSwk1TCWNWqxWV4J6o'
        },
        // Add other chains as needed
      };

      tokenAddress = tokenAddresses[statusResult.chain]?.[token] || null;

      if (!tokenAddress) {
        console.log(colorize.yellow(`\nToken ${token} not supported on ${statusResult.chain}. Using native token.`));
      }
    }

    // Confirm transaction
    const { confirm } = await inquirer.prompt([
      {
        type: 'confirm',
        name: 'confirm',
        message: `Send ${amount} ${token} to ${recipient}?`,
        default: false
      }
    ]);

    if (!confirm) {
      console.log(colorize.yellow('Transaction cancelled.'));
      await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
      return;
    }

    const spinner = ora('Sending transaction...').start();

    const result = await global.juliaBridge.execute('Wallet.send_transaction', [
      recipient,
      amount,
      tokenAddress
    ]);

    spinner.stop();

    if (result.success) {
      console.log(colorize.green('\nTransaction sent successfully!'));
      console.log(colorize.cyan(`Transaction Hash: ${result.tx_hash}`));
    } else {
      console.log(colorize.red(`Failed to send transaction: ${result.error || 'Unknown error'}`));
    }
  } catch (error) {
    console.error(colorize.red('Error sending transaction:', error.message));
  }

  await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// View Transaction History
async function viewTransactionHistory() {
  const spinner = ora('Fetching transaction history...').start();

  try {
    const statusResult = await global.juliaBridge.execute('Wallet.get_status', []);

    if (!statusResult.connected) {
      spinner.stop();
      console.log(colorize.yellow('\nNo wallet connected. Please connect a wallet first.'));
      await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
      return;
    }

    const result = await global.juliaBridge.execute('Wallet.get_transaction_history', []);
    spinner.stop();

    if (result.success && result.transactions && result.transactions.length > 0) {
      console.log(colorize.green('\nTransaction History:'));

      result.transactions.forEach((tx, index) => {
        const date = new Date(tx.timestamp * 1000).toLocaleString();
        const type = tx.from.toLowerCase() === statusResult.address.toLowerCase() ? 'Sent' : 'Received';
        const amount = tx.value;
        const token = tx.token_symbol || 'Native';

        console.log(colorize.cyan(`${index + 1}. ${type} ${amount} ${token} - ${date}`));
        console.log(colorize.gray(`   Hash: ${tx.hash}`));
        console.log(colorize.gray(`   ${type === 'Sent' ? 'To' : 'From'}: ${type === 'Sent' ? tx.to : tx.from}`));
        console.log();
      });
    } else if (result.success && (!result.transactions || result.transactions.length === 0)) {
      console.log(colorize.yellow('\nNo transactions found.'));
    } else {
      console.log(colorize.red(`Failed to fetch transaction history: ${result.error || 'Unknown error'}`));
    }
  } catch (error) {
    spinner.stop();
    console.error(colorize.red('Error fetching transaction history:', error.message));
  }

  await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// Disconnect Wallet
async function disconnectWallet() {
  const spinner = ora('Disconnecting wallet...').start();

  try {
    const result = await global.juliaBridge.execute('Wallet.disconnect', []);
    spinner.stop();

    if (result.success) {
      console.log(colorize.green('\nWallet disconnected successfully!'));
    } else {
      console.log(colorize.red(`Failed to disconnect wallet: ${result.error || 'Unknown error'}`));
    }
  } catch (error) {
    spinner.stop();
    console.error(colorize.red('Error disconnecting wallet:', error.message));
  }

  await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// System Information
async function systemInfo() {
  displayHeader();
  console.log(colorize.yellow('System Information\n'));

  const spinner = ora('Fetching system information...').start();

  try {
    const health = await global.juliaBridge.getHealth();
    spinner.stop();

    console.log(colorize.green('JuliaOS Status:'));
    console.log(colorize.cyan(`- Julia Server: ${health.status === 'healthy' ? 'Running' : 'Not Running'}`));
    console.log(colorize.cyan(`- Version: ${health.version || 'Unknown'}`));
    console.log(colorize.cyan(`- Timestamp: ${health.timestamp || 'Unknown'}`));

    if (health.storage) {
      console.log(colorize.green('\nStorage:'));
      console.log(colorize.cyan(`- Local DB: ${health.storage.local_db || 'Unknown'}`));
      console.log(colorize.cyan(`- Web3 Storage: ${health.storage.web3_storage || 'Not configured'}`));
    }
  } catch (error) {
    spinner.stop();
    console.error(colorize.red('Error fetching system information:', error.message));
  }

  await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// Start the interactive CLI
mainMenu().catch(console.error);

module.exports = { mainMenu };