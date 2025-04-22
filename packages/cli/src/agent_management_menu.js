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
            'Pause Agent',
            'Resume Agent',
            'Execute Task',
            'View Memory',
            'Clear Memory',
            'View Metrics',
            'View Health Status',
            'View Agent Memory',
            'Clear Agent Memory',
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
            case 'Pause Agent':
                await pauseAgent(breadcrumbs);
                break;
            case 'Resume Agent':
                await resumeAgent(breadcrumbs);
                break;
            case 'Execute Task':
                await executeAgentTask(breadcrumbs);
                break;
            case 'View Memory':
                await viewAgentMemory(breadcrumbs);
                break;
            case 'Clear Memory':
                await clearAgentMemory(breadcrumbs);
                break;
            case 'View Metrics':
                await displayAgentMetrics(breadcrumbs);
                break;
            case 'View Health Status':
                await displayAgentHealth(breadcrumbs);
                break;
            case 'Start Monitoring':
                await startAgentMonitoring(breadcrumbs);
                break;
            case 'Stop Monitoring':
                await stopAgentMonitoring(breadcrumbs);
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
        // Response format: { success: true, data: { agents: [...], pagination: {...} } }
        if (result &&
            ((result.success && result.data && Array.isArray(result.data.agents)) || // New format
             (Array.isArray(result) || (result.agents && Array.isArray(result.agents))))) { // Old formats

            // Extract the agents array - handle all response formats
            let agents = [];
            if (result.success && result.data && Array.isArray(result.data.agents)) {
                agents = result.data.agents;
            } else if (Array.isArray(result)) {
                agents = result;
            } else if (result.agents && Array.isArray(result.agents)) {
                agents = result.agents;
            }

            // Get pagination info if available
            let pagination = null;
            if (result && result.pagination) {
                pagination = result.pagination;
            } else if (result && result.data && result.data.pagination) {
                pagination = result.data.pagination;
            }

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
                        case 'RUNNING':
                            statusColor = chalk.green;
                            statusIcon = '✅';
                            break;
                        case 'STOPPED':
                            statusColor = chalk.yellow;
                            statusIcon = '⏹️';
                            break;
                        case 'PAUSED':
                            statusColor = chalk.yellow;
                            statusIcon = '⏸️';
                            break;
                        case 'CREATED':
                            statusColor = chalk.blue;
                            statusIcon = '🆕';
                            break;
                        case 'INITIALIZING':
                            statusColor = chalk.blue;
                            statusIcon = '🔄';
                            break;
                        case 'ERROR':
                            statusColor = chalk.red;
                            statusIcon = '❌';
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
                    agent.type === 1 || // TRADING type
                    (agent.capabilities && agent.capabilities.includes('trading'))
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

        // Handle different response formats
        if (listResult && listResult.success && listResult.data && listResult.data.agents) {
            // New format: { success: true, data: { agents: [...] } }
            agents = listResult.data.agents;
        } else if (listResult && Array.isArray(listResult)) {
            // Old format: direct array
            agents = listResult;
        } else if (listResult && listResult.agents && Array.isArray(listResult.agents)) {
            // Old format: { agents: [...] }
            agents = listResult.agents;
        } else {
            listSpinner.fail('Failed to fetch agents.');
            const listError = 'Unexpected response format from backend.';
            console.error(chalk.red(`Error listing agents: ${listError}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return; // Can't configure if we can't list
        }
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
            const updateResult = await juliaBridge.executeCommand('agents.update_agent', {
                agent_id: agentId,
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
        command: 'start_agent',
        updateData: null, // No update data needed for start_agent
        loadingMessage: 'Starting agent...',
        successMessage: 'Agent started successfully!',
        errorMessage: 'Failed to start agent.',
        filterPredicate: agent => agent.status !== 'RUNNING' // Only show non-running agents
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
        command: 'stop_agent',
        updateData: null, // No update data needed for stop_agent
        loadingMessage: 'Stopping agent...',
        successMessage: 'Agent stopped successfully!',
        errorMessage: 'Failed to stop agent.',
        filterPredicate: agent => agent.status === 'RUNNING' || agent.status === 'PAUSED' // Only show running or paused agents
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
        command: 'delete_agent',
        updateData: null, // No update data needed for delete
        loadingMessage: 'Deleting agent...',
        successMessage: 'Agent deleted successfully!',
        errorMessage: 'Failed to delete agent.',
        confirmPrompt: true // Add confirmation step
    });
    // No automatic return here, let agentManagementMenu handle the loop
}

/**
 * Pause a running agent
 */
async function pauseAgent(breadcrumbs = ['Main', 'Agent Management', 'Pause Agent']) {
    displayHeader(breadcrumbs.join(' > '));
    await selectAgentAndRunCommand({
        promptMessage: 'Select an agent to pause:',
        command: 'pause_agent',
        updateData: null, // No update data needed for pause
        loadingMessage: 'Pausing agent...',
        successMessage: 'Agent paused successfully!',
        errorMessage: 'Failed to pause agent.',
        filterPredicate: agent => agent.status === 'RUNNING' // Only show running agents
    });
}

/**
 * Resume a paused agent
 */
async function resumeAgent(breadcrumbs = ['Main', 'Agent Management', 'Resume Agent']) {
    displayHeader(breadcrumbs.join(' > '));
    await selectAgentAndRunCommand({
        promptMessage: 'Select an agent to resume:',
        command: 'resume_agent',
        updateData: null, // No update data needed for resume
        loadingMessage: 'Resuming agent...',
        successMessage: 'Agent resumed successfully!',
        errorMessage: 'Failed to resume agent.',
        filterPredicate: agent => agent.status === 'PAUSED' // Only show paused agents
    });
}

/**
 * Execute a task on an agent
 */
async function executeAgentTask(breadcrumbs = ['Main', 'Agent Management', 'Execute Task']) {
    displayHeader(breadcrumbs.join(' > '));

    // First, select an agent
    const listSpinner = ora('Fetching agents...').start();
    let agents = [];

    try {
        const listResult = await juliaBridge.executeCommand('list_agents', {}, {
            showSpinner: false,
            fallbackToMock: true
        });

        // Handle different response formats
        if (listResult && listResult.success && listResult.data && listResult.data.agents) {
            // New format: { success: true, data: { agents: [...] } }
            agents = listResult.data.agents;
        } else if (listResult && Array.isArray(listResult)) {
            // Old format: direct array
            agents = listResult;
        } else if (listResult && listResult.agents && Array.isArray(listResult.agents)) {
            // Old format: { agents: [...] }
            agents = listResult.agents;
        } else {
            listSpinner.fail('Failed to fetch agents.');
            console.error(chalk.red(`Error listing agents: Unexpected response format`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return; // Can't continue if we can't list
        }
        listSpinner.succeed('Agents retrieved.');

        if (agents.length === 0) {
            console.log(chalk.yellow('\nNo agents found. Create an agent first.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        // Filter for running agents
        const runningAgents = agents.filter(agent => agent.status === 'RUNNING');

        if (runningAgents.length === 0) {
            console.log(chalk.yellow('\nNo running agents found. Start an agent first.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        // Select an agent
        const { agentId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'agentId',
                message: 'Select an agent to execute a task on:',
                choices: [
                    ...runningAgents.map(agent => ({
                        name: `${agent.name || 'Unnamed'} (${agent.id}) - ${agent.status}`,
                        value: agent.id
                    })),
                    new inquirer.Separator(),
                    { name: 'Cancel', value: null }
                ],
                pageSize: 15
            }
        ]);

        if (agentId === null) {
            console.log(chalk.yellow('Task execution cancelled.'));
            await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
            return;
        }

        // Select a task type
        const { taskType } = await inquirer.prompt([
            {
                type: 'list',
                name: 'taskType',
                message: 'Select task type:',
                choices: [
                    { name: 'Ping (test connection)', value: 'ping' },
                    { name: 'LLM Chat (send prompt to agent)', value: 'llm_chat' },
                    { name: 'Custom Task (JSON format)', value: 'custom' },
                    new inquirer.Separator(),
                    { name: 'Cancel', value: null }
                ]
            }
        ]);

        if (taskType === null) {
            console.log(chalk.yellow('Task execution cancelled.'));
            await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
            return;
        }

        // Prepare task data based on type
        let taskData = {};

        if (taskType === 'ping') {
            taskData = { ability: 'ping' };
        } else if (taskType === 'llm_chat') {
            const { prompt } = await inquirer.prompt([
                {
                    type: 'input',
                    name: 'prompt',
                    message: 'Enter your prompt:',
                    validate: input => input.length > 0 ? true : 'Prompt is required'
                }
            ]);

            taskData = { ability: 'llm_chat', prompt };
        } else if (taskType === 'custom') {
            const { customTask } = await inquirer.prompt([
                {
                    type: 'editor',
                    name: 'customTask',
                    message: 'Enter custom task in JSON format:',
                    default: JSON.stringify({ ability: 'custom_ability', parameters: {} }, null, 2)
                }
            ]);

            try {
                taskData = JSON.parse(customTask);
            } catch (error) {
                console.log(chalk.red(`Invalid JSON format: ${error.message}`));
                await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
                return;
            }
        }

        // Execute the task
        const taskSpinner = ora('Executing task...').start();

        try {
            const result = await juliaBridge.executeCommand('execute_agent_task', {
                agent_id: agentId,
                task: taskData
            }, {
                showSpinner: false,
                fallbackToMock: false
            });

            taskSpinner.succeed('Task executed successfully!');

            console.log(chalk.cyan('\nTask Result:'));
            console.log(chalk.cyan('╔════════════════════════════════════════════════════════════╗'));
            console.log(chalk.cyan('║  Response:                                                ║'));

            // Extract the actual result data from the response
            const resultData = result && result.success && result.data ? result.data : result;

            // Format the result for display
            const resultStr = JSON.stringify(resultData, null, 2);
            const lines = resultStr.split('\n');

            lines.forEach(line => {
                // Truncate long lines
                const displayLine = line.length > 50 ? line.substring(0, 47) + '...' : line;
                console.log(chalk.cyan(`║  ${chalk.white(displayLine)}${' '.repeat(Math.max(0, 50 - displayLine.length))}║`));
            });

            console.log(chalk.cyan('╚════════════════════════════════════════════════════════════╝'));
        } catch (error) {
            taskSpinner.fail(`Failed to execute task: ${error.message}`);
        }
    } catch (error) {
        if (listSpinner) listSpinner.fail(`Error: ${error.message}`);
        console.error(chalk.red(`An error occurred: ${error.message}`));
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * View agent memory
 */
async function viewAgentMemory(breadcrumbs = ['Main', 'Agent Management', 'View Memory']) {
    displayHeader(breadcrumbs.join(' > '));

    // First, select an agent
    const listSpinner = ora('Fetching agents...').start();
    let agents = [];

    try {
        const listResult = await juliaBridge.executeCommand('list_agents', {}, {
            showSpinner: false,
            fallbackToMock: true
        });

        // Handle different response formats
        if (listResult && listResult.success && listResult.data && listResult.data.agents) {
            // New format: { success: true, data: { agents: [...] } }
            agents = listResult.data.agents;
        } else if (listResult && Array.isArray(listResult)) {
            // Old format: direct array
            agents = listResult;
        } else if (listResult && listResult.agents && Array.isArray(listResult.agents)) {
            // Old format: { agents: [...] }
            agents = listResult.agents;
        } else {
            listSpinner.fail('Failed to fetch agents.');
            console.error(chalk.red(`Error listing agents: Unexpected response format`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return; // Can't continue if we can't list
        }
        listSpinner.succeed('Agents retrieved.');

        if (agents.length === 0) {
            console.log(chalk.yellow('\nNo agents found. Create an agent first.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        // Select an agent
        const { agentId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'agentId',
                message: 'Select an agent to view memory:',
                choices: [
                    ...agents.map(agent => ({
                        name: `${agent.name || 'Unnamed'} (${agent.id}) - ${agent.status}`,
                        value: agent.id
                    })),
                    new inquirer.Separator(),
                    { name: 'Cancel', value: null }
                ],
                pageSize: 15
            }
        ]);

        if (agentId === null) {
            console.log(chalk.yellow('Memory view cancelled.'));
            await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
            return;
        }

        // Get memory key
        const { memoryKey } = await inquirer.prompt([
            {
                type: 'input',
                name: 'memoryKey',
                message: 'Enter memory key to retrieve (leave empty to view all):',
                default: ''
            }
        ]);

        // Get memory
        const memorySpinner = ora('Retrieving memory...').start();

        try {
            let result;

            if (memoryKey.trim() === '') {
                // Get all memory (this is a mock since the API doesn't directly support this)
                // In a real implementation, you'd need to add an API endpoint for this
                result = await juliaBridge.executeCommand('get_agent', {
                    agent_id: agentId
                }, {
                    showSpinner: false,
                    fallbackToMock: true
                });

                // Extract memory from agent data
                // Handle different response formats
                let memory = {};
                if (result && result.success && result.data && result.data.memory) {
                    // New format: { success: true, data: { memory: {...} } }
                    memory = result.data.memory;
                } else if (result && result.memory) {
                    // Old format: { memory: {...} }
                    memory = result.memory;
                }

                memorySpinner.succeed('Memory retrieved successfully!');

                console.log(chalk.cyan('\nAgent Memory:'));
                console.log(chalk.cyan('╔════════════════════════════════════════════════════════════╗'));

                if (Object.keys(memory).length === 0) {
                    console.log(chalk.cyan(`║  ${chalk.yellow('No memory entries found')}${' '.repeat(30)}║`));
                } else {
                    for (const [key, value] of Object.entries(memory)) {
                        console.log(chalk.cyan(`║  ${chalk.white(key)}: ${chalk.gray(JSON.stringify(value).substring(0, 30))}${' '.repeat(Math.max(0, 40 - key.length - JSON.stringify(value).substring(0, 30).length))}║`));
                    }
                }

                console.log(chalk.cyan('╚════════════════════════════════════════════════════════════╝'));
            } else {
                // Get specific memory key
                result = await juliaBridge.executeCommand('get_agent_memory', {
                    agent_id: agentId,
                    key: memoryKey
                }, {
                    showSpinner: false,
                    fallbackToMock: true
                });

                memorySpinner.succeed('Memory retrieved successfully!');

                console.log(chalk.cyan('\nMemory Value:'));
                console.log(chalk.cyan('╔════════════════════════════════════════════════════════════╗'));

                // Extract the actual memory value from the response
                let memoryValue = null;
                if (result && result.success && result.data) {
                    // New format: { success: true, data: value }
                    memoryValue = result.data;
                } else {
                    // Old format: direct value
                    memoryValue = result;
                }

                if (memoryValue === null || memoryValue === undefined) {
                    console.log(chalk.cyan(`║  ${chalk.yellow(`Key '${memoryKey}' not found`)}${' '.repeat(Math.max(0, 40 - memoryKey.length))}║`));
                } else {
                    // Format the result for display
                    const resultStr = JSON.stringify(memoryValue, null, 2);
                    const lines = resultStr.split('\n');

                    lines.forEach(line => {
                        // Truncate long lines
                        const displayLine = line.length > 50 ? line.substring(0, 47) + '...' : line;
                        console.log(chalk.cyan(`║  ${chalk.white(displayLine)}${' '.repeat(Math.max(0, 50 - displayLine.length))}║`));
                    });
                }

                console.log(chalk.cyan('╚════════════════════════════════════════════════════════════╝'));
            }
        } catch (error) {
            memorySpinner.fail(`Failed to retrieve memory: ${error.message}`);
        }
    } catch (error) {
        if (listSpinner) listSpinner.fail(`Error: ${error.message}`);
        console.error(chalk.red(`An error occurred: ${error.message}`));
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * Clear agent memory
 */
async function clearAgentMemory(breadcrumbs = ['Main', 'Agent Management', 'Clear Memory']) {
    displayHeader(breadcrumbs.join(' > '));
    await selectAgentAndRunCommand({
        promptMessage: 'Select an agent to clear memory:',
        command: 'agents.clear_memory',
        updateData: null, // No update data needed
        loadingMessage: 'Clearing agent memory...',
        successMessage: 'Agent memory cleared successfully!',
        errorMessage: 'Failed to clear agent memory.',
        confirmPrompt: true // Add confirmation step
    });
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

        // Handle different response formats
        if (listResult && listResult.success && listResult.data && listResult.data.agents) {
            // New format: { success: true, data: { agents: [...] } }
            agents = listResult.data.agents;
        } else if (listResult && Array.isArray(listResult)) {
            // Old format: direct array
            agents = listResult;
        } else if (listResult && listResult.agents && Array.isArray(listResult.agents)) {
            // Old format: { agents: [...] }
            agents = listResult.agents;
        } else {
            listSpinner.fail('Failed to fetch agents.');
            console.error(chalk.red(`Error listing agents: Unexpected response format.`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return; // Can't continue if we can't list
        }

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
                message: chalk.red(`Are you sure you want to ${command.replace('_', ' ')} agent ${agentId}? This cannot be undone. `),
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
            let params = { agent_id: agentId };

            // Add updates if provided (for update operations)
            if (updateData !== null) {
                params.updates = updateData;
            }

            // Use the enhanced bridge with better error handling
            // No need to split the command name anymore - use the full command
            const commandResult = await juliaBridge.executeCommand(command, params, {
                showSpinner: false, // We're already showing our own spinner
                fallbackToMock: false // Don't allow fallback for critical operations
            });

            commandSpinner.stop();
            // Handle both response formats: { success: true } and { success: true, data: {...} }
            if (commandResult === true ||
                (commandResult && (commandResult.success !== false)) ||
                (commandResult && commandResult.success === true)) {
                commandSpinner.succeed(successMessage);

                // If there's data in the response, log it
                if (commandResult && commandResult.data) {
                    console.log(chalk.cyan('Response data:'));
                    console.log(JSON.stringify(commandResult.data, null, 2));
                }
            } else {
                commandSpinner.fail(errorMessage);
                if (commandResult && commandResult.error) {
                    console.error(chalk.red(`Error: ${commandResult.error}`));
                } else {
                    console.error(chalk.red(`Error: Unknown error from backend.`));
                }
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
        const listResult = await juliaBridge.executeCommand('list_agents', {}, {
            showSpinner: false,
            fallbackToMock: true
        });

        // Handle different response formats
        if (listResult && listResult.success && listResult.data && listResult.data.agents) {
            // New format: { success: true, data: { agents: [...] } }
            agents = listResult.data.agents;
        } else if (listResult && Array.isArray(listResult)) {
            // Old format: direct array
            agents = listResult;
        } else if (listResult && listResult.agents && Array.isArray(listResult.agents)) {
            // Old format: { agents: [...] }
            agents = listResult.agents;
        } else {
            listSpinner.fail('Failed to fetch agents.');
            console.error(chalk.red(`Error listing agents: Unexpected response format.`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return; // Can't continue if we can't list
        }
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
            // Use executeCommand instead of runJuliaCommand for consistency
            const metricsResult = await juliaBridge.executeCommand('agents.get_metrics', { agent_id: agentId }, {
                showSpinner: false,
                fallbackToMock: true
            });

            metricsSpinner.stop();

            // Extract metrics data from the response
            let metrics = null;
            if (metricsResult && metricsResult.success && metricsResult.data) {
                // New format: { success: true, data: {...} }
                metrics = metricsResult.data;
                metricsSpinner.succeed('Metrics retrieved successfully!');
            } else if (metricsResult && typeof metricsResult === 'object') {
                // Old format: direct object
                metrics = metricsResult;
                metricsSpinner.succeed('Metrics retrieved successfully!');
            } else {
                metricsSpinner.fail('Failed to fetch metrics.');
                const metricsError = metricsResult?.error || 'Unknown error or invalid format from backend.';
                console.error(chalk.red(`Error: ${metricsError}`));
                return;
            }

            console.log(chalk.cyan('\nAgent Metrics:'));
            // Display metrics - adjust keys based on actual backend response
            console.log(`  CPU Usage:      ${metrics.cpu || 'N/A'}`);
            console.log(`  Memory Usage:   ${metrics.memory || 'N/A'}`);
            console.log(`  Tasks Processed:${metrics.tasks_processed || 'N/A'}`);
            console.log(`  Active Threads: ${metrics.active_threads || 'N/A'}`);
            console.log(`  Uptime:         ${metrics.uptime || 'N/A'}`);
            // Add more metrics as available from the backend
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

        // Handle different response formats
        if (listResult && listResult.success && listResult.data && listResult.data.agents) {
            // New format: { success: true, data: { agents: [...] } }
            agents = listResult.data.agents;
        } else if (listResult && Array.isArray(listResult)) {
            // Old format: direct array
            agents = listResult;
        } else if (listResult && listResult.agents && Array.isArray(listResult.agents)) {
            // Old format: { agents: [...] }
            agents = listResult.agents;
        } else {
            listSpinner.fail('Failed to fetch agents.');
            console.error(chalk.red(`Error listing agents: Unexpected response format.`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return; // Can't continue if we can't list
        }
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
                eligibleAgents = agents.filter(agent => agent.status !== 'RUNNING');
                if (eligibleAgents.length === 0) {
                    console.log(chalk.yellow('\nAll agents are already running.'));
                    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
                    return;
                }
                break;
            case 'stop':
                eligibleAgents = agents.filter(agent => agent.status === 'RUNNING');
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
                            result = await juliaBridge.executeCommand('start_agent', {
                                agent_id: agentId
                            }, {
                                showSpinner: false,
                                fallbackToMock: false
                            });
                            break;
                        case 'stop':
                            result = await juliaBridge.executeCommand('stop_agent', {
                                agent_id: agentId
                            }, {
                                showSpinner: false,
                                fallbackToMock: false
                            });
                            break;
                        case 'delete':
                            result = await juliaBridge.executeCommand('delete_agent', {
                                agent_id: agentId
                            }, {
                                showSpinner: false,
                                fallbackToMock: false
                            });
                            break;
                        case 'export':
                            // For export, we need to get the full agent details
                            result = await juliaBridge.executeCommand('agents.get_agent', {
                                agent_id: agentId
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

/**
 * Display agent health status
 */
async function displayAgentHealth(breadcrumbs = ['Main', 'Agent Management', 'View Health Status']) {
    displayHeader(breadcrumbs.join(' > '));
    const spinner = ora('Fetching agent health status...').start();

    try {
        // Fetch health status for all agents
        const result = await juliaBridge.executeCommand('get_agent_health', {}, {
            showSpinner: false,
            fallbackToMock: true
        });

        spinner.stop();

        if (result) {
            spinner.succeed('Agent health status retrieved.');

            // Check if we have any agents with health status
            const agentIds = Object.keys(result);
            if (agentIds.length === 0) {
                console.log(chalk.yellow('\nNo agent health information available.'));
                console.log(chalk.cyan('\nTip: ') + 'Make sure agent monitoring is enabled.');
            } else {
                // Create a formatted table for better readability
                console.log(chalk.cyan('\n┌─ Agent Health Status ───────────────────────────────────────────┐'));

                agentIds.forEach(agentId => {
                    const health = result[agentId];

                    // Determine status color
                    let statusColor;
                    let statusIcon;
                    switch(health.status) {
                        case 'HEALTHY':
                            statusColor = chalk.green;
                            statusIcon = '✅';
                            break;
                        case 'WARNING':
                            statusColor = chalk.yellow;
                            statusIcon = '⚠️';
                            break;
                        case 'CRITICAL':
                            statusColor = chalk.red;
                            statusIcon = '🚨';
                            break;
                        case 'UNKNOWN':
                            statusColor = chalk.gray;
                            statusIcon = '❓';
                            break;
                        default:
                            statusColor = chalk.gray;
                            statusIcon = '❓';
                    }

                    // Format timestamp
                    const timestamp = health.timestamp ? new Date(health.timestamp).toLocaleString() : 'Unknown';

                    console.log(chalk.cyan('│                                                              │'));
                    console.log(chalk.cyan(`│  ${chalk.bold(`Agent: ${health.agent_id}`)}${' '.repeat(Math.max(0, 45 - health.agent_id.length - 7))}│`));
                    console.log(chalk.cyan(`│     Status: ${statusIcon} ${statusColor(health.status || 'Unknown')}${' '.repeat(Math.max(0, 42 - (health.status || 'Unknown').length))}│`));
                    console.log(chalk.cyan(`│     Message: ${chalk.white(health.message || 'No message')}${' '.repeat(Math.max(0, 41 - (health.message || 'No message').length))}│`));
                    console.log(chalk.cyan(`│     Last Check: ${chalk.gray(timestamp)}${' '.repeat(Math.max(0, 38 - timestamp.length))}│`));

                    // Show details if available
                    if (health.details && Object.keys(health.details).length > 0) {
                        console.log(chalk.cyan('│     Details:                                                │'));
                        Object.entries(health.details).forEach(([key, value]) => {
                            const detailText = `${key}: ${value}`;
                            console.log(chalk.cyan(`│       - ${chalk.white(detailText)}${' '.repeat(Math.max(0, 47 - detailText.length))}│`));
                        });
                    }

                    console.log(chalk.cyan('│     ────────────────────────────────────────────────────     │'));
                });

                console.log(chalk.cyan('└──────────────────────────────────────────────────────────────┘'));
            }
        } else {
            spinner.fail('Failed to fetch agent health status.');
            console.error(chalk.red('\n✖ Error: Unable to retrieve health status.'));
        }
    } catch (error) {
        spinner.fail('Failed to communicate with backend.');
        console.error(chalk.red(`\n✖ Error fetching health status: ${error.message}`));
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: '🔄 Press Enter to continue...'}]);
}

/**
 * Start agent monitoring
 */
async function startAgentMonitoring(breadcrumbs = ['Main', 'Agent Management', 'Start Monitoring']) {
    displayHeader(breadcrumbs.join(' > '));
    const spinner = ora('Starting agent monitoring...').start();

    try {
        const result = await juliaBridge.executeCommand('start_agent_monitor', {}, {
            showSpinner: false,
            fallbackToMock: true
        });

        spinner.stop();

        if (result === true) {
            spinner.succeed('Agent monitoring started successfully.');
            console.log(chalk.green('\nAgent monitoring system is now active.'));
            console.log(chalk.cyan('\nTip: ') + 'Use "View Health Status" to check agent health.');
        } else {
            spinner.fail('Failed to start agent monitoring.');
            console.log(chalk.yellow('\nAgent monitoring may already be running or there was an error starting it.'));
        }
    } catch (error) {
        spinner.fail('Failed to communicate with backend.');
        console.error(chalk.red(`\n✖ Error starting monitoring: ${error.message}`));
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: '🔄 Press Enter to continue...'}]);
}

/**
 * Stop agent monitoring
 */
async function stopAgentMonitoring(breadcrumbs = ['Main', 'Agent Management', 'Stop Monitoring']) {
    displayHeader(breadcrumbs.join(' > '));
    const spinner = ora('Stopping agent monitoring...').start();

    try {
        const result = await juliaBridge.executeCommand('stop_agent_monitor', {}, {
            showSpinner: false,
            fallbackToMock: true
        });

        spinner.stop();

        if (result === true) {
            spinner.succeed('Agent monitoring stopped successfully.');
            console.log(chalk.yellow('\nAgent monitoring system has been deactivated.'));
        } else {
            spinner.fail('Failed to stop agent monitoring.');
            console.log(chalk.yellow('\nAgent monitoring may not be running or there was an error stopping it.'));
        }
    } catch (error) {
        spinner.fail('Failed to communicate with backend.');
        console.error(chalk.red(`\n✖ Error stopping monitoring: ${error.message}`));
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: '🔄 Press Enter to continue...'}]);
}

/**
 * Display agent metrics
 */
async function displayAgentMetrics(breadcrumbs = ['Main', 'Agent Management', 'View Metrics']) {
    displayHeader(breadcrumbs.join(' > '));
    const spinner = ora('Fetching agent metrics...').start();

    try {
        // Fetch metrics for all agents
        const result = await juliaBridge.executeCommand('get_agent_metrics', {}, {
            showSpinner: false,
            fallbackToMock: true
        });

        spinner.stop();

        if (result) {
            spinner.succeed('Agent metrics retrieved.');

            // Check if we have any agents with metrics
            const agentIds = Object.keys(result);
            if (agentIds.length === 0) {
                console.log(chalk.yellow('\nNo agent metrics available.'));
                console.log(chalk.cyan('\nTip: ') + 'Agents need to be running to collect metrics.');
            } else {
                // Create a formatted table for better readability
                console.log(chalk.cyan('\n┌─ Agent Metrics ───────────────────────────────────────────────┐'));

                agentIds.forEach(agentId => {
                    const agentMetrics = result[agentId];
                    const metricNames = Object.keys(agentMetrics);

                    console.log(chalk.cyan('│                                                              │'));
                    console.log(chalk.cyan(`│  ${chalk.bold(`Agent: ${agentId}`)}${' '.repeat(Math.max(0, 45 - agentId.length - 7))}│`));
                    console.log(chalk.cyan('│     ────────────────────────────────────────────────────     │'));

                    if (metricNames.length === 0) {
                        console.log(chalk.cyan(`│     ${chalk.gray('No metrics available for this agent')}${' '.repeat(15)}│`));
                    } else {
                        metricNames.forEach(metricName => {
                            const metric = agentMetrics[metricName];
                            const metricType = metric.type || 'UNKNOWN';

                            console.log(chalk.cyan(`│     ${chalk.bold(metricName)}${' '.repeat(Math.max(0, 45 - metricName.length))}│`));

                            if (metricType === 'COUNTER' || metricType === 'GAUGE') {
                                console.log(chalk.cyan(`│       Value: ${chalk.white(metric.current)}${' '.repeat(Math.max(0, 42 - String(metric.current).length))}│`));
                            } else if (metricType === 'HISTOGRAM' || metricType === 'SUMMARY') {
                                console.log(chalk.cyan(`│       Count: ${chalk.white(metric.count || 0)}${' '.repeat(Math.max(0, 42 - String(metric.count || 0).length))}│`));
                                console.log(chalk.cyan(`│       Min: ${chalk.white(metric.min || 0)}${' '.repeat(Math.max(0, 44 - String(metric.min || 0).length))}│`));
                                console.log(chalk.cyan(`│       Max: ${chalk.white(metric.max || 0)}${' '.repeat(Math.max(0, 44 - String(metric.max || 0).length))}│`));
                                console.log(chalk.cyan(`│       Mean: ${chalk.white(metric.mean || 0)}${' '.repeat(Math.max(0, 43 - String(metric.mean || 0).length))}│`));
                                if (metric.median) {
                                    console.log(chalk.cyan(`│       Median: ${chalk.white(metric.median)}${' '.repeat(Math.max(0, 41 - String(metric.median).length))}│`));
                                }
                            }

                            // Show last updated timestamp
                            if (metric.last_updated) {
                                const lastUpdated = new Date(metric.last_updated).toLocaleString();
                                console.log(chalk.cyan(`│       Updated: ${chalk.gray(lastUpdated)}${' '.repeat(Math.max(0, 40 - lastUpdated.length))}│`));
                            }

                            console.log(chalk.cyan('│     ────────────────────────────────────────────────────     │'));
                        });
                    }
                });

                console.log(chalk.cyan('└──────────────────────────────────────────────────────────────┘'));
            }
        } else {
            spinner.fail('Failed to fetch agent metrics.');
            console.error(chalk.red('\n✖ Error: Unable to retrieve metrics.'));
        }
    } catch (error) {
        spinner.fail('Failed to communicate with backend.');
        console.error(chalk.red(`\n✖ Error fetching metrics: ${error.message}`));
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: '🔄 Press Enter to continue...'}]);
}

// Export the module with a function that takes the required dependencies
module.exports = function(dependencies) {
    // Assign dependencies to local variables
    juliaBridge = dependencies.juliaBridge;
    displayHeader = dependencies.displayHeader;

    // Return the main menu function and potentially others if needed
    return {
        agentManagementMenu,
        displayAgentHealth,
        startAgentMonitoring,
        stopAgentMonitoring,
        displayAgentMetrics
    };
};
