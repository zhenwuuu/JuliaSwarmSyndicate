const inquirer = require('inquirer');
const chalk = require('chalk');
const ora = require('ora');
const { v4: uuidv4 } = require('uuid');
const { displayHeader } = require('./utils');

/**
 * Agent Specialization Menu
 * Provides functionality for managing agent specializations
 */
async function agentSpecializationMenu(juliaBridge, breadcrumbs = ['Main', 'Agent Specialization']) {
    let exit = false;

    while (!exit) {
        displayHeader(breadcrumbs.join(' > '));

        console.log(chalk.cyan(`
┌─────────────────────────────────────────────────┐
│                                                 │
│  🧠 Agent Specialization Management             │
│                                                 │
│  Create, apply, and manage specializations      │
│  that enhance agent capabilities and skills.    │
│                                                 │
└─────────────────────────────────────────────────┘
`));

        const { action } = await inquirer.prompt([
            {
                type: 'list',
                name: 'action',
                message: 'Select an action:',
                pageSize: 10,
                choices: [
                    { name: 'List Specializations', value: 'list' },
                    { name: 'Create Specialization', value: 'create' },
                    { name: 'View Specialization Details', value: 'view' },
                    { name: 'Apply Specialization to Agent', value: 'apply' },
                    { name: 'Remove Specialization from Agent', value: 'remove' },
                    { name: 'View Agent Specializations', value: 'agent_specs' },
                    { name: 'Delete Specialization', value: 'delete' },
                    new inquirer.Separator(),
                    { name: 'Back to Main Menu', value: 'back' }
                ]
            }
        ]);

        switch (action) {
            case 'list':
                await listSpecializations(juliaBridge, [...breadcrumbs, 'List Specializations']);
                break;
            case 'create':
                await createSpecialization(juliaBridge, [...breadcrumbs, 'Create Specialization']);
                break;
            case 'view':
                await viewSpecializationDetails(juliaBridge, [...breadcrumbs, 'View Specialization']);
                break;
            case 'apply':
                await applySpecialization(juliaBridge, [...breadcrumbs, 'Apply Specialization']);
                break;
            case 'remove':
                await removeSpecialization(juliaBridge, [...breadcrumbs, 'Remove Specialization']);
                break;
            case 'agent_specs':
                await viewAgentSpecializations(juliaBridge, [...breadcrumbs, 'Agent Specializations']);
                break;
            case 'delete':
                await deleteSpecialization(juliaBridge, [...breadcrumbs, 'Delete Specialization']);
                break;
            case 'back':
                exit = true;
                break;
        }
    }
}

/**
 * List all available specializations
 */
async function listSpecializations(juliaBridge, breadcrumbs) {
    displayHeader(breadcrumbs.join(' > '));

    const spinner = ora({
        text: 'Fetching specializations...',
        spinner: 'dots',
        color: 'blue'
    }).start();

    try {
        const result = await juliaBridge.runJuliaCommand('specialization.list', {});

        spinner.stop();

        if (result && result.success && Array.isArray(result.specializations)) {
            const specializations = result.specializations;

            if (specializations.length === 0) {
                console.log(chalk.yellow('\nNo specializations found.'));
                console.log(chalk.cyan('\nTip: ') + 'Use "Create Specialization" to add a new specialization.');
            } else {
                console.log(chalk.cyan(`\n┌─ Available Specializations (${ specializations.length }) ───────────────────────────────┐`));

                specializations.forEach((spec, index) => {
                    console.log(chalk.cyan('│                                                                      │'));
                    console.log(chalk.cyan(`│  ${chalk.bold(`${index + 1}. ${spec.name}`)}${' '.repeat(Math.max(0, 54 - spec.name.length - String(index + 1).length))}│`));
                    console.log(chalk.cyan(`│     ID: ${chalk.gray(spec.id)}${' '.repeat(Math.max(0, 54 - spec.id.length))}│`));
                    console.log(chalk.cyan(`│     Description: ${spec.description.substring(0, 40)}${spec.description.length > 40 ? '...' : ''}${' '.repeat(Math.max(0, 40 - Math.min(spec.description.length, 43)))}│`));

                    const capabilitiesStr = spec.capabilities.join(', ');
                    const displayCapabilities = capabilitiesStr.length > 40 ?
                        capabilitiesStr.substring(0, 37) + '...' :
                        capabilitiesStr;

                    console.log(chalk.cyan(`│     Capabilities: ${displayCapabilities}${' '.repeat(Math.max(0, 40 - displayCapabilities.length))}│`));
                    console.log(chalk.cyan(`│     Skills: ${spec.num_skills || 0}${' '.repeat(Math.max(0, 47 - String(spec.num_skills || 0).length))}│`));

                    if (index < specializations.length - 1) {
                        console.log(chalk.cyan('│     ────────────────────────────────────────────────────────     │'));
                    }
                });

                console.log(chalk.cyan('│                                                                      │'));
                console.log(chalk.cyan('└──────────────────────────────────────────────────────────────────────┘'));
            }
        } else {
            spinner.fail('Failed to fetch specializations.');
            console.error(chalk.red(`\n❌ Error: ${result?.error || 'Unknown error'}`));
        }
    } catch (error) {
        spinner.fail('Failed to communicate with backend.');
        console.error(chalk.red(`\n❌ Error listing specializations: ${error.message}`));
    }

    await inquirer.prompt([{ type: 'input', name: 'continue', message: '🔄 Press Enter to continue...' }]);
}

/**
 * Create a new specialization
 */
async function createSpecialization(juliaBridge, breadcrumbs) {
    displayHeader(breadcrumbs.join(' > '));

    console.log(chalk.cyan(`
┌─────────────────────────────────────────────────┐
│                                                 │
│  🧠 Create New Specialization                   │
│                                                 │
│  Define capabilities and skills that can be     │
│  applied to agents to enhance their abilities.  │
│                                                 │
└─────────────────────────────────────────────────┘
`));

    // Get basic information
    const basicInfo = await inquirer.prompt([
        {
            type: 'input',
            name: 'name',
            message: 'Specialization name:',
            validate: input => input.trim() !== '' ? true : 'Name is required'
        },
        {
            type: 'input',
            name: 'description',
            message: 'Description:',
            validate: input => input.trim() !== '' ? true : 'Description is required'
        }
    ]);

    // Get capabilities
    console.log(chalk.cyan('\nCapabilities define what the agent can do with this specialization.'));

    const capabilitiesInput = await inquirer.prompt([
        {
            type: 'checkbox',
            name: 'capabilities',
            message: 'Select capabilities:',
            choices: [
                { name: 'trading - Trading operations', value: 'trading', checked: false },
                { name: 'market_analysis - Market data analysis', value: 'market_analysis', checked: false },
                { name: 'risk_management - Risk assessment and management', value: 'risk_management', checked: false },
                { name: 'blockchain - Blockchain interactions', value: 'blockchain', checked: false },
                { name: 'data_processing - Advanced data processing', value: 'data_processing', checked: false },
                { name: 'machine_learning - ML model training and inference', value: 'machine_learning', checked: false },
                { name: 'leadership - Swarm leadership capabilities', value: 'leadership', checked: false },
                { name: 'messaging - Inter-agent communication', value: 'messaging', checked: false },
                { name: 'monitoring - System and market monitoring', value: 'monitoring', checked: false },
                { name: 'storage - Data storage operations', value: 'storage', checked: false }
            ],
            validate: input => input.length > 0 ? true : 'Select at least one capability'
        },
        {
            type: 'input',
            name: 'customCapabilities',
            message: 'Add custom capabilities (comma-separated, leave empty for none):',
        }
    ]);

    // Process capabilities
    let capabilities = capabilitiesInput.capabilities;
    if (capabilitiesInput.customCapabilities.trim() !== '') {
        const custom = capabilitiesInput.customCapabilities.split(',').map(c => c.trim()).filter(c => c !== '');
        capabilities = [...capabilities, ...custom];
    }

    // Get requirements
    console.log(chalk.cyan('\nRequirements define what an agent needs to use this specialization.'));

    const requirementsInput = await inquirer.prompt([
        {
            type: 'checkbox',
            name: 'requiredCapabilities',
            message: 'Required agent capabilities:',
            choices: [
                { name: 'basic - Core functionality', value: 'basic', checked: true },
                { name: 'network - Network communication', value: 'network', checked: false },
                { name: 'data - Data processing', value: 'data', checked: false },
                { name: 'ml - Machine learning', value: 'ml', checked: false },
                { name: 'blockchain - Blockchain interaction', value: 'blockchain', checked: false }
            ]
        },
        {
            type: 'input',
            name: 'minMemory',
            message: 'Minimum memory required (MB):',
            default: '256',
            validate: input => {
                const num = parseInt(input);
                return !isNaN(num) && num > 0 ? true : 'Please enter a valid number greater than 0';
            },
            filter: input => parseInt(input)
        }
    ]);

    // Create the specialization configuration
    const specializationConfig = {
        name: basicInfo.name,
        description: basicInfo.description,
        capabilities: capabilities,
        skills: [], // We'll keep this simple for now
        requirements: {
            capabilities: requirementsInput.requiredCapabilities,
            min_memory: requirementsInput.minMemory
        },
        parameters: {},
        metadata: {
            created_at: new Date().toISOString(),
            created_by: 'cli'
        }
    };

    // Show summary and confirm
    console.log(chalk.cyan('\n┌─ Specialization Summary ─────────────────────────────────────┐'));
    console.log(chalk.cyan(`│ Name: ${chalk.white(specializationConfig.name)}${' '.repeat(Math.max(0, 50 - specializationConfig.name.length))}│`));
    console.log(chalk.cyan(`│ Description: ${chalk.white(specializationConfig.description.substring(0, 45))}${specializationConfig.description.length > 45 ? '...' : ''}${' '.repeat(Math.max(0, 45 - Math.min(specializationConfig.description.length, 48)))}│`));
    console.log(chalk.cyan(`│ Capabilities: ${chalk.white(specializationConfig.capabilities.length)}${' '.repeat(Math.max(0, 44 - String(specializationConfig.capabilities.length).length))}│`));
    console.log(chalk.cyan(`│ Required Memory: ${chalk.white(specializationConfig.requirements.min_memory)} MB${' '.repeat(Math.max(0, 40 - String(specializationConfig.requirements.min_memory).length))}│`));
    console.log(chalk.cyan('└──────────────────────────────────────────────────────────────┘'));

    const { confirmCreate } = await inquirer.prompt([
        {
            type: 'confirm',
            name: 'confirmCreate',
            message: 'Create this specialization?',
            default: true
        }
    ]);

    if (!confirmCreate) {
        console.log(chalk.yellow('\nSpecialization creation cancelled.'));
        return;
    }

    // Create the specialization
    const spinner = ora({
        text: 'Creating specialization...',
        spinner: 'dots',
        color: 'blue'
    }).start();

    try {
        const result = await juliaBridge.runJuliaCommand('specialization.create', specializationConfig);

        spinner.stop();

        if (result && result.success) {
            console.log(chalk.green('\n✅ Specialization created successfully!'));
            console.log(chalk.cyan(`\nSpecialization ID: ${chalk.white(result.id)}`));
            console.log(chalk.cyan('\nTip: ') + 'Use "Apply Specialization to Agent" to enhance an agent with these capabilities.');
        } else {
            console.log(chalk.red(`\n❌ Failed to create specialization: ${result?.error || 'Unknown error'}`));
        }
    } catch (error) {
        spinner.fail('Failed to communicate with backend.');
        console.error(chalk.red(`\n❌ Error creating specialization: ${error.message}`));
    }

    await inquirer.prompt([{ type: 'input', name: 'continue', message: '🔄 Press Enter to continue...' }]);
}

/**
 * View specialization details
 */
async function viewSpecializationDetails(juliaBridge, breadcrumbs) {
    displayHeader(breadcrumbs.join(' > '));

    // First, get the list of specializations
    const spinner = ora({
        text: 'Fetching specializations...',
        spinner: 'dots',
        color: 'blue'
    }).start();

    try {
        const result = await juliaBridge.runJuliaCommand('specialization.list', {});

        spinner.stop();

        if (result && result.success && Array.isArray(result.specializations)) {
            const specializations = result.specializations;

            if (specializations.length === 0) {
                console.log(chalk.yellow('\nNo specializations found.'));
                await inquirer.prompt([{ type: 'input', name: 'continue', message: '🔄 Press Enter to continue...' }]);
                return;
            }

            // Let user select a specialization
            const choices = specializations.map(spec => ({
                name: `${spec.name} (${spec.id})`,
                value: spec.id
            }));

            choices.push(new inquirer.Separator(), { name: 'Back', value: 'back' });

            const { specId } = await inquirer.prompt([
                {
                    type: 'list',
                    name: 'specId',
                    message: 'Select a specialization to view:',
                    choices: choices,
                    pageSize: 15
                }
            ]);

            if (specId === 'back') {
                return;
            }

            // Fetch the specialization details
            spinner.text = 'Fetching specialization details...';
            spinner.start();

            const detailsResult = await juliaBridge.runJuliaCommand('specialization.get', { id: specId });

            spinner.stop();

            if (detailsResult && detailsResult.success) {
                const spec = detailsResult;

                console.log(chalk.cyan(`\n┌─ Specialization: ${spec.name} ─${'\u2500'.repeat(Math.max(0, 50 - spec.name.length))}┐`));
                console.log(chalk.cyan(`│                                                                      │`));
                console.log(chalk.cyan(`│  ${chalk.bold('ID:')} ${chalk.white(spec.id)}${' '.repeat(Math.max(0, 60 - spec.id.length))}  │`));
                console.log(chalk.cyan(`│  ${chalk.bold('Description:')} ${chalk.white(spec.description)}${' '.repeat(Math.max(0, 48 - spec.description.length))}  │`));
                console.log(chalk.cyan(`│                                                                      │`));
                console.log(chalk.cyan(`│  ${chalk.bold('Capabilities:')}${' '.repeat(50)}  │`));

                spec.capabilities.forEach(cap => {
                    console.log(chalk.cyan(`│    • ${cap}${' '.repeat(Math.max(0, 58 - cap.length))}  │`));
                });

                console.log(chalk.cyan(`│                                                                      │`));
                console.log(chalk.cyan(`│  ${chalk.bold('Requirements:')}${' '.repeat(50)}  │`));

                if (spec.requirements && spec.requirements.capabilities) {
                    console.log(chalk.cyan(`│    Required Capabilities:${' '.repeat(40)}  │`));
                    spec.requirements.capabilities.forEach(cap => {
                        console.log(chalk.cyan(`│      • ${cap}${' '.repeat(Math.max(0, 56 - cap.length))}  │`));
                    });
                }

                if (spec.requirements && spec.requirements.min_memory) {
                    console.log(chalk.cyan(`│    Minimum Memory: ${spec.requirements.min_memory} MB${' '.repeat(Math.max(0, 42 - String(spec.requirements.min_memory).length))}  │`));
                }

                console.log(chalk.cyan(`│                                                                      │`));

                if (spec.skills && spec.skills.length > 0) {
                    console.log(chalk.cyan(`│  ${chalk.bold('Skills:')}${' '.repeat(55)}  │`));

                    spec.skills.forEach(skill => {
                        console.log(chalk.cyan(`│    • ${skill.name}: ${skill.description.substring(0, 30)}${skill.description.length > 30 ? '...' : ''}${' '.repeat(Math.max(0, 40 - skill.name.length - Math.min(skill.description.length, 33)))}  │`));
                    });

                    console.log(chalk.cyan(`│                                                                      │`));
                }

                if (spec.metadata && Object.keys(spec.metadata).length > 0) {
                    console.log(chalk.cyan(`│  ${chalk.bold('Metadata:')}${' '.repeat(53)}  │`));

                    for (const [key, value] of Object.entries(spec.metadata)) {
                        const displayValue = typeof value === 'object' ? JSON.stringify(value).substring(0, 30) : String(value).substring(0, 30);
                        console.log(chalk.cyan(`│    ${key}: ${displayValue}${displayValue.length > 30 ? '...' : ''}${' '.repeat(Math.max(0, 55 - key.length - Math.min(displayValue.length, 33)))}  │`));
                    }

                    console.log(chalk.cyan(`│                                                                      │`));
                }

                console.log(chalk.cyan(`└──────────────────────────────────────────────────────────────┘`));
            } else {
                console.log(chalk.red(`\n❌ Failed to fetch specialization details: ${detailsResult?.error || 'Unknown error'}`));
            }
        } else {
            console.log(chalk.red(`\n❌ Failed to fetch specializations: ${result?.error || 'Unknown error'}`));
        }
    } catch (error) {
        spinner.fail('Failed to communicate with backend.');
        console.error(chalk.red(`\n❌ Error: ${error.message}`));
    }

    await inquirer.prompt([{ type: 'input', name: 'continue', message: '🔄 Press Enter to continue...' }]);
}

/**
 * Apply specialization to agent
 */
async function applySpecialization(juliaBridge, breadcrumbs) {
    displayHeader(breadcrumbs.join(' > '));

    console.log(chalk.cyan(`
┌─────────────────────────────────────────────────┐
│                                                 │
│  🔗 Apply Specialization to Agent               │
│                                                 │
│  Enhance an agent with new capabilities and     │
│  skills from a specialization.                  │
│                                                 │
└─────────────────────────────────────────────────┘
`));

    // First, get the list of specializations
    const spinner = ora({
        text: 'Fetching specializations...',
        spinner: 'dots',
        color: 'blue'
    }).start();

    try {
        const specializationsResult = await juliaBridge.runJuliaCommand('specialization.list', {});

        if (!specializationsResult || !specializationsResult.success || !Array.isArray(specializationsResult.specializations) || specializationsResult.specializations.length === 0) {
            spinner.fail('No specializations available.');
            console.log(chalk.yellow('\nNo specializations found. Create a specialization first.'));
            await inquirer.prompt([{ type: 'input', name: 'continue', message: '🔄 Press Enter to continue...' }]);
            return;
        }

        // Now get the list of agents
        spinner.text = 'Fetching agents...';

        const agentsResult = await juliaBridge.runJuliaCommand('agents.list_agents', {});

        spinner.stop();

        if (!agentsResult || !agentsResult.success || !Array.isArray(agentsResult.data) || agentsResult.data.length === 0) {
            console.log(chalk.yellow('\nNo agents found. Create an agent first.'));
            await inquirer.prompt([{ type: 'input', name: 'continue', message: '🔄 Press Enter to continue...' }]);
            return;
        }

        // Let user select a specialization
        const specializationChoices = specializationsResult.specializations.map(spec => ({
            name: `${spec.name} - ${spec.description.substring(0, 40)}${spec.description.length > 40 ? '...' : ''}`,
            value: spec.id
        }));

        const { specializationId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'specializationId',
                message: 'Select a specialization to apply:',
                choices: specializationChoices,
                pageSize: 10
            }
        ]);

        // Let user select an agent
        const agentChoices = agentsResult.data.map(agent => ({
            name: `${agent.name} (${agent.type}) - ${agent.status}`,
            value: agent.id
        }));

        const { agentId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'agentId',
                message: 'Select an agent to enhance:',
                choices: agentChoices,
                pageSize: 10
            }
        ]);

        // Confirm the action
        const selectedSpec = specializationsResult.specializations.find(s => s.id === specializationId);
        const selectedAgent = agentsResult.data.find(a => a.id === agentId);

        console.log(chalk.cyan('\n┌─ Confirm Application ─────────────────────────────────────┐'));
        console.log(chalk.cyan(`│ Specialization: ${chalk.white(selectedSpec.name)}${' '.repeat(Math.max(0, 40 - selectedSpec.name.length))}│`));
        console.log(chalk.cyan(`│ Agent: ${chalk.white(selectedAgent.name)}${' '.repeat(Math.max(0, 48 - selectedAgent.name.length))}│`));
        console.log(chalk.cyan('└──────────────────────────────────────────────────────────────┘'));

        const { confirmApply } = await inquirer.prompt([
            {
                type: 'confirm',
                name: 'confirmApply',
                message: `Apply "${selectedSpec.name}" to agent "${selectedAgent.name}"?`,
                default: true
            }
        ]);

        if (!confirmApply) {
            console.log(chalk.yellow('\nOperation cancelled.'));
            await inquirer.prompt([{ type: 'input', name: 'continue', message: '🔄 Press Enter to continue...' }]);
            return;
        }

        // Apply the specialization
        spinner.text = 'Applying specialization to agent...';
        spinner.start();

        const applyResult = await juliaBridge.runJuliaCommand('specialization.apply', {
            specialization_id: specializationId,
            agent_id: agentId
        });

        spinner.stop();

        if (applyResult && applyResult.success) {
            console.log(chalk.green('\n✅ Specialization applied successfully!'));
            console.log(chalk.cyan('\nThe agent has been enhanced with new capabilities and skills.'));
        } else {
            console.log(chalk.red(`\n❌ Failed to apply specialization: ${applyResult?.error || 'Unknown error'}`));

            if (applyResult?.message && applyResult.message.includes('requirements')) {
                console.log(chalk.yellow('\nThe agent does not meet the requirements for this specialization.'));
                console.log(chalk.yellow('Check the specialization details for requirements.'));
            }
        }
    } catch (error) {
        spinner.fail('Failed to communicate with backend.');
        console.error(chalk.red(`\n❌ Error: ${error.message}`));
    }

    await inquirer.prompt([{ type: 'input', name: 'continue', message: '🔄 Press Enter to continue...' }]);
}

/**
 * Remove specialization from agent
 */
async function removeSpecialization(juliaBridge, breadcrumbs) {
    displayHeader(breadcrumbs.join(' > '));

    console.log(chalk.cyan(`
┌─────────────────────────────────────────────────┐
│                                                 │
│  🔧 Remove Specialization from Agent            │
│                                                 │
│  Remove capabilities and skills granted by a     │
│  specialization from an agent.                   │
│                                                 │
└─────────────────────────────────────────────────┘
`));

    // First, get the list of agents
    const spinner = ora({
        text: 'Fetching agents...',
        spinner: 'dots',
        color: 'blue'
    }).start();

    try {
        const agentsResult = await juliaBridge.runJuliaCommand('agents.list_agents', {});

        if (!agentsResult || !agentsResult.success || !Array.isArray(agentsResult.data) || agentsResult.data.length === 0) {
            spinner.fail('No agents available.');
            console.log(chalk.yellow('\nNo agents found.'));
            await inquirer.prompt([{ type: 'input', name: 'continue', message: '🔄 Press Enter to continue...' }]);
            return;
        }

        // Let user select an agent
        spinner.stop();

        const agentChoices = agentsResult.data.map(agent => ({
            name: `${agent.name} (${agent.type}) - ${agent.status}`,
            value: agent.id
        }));

        const { agentId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'agentId',
                message: 'Select an agent:',
                choices: agentChoices,
                pageSize: 10
            }
        ]);

        // Get specializations for this agent
        spinner.text = 'Fetching agent specializations...';
        spinner.start();

        const specsResult = await juliaBridge.runJuliaCommand('specialization.get_agent_specializations', {
            agent_id: agentId
        });

        spinner.stop();

        if (!specsResult || !specsResult.success || !Array.isArray(specsResult.specializations) || specsResult.specializations.length === 0) {
            console.log(chalk.yellow('\nThis agent has no specializations applied.'));
            await inquirer.prompt([{ type: 'input', name: 'continue', message: '🔄 Press Enter to continue...' }]);
            return;
        }

        // Let user select a specialization to remove
        const specChoices = specsResult.specializations.map(spec => ({
            name: `${spec.name} - ${spec.description.substring(0, 40)}${spec.description.length > 40 ? '...' : ''}`,
            value: spec.id
        }));

        const { specializationId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'specializationId',
                message: 'Select a specialization to remove:',
                choices: specChoices,
                pageSize: 10
            }
        ]);

        // Confirm the action
        const selectedSpec = specsResult.specializations.find(s => s.id === specializationId);
        const selectedAgent = agentsResult.data.find(a => a.id === agentId);

        console.log(chalk.cyan('\n┌─ Confirm Removal ───────────────────────────────────────┐'));
        console.log(chalk.cyan(`│ Specialization: ${chalk.white(selectedSpec.name)}${' '.repeat(Math.max(0, 40 - selectedSpec.name.length))}│`));
        console.log(chalk.cyan(`│ Agent: ${chalk.white(selectedAgent.name)}${' '.repeat(Math.max(0, 48 - selectedAgent.name.length))}│`));
        console.log(chalk.cyan('└──────────────────────────────────────────────────────────────┘'));

        const { confirmRemove } = await inquirer.prompt([
            {
                type: 'confirm',
                name: 'confirmRemove',
                message: `Remove "${selectedSpec.name}" from agent "${selectedAgent.name}"?`,
                default: true
            }
        ]);

        if (!confirmRemove) {
            console.log(chalk.yellow('\nOperation cancelled.'));
            await inquirer.prompt([{ type: 'input', name: 'continue', message: '🔄 Press Enter to continue...' }]);
            return;
        }

        // Remove the specialization
        spinner.text = 'Removing specialization from agent...';
        spinner.start();

        const removeResult = await juliaBridge.runJuliaCommand('specialization.remove', {
            specialization_id: specializationId,
            agent_id: agentId
        });

        spinner.stop();

        if (removeResult && removeResult.success) {
            console.log(chalk.green('\n✅ Specialization removed successfully!'));
            console.log(chalk.cyan('\nThe capabilities and skills granted by this specialization have been removed from the agent.'));
        } else {
            console.log(chalk.red(`\n❌ Failed to remove specialization: ${removeResult?.error || 'Unknown error'}`));
        }
    } catch (error) {
        spinner.fail('Failed to communicate with backend.');
        console.error(chalk.red(`\n❌ Error: ${error.message}`));
    }

    await inquirer.prompt([{ type: 'input', name: 'continue', message: '🔄 Press Enter to continue...' }]);
}

/**
 * View agent specializations
 */
async function viewAgentSpecializations(juliaBridge, breadcrumbs) {
    displayHeader(breadcrumbs.join(' > '));

    console.log(chalk.cyan(`
┌─────────────────────────────────────────────────┐
│                                                 │
│  👨‍💻 Agent Specializations                     │
│                                                 │
│  View specializations applied to an agent.      │
│                                                 │
└─────────────────────────────────────────────────┘
`));

    // First, get the list of agents
    const spinner = ora({
        text: 'Fetching agents...',
        spinner: 'dots',
        color: 'blue'
    }).start();

    try {
        const agentsResult = await juliaBridge.runJuliaCommand('agents.list_agents', {});

        if (!agentsResult || !agentsResult.success || !Array.isArray(agentsResult.data) || agentsResult.data.length === 0) {
            spinner.fail('No agents available.');
            console.log(chalk.yellow('\nNo agents found.'));
            await inquirer.prompt([{ type: 'input', name: 'continue', message: '🔄 Press Enter to continue...' }]);
            return;
        }

        // Let user select an agent
        spinner.stop();

        const agentChoices = agentsResult.data.map(agent => ({
            name: `${agent.name} (${agent.type}) - ${agent.status}`,
            value: agent.id
        }));

        const { agentId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'agentId',
                message: 'Select an agent:',
                choices: agentChoices,
                pageSize: 10
            }
        ]);

        // Get specializations for this agent
        spinner.text = 'Fetching agent specializations...';
        spinner.start();

        const specsResult = await juliaBridge.runJuliaCommand('specialization.get_agent_specializations', {
            agent_id: agentId
        });

        spinner.stop();

        const selectedAgent = agentsResult.data.find(a => a.id === agentId);

        console.log(chalk.cyan(`\n┌─ Specializations for ${selectedAgent.name} ─${'\u2500'.repeat(Math.max(0, 40 - selectedAgent.name.length))}┐`));

        if (!specsResult || !specsResult.success || !Array.isArray(specsResult.specializations) || specsResult.specializations.length === 0) {
            console.log(chalk.cyan(`│                                                                      │`));
            console.log(chalk.cyan(`│  ${chalk.yellow('No specializations applied to this agent.')}${' '.repeat(20)}  │`));
            console.log(chalk.cyan(`│                                                                      │`));
        } else {
            console.log(chalk.cyan(`│                                                                      │`));

            specsResult.specializations.forEach((spec, index) => {
                console.log(chalk.cyan(`│  ${index + 1}. ${chalk.bold(spec.name)}${' '.repeat(Math.max(0, 55 - spec.name.length - String(index + 1).length))}  │`));
                console.log(chalk.cyan(`│     ${spec.description.substring(0, 60)}${spec.description.length > 60 ? '...' : ''}${' '.repeat(Math.max(0, 60 - Math.min(spec.description.length, 63)))}  │`));
                console.log(chalk.cyan(`│                                                                      │`));
            });
        }

        console.log(chalk.cyan(`└──────────────────────────────────────────────────────────────┘`));
    } catch (error) {
        spinner.fail('Failed to communicate with backend.');
        console.error(chalk.red(`\n❌ Error: ${error.message}`));
    }

    await inquirer.prompt([{ type: 'input', name: 'continue', message: '🔄 Press Enter to continue...' }]);
}

/**
 * Delete specialization
 */
async function deleteSpecialization(juliaBridge, breadcrumbs) {
    displayHeader(breadcrumbs.join(' > '));

    console.log(chalk.cyan(`
┌─────────────────────────────────────────────────┐
│                                                 │
│  🗑️ Delete Specialization                      │
│                                                 │
│  Permanently delete a specialization.           │
│                                                 │
└─────────────────────────────────────────────────┘
`));

    // First, get the list of specializations
    const spinner = ora({
        text: 'Fetching specializations...',
        spinner: 'dots',
        color: 'blue'
    }).start();

    try {
        const result = await juliaBridge.runJuliaCommand('specialization.list', {});

        spinner.stop();

        if (!result || !result.success || !Array.isArray(result.specializations) || result.specializations.length === 0) {
            console.log(chalk.yellow('\nNo specializations found.'));
            await inquirer.prompt([{ type: 'input', name: 'continue', message: '🔄 Press Enter to continue...' }]);
            return;
        }

        // Let user select a specialization
        const choices = result.specializations.map(spec => ({
            name: `${spec.name} - ${spec.description.substring(0, 40)}${spec.description.length > 40 ? '...' : ''}`,
            value: spec.id
        }));

        choices.push(new inquirer.Separator(), { name: 'Cancel', value: 'cancel' });

        const { specId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'specId',
                message: 'Select a specialization to delete:',
                choices: choices,
                pageSize: 15
            }
        ]);

        if (specId === 'cancel') {
            console.log(chalk.yellow('\nOperation cancelled.'));
            return;
        }

        // Confirm deletion
        const selectedSpec = result.specializations.find(s => s.id === specId);

        console.log(chalk.red('\n⚠️ Warning: This action cannot be undone!'));
        console.log(chalk.cyan(`\nYou are about to delete the specialization: ${chalk.bold(selectedSpec.name)}`));

        const { confirmDelete } = await inquirer.prompt([
            {
                type: 'confirm',
                name: 'confirmDelete',
                message: 'Are you sure you want to delete this specialization?',
                default: false
            }
        ]);

        if (!confirmDelete) {
            console.log(chalk.yellow('\nDeletion cancelled.'));
            await inquirer.prompt([{ type: 'input', name: 'continue', message: '🔄 Press Enter to continue...' }]);
            return;
        }

        // Delete the specialization
        spinner.text = 'Deleting specialization...';
        spinner.start();

        const deleteResult = await juliaBridge.runJuliaCommand('specialization.delete', { id: specId });

        spinner.stop();

        if (deleteResult && deleteResult.success) {
            console.log(chalk.green('\n✅ Specialization deleted successfully!'));
        } else {
            console.log(chalk.red(`\n❌ Failed to delete specialization: ${deleteResult?.error || 'Unknown error'}`));
        }
    } catch (error) {
        spinner.fail('Failed to communicate with backend.');
        console.error(chalk.red(`\n❌ Error: ${error.message}`));
    }

    await inquirer.prompt([{ type: 'input', name: 'continue', message: '🔄 Press Enter to continue...' }]);
}

// Export the menu function
module.exports = {
    agentSpecializationMenu,
    listSpecializations,
    createSpecialization,
    viewSpecializationDetails,
    applySpecialization,
    removeSpecialization,
    viewAgentSpecializations,
    deleteSpecialization
};
