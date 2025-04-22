// Import required modules
const chalk = require('chalk');
const inquirer = require('inquirer');
const ora = require('ora');
const visualizeSwarm = require('./visualize_swarm');

// Initialize variables that will be set by the module consumer
let juliaBridge;
let displayHeader;

/**
 * Display the swarm management menu
 */
async function swarmManagementMenu(breadcrumbs = ['Main', 'Swarm Management']) {
    try {
        displayHeader('Swarm Management', breadcrumbs);

        // Display a professional header for swarm management
        console.log(chalk.green(`\n      ╔══════════════════════════════════════════╗\n      ║           Swarm Management               ║\n      ║                                          ║\n      ║  🐝 Create and manage swarms of          ║\n      ║     agents for complex tasks.            ║\n      ║                                          ║\n      ╚══════════════════════════════════════════╝\n    `));

        const { action } = await inquirer.prompt([
            {
                type: 'list',
                name: 'action',
                message: 'Choose an action:',
                choices: [
                    { name: '1. 📋 List Swarms', value: 'list_swarms' },
                    { name: '2. ➕ Create New Swarm', value: 'create_swarm' },
                    { name: '3. 🔍 View Swarm Details', value: 'view_swarm' },
                    { name: '4. ⚙️ Configure Swarm', value: 'configure_swarm' },
                    { name: '5. 📊 Visualize Swarm', value: 'visualize_swarm' },
                    { name: '6. 🗑️ Delete Swarm', value: 'delete_swarm' },
                    { name: '0. 🔙 Back to Main Menu', value: 'back' }
                ]
            }
        ]);

        switch (action) {
            case 'list_swarms':
                await listSwarms(breadcrumbs);
                break;
            case 'create_swarm':
                await createSwarm(breadcrumbs);
                break;
            case 'view_swarm':
                await viewSwarmDetails(breadcrumbs);
                break;
            case 'configure_swarm':
                await configureSwarm(breadcrumbs);
                break;
            case 'visualize_swarm':
                await visualizeSwarm(juliaBridge, breadcrumbs);
                break;
            case 'delete_swarm':
                await deleteSwarm(breadcrumbs);
                break;
            case 'back':
                return;
        }

        // Return to the swarm management menu after completing an action
        await swarmManagementMenu(breadcrumbs);
    } catch (error) {
        console.error(chalk.red('An unexpected error occurred in the Swarm Management menu.'));
        console.error(chalk.red('Details:'), error.message);
        await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
    }
}

/**
 * List all swarms
 */
async function listSwarms(breadcrumbs) {
    try {
        const spinner = ora('Fetching swarms...').start();
        let swarms = [];
        try {
            // Use the enhanced bridge to execute the command with better error handling
            const response = await juliaBridge.executeCommand('swarms.list_swarms', {}, {
                showSpinner: false, // We're already showing our own spinner
                fallbackToMock: true // Allow fallback to mock data if backend is unavailable
            });
            spinner.stop();

            // Handle different response formats
            if (response && response.success && response.data && response.data.swarms) {
                // New format: { success: true, data: { swarms: [...] } }
                swarms = response.data.swarms;
            } else if (response && response.swarms) {
                // Old format: { swarms: [...] }
                swarms = response.swarms;
            } else if (Array.isArray(response)) {
                // If response is already an array, use it directly
                swarms = response;
            } else {
                // For mock implementation which might return different format
                swarms = response;
            }

            // Log the response for debugging
            console.log(chalk.blue(`Response from server: ${JSON.stringify(response, null, 2)}`));
        } catch (error) {
            spinner.fail('Failed to fetch swarms');
            console.error(chalk.red('Could not connect to backend. Please ensure the Julia server is running.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        // If swarms is not an array, handle the error
        if (!Array.isArray(swarms)) {
            console.log(chalk.red(`Error: Failed to fetch swarms - unexpected response format`));
            console.log(chalk.yellow(`Response type: ${typeof swarms}`));
            console.log(chalk.yellow(`Response: ${JSON.stringify(swarms, null, 2)}`));

            // Try to extract swarms from the response if it's an object
            if (typeof swarms === 'object' && swarms !== null) {
                if (swarms.swarms && Array.isArray(swarms.swarms)) {
                    swarms = swarms.swarms;
                    console.log(chalk.green(`Successfully extracted swarms array from response`));
                } else {
                    // Create a mock swarm array for demonstration
                    swarms = [
                        { id: 'mock-swarm-1', name: 'Mock Trading Swarm', type: 'Trading', status: 'active', agent_count: 5 },
                        { id: 'mock-swarm-2', name: 'Mock Analysis Swarm', type: 'Analysis', status: 'inactive', agent_count: 3 }
                    ];
                    console.log(chalk.yellow(`Using mock swarms for demonstration`));
                }
            } else {
                await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
                return;
            }
        }
        if (swarms.length === 0) {
            console.log(chalk.yellow('\nNo swarms found. Create a new swarm to get started.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        console.log(chalk.cyan('\nAvailable Swarms:'));
        swarms.forEach((swarm, index) => {
            console.log(chalk.bold(`\n${index + 1}. ${swarm.name || swarm.id}`));
            console.log(`   ID: ${swarm.id}`);
            console.log(`   Type: ${swarm.type || 'Standard'}`);
            console.log(`   Agents: ${swarm.agent_count || 0}`);
            console.log(`   Status: ${swarm.status || 'Unknown'}`);
        });
    } catch (error) {
        console.error(chalk.red('An unexpected error occurred while listing swarms.'));
        console.error(chalk.red('Details:'), error.message);
    }
    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * Create a new swarm
 */
async function createSwarm(breadcrumbs) {
    try {
        console.log(chalk.cyan('\nCreate New Swarm'));

        const { name, type, algorithm, size } = await inquirer.prompt([
            {
                type: 'input',
                name: 'name',
                message: 'Enter swarm name:',
                validate: input => input.trim().length > 0 ? true : 'Swarm name is required'
            },
            {
                type: 'list',
                name: 'type',
                message: 'Select swarm type:',
                choices: [
                    { name: 'Julia Native Swarm', value: 'julia_native' },
                    { name: 'OpenAI Swarm', value: 'openai' },
                    { name: 'Llama Swarm', value: 'llama' },
                    { name: 'Mistral Swarm', value: 'mistral' },
                    { name: 'Claude Swarm', value: 'claude' },
                    { name: 'Trading Swarm', value: 'trading' },
                    { name: 'Arbitrage Swarm', value: 'arbitrage' },
                    { name: 'Liquidity Swarm', value: 'liquidity' },
                    { name: 'Monitoring Swarm', value: 'monitoring' },
                    { name: 'Data Swarm', value: 'data' },
                    { name: 'Custom Swarm', value: 'custom' },
                    { name: 'Back', value: 'back' }
                ]
            },
            {
                type: 'list',
                name: 'algorithm',
                message: 'Select swarm algorithm:',
                choices: [
                    { name: 'Particle Swarm Optimization (PSO)', value: 'pso' },
                    { name: 'Differential Evolution (DE)', value: 'de' },
                    { name: 'Grey Wolf Optimizer (GWO)', value: 'gwo' },
                    { name: 'Ant Colony Optimization (ACO)', value: 'aco' },
                    { name: 'Genetic Algorithm (GA)', value: 'ga' },
                    { name: 'Whale Optimization Algorithm (WOA)', value: 'woa' },
                    { name: 'Hybrid DEPSO', value: 'depso' }
                ]
            },
            {
                type: 'number',
                name: 'size',
                message: 'Enter swarm size (number of agents):',
                default: 5,
                validate: input => {
                    return input > 0 && input <= 100 ? true : 'Please enter a number between 1 and 100';
                }
            }
        ]);

        // Additional parameters for custom swarm type
        let customParams = {};
        if (type === 'custom') {
            const { objective, constraints } = await inquirer.prompt([
                {
                    type: 'list',
                    name: 'objective',
                    message: 'Select optimization objective:',
                    choices: [
                        { name: 'Maximize Profit', value: 'maximize_profit' },
                        { name: 'Minimize Risk', value: 'minimize_risk' },
                        { name: 'Balanced (Profit/Risk)', value: 'balanced' },
                        { name: 'Custom Objective Function', value: 'custom' }
                    ]
                },
                {
                    type: 'checkbox',
                    name: 'constraints',
                    message: 'Select constraints:',
                    choices: [
                        { name: 'Maximum Drawdown Limit', value: 'max_drawdown' },
                        { name: 'Minimum Return Threshold', value: 'min_return' },
                        { name: 'Maximum Position Size', value: 'max_position' },
                        { name: 'Diversification Requirements', value: 'diversification' }
                    ]
                }
            ]);

            customParams = { objective, constraints };
        }

        const spinner = ora('Creating swarm...').start();
        let result;
        try {
            const params = {
                name,
                type,
                algorithm,
                size,
                ...customParams
            };
            // Use the enhanced bridge to execute the command with better error handling
            result = await juliaBridge.executeCommand('swarms.create_swarm', params, {
                showSpinner: false, // We're already showing our own spinner
                fallbackToMock: false // Don't allow fallback for creation operations
            });
            spinner.stop();
        } catch (error) {
            spinner.fail('Failed to create swarm');
            console.error(chalk.red('Could not connect to backend. Please ensure the Julia server is running.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        // Extract swarm data from the response
        let swarmData = null;
        if (result && result.success && result.data) {
            // New format: { success: true, data: { swarm_id: ... } }
            swarmData = result.data;
        } else if (result && result.swarm_id) {
            // Old format: { swarm_id: ... }
            swarmData = result;
        }

        if (!swarmData || !swarmData.swarm_id) {
            console.log(chalk.red(`Error: Failed to create swarm - unexpected response format`));
            console.log(chalk.yellow(`Response: ${JSON.stringify(result, null, 2)}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        console.log(chalk.green('\nSwarm created successfully!'));
        console.log(chalk.cyan(`Swarm ID: ${swarmData.swarm_id}`));
        console.log(chalk.cyan(`Swarm Name: ${name}`));
        console.log(chalk.cyan(`Type: ${type}`));
        console.log(chalk.cyan(`Algorithm: ${algorithm}`));
        console.log(chalk.cyan(`Size: ${size} agents`));

        if (type === 'custom') {
            console.log(chalk.cyan(`Objective: ${customParams.objective}`));
            console.log(chalk.cyan(`Constraints: ${customParams.constraints.join(', ') || 'None'}`));
        }
    } catch (error) {
        console.error(chalk.red('An unexpected error occurred while creating a swarm.'));
        console.error(chalk.red('Details:'), error.message);
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * View details of a specific swarm
 */
async function viewSwarmDetails(breadcrumbs) {
    try {
        // First, get the list of swarms
        const spinner = ora('Fetching swarms...').start();
        let result;
        try {
            result = await juliaBridge.executeCommand('swarms.list_swarms', {});
            spinner.stop();
        } catch (error) {
            spinner.fail('Failed to fetch swarms');
            console.error(chalk.red('Could not connect to backend. Please ensure the Julia server is running.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        // Extract swarms from the response
        let swarms = [];
        if (result && result.success && result.data && result.data.swarms) {
            // New format: { success: true, data: { swarms: [...] } }
            swarms = result.data.swarms;
        } else if (result && result.swarms) {
            // Old format: { swarms: [...] }
            swarms = result.swarms;
        } else if (result && Array.isArray(result)) {
            // Direct array format
            swarms = result;
        } else if (!result || !result.success) {
            console.log(chalk.red(`Error: ${result?.error || 'Failed to fetch swarms'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        if (swarms.length === 0) {
            console.log(chalk.yellow('\nNo swarms found. Create a new swarm to get started.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        // Prompt user to select a swarm
        const { swarmId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'swarmId',
                message: 'Select a swarm to view:',
                choices: swarms.map(swarm => ({
                    name: `${swarm.name || swarm.id} (${swarm.type || 'Standard'})`,
                    value: swarm.id
                }))
            }
        ]);
        // Fetch details for the selected swarm
        const detailsSpinner = ora(`Fetching details for swarm ${swarmId}...`).start();
        let detailsResult;
        try {
            detailsResult = await juliaBridge.executeCommand('swarms.get_swarm_details', { swarm_id: swarmId });
            detailsSpinner.stop();
        } catch (error) {
            detailsSpinner.fail('Failed to fetch swarm details');
            console.error(chalk.red('Could not connect to backend. Please ensure the Julia server is running.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        // Extract swarm details from the response
        let swarm = null;
        if (detailsResult && detailsResult.success && detailsResult.data) {
            // New format: { success: true, data: {...} }
            swarm = detailsResult.data;
        } else if (detailsResult && detailsResult.swarm) {
            // Old format: { swarm: {...} }
            swarm = detailsResult.swarm;
        } else if (detailsResult && typeof detailsResult === 'object' && !detailsResult.success) {
            console.log(chalk.red(`Error: ${detailsResult.error || 'Failed to fetch swarm details'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        } else if (!detailsResult) {
            console.log(chalk.red('Failed to fetch swarm details: No response from server'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        if (!swarm || typeof swarm !== 'object') {
            console.log(chalk.red(`Error: Invalid swarm details format`));
            console.log(chalk.yellow(`Response: ${JSON.stringify(detailsResult, null, 2)}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        console.log(chalk.cyan(`\nSwarm Details: ${swarm.name || swarm.id}`));
        console.log(chalk.bold('\nBasic Information:'));
        console.log(`ID: ${swarm.id}`);
        console.log(`Name: ${swarm.name}`);
        console.log(`Type: ${swarm.type || 'Standard'}`);
        console.log(`Algorithm: ${swarm.algorithm}`);
        console.log(`Status: ${swarm.status || 'Unknown'}`);
        console.log(`Created: ${swarm.created_at || 'Unknown'}`);
        console.log(chalk.bold('\nConfiguration:'));
        console.log(`Size: ${swarm.size || swarm.agent_count || 0} agents`);
        console.log(`Objective: ${swarm.objective || 'Default'}`);
        console.log(`Constraints: ${(swarm.constraints && swarm.constraints.join(', ')) || 'None'}`);
        if (swarm.agents && swarm.agents.length > 0) {
            console.log(chalk.bold('\nAgents:'));
            swarm.agents.forEach((agent, index) => {
                console.log(`${index + 1}. ${agent.name || agent.id} (${agent.type || 'Standard'})`);
            });
        }
        if (swarm.performance) {
            console.log(chalk.bold('\nPerformance Metrics:'));
            console.log(`Success Rate: ${swarm.performance.success_rate || 'N/A'}`);
            console.log(`Convergence Speed: ${swarm.performance.convergence_speed || 'N/A'}`);
            console.log(`Efficiency: ${swarm.performance.efficiency || 'N/A'}`);
        }
    } catch (error) {
        console.error(chalk.red('An unexpected error occurred while viewing swarm details.'));
        console.error(chalk.red('Details:'), error.message);
    }
    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * Configure an existing swarm
 */
async function configureSwarm(breadcrumbs) {
    try {
        // First, get the list of swarms
        const spinner = ora('Fetching swarms...').start();
        let result;
        try {
            result = await juliaBridge.executeCommand('swarms.list_swarms', {});
            spinner.stop();
        } catch (error) {
            spinner.fail('Failed to fetch swarms');
            console.error(chalk.red('Could not connect to backend. Please ensure the Julia server is running.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        // Extract swarms from the response
        let swarms = [];
        if (result && result.success && result.data && result.data.swarms) {
            // New format: { success: true, data: { swarms: [...] } }
            swarms = result.data.swarms;
        } else if (result && result.swarms) {
            // Old format: { swarms: [...] }
            swarms = result.swarms;
        } else if (result && Array.isArray(result)) {
            // Direct array format
            swarms = result;
        } else if (!result || !result.success) {
            console.log(chalk.red(`Error: ${result?.error || 'Failed to fetch swarms'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        if (swarms.length === 0) {
            console.log(chalk.yellow('\nNo swarms found. Create a new swarm to get started.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        // Prompt user to select a swarm
        const { swarmId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'swarmId',
                message: 'Select a swarm to configure:',
                choices: swarms.map(swarm => ({
                    name: `${swarm.name || swarm.id} (${swarm.type || 'Standard'})`,
                    value: swarm.id
                }))
            }
        ]);
        // Fetch details for the selected swarm
        const detailsSpinner = ora(`Fetching details for swarm ${swarmId}...`).start();
        let detailsResult;
        try {
            detailsResult = await juliaBridge.executeCommand('swarms.get_swarm_details', { swarm_id: swarmId });
            detailsSpinner.stop();
        } catch (error) {
            detailsSpinner.fail('Failed to fetch swarm details');
            console.error(chalk.red('Could not connect to backend. Please ensure the Julia server is running.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        // Extract swarm details from the response
        let swarm = null;
        if (detailsResult && detailsResult.success && detailsResult.data) {
            // New format: { success: true, data: {...} }
            swarm = detailsResult.data;
        } else if (detailsResult && detailsResult.swarm) {
            // Old format: { swarm: {...} }
            swarm = detailsResult.swarm;
        } else if (detailsResult && typeof detailsResult === 'object' && !detailsResult.success) {
            console.log(chalk.red(`Error: ${detailsResult.error || 'Failed to fetch swarm details'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        } else if (!detailsResult) {
            console.log(chalk.red('Failed to fetch swarm details: No response from server'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        if (!swarm || typeof swarm !== 'object') {
            console.log(chalk.red(`Error: Invalid swarm details format`));
            console.log(chalk.yellow(`Response: ${JSON.stringify(detailsResult, null, 2)}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        // Prompt user for configuration options
        const { configOption } = await inquirer.prompt([
            {
                type: 'list',
                name: 'configOption',
                message: 'What would you like to configure?',
                choices: [
                    { name: 'Rename Swarm', value: 'rename' },
                    { name: 'Change Algorithm', value: 'algorithm' },
                    { name: 'Adjust Size', value: 'size' },
                    { name: 'Modify Objective', value: 'objective' },
                    { name: 'Update Constraints', value: 'constraints' },
                    { name: 'Advanced Parameters', value: 'advanced' },
                    { name: 'Cancel', value: 'cancel' }
                ]
            }
        ]);
        if (configOption === 'cancel') {
            return;
        }
        let updateParams = {};
        switch (configOption) {
            case 'rename':
                const { newName } = await inquirer.prompt([
                    {
                        type: 'input',
                        name: 'newName',
                        message: 'Enter new swarm name:',
                        default: swarm.name,
                        validate: input => input.trim().length > 0 ? true : 'Swarm name is required'
                    }
                ]);
                updateParams = { name: newName };
                break;

            case 'algorithm':
                const { newAlgorithm } = await inquirer.prompt([
                    {
                        type: 'list',
                        name: 'newAlgorithm',
                        message: 'Select new swarm algorithm:',
                        default: swarm.algorithm,
                        choices: [
                            { name: 'Particle Swarm Optimization (PSO)', value: 'pso' },
                            { name: 'Differential Evolution (DE)', value: 'de' },
                            { name: 'Grey Wolf Optimizer (GWO)', value: 'gwo' },
                            { name: 'Ant Colony Optimization (ACO)', value: 'aco' },
                            { name: 'Genetic Algorithm (GA)', value: 'ga' },
                            { name: 'Whale Optimization Algorithm (WOA)', value: 'woa' },
                            { name: 'Hybrid DEPSO', value: 'depso' }
                        ]
                    }
                ]);
                updateParams = { algorithm: newAlgorithm };
                break;

            case 'size':
                const { newSize } = await inquirer.prompt([
                    {
                        type: 'input',
                        name: 'newSize',
                        message: 'Enter new swarm size (number of agents):',
                        default: swarm.size || swarm.agent_count || 5,
                        validate: input => {
                            const num = parseInt(input);
                            return !isNaN(num) && num > 0 && num <= 100 ? true : 'Please enter a number between 1 and 100';
                        },
                        filter: input => parseInt(input)
                    }
                ]);
                updateParams = { size: newSize };
                break;

            case 'objective':
                const { newObjective } = await inquirer.prompt([
                    {
                        type: 'list',
                        name: 'newObjective',
                        message: 'Select new optimization objective:',
                        default: swarm.objective,
                        choices: [
                            { name: 'Maximize Profit', value: 'maximize_profit' },
                            { name: 'Minimize Risk', value: 'minimize_risk' },
                            { name: 'Balanced (Profit/Risk)', value: 'balanced' },
                            { name: 'Custom Objective Function', value: 'custom' }
                        ]
                    }
                ]);
                updateParams = { objective: newObjective };
                break;

            case 'constraints':
                const { newConstraints } = await inquirer.prompt([
                    {
                        type: 'checkbox',
                        name: 'newConstraints',
                        message: 'Select new constraints:',
                        default: swarm.constraints || [],
                        choices: [
                            { name: 'Maximum Drawdown Limit', value: 'max_drawdown' },
                            { name: 'Minimum Return Threshold', value: 'min_return' },
                            { name: 'Maximum Position Size', value: 'max_position' },
                            { name: 'Diversification Requirements', value: 'diversification' }
                        ]
                    }
                ]);
                updateParams = { constraints: newConstraints };
                break;

            case 'advanced':
                const { iterations, tolerance, adaptiveParams } = await inquirer.prompt([
                    {
                        type: 'input',
                        name: 'iterations',
                        message: 'Maximum iterations:',
                        default: swarm.advanced?.iterations || 100,
                        validate: input => {
                            const num = parseInt(input);
                            return !isNaN(num) && num > 0 ? true : 'Please enter a positive number';
                        },
                        filter: input => parseInt(input)
                    },
                    {
                        type: 'input',
                        name: 'tolerance',
                        message: 'Convergence tolerance:',
                        default: swarm.advanced?.tolerance || 0.001,
                        validate: input => {
                            const num = parseFloat(input);
                            return !isNaN(num) && num > 0 ? true : 'Please enter a positive number';
                        },
                        filter: input => parseFloat(input)
                    },
                    {
                        type: 'confirm',
                        name: 'adaptiveParams',
                        message: 'Enable adaptive parameters?',
                        default: swarm.advanced?.adaptive_params || false
                    }
                ]);
                updateParams = {
                    advanced: {
                        iterations,
                        tolerance,
                        adaptive_params: adaptiveParams
                    }
                };
                break;
        }
        // Update the swarm configuration
        const updateSpinner = ora('Updating swarm configuration...').start();
        let updateResult;
        try {
            updateResult = await juliaBridge.executeCommand('swarms.update_swarm', { swarm_id: swarmId, ...updateParams });
            updateSpinner.stop();
        } catch (error) {
            updateSpinner.fail('Failed to update swarm configuration');
            console.error(chalk.red('Could not connect to backend. Please ensure the Julia server is running.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        // Check if the update operation was successful
        if (updateResult && updateResult.success) {
            console.log(chalk.green('\nSwarm configuration updated successfully!'));
        } else if (updateResult && !updateResult.success) {
            console.log(chalk.red(`Error: ${updateResult.error || 'Failed to update swarm configuration'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        } else {
            console.log(chalk.red('Failed to update swarm configuration: Unexpected response format'));
            console.log(chalk.yellow(`Response: ${JSON.stringify(updateResult, null, 2)}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
    } catch (error) {
        console.error(chalk.red('An unexpected error occurred while configuring a swarm.'));
        console.error(chalk.red('Details:'), error.message);
    }
    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * Delete a swarm
 */
async function deleteSwarm(breadcrumbs) {
    try {
        // First, get the list of swarms
        const spinner = ora('Fetching swarms...').start();
        let result;
        try {
            result = await juliaBridge.executeCommand('swarms.list_swarms', {});
            spinner.stop();
        } catch (error) {
            spinner.fail('Failed to fetch swarms');
            console.error(chalk.red('Could not connect to backend. Please ensure the Julia server is running.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        // Extract swarms from the response
        let swarms = [];
        if (result && result.success && result.data && result.data.swarms) {
            // New format: { success: true, data: { swarms: [...] } }
            swarms = result.data.swarms;
        } else if (result && result.swarms) {
            // Old format: { swarms: [...] }
            swarms = result.swarms;
        } else if (result && Array.isArray(result)) {
            // Direct array format
            swarms = result;
        } else if (!result || !result.success) {
            console.log(chalk.red(`Error: ${result?.error || 'Failed to fetch swarms'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        if (swarms.length === 0) {
            console.log(chalk.yellow('\nNo swarms found. Create a new swarm to get started.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        // Prompt user to select a swarm
        const { swarmId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'swarmId',
                message: 'Select a swarm to delete:',
                choices: swarms.map(swarm => ({
                    name: `${swarm.name || swarm.id} (${swarm.type || 'Standard'})`,
                    value: swarm.id
                }))
            }
        ]);
        // Confirm deletion
        const { confirmDelete } = await inquirer.prompt([
            {
                type: 'confirm',
                name: 'confirmDelete',
                message: `Are you sure you want to delete this swarm? This action cannot be undone.`,
                default: false
            }
        ]);
        if (!confirmDelete) {
            console.log(chalk.yellow('Deletion cancelled.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        // Delete the swarm
        const deleteSpinner = ora(`Deleting swarm ${swarmId}...`).start();
        let deleteResult;
        try {
            deleteResult = await juliaBridge.executeCommand('swarms.delete_swarm', { swarm_id: swarmId });
            deleteSpinner.stop();
        } catch (error) {
            deleteSpinner.fail('Failed to delete swarm');
            console.error(chalk.red('Could not connect to backend. Please ensure the Julia server is running.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        // Check if the delete operation was successful
        if (deleteResult && deleteResult.success) {
            console.log(chalk.green('\nSwarm deleted successfully!'));
        } else if (deleteResult && !deleteResult.success) {
            console.log(chalk.red(`Error: ${deleteResult.error || 'Failed to delete swarm'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        } else {
            console.log(chalk.red('Failed to delete swarm: Unexpected response format'));
            console.log(chalk.yellow(`Response: ${JSON.stringify(deleteResult, null, 2)}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
    } catch (error) {
        console.error(chalk.red('An unexpected error occurred while deleting a swarm.'));
        console.error(chalk.red('Details:'), error.message);
    }
    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

// Export the module with a function that takes the required dependencies
module.exports = function(deps) {
    // Assign dependencies to local variables if they're passed in
    if (deps) {
        if (deps.juliaBridge) juliaBridge = deps.juliaBridge;
        if (deps.displayHeader) displayHeader = deps.displayHeader;
    }

    // Return an object with all the functions
    return {
        swarmManagementMenu,
        listSwarms,
        createSwarm,
        viewSwarmDetails,
        configureSwarm,
        visualizeSwarm,
        deleteSwarm
    };
};
