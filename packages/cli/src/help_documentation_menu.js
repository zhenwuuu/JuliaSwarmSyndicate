// Import required modules
const chalk = require('chalk');
const inquirer = require('inquirer');
const ora = require('ora');
const fs = require('fs');
const path = require('path');
const { marked } = require('marked');
const { markedTerminal } = require('marked-terminal');

// Configure marked to use the terminal renderer
marked.use(markedTerminal());

// Initialize variables that will be set by the module consumer
let juliaBridge;
let displayHeader;

/**
 * Display the help and documentation menu
 */
async function helpDocumentationMenu() {
    try {
        displayHeader('Help & Documentation');

        const { action } = await inquirer.prompt([
            {
                type: 'list',
                name: 'action',
                message: 'Choose an action:',
                choices: [
                    { name: '📚 Getting Started Guide', value: 'getting_started' },
                    { name: '🔍 Feature Documentation', value: 'feature_docs' },
                    { name: '🧩 API Reference', value: 'api_reference' },
                    { name: '🛠️ Troubleshooting', value: 'troubleshooting' },
                    { name: '❓ FAQ', value: 'faq' },
                    { name: '🔄 Check for Documentation Updates', value: 'check_updates' },
                    { name: '🔙 Back to Main Menu', value: 'back' }
                ]
            }
        ]);

        switch (action) {
            case 'getting_started':
                await showGettingStartedGuide();
                break;
            case 'feature_docs':
                await showFeatureDocumentation();
                break;
            case 'api_reference':
                await showApiReference();
                break;
            case 'troubleshooting':
                await showTroubleshooting();
                break;
            case 'faq':
                await showFAQ();
                break;
            case 'check_updates':
                await checkDocumentationUpdates();
                break;
            case 'back':
                return;
        }

        // Return to the help and documentation menu after completing an action
        await helpDocumentationMenu();
    } catch (error) {
        console.error(chalk.red('Error:'), error.message);
        await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
    }
}

/**
 * Show the getting started guide
 */
async function showGettingStartedGuide() {
    try {
        const spinner = ora('Loading getting started guide...').start();
        
        try {
            // Try to load from backend first
            const result = await juliaBridge.runJuliaCommand('Documentation.get_documentation', ['getting_started']);
            
            spinner.stop();
            
            if (result.success && result.content) {
                console.log(marked(result.content));
            } else {
                // Fallback to local file
                const docPath = path.join(__dirname, '..', 'docs', 'getting_started.md');
                
                if (fs.existsSync(docPath)) {
                    const content = fs.readFileSync(docPath, 'utf8');
                    console.log(marked(content));
                } else {
                    // Hardcoded fallback content
                    console.log(marked(`
# Getting Started with JuliaOS

## Introduction

JuliaOS is a powerful framework that combines Julia's computational capabilities with blockchain technology, swarm intelligence, and agent-based systems. This guide will help you get started with JuliaOS and explore its features.

## Installation

1. **Prerequisites**:
   - Node.js (v14 or later)
   - Julia (v1.6 or later)
   - Git

2. **Clone the Repository**:
   \`\`\`bash
   git clone https://github.com/yourusername/juliaos.git
   cd juliaos
   \`\`\`

3. **Install Dependencies**:
   \`\`\`bash
   npm install
   \`\`\`

4. **Install Julia Packages**:
   \`\`\`bash
   julia -e 'using Pkg; Pkg.activate("."); Pkg.instantiate()'
   \`\`\`

## Running JuliaOS

1. **Start the Julia Server**:
   \`\`\`bash
   npm run start-julia
   \`\`\`

2. **Start the Interactive CLI**:
   \`\`\`bash
   npm run interactive
   \`\`\`

## Core Features

- **Agent Management**: Create and manage intelligent agents
- **Swarm Management**: Coordinate multiple agents in swarms
- **Neural Networks**: Train and deploy neural networks
- **Portfolio Optimization**: Optimize investment portfolios
- **Swarm Algorithms**: Implement and test swarm intelligence algorithms
- **Cross-Chain Hub**: Interact with multiple blockchains
- **API Keys Management**: Manage API keys for external services

## Next Steps

- Explore the Feature Documentation for detailed information on each feature
- Check out the API Reference for programmatic usage
- Visit the Troubleshooting section if you encounter any issues

For more information, visit the [JuliaOS GitHub repository](https://github.com/yourusername/juliaos).
`));
                }
            }
        } catch (error) {
            spinner.fail('Failed to load getting started guide');
            console.error(chalk.red('Error:'), error.message);
        }
    } catch (error) {
        console.error(chalk.red('Error:'), error.message);
    }
    
    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * Show feature documentation
 */
async function showFeatureDocumentation() {
    try {
        // Get list of features
        const features = [
            { name: 'Agent Management', value: 'agent_management' },
            { name: 'Swarm Management', value: 'swarm_management' },
            { name: 'Neural Networks', value: 'neural_networks' },
            { name: 'Portfolio Optimization', value: 'portfolio_optimization' },
            { name: 'Swarm Algorithms', value: 'swarm_algorithms' },
            { name: 'Cross-Chain Hub', value: 'cross_chain_hub' },
            { name: 'API Keys Management', value: 'api_keys_management' },
            { name: 'System Configuration', value: 'system_configuration' },
            { name: 'Performance Metrics', value: 'performance_metrics' }
        ];
        
        // Prompt user to select a feature
        const { feature } = await inquirer.prompt([
            {
                type: 'list',
                name: 'feature',
                message: 'Select a feature:',
                choices: features
            }
        ]);
        
        const spinner = ora(`Loading documentation for ${feature}...`).start();
        
        try {
            // Try to load from backend first
            const result = await juliaBridge.runJuliaCommand('Documentation.get_documentation', [feature]);
            
            spinner.stop();
            
            if (result.success && result.content) {
                console.log(marked(result.content));
            } else {
                // Fallback to local file
                const docPath = path.join(__dirname, '..', 'docs', `${feature}.md`);
                
                if (fs.existsSync(docPath)) {
                    const content = fs.readFileSync(docPath, 'utf8');
                    console.log(marked(content));
                } else {
                    // Hardcoded fallback content
                    console.log(chalk.yellow(`\nDocumentation for ${feature.replace(/_/g, ' ')} is not available.`));
                    console.log(chalk.yellow('Please check back later or visit our GitHub repository for the latest documentation.'));
                }
            }
        } catch (error) {
            spinner.fail(`Failed to load documentation for ${feature}`);
            console.error(chalk.red('Error:'), error.message);
        }
    } catch (error) {
        console.error(chalk.red('Error:'), error.message);
    }
    
    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * Show API reference
 */
async function showApiReference() {
    try {
        // Get list of API categories
        const categories = [
            { name: 'Agent API', value: 'agent_api' },
            { name: 'Swarm API', value: 'swarm_api' },
            { name: 'Blockchain API', value: 'blockchain_api' },
            { name: 'Storage API', value: 'storage_api' },
            { name: 'Bridge API', value: 'bridge_api' },
            { name: 'DEX API', value: 'dex_api' },
            { name: 'Neural Networks API', value: 'neural_networks_api' },
            { name: 'Configuration API', value: 'config_api' },
            { name: 'Metrics API', value: 'metrics_api' }
        ];
        
        // Prompt user to select a category
        const { category } = await inquirer.prompt([
            {
                type: 'list',
                name: 'category',
                message: 'Select an API category:',
                choices: categories
            }
        ]);
        
        const spinner = ora(`Loading API reference for ${category}...`).start();
        
        try {
            // Try to load from backend first
            const result = await juliaBridge.runJuliaCommand('Documentation.get_api_reference', [category]);
            
            spinner.stop();
            
            if (result.success && result.content) {
                console.log(marked(result.content));
            } else {
                // Fallback to local file
                const docPath = path.join(__dirname, '..', 'docs', 'api', `${category}.md`);
                
                if (fs.existsSync(docPath)) {
                    const content = fs.readFileSync(docPath, 'utf8');
                    console.log(marked(content));
                } else {
                    // Hardcoded fallback content
                    console.log(chalk.yellow(`\nAPI reference for ${category.replace(/_/g, ' ')} is not available.`));
                    console.log(chalk.yellow('Please check back later or visit our GitHub repository for the latest API documentation.'));
                }
            }
        } catch (error) {
            spinner.fail(`Failed to load API reference for ${category}`);
            console.error(chalk.red('Error:'), error.message);
        }
    } catch (error) {
        console.error(chalk.red('Error:'), error.message);
    }
    
    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * Show troubleshooting guide
 */
async function showTroubleshooting() {
    try {
        const spinner = ora('Loading troubleshooting guide...').start();
        
        try {
            // Try to load from backend first
            const result = await juliaBridge.runJuliaCommand('Documentation.get_documentation', ['troubleshooting']);
            
            spinner.stop();
            
            if (result.success && result.content) {
                console.log(marked(result.content));
            } else {
                // Fallback to local file
                const docPath = path.join(__dirname, '..', 'docs', 'troubleshooting.md');
                
                if (fs.existsSync(docPath)) {
                    const content = fs.readFileSync(docPath, 'utf8');
                    console.log(marked(content));
                } else {
                    // Hardcoded fallback content
                    console.log(marked(`
# Troubleshooting Guide

## Common Issues and Solutions

### Julia Server Connection Issues

**Problem**: Unable to connect to the Julia server.

**Solutions**:
1. Ensure the Julia server is running with \`npm run start-julia\`
2. Check if the server is running on the correct port (default: 8052)
3. Verify there are no firewall issues blocking the connection
4. Restart the Julia server and try again

### Package Installation Problems

**Problem**: Julia package installation fails.

**Solutions**:
1. Run \`julia -e 'using Pkg; Pkg.update()'\` to update package registry
2. Delete the \`Manifest.toml\` file and run \`julia -e 'using Pkg; Pkg.activate("."); Pkg.instantiate()'\`
3. Check for package compatibility issues with your Julia version

### Blockchain Connection Issues

**Problem**: Unable to connect to blockchain networks.

**Solutions**:
1. Verify your API keys are correctly configured
2. Check your internet connection
3. Ensure the RPC endpoints are accessible
4. Try using alternative RPC providers

### Performance Issues

**Problem**: System is running slowly.

**Solutions**:
1. Check resource usage in Performance Metrics
2. Close unnecessary applications
3. Increase memory allocation for Julia if possible
4. Optimize storage by cleaning up unused data

### Wallet Connection Problems

**Problem**: Unable to connect or use wallets.

**Solutions**:
1. Verify wallet configuration
2. Check if the wallet has sufficient funds
3. Ensure correct network is selected
4. Try reconnecting the wallet

## Getting Help

If you continue to experience issues:

1. Check the FAQ section for more information
2. Visit our GitHub repository for the latest updates
3. Join our community Discord server for support
4. Submit an issue on GitHub with detailed information about your problem

For critical issues, please contact our support team at support@juliaos.com.
`));
                }
            }
        } catch (error) {
            spinner.fail('Failed to load troubleshooting guide');
            console.error(chalk.red('Error:'), error.message);
        }
    } catch (error) {
        console.error(chalk.red('Error:'), error.message);
    }
    
    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * Show FAQ
 */
async function showFAQ() {
    try {
        const spinner = ora('Loading FAQ...').start();
        
        try {
            // Try to load from backend first
            const result = await juliaBridge.runJuliaCommand('Documentation.get_documentation', ['faq']);
            
            spinner.stop();
            
            if (result.success && result.content) {
                console.log(marked(result.content));
            } else {
                // Fallback to local file
                const docPath = path.join(__dirname, '..', 'docs', 'faq.md');
                
                if (fs.existsSync(docPath)) {
                    const content = fs.readFileSync(docPath, 'utf8');
                    console.log(marked(content));
                } else {
                    // Hardcoded fallback content
                    console.log(marked(`
# Frequently Asked Questions (FAQ)

## General Questions

### What is JuliaOS?
JuliaOS is a comprehensive framework that combines Julia's computational capabilities with blockchain technology, swarm intelligence, and agent-based systems. It provides a unified interface for creating, managing, and deploying intelligent agents and swarms.

### What can I do with JuliaOS?
JuliaOS enables you to create intelligent agents, coordinate them in swarms, train neural networks, optimize investment portfolios, implement swarm algorithms, interact with multiple blockchains, and much more.

### Is JuliaOS open source?
Yes, JuliaOS is open source and available on GitHub. You can contribute to the project by submitting pull requests or reporting issues.

## Technical Questions

### What are the system requirements for JuliaOS?
- Node.js (v14 or later)
- Julia (v1.6 or later)
- 4GB RAM minimum (8GB recommended)
- 1GB free disk space

### How do I update JuliaOS?
You can update JuliaOS by pulling the latest changes from the GitHub repository and running \`npm install\` to update dependencies.

### Can I use JuliaOS with other programming languages?
JuliaOS primarily uses Julia for backend processing, but it provides APIs that can be accessed from other programming languages. There's also a Python wrapper available for integration with Python applications.

## Feature-Specific Questions

### What blockchain networks does JuliaOS support?
JuliaOS supports Ethereum, Polygon, Solana, Avalanche, and Binance Smart Chain. More networks will be added in future updates.

### How do I create a new agent?
You can create a new agent through the Agent Management menu in the interactive CLI. You'll need to provide a name, description, and select capabilities for your agent.

### What swarm algorithms are available?
JuliaOS includes several swarm algorithms such as Particle Swarm Optimization, Ant Colony Optimization, Differential Evolution, and more. You can view and configure these algorithms in the Swarm Algorithms menu.

### How do I train a neural network?
You can train neural networks through the Neural Networks menu. JuliaOS supports various network architectures including dense, recurrent, and convolutional networks.

## Troubleshooting

### The Julia server won't start. What should I do?
Check if Julia is properly installed and in your PATH. Also, ensure all required Julia packages are installed by running \`julia -e 'using Pkg; Pkg.activate("."); Pkg.instantiate()'\`.

### I'm getting connection errors when trying to use blockchain features. How do I fix this?
Verify your API keys are correctly configured in the API Keys Management menu. Also, check your internet connection and ensure the RPC endpoints are accessible.

### Where can I find logs for debugging?
Logs are stored in the \`logs\` directory. You can also view performance logs through the Performance Metrics menu.

## Support and Community

### How do I get help if I'm stuck?
You can:
1. Check the documentation in the Help & Documentation menu
2. Visit our GitHub repository for the latest information
3. Join our community Discord server for support
4. Submit an issue on GitHub with detailed information about your problem

### How can I contribute to JuliaOS?
You can contribute by:
1. Reporting bugs and suggesting features on GitHub
2. Submitting pull requests with code improvements
3. Writing documentation and tutorials
4. Helping other users in the community

### Where can I find more information about JuliaOS?
Visit our GitHub repository at https://github.com/yourusername/juliaos for the latest information, documentation, and updates.
`));
                }
            }
        } catch (error) {
            spinner.fail('Failed to load FAQ');
            console.error(chalk.red('Error:'), error.message);
        }
    } catch (error) {
        console.error(chalk.red('Error:'), error.message);
    }
    
    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * Check for documentation updates
 */
async function checkDocumentationUpdates() {
    try {
        const spinner = ora('Checking for documentation updates...').start();
        
        try {
            const result = await juliaBridge.runJuliaCommand('Documentation.check_updates', []);
            
            spinner.stop();
            
            if (!result.success) {
                console.log(chalk.red(`Error: ${result.error || 'Failed to check for documentation updates'}`));
                return;
            }
            
            if (result.updates_available) {
                console.log(chalk.green('\nDocumentation updates are available!'));
                
                if (result.updates && result.updates.length > 0) {
                    console.log(chalk.cyan('\nUpdated Documents:'));
                    result.updates.forEach(update => {
                        console.log(`- ${update.title}: ${update.description}`);
                    });
                }
                
                // Prompt to download updates
                const { downloadUpdates } = await inquirer.prompt([
                    {
                        type: 'confirm',
                        name: 'downloadUpdates',
                        message: 'Do you want to download the latest documentation?',
                        default: true
                    }
                ]);
                
                if (downloadUpdates) {
                    const downloadSpinner = ora('Downloading documentation updates...').start();
                    
                    try {
                        const downloadResult = await juliaBridge.runJuliaCommand('Documentation.download_updates', []);
                        
                        downloadSpinner.stop();
                        
                        if (!downloadResult.success) {
                            console.log(chalk.red(`Error: ${downloadResult.error || 'Failed to download documentation updates'}`));
                            return;
                        }
                        
                        console.log(chalk.green('\nDocumentation updated successfully!'));
                    } catch (error) {
                        downloadSpinner.fail('Failed to download documentation updates');
                        console.error(chalk.red('Error:'), error.message);
                    }
                }
            } else {
                console.log(chalk.green('\nYour documentation is up to date!'));
            }
        } catch (error) {
            spinner.fail('Failed to check for documentation updates');
            console.error(chalk.red('Error:'), error.message);
        }
    } catch (error) {
        console.error(chalk.red('Error:'), error.message);
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
        helpDocumentationMenu,
        showGettingStartedGuide,
        showFeatureDocumentation,
        showApiReference,
        showTroubleshooting,
        showFAQ,
        checkDocumentationUpdates
    };
};
