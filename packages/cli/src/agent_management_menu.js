// Import required modules
const chalk = require('chalk');
const inquirer = require('inquirer');
const ora = require('ora');
const createAgent = require('./agent_creation_menu');

// Initialize variables that will be set by the module consumer
let juliaBridge;
let displayHeader;

/**
 * Display the agent management menu
 */
async function agentManagementMenu(breadcrumbs = ['Main', 'Agent Management']) {
    try {
        displayHeader('Agent Management');
        // Display a professional header for agent management
        console.log(chalk.green(`\n      ╔══════════════════════════════════════════╗\n      ║           Agent Management               ║\n      ║                                          ║\n      ║  🤖 Create, configure and manage AI      ║\n      ║     agents for various tasks.            ║\n      ║                                          ║\n      ╚══════════════════════════════════════════╝\n    `));
        // Add hotkeys/numbers to choices
        const actions = [
            'Create Agent',
            'List Agents',
            'Configure Agent',
            'Start Agent',
            'Stop Agent',
            'View Metrics',
            'Delete Agent',
            'Batch Operations',
            'Back'
        ];
        const numberedChoices = actions.map((action, idx) => `${idx + 1}. ${action}`);
        const { action } = await inquirer.prompt([
            {
                type: 'list',
                name: 'action',
                message: '👤 Select agent action:',
                choices: numberedChoices,
                pageSize: 10
            }
        ]);
        const selected = actions[numberedChoices.indexOf(action)];
        if (selected === 'Back') {
            return;
        }
        // Show a loading animation when an action is selected
        if (selected !== 'Back') {
            const spinner = ora({
                text: `Preparing ${selected.toLowerCase()}...`,
                spinner: 'dots',
                color: 'blue'
            }).start();
            await new Promise(resolve => setTimeout(resolve, 500));
            spinner.stop();
        }

        // Handle the selected action
        switch (selected) {
            case 'Create Agent':
                await createAgent(juliaBridge);
                break;
            case 'List Agents':
                await listAgents(breadcrumbs);
                break;
            case 'Configure Agent':
                await configureAgent(breadcrumbs);
                break;
            case 'Start Agent':
                await startAgent(breadcrumbs);
                break;
            case 'Stop Agent':
                await stopAgent(breadcrumbs);
                break;
            case 'View Metrics':
                await displayAgentMetrics(breadcrumbs);
                break;
            case 'Delete Agent':
                await deleteAgent(breadcrumbs);
                break;
            case 'Batch Operations':
                await batchOperations(breadcrumbs);
                break;
        }

        // Return to the menu after completing an action
        await agentManagementMenu(breadcrumbs);
    } catch (error) {
        console.error(chalk.red('\n✖ Error in agent management:'), error.message);
        await agentManagementMenu(breadcrumbs);
    }
}

/**
 * List all agents
 */
async function listAgents(breadcrumbs = ['Main', 'Agent Management', 'List Agents']) {
    displayHeader(breadcrumbs.join(' > '));
    const spinner = ora({
        text: 'Fetching agents from backend...',
        spinner: 'dots',
        color: 'blue'
    }).start();

    try {
        // Use the enhanced bridge to execute the command with better error handling
        const result = await juliaBridge.executeCommand('list_agents', {}, {
            showSpinner: false, // We're already showing our own spinner
            fallbackToMock: true // Allow fallback to mock data if backend is unavailable
        });

        spinner.stop();

        // Check if we have a valid response with agents array
        // Response format: { agents: [...], pagination: {...} }
        if (result && (Array.isArray(result) || (result.agents && Array.isArray(result.agents)))) {
            // Extract the agents array - handle both response formats
            const agents = Array.isArray(result) ? result : result.agents;
            
            // Get pagination info if available
            const pagination = result && result.pagination ? result.pagination : null;
            
            if (agents.length === 0) {
                spinner.info('No agents found.');
                console.log(chalk.yellow('\nNo agents currently exist. Use "Create Agent" to add one.'));
                console.log(chalk.cyan('\nTip: ') + 'Agents are used to automate tasks like trading, monitoring, and data analysis.');
            } else {
                const totalCount = pagination ? pagination.total : agents.length;
                spinner.succeed(`${agents.length} agent${agents.length > 1 ? 's' : ''} retrieved successfully${pagination ? ` (${totalCount} total)` : ''}.`);

                // Create a formatted table for better readability
                console.log(chalk.cyan('\n┌─ Available Agents ───────────────────────────────────────────┐'));

                agents.forEach((agent, index) => {
                    // Determine status color
                    let statusColor;
                    let statusIcon;
                    switch(agent.status) {
                        case 'active':
                            statusColor = chalk.green;
                            statusIcon = '✅';
                            break;
                        case 'inactive':
                            statusColor = chalk.yellow;
                            statusIcon = '⏸️';
                            break;
                        case 'failed':
                            statusColor = chalk.red;
                            statusIcon = '❌';
                            break;
                        case 'restarting':
                        case 'reloading':
                        case 'resetting':
                        case 'recreating':
                            statusColor = chalk.blue;
                            statusIcon = '🔄';
                            break;
                        default:
                            statusColor = chalk.gray;
                            statusIcon = '❓';
                    }

                    // Format created date
                    const createdDate = agent.created_at ? new Date(agent.created_at).toLocaleString() : 'Unknown';

                    console.log(chalk.cyan('│                                                              │'));
                    console.log(chalk.cyan(`│  ${chalk.bold(`${index + 1}. ${agent.name || 'Unnamed Agent'}`)}${' '.repeat(Math.max(0, 45 - (agent.name || 'Unnamed Agent').length - String(index + 1).length))}│`));
                    console.log(chalk.cyan(`│     ID: ${chalk.gray(agent.id)}${' '.repeat(Math.max(0, 45 - agent.id.length))}│`));
                    console.log(chalk.cyan(`│     Type: ${chalk.blue(agent.type || 'Unknown')}${' '.repeat(Math.max(0, 45 - (agent.type || 'Unknown').length))}│`));
                    console.log(chalk.cyan(`│     Status: ${statusIcon} ${statusColor(agent.status || 'Unknown')}${' '.repeat(Math.max(0, 42 - (agent.status || 'Unknown').length))}│`));
                    console.log(chalk.cyan(`│     Created: ${chalk.gray(createdDate)}${' '.repeat(Math.max(0, 42 - createdDate.length))}│`));

                    if (index < agents.length - 1) {
                        console.log(chalk.cyan('│     ────────────────────────────────────────────────────     │'));
                    }
                });

                console.log(chalk.cyan('│                                                              │'));
                console.log(chalk.cyan('└──────────────────────────────────────────────────────────────┘'));

                // Add action buttons for trading agents
                const tradingAgents = agents.filter(agent =>
                    agent.type === 'trading' || (agent.capabilities && agent.capabilities.includes('trading'))
                );

                if (tradingAgents.length > 0) {
                    console.log(chalk.cyan('\n┌─ Quick Actions ─────────────────────────────────────────────────┐'));
                    console.log(chalk.cyan('│                                                              │'));
                    console.log(chalk.cyan(`│  ${chalk.bold('Trading Agents')}${' '.repeat(56)}│`));

                    tradingAgents.forEach((agent, index) => {
                        console.log(chalk.cyan(`│  ${index + 1}. ${agent.name} - ${chalk.green('Trade Now')}${' '.repeat(Math.max(0, 50 - agent.name.length - String(index + 1).length))}│`));
                    });

                    console.log(chalk.cyan('│                                                              │'));
                    console.log(chalk.cyan('└──────────────────────────────────────────────────────────────┘'));

                    // Prompt for quick action
                    inquirer.prompt([
                        {
                            type: 'confirm',
                            name: 'useQuickAction',
                            message: 'Would you like to trade with one of these agents?',
                            default: false
                        }
                    ]).then(async ({ useQuickAction }) => {
                        if (useQuickAction) {
                            const { agentIndex } = await inquirer.prompt([
                                {
                                    type: 'list',
                                    name: 'agentIndex',
                                    message: 'Select a trading agent:',
                                    choices: tradingAgents.map((agent, idx) => ({
                                        name: `${idx + 1}. ${agent.name}`,
                                        value: idx
                                    })),
                                    pageSize: 10
                                }
                            ]);

                            const selectedAgent = tradingAgents[agentIndex];
                            console.log(chalk.green(`\nRedirecting to Trading menu with agent ${selectedAgent.name}...`));

                            // Store the selected agent ID in a global variable
                            global.selectedTradingAgentId = selectedAgent.id;
                            global.selectedTradingAgentName = selectedAgent.name;

                            // Return to main menu and then navigate to trading
                            console.log(chalk.green(`\nRedirecting to Trading menu with agent ${selectedAgent.name}...`));

                            // Set the navigation flag that will be checked in the main menu
                            global.navigateToTrading = true;

                            // Force return to main menu
                            setTimeout(() => {
                                // This will be handled by the main menu
                                return;
                            }, 1500);
                        }
                    });
                }

                // Add helpful tips
                console.log(chalk.cyan('\nTip: ') + 'Use "Start Agent" to activate an agent or "Configure Agent" to modify settings.');
            }
        } else {
            spinner.fail('Failed to fetch agents.');
            const errorMessage = result?.error || 'Unexpected response format from backend.';
            console.error(chalk.red(`\n✖ Error: ${errorMessage}`));

            // Provide more helpful error information
            if (result?.details) {
                console.error(chalk.red('Error details:'), result.details);
            }

            // Only show debug info if explicitly requested or in development mode
            if (process.env.NODE_ENV === 'development') {
                console.log(chalk.yellow("\nDEBUG: Full backend response:"), JSON.stringify(result, null, 2));
            } else {
                console.log(chalk.yellow("\nFor more details, run with NODE_ENV=development"));
            }

            // Provide troubleshooting tips
            console.log(chalk.cyan('\nTroubleshooting:'));
            console.log('1. Check if the Julia backend server is running');
            console.log('2. Verify network connectivity to the backend');
            console.log('3. Check server logs for more details');
        }
    } catch (error) {
        spinner.fail('Failed to communicate with backend.');
        console.error(chalk.red(`\n✖ Error listing agents: ${error.message}`));

        // Provide more specific error guidance
        if (error.message.includes('ECONNREFUSED') || error.message.includes('socket hang up')) {
            console.log(chalk.yellow('\nThe Julia backend server appears to be offline or unreachable.'));
            console.log(chalk.cyan('\nTroubleshooting:'));
            console.log('1. Start the Julia server with: cd /Users/rabban/Desktop/JuliaOS && julia julia/julia_server.jl');
            console.log('2. Check if the server is running on the expected port (default: 8053)');
            console.log('3. Verify there are no firewall or network issues blocking the connection');
        } else if (error.message.includes('timeout')) {
            console.log(chalk.yellow('\nThe request to the backend timed out.'));
            console.log(chalk.cyan('\nTroubleshooting:'));
            console.log('1. The server might be overloaded or processing a long-running task');
            console.log('2. Try again in a few moments');
            console.log('3. Check server logs for any performance issues');
        } else {
            console.log(chalk.yellow('\nAn unexpected error occurred while communicating with the backend.'));
            console.log(chalk.cyan('\nTroubleshooting:'));
            console.log('1. Check the CLI and server logs for more details');
            console.log('2. Restart both the CLI and the server if the issue persists');
        }
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: '🔄 Press Enter to continue...'}]);
    // No automatic return here, let agentManagementMenu handle the loop
}

/**
 * Configure an existing agent
 */
async function configureAgent(breadcrumbs = ['Main', 'Agent Management', 'Configure Agent']) {
    displayHeader(breadcrumbs.join(' > '));
    const listSpinner = ora('Fetching agents...').start();
    let agents = [];

    try {
        // List agents first to allow selection
        const listResult = await juliaBridge.executeCommand('list_agents', {}, {
            showSpinner: false, // We're already showing our own spinner
            fallbackToMock: true // Allow fallback to mock data if backend is unavailable
        });

        if (!(listResult && Array.isArray(listResult))) {
            listSpinner.fail('Failed to fetch agents.');
            const listError = 'Unexpected response format from backend.';
            console.error(chalk.red(`Error listing agents: ${listError}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return; // Can't configure if we can't list
        }
        agents = listResult;
        listSpinner.succeed('Agents retrieved.');

        if (agents.length === 0) {
            console.log(chalk.yellow('\nNo agents found to configure. Create an agent first.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

    } catch (error) {
        listSpinner.fail('Failed to communicate with backend while listing agents.');
        console.error(chalk.red(`Error: ${error.message}`));
        if (error.message.includes('ECONNREFUSED') || error.message.includes('socket hang up')) {
            console.log(chalk.yellow('Hint: Is the Julia backend server running?'));
        }
        await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
        return;
    }

    // Prompt user to select an agent
    try {
        const { agentId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'agentId',
                message: 'Select an agent to configure:',
                choices: [
                    ...agents.map(agent => ({
                        name: `${agent.name || 'Unnamed'} (${agent.id})`,
                        value: agent.id
                    })),
                    new inquirer.Separator(),
                    { name: 'Cancel', value: null }
                ],
                pageSize: 15
            }
        ]);

        if (agentId === null) {
            console.log(chalk.yellow('Configuration cancelled.'));
            await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
            return;
        }

        // Fetch current details for defaults (optional but good UX)
        const selectedAgent = agents.find(a => a.id === agentId) || { name: 'Unknown', config: {} };

        // Prompt for configuration updates
        const { name, configInput } = await inquirer.prompt([
            {
                type: 'input',
                name: 'name',
                message: 'Enter new agent name (leave blank to keep current):',
                default: selectedAgent.name
            },
            {
                type: 'input',
                name: 'configInput',
                message: 'Enter new agent configuration (JSON, leave blank to keep current):',
                default: JSON.stringify(selectedAgent.config || {}, null, 2)
            }
        ]);

        // Parse the config
        let parsedConfig = {};
        try {
            if (configInput.trim() !== '') {
                parsedConfig = JSON.parse(configInput);
            }
        } catch (error) {
            console.log(chalk.red('\nInvalid JSON configuration format. Please try again.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return await configureAgent(breadcrumbs); // Retry configuration
        }

        // Prepare updates object, only include changed fields
        const updates = {};
        if (name && name !== selectedAgent.name) {
            updates.name = name;
        }
        // Only include config if it was provided and parsed
        if (configInput.trim() !== '') {
            updates.config = parsedConfig;
        }

        if (Object.keys(updates).length === 0) {
            console.log(chalk.yellow('No changes specified. Agent configuration remains unchanged.'));
            await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
            return;
        }

        // Update the agent
        const updateSpinner = ora('Updating agent...').start();
        try {
            const updateResult = await juliaBridge.executeCommand('update_agent', {
                id: agentId,
                updates: updates
            }, {
                showSpinner: false, // We're already showing our own spinner
                fallbackToMock: false // Don't allow fallback for updates
            });

            updateSpinner.stop();
            if (updateResult) {
                updateSpinner.succeed('Agent updated successfully!');
                // Optionally display updated agent details if returned in updateResult
            } else {
                updateSpinner.fail('Failed to update agent.');
                console.error(chalk.red(`Error: Unknown error from backend.`));
            }
        } catch (error) {
            updateSpinner.fail('Failed to communicate with backend while updating agent.');
            console.error(chalk.red(`Error: ${error.message}`));
            if (error.message.includes('ECONNREFUSED') || error.message.includes('socket hang up')) {
                console.log(chalk.yellow('Hint: Is the Julia backend server running?'));
            }
        }
    } catch (error) {
        // Catch errors from inquirer prompts etc.
        console.error(chalk.red(`An unexpected error occurred during configuration: ${error.message}`));
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
    // No automatic return here, let agentManagementMenu handle the loop
}

/**
 * Start an existing agent
 */
async function startAgent(breadcrumbs = ['Main', 'Agent Management', 'Start Agent']) {
    displayHeader(breadcrumbs.join(' > '));
    await selectAgentAndRunCommand({
        promptMessage: 'Select an agent to start:',
        command: 'agents.update_agent',
        updateData: { status: 'active' },
        loadingMessage: 'Starting agent...',
        successMessage: 'Agent started successfully!',
        errorMessage: 'Failed to start agent.',
        filterPredicate: agent => agent.status !== 'active' // Only show non-active agents
    });
    // No automatic return here, let agentManagementMenu handle the loop
}

/**
 * Stop an existing agent
 */
async function stopAgent(breadcrumbs = ['Main', 'Agent Management', 'Stop Agent']) {
    displayHeader(breadcrumbs.join(' > '));
    await selectAgentAndRunCommand({
        promptMessage: 'Select an agent to stop:',
        command: 'agents.update_agent',
        updateData: { status: 'inactive' },
        loadingMessage: 'Stopping agent...',
        successMessage: 'Agent stopped successfully!',
        errorMessage: 'Failed to stop agent.',
        filterPredicate: agent => agent.status === 'active' // Only show active agents
    });
    // No automatic return here, let agentManagementMenu handle the loop
}

/**
 * Delete an existing agent
 */
async function deleteAgent(breadcrumbs = ['Main', 'Agent Management', 'Delete Agent']) {
    displayHeader(breadcrumbs.join(' > '));
    await selectAgentAndRunCommand({
        promptMessage: 'Select an agent to DELETE:',
        command: 'agents.delete_agent',
        updateData: null, // No update data needed for delete
        loadingMessage: 'Deleting agent...',
        successMessage: 'Agent deleted successfully!',
        errorMessage: 'Failed to delete agent.',
        confirmPrompt: true // Add confirmation step
    });
    // No automatic return here, let agentManagementMenu handle the loop
}

// Helper function to reduce repetition for start/stop/delete
async function selectAgentAndRunCommand(options) {
    const { promptMessage, command, updateData, loadingMessage, successMessage, errorMessage, filterPredicate, confirmPrompt = false } = options;

    const listSpinner = ora('Fetching agents...').start();
    let agents = [];
    try {
        const listResult = await juliaBridge.executeCommand('list_agents', {}, {
            showSpinner: false, // We're already showing our own spinner
            fallbackToMock: true // Allow fallback to mock data if backend is unavailable
        });

        if (!(listResult && Array.isArray(listResult))) {
            listSpinner.fail('Failed to fetch agents.');
            console.error(chalk.red(`Error listing agents: Unexpected response format.`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        agents = listResult;

        // Apply filter if provided
        if (filterPredicate) {
            agents = agents.filter(filterPredicate);
        }

        listSpinner.succeed('Agents retrieved.');

        if (agents.length === 0) {
            console.log(chalk.yellow('\nNo suitable agents found for this operation.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

    } catch (error) {
        listSpinner.fail('Failed to communicate with backend while listing agents.');
        console.error(chalk.red(`Error: ${error.message}`));
        if (error.message.includes('ECONNREFUSED') || error.message.includes('socket hang up')) {
            console.log(chalk.yellow('Hint: Is the Julia backend server running?'));
        }
        await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
        return;
    }

    try {
        const { agentId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'agentId',
                message: promptMessage,
                choices: [
                    ...agents.map(agent => ({
                        name: `${agent.name || 'Unnamed'} (${agent.id}) - Status: ${agent.status || 'Unknown'}`,
                        value: agent.id
                    })),
                    new inquirer.Separator(),
                    { name: 'Cancel', value: null }
                ],
                pageSize: 15
            }
        ]);

        if (agentId === null) {
            console.log(chalk.yellow('Operation cancelled.'));
            await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
            return;
        }

        if (confirmPrompt) {
            const { confirm } = await inquirer.prompt([{
                type: 'confirm',
                name: 'confirm',
                message: chalk.red(`Are you sure you want to ${command.split('.')[1]} agent ${agentId}? This cannot be undone. `),
                default: false
            }]);
            if (!confirm) {
                console.log(chalk.yellow('Operation cancelled.'));
                await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
                return;
            }
        }

        const commandSpinner = ora(loadingMessage).start();
        try {
            // Prepare parameters
            const params = { id: agentId };
            if (updateData !== null) {
                // For update operations
                params.updates = updateData;
            } // For delete, only id is needed

            // Use the enhanced bridge with better error handling
            const commandName = command.split('.')[1]; // Extract the command name from the full command
            const commandResult = await juliaBridge.executeCommand(commandName, params, {
                showSpinner: false, // We're already showing our own spinner
                fallbackToMock: false // Don't allow fallback for critical operations
            });

            commandSpinner.stop();
            if (commandResult) {
                commandSpinner.succeed(successMessage);
                // Optionally display updated agent status if returned
            } else {
                commandSpinner.fail(errorMessage);
                console.error(chalk.red(`Error: Unknown error from backend.`));
            }
        } catch (error) {
            commandSpinner.fail('Failed to communicate with backend.');
            console.error(chalk.red(`Error during command execution: ${error.message}`));
            if (error.message.includes('ECONNREFUSED') || error.message.includes('socket hang up')) {
                console.log(chalk.yellow('Hint: Is the Julia backend server running?'));
            }
        }
    } catch (error) {
        console.error(chalk.red(`An unexpected error occurred: ${error.message}`));
    }
    await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

/**
 * Display metrics for a specific agent
 */
async function displayAgentMetrics(breadcrumbs = ['Main', 'Agent Management', 'View Metrics']) {
    displayHeader(breadcrumbs.join(' > '));
    const listSpinner = ora('Fetching agents...').start();
    let agents = [];
    try {
        const listResult = await juliaBridge.runJuliaCommand('agents.list_agents', {});
        if (!(listResult && listResult.success && Array.isArray(listResult.data))) {
            listSpinner.fail('Failed to fetch agents.');
            const listError = listResult?.error || 'Unexpected response format.';
            console.error(chalk.red(`Error listing agents: ${listError}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        agents = listResult.data;
        listSpinner.succeed('Agents retrieved.');

        if (agents.length === 0) {
            console.log(chalk.yellow('\nNo agents found to view metrics for.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

    } catch (error) {
        listSpinner.fail('Failed to communicate with backend while listing agents.');
        console.error(chalk.red(`Error: ${error.message}`));
        if (error.message.includes('ECONNREFUSED') || error.message.includes('socket hang up')) {
            console.log(chalk.yellow('Hint: Is the Julia backend server running?'));
        }
        await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
        return;
    }

    try {
        const { agentId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'agentId',
                message: 'Select an agent to view metrics:',
                choices: [
                    ...agents.map(agent => ({
                        name: `${agent.name || 'Unnamed'} (${agent.id})`,
                        value: agent.id
                    })),
                    new inquirer.Separator(),
                    { name: 'Cancel', value: null }
                ],
                pageSize: 15
            }
        ]);

        if (agentId === null) {
            console.log(chalk.yellow('Operation cancelled.'));
            await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
            return;
        }

        const metricsSpinner = ora(`Fetching metrics for agent ${agentId}...`).start();
        try {
            // Assume backend command is 'agents.get_metrics' or similar
            const metricsResult = await juliaBridge.runJuliaCommand('agents.get_metrics', { id: agentId });

            metricsSpinner.stop();
            if (metricsResult && metricsResult.success && metricsResult.data) {
                metricsSpinner.succeed('Metrics retrieved successfully!');
                const metrics = metricsResult.data;
                console.log(chalk.cyan('\nAgent Metrics:'));
                // Display metrics - adjust keys based on actual backend response
                console.log(`  CPU Usage:      ${metrics.cpu || 'N/A'}`);
                console.log(`  Memory Usage:   ${metrics.memory || 'N/A'}`);
                console.log(`  Tasks Processed:${metrics.tasks_processed || 'N/A'}`);
                console.log(`  Active Threads: ${metrics.active_threads || 'N/A'}`);
                console.log(`  Uptime:         ${metrics.uptime || 'N/A'}`);
                // Add more metrics as available from the backend
            } else {
                metricsSpinner.fail('Failed to fetch metrics.');
                const metricsError = metricsResult?.error || 'Unknown error or invalid format from backend.';
                console.error(chalk.red(`Error: ${metricsError}`));
            }
        } catch (error) {
            metricsSpinner.fail('Failed to communicate with backend while fetching metrics.');
            console.error(chalk.red(`Error: ${error.message}`));
            if (error.message.includes('ECONNREFUSED') || error.message.includes('socket hang up')) {
                console.log(chalk.yellow('Hint: Is the Julia backend server running?'));
            }
        }
    } catch (error) {
        console.error(chalk.red(`An unexpected error occurred: ${error.message}`));
    }
    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
    // No automatic return here, let agentManagementMenu handle the loop
}

/**
 * Batch operations for agents
 */
async function batchOperations(breadcrumbs = ['Main', 'Agent Management', 'Batch Operations']) {
    displayHeader(breadcrumbs.join(' > '));
    console.log(chalk.cyan(`
      ╔══════════════════════════════════════════╗
      ║           Batch Operations               ║
      ║                                          ║
      ║  🔄 Perform operations on multiple       ║
      ║     agents at once.                      ║
      ║                                          ║
      ╚══════════════════════════════════════════╝
    `));

    // First, get the list of all agents
    const listSpinner = ora('Fetching agents...').start();
    let agents = [];

    try {
        const listResult = await juliaBridge.executeCommand('list_agents', {}, {
            showSpinner: false,
            fallbackToMock: true
        });

        if (!(listResult && Array.isArray(listResult))) {
            listSpinner.fail('Failed to fetch agents.');
            console.error(chalk.red(`Error listing agents: Unexpected response format.`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        agents = listResult;
        listSpinner.succeed(`${agents.length} agents retrieved.`);

        if (agents.length === 0) {
            console.log(chalk.yellow('\nNo agents found. Create some agents first.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        // Ask user what batch operation they want to perform
        const { operation } = await inquirer.prompt([
            {
                type: 'list',
                name: 'operation',
                message: 'Select batch operation:',
                choices: [
                    { name: '1. Start Multiple Agents', value: 'start' },
                    { name: '2. Stop Multiple Agents', value: 'stop' },
                    { name: '3. Delete Multiple Agents', value: 'delete' },
                    { name: '4. Export Agents', value: 'export' },
                    { name: '0. Back', value: 'back' }
                ]
            }
        ]);

        if (operation === 'back') {
            return;
        }

        // Filter agents based on operation
        let eligibleAgents = [];
        switch (operation) {
            case 'start':
                eligibleAgents = agents.filter(agent => agent.status !== 'active');
                if (eligibleAgents.length === 0) {
                    console.log(chalk.yellow('\nAll agents are already active.'));
                    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
                    return;
                }
                break;
            case 'stop':
                eligibleAgents = agents.filter(agent => agent.status === 'active');
                if (eligibleAgents.length === 0) {
                    console.log(chalk.yellow('\nNo active agents found.'));
                    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
                    return;
                }
                break;
            case 'delete':
            case 'export':
                eligibleAgents = agents; // All agents are eligible for delete/export
                break;
        }

        // Let user select multiple agents
        const { selectedAgentIds } = await inquirer.prompt([
            {
                type: 'checkbox',
                name: 'selectedAgentIds',
                message: `Select agents to ${operation}:`,
                choices: eligibleAgents.map(agent => ({
                    name: `${agent.name || 'Unnamed'} (${agent.id}) - Status: ${agent.status || 'Unknown'}`,
                    value: agent.id,
                    checked: false
                })),
                pageSize: 15,
                validate: input => input.length > 0 ? true : 'Please select at least one agent'
            }
        ]);

        if (selectedAgentIds.length === 0) {
            console.log(chalk.yellow('No agents selected. Operation cancelled.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        // Confirm the operation
        if (operation === 'delete') {
            const { confirm } = await inquirer.prompt([
                {
                    type: 'confirm',
                    name: 'confirm',
                    message: chalk.red(`Are you sure you want to DELETE ${selectedAgentIds.length} agent(s)? This cannot be undone.`),
                    default: false
                }
            ]);

            if (!confirm) {
                console.log(chalk.yellow('Operation cancelled.'));
                await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
                return;
            }
        }

        // Perform the batch operation
        const operationSpinner = ora(`Performing batch ${operation} on ${selectedAgentIds.length} agent(s)...`).start();

        try {
            let successCount = 0;
            let failCount = 0;
            let results = [];

            // Process each agent
            for (const agentId of selectedAgentIds) {
                try {
                    let result;
                    switch (operation) {
                        case 'start':
                            result = await juliaBridge.executeCommand('update_agent', {
                                id: agentId,
                                updates: { status: 'active' }
                            }, {
                                showSpinner: false,
                                fallbackToMock: false
                            });
                            break;
                        case 'stop':
                            result = await juliaBridge.executeCommand('update_agent', {
                                id: agentId,
                                updates: { status: 'inactive' }
                            }, {
                                showSpinner: false,
                                fallbackToMock: false
                            });
                            break;
                        case 'delete':
                            result = await juliaBridge.executeCommand('delete_agent', {
                                id: agentId
                            }, {
                                showSpinner: false,
                                fallbackToMock: false
                            });
                            break;
                        case 'export':
                            // For export, we need to get the full agent details
                            result = await juliaBridge.executeCommand('get_agent', {
                                id: agentId
                            }, {
                                showSpinner: false,
                                fallbackToMock: true
                            });
                            break;
                    }

                    if (result) {
                        successCount++;
                        results.push({ id: agentId, success: true, result });
                    } else {
                        failCount++;
                        results.push({ id: agentId, success: false, error: 'Unknown error' });
                    }
                } catch (error) {
                    failCount++;
                    results.push({ id: agentId, success: false, error: error.message });
                }

                // Update spinner text to show progress
                operationSpinner.text = `Processing agent ${results.length}/${selectedAgentIds.length}... (${successCount} succeeded, ${failCount} failed)`;
            }

            operationSpinner.succeed(`Batch operation completed: ${successCount} succeeded, ${failCount} failed`);

            // Handle export operation specially
            if (operation === 'export' && successCount > 0) {
                const exportData = results
                    .filter(r => r.success)
                    .map(r => r.result);

                // Format the export data
                const exportJson = JSON.stringify(exportData, null, 2);

                // Show export data
                console.log(chalk.cyan('\nExported Agent Data:'));
                console.log(exportJson);

                console.log(chalk.green('\nCopy the above JSON data to save your agent configurations.'));
            }

            // Show detailed results
            if (failCount > 0) {
                console.log(chalk.yellow('\nFailed operations:'));
                results
                    .filter(r => !r.success)
                    .forEach(r => {
                        const agent = agents.find(a => a.id === r.id);
                        console.log(chalk.red(`- ${agent?.name || 'Unknown'} (${r.id}): ${r.error}`));
                    });
            }

        } catch (error) {
            operationSpinner.fail(`Batch operation failed: ${error.message}`);
        }

    } catch (error) {
        listSpinner.fail('Failed to communicate with backend.');
        console.error(chalk.red(`Error: ${error.message}`));
        if (error.message.includes('ECONNREFUSED') || error.message.includes('socket hang up')) {
            console.log(chalk.yellow('Hint: Is the Julia backend server running?'));
        }
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

// Export the module with a function that takes the required dependencies
module.exports = function(dependencies) {
    // Assign dependencies to local variables
    juliaBridge = dependencies.juliaBridge;
    displayHeader = dependencies.displayHeader;

    // Return the main menu function and potentially others if needed
    return {
        agentManagementMenu
    };
};
