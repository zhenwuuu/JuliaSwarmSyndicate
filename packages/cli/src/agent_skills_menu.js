// Import required modules
const chalk = require('chalk');
const inquirer = require('inquirer');
const ora = require('ora');

// Define a displayHeader function that will be used if one isn't provided
let displayHeader = (title) => {
    console.clear();
    console.log(chalk.bold.cyan(`=== ${title || 'JuliaOS'} ===`));
};

// Define a global juliaBridge variable that will be set when the module is initialized
let juliaBridge;

// =============================================================================
// Agent Skills & Specialization Menu
// =============================================================================
async function agentSkillsMenu() {
    // Make sure we have access to the required variables
    if (!juliaBridge) {
        console.error('Error: juliaBridge is not defined. Make sure it is properly passed to this module.');
        return;
    }

    while (true) {
        console.clear();
        displayHeader('Agent Skills & Specialization');

        console.log(chalk.cyan(`
      ╔══════════════════════════════════════════╗
      ║     Agent Skills & Specialization        ║
      ║                                          ║
      ║  🧠 Manage agent skills, training, and    ║
      ║     specialization paths.                ║
      ║                                          ║
      ╚══════════════════════════════════════════╝
    `));

        const { action } = await inquirer.prompt([
            {
                type: 'list',
                name: 'action',
                message: '🧠 Choose an action:',
                choices: [
                    'View Agent Skills',
                    'Train Agent Skill',
                    'Set Agent Specialization',
                    'View Specialization Paths',
                    'Advanced Specialization Management',
                    'Back to Main Menu'
                ]
            }
        ]);

        // Show a loading animation when an action is selected
        if (action !== 'Back to Main Menu') {
            const spinner = ora({
                text: `Preparing ${action.toLowerCase()}...`,
                spinner: 'dots',
                color: 'cyan'
            }).start();

            await new Promise(resolve => setTimeout(resolve, 500));
            spinner.stop();
        }

        switch (action) {
            case 'View Agent Skills':
                await viewAgentSkills();
                break;
            case 'Train Agent Skill':
                await trainAgentSkill();
                break;
            case 'Set Agent Specialization':
                await setAgentSpecialization();
                break;
            case 'View Specialization Paths':
                await viewSpecializationPaths();
                break;
            case 'Advanced Specialization Management':
                // Call the agent specialization menu
                const { agentSpecializationMenu } = require('./agent_specialization_menu');
                await agentSpecializationMenu(juliaBridge, ['Main', 'Agent Skills & Specialization', 'Advanced Specialization']);
                break;
            case 'Back to Main Menu':
                return;
        }
    }
}

async function viewAgentSkills() {
    try {
        // Get list of agents
        const agentsResult = await juliaBridge.runJuliaCommand('AgentSystem.list_agents', []);

        if (!agentsResult.success || !agentsResult.agents || agentsResult.agents.length === 0) {
            console.log(chalk.yellow('No agents found. Please create an agent first.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        // Select an agent
        const { agentId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'agentId',
                message: 'Select an agent:',
                choices: agentsResult.agents.map(agent => ({
                    name: `${agent.name} (${agent.id})`,
                    value: agent.id
                }))
            }
        ]);

        const spinner = ora('Fetching agent skills...').start();

        // Get agent skills
        const skillsResult = await juliaBridge.runJuliaCommand('Skills.get_agent_skill_set', [agentId]);

        spinner.stop();

        if (!skillsResult.success) {
            console.log(chalk.red(`Error: ${skillsResult.error || 'Failed to fetch agent skills'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        // Display agent skills
        console.log(chalk.cyan('\nAgent Skills:'));

        if (Object.keys(skillsResult.skills).length === 0) {
            console.log(chalk.yellow('This agent has no skills yet.'));
        } else {
            // Group skills by category
            const skillsByCategory = {};

            for (const [skillId, skill] of Object.entries(skillsResult.skills)) {
                if (!skillsByCategory[skill.category]) {
                    skillsByCategory[skill.category] = [];
                }
                skillsByCategory[skill.category].push(skill);
            }

            // Display skills by category
            for (const [category, skills] of Object.entries(skillsByCategory)) {
                console.log(chalk.bold(`\n${category.toUpperCase()}`));

                // Sort skills by level
                skills.sort((a, b) => b.level - a.level);

                for (const skill of skills) {
                    console.log(`  ${skill.name} (Level ${skill.level} - ${skill.level_name})`);
                    console.log(`    Experience: ${skill.experience.toFixed(2)}`);
                    console.log(`    Proficiency: ${(skill.proficiency * 100).toFixed(1)}% to next level`);
                    console.log(`    Performance Bonus: ${((skill.performance_bonus - 1.0) * 100).toFixed(1)}%`);
                    console.log(`    Usage Count: ${skill.usage_count}`);
                }
            }
        }

        // Get agent specialization
        const specializationResult = await juliaBridge.runJuliaCommand('Skills.get_agent_specialization', [agentId]);

        if (specializationResult.success) {
            console.log(chalk.cyan(`\nSpecialization: ${specializationResult.specialization}`));
        }
    } catch (error) {
        console.error(chalk.red(`Error: ${error.message}`));
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

async function trainAgentSkill() {
    try {
        // Get list of agents
        const agentsResult = await juliaBridge.runJuliaCommand('AgentSystem.list_agents', []);

        if (!agentsResult.success || !agentsResult.agents || agentsResult.agents.length === 0) {
            console.log(chalk.yellow('No agents found. Please create an agent first.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        // Select an agent
        const { agentId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'agentId',
                message: 'Select an agent:',
                choices: agentsResult.agents.map(agent => ({
                    name: `${agent.name} (${agent.id})`,
                    value: agent.id
                }))
            }
        ]);

        // Get agent skills
        const skillsResult = await juliaBridge.runJuliaCommand('Skills.get_agent_skill_set', [agentId]);

        if (!skillsResult.success || Object.keys(skillsResult.skills).length === 0) {
            console.log(chalk.yellow('This agent has no skills to train.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        // Select a skill to train
        const { skillId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'skillId',
                message: 'Select a skill to train:',
                choices: Object.entries(skillsResult.skills).map(([id, skill]) => ({
                    name: `${skill.name} (Level ${skill.level} - ${skill.level_name})`,
                    value: id
                }))
            }
        ]);

        // Select training intensity
        const { intensity } = await inquirer.prompt([
            {
                type: 'list',
                name: 'intensity',
                message: 'Select training intensity:',
                choices: [
                    { name: 'Low (0.3)', value: 0.3 },
                    { name: 'Medium (0.5)', value: 0.5 },
                    { name: 'High (0.8)', value: 0.8 },
                    { name: 'Intense (1.0)', value: 1.0 }
                ]
            }
        ]);

        const spinner = ora('Training skill...').start();

        // Train the skill
        const trainingResult = await juliaBridge.runJuliaCommand('Skills.train_skill', [agentId, skillId, intensity]);

        spinner.stop();

        if (!trainingResult.success) {
            console.log(chalk.red(`Error: ${trainingResult.error || 'Failed to train skill'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        console.log(chalk.green('Skill trained successfully!'));

        if (trainingResult.leveled_up) {
            console.log(chalk.cyan('The skill leveled up!'));
        }

        // Get updated skill info
        const updatedSkillsResult = await juliaBridge.runJuliaCommand('Skills.get_agent_skill_set', [agentId]);

        if (updatedSkillsResult.success && updatedSkillsResult.skills[skillId]) {
            const skill = updatedSkillsResult.skills[skillId];
            console.log(chalk.cyan(`\nUpdated Skill Information:`));
            console.log(`Name: ${skill.name}`);
            console.log(`Level: ${skill.level} (${skill.level_name})`);
            console.log(`Experience: ${skill.experience.toFixed(2)}`);
            console.log(`Proficiency: ${(skill.proficiency * 100).toFixed(1)}% to next level`);
            console.log(`Performance Bonus: ${((skill.performance_bonus - 1.0) * 100).toFixed(1)}%`);
        }
    } catch (error) {
        console.error(chalk.red(`Error: ${error.message}`));
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

async function setAgentSpecialization() {
    try {
        // Get list of agents
        const agentsResult = await juliaBridge.runJuliaCommand('AgentSystem.list_agents', []);

        if (!agentsResult.success || !agentsResult.agents || agentsResult.agents.length === 0) {
            console.log(chalk.yellow('No agents found. Please create an agent first.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        // Select an agent
        const { agentId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'agentId',
                message: 'Select an agent:',
                choices: agentsResult.agents.map(agent => ({
                    name: `${agent.name} (${agent.id})`,
                    value: agent.id
                }))
            }
        ]);

        // Get specialization paths
        const pathsResult = await juliaBridge.runJuliaCommand('Skills.SpecializationPath.all', []);

        if (!pathsResult.success) {
            console.log(chalk.red(`Error: ${pathsResult.error || 'Failed to fetch specialization paths'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        // Select a specialization path
        const { specialization } = await inquirer.prompt([
            {
                type: 'list',
                name: 'specialization',
                message: 'Select a specialization path:',
                choices: pathsResult.paths.map(path => ({
                    name: path.charAt(0).toUpperCase() + path.slice(1).replace('_', ' '),
                    value: path
                }))
            }
        ]);

        const spinner = ora('Setting agent specialization...').start();

        // Set the specialization
        const specializationResult = await juliaBridge.runJuliaCommand('Skills.set_agent_specialization', [agentId, specialization]);

        spinner.stop();

        if (!specializationResult.success) {
            console.log(chalk.red(`Error: ${specializationResult.error || 'Failed to set agent specialization'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        console.log(chalk.green(`Agent specialization set to ${specialization} successfully!`));

        // Get recommended skills for this specialization
        const recommendedSkillsResult = await juliaBridge.runJuliaCommand('Skills.SpecializationPath.recommended_skills', [specialization]);

        if (recommendedSkillsResult.success) {
            console.log(chalk.cyan('\nRecommended skills for this specialization:'));
            for (const skillId of recommendedSkillsResult.skills) {
                console.log(`  - ${skillId.replace('_', ' ').split(' ').map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(' ')}`);
            }
        }
    } catch (error) {
        console.error(chalk.red(`Error: ${error.message}`));
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

async function viewSpecializationPaths() {
    try {
        const spinner = ora('Fetching specialization paths...').start();

        // Get specialization paths from the backend
        const pathsResult = await juliaBridge.runJuliaCommand('Skills.SpecializationPath.all', []);

        spinner.stop();

        if (!pathsResult.success) {
            console.log(chalk.red(`Error: ${pathsResult.error || 'Failed to fetch specialization paths'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        // If no paths are returned, use hardcoded paths as fallback
        const paths = pathsResult.paths && pathsResult.paths.length > 0 ? pathsResult.paths : [
            'analyst',
            'trader',
            'researcher',
            'optimizer',
            'predictor',
            'risk_manager',
            'security_expert',
            'generalist'
        ];

        console.log(chalk.cyan('\nSpecialization Paths:'));

        for (const path of paths) {
            // Get path details from the backend
            const detailsResult = await juliaBridge.runJuliaCommand('Skills.SpecializationPath.get_details', [path]);

            console.log(chalk.bold(`\n${path.charAt(0).toUpperCase() + path.slice(1).replace('_', ' ')}`));

            if (detailsResult.success && detailsResult.details) {
                const details = detailsResult.details;

                if (details.description) {
                    console.log(`  ${details.description}`);
                }

                if (details.primary_category) {
                    console.log(`  Primary Category: ${details.primary_category}`);
                }

                if (details.specialization_bonus) {
                    console.log(`  Specialization Bonus: ${((details.specialization_bonus - 1.0) * 100).toFixed(1)}%`);
                }

                if (details.recommended_skills && details.recommended_skills.length > 0) {
                    console.log('  Recommended Skills:');
                    for (const skillId of details.recommended_skills) {
                        console.log(`    - ${skillId.replace('_', ' ').split(' ').map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(' ')}`);
                    }
                }

                if (details.benefits && details.benefits.length > 0) {
                    console.log('  Benefits:');
                    for (const benefit of details.benefits) {
                        console.log(`    - ${benefit}`);
                    }
                }
            } else {
                // Fallback to individual API calls if get_details fails
                // Get primary category for this path
                const categoryResult = await juliaBridge.runJuliaCommand('Skills.SpecializationPath.primary_category', [path]);

                // Get specialization bonus for this path
                const bonusResult = await juliaBridge.runJuliaCommand('Skills.SpecializationPath.specialization_bonus', [path]);

                if (categoryResult.success && categoryResult.category) {
                    console.log(`  Primary Category: ${categoryResult.category}`);
                }

                if (bonusResult.success && bonusResult.bonus) {
                    console.log(`  Specialization Bonus: ${((bonusResult.bonus - 1.0) * 100).toFixed(1)}%`);
                }

                // Get recommended skills for this path
                const recommendedSkillsResult = await juliaBridge.runJuliaCommand('Skills.SpecializationPath.recommended_skills', [path]);

                if (recommendedSkillsResult.success && recommendedSkillsResult.skills) {
                    console.log('  Recommended Skills:');
                    for (const skillId of recommendedSkillsResult.skills) {
                        console.log(`    - ${skillId.replace('_', ' ').split(' ').map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(' ')}`);
                    }
                }
            }
        }
    } catch (error) {
        console.error(chalk.red(`Error: ${error.message}`));
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
        agentSkillsMenu,
        viewAgentSkills,
        trainAgentSkill,
        setAgentSpecialization,
        viewSpecializationPaths
    };
};
