const chalk = require('chalk');
const inquirer = require('inquirer');
const { v4: uuidv4 } = require('uuid');

// Function to display a professional header for agent creation
function displayAgentCreationHeader() {
    console.clear();
    console.log(chalk.green(`\n      ╔══════════════════════════════════════════╗\n      ║           Agent Creation                 ║\n      ║                                          ║\n      ║  🤖 Create and configure individual      ║\n      ║     agents for specific tasks.           ║\n      ║                                          ║\n      ╚══════════════════════════════════════════╝\n    `));

    // Add helpful description
    console.log(chalk.cyan('\nAgents are autonomous entities that can perform tasks like trading,'));
    console.log(chalk.cyan('monitoring markets, analyzing data, and executing strategies.'));
    console.log(chalk.cyan('Each agent type has different capabilities and use cases.\n'));
}

async function createAgent(juliaBridge) {
    try {
        // Display the agent creation header
        displayAgentCreationHeader();

        // Step 1: Basic Information
        const basicInfo = await inquirer.prompt([
            {
                type: 'input',
                name: 'name',
                message: 'Enter agent name:',
                validate: input => input.length > 0 ? true : 'Name is required'
            },
            {
                type: 'list',
                name: 'type',
                message: 'Select agent type:',
                pageSize: 15,
                choices: [
                    { name: 'Julia Native Agent - Pure Julia implementation', value: 'julia_native' },
                    { name: 'OpenAI Agent - Powered by GPT models', value: 'openai' },
                    { name: 'Llama Agent - Open source LLM integration', value: 'llama' },
                    { name: 'Mistral Agent - Efficient language model', value: 'mistral' },
                    { name: 'Claude Agent - Anthropic\'s AI assistant', value: 'claude' },
                    new inquirer.Separator('--- Specialized Agents ---'),
                    { name: 'Trading Agent - Automated trading strategies', value: 'trading' },
                    { name: 'Arbitrage Agent - Cross-exchange price differences', value: 'arbitrage' },
                    { name: 'Liquidity Agent - Provide liquidity to DEXs', value: 'liquidity' },
                    { name: 'Monitoring Agent - Market and system monitoring', value: 'monitoring' },
                    { name: 'Data Agent - Data collection and analysis', value: 'data' },
                    new inquirer.Separator('--- Other Options ---'),
                    { name: 'Custom Agent - Define your own agent type', value: 'custom' },
                    { name: 'Back to previous menu', value: 'back' }
                ]
            }
        ]);

        if (basicInfo.type === 'back') {
            return;
        }

        // Step 2: Advanced Configuration
        const advancedConfig = await inquirer.prompt([
            {
                type: 'input',
                name: 'version',
                message: 'Enter agent version:',
                default: '1.0.0'
            },
            {
                type: 'number',
                name: 'max_memory',
                message: 'Maximum memory size (MB):',
                default: 1024
            },
            {
                type: 'number',
                name: 'max_skills',
                message: 'Maximum number of skills:',
                default: 10
            },
            {
                type: 'number',
                name: 'update_interval',
                message: 'Update interval (seconds):',
                default: 60
            }
        ]);

        // Step 3: Capabilities Selection
        console.log(chalk.cyan('\nCapabilities determine what your agent can do. Select all that apply:'));

        const capabilitiesSelection = await inquirer.prompt([
            {
                type: 'checkbox',
                name: 'capabilities',
                message: 'Select agent capabilities:',
                pageSize: 10,
                choices: [
                    { name: 'Basic Operations - Core functionality (required)', value: 'basic', checked: true, disabled: true },
                    new inquirer.Separator('--- Communication ---'),
                    { name: 'Network Communication - Connect to external services', value: 'network' },
                    { name: 'API Integration - Work with external APIs', value: 'api' },
                    { name: 'Messaging - Send/receive messages to other agents', value: 'messaging' },
                    new inquirer.Separator('--- Data Handling ---'),
                    { name: 'Data Processing - Analyze and transform data', value: 'data' },
                    { name: 'Storage - Persistent data storage capabilities', value: 'storage' },
                    { name: 'Database - Work with SQL and NoSQL databases', value: 'database' },
                    new inquirer.Separator('--- Advanced ---'),
                    { name: 'Machine Learning - ML model training and inference', value: 'ml' },
                    { name: 'Smart Contract Interaction - Work with blockchain', value: 'blockchain' },
                    { name: 'Scheduled Tasks - Run operations on a schedule', value: 'scheduled' },
                    { name: 'Advanced Analytics - Complex data analysis', value: 'analytics' }
                ]
            }
        ]);

        // Show selected capabilities
        if (capabilitiesSelection.capabilities.length > 1) { // More than just 'basic'
            console.log(chalk.green('\nSelected capabilities:'));
            capabilitiesSelection.capabilities.forEach(cap => {
                console.log(`  • ${cap}`);
            });
        }

        // Prepare the complete agent configuration
        const agentConfig = {
            id: uuidv4(),
            name: basicInfo.name,
            version: advancedConfig.version,
            agent_type: basicInfo.type,
            capabilities: capabilitiesSelection.capabilities.length > 0
                ? capabilitiesSelection.capabilities
                : ['basic'],
            max_memory: advancedConfig.max_memory,
            max_skills: advancedConfig.max_skills,
            update_interval: advancedConfig.update_interval,
            network_configs: {},
            status: "inactive"
        };

        // Show a summary and ask for confirmation
        console.log(chalk.cyan('\n╔═══════════ Agent Summary ════════════╗'));
        console.log(chalk.cyan(`║ Name: ${chalk.white(agentConfig.name)}${' '.repeat(Math.max(0, 30 - agentConfig.name.length))}║`));
        console.log(chalk.cyan(`║ Type: ${chalk.white(agentConfig.agent_type)}${' '.repeat(Math.max(0, 30 - agentConfig.agent_type.length))}║`));
        console.log(chalk.cyan(`║ Capabilities: ${chalk.white(agentConfig.capabilities.length)} selected${' '.repeat(Math.max(0, 15 - String(agentConfig.capabilities.length).length))}║`));
        console.log(chalk.cyan(`║ Memory: ${chalk.white(agentConfig.max_memory)} MB${' '.repeat(Math.max(0, 25 - String(agentConfig.max_memory).length))}║`));
        console.log(chalk.cyan('╚═════════════════════════════════════════╝'));

        const { confirmCreate } = await inquirer.prompt([
            {
                type: 'confirm',
                name: 'confirmCreate',
                message: 'Create this agent with the above configuration?',
                default: true
            }
        ]);

        if (!confirmCreate) {
            console.log(chalk.yellow('\nAgent creation cancelled.'));
            return;
        }

        // Create the agent
        console.log(chalk.blue('\nCreating agent...'));

        // Add a loading spinner for better user experience
        const ora = require('ora');
        const spinner = ora({
            text: 'Communicating with backend...',
            spinner: 'dots',
            color: 'blue'
        }).start();

        try {
            const result = await juliaBridge.executeCommand('create_agent', agentConfig, {
                showSpinner: false, // We're already showing our own spinner
                fallbackToMock: true
            });
            spinner.stop();

            if (result) {
                console.log(chalk.green('\n✅ Agent created successfully!'));
                console.log(chalk.cyan('\nAgent Details:'));
                console.log(chalk.cyan('╔════════════════════════════════════════════════════════════╗'));
                
                const agentId = (result.data && result.data.id) || result.id || agentConfig.id;
                console.log(chalk.cyan(`║  ID: ${chalk.white(agentId)}${' '.repeat(Math.max(0, 50 - String(agentId).length))}║`));
                
                console.log(chalk.cyan(`║  Name: ${chalk.white(agentConfig.name)}${' '.repeat(Math.max(0, 48 - agentConfig.name.length))}║`));
                console.log(chalk.cyan(`║  Type: ${chalk.white(agentConfig.agent_type)}${' '.repeat(Math.max(0, 48 - agentConfig.agent_type.length))}║`));
                console.log(chalk.cyan(`║  Status: ${chalk.yellow('inactive')}${' '.repeat(40)}║`));
                console.log(chalk.cyan('╚════════════════════════════════════════════════════════════╝'));

                console.log(chalk.cyan('\nTip: ') + 'Use "Start Agent" from the Agent Management menu to activate this agent.');
            } else {
                console.log(chalk.red('\n❌ Failed to create agent.'));
                if (result && result.error) {
                    console.log(chalk.red(`Error: ${result.error}`));
                } else {
                    console.log(chalk.red('No response received from the server.'));
                }
                if (result && result.details) {
                    console.log(chalk.red('Details:'), result.details);
                }
                console.log(chalk.yellow('\nTroubleshooting:'));
                console.log('1. Check if the agent name is unique');
                console.log('2. Verify that the Julia backend server is running');
                console.log('3. Check server logs for more details');
            }
        } catch (createError) {
            spinner.fail('Communication with backend failed');
            console.error(chalk.red(`\n❌ Error creating agent: ${createError.message}`));

            if (createError.message.includes('ECONNREFUSED') || createError.message.includes('socket hang up')) {
                console.log(chalk.yellow('\nThe Julia backend server appears to be offline or unreachable.'));
                console.log(chalk.cyan('\nTroubleshooting:'));
                console.log('1. Start the Julia server with: cd /Users/rabban/Desktop/JuliaOS && julia julia/julia_server.jl');
                console.log('2. Check if the server is running on the expected port (default: 8053)');
            }
        }
    } catch (error) {
        console.error(chalk.red('\n❌ Error in agent creation process:'), error.message);
        console.log(chalk.yellow('\nPlease try again or contact support if the issue persists.'));
    }
}

module.exports = createAgent;