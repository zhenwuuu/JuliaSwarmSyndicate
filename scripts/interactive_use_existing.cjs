#!/usr/bin/env node

/**
 * interactive_use_existing.cjs - Modified version that uses an existing Julia server
 *
 * This script provides a comprehensive interactive command-line interface
 * for managing Agents, Swarms, Cross-Chain operations, Trading Strategies,
 * and System Configuration within the JuliaOS framework.
 *
 * Modified to use an existing Julia server to avoid initialization issues.
 */

// =============================================================================
// Imports and Setup
// =============================================================================
const inquirer = require('inquirer');
const chalk = require('chalk');
const figlet = require('figlet');
const ora = require('ora');
const fs = require('fs-extra');
const path = require('path');
const os = require('os');
const { fileURLToPath } = require('url');
const { dirname } = require('path');
const dotenv = require('dotenv');
const { exec } = require('child_process');
const { promisify } = require('util');
const { JuliaBridge } = require('../packages/julia-bridge/dist/index');
const { WalletManager } = require('../packages/wallets/src/index');
const { v4: uuidv4 } = require('uuid'); // Added for generating unique IDs

const execAsync = promisify(exec);

// Initialize the JuliaBridge and WalletManager with useExistingServer=true
let juliaBridge;
try {
    juliaBridge = new JuliaBridge({
        apiUrl: 'http://localhost:8052/api/command',
        useWebSocket: false,
        useExistingServer: true  // Modified to use existing server
    });
} catch (error) {
    console.error(chalk.red('Failed to initialize JuliaBridge:'), error.message);
}

const walletManager = new WalletManager();

// =============================================================================
// System Initialization (simplified)
// =============================================================================
async function initializeSystem() {
    try {
        // Load environment variables
        dotenv.config();

        // Set default environment variables if not set
        process.env.JULIA_HOME = process.env.JULIA_HOME || '/usr/local/bin/julia';
        process.env.JULIA_NUM_THREADS = process.env.JULIA_NUM_THREADS || '4';
        process.env.JULIA_DEPOT_PATH = process.env.JULIA_DEPOT_PATH || path.join(os.homedir(), '.julia');

        // Initialize Julia bridge with existing server flag
        juliaBridge.initialized = true; // Skip initialization
        
        // Create necessary directories
        const configDir = path.join(os.homedir(), '.juliaos');
        const dataDir = path.join(configDir, 'data');
        const logsDir = path.join(configDir, 'logs');

        await fs.ensureDir(configDir);
        await fs.ensureDir(dataDir);
        await fs.ensureDir(logsDir);

        // Create or load settings file
        const settingsFile = path.join(configDir, 'settings.json');
        let settings = {};

        if (await fs.pathExists(settingsFile)) {
            settings = await fs.readJson(settingsFile);
        } else {
            settings = {
                performance: {
                    cpuLimit: 80,
                    memoryLimit: 2048,
                    threads: 4
                },
                security: {
                    encryption: 'medium',
                    authentication: 'password',
                    firewall: 'basic'
                },
                network: {
                    proxy: '',
                    dns: '8.8.8.8',
                    timeout: 30
                },
                storage: {
                    path: dataDir,
                    quota: 10,
                    backup: 'daily'
                }
            };
            await fs.writeJson(settingsFile, settings, { spaces: 2 });
        }

        return settings;
    } catch (error) {
        throw new Error(`Failed to initialize system: ${error.message}`);
    }
}

// =============================================================================
// Main
// =============================================================================
async function main() {
    try {
        // Display ASCII art header
        displayHeader();

        // Initialize system (simplified to use existing server)
        const spinner = ora('Initializing system...').start();
        await initializeSystem();
        spinner.succeed('System initialized (using existing server)');

        // Start main menu directly without running system checks
        await mainMenu();
    } catch (error) {
        console.error(chalk.red('Fatal error:'), error.message);
        process.exit(1);
    }
}

// Start the application
main();

// Include the rest of the original file's functions below
// =============================================================================
// Wallet Management Functions
// =============================================================================
async function connectWallet() {
    try {
        // First, choose the connection mode
        const { mode } = await inquirer.prompt([
            {
                type: 'list',
                name: 'mode',
                message: 'Select wallet connection mode:',
                choices: ['Address Only (Read-only)', 'Private Key (Full Access)']
            }
        ]);
        
        // Then, choose the chain
        const { chain } = await inquirer.prompt([
            {
                type: 'list',
                name: 'chain',
                message: 'Select blockchain:',
                choices: ['ethereum', 'polygon', 'solana', 'arbitrum', 'optimism', 'base', 'bsc']
            }
        ]);
        
        if (mode === 'Address Only (Read-only)') {
            // Get the address from the user
            let address = '';
            let isValid = false;
            
            while (!isValid) {
                const response = await inquirer.prompt([
                    {
                        type: 'input',
                        name: 'address',
                        message: 'Enter your wallet address:',
                    }
                ]);
                
                address = response.address.trim();
                
                if (address === '') {
                    console.log(chalk.red('Address cannot be empty. Please try again.'));
                    continue;
                }
                
                // Simplified validation for this test
                isValid = true;
            }
            
            console.log(chalk.blue('Connecting to wallet in read-only mode...'));
            
            // Connect with validated address
            const state = {
                isConnected: true,
                address: address,
                chain: chain,
                balance: 'N/A', // We don't fetch balance in read-only mode without API
                readOnly: true
            };
            
            // Store in walletManager
            walletManager.state = state;
            
            console.log(chalk.green('Wallet connected successfully in read-only mode!'));
            console.log(chalk.cyan('Address:'), state.address);
            console.log(chalk.cyan('Chain:'), state.chain);
            
            // Add a pause to let the user see the connection info
            await inquirer.prompt([{
                type: 'input',
                name: 'continue',
                message: 'Press Enter to continue...'
            }]);
            
            return state;
        } else {
            // Simplified private key handling for testing
            console.log(chalk.yellow('Private key mode is disabled in this test version'));
            return null;
        }
    } catch (error) {
        console.error(chalk.red('Failed to connect wallet:'), error.message);
        return null;
    }
}

// =============================================================================
// Main Menu
// =============================================================================
async function mainMenu() {
    displayHeader();
    while (true) {
        console.clear();
        displayHeader();
        await displayStatus();

        const { action } = await inquirer.prompt([
            {
                type: 'list',
                name: 'action',
                message: 'Select an action:',
                choices: [
                    'Cross-Chain Hub',
                    'Exit'
                ]
            }
        ]);

        switch (action) {
            case 'Cross-Chain Hub':
                await crossChainHubMenu();
                break;
            case 'Exit':
                console.log(chalk.green('Goodbye!'));
                process.exit(0);
                break;
        }
    }
}

// =============================================================================
// Display Functions
// =============================================================================
function displayHeader() {
    console.log(chalk.cyan(`
     ╔═══════════════════════════════════════════════════════════════╗
     ║                                                               ║
     ║          ██╗██████╗   ██████╗ ███████╗                        ║ 
     ║          ██║╚════██╗ ██╔═══██╗██╔════╝                        ║    
     ║          ██║ █████╔╝ ██║   ██║███████╗                        ║
     ║       ██ ██║ ╚═══██╗ ██║   ██║╚════██║                        ║
     ║         ████║██████╔╝╚██████╔╝███████║                        ║
     ║          ╚╝╚═╝╚═════╝  ╚═════╝ ╚═════╝                        ║
     ║                                                               ║
     ║                   JuliaOS J3OS Mode v1.0                      ║
     ║                                                               ║
     ╚═══════════════════════════════════════════════════════════════╝
`));
}

async function displayStatus() {
    const juliaStatus = await checkJulia();
    const walletStatus = await checkWallet();

    console.log(chalk.cyan('\nSystem Status:'));
    console.log(chalk.white('Julia Engine:'), juliaStatus);
    console.log(chalk.white('Wallet Status:'), walletStatus);
    console.log();
}

// =============================================================================
// System Check Functions
// =============================================================================
async function checkJulia() {
    try {
        const health = await fetch('http://localhost:8052/health').then(res => res.json());
        return health.status === 'healthy' || health.status === 'ok' ? chalk.green('Active ✅') : chalk.red('Inactive ❌');
    } catch (error) {
        return chalk.red('Error ❌');
    }
}

async function checkWallet() {
    const state = walletManager.getState ? walletManager.getState() : {};
    if (state && state.isConnected) {
        const mode = state.readOnly ? 'Read-only' : 'Full Access';
        return chalk.green(`Connected (${state.chain}) [${mode}] ✅`);
    }
    return chalk.yellow('Disconnected ⚠️');
}

async function crossChainHubMenu() {
    const state = walletManager.getState ? walletManager.getState() : {};
    const walletStatus = state && state.isConnected 
        ? `${state.address} (${state.chain}) [${state.readOnly ? 'Read-only' : 'Full Access'}]` 
        : 'Not connected';
        
    console.log(chalk.cyan('\nWallet Status:'), walletStatus);
    
    const choices = [
        'Connect Wallet',
        ...(state && state.isConnected ? [
            'Disconnect Wallet'
        ] : []),
        'Back'
    ];
    
    const { action } = await inquirer.prompt([
        {
            type: 'list',
            name: 'action',
            message: 'Cross-Chain Hub:',
            choices
        }
    ]);

    switch (action) {
        case 'Connect Wallet':
            await connectWallet();
            break;
        case 'Disconnect Wallet':
            // Simplified disconnect
            walletManager.state = {
                isConnected: false,
                address: null,
                chain: null
            };
            console.log(chalk.green('Wallet disconnected successfully!'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            break;
    }
} 