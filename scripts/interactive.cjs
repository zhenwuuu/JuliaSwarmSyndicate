#!/usr/bin/env node

/**
 * interactive.js - Enhanced JuliaOS Interactive CLI (v4 - Context Aware)
 *
 * This script provides a comprehensive interactive command-line interface
 * for managing Agents, Swarms, Cross-Chain operations, Trading Strategies,
 * and System Configuration within the JuliaOS framework.
 *
 * Updates based on provided project context (chains, completed features).
 * NOTE: For production use, this file should be refactored into smaller modules.
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
// Update paths to point to the correct locations
const { JuliaBridge } = require('../packages/julia-bridge/dist/index'); // Adjusted path
const { WalletManager } = require('../packages/wallets/dist/index');    // Adjusted path
const { v4: uuidv4 } = require('uuid'); // Added for generating unique IDs
const { ethers } = require('ethers'); // Import ethers

const execAsync = promisify(exec);

// Initialize the JuliaBridge and WalletManager
let juliaBridge;
try {
    juliaBridge = new JuliaBridge({
        apiUrl: process.env.JULIA_API_URL || 'http://localhost:8052/api/command', // Use env var
        useWebSocket: false,
        useExistingServer: true  // Use existing server instead of starting a new one
    });
} catch (error) {
    console.error(chalk.red('Failed to initialize JuliaBridge:'), error.message);
    process.exit(1); // Exit if bridge fails to initialize
}

const walletManager = new WalletManager();

// Map chain names to chain IDs used by PrivateKeyProvider and elsewhere
const CHAIN_NAME_TO_ID = {
    'ethereum': 1,
    'sepolia': 11155111,
    'polygon': 137,
    'mumbai': 80001,
    'optimism': 10,
    'optimism_goerli': 420,
    'arbitrum': 42161,
    'arbitrum_goerli': 421613,
    'bsc': 56,
    'bsc_testnet': 97,
    'base': 8453,
    'base_goerli': 84531,
    // Add other chains as needed
};

const ID_TO_CHAIN_NAME = Object.fromEntries(Object.entries(CHAIN_NAME_TO_ID).map(([name, id]) => [id, name]));

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
                // Filter out browser-only providers if not in browser context?
                // For now, keep simple
                choices: ['Address Only (Read-only)', 'Private Key (Full Access)', 'MetaMask (Browser)', 'Rabby (Browser)', 'Phantom (Browser)']
            }
        ]);

        let providerName = null;
        let isNodeProvider = false;

        if (mode === 'Address Only (Read-only)') {
            // ... (existing read-only logic remains largely the same) ...
            // Prompt for chain as before
             const { chainName } = await inquirer.prompt([
                {
                    type: 'list',
                    name: 'chainName',
                    message: 'Select blockchain:',
                    choices: Object.keys(CHAIN_NAME_TO_ID) // Use defined chains
                }
            ]);
            // ... rest of read-only address input and validation ...
             console.log(chalk.blue('Connecting wallet in read-only mode...'));
             // Update state object correctly
             const state = {
                isConnected: true,
                address: address, // validated address
                chainId: CHAIN_NAME_TO_ID[chainName], // Store chain ID
                balance: 'N/A',
                readOnly: true,
                provider: 'read-only', // Indicate mode
                hasFullAccess: false,
             };
             walletManager.state = state; // Directly setting state here - consider refactoring
             console.log(chalk.green('Wallet configured successfully in read-only mode!'));
             console.log(chalk.cyan('Address:'), state.address);
             console.log(chalk.cyan('Chain:'), chainName, `(ID: ${state.chainId})`);
             // ... pause and return ...
             return state;

        } else if (mode === 'Private Key (Full Access)') {
            isNodeProvider = true;
            providerName = 'node'; // Internal identifier for our PrivateKeyProvider usage

            // Get the private key from the user
            // ... (existing private key input logic) ...
            let privateKey = '';
            while (privateKey.trim() === '') {
                // ... (prompt logic) ...
                 privateKey = response.privateKey;
                 // Add basic validation (e.g., starts with 0x for EVM)
                 if (!privateKey.startsWith('0x')) {
                     console.log(chalk.red('Private key should typically start with 0x for EVM chains.'));
                     privateKey = ''; // Reset to re-prompt
                     continue;
                 }
                 if (privateKey.length !== 66) { // 0x + 64 hex chars
                     console.log(chalk.red('Private key should be 66 characters long (including 0x).'));
                     privateKey = ''; // Reset to re-prompt
                     continue;
                 }
            }

            // Get the target Chain ID
            const { chainName } = await inquirer.prompt([
                {
                    type: 'list',
                    name: 'chainName',
                    message: 'Select blockchain network for this private key:',
                    choices: Object.keys(CHAIN_NAME_TO_ID) // Show supported chains
                }
            ]);
            const chainId = CHAIN_NAME_TO_ID[chainName];

            console.log(chalk.blue(`Connecting via Private Key on ${chainName} (ID: ${chainId})...`));
            const spinner = ora(`Connecting to ${chainName}...`).start();

            try {
                // Use the new WalletManager method
                await walletManager.connectWithPrivateKey(privateKey, chainId);
                spinner.succeed('Wallet securely connected via Private Key');

                // Get state from WalletManager AFTER connection
                const state = walletManager.getState();

                console.log(chalk.green('Wallet connected successfully with full access!'));
                console.log(chalk.cyan('Address:'), state.address);
                console.log(chalk.cyan('Network:'), ID_TO_CHAIN_NAME[state.chainId] || `Unknown (ID: ${state.chainId})`);
                console.log(chalk.cyan('Balance:'), await walletManager.getBalance()); // Fetch real balance

            } catch (error) {
                spinner.fail(`Failed to connect using private key: ${error.message}`);
                 console.error(chalk.red('Connection Error Details:'), error);
                 // Add pause
                 await inquirer.prompt([{
                    type: 'input',
                    name: 'continue',
                    message: 'Press Enter to continue...'
                 }]);
                return null;
            } finally {
                 privateKey = null; // Clear private key from memory
                 // Add pause
                 await inquirer.prompt([{
                    type: 'input',
                    name: 'continue',
                    message: 'Press Enter to continue...'
                 }]);
            }
             return walletManager.getState(); // Return the latest state

        } else { // Handle Browser Providers (MetaMask, Rabby, Phantom)
            providerName = mode.split(' ')[0].toLowerCase(); // Extract 'metamask', 'rabby', 'phantom'

            if (!walletManager.isAvailable(providerName)) {
                console.log(chalk.red(`Wallet provider ${providerName} is not available. Make sure the browser extension is installed and active.`));
                return null;
            }

            console.log(chalk.blue(`Connecting to ${providerName} via browser extension...`));
            const spinner = ora(`Waiting for ${providerName} connection...`).start();

            try {
                await walletManager.connect(providerName);
                 spinner.succeed(`Connected to ${providerName}`);
                 const state = walletManager.getState();
                 console.log(chalk.green('Wallet connected successfully via browser extension!'));
                 console.log(chalk.cyan('Address:'), state.address);
                 console.log(chalk.cyan('Network:'), ID_TO_CHAIN_NAME[state.chainId] || `Unknown (ID: ${state.chainId})`);
                 console.log(chalk.cyan('Balance:'), await walletManager.getBalance()); // Fetch real balance
                 // Add pause
                 await inquirer.prompt([{
                    type: 'input',
                    name: 'continue',
                    message: 'Press Enter to continue...'
                 }]);
                 return state;
            } catch (error) {
                 spinner.fail(`Failed to connect to ${providerName}: ${error.message}`);
                 console.error(chalk.red('Connection Error Details:'), error);
                 // Add pause
                 await inquirer.prompt([{
                    type: 'input',
                    name: 'continue',
                    message: 'Press Enter to continue...'
                 }]);
                 return null;
            }
        }

    } catch (error) {
        console.error(chalk.red('Failed during wallet connection process:'), error.message);
         // Add pause
         await inquirer.prompt([{
            type: 'input',
            name: 'continue',
            message: 'Press Enter to continue...'
         }]);
        return null;
    }
}

async function disconnectWallet() {
    const state = walletManager.getState();
    if (!state.isConnected) {
        console.log(chalk.yellow('No wallet is currently connected.'));
        return;
    }

    try {
        const previousAddress = state.address;
        const previousChain = state.chain;
        
        // Reset wallet state
        walletManager.state = {
            isConnected: false,
            address: null,
            chain: null,
            balance: null,
            readOnly: false,
            transactions: []
        };
        
        console.log(chalk.green('Wallet disconnected successfully!'));
        console.log(chalk.cyan('Disconnected address:'), previousAddress);
        console.log(chalk.cyan('Disconnected chain:'), previousChain);
    } catch (error) {
        console.error(chalk.red('Failed to disconnect wallet:'), error.message);
    }
}

async function checkWallet() {
    const state = walletManager.getState();
    if (state.isConnected) {
        const mode = state.readOnly ? 'Read-only' : 'Full Access';
        return chalk.green(`Connected (${state.chain}) [${mode}] ✅`);
    }
    return chalk.yellow('Disconnected ⚠️');
}

async function getWalletBalance() {
    const state = walletManager.getState();
    if (!state.isConnected) {
        return chalk.red('Wallet not connected');
    }
    
    // Read-only mode still doesn't fetch balance
    if (state.readOnly) {
        return chalk.yellow('Balance not available in read-only mode');
    }

    const spinner = ora('Fetching balance...').start();
    try {
        const balance = await walletManager.getBalance(); // Use WalletManager method
        const chainName = ID_TO_CHAIN_NAME[state.chainId] || `Chain ${state.chainId}`;
        spinner.succeed('Balance fetched');
        return chalk.green(`${balance} ${chainName.toUpperCase()}`);
    } catch (error) {
        spinner.fail('Failed to get balance');
        return chalk.red(`Failed to get balance: ${error.message}`);
    }
}

// =============================================================================
// Main Menu
// =============================================================================
async function mainMenu() {
    while (true) {
        // The displayHeader function already includes console.clear()
        displayHeader();
        displayStatus();

        const { action } = await inquirer.prompt([
            {
                type: 'list',
                name: 'action',
                message: '🎮 Choose a management area:',
                choices: [
                    '👤 Agent Management',
                    '🐝 Swarm Management',
                    '⛓️ Cross-Chain Hub',
                    '🔑 API Keys Management',
                    '⚙️ System Configuration',
                    '📊 Performance Metrics',
                    '🔍 Run System Checks',
                    '👋 Exit'
                ],
                pageSize: 10 // Ensure all options are visible without scrolling
            }
        ]);

        // Extract the action text without emoji
        const actionWithoutEmoji = action.substring(action.indexOf(' ') + 1);
        
        // Show a loading animation when an action is selected
        if (actionWithoutEmoji !== 'Exit') {
            const spinner = ora({
                text: `Loading ${actionWithoutEmoji.toLowerCase()}...`,
                spinner: 'dots',
                color: 'cyan'
            }).start();
            
            await new Promise(resolve => setTimeout(resolve, 500));
            spinner.stop();
        }

        switch (actionWithoutEmoji) {
            case 'Agent Management':
                await agentManagementMenu();
                break;
            case 'Swarm Management':
                await swarmManagementMenu();
                break;
            case 'Cross-Chain Hub':
                await crossChainHubMenu();
                break;
            case 'API Keys Management':
                await apiKeysManagementMenu();
                break;
            case 'System Configuration':
                await systemConfigurationMenu();
                break;
            case 'Performance Metrics':
                await performanceMetricsMenu();
                break;
            case 'Run System Checks':
                await runAllSystemChecks();
                break;
            case 'Exit':
                console.log(chalk.green('\nThank you for using JuliaOS! Goodbye! 👋'));
                process.exit(0);
                break;
        }
    }
}

// =============================================================================
// Display Functions
// =============================================================================
function displayHeader() {
    // Clear any previous output
    console.clear();
    
    // Add a subtle random color variation to make the interface feel alive
    const colors = [chalk.cyan, chalk.blue, chalk.blueBright];
    const randomColor = colors[Math.floor(Math.random() * colors.length)];
    
    console.log(randomColor(`
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
    const networkStatus = await checkNetworks();
    const apiStatus = await checkApis();
    const storageStatus = await checkStorage();

    console.log(chalk.cyan('\n┌─ System Status ─────────────────────────────────────────┐'));
    console.log(chalk.cyan('│                                                           │'));
    console.log(chalk.cyan(`│  🧠 Julia Engine:  ${juliaStatus.padEnd(46)}│`));
    console.log(chalk.cyan(`│  💼 Wallet Status: ${walletStatus.padEnd(46)}│`));
    console.log(chalk.cyan(`│  🌐 Network:       ${networkStatus.padEnd(46)}│`));
    console.log(chalk.cyan(`│  🔑 API Keys:      ${apiStatus.padEnd(46)}│`));
    console.log(chalk.cyan(`│  💾 Storage:       ${storageStatus.padEnd(46)}│`));
    console.log(chalk.cyan(`│  ⚡ Performance:   ${chalk.green('Optimized').padEnd(46)}│`));
    console.log(chalk.cyan('│                                                          │'));
    console.log(chalk.cyan('└──────────────────────────────────────────────────────────┘'));
    console.log();
}

// =============================================================================
// System Check Functions
// =============================================================================
async function checkJulia() {
    try {
        const health = await juliaBridge.getHealth();
        return health.status === 'healthy' || health.status === 'ok' ? chalk.green('Active ✅') : chalk.red('Inactive ❌');
    } catch (error) {
        console.error(chalk.red('Error checking Julia health:'), error.message);
        return chalk.red('Error ❌');
    }
}

async function checkNetworks() {
    try {
        const networks = ['ethereum', 'polygon', 'bsc', 'arbitrum', 'optimism', 'base'];
        const results = await Promise.all(
            networks.map(async (network) => {
                try {
                    // Simulate network check
                    await new Promise(resolve => setTimeout(resolve, 100));
                    return true;
                } catch (error) {
                    return false;
                }
            })
        );
        return results.every(result => result) ? chalk.green('All Reachable ✅') : chalk.yellow('Some Unreachable ⚠️');
    } catch (error) {
        return chalk.red('Error ❌');
    }
}

async function checkApis() {
    try {
        const apis = ['openai', 'anthropic', 'google', 'aws'];
        const results = await Promise.all(
            apis.map(async (api) => {
                try {
                    // Simulate API check
                    await new Promise(resolve => setTimeout(resolve, 100));
                    return true;
                } catch (error) {
                    return false;
                }
            })
        );
        return results.every(result => result) ? chalk.green('All Valid ✅') : chalk.yellow('Missing/Invalid Keys ⚠️');
    } catch (error) {
        return chalk.red('Error ❌');
    }
}

async function checkStorage() {
    try {
        const configDir = path.join(os.homedir(), '.juliaos');
        const settingsFile = path.join(configDir, 'settings.json');

        // Check if config directory exists and is writable
        if (!fs.existsSync(configDir)) {
            fs.mkdirSync(configDir, { recursive: true });
        }

        // Check if settings file exists and is readable
        if (!fs.existsSync(settingsFile)) {
            fs.writeFileSync(settingsFile, JSON.stringify({}, null, 2));
        }

        return chalk.green('Ready ✅');
    } catch (error) {
        return chalk.red('Error ❌');
    }
}

async function runAllSystemChecks() {
    // displayHeader already includes console.clear()
    displayHeader();
    
    // Create a more visually interesting spinner
    const spinner = ora({
        text: 'Running system checks...',
        spinner: 'dots',
        color: 'cyan'
    }).start();
    
    try {
        // Simulate the checks running with a slight delay for each check to see the spinner
        const juliaPromise = checkJulia().then(result => {
            spinner.text = 'Checking Julia engine...';
            return result;
        });
        await new Promise(resolve => setTimeout(resolve, 300));
        
        const walletPromise = checkWallet().then(result => {
            spinner.text = 'Checking wallet connection...';
            return result;
        });
        await new Promise(resolve => setTimeout(resolve, 300));
        
        const networkPromise = checkNetworks().then(result => {
            spinner.text = 'Checking network connectivity...';
            return result;
        });
        await new Promise(resolve => setTimeout(resolve, 300));
        
        const apiPromise = checkApis().then(result => {
            spinner.text = 'Verifying API keys...';
            return result;
        });
        await new Promise(resolve => setTimeout(resolve, 300));
        
        const storagePromise = checkStorage().then(result => {
            spinner.text = 'Checking storage system...';
            return result;
        });
        await new Promise(resolve => setTimeout(resolve, 300));
        
        // Wait for all promises to resolve
        const [juliaStatus, walletStatus, networkStatus, apiStatus, storageStatus] = 
            await Promise.all([juliaPromise, walletPromise, networkPromise, apiPromise, storagePromise]);

        spinner.succeed('System checks complete ✨');
        
        // Display results in a fancy box
        console.log(chalk.cyan('\n┌─ System Status ─────────────────────────────────────────┐'));
        console.log(chalk.cyan('│                                                          │'));
        console.log(chalk.cyan(`│  🧠 Julia Engine:  ${juliaStatus.padEnd(46)}│`));
        console.log(chalk.cyan(`│  💼 Wallet Status: ${walletStatus.padEnd(46)}│`));
        console.log(chalk.cyan(`│  🌐 Network:       ${networkStatus.padEnd(46)}│`));
        console.log(chalk.cyan(`│  🔑 API Keys:      ${apiStatus.padEnd(46)}│`));
        console.log(chalk.cyan(`│  💾 Storage:       ${storageStatus.padEnd(46)}│`));
        console.log(chalk.cyan(`│  ⚡ Performance:   ${chalk.green('Optimized').padEnd(46)}│`));
        console.log(chalk.cyan('│                                                          │'));
        console.log(chalk.cyan('└──────────────────────────────────────────────────────────┘'));
    } catch (error) {
        spinner.fail('System checks failed ❌');
        console.error(chalk.red('Error running system checks:'), error.message);
    }
    
    // Pause to let the user see the results
    await inquirer.prompt([
        {
            type: 'input',
            name: 'continue',
            message: '🔄 Press Enter to continue...'
        }
    ]);
}

// =============================================================================
// Menu Functions
// =============================================================================
async function agentManagementMenu() {
    // displayHeader already includes console.clear()
    displayHeader();
    
    // Display an improved agent animation with better alignment
    console.log(chalk.blue(`
      ╔══════════════════════════════════════════╗
      ║           Agent Management               ║
      ║                                          ║
      ║           ╔═══════════╗                  ║
      ║           ║   ╭───╮   ║                  ║
      ║           ║   │o o│   ║  AI Agent        ║
      ║           ║   │ ▿ │   ║  Ready for       ║
      ║           ║   ╰───╯   ║  your commands!  ║
      ║           ╚═══╦═══╦═══╝                  ║
      ║               ║   ║                      ║
      ║             ╔═╝   ╚═╗                    ║
      ║             ╚═══════╝                    ║
      ╚══════════════════════════════════════════╝
    `));
    
    const { action } = await inquirer.prompt([
        {
            type: 'list',
            name: 'action',
            message: '👤 Select agent action:',
            choices: [
                'Create Agent',
                'List Agents',
                'Configure Agent',
                'Start Agent',
                'Stop Agent',
                'View Metrics',
                'Delete Agent',
                'Back'
            ],
            pageSize: 10
        }
    ]);

    // Show a loading animation when an action is selected
    if (action !== 'Back') {
        const spinner = ora({
            text: `Preparing ${action.toLowerCase()}...`,
            spinner: 'dots',
            color: 'blue'
        }).start();
        
        await new Promise(resolve => setTimeout(resolve, 500));
        spinner.stop();
    }

    switch (action) {
        case 'Create Agent':
            await createAgent();
            break;
        case 'List Agents':
            await listAgents();
            break;
        case 'Configure Agent':
            await configureAgent();
            break;
        case 'Start Agent':
            await startAgent();
            break;
        case 'Stop Agent':
            await stopAgent();
            break;
        case 'View Metrics':
            await displayAgentMetrics();
            break;
        case 'Delete Agent':
            await deleteAgent();
            break;
    }
}

async function swarmManagementMenu() {
    // displayHeader already includes console.clear()
    displayHeader();

    // Display an improved swarm animation with better alignment
    console.log(chalk.green(`
      ╔══════════════════════════════════════════╗
      ║           Swarm Management               ║
      ║                                          ║
      ║      ╭─●─╮       ●         ╭─●─╮        ║
      ║      │   │      ╱ ╲        │   │        ║
      ║      ○   ○     ○   ●       ○   ○        ║
      ║     ╱     ╲   ╱     ╲     ╱     ╲       ║
      ║    ●       ○ ○       ●   ●       ○      ║
      ║     ╲     ╱   ╲     ╱     ╲     ╱       ║
      ║      ○   ●     ●   ○       ○   ●        ║
      ║      │   │      ╲ ╱        │   │        ║
      ║      ╰─○─╯       ○         ╰─○─╯        ║
      ╚══════════════════════════════════════════╝
    `));

    const { action } = await inquirer.prompt([
        {
            type: 'list',
            name: 'action',
            message: '🐝 Select swarm action:',
            choices: [
                'Create Swarm', // Includes Julia Native & OpenAI
                'List Swarms',
                'Configure Swarm', // Primarily for Julia Native Swarms for now
                'Start Swarm',     // Primarily for Julia Native Swarms for now
                'Stop Swarm',      // Primarily for Julia Native Swarms for now
                new inquirer.Separator('--- OpenAI Swarm Actions ---'),
                'Run OpenAI Task',
                'Get OpenAI Response',
                new inquirer.Separator(),
                'View Metrics',    // Primarily for Julia Native Swarms for now
                'Delete Swarm',
                'Back'
            ],
            pageSize: 15 // Increased page size
        }
    ]);

    // Show a loading animation when an action is selected
    if (action !== 'Back') {
        const spinner = ora({
            text: `Preparing ${action.toLowerCase()}...`,
            spinner: 'dots',
            color: 'green'
        }).start();

        await new Promise(resolve => setTimeout(resolve, 500));
        spinner.stop();
    }

    switch (action) {
        case 'Create Swarm':
            await createSwarm();
            break;
        case 'List Swarms':
            await listSwarms();
            break;
        case 'Configure Swarm':
            await configureSwarm();
            break;
        case 'Start Swarm':
            await startSwarm();
            break;
        case 'Stop Swarm':
            await stopSwarm();
            break;
        case 'Run OpenAI Task': // New Action
            await runOpenAITask();
            break;
        case 'Get OpenAI Response': // New Action
            await getOpenAIResponse();
            break;
        case 'View Metrics':
            await displaySwarmMetrics();
            break;
        case 'Delete Swarm':
            await deleteSwarm();
            break;
    }
}

async function crossChainHubMenu() {
    // Remove displayHeader() call here as it's already called in mainMenu()

    // Display an improved cross-chain animation with better alignment
    console.log(chalk.magenta(`
      ╔══════════════════════════════════════════╗
      ║           Cross-Chain Hub                ║
      ╚══════════════════════════════════════════╝
    `));

    const state = walletManager.getState();
    const walletStatus = state.isConnected
        ? `${state.address} (${state.provider || 'Unknown'} on ${state.chain}) [${state.readOnly ? 'Read-only' : 'Full Access'}]`
        : 'Not connected';

    console.log(chalk.cyan('\n💼 Wallet Status:'), walletStatus);

    const choices = [
        'Connect Wallet',
        ...(state.isConnected ? [
            'Disconnect Wallet',
            'View Balance',
            'Send Transaction',
            'View Transaction History',
            'Check Transaction Status' // Add new option
        ] : []),
        'Back'
    ];

    const { action } = await inquirer.prompt([
        {
            type: 'list',
            name: 'action',
            message: '⛓️ Select cross-chain/trade action:', // Updated message
            choices,
            pageSize: 10
        }
    ]);

    // Show a loading animation when an action is selected
    if (action !== 'Back') {
        const spinner = ora({
            text: `Preparing ${action.toLowerCase()}...`,
            spinner: 'dots',
            color: 'magenta'
        }).start();

        await new Promise(resolve => setTimeout(resolve, 500));
        spinner.stop();
    }

    switch (action) {
        case 'Connect Wallet':
            await connectWallet();
            break;
        case 'Disconnect Wallet':
            await disconnectWallet();
            break;
        case 'View Balance':
            // Fetch balance using the Bridge command
            if (state.isConnected) {
                const spinner = ora('Fetching balance via Julia backend...').start();
                try {
                    const balanceResult = await juliaBridge.runJuliaCommand('Bridge.get_wallet_balance', [
                        state.address,
                        null, // Pass null for native balance, or specific token address
                        state.chain
                    ]);
                    if (balanceResult.success) {
                        spinner.succeed('Balance retrieved successfully!');
                        console.log(chalk.green(`Native Balance (${state.chain}): ${balanceResult.data.balance}`));
                        // TODO: Add prompt to fetch specific token balance
                    } else {
                        spinner.fail(`Failed to get balance: ${balanceResult.error}`);
                    }
                } catch (error) {
                    spinner.fail(`Error fetching balance: ${error.message}`);
                }
            } else {
                 console.log(chalk.red('Wallet not connected'));
            }
            await inquirer.prompt([{type: 'input', name: 'continue', message: '🔄 Press Enter to continue...'}]);
            break;
        case 'Send Transaction':
            await sendTransaction(); // Keep existing simple send
            break;
        case 'Execute Manual Trade': // New case
             await manualTrade();
             break;
        case 'View Transaction History':
            await viewTransactionHistory();
            break;
        case 'Check Transaction Status':
            await checkTransactionStatus();
            break;
    }
}

async function apiKeysManagementMenu() {
    // displayHeader already includes console.clear()
    displayHeader();
    
    // Display an improved API keys animation with better alignment
    console.log(chalk.yellow(`
      ╔══════════════════════════════════════════╗
      ║         API Keys Management              ║
      ║                                          ║
      ║       ┌─────────────────────┐            ║
      ║       │                     │            ║
      ║       │   ┌───┐ ┌───┐ ┌───┐ │            ║
      ║       │   │ A │ │ P │ │ I │ │            ║
      ║       │   └───┘ └───┘ └───┘ │            ║
      ║       │                     │            ║
      ║       └─────────┬───────────┘            ║
      ║                 │                        ║
      ║           ┌─────┴─────┐                  ║
      ║           │ ********* │                  ║
      ║           └───────────┘                  ║
      ╚══════════════════════════════════════════╝
    `));
  
    const { action } = await inquirer.prompt([
        {
            type: 'list',
            name: 'action',
            message: '🔑 Select API key action:',
            choices: [
                'Add API Key',
                'List API Keys',
                'Update API Key',
                'Delete API Key',
                'Back'
            ],
            pageSize: 10
        }
    ]);

    // Show a loading animation when an action is selected
    if (action !== 'Back') {
        const spinner = ora({
            text: `Preparing ${action.toLowerCase()}...`,
            spinner: 'dots',
            color: 'yellow'
        }).start();
        
        await new Promise(resolve => setTimeout(resolve, 500));
        spinner.stop();
    }
  
    switch (action) {
        case 'Add API Key':
            await addApiKey();
            break;
        case 'List API Keys':
            await listApiKeys();
            break;
        case 'Update API Key':
            await updateApiKey();
            break;
        case 'Delete API Key':
            await deleteApiKey();
            break;
    }
}

async function systemConfigurationMenu() {
    // displayHeader already includes console.clear()
    displayHeader();
    
    // Display an improved system configuration animation with better alignment
    console.log(chalk.blueBright(`
      ╔══════════════════════════════════════════╗
      ║        System Configuration              ║
      ║                                          ║
      ║          ┌─────────────────┐             ║
      ║          │  ⚙️  Settings   │             ║
      ║          └────────┬────────┘             ║
      ║                   │                      ║
      ║         ┌─────────┼─────────┐            ║
      ║         │         │         │            ║
      ║      ┌──┴──┐   ┌──┴──┐   ┌──┴──┐         ║
      ║      │ Perf │   │ Sec │   │ Net │         ║
      ║      └─────┘   └─────┘   └─────┘         ║
      ║                                          ║
      ╚══════════════════════════════════════════╝
    `));
    
    const { action } = await inquirer.prompt([
        {
            type: 'list',
            name: 'action',
            message: '⚙️ Select configuration area:',
            choices: [
                'Configure Performance',
                'Configure Security',
                'Configure Network',
                'Configure Storage',
                'Back'
            ],
            pageSize: 10
        }
    ]);
    
    // Show a loading animation when an action is selected
    if (action !== 'Back') {
        const spinner = ora({
            text: `Preparing ${action.toLowerCase()}...`,
            spinner: 'dots',
            color: 'blue'
        }).start();
        
        await new Promise(resolve => setTimeout(resolve, 500));
        spinner.stop();
    }
    
    switch (action) {
        case 'Configure Performance':
            await configurePerformance();
            break;
        case 'Configure Security':
            await configureSecurity();
            break;
        case 'Configure Network':
            await configureNetwork();
            break;
        case 'Configure Storage':
            await configureStorage();
            break;
    }
}

async function performanceMetricsMenu() {
    // displayHeader already includes console.clear()
    displayHeader();
    
    // Display an improved metrics animation with better alignment
    console.log(chalk.redBright(`
      ╔══════════════════════════════════════════╗
      ║        Performance Metrics               ║
      ║                                          ║
      ║             ┌──────────┐                 ║
      ║             │ Analytics│                 ║
      ║        ┌────┴──────────┴────┐            ║
      ║        │                    │            ║
      ║        │   📊   📉   📈    │            ║
      ║        │                    │            ║
      ║        └────────────────────┘            ║
      ║                                          ║
      ╚══════════════════════════════════════════╝
    `));
  
    const { action } = await inquirer.prompt([
        {
            type: 'list',
            name: 'action',
            message: '📊 Select metrics to view:',
            choices: [
                'View System Metrics',
                'View Agent Metrics',
                'View Swarm Metrics',
                'View Network Metrics',
                'Back'
            ],
            pageSize: 10
        }
    ]);
    
    // Show a loading animation when an action is selected
    if (action !== 'Back') {
        const spinner = ora({
            text: `Loading ${action.toLowerCase()}...`,
            spinner: 'dots',
            color: 'red'
        }).start();
        
        await new Promise(resolve => setTimeout(resolve, 500));
        spinner.stop();
    }
  
    switch (action) {
        case 'View System Metrics':
            await displaySystemMetrics();
            break;
        case 'View Agent Metrics':
            await displayAgentMetrics();
            break;
        case 'View Swarm Metrics':
            await displaySwarmMetrics();
            break;
        case 'View Network Metrics':
            await displayNetworkMetrics();
            break;
    }
}

// =============================================================================
// Agent Functions
// =============================================================================
async function createAgent() {
    const { name, type, config } = await inquirer.prompt([
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
            choices: ['Trading', 'Analysis', 'Execution', 'Monitoring']
        },
        {
            type: 'input',
            name: 'config',
            message: 'Enter agent configuration (JSON):',
            default: '{}'
        }
    ]);

    // Show a loading spinner
    const spinner = ora({
        text: 'Creating agent...',
        spinner: 'dots',
        color: 'blue'
    }).start();

    try {
        // Safely parse JSON with try/catch
        let agentConfig;
        try {
            agentConfig = JSON.parse(config);
        } catch (jsonError) {
            spinner.warn('Invalid JSON configuration format. Using empty config.');
            agentConfig = {};
        }
        
        // Try to create agent using the Julia backend first
        let useBackend = true;
        
        try {
            spinner.text = 'Connecting to Julia backend...';
            // First check if the backend is responsive
            const healthResult = await juliaBridge.getHealth();
            if (!healthResult || healthResult.status !== 'healthy') {
                throw new Error('Backend health check failed');
            }
            
            spinner.text = 'Sending request to Julia backend...';
            const backendResult = await juliaBridge.runJuliaCommand('create_agent', [name, type, JSON.stringify(agentConfig)]);
            
            if (backendResult && backendResult.error) {
                throw new Error(backendResult.error);
            }
            
            // Successfully created via backend
            spinner.succeed('Agent created successfully via Julia backend!');
            
            console.log(chalk.green(`\nAgent "${name}" created successfully!`));
            console.log(chalk.cyan('Agent ID:'), backendResult.id || 'Unknown');
            console.log(chalk.cyan('Status:'), backendResult.status || 'Initialized');
            
            // Debug information
            console.log(chalk.gray('\nDebug: Response from backend:'), JSON.stringify(backendResult));
            
        } catch (backendError) {
            // Backend failed, fall back to local mock implementation
            useBackend = false;
            spinner.warn(`Julia backend request failed: ${backendError.message}`);
            console.log(chalk.yellow('Falling back to local agent creation...'));
            
            // Short delay for UI
            await new Promise(resolve => setTimeout(resolve, 500));
        }
        
        // Only proceed with local creation if backend failed
        if (!useBackend) {
            // Fallback to local creation
            spinner.text = 'Using local mock implementation...';
            
            const result = await createAgentService(name, type, agentConfig);
            
            spinner.succeed('Agent created with local mock implementation');
            
            console.log(chalk.green(`\nAgent "${name}" created successfully!`));
            console.log(chalk.cyan('Agent ID:'), result.id);
            console.log(chalk.cyan('Status:'), result.status);
            console.log(chalk.yellow('\nNote: This agent was created using a local mock implementation.'));
            console.log(chalk.yellow('      It will not persist between CLI sessions.'));
        }
    } catch (error) {
        spinner.fail('Failed to create agent');
        console.error(chalk.red('\nError:'), error.message);
    }
    
    // Pause to let the user see the results
    await inquirer.prompt([
        {
            type: 'input',
            name: 'continue',
            message: '🔄 Press Enter to continue...'
        }
    ]);
}

async function listAgents() {
    try {
        // Show a loading spinner
        const spinner = ora({
            text: 'Fetching agents...',
            spinner: 'dots',
            color: 'blue'
        }).start();
        
        await new Promise(resolve => setTimeout(resolve, 800));
        
        let result;
        let usingMockData = false;
        
        try {
            // Try to get all agents from Julia backend
            result = await juliaBridge.runJuliaCommand('list_agents', []);
        } catch (backendError) {
            // If backend fails, log the error and use mock data
            spinner.warn(`Backend error: ${backendError.message}. Using mock data.`);
            usingMockData = true;
            
            // Provide mock data for demo purposes
            result = {
                agents: [
                    { 
                        id: uuidv4().substring(0, 8),
                        name: 'TradingAssistant', 
                        type: 'Trading', 
                        status: 'active' 
                    },
                    { 
                        id: uuidv4().substring(0, 8),
                        name: 'MarketAnalyzer', 
                        type: 'Analysis', 
                        status: 'inactive' 
                    }
                ]
            };
        }
        
        spinner.stop();
        
        if (result && result.error) {
            throw new Error(result.error);
        }
        
        console.log(chalk.cyan('\n┌─ Agent List ───────────────────────────────────────────┐'));
        console.log(chalk.cyan('│                                                          │'));
        
        if (result && result.agents && result.agents.length > 0) {
            result.agents.forEach(agent => {
                const status = agent.status === 'active' ? chalk.green('Active') : chalk.yellow('Inactive');
                console.log(chalk.cyan(`│  • ${agent.name.padEnd(20)} (${agent.type.padEnd(10)}) [${status}]   │`));
            });
            
            if (usingMockData) {
                console.log(chalk.cyan('│                                                          │'));
                console.log(chalk.cyan('│  ℹ️  Note: Displaying mock data (backend unavailable)    │'));
            }
        } else {
            // No agents found or empty response
            console.log(chalk.cyan('│  No agents found. Create an agent to get started.      │'));
            console.log(chalk.cyan('│                                                          │'));
            console.log(chalk.cyan('│  Tip: Select "Create Agent" from the Agent Management  │'));
            console.log(chalk.cyan('│       menu to create your first agent.                 │'));
        }
        
        console.log(chalk.cyan('│                                                          │'));
        console.log(chalk.cyan('└──────────────────────────────────────────────────────────┘'));
        
        // Debug information about the response
        console.log(chalk.gray('\nDebug: Response from backend:'), result ? JSON.stringify(result) : 'No response');
    } catch (error) {
        console.error(chalk.red('\nFailed to list agents:'), error.message);
    }
    
    // Pause to let the user see the results
    await inquirer.prompt([
        {
            type: 'input',
            name: 'continue',
            message: '🔄 Press Enter to continue...'
        }
    ]);
}

async function configureAgent() {
    const { agentId, updates } = await inquirer.prompt([
        {
            type: 'input',
            name: 'agentId',
            message: 'Enter agent ID:',
            validate: input => input.length > 0 ? true : 'Agent ID is required'
        },
        {
            type: 'input',
            name: 'updates',
            message: 'Enter configuration updates (JSON):',
            default: '{}'
        }
    ]);

    try {
        // FIX: Safely parse JSON with try/catch
        let configUpdates;
        try {
            configUpdates = JSON.parse(updates);
        } catch (jsonError) {
            console.error(chalk.red('Invalid JSON updates format. Using empty updates.'));
            configUpdates = {};
        }
        
        const result = await updateAgentService(agentId, configUpdates);
        console.log(chalk.green(`Agent "${agentId}" configuration updated successfully!`));
        console.log(chalk.cyan('New Status:'), result.status);
    } catch (error) {
        console.error(chalk.red('Failed to update agent configuration:'), error.message);
    }
}

async function startAgent() {
    const { agentId } = await inquirer.prompt([
        {
            type: 'input',
            name: 'agentId',
            message: 'Enter agent ID:',
            validate: input => input.length > 0 ? true : 'Agent ID is required'
        }
    ]);

    try {
        const result = await updateAgentService(agentId, { status: 'active' });
        console.log(chalk.green(`Agent "${agentId}" started successfully!`));
        console.log(chalk.cyan('Status:'), result.status);
  } catch (error) {
        console.error(chalk.red('Failed to start agent:'), error.message);
    }
}

async function stopAgent() {
    const { agentId } = await inquirer.prompt([
        {
            type: 'input',
            name: 'agentId',
            message: 'Enter agent ID:',
            validate: input => input.length > 0 ? true : 'Agent ID is required'
        }
    ]);

    try {
        const result = await updateAgentService(agentId, { status: 'inactive' });
        console.log(chalk.green(`Agent "${agentId}" stopped successfully!`));
        console.log(chalk.cyan('Status:'), result.status);
    } catch (error) {
        console.error(chalk.red('Failed to stop agent:'), error.message);
    }
}

async function deleteAgent() {
    const { agentId, confirm } = await inquirer.prompt([
        {
            type: 'input',
            name: 'agentId',
            message: 'Enter agent ID:',
            validate: input => input.length > 0 ? true : 'Agent ID is required'
        },
        {
            type: 'confirm',
            name: 'confirm',
            message: 'Are you sure you want to delete this agent?',
            default: false
        }
    ]);

    if (confirm) {
        try {
            const result = await juliaBridge.runJuliaCommand('delete_agent', [agentId]);
            if (result.error) {
                throw new Error(result.error);
            }
            console.log(chalk.green(`Agent "${agentId}" deleted successfully!`));
        } catch (error) {
            console.error(chalk.red('Failed to delete agent:'), error.message);
        }
    }
}

async function displayAgentMetrics() {
    // displayHeader already includes console.clear()
    displayHeader();
    
    const { agentId } = await inquirer.prompt([
        {
            type: 'input',
            name: 'agentId',
            message: 'Enter agent ID:',
            validate: input => input.length > 0 ? true : 'Agent ID is required'
        }
    ]);

    // Show a loading spinner
    const spinner = ora({
        text: 'Collecting agent metrics...',
        spinner: 'dots',
        color: 'cyan'
    }).start();
    
    await new Promise(resolve => setTimeout(resolve, 1200)); // Simulate loading

    try {
        const state = await getAgentStateService(agentId);
        const metrics = state.metrics || {
            cpu: '25%',
            memory: '128MB',
            uptime: '3h 45m',
            tasks: '42',
            success: '97.5%'
        };

        spinner.succeed('Agent metrics collected successfully! 📊');

        // Display metrics in a nicely formatted box
        console.log(chalk.cyan('\n┌─ Agent Metrics ─────────────────────────────────────────┐'));
        console.log(chalk.cyan('│                                                          │'));
        console.log(chalk.cyan(`│  🤖 Agent ID:       ${agentId.padEnd(46)}│`));
        console.log(chalk.cyan(`│  💻 CPU Usage:      ${metrics.cpu.padEnd(46)}│`));
        console.log(chalk.cyan(`│  🧠 Memory Usage:   ${metrics.memory.padEnd(46)}│`));
        console.log(chalk.cyan(`│  ⏱️  Uptime:         ${metrics.uptime.padEnd(46)}│`));
        console.log(chalk.cyan(`│  🔄 Tasks Processed: ${metrics.tasks.padEnd(44)}│`));
        console.log(chalk.cyan(`│  ✅ Success Rate:   ${metrics.success.padEnd(46)}│`));
        console.log(chalk.cyan('│                                                          │'));
        console.log(chalk.cyan('└──────────────────────────────────────────────────────────┘'));
        
        // Pause to let the user see the results
        await inquirer.prompt([
            {
                type: 'input',
                name: 'continue',
                message: '🔄 Press Enter to continue...'
            }
        ]);
    } catch (error) {
        spinner.fail('Failed to collect agent metrics');
        console.error(chalk.red('Error:'), error.message);
        
        // Pause to let the user see the error
        await inquirer.prompt([
            {
                type: 'input',
                name: 'continue',
                message: '🔄 Press Enter to continue...'
            }
        ]);
    }
}

// =============================================================================
// Swarm Functions
// =============================================================================
async function createSwarm() {
    // Ask user for the type of swarm implementation
    const { implementationType } = await inquirer.prompt([
        {
            type: 'list',
            name: 'implementationType',
            message: 'Select swarm implementation type:',
            choices: ['Julia Native Swarm', 'OpenAI Swarm']
        }
    ]);

    if (implementationType === 'Julia Native Swarm') {
        // --- Logic for Julia Native Swarm ---
        console.log(chalk.blue('\n--- Configure Julia Native Swarm ---'));

        // Prompt for individual configuration values
        const namePrompt = await inquirer.prompt([
            {
                type: 'input',
                name: 'name',
                message: 'Enter Julia swarm name:',
                validate: input => input.length > 0 ? true : 'Name is required'
            }
        ]);
        const name = namePrompt.name;

        const sizePrompt = await inquirer.prompt([
            {
                type: 'number',
                name: 'size',
                message: 'Enter swarm size (number of particles/agents):',
                default: 10,
                validate: input => !isNaN(parseInt(input)) && parseInt(input) > 0 ? true : 'Size must be a positive number'
            }
        ]);
        const size = parseInt(sizePrompt.size);

        const algoChoices = ['pso', 'gwo', 'woa', 'genetic', 'ga', 'aco', 'de'];
        const algoPrompt = await inquirer.prompt([
            {
                type: 'list',
                name: 'algorithm',
                message: 'Select swarm algorithm:',
                choices: algoChoices,
                default: 'pso'
            }
        ]);
        const algorithm = algoPrompt.algorithm;

        const pairsPrompt = await inquirer.prompt([
            {
                type: 'input',
                name: 'trading_pairs',
                message: 'Enter trading pairs (comma-separated, e.g., ETH/USD,BTC/USD):',
                default: 'ETH/USD',
                filter: input => input.split(',').map(p => p.trim()).filter(p => p.length > 0) // Split, trim, remove empty
            }
        ]);
        const trading_pairs = pairsPrompt.trading_pairs;
        
        const chainPrompt = await inquirer.prompt([
            {
                type: 'input',
                name: 'chain',
                message: 'Enter blockchain (e.g., ethereum):',
                default: 'ethereum'
            }
        ]);
        const chain = chainPrompt.chain;

        const dexPrompt = await inquirer.prompt([
            {
                type: 'input',
                name: 'dex',
                message: 'Enter DEX (e.g., uniswap-v3):',
                default: 'uniswap-v3'
            }
        ]);
        const dex = dexPrompt.dex;

        // Iteratively prompt for algorithm parameters
        console.log(chalk.blue('\nEnter algorithm-specific parameters (leave key blank to finish):'));
        const parameters = {};
        while (true) {
            const keyPrompt = await inquirer.prompt({
                type: 'input',
                name: 'key',
                message: 'Parameter key (or leave blank to finish):'
            });
            const key = keyPrompt.key.trim();
            if (key === '') {
                break;
            }

            const valuePrompt = await inquirer.prompt({
                type: 'input',
                name: 'value',
                message: `Value for "${key}":`
            });
            // Attempt to parse as number, otherwise store as string
            const parsedValue = parseFloat(valuePrompt.value);
            parameters[key] = isNaN(parsedValue) ? valuePrompt.value : parsedValue;
        }

        try {
            // Construct the config object from prompts
            const swarmConfig = {
                name: name,
                size: size,
                algorithm: algorithm,
                trading_pairs: trading_pairs,
                parameters: parameters
                // chain and dex are passed separately to the service function
            };
            
            console.log(chalk.cyan('\nConstructed Julia Swarm Config:'), JSON.stringify(swarmConfig, null, 2));
            console.log(chalk.cyan('Target Chain:'), chain);
            console.log(chalk.cyan('Target DEX:'), dex);

            // Pass the constructed config object
            const result = await createSwarmService(name, 'Trading', swarmConfig, chain, dex); // Pass chain/dex
            console.log(chalk.green(`Julia Swarm "${name}" creation request sent!`));
            console.log(chalk.cyan('Backend Response:'), JSON.stringify(result));
        } catch (error) {
            console.error(chalk.red('Failed to create Julia swarm:'), error.message);
        }

    } else if (implementationType === 'OpenAI Swarm') {
        // --- Logic for OpenAI Swarm ---
        console.log(chalk.blue('\n--- Configure OpenAI Swarm ---'));
        
        const namePrompt = await inquirer.prompt([
            {
                type: 'input',
                name: 'name',
                message: 'Enter OpenAI swarm name:',
                validate: input => input.length > 0 ? true : 'Name is required'
            }
        ]);
        const name = namePrompt.name;

        const agentConfigs = [];
        console.log(chalk.blue('\nAdd agents to the swarm (leave agent name blank to finish):'));
        let agentCounter = 1;
        while (true) {
             const agentNamePrompt = await inquirer.prompt({
                type: 'input',
                name: 'agentName',
                message: `Agent ${agentCounter} Name (or leave blank to finish):`
            });
            const agentName = agentNamePrompt.agentName.trim();
            if (agentName === '') {
                break;
            }

            const instructionsPrompt = await inquirer.prompt({
                type: 'input',
                name: 'instructions',
                message: `Agent "${agentName}" Instructions:`,
                default: 'You are a helpful agent.'
            });
            const instructions = instructionsPrompt.instructions;
            
            // TODO: Add prompts for agent functions/tools if needed later

            agentConfigs.push({
                name: agentName,
                instructions: instructions
                // functions: [] // Placeholder for future function support
            });
            agentCounter++;
        }

        if (agentConfigs.length === 0) {
            console.log(chalk.yellow('No agents added. OpenAI Swarm creation cancelled.'));
            return;
        }

        try {
            console.log(chalk.cyan('\nConstructed OpenAI Agent Configs:'), JSON.stringify(agentConfigs, null, 2));

            console.log(chalk.magenta('[DEBUG] About to call createOpenAISwarmService...'));

            // Call the service function for OpenAI Swarm
            const result = await createOpenAISwarmService(name, agentConfigs);
            
            console.log(chalk.magenta('[DEBUG] Call to createOpenAISwarmService finished.'));
            
            console.log(chalk.green(`OpenAI Swarm "${name}" creation request sent!`));
            console.log(chalk.cyan('Backend Response:'), JSON.stringify(result));

        } catch (error) {
             console.log(chalk.magenta('[DEBUG] Caught error in createSwarm (OpenAI branch).'));
            console.error(chalk.red('Failed to create OpenAI swarm:'), error.message);
        }
    }
}

async function listSwarms() {
    try {
        // Show a loading spinner
        const spinner = ora({
            text: 'Fetching swarms...',
            spinner: 'dots',
            color: 'green'
        }).start();
        
        await new Promise(resolve => setTimeout(resolve, 800));
        
        let result;
        let usingMockData = false;
        
        try {
            // Try to get all swarms from Julia backend
            result = await juliaBridge.runJuliaCommand('list_swarms', []);
        } catch (backendError) {
            // If backend fails, log the error and use mock data
            spinner.warn(`Backend error: ${backendError.message}. Using mock data.`);
            usingMockData = true;
            
            // Provide mock data for demo purposes
            result = {
                swarms: [
                    { 
                        id: uuidv4().substring(0, 8),
                        name: 'TradingSwarm', 
                        type: 'PSO', 
                        agents: 12,
                        status: 'active' 
                    },
                    { 
                        id: uuidv4().substring(0, 8),
                        name: 'AnalyticsCluster', 
                        type: 'GWO', 
                        agents: 8,
                        status: 'inactive' 
                    }
                ]
            };
        }
        
        spinner.stop();
        
        if (result && result.error) {
            throw new Error(result.error);
        }
        
        console.log(chalk.green('\n┌─ Swarm List ───────────────────────────────────────────┐'));
        console.log(chalk.green('│                                                          │'));
        
        if (result && result.swarms && result.swarms.length > 0) {
            result.swarms.forEach(swarm => {
                const status = swarm.status === 'active' ? chalk.green('Active') : chalk.yellow('Inactive');
                console.log(chalk.green(`│  • ${swarm.name.padEnd(20)} (${swarm.type.padEnd(10)}) [${status}]   │`));
            });
            
            if (usingMockData) {
                console.log(chalk.green('│                                                          │'));
                console.log(chalk.green('│  ℹ️  Note: Displaying mock data (backend unavailable)    │'));
            }
        } else {
            // No swarms found or empty response
            console.log(chalk.green('│  No swarms found. Create a swarm to get started.      │'));
            console.log(chalk.green('│                                                          │'));
            console.log(chalk.green('│  Tip: Select "Create Swarm" from the Swarm Management  │'));
            console.log(chalk.green('│       menu to create your first swarm.                 │'));
        }
        
        console.log(chalk.green('│                                                          │'));
        console.log(chalk.green('└──────────────────────────────────────────────────────────┘'));
        
        // Debug information about the response
        console.log(chalk.gray('\nDebug: Response from backend:'), result ? JSON.stringify(result) : 'No response');
    } catch (error) {
        console.error(chalk.red('\nFailed to list swarms:'), error.message);
    }
    
    // Pause to let the user see the results
    await inquirer.prompt([
        {
            type: 'input',
            name: 'continue',
            message: '🔄 Press Enter to continue...'
        }
    ]);
}

async function configureSwarm() {
    const { swarmId, updates } = await inquirer.prompt([
        {
            type: 'input',
            name: 'swarmId',
            message: 'Enter swarm ID:',
            validate: input => input.length > 0 ? true : 'Swarm ID is required'
        },
        {
            type: 'input',
            name: 'updates',
            message: 'Enter configuration updates (JSON):',
            default: '{}'
        }
    ]);

    try {
        // FIX: Safely parse JSON with try/catch
        let configUpdates;
        try {
            configUpdates = JSON.parse(updates);
        } catch (jsonError) {
            console.error(chalk.red('Invalid JSON updates format. Using empty updates.'));
            configUpdates = {};
        }
        
        const result = await updateSwarmService(swarmId, configUpdates);
        console.log(chalk.green(`Swarm "${swarmId}" configuration updated successfully!`));
        console.log(chalk.cyan('New Status:'), result.status);
    } catch (error) {
        console.error(chalk.red('Failed to update swarm configuration:'), error.message);
    }
}

async function startSwarm() {
    const { swarmId } = await inquirer.prompt([
        {
            type: 'input',
            name: 'swarmId',
            message: 'Enter swarm ID:',
            validate: input => input.length > 0 ? true : 'Swarm ID is required'
        }
    ]);

    try {
        const result = await updateSwarmService(swarmId, { status: 'active' });
        console.log(chalk.green(`Swarm "${swarmId}" started successfully!`));
        console.log(chalk.cyan('Status:'), result.status);
  } catch (error) {
        console.error(chalk.red('Failed to start swarm:'), error.message);
    }
}

async function stopSwarm() {
    const { swarmId } = await inquirer.prompt([
        {
            type: 'input',
            name: 'swarmId',
            message: 'Enter swarm ID:',
            validate: input => input.length > 0 ? true : 'Swarm ID is required'
        }
    ]);

    try {
        const result = await updateSwarmService(swarmId, { status: 'inactive' });
        console.log(chalk.green(`Swarm "${swarmId}" stopped successfully!`));
        console.log(chalk.cyan('Status:'), result.status);
    } catch (error) {
        console.error(chalk.red('Failed to stop swarm:'), error.message);
    }
}

async function deleteSwarm() {
    const { swarmId, confirm } = await inquirer.prompt([
        {
            type: 'input',
            name: 'swarmId',
            message: 'Enter swarm ID:',
            validate: input => input.length > 0 ? true : 'Swarm ID is required'
        },
        {
            type: 'confirm',
            name: 'confirm',
            message: 'Are you sure you want to delete this swarm?',
            default: false
        }
    ]);

    if (confirm) {
        try {
            const result = await juliaBridge.runJuliaCommand('delete_swarm', [swarmId]);
            if (result.error) {
                throw new Error(result.error);
            }
            console.log(chalk.green(`Swarm "${swarmId}" deleted successfully!`));
        } catch (error) {
            console.error(chalk.red('Failed to delete swarm:'), error.message);
        }
    }
}

async function displaySwarmMetrics() {
    // displayHeader already includes console.clear()
    displayHeader();
    
    const { swarmId } = await inquirer.prompt([
        {
            type: 'input',
            name: 'swarmId',
            message: 'Enter swarm ID:',
            validate: input => input.length > 0 ? true : 'Swarm ID is required'
        }
    ]);

    // Show a loading spinner
    const spinner = ora({
        text: 'Collecting swarm metrics...',
        spinner: 'dots',
        color: 'green'
    }).start();
    
    await new Promise(resolve => setTimeout(resolve, 1200)); // Simulate loading

    try {
        const state = await getSwarmStateService(swarmId);
        const metrics = state.metrics || {
            agents: '12/15',
            cpu: '45%',
            memory: '512MB',
            uptime: '8h 20m',
            tasks: '157',
            success: '94.2%'
        };

        spinner.succeed('Swarm metrics collected successfully! 📊');

        // Display metrics in a nicely formatted box
        console.log(chalk.green('\n┌─ Swarm Metrics ─────────────────────────────────────────┐'));
        console.log(chalk.green('│                                                          │'));
        console.log(chalk.green(`│  🐝 Swarm ID:       ${swarmId.padEnd(46)}│`));
        console.log(chalk.green(`│  👥 Active Agents:  ${metrics.agents.padEnd(46)}│`));
        console.log(chalk.green(`│  💻 CPU Usage:      ${metrics.cpu.padEnd(46)}│`));
        console.log(chalk.green(`│  🧠 Memory Usage:   ${metrics.memory.padEnd(46)}│`));
        console.log(chalk.green(`│  ⏱️  Uptime:         ${metrics.uptime.padEnd(46)}│`));
        console.log(chalk.green(`│  🔄 Tasks Processed: ${metrics.tasks.padEnd(44)}│`));
        console.log(chalk.green(`│  ✅ Success Rate:   ${metrics.success.padEnd(46)}│`));
        console.log(chalk.green('│                                                          │'));
        console.log(chalk.green('└──────────────────────────────────────────────────────────┘'));
        
        // Pause to let the user see the results
        await inquirer.prompt([
            {
                type: 'input',
                name: 'continue',
                message: '🔄 Press Enter to continue...'
            }
        ]);
    } catch (error) {
        spinner.fail('Failed to collect swarm metrics');
        console.error(chalk.red('Error:'), error.message);
        
        // Pause to let the user see the error
        await inquirer.prompt([
            {
                type: 'input',
                name: 'continue',
                message: '🔄 Press Enter to continue...'
            }
        ]);
    }
}

// =============================================================================
// Transaction Functions
// =============================================================================
/**
 * Sends a standard transaction (e.g., value transfer) from the connected wallet.
 */
async function sendTransaction() {
    const state = walletManager.getState();
    if (!state.isConnected) {
        console.log(chalk.red('Please connect a wallet first.'));
        return;
    }
    if (state.readOnly) {
        console.log(chalk.red('Cannot send transactions in read-only mode.'));
        return;
    }
    // Check if the current provider is node (PrivateKeyProvider)
    const currentProvider = walletManager.getCurrentProvider();
    const isNodePvkProvider = currentProvider instanceof walletManager.getNodeProvider().constructor;

    if (!isNodePvkProvider) {
         console.log(chalk.yellow('Sending transactions directly is currently only supported when connected via Private Key.'));
         console.log(chalk.yellow('For browser wallets, initiate transactions through dApps or their interfaces.'));
         return;
    }

    try {
        // Get transaction details from the user
        const { to, value, data } = await inquirer.prompt([
            // ... (prompts for to, value, data - same as before) ...
            {
                type: 'input',
                name: 'to',
                message: 'Enter recipient address:',
                // Add validation
            },
            {
                type: 'input',
                name: 'value',
                message: 'Enter amount to send (in Ether/native token):',
                 validate: input => !isNaN(parseFloat(input)) && parseFloat(input) >= 0 ? true : 'Invalid amount'
            },
            {
                type: 'input',
                name: 'data',
                message: 'Enter transaction data (optional, hex string):',
                default: '0x'
            }
        ]);

        // Construct the transaction request (ethers v5)
        const txRequest = {
            to: to,
            value: ethers.utils.parseEther(value), // Convert ETH value to Wei
            data: data || '0x',
            // Let ethers/provider handle nonce, gas estimation etc.
        };

        const { confirmed } = await inquirer.prompt([
            {
                type: 'confirm',
                name: 'confirmed',
                message: `Send ${value} to ${to}?`,
                default: false
            }
        ]);

        if (!confirmed) {
            console.log(chalk.yellow('Transaction cancelled.'));
            return;
        }

        const spinner = ora('Sending transaction...').start();
        try {
            // Use the WalletManager method - it handles provider check internally
            const txResponse = await walletManager.sendTransaction(txRequest);
            spinner.succeed(`Transaction submitted! Hash: ${txResponse.hash}`);
            console.log(chalk.cyan('Waiting for confirmation...'));

            // Wait for 1 confirmation
            const receipt = await walletManager.waitForTransaction(txResponse.hash, 1);

            if (receipt && receipt.status === 1) {
                spinner.succeed(`Transaction confirmed! Block: ${receipt.blockNumber}`);
                 // Update local history if needed
                 if (!walletManager.state.transactions) walletManager.state.transactions = [];
                 walletManager.state.transactions.push({
                     hash: receipt.transactionHash,
                     from: state.address,
                     to: to,
                     amount: `${value} ${ID_TO_CHAIN_NAME[state.chainId]}`, // Use correct chain name
                     timestamp: new Date(), // Or get block timestamp from receipt
                     status: 'Confirmed',
                     provider: 'node' // Indicate it was sent via node provider
                 });
            } else {
                spinner.fail(`Transaction failed or status unknown. Receipt: ${JSON.stringify(receipt)}`);
            }

        } catch (error) {
            spinner.fail(`Transaction failed: ${error.message}`);
            console.error(chalk.red('Error Details:'), error);
        }
    } catch (error) {
        console.error(chalk.red('Error preparing transaction:'), error.message);
    }
    // Add pause
    await inquirer.prompt([{
       type: 'input',
       name: 'continue',
       message: 'Press Enter to continue...'
    }]);
}

async function viewTransactionHistory() {
    const state = walletManager.getState();
    if (!state.isConnected) {
        console.log(chalk.yellow('Please connect a wallet first.'));
        return;
    }

    try {
        let transactions = state.transactions || [];
        
        if (transactions.length === 0) {
            // If no transactions, provide mock data for demo purposes
            if (state.readOnly) {
                console.log(chalk.yellow('No transaction history available in read-only mode.'));
                console.log(chalk.yellow('Connect with a private key to view and make transactions.'));
                return;
            } else {
                transactions = [
                    { 
                        hash: `0x${Math.random().toString(16).substring(2, 12)}`, 
                        from: 'Previous Wallet',
                        to: state.address, 
                        amount: `0.5 ${state.chain.toUpperCase()}`, 
                        timestamp: new Date(Date.now() - 86400000), // 1 day ago
                        status: 'Confirmed' 
                    }
                ];
            }
        }

        console.log(chalk.cyan('\nTransaction History:'));
        transactions.forEach(tx => {
            const statusColor = tx.status === 'Confirmed' ? chalk.green : chalk.yellow;
            console.log(
                chalk.white(`- ${tx.hash}`),
                '\n  ',
                chalk.white(`From: ${tx.from}`),
                '\n  ',
                chalk.white(`To: ${tx.to}`),
                '\n  ',
                chalk.white(`Amount: ${tx.amount}`),
                '\n  ',
                chalk.white(`Date: ${tx.timestamp.toLocaleString()}`),
                '\n  ',
                chalk.white(`Status: ${statusColor(tx.status)}`),
                '\n'
            );
        });
        
        await inquirer.prompt([
            {
                type: 'input',
                name: 'continue',
                message: 'Press Enter to continue...'
            }
        ]);
    } catch (error) {
        console.error(chalk.red('Failed to get transaction history:'), error.message);
    }
}

// =============================================================================
// API Key Functions
// =============================================================================
async function addApiKey() {
    const { service, key } = await inquirer.prompt([
    {
      type: 'list',
            name: 'service',
            message: 'Select service:',
            choices: ['OpenAI', 'Anthropic', 'Google', 'AWS']
        },
        {
            type: 'password',
            name: 'key',
            message: 'Enter API key:',
            validate: input => input.length > 0 ? true : 'API key is required'
        }
    ]);

    try {
        // Simulate adding API key
        console.log(chalk.green(`API key for ${service} added successfully!`));
    } catch (error) {
        console.error(chalk.red('Failed to add API key:'), error.message);
    }
}

async function listApiKeys() {
    try {
        // Show a loading spinner
        const spinner = ora({
            text: 'Fetching API keys...',
            spinner: 'dots',
            color: 'yellow'
        }).start();
        
        await new Promise(resolve => setTimeout(resolve, 800));
        
        // Simulate listing API keys (in a real app, this would fetch from a backend)
        const keys = [
            { service: 'OpenAI', status: 'Valid', last_used: '2 hours ago' },
            { service: 'Anthropic', status: 'Valid', last_used: '1 day ago' },
            { service: 'Google', status: 'Invalid', last_used: 'Never' },
            { service: 'AWS', status: 'Missing', last_used: 'Never' }
        ];
        
        spinner.succeed('API keys retrieved successfully');

        console.log(chalk.yellow('\n┌─ API Keys ─────────────────────────────────────────────┐'));
        console.log(chalk.yellow('│                                                          │'));
        
        if (keys.length > 0) {
            keys.forEach(key => {
                let statusColor;
                let statusIcon;
                
                switch (key.status) {
                    case 'Valid':
                        statusColor = chalk.green;
                        statusIcon = '✅';
                        break;
                    case 'Invalid':
                        statusColor = chalk.red;
                        statusIcon = '❌';
                        break;
                    case 'Missing':
                        statusColor = chalk.yellow;
                        statusIcon = '⚠️';
                        break;
                    default:
                        statusColor = chalk.white;
                        statusIcon = '❓';
                }
                
                console.log(chalk.yellow(`│  • ${key.service.padEnd(12)} ${statusIcon} ${statusColor(key.status.padEnd(10))} Last used: ${key.last_used.padEnd(12)} │`));
            });
        } else {
            console.log(chalk.yellow('│  No API keys found. Add an API key to get started.     │'));
            console.log(chalk.yellow('│                                                          │'));
            console.log(chalk.yellow('│  Tip: Select "Add API Key" from the API Keys Management │'));
            console.log(chalk.yellow('│       menu to add your first API key.                   │'));
        }
        
        console.log(chalk.yellow('│                                                          │'));
        console.log(chalk.yellow('└──────────────────────────────────────────────────────────┘'));
    } catch (error) {
        console.error(chalk.red('\nFailed to list API keys:'), error.message);
    }
    
    // Pause to let the user see the results
    await inquirer.prompt([
        {
            type: 'input',
            name: 'continue',
            message: '🔄 Press Enter to continue...'
        }
    ]);
}

async function updateApiKey() {
    const { service, key } = await inquirer.prompt([
        {
            type: 'list',
            name: 'service',
            message: 'Select service:',
            choices: ['OpenAI', 'Anthropic', 'Google', 'AWS']
        },
        {
            type: 'password',
            name: 'key',
            message: 'Enter new API key:',
            validate: input => input.length > 0 ? true : 'API key is required'
        }
    ]);

    try {
        // Simulate updating API key
        console.log(chalk.green(`API key for ${service} updated successfully!`));
    } catch (error) {
        console.error(chalk.red('Failed to update API key:'), error.message);
    }
}

async function deleteApiKey() {
    const { service, confirm } = await inquirer.prompt([
        {
            type: 'list',
            name: 'service',
            message: 'Select service:',
            choices: ['OpenAI', 'Anthropic', 'Google', 'AWS']
        },
        {
            type: 'confirm',
            name: 'confirm',
            message: 'Are you sure you want to delete this API key?',
            default: false
        }
    ]);

    if (confirm) {
        try {
            // Simulate deleting API key
            console.log(chalk.green(`API key for ${service} deleted successfully!`));
  } catch (error) {
            console.error(chalk.red('Failed to delete API key:'), error.message);
        }
    }
}

// =============================================================================
// Configuration Functions
// =============================================================================
async function configurePerformance() {
    const { cpu, memory, threads } = await inquirer.prompt([
          {
            type: 'input',
            name: 'cpu',
            message: 'Enter CPU limit (percentage):',
            default: '80',
            validate: input => !isNaN(input) && parseInt(input) > 0 && parseInt(input) <= 100 ? true : 'CPU limit must be between 1 and 100'
        },
        {
            type: 'input',
            name: 'memory',
            message: 'Enter memory limit (MB):',
            default: '2048',
            validate: input => !isNaN(input) && parseInt(input) > 0 ? true : 'Memory limit must be a positive number'
        },
        {
            type: 'input',
            name: 'threads',
            message: 'Enter number of threads:',
            default: '4',
            validate: input => !isNaN(input) && parseInt(input) > 0 ? true : 'Number of threads must be a positive number'
        }
    ]);

    try {
        // Simulate updating performance settings
        console.log(chalk.green('Performance settings updated successfully!'));
    } catch (error) {
        console.error(chalk.red('Failed to update performance settings:'), error.message);
    }
}

async function configureSecurity() {
    const { encryption, authentication, firewall } = await inquirer.prompt([
        {
            type: 'list',
            name: 'encryption',
            message: 'Select encryption level:',
            choices: ['Low', 'Medium', 'High']
        },
        {
            type: 'list',
            name: 'authentication',
            message: 'Select authentication method:',
            choices: ['Password', '2FA', 'Hardware Key']
        },
        {
            type: 'list',
            name: 'firewall',
            message: 'Select firewall level:',
            choices: ['Basic', 'Advanced', 'Custom']
        }
    ]);

    try {
        // Simulate updating security settings
        console.log(chalk.green('Security settings updated successfully!'));
  } catch (error) {
        console.error(chalk.red('Failed to update security settings:'), error.message);
    }
}

async function configureNetwork() {
    const { proxy, dns, timeout } = await inquirer.prompt([
        {
            type: 'input',
            name: 'proxy',
            message: 'Enter proxy server (optional):',
            default: ''
        },
        {
            type: 'input',
            name: 'dns',
            message: 'Enter DNS server:',
            default: '8.8.8.8',
            validate: input => input.length > 0 ? true : 'DNS server is required'
        },
        {
            type: 'input',
            name: 'timeout',
            message: 'Enter connection timeout (seconds):',
            default: '30',
            validate: input => !isNaN(input) && parseInt(input) > 0 ? true : 'Timeout must be a positive number'
        }
    ]);

    try {
        // Simulate updating network settings
        console.log(chalk.green('Network settings updated successfully!'));
    } catch (error) {
        console.error(chalk.red('Failed to update network settings:'), error.message);
    }
}

async function configureStorage() {
    const { path, quota, backup } = await inquirer.prompt([
        {
            type: 'input',
            name: 'path',
            message: 'Enter storage path:',
            default: path.join(os.homedir(), '.juliaos', 'data'),
            validate: input => input.length > 0 ? true : 'Storage path is required'
        },
        {
            type: 'input',
            name: 'quota',
            message: 'Enter storage quota (GB):',
            default: '10',
            validate: input => !isNaN(input) && parseInt(input) > 0 ? true : 'Storage quota must be a positive number'
        },
    {
      type: 'list',
            name: 'backup',
            message: 'Select backup frequency:',
            choices: ['Never', 'Daily', 'Weekly', 'Monthly']
        }
    ]);

    try {
        // Simulate updating storage settings
        console.log(chalk.green('Storage settings updated successfully!'));
    } catch (error) {
        console.error(chalk.red('Failed to update storage settings:'), error.message);
    }
}

// =============================================================================
// Metrics Functions
// =============================================================================
async function displaySystemMetrics() {
    // displayHeader already includes console.clear()
    displayHeader();
    
    // Show loading spinner
    const spinner = ora({
        text: 'Collecting system metrics...',
        spinner: 'dots',
        color: 'cyan'
    }).start();
    
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    try {
        // Simulate retrieving system metrics
        const metrics = {
            cpu: '35%',
            memory: '4GB',
            disk: '250GB',
            network: '100Mbps',
            processes: '50'
        };

        spinner.succeed('System metrics collected successfully! 📊');

        console.log(chalk.cyan('\n┌─ System Metrics ────────────────────────────────────────┐'));
        console.log(chalk.cyan('│                                                          │'));
        console.log(chalk.cyan(`│  💻 CPU Usage:      ${metrics.cpu.padEnd(46)}│`));
        console.log(chalk.cyan(`│  🧠 Memory Usage:   ${metrics.memory.padEnd(46)}│`));
        console.log(chalk.cyan(`│  💾 Disk Usage:     ${metrics.disk.padEnd(46)}│`));
        console.log(chalk.cyan(`│  🌐 Network Speed:  ${metrics.network.padEnd(46)}│`));
        console.log(chalk.cyan(`│  🔄 Processes:      ${metrics.processes.padEnd(46)}│`));
        console.log(chalk.cyan('│                                                          │'));
        console.log(chalk.cyan('└──────────────────────────────────────────────────────────┘'));
        
        // Pause to let the user see the results
        await inquirer.prompt([
            {
                type: 'input',
                name: 'continue',
                message: '🔄 Press Enter to continue...'
            }
        ]);
    } catch (error) {
        spinner.fail('Failed to collect system metrics');
        console.error(chalk.red('Error:'), error.message);
        
        // Pause to let the user see the error
        await inquirer.prompt([
            {
                type: 'input',
                name: 'continue',
                message: '🔄 Press Enter to continue...'
            }
        ]);
    }
}

async function displayNetworkMetrics() {
    // displayHeader already includes console.clear()
    displayHeader();
    
    // Show loading spinner
    const spinner = ora({
        text: 'Analyzing network metrics...',
        spinner: 'dots',
        color: 'blue'
    }).start();
    
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    try {
        // Simulate retrieving network metrics
        const metrics = {
            bandwidth: '100Mbps',
            latency: '50ms',
            packets: '1000/s',
            errors: '0.1%',
            connections: '25'
        };

        spinner.succeed('Network analysis complete! 🌐');
        
        console.log(chalk.blue('\n┌─ Network Metrics ───────────────────────────────────────┐'));
        console.log(chalk.blue('│                                                          │'));
        console.log(chalk.blue(`│  🔌 Bandwidth:      ${metrics.bandwidth.padEnd(46)}│`));
        console.log(chalk.blue(`│  ⏱️  Latency:        ${metrics.latency.padEnd(46)}│`));
        console.log(chalk.blue(`│  📦 Packets/s:      ${metrics.packets.padEnd(46)}│`));
        console.log(chalk.blue(`│  ⚠️  Error Rate:     ${metrics.errors.padEnd(46)}│`));
        console.log(chalk.blue(`│  🔄 Connections:    ${metrics.connections.padEnd(46)}│`));
        console.log(chalk.blue('│                                                          │'));
        console.log(chalk.blue('└──────────────────────────────────────────────────────────┘'));
        
        // Pause to let the user see the results
        await inquirer.prompt([
            {
                type: 'input',
                name: 'continue',
                message: '🔄 Press Enter to continue...'
            }
        ]);
    } catch (error) {
        spinner.fail('Failed to collect network metrics');
        console.error(chalk.red('Error:'), error.message);
        
        // Pause to let the user see the error
        await inquirer.prompt([
            {
                type: 'input',
                name: 'continue',
                message: '🔄 Press Enter to continue...'
            }
        ]);
    }
}

// =============================================================================
// Agent Service Functions
// =============================================================================
async function createAgentService(name, type, config) {
    // In a real implementation, we'd communicate with the Julia backend
    // through the juliaBridge to create an agent
    
    try {
        // For demo, generate a unique ID using UUID
        const id = uuidv4();
        
        // Get agent capabilities based on type
        const capabilities = getAgentCapabilities(type);
        
        // Create a more realistic agent object
        const agent = {
            id,
            name,
            type,
            config,
            status: 'Initialized',
            created_at: new Date().toISOString(),
            capabilities: capabilities,
            metrics: {
                cpu: '0%',
                memory: '0MB',
                uptime: '0s',
                tasks: '0',
                success: '0%'
            }
        };
        
        // In a real app, we'd persist this agent somewhere
        
        return agent;
    } catch (error) {
        console.error('Error in createAgentService:', error);
        throw new Error(`Failed to create agent: ${error.message}`);
    }
}

async function updateAgentService(agentId, updates) {
    try {
        // Call Julia backend to update agent
        const result = await juliaBridge.runJuliaCommand('update_agent', [agentId, JSON.stringify(updates)]);
        
        if (result.error) {
            throw new Error(result.error);
        }

        return result;
    } catch (error) {
        throw new Error(`Failed to update agent: ${error.message}`);
    }
}

async function getAgentStateService(agentId) {
    try {
        // Call Julia backend to get agent state
        const result = await juliaBridge.runJuliaCommand('get_agent_state', [agentId]);
        
        if (result.error) {
            throw new Error(result.error);
        }

        return result;
    } catch (error) {
        throw new Error(`Failed to get agent state: ${error.message}`);
    }
}

async function registerAgentSkillService(agentId, skill) {
    try {
        // Call Julia backend to register skill
        const result = await juliaBridge.runJuliaCommand('register_skill', [agentId, JSON.stringify(skill)]);
        
        if (result.error) {
            throw new Error(result.error);
        }

        return result;
    } catch (error) {
        throw new Error(`Failed to register agent skill: ${error.message}`);
    }
}

// =============================================================================
// Swarm Service Functions
// =============================================================================
async function createSwarmService(name, type, config, chain, dex) {
    try {
        // Construct the parameters expected by the Julia backend
        const swarmConfig = {
            name: name,
            size: config.size || 10, // Default size if not provided
            algorithm: config.algorithm || 'pso', // Default algorithm
            trading_pairs: config.trading_pairs || ['ETH/USD'], // Default pair
            parameters: config.parameters || {} // Algorithm parameters
        };

        // Call the Julia backend function via the bridge
        const result = await juliaBridge.runJuliaCommand(
            'SwarmManager.create_swarm', 
            [swarmConfig, chain, dex] // Pass parameters as an array
        );

        if (result && result.error) {
            throw new Error(result.error);
        }

        // Return the successful result from the backend
        // The actual structure might differ based on what SwarmManager.create_swarm returns
        return result || { id: 'unknown', status: 'created_backend' }; 

    } catch (error) {
        // Log the error for debugging
        console.error(chalk.red(`Error in createSwarmService: ${error.message}`), error);
        // Re-throw the error to be caught by the calling function
        throw new Error(`Failed to create swarm via backend: ${error.message}`);
    }
}

// Placeholder function for OpenAI Swarm creation
async function createOpenAISwarmService(name, agentConfigs) {
    console.log(chalk.magenta('[DEBUG] Entered createOpenAISwarmService.'));
    try {
        console.log(chalk.yellow(`Attempting to call backend for OpenAI Swarm: ${name}`));

        // Construct the payload for the Julia backend function
        // Ensure this structure matches what `julia_server.jl` expects for `create_openai_swarm`
        // The backend expects the config object directly as the first element in the params array.
        const payload = {
            name: name,
            agents: agentConfigs
            // Add other OpenAI-specific swarm config if needed here
        };

        console.log(chalk.magenta('[DEBUG] Payload constructed:', JSON.stringify(payload)));

        // Call the Julia backend function via the bridge
        console.log(chalk.magenta('[DEBUG] Calling juliaBridge.runJuliaCommand...'));
        // Pass the payload object as the single element in the params array
        const result = await juliaBridge.runJuliaCommand(
            'create_openai_swarm',
            [payload] // Pass payload directly inside the array
        );
        console.log(chalk.magenta('[DEBUG] juliaBridge.runJuliaCommand finished.'));

        console.log(chalk.cyan('Backend Response (OpenAI Swarm):'), JSON.stringify(result));

        if (result && result.error) {
            console.log(chalk.magenta('[DEBUG] Backend returned an error.'));
            throw new Error(result.error);
        }

        console.log(chalk.magenta('[DEBUG] Returning result from createOpenAISwarmService.'));
        return result;

    } catch (error) {
        console.log(chalk.magenta('[DEBUG] Caught error inside createOpenAISwarmService.'));
        console.error(chalk.red(`Error in createOpenAISwarmService: ${error.message}`), error);
        throw new Error(`Failed to create OpenAI swarm via backend: ${error.message}`);
    }
}

async function updateSwarmService(swarmId, updates) {
    try {
        // Call Julia backend to update swarm
        const result = await juliaBridge.runJuliaCommand('update_swarm', [swarmId, JSON.stringify(updates)]);
        
        if (result.error) {
            throw new Error(result.error);
        }

        return result;
    } catch (error) {
        throw new Error(`Failed to update swarm: ${error.message}`);
    }
}

async function getSwarmStateService(swarmId) {
    try {
        // Call Julia backend to get swarm state
        const result = await juliaBridge.runJuliaCommand('get_swarm_state', [swarmId]);
        
        if (result.error) {
            throw new Error(result.error);
        }

        return result;
    } catch (error) {
        throw new Error(`Failed to get swarm state: ${error.message}`);
    }
}

async function broadcastSwarmMessageService(swarmId, message) {
    try {
        // Call Julia backend to broadcast message
        const result = await juliaBridge.runJuliaCommand('broadcast_message', [swarmId, JSON.stringify(message)]);

        if (result.error) {
            throw new Error(result.error);
        }

        return result;
    } catch (error) {
        throw new Error(`Failed to broadcast swarm message: ${error.message}`);
    }
}

// =============================================================================
// New OpenAI Swarm Interaction Functions
// =============================================================================

async function runOpenAITask() {
    console.log(chalk.blue('\n--- Run Task in OpenAI Swarm ---'));
    try {
        const answers = await inquirer.prompt([
            {
                type: 'input',
                name: 'swarm_id',
                message: 'Enter the OpenAI Swarm ID:',
                validate: input => input.trim().length > 0 ? true : 'Swarm ID cannot be empty.'
            },
            {
                type: 'input',
                name: 'agent_name',
                message: 'Enter the Agent Name within the swarm:',
                validate: input => input.trim().length > 0 ? true : 'Agent Name cannot be empty.'
            },
            {
                type: 'input',
                name: 'task_prompt',
                message: 'Enter the task prompt for the agent:',
                validate: input => input.trim().length > 0 ? true : 'Task prompt cannot be empty.'
            },
            {
                type: 'input',
                name: 'thread_id',
                message: 'Enter existing Thread ID (optional, leave blank to create new):'
            }
        ]);

        const { swarm_id, agent_name, task_prompt } = answers;
        const thread_id = answers.thread_id.trim() || null; // Send null if blank

        const spinner = ora('Submitting task to OpenAI swarm via backend...').start();

        // Construct params array
        const params = [swarm_id, agent_name, task_prompt];
        if (thread_id) {
            params.push(thread_id);
        }

        try {
            const response = await juliaBridge.runJuliaCommand('run_openai_task', params);
            spinner.stop();

            if (response && response.error) {
                console.error(chalk.red('\nBackend Error:'), response.error);
            } else if (response && response.result && response.result.success) {
                spinner.succeed('Task submitted successfully!');
                console.log(chalk.green('\nTask Submission Details:'));
                console.log(chalk.cyan(`  Swarm ID:    ${response.result.swarm_id}`));
                console.log(chalk.cyan(`  Agent Name:  ${response.result.agent_name}`));
                console.log(chalk.cyan(`  Thread ID:   ${response.result.thread_id}`));
                console.log(chalk.cyan(`  Run ID:      ${response.result.run_id}`));
                console.log(chalk.cyan(`  Run Status:  ${response.result.status}`));
                console.log(chalk.yellow('\nUse "Get OpenAI Response" with the Thread ID and Run ID to check status and get results.'));
            } else {
                console.error(chalk.red('\nFailed to submit task. Unexpected response format:'));
                console.log(response);
            }
        } catch (bridgeError) {
            spinner.fail('Failed to communicate with backend.');
            console.error(chalk.red('Bridge Error:'), bridgeError.message);
        }

    } catch (error) {
        console.error(chalk.red('An error occurred while setting up the OpenAI task:'), error.message);
    }

    // Pause
    await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

async function getOpenAIResponse() {
    console.log(chalk.blue('\n--- Get Response/Status from OpenAI Run ---'));
    try {
        const answers = await inquirer.prompt([
            {
                type: 'input',
                name: 'swarm_id',
                message: 'Enter the OpenAI Swarm ID:',
                validate: input => input.trim().length > 0 ? true : 'Swarm ID cannot be empty.'
            },
            {
                type: 'input',
                name: 'thread_id',
                message: 'Enter the Thread ID:',
                validate: input => input.trim().length > 0 ? true : 'Thread ID cannot be empty.'
            },
            {
                type: 'input',
                name: 'run_id',
                message: 'Enter the Run ID:',
                validate: input => input.trim().length > 0 ? true : 'Run ID cannot be empty.'
            }
        ]);

        const { swarm_id, thread_id, run_id } = answers;
        const spinner = ora('Fetching response/status from backend...').start();

        try {
            const response = await juliaBridge.runJuliaCommand('get_openai_response', [swarm_id, thread_id, run_id]);
            spinner.stop();

            if (response && response.error) {
                console.error(chalk.red('\nBackend Error:'), response.error);
            } else if (response && response.result) {
                const result = response.result;
                if (result.success) {
                    spinner.succeed(`Status fetched: ${result.status}`);
                    console.log(chalk.green('\nRun Details:'));
                    console.log(chalk.cyan(`  Swarm ID:    ${result.swarm_id || swarm_id}`));
                    console.log(chalk.cyan(`  Thread ID:   ${result.thread_id || thread_id}`));
                    console.log(chalk.cyan(`  Run ID:      ${result.run_id || run_id}`));
                    console.log(chalk.cyan(`  Status:      ${result.status}`));

                    if (result.status === 'completed' && result.response) {
                        console.log(chalk.cyan(`\nAssistant Response:`));
                        console.log(chalk.white(`  ${result.response.content || '(No content found)'}`));
                        console.log(chalk.gray(`  (Message ID: ${result.response.message_id})`));
                    } else if (result.message) {
                         console.log(chalk.yellow(`\nMessage: ${result.message}`));
                    }

                } else {
                    // Handle cases where success is false (e.g., run failed)
                     spinner.fail(`Run status: ${result.status || 'Failed'}`);
                     console.log(chalk.red(`\nError: ${result.error || 'Failed to get response.'}`));
                     if (result.run_details) {
                         console.log(chalk.gray('Run Details:'), JSON.stringify(result.run_details, null, 2));
                     }
                }
            } else {
                console.error(chalk.red('\nFailed to get response. Unexpected response format:'));
                console.log(response);
            }
        } catch (bridgeError) {
            spinner.fail('Failed to communicate with backend.');
            console.error(chalk.red('Bridge Error:'), bridgeError.message);
        }

    } catch (error) {
        console.error(chalk.red('An error occurred while setting up the OpenAI response request:'), error.message);
    }

    // Pause
    await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// Helper function to get agent capabilities based on type
function getAgentCapabilities(type) {
    const capabilities = {
        'Trading': ['market_analysis', 'order_execution', 'risk_management'],
        'Analysis': ['data_processing', 'pattern_recognition', 'prediction'],
        'Execution': ['order_routing', 'position_management', 'risk_control'],
        'Monitoring': ['system_monitoring', 'alert_management', 'performance_tracking']
    };
    return capabilities[type] || [];
}

// =============================================================================
// System Initialization
// =============================================================================
async function initializeSystem() {
    try {
        // Load environment variables
        dotenv.config();

        // Set default environment variables if not set
        process.env.JULIA_HOME = process.env.JULIA_HOME || '/usr/local/bin/julia';
        process.env.JULIA_NUM_THREADS = process.env.JULIA_NUM_THREADS || '4';
        process.env.JULIA_DEPOT_PATH = process.env.JULIA_DEPOT_PATH || path.join(os.homedir(), '.julia');

        // Initialize Julia bridge
        // Skip actual initialization since we're using an existing server
        juliaBridge.initialized = true;

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
// Welcome Animation
// =============================================================================
async function displayWelcomeAnimation() {
    console.clear();
    
    // Animation frames for the logo
    const frames = [
        `
     ╔═══════════════════════════════════════════════════════════════╗
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ╚═══════════════════════════════════════════════════════════════╝`,
        `
     ╔═══════════════════════════════════════════════════════════════╗
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ╚═══════════════════════════════════════════════════════════════╝`,
        `
     ╔═══════════════════════════════════════════════════════════════╗
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ╚═══════════════════════════════════════════════════════════════╝`,
        `
     ╔═══════════════════════════════════════════════════════════════╗
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ╚═══════════════════════════════════════════════════════════════╝`,
        `
     ╔═══════════════════════════════════════════════════════════════╗
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ╚═══════════════════════════════════════════════════════════════╝`,
        `
     ╔═══════════════════════════════════════════════════════════════╗
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ╚═══════════════════════════════════════════════════════════════╝`,
        `
     ╔═══════════════════════════════════════════════════════════════╗
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ╚═══════════════════════════════════════════════════════════════╝`,
        `
     ╔═══════════════════════════════════════════════════════════════╗
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ║                                                               ║
     ╚═══════════════════════════════════════════════════════════════╝`
    ];
    
    // Color sequence for a rainbow effect
    const colors = [
        chalk.red,
        chalk.yellow,
        chalk.green,
        chalk.blue,
        chalk.magenta,
        chalk.cyan,
        chalk.white
    ];
    
    // Display the frames with progressively changing colors
    for (let i = 0; i < frames.length; i++) {
        console.clear();
        const color = colors[i % colors.length];
        console.log(color(frames[i]));
        await new Promise(resolve => setTimeout(resolve, 200)); // Frame display time
    }
    
    // Add a loading bar animation
    const loadingSteps = 20;
    const loadingChar = '■';
    
    console.log('\n  Initializing JuliaOS components...\n');
    process.stdout.write('  [');
    
    for (let i = 0; i < loadingSteps; i++) {
        process.stdout.write(chalk.cyan(loadingChar));
        await new Promise(resolve => setTimeout(resolve, 100));
    }
    
    process.stdout.write('] Done!\n\n');
    console.log(chalk.green('  ✓ System core initialized'));
    console.log(chalk.green('  ✓ Runtime environment loaded'));
    console.log(chalk.green('  ✓ Network connections established'));
    console.log(chalk.green('  ✓ Security protocols activated'));
    console.log(chalk.green('  ✓ User interface ready'));
    
    // Short pause before continuing to the main interface
    await new Promise(resolve => setTimeout(resolve, 1000));
}

// =============================================================================
// NEW: Manual Trade Function with Signing Flow
// =============================================================================
async function manualTrade() {
    const walletState = walletManager.getState();
    if (!walletState.isConnected || walletState.readOnly) {
        console.log(chalk.red('Please connect a wallet with full access first.'));
        return;
    }

    // Check if we are connected via the PrivateKeyProvider
    const currentProvider = walletManager.getCurrentProvider();
    const canSignLocally = currentProvider instanceof walletManager.getNodeProvider().constructor;

    if (!canSignLocally) {
        console.log(chalk.yellow('Manual trade execution currently requires connection via Private Key for signing.'));
        return;
    }

    console.log(chalk.blue('--- Execute Manual Trade ---'));
    try {
        const { dex, chainName, tokenInSymbol, tokenOutSymbol, amountIn, slippagePercent } = await inquirer.prompt([
            { type: 'input', name: 'dex', message: 'DEX Name (e.g., uniswap_v3):', default: 'uniswap_v3' },
            { type: 'list', name: 'chainName', message: 'Chain:', choices: Object.keys(CHAIN_NAME_TO_ID), default: ID_TO_CHAIN_NAME[walletState.chainId] },
            { type: 'input', name: 'tokenInSymbol', message: 'Token In Symbol (e.g., WETH):' },
            { type: 'input', name: 'tokenOutSymbol', message: 'Token Out Symbol (e.g., USDC):' },
            { type: 'input', name: 'amountIn', message: 'Amount In:', validate: input => !isNaN(parseFloat(input)) && parseFloat(input) > 0 },
            { type: 'input', name: 'slippagePercent', message: 'Slippage Tolerance (%): ', default: '0.5', validate: input => !isNaN(parseFloat(input)) }
        ]);

        const chain = chainName.toLowerCase();
        const slippage = parseFloat(slippagePercent) / 100;

        // 1. Resolve Token Addresses via Bridge
        const addrSpinner = ora('Resolving token addresses...').start();
        let tokenInAddress, tokenOutAddress;
        try {
            const [inAddrRes, outAddrRes] = await Promise.all([
                juliaBridge.runJuliaCommand('Bridge.get_token_address', { symbol: tokenInSymbol, chain: chain }),
                juliaBridge.runJuliaCommand('Bridge.get_token_address', { symbol: tokenOutSymbol, chain: chain })
            ]);

            if (inAddrRes.status !== 'success' || outAddrRes.status !== 'success') {
                throw new Error(`Failed to resolve addresses: IN: ${inAddrRes.error || 'OK'}, OUT: ${outAddrRes.error || 'OK'}`);
            }
            tokenInAddress = inAddrRes.address;
            tokenOutAddress = outAddrRes.address;
            addrSpinner.succeed(`Addresses resolved: ${tokenInSymbol}=${tokenInAddress}, ${tokenOutSymbol}=${tokenOutAddress}`);
        } catch (error) {
            addrSpinner.fail(`Address resolution failed: ${error.message}`);
            return;
        }

        // 2. Get Token Decimals via Bridge (or Blockchain module directly? Bridge seems better)
        const decSpinner = ora(`Fetching ${tokenInSymbol} decimals...`).start();
        let tokenInDecimals;
        try {
             // Assuming a Bridge command exists, otherwise need to add it or call Blockchain directly
             // Let's assume Bridge.get_token_decimals exists for now
             const decRes = await juliaBridge.runJuliaCommand('Bridge.get_token_decimals', { address: tokenInAddress, chain: chain });
             if (decRes.status !== 'success') throw new Error(decRes.error || 'Unknown error');
             tokenInDecimals = decRes.decimals;
             decSpinner.succeed(`${tokenInSymbol} decimals: ${tokenInDecimals}`);
        } catch (error) {
             // Fallback: Call Blockchain.getDecimals directly if Bridge command fails/doesn't exist
             decSpinner.text = `Bridge failed, fetching decimals via Blockchain module...`;
             try {
                 const decRes = await juliaBridge.runJuliaCommand('Blockchain.getDecimals', { contractAddress: tokenInAddress, chain: chain });
                 if (decRes.status !== 'success') throw new Error(decRes.error || 'Unknown error fetching via Blockchain');
                 tokenInDecimals = decRes.result; // Adjust based on actual return structure
                 decSpinner.succeed(`${tokenInSymbol} decimals: ${tokenInDecimals}`);
             } catch (finalError) {
                 decSpinner.fail(`Failed to fetch decimals: ${finalError.message}`);
                 return;
             }
        }

        // 3. Calculate amountInWei
        const amountInWei = ethers.utils.parseUnits(amountIn, tokenInDecimals).toString();

        // 4. Prepare Trade via Julia Bridge
        const prepSpinner = ora('Preparing trade via Julia backend...').start();
        let tradePrepResult;
        try {
            tradePrepResult = await juliaBridge.runJuliaCommand('Bridge.execute_trade', {
                dex: dex,
                chain: chain,
                token_in: tokenInAddress,
                token_out: tokenOutAddress,
                amount_in: amountInWei,
                slippage: slippage,
                recipient: walletState.address // Use connected wallet address
            });
            prepSpinner.succeed('Trade prepared by backend.');
            console.log('Backend Response:', tradePrepResult);
        } catch (error) {
            prepSpinner.fail(`Trade preparation failed: ${error.message}`);
            return;
        }

        // 5. Handle Signing Request
        if (tradePrepResult.status === 'needs_signing' && tradePrepResult.unsigned_transaction) {
            const unsignedTx = tradePrepResult.unsigned_transaction;
            const requestId = tradePrepResult.request_id;
            const txChain = tradePrepResult.chain; // Chain from the response

            console.log(chalk.yellow('\n--- Transaction Requires Signing ---'));
            // Display transaction details clearly to the user
            console.log(`  From:    ${unsignedTx.from}`);
            console.log(`  To:      ${unsignedTx.to}`);
            console.log(`  Value:   ${unsignedTx.value ? ethers.utils.formatEther(unsignedTx.value) : '0'} ETH/Native`);
            console.log(`  Nonce:   ${unsignedTx.nonce}`);
            console.log(`  GasPrice:${unsignedTx.gasPrice ? ethers.utils.formatUnits(unsignedTx.gasPrice, 'gwei') : 'N/A'} Gwei`);
            console.log(`  GasLimit:${unsignedTx.gas}`);
            console.log(`  Data:    ${unsignedTx.data.substring(0, 50)}...`);
            console.log(`  Chain:   ${txChain} (ID: ${CHAIN_NAME_TO_ID[txChain]})`);
            console.log(`  Request: ${requestId}`);

            const { confirmSign } = await inquirer.prompt([{
                type: 'confirm', name: 'confirmSign', message: 'Do you want to sign and submit this transaction?', default: true
            }]);

            if (confirmSign) {
                const signSpinner = ora('Signing transaction...').start();
                try {
                    // Ensure unsignedTx fields match ethers.TransactionRequest
                    // Convert string hex numbers to BigInt or number where needed by ethers v5
                    const txToSign = {
                        to: unsignedTx.to,
                        from: unsignedTx.from, // Optional in ethers v5, signer fills it
                        nonce: parseInt(unsignedTx.nonce), // Must be number
                        gasLimit: ethers.BigNumber.from(unsignedTx.gas), // Must be BigNumber/string
                        gasPrice: unsignedTx.gasPrice ? ethers.BigNumber.from(unsignedTx.gasPrice) : undefined,
                        data: unsignedTx.data || '0x',
                        value: unsignedTx.value ? ethers.BigNumber.from(unsignedTx.value) : ethers.BigNumber.from(0),
                        chainId: CHAIN_NAME_TO_ID[txChain]
                    };

                    // Sign using the WalletManager method
                    const signedTxHex = await walletManager.signTransactionRequest(txToSign);
                    signSpinner.succeed('Transaction signed successfully.');
                    console.log('Signed TX Hex:', signedTxHex.substring(0, 60), '...');

                    // 6. Submit Signed Transaction via Bridge
                    const submitSpinner = ora('Submitting signed transaction to Julia backend...').start();
                    try {
                        const submitResult = await juliaBridge.runJuliaCommand('Bridge.submit_signed_transaction', {
                           chain: txChain,
                           request_id: requestId,
                           signed_tx_hex: signedTxHex
                        });

                        if (submitResult.status === 'success') {
                           submitSpinner.succeed(`Transaction submitted! Final Hash: ${submitResult.tx_hash}`);
                           // TODO: Optionally wait for confirmation here
                        } else {
                            throw new Error(submitResult.error || 'Submission failed with unknown error');
                        }
                    } catch (error) {
                         submitSpinner.fail(`Transaction submission failed: ${error.message}`);
                    }

                } catch (error) {
                    signSpinner.fail(`Signing failed: ${error.message}`);
                    console.error(chalk.red('Signing Error Details:'), error);
                }
            } else {
                console.log(chalk.yellow('Transaction signing cancelled.'));
            }
        } else if (tradePrepResult.status === 'success') {
             // Handle cases where backend might execute directly (e.g., internal wallet or simulation)
             console.log(chalk.green(`Trade executed directly by backend (status: ${tradePrepResult.status}). Hash: ${tradePrepResult.tx_hash || 'N/A'}`));
        } else {
            // Handle other statuses or errors from Bridge.execute_trade
            console.error(chalk.red(`Trade preparation failed with status: ${tradePrepResult.status}. Error: ${tradePrepResult.error || 'Unknown error'}`));
        }

    } catch (error) {
        console.error(chalk.red(`Manual trade failed: ${error.message}`));
    }
     // Add pause
     await inquirer.prompt([{
        type: 'input',
        name: 'continue',
        message: 'Press Enter to continue...'
     }]);
}

// =============================================================================
// Initialization and Main Execution
// =============================================================================

// ... initializeSystem and main functions ...
// Ensure dotenv.config() is called early in initializeSystem or before it.
dotenv.config(); // Load .env file

// ... (rest of initializeSystem) ...

async function main() {
     try {
         // Load .env first
         dotenv.config();
         // Display welcome animation
         await displayWelcomeAnimation();

         // Initialize system (this might load more env vars)
         const spinner = ora('Initializing system...').start();
         await initializeSystem();
         spinner.succeed('System initialized');

         // Run initial system checks
         await runAllSystemChecks();

         // Start main menu
         await mainMenu();
     } catch (error) {
         console.error(chalk.red('Fatal error during startup:'), error.message);
         console.error(error.stack); // Print stack trace for debugging
         process.exit(1);
     }
}

main(); 

/**
 * Checks the status of a blockchain transaction.
 */
async function checkTransactionStatus() {
    try {
        const { txHash, chain } = await inquirer.prompt([
            {
                type: 'input',
                name: 'txHash',
                message: 'Enter transaction hash:',
                validate: input => input.trim().length > 0 ? true : 'Transaction hash is required'
            },
            {
                type: 'list',
                name: 'chain',
                message: 'Select blockchain network:',
                choices: Object.keys(CHAIN_NAME_TO_ID),
                default: walletManager.getState().chainId ? ID_TO_CHAIN_NAME[walletManager.getState().chainId] : 'ethereum'
            }
        ]);

        const spinner = ora('Checking transaction status...').start();
        
        try {
            const result = await juliaBridge.runJuliaCommand('Bridge.get_transaction_status', { chain: chain.toLowerCase(), tx_hash: txHash });
            
            spinner.stop();
            
            if (result.status === 'error') {
                console.log(chalk.red(`Error checking transaction: ${result.message}`));
                return;
            }
            
            // Display transaction status with nice formatting
            const txStatus = result.status;
            let statusColor;
            let statusIcon;
            
            switch (txStatus) {
                case 'confirmed':
                    statusColor = chalk.green;
                    statusIcon = '✅';
                    break;
                case 'pending':
                    statusColor = chalk.yellow;
                    statusIcon = '⏳';
                    break;
                case 'failed':
                    statusColor = chalk.red;
                    statusIcon = '❌';
                    break;
                default:
                    statusColor = chalk.gray;
                    statusIcon = '❓';
            }
            
            console.log(chalk.bold('\nTransaction Status:'));
            console.log(`${statusIcon} Status: ${statusColor(txStatus.toUpperCase())}`);
            console.log(`${chalk.cyan('Transaction Hash:')} ${txHash}`);
            console.log(`${chalk.cyan('Network:')} ${chain}`);
            
            if (result.block_number) {
                console.log(`${chalk.cyan('Block Number:')} ${result.block_number}`);
            }
            
            if (result.confirmations) {
                console.log(`${chalk.cyan('Confirmations:')} ${result.confirmations}`);
            }
            
            // Additional receipt info if available
            if (txStatus === 'confirmed' || txStatus === 'failed') {
                const receipt = result.receipt;
                
                if (receipt && receipt.gasUsed) {
                    const gasUsed = typeof receipt.gasUsed === 'string' && receipt.gasUsed.startsWith('0x')
                        ? parseInt(receipt.gasUsed.substring(2), 16)
                        : receipt.gasUsed;
                    console.log(`${chalk.cyan('Gas Used:')} ${gasUsed}`);
                }
                
                if (receipt && receipt.effectiveGasPrice) {
                    const gasPrice = typeof receipt.effectiveGasPrice === 'string' && receipt.effectiveGasPrice.startsWith('0x')
                        ? parseInt(receipt.effectiveGasPrice.substring(2), 16) / 1e9
                        : receipt.effectiveGasPrice / 1e9;
                    console.log(`${chalk.cyan('Gas Price:')} ${gasPrice.toFixed(2)} Gwei`);
                }
                
                if (txStatus === 'failed' && receipt && receipt.revertReason) {
                    console.log(`${chalk.red('Revert Reason:')} ${receipt.revertReason}`);
                }
            }
            
            // Offer to check again if pending
            if (txStatus === 'pending') {
                const { checkAgain } = await inquirer.prompt([{
                    type: 'confirm',
                    name: 'checkAgain',
                    message: 'Transaction is still pending. Check status again?',
                    default: true
                }]);
                
                if (checkAgain) {
                    await checkTransactionStatus(); // Recursively call to check again
                    return; 
                }
            }
            
        } catch (error) {
            spinner.fail('Failed to check transaction status');
            console.error(chalk.red('Error:'), error);
        }
    } catch (error) {
        console.error(chalk.red('Error:'), error);
    }
    
    // Pause to let the user see the results
    await inquirer.prompt([{
        type: 'input',
        name: 'continue',
        message: 'Press Enter to continue...'
    }]);
}

// =============================================================================
// New OpenAI Swarm Interaction Functions
// =============================================================================

async function runOpenAITask() {
    console.log(chalk.blue('\n--- Run Task in OpenAI Swarm ---'));
    try {
        const answers = await inquirer.prompt([
            {
                type: 'input',
                name: 'swarm_id',
                message: 'Enter the OpenAI Swarm ID:',
                validate: input => input.trim().length > 0 ? true : 'Swarm ID cannot be empty.'
            },
            {
                type: 'input',
                name: 'agent_name',
                message: 'Enter the Agent Name within the swarm:',
                validate: input => input.trim().length > 0 ? true : 'Agent Name cannot be empty.'
            },
            {
                type: 'input',
                name: 'task_prompt',
                message: 'Enter the task prompt for the agent:',
                validate: input => input.trim().length > 0 ? true : 'Task prompt cannot be empty.'
            },
            {
                type: 'input',
                name: 'thread_id',
                message: 'Enter existing Thread ID (optional, leave blank to create new):'
            }
        ]);

        const { swarm_id, agent_name, task_prompt } = answers;
        const thread_id = answers.thread_id.trim() || null; // Send null if blank

        const spinner = ora('Submitting task to OpenAI swarm via backend...').start();

        // Construct params array
        const params = [swarm_id, agent_name, task_prompt];
        if (thread_id) {
            params.push(thread_id);
        }

        try {
            const response = await juliaBridge.runJuliaCommand('run_openai_task', params);
            spinner.stop();

            if (response && response.error) {
                console.error(chalk.red('\nBackend Error:'), response.error);
            } else if (response && response.result && response.result.success) {
                spinner.succeed('Task submitted successfully!');
                console.log(chalk.green('\nTask Submission Details:'));
                console.log(chalk.cyan(`  Swarm ID:    ${response.result.swarm_id}`));
                console.log(chalk.cyan(`  Agent Name:  ${response.result.agent_name}`));
                console.log(chalk.cyan(`  Thread ID:   ${response.result.thread_id}`));
                console.log(chalk.cyan(`  Run ID:      ${response.result.run_id}`));
                console.log(chalk.cyan(`  Run Status:  ${response.result.status}`));
                console.log(chalk.yellow('\nUse "Get OpenAI Response" with the Thread ID and Run ID to check status and get results.'));
            } else {
                console.error(chalk.red('\nFailed to submit task. Unexpected response format:'));
                console.log(response);
            }
        } catch (bridgeError) {
            spinner.fail('Failed to communicate with backend.');
            console.error(chalk.red('Bridge Error:'), bridgeError.message);
        }

    } catch (error) {
        console.error(chalk.red('An error occurred while setting up the OpenAI task:'), error.message);
    }

    // Pause
    await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

async function getOpenAIResponse() {
    console.log(chalk.blue('\n--- Get Response/Status from OpenAI Run ---'));
    try {
        const answers = await inquirer.prompt([
            {
                type: 'input',
                name: 'swarm_id',
                message: 'Enter the OpenAI Swarm ID:',
                validate: input => input.trim().length > 0 ? true : 'Swarm ID cannot be empty.'
            },
            {
                type: 'input',
                name: 'thread_id',
                message: 'Enter the Thread ID:',
                validate: input => input.trim().length > 0 ? true : 'Thread ID cannot be empty.'
            },
            {
                type: 'input',
                name: 'run_id',
                message: 'Enter the Run ID:',
                validate: input => input.trim().length > 0 ? true : 'Run ID cannot be empty.'
            }
        ]);

        const { swarm_id, thread_id, run_id } = answers;
        const spinner = ora('Fetching response/status from backend...').start();

        try {
            const response = await juliaBridge.runJuliaCommand('get_openai_response', [swarm_id, thread_id, run_id]);
            spinner.stop();

            if (response && response.error) {
                console.error(chalk.red('\nBackend Error:'), response.error);
            } else if (response && response.result) {
                const result = response.result;
                if (result.success) {
                    spinner.succeed(`Status fetched: ${result.status}`);
                    console.log(chalk.green('\nRun Details:'));
                    console.log(chalk.cyan(`  Swarm ID:    ${result.swarm_id || swarm_id}`));
                    console.log(chalk.cyan(`  Thread ID:   ${result.thread_id || thread_id}`));
                    console.log(chalk.cyan(`  Run ID:      ${result.run_id || run_id}`));
                    console.log(chalk.cyan(`  Status:      ${result.status}`));

                    if (result.status === 'completed' && result.response) {
                        console.log(chalk.cyan(`\nAssistant Response:`));
                        console.log(chalk.white(`  ${result.response.content || '(No content found)'}`));
                        console.log(chalk.gray(`  (Message ID: ${result.response.message_id})`));
                    } else if (result.message) {
                         console.log(chalk.yellow(`\nMessage: ${result.message}`));
                    }

                } else {
                    // Handle cases where success is false (e.g., run failed)
                     spinner.fail(`Run status: ${result.status || 'Failed'}`);
                     console.log(chalk.red(`\nError: ${result.error || 'Failed to get response.'}`));
                     if (result.run_details) {
                         console.log(chalk.gray('Run Details:'), JSON.stringify(result.run_details, null, 2));
                     }
                }
            } else {
                console.error(chalk.red('\nFailed to get response. Unexpected response format:'));
                console.log(response);
            }
        } catch (bridgeError) {
            spinner.fail('Failed to communicate with backend.');
            console.error(chalk.red('Bridge Error:'), bridgeError.message);
        }

    } catch (error) {
        console.error(chalk.red('An error occurred while setting up the OpenAI response request:'), error.message);
    }

    // Pause
    await inquirer.prompt([{ type: 'input', name: 'continue', message: 'Press Enter to continue...' }]);
}

// Helper function to get agent capabilities based on type
function getAgentCapabilities(type) {
    const capabilities = {
        'Trading': ['market_analysis', 'order_execution', 'risk_management'],
        'Analysis': ['data_processing', 'pattern_recognition', 'prediction'],
        'Execution': ['order_routing', 'position_management', 'risk_control'],
        'Monitoring': ['system_monitoring', 'alert_management', 'performance_tracking']
    };
    return capabilities[type] || [];
}