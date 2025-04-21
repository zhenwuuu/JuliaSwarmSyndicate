const chalk = require('chalk');
const inquirer = require('inquirer');

/**
 * Visualize a swarm
 */
async function visualizeSwarm(juliaBridge, breadcrumbs) {
    try {
        // Call the swarm visualization menu
        const { swarmVisualizationMenu } = require('./swarm_visualization');
        await swarmVisualizationMenu(juliaBridge, [...breadcrumbs, 'Visualize']);
    } catch (error) {
        console.error(chalk.red('An unexpected error occurred while visualizing the swarm.'));
        console.error(chalk.red('Details:'), error.message);
        await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
    }
}

module.exports = visualizeSwarm;
