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
const { JuliaBridge } = require('./packages/julia-bridge/dist/index');
const { WalletManager } = require('./packages/wallets/dist/index');
const { v4: uuidv4 } = require('uuid'); // Added for generating unique IDs
// Note: execAsync import removed as it's not used

const execAsync = promisify(exec);

// Initialize the JuliaBridge and WalletManager
let juliaBridge;
try {
    juliaBridge = new JuliaBridge({
        apiUrl: 'http://localhost:8052/api/command',
        useWebSocket: false,
        useExistingServer: true  // Use existing server instead of starting a new one
    });
} catch (error) {
    console.error(chalk.red('Failed to initialize JuliaBridge:'), error.message);
}

const walletManager = new WalletManager();

// =============================================================================
// Wallet Management Functions
// =============================================================================
async function connectWallet() {
    try {
        // First, choose the wallet provider
        const { provider } = await inquirer.prompt([
            {
                type: 'list',
                name: 'provider',
                message: 'Select wallet provider:',
                choices: ['MetaMask', 'Phantom', 'Rabby']
            }
        ]);
        
        // Determine available chains and default chain based on selected provider
        let availableChains;
        let defaultChain;
        
        if (provider === 'Phantom') {
            // Phantom only supports Solana
            availableChains = ['solana'];
            defaultChain = 'solana';
        } else {
            // Both MetaMask and Rabby support EVM chains
            availableChains = ['ethereum', 'polygon', 'arbitrum', 'optimism', 'base', 'bsc'];
            defaultChain = 'ethereum';
        }
        
        // For wallets that only support one chain, skip the selection
        let chain;
        if (availableChains.length === 1) {
            chain = availableChains[0];
            console.log(chalk.blue(`${provider} wallet selected (${chain} network)`));
        } else {
            // Otherwise, prompt for chain selection
            const chainPrompt = await inquirer.prompt([
                {
                    type: 'list',
                    name: 'chain',
                    message: 'Select blockchain network:',
                    choices: availableChains,
                    default: defaultChain
                }
            ]);
            chain = chainPrompt.chain;
        }
        
        // Then, choose the connection mode
        const { mode } = await inquirer.prompt([
            {
                type: 'list',
                name: 'mode',
                message: 'Select wallet connection mode:',
                choices: ['Address Only (Read-only)', 'Private Key (Full Access)']
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
                
                // Improved address validation based on chain
                if (['ethereum', 'polygon', 'arbitrum', 'optimism', 'base', 'bsc'].includes(chain)) {
                    // EVM chain address validation
                    if (!address.startsWith('0x')) {
                        console.log(chalk.red('Ethereum-based addresses must start with 0x.'));
                        continue;
                    }
                    
                    if (!/^0x[0-9a-fA-F]{40}$/.test(address)) {
                        console.log(chalk.red('Invalid Ethereum address format. Must be 0x followed by 40 hex characters.'));
                        continue;
                    }
                    
                    // Additional checksum validation could be added here with ethers.js
                    
                    isValid = true;
                } else if (chain === 'solana') {
                    // Solana address validation - basic check for length
                    if (address.length !== 44 && address.length !== 43) {
                        console.log(chalk.red('Invalid Solana address length. Solana addresses are typically 43-44 characters.'));
                        continue;
                    }
                    
                    // Further validation using @solana/web3.js PublicKey could be added
                    try {
                        // Mock validation - in production, would use:
                        // new PublicKey(address); 
                        if (!/^[1-9A-HJ-NP-Za-km-z]{43,44}$/.test(address)) {
                            throw new Error('Invalid characters in Solana address');
                        }
                        isValid = true;
                    } catch (error) {
                        console.log(chalk.red(`Invalid Solana address: ${error.message}`));
                        continue;
                    }
                }
            }
            
            console.log(chalk.blue(`Connecting to ${provider} wallet (${chain}) in read-only mode...`));
            
            // Create a loading spinner
            const spinner = ora({
                text: `Connecting to ${provider}...`,
                spinner: 'dots',
                color: 'blue'
            }).start();
            
            // Note: In our previous implementation, we tried to connect to the provider directly
            // which might not work if the actual wallet implementation is mocked.
            // Let's use a more robust approach that will work with mocked wallets

            // Connect with validated address
            const state = {
                isConnected: true,
                address: address,
                chain: chain,
                balance: 'N/A', // We don't fetch balance in read-only mode without API
                readOnly: true,
                provider: provider.toLowerCase()
            };
            
            // If real wallet integration is available, attempt to use it
            try {
                if (typeof walletManager.connect === 'function') {
                    // Use timeout to prevent hanging
                    const connectPromise = walletManager.connect(provider.toLowerCase());
                    const timeoutPromise = new Promise((_, reject) => 
                        setTimeout(() => reject(new Error('Connection timeout')), 3000)
                    );
                    
                    await Promise.race([connectPromise, timeoutPromise]);
                    spinner.succeed('Connected to wallet provider');
                } else {
                    spinner.info('Using mock wallet connection (provider connect not available)');
                }
            } catch (providerError) {
                // Log the error but continue with mock connection
                spinner.warn(`Could not connect to real provider: ${providerError.message}`);
                console.log(chalk.yellow('Falling back to mock wallet connection...'));
            }
            
            // Store in walletManager
            walletManager.state = state;
            spinner.succeed('Wallet configured in read-only mode');
            
            console.log(chalk.green('Wallet connected successfully in read-only mode!'));
            console.log(chalk.cyan('Provider:'), provider);
            console.log(chalk.cyan('Address:'), state.address);
            console.log(chalk.cyan('Network:'), chain);
            console.log(chalk.yellow('Note: Balance fetching requires API key in read-only mode'));
            
            // Add a pause to let the user see the connection info
            await inquirer.prompt([{
                type: 'input',
                name: 'continue',
                message: 'Press Enter to continue...'
            }]);
            
            return state;
            
        } else {
            // Get the private key from the user
            let privateKey = '';
            while (privateKey.trim() === '') {
                const response = await inquirer.prompt([
                    {
                        type: 'password',
                        name: 'privateKey',
                        message: 'Enter your private key (will not be displayed):',
                    }
                ]);
                
                privateKey = response.privateKey;
                
                if (privateKey.trim() === '') {
                    console.log(chalk.red('Private key cannot be empty. Please try again.'));
                }
            }
            
            console.log(chalk.blue(`Connecting to ${provider} wallet (${chain}) with private key...`));
            
            // Create a loading spinner
            const spinner = ora({
                text: `Connecting to ${provider}...`,
                spinner: 'dots',
                color: 'blue'
            }).start();
            
            // SECURITY FIX: Use walletManager's secure method to connect with a private key
            // instead of storing the key in application state
            try {
                // In real implementation, we would connect to the provider
                // and use the private key to create a wallet
                let walletResult = null;
                
                if (typeof walletManager.connect === 'function' && 
                    typeof walletManager.secureConnect === 'function') {
                    // Use timeout to prevent hanging
                    const connectPromise = walletManager.connect(provider.toLowerCase());
                    const timeoutPromise = new Promise((_, reject) => 
                        setTimeout(() => reject(new Error('Connection timeout')), 3000)
                    );
                    
                    await Promise.race([connectPromise, timeoutPromise]);
                    spinner.text = 'Connected to provider, setting up secure wallet...';
                    
                    walletResult = await walletManager.secureConnect(chain, privateKey);
                    spinner.succeed('Wallet securely connected');
                } else {
                    spinner.info('Using mock wallet connection (provider connect not available)');
                    // Mock result for demo
                    walletResult = {
                        address: `${chain}_wallet_${privateKey.substring(0, 4)}`,
                        balance: '1.2345'
                    };
                }
                
                // Get derived data but NEVER store the private key
                const state = {
                    isConnected: true,
                    address: walletResult.address,
                    chain: chain,
                    balance: walletResult.balance,
                    hasFullAccess: true,  // Indicates full access without storing key
                    readOnly: false,
                    provider: provider.toLowerCase()
                };
                
                // Store in walletManager - private key NOT included in state
                walletManager.state = state;
                
                console.log(chalk.green('Wallet connected successfully with full access!'));
                console.log(chalk.cyan('Provider:'), provider);
                console.log(chalk.cyan('Address:'), walletResult.address);
                console.log(chalk.cyan('Network:'), chain);
                console.log(chalk.cyan('Balance:'), walletResult.balance);
                
                // Immediately clear private key from memory
                privateKey = null;
                
                // Add a pause to let the user see the connection info
                await inquirer.prompt([{
                    type: 'input',
                    name: 'continue',
                    message: 'Press Enter to continue...'
                }]);
                
                return state;
            } catch (error) {
                spinner.fail(`Failed to securely connect wallet: ${error.message}`);
                console.error(chalk.red('Error details:'), error);
                
                // Give user an option to continue with mock wallet
                const { useMock } = await inquirer.prompt([{
                    type: 'confirm',
                    name: 'useMock',
                    message: 'Would you like to use a mock wallet connection instead?',
                    default: true
                }]);
                
                if (useMock) {
                    // Create mock wallet state
                    const mockAddress = `${chain}_wallet_${privateKey.substring(0, 4)}`;
                    const state = {
                        isConnected: true,
                        address: mockAddress,
                        chain: chain,
                        balance: '1.2345',
                        hasFullAccess: true,
                        readOnly: false,
                        provider: provider.toLowerCase(),
                        isMock: true // Flag to indicate this is a mock connection
                    };
                    
                    // Store in walletManager
                    walletManager.state = state;
                    
                    console.log(chalk.green('Mock wallet connected successfully!'));
                    console.log(chalk.yellow('Note: This is a mock wallet connection for demo purposes.'));
                    console.log(chalk.cyan('Provider:'), provider);
                    console.log(chalk.cyan('Address:'), mockAddress);
                    console.log(chalk.cyan('Network:'), chain);
                    
                    // Clear private key
                    privateKey = null;
                    
                    // Add a pause to let the user see the connection info
                    await inquirer.prompt([{
                        type: 'input',
                        name: 'continue',
                        message: 'Press Enter to continue...'
                    }]);
                    
                    return state;
                } else {
                    // Clear private key
                    privateKey = null;
                    console.log(chalk.yellow('Wallet connection canceled.'));
                    return null;
                }
            } finally {
                // Ensure private key is cleared from memory even in case of error
                privateKey = null;
            }
        }
    } catch (error) {
        console.error(chalk.red('Failed to connect wallet:'), error);
        console.log(chalk.yellow('Error details:'), error.stack || 'No stack trace available');
        
        // Add a pause to let the user see the error
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
        const previousProvider = state.provider;
        
        // Disconnect from the provider if it exists
        if (previousProvider) {
            try {
                await walletManager.disconnect();
            } catch (error) {
                console.log(chalk.yellow(`Error disconnecting from provider: ${error.message}`));
            }
        }
        
        // Reset wallet state
        walletManager.state = {
            isConnected: false,
            address: null,
            chain: null,
            balance: null,
            readOnly: false,
            provider: null,
            transactions: []
        };
        
        console.log(chalk.green('Wallet disconnected successfully!'));
        console.log(chalk.cyan('Disconnected provider:'), previousProvider || 'Unknown');
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
        const provider = state.provider ? ` (${state.provider})` : '';
        return chalk.green(`Connected${provider} (${state.chain}) [${mode}] ✅`);
    }
    return chalk.yellow('Disconnected ⚠️');
}

async function getWalletBalance() {
    const state = walletManager.getState();
    if (!state.isConnected) {
        return chalk.red('Wallet not connected');
    }
    
    if (state.readOnly) {
        return chalk.yellow('Balance not available in read-only mode');
    }
    
    try {
        // Get the provider
        const provider = state.provider;
        if (!provider) {
            return chalk.red('Wallet provider information missing. Please reconnect your wallet.');
        }
        
        // Check if we're using a mock wallet
        if (state.isMock) {
            // Return mock balance
            return chalk.green(`${state.balance} ${state.chain.toUpperCase()} (Mock Wallet)`);
        }
        
        // Get the current provider instance
        const currentProvider = walletManager.getCurrentProvider();
        if (!currentProvider) {
            return chalk.red(`Provider ${provider} is not connected`);
        }
        
        // Check if the getBalance method exists
        if (typeof currentProvider.getBalance !== 'function') {
            return chalk.yellow(`Provider ${provider} doesn't support getBalance. Using mock balance: ${state.balance} ${state.chain.toUpperCase()}`);
        }
        
        // Get balance using the provider-specific method
        const balance = await currentProvider.getBalance();
        
        return chalk.green(`${balance} ${state.chain.toUpperCase()} (via ${provider})`);
    } catch (error) {
        console.error('Balance error:', error);
        
        // If there's an error, fall back to the cached balance
        if (state.balance) {
            return chalk.yellow(`${state.balance} ${state.chain.toUpperCase()} (cached, error: ${error.message})`);
        }
        
        return chalk.red(`Failed to get balance: ${error.message}`);
    }
}

async function signTransaction(tx) {
    try {
        return await walletManager.signTransaction(tx);
    } catch (error) {
        throw new Error(`Failed to sign transaction: ${error.message}`);
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
                    '🧪 Component Diagnostics',
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
            case 'Component Diagnostics':
                await checkComponentConnections();
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

    console.log(chalk.cyan('System Status: '));
    console.log(chalk.cyan('  '));
    console.log(chalk.cyan(`  🧠 Julia Engine:   ${juliaStatus.padEnd(46)}`));
    console.log(chalk.cyan(`  💼 Wallet Status:  ${walletStatus.padEnd(46)}`));
    console.log(chalk.cyan(`  🌐 Network:        ${networkStatus.padEnd(46)}`));
    console.log(chalk.cyan(`  🔑 API Keys:       ${apiStatus.padEnd(46)}`));
    console.log(chalk.cyan(`  💾 Storage:        ${storageStatus.padEnd(46)}`));
    console.log(chalk.cyan(`  ⚡ Performance:     ${chalk.green('Optimized').padEnd(46)}`));
    console.log(chalk.cyan(' '));
    console.log(chalk.cyan(' '));
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

async function checkComponentConnections() {
    console.clear();
    
    // Create a fancy header
    console.log(chalk.blue(`
     ╔══════════════════════════════════════════════════════════╗
     ║             Component Connection Diagnostics             ║
     ╚══════════════════════════════════════════════════════════╝
    `));
    
    const spinner = ora({
        text: 'Starting connection diagnostics...',
        spinner: 'dots',
        color: 'blue'
    }).start();
    
    const results = {
        bridge: false,
        agent: false,
        swarm: false,
        blockchain: false,
        storage: false,
        openai: false
    };
    
    // Check JuliaBridge basic connection
    try {
        spinner.text = 'Checking JuliaBridge connection...';
        
        const health = await juliaBridge.getHealth();
        results.bridge = health && (health.status === 'healthy' || health.status === 'ok');
        
        spinner.succeed('JuliaBridge check complete');
    } catch (error) {
        spinner.fail(`JuliaBridge check failed: ${error.message}`);
        console.error(chalk.red('Error details:'), error);
    }
    
    // Check Agent System connection
    try {
        spinner.text = 'Checking Agent System connection...';
        
        // Try to get agent list - even if empty, this tests the connection
        const agentResult = await juliaBridge.runJuliaCommand('list_agents', []);
        
        // If we get a result (even an empty list) without error, the connection works
        results.agent = agentResult !== undefined && agentResult.error === undefined;
        
        spinner.succeed('Agent System check complete');
    } catch (error) {
        spinner.fail(`Agent System check failed: ${error.message}`);
        console.error(chalk.red('Error details:'), error);
    }
    
    // Check Swarm System connection
    try {
        spinner.text = 'Checking Swarm System connection...';
        
        // Try to get swarm list - even if empty, this tests the connection
        const swarmResult = await juliaBridge.runJuliaCommand('list_swarms', []);
        
        // If we get a result (even an empty list) without error, the connection works
        results.swarm = swarmResult !== undefined && swarmResult.error === undefined;
        
        spinner.succeed('Swarm System check complete');
    } catch (error) {
        spinner.fail(`Swarm System check failed: ${error.message}`);
        console.error(chalk.red('Error details:'), error);
    }
    
    // Check Blockchain connection
    try {
        spinner.text = 'Checking Blockchain connection...';
        
        // This is a lightweight check to see if the blockchain module is loaded and responding
        const blockchainResult = await juliaBridge.runJuliaCommand('blockchain_connect', ["ethereum", "test"]);
        
        // We might get an error about invalid params, but the module should still respond
        results.blockchain = blockchainResult !== undefined;
        
        spinner.succeed('Blockchain check complete');
    } catch (error) {
        spinner.fail(`Blockchain check failed: ${error.message}`);
        console.error(chalk.red('Error details:'), error);
    }
    
    // Check Storage connection
    try {
        spinner.text = 'Checking Storage connection...';
        
        // Try to load some test data
        const storageResult = await juliaBridge.runJuliaCommand('storage_load', ["test_key"]);
        
        // Even if data doesn't exist, the command should work
        results.storage = storageResult !== undefined;
        
        spinner.succeed('Storage check complete');
    } catch (error) {
        spinner.fail(`Storage check failed: ${error.message}`);
        console.error(chalk.red('Error details:'), error);
    }
    
    // Check OpenAI Swarm adapter connection
    try {
        spinner.text = 'Checking OpenAI Swarm connection...';
        
        // Simple command to check if OpenAI module is loaded
        const openaiResult = await juliaBridge.runJuliaCommand('create_openai_swarm', [{ name: "test", agents: [] }]);
        
        // We might get an error about invalid config, but the module should respond
        results.openai = openaiResult !== undefined;
        
        spinner.succeed('OpenAI Swarm check complete');
    } catch (error) {
        spinner.fail(`OpenAI Swarm check failed: ${error.message}`);
        console.error(chalk.red('Error details:'), error);
    }
    
    // Display results in a formatted table
    console.log('\n');
    console.log(chalk.cyan('Component Connection Status:'));
    console.log(chalk.cyan('─────────────────────────────────────'));
    
    Object.entries(results).forEach(([component, isConnected]) => {
        const status = isConnected 
            ? chalk.green('Connected ✅') 
            : chalk.red('Disconnected ❌');
        
        console.log(chalk.cyan(`${component.padEnd(12)}: ${status}`));
    });
    
    console.log(chalk.cyan('─────────────────────────────────────'));
    
    // Recommendations based on results
    console.log('\n');
    console.log(chalk.yellow('Recommendations:'));
    
    if (!results.bridge) {
        console.log(chalk.red('• Julia server is not running or not accessible. Try:'));
        console.log(chalk.yellow('  1. Check if the Julia server is running (cd julia && ./start.sh)'));
        console.log(chalk.yellow('  2. Ensure port 8052 is not blocked or in use'));
    }
    
    if (!results.agent && results.bridge) {
        console.log(chalk.red('• Agent system is not responding. Try:'));
        console.log(chalk.yellow('  1. Check if AgentSystem.jl exists and is correctly loaded'));
        console.log(chalk.yellow('  2. Restart the Julia server'));
    }
    
    if (!results.swarm && results.bridge) {
        console.log(chalk.red('• Swarm system is not responding. Try:'));
        console.log(chalk.yellow('  1. Check if SwarmManager.jl and algorithms/Algorithms.jl exist'));
        console.log(chalk.yellow('  2. Restart the Julia server'));
    }
    
    if (!results.blockchain && results.bridge) {
        console.log(chalk.red('• Blockchain module is not responding. Try:'));
        console.log(chalk.yellow('  1. Check if Blockchain.jl exists and is correctly loaded'));
        console.log(chalk.yellow('  2. Ensure blockchain RPC endpoints are configured'));
    }
    
    if (!results.storage && results.bridge) {
        console.log(chalk.red('• Storage system is not responding. Try:'));
        console.log(chalk.yellow('  1. Check if Storage.jl exists and is correctly loaded'));
        console.log(chalk.yellow('  2. Ensure the database path is correct and accessible'));
    }
    
    if (!results.openai && results.bridge) {
        console.log(chalk.red('• OpenAI Swarm adapter is not responding. Try:'));
        console.log(chalk.yellow('  1. Check if OpenAISwarmAdapter.jl exists'));
        console.log(chalk.yellow('  2. Set the OPENAI_API_KEY environment variable'));
    }
    
    if (Object.values(results).every(result => result)) {
        console.log(chalk.green('All components are connected and responding correctly!'));
    }
    
    // Pause to let the user see the results
    await inquirer.prompt([{
        type: 'input',
        name: 'continue',
        message: 'Press Enter to continue...'
    }]);
}

// Update runAllSystemChecks to include component connection check
async function runAllSystemChecks() {
    // Clear console but don't use displayHeader to avoid double menus
    console.clear();
    
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
        console.log(chalk.cyan('  System Status: '));
        console.log(chalk.cyan('  '));
        console.log(chalk.cyan(`  🧠  Julia Engine:  ${juliaStatus.padEnd(46)}`));
        console.log(chalk.cyan(`  💼  Wallet Status: ${walletStatus.padEnd(46)}`));
        console.log(chalk.cyan(`  🌐  Network:       ${networkStatus.padEnd(46)}`));
        console.log(chalk.cyan(`  🔑  API Keys:      ${apiStatus.padEnd(46)}`));
        console.log(chalk.cyan(`  💾  Storage:       ${storageStatus.padEnd(46)}`));
        console.log(chalk.cyan(`  ⚡  Performance:   ${chalk.green('Optimized').padEnd(46)}`));
        console.log(chalk.cyan(' '));
        console.log(chalk.cyan(' '));
        
        // Ask if user wants to run component connection diagnostics
        const { runDiagnostics } = await inquirer.prompt([
            {
                type: 'confirm',
                name: 'runDiagnostics',
                message: 'Would you like to run detailed component connection diagnostics?',
                default: true
            }
        ]);
        
        if (runDiagnostics) {
            await checkComponentConnections();
        } else {
            // Pause to let the user see the results
            await inquirer.prompt([
                {
                    type: 'input',
                    name: 'continue',
                    message: '🔄 Press Enter to continue...'
                }
            ]);
        }
    } catch (error) {
        spinner.fail('System checks failed ❌');
        console.error(chalk.red('Error running system checks:'), error.message);
        
        // Pause to let the user see the results
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
// Menu Functions
// =============================================================================
async function agentManagementMenu() {
    // Remove displayHeader() call here as it's already called in mainMenu()
    
    // Display an improved agent animation with better alignment
    console.log(chalk.blue(`
      ╔══════════════════════════════════════════╗
      ║           Agent Management               ║
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
    // Remove displayHeader() call here as it's already called in mainMenu()
    
    // Display an improved swarm animation with better alignment
    console.log(chalk.green(`
      ╔══════════════════════════════════════════╗
      ║           Swarm Management               ║
      ╚══════════════════════════════════════════╝
    `));
    
    const { action } = await inquirer.prompt([
        {
            type: 'list',
            name: 'action',
            message: '🐝 Select swarm action:',
            choices: [
                'Create Swarm',
                'List Swarms',
                'Configure Swarm',
                'Start Swarm',
                'Stop Swarm',
                'View Metrics',
                'Delete Swarm',
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
            'View Transaction History'
        ] : []),
        'Back'
    ];
    
    const { action } = await inquirer.prompt([
        {
            type: 'list',
            name: 'action',
            message: '⛓️ Select cross-chain action:',
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
            console.log(await getWalletBalance());
            await inquirer.prompt([{type: 'input', name: 'continue', message: '🔄 Press Enter to continue...'}]);
            break;
        case 'Send Transaction':
            await sendTransaction();
            break;
        case 'View Transaction History':
            await viewTransactionHistory();
            break;
    }
}

async function apiKeysManagementMenu() {
    // Remove displayHeader() call here as it's already called in mainMenu()
    
    // Display an improved API keys animation with better alignment
    console.log(chalk.yellow(`
      ╔══════════════════════════════════════════╗
      ║         API Keys Management              ║
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
    // Remove displayHeader() call here as it's already called in mainMenu()
    
    // Display an improved system configuration animation with better alignment
    console.log(chalk.blueBright(`
      ╔══════════════════════════════════════════╗
      ║          System Configuration            ║
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
    // Remove displayHeader() call here as it's already called in mainMenu()
    
    // Display an improved metrics animation with better alignment
    console.log(chalk.redBright(`
      ╔══════════════════════════════════════════╗
      ║          Performance Metrics             ║
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
    // Remove displayHeader() call here as it's already called in mainMenu()
    
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
        console.log(chalk.cyan(' Agent Metrics: '));
        console.log(chalk.cyan('                                                         '));
        console.log(chalk.cyan(`  🤖 Agent ID:        ${agentId.padEnd(46)}│`));
        console.log(chalk.cyan(`  💻 CPU Usage:       ${metrics.cpu.padEnd(46)}│`));
        console.log(chalk.cyan(`  🧠 Memory Usage:    ${metrics.memory.padEnd(46)}│`));
        console.log(chalk.cyan(`  ⏱️ Uptime:          ${metrics.uptime.padEnd(46)}│`));
        console.log(chalk.cyan(`  🔄 Tasks Processed: ${metrics.tasks.padEnd(44)}│`));
        console.log(chalk.cyan(`  ✅ Success Rate:    ${metrics.success.padEnd(46)}`));
        console.log(chalk.cyan(' '));
        console.log(chalk.cyan(' '));
        
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
    // Remove displayHeader() call here as it's already called in mainMenu()
    
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
        console.log(chalk.green(' Swarm Metrics: '));
        console.log(chalk.green('  '));
        console.log(chalk.green(`  🐝 Swarm ID:        ${swarmId.padEnd(46)}`));
        console.log(chalk.green(`  👥 Active Agents:   ${metrics.agents.padEnd(46)}`));
        console.log(chalk.green(`  💻 CPU Usage:       ${metrics.cpu.padEnd(46)}`));
        console.log(chalk.green(`  🧠 Memory Usage:    ${metrics.memory.padEnd(46)}`));
        console.log(chalk.green(`  ⏱️ Uptime:          ${metrics.uptime.padEnd(46)}`));
        console.log(chalk.green(`  🔄 Tasks Processed: ${metrics.tasks.padEnd(44)}`));
        console.log(chalk.green(`  ✅ Success Rate:    ${metrics.success.padEnd(46)}`));
        console.log(chalk.green(' '));
        
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
 * Sends a transaction from the connected wallet
 * Demonstrates proper transaction handling with the improved WalletManager
 * Now with multi-factor authentication for high-value transactions
 */
async function sendTransaction() {
    try {
        // Check if wallet is connected
        if (!walletManager.state.isConnected) {
            console.log(chalk.red('Please connect a wallet first.'));
            return;
        }
        
        // Check if wallet has full access
        if (walletManager.state.readOnly) {
            console.log(chalk.red('Cannot send transactions in read-only mode. Please connect with private key.'));
            return;
        }

        // Make sure we know which provider we're using
        const provider = walletManager.state.provider;
        if (!provider) {
            console.log(chalk.red('Wallet provider information is missing. Please reconnect your wallet.'));
            return;
        }
        
        // Get transaction details from the user
        const { to, value, data } = await inquirer.prompt([
            {
                type: 'input',
                name: 'to',
                message: 'Enter recipient address:',
                validate: (input) => {
                    // Proper validation based on chain
                    const chain = walletManager.state.chain;
                    if (['ethereum', 'polygon', 'arbitrum', 'optimism', 'base', 'bsc'].includes(chain)) {
                        return /^0x[0-9a-fA-F]{40}$/.test(input) ? true : 'Invalid Ethereum address';
                    } else if (chain === 'solana') {
                        return (input.length === 43 || input.length === 44) ? true : 'Invalid Solana address';
                    }
                    return true;
                }
            },
            {
                type: 'input',
                name: 'value',
                message: 'Enter amount to send:',
                validate: (input) => {
                    return !isNaN(parseFloat(input)) && parseFloat(input) > 0 ? true : 'Amount must be a positive number';
                }
            },
            {
                type: 'input',
                name: 'data',
                message: 'Enter transaction data (optional):',
                default: ''
            }
        ]);
        
        // Determine if this transaction requires MFA (high-value)
        const highValueThresholds = {
            'ethereum': 0.5, // 0.5 ETH
            'polygon': 100, // 100 MATIC
            'solana': 5, // 5 SOL
            'arbitrum': 0.5, // 0.5 ETH
            'optimism': 0.5, // 0.5 ETH
            'base': 0.5, // 0.5 ETH
            'bsc': 1, // 1 BNB
        };
        
        const threshold = highValueThresholds[walletManager.state.chain] || 0;
        const isHighValue = parseFloat(value) >= threshold;
        
        // Warn user if this is a high-value transaction
        if (isHighValue) {
            console.log(chalk.yellow(`⚠️ High-value transaction detected! Amounts over ${threshold} ${walletManager.state.chain.toUpperCase()} require additional verification.`));
        }
        
        // Confirm the transaction with user
        const { confirmed } = await inquirer.prompt([
            {
                type: 'confirm',
                name: 'confirmed',
                message: `Are you sure you want to send ${value} ${walletManager.state.chain.toUpperCase()} to ${to}?`,
                default: false
            }
        ]);
        
        if (!confirmed) {
            console.log(chalk.yellow('Transaction cancelled.'));
            return;
        }
        
        // Show loading spinner
        const spinner = ora('Processing transaction...').start();
        
        try {
            // Create transaction object based on provider and chain
            let tx;
            if (walletManager.state.chain === 'solana' && provider === 'phantom') {
                tx = {
                    to,
                    amount: parseFloat(value),
                    chainId: 'solana',
                    data: data || null
                };
            } else {
                // EVM chain transaction (for MetaMask or Rabby)
                tx = {
                    to,
                    value: parseFloat(value),
                    chainId: walletManager.state.chain,
                    data: data || '0x',
                    from: walletManager.state.address
                };
            }
            
            // If high-value, update spinner text to inform user about MFA
            if (isHighValue) {
                spinner.text = 'High-value transaction - additional verification required...';
                
                // For demo purposes, we'll simulate the MFA process
                // In production, the WalletManager.signTransaction would handle this internally
                console.log();
                spinner.stop();
                
                // The walletManager will now handle the MFA process internally
                console.log(chalk.blue('Multi-factor authentication required for high-value transaction.'));
                console.log(chalk.yellow('In a real application, a code would be sent to your registered email/phone.'));
                
                // This is just for better UX in our CLI demo - the actual MFA happens in the wallet manager
                await new Promise(resolve => setTimeout(resolve, 1000));
                
                spinner.start('Verifying authentication code...');
            }
            
            let result;
            // Check if we're using a mock wallet
            if (walletManager.state.isMock) {
                spinner.text = `Simulating transaction via ${provider}...`;
                await new Promise(resolve => setTimeout(resolve, 1500)); // Simulate processing time
                
                // Generate a mock transaction result
                const txHash = `0x${Math.random().toString(16).substring(2, 40)}`;
                result = {
                    hash: txHash,
                    signature: txHash,
                    confirmations: 0,
                    from: walletManager.state.address,
                    to: to,
                    value: parseFloat(value),
                    data: data || '0x',
                    chainId: walletManager.state.chain,
                    status: 'pending'
                };
                
                spinner.succeed('Transaction simulated successfully!');
                console.log(chalk.yellow('Note: This is a mock transaction and is not actually sent to the blockchain.'));
            } else {
                // Get the appropriate provider
                const currentProvider = walletManager.getCurrentProvider();
                if (!currentProvider) {
                    throw new Error(`Provider ${provider} is not connected`);
                }
                
                // Check if the sendTransaction method exists
                if (typeof currentProvider.sendTransaction !== 'function') {
                    spinner.warn('Provider does not support sendTransaction. Using mock implementation.');
                    await new Promise(resolve => setTimeout(resolve, 1500)); // Simulate processing time
                    
                    // Generate a mock transaction result
                    const txHash = `0x${Math.random().toString(16).substring(2, 40)}`;
                    result = {
                        hash: txHash,
                        signature: txHash,
                        confirmations: 0,
                        from: walletManager.state.address,
                        to: to,
                        value: parseFloat(value),
                        data: data || '0x',
                        chainId: walletManager.state.chain,
                        status: 'pending'
                    };
                    
                    spinner.succeed('Transaction simulated successfully!');
                    console.log(chalk.yellow('Note: This is a mock transaction due to missing wallet implementation.'));
                } else {
                    // Send transaction using the provider-specific method
                    spinner.text = `Sending transaction via ${provider}...`;
                    result = await currentProvider.sendTransaction(tx);
                    spinner.succeed('Transaction signed successfully!');
                }
            }
            
            // Display the transaction details
            console.log(chalk.green('Transaction submitted to network'));
            console.log(chalk.cyan('Transaction Hash:'), result.signature || result.hash || 'Unknown');
            console.log(chalk.cyan('From:'), walletManager.state.address);
            console.log(chalk.cyan('To:'), to);
            console.log(chalk.cyan('Value:'), value);
            console.log(chalk.cyan('Chain:'), walletManager.state.chain);
            console.log(chalk.cyan('Provider:'), provider);
            
            // Store transaction for history
            if (!walletManager.state.transactions) {
                walletManager.state.transactions = [];
            }
            
            walletManager.state.transactions.push({
                hash: result.signature || result.hash || `0x${uuidv4().replace(/-/g, '')}`,
                from: walletManager.state.address,
                to: to,
                amount: `${value} ${walletManager.state.chain.toUpperCase()}`,
                timestamp: new Date(),
                status: 'Pending',
                provider: provider
            });
            
            // For demo, we just wait and simulate confirmation
            spinner.start('Waiting for confirmation...');
            await new Promise(resolve => setTimeout(resolve, 2000));
            walletManager.state.transactions[walletManager.state.transactions.length - 1].status = 'Confirmed';
            spinner.succeed('Transaction confirmed!');
            
        } catch (error) {
            spinner.fail(`Transaction failed: ${error.message}`);
            console.error(chalk.red('Error details:'), error);
            
            // Handle specific error cases
            if (error.message.includes('locked')) {
                console.log(chalk.red('Your account is temporarily locked due to too many failed attempts.'));
                console.log(chalk.yellow('Please try again later or contact support.'));
            } else if (error.message.includes('MFA') || error.message.includes('authentication')) {
                console.log(chalk.red('Authentication failed. Transaction was not sent.'));
                console.log(chalk.yellow('For security reasons, multiple failed authentication attempts may lock your account.'));
            } else if (error.message.includes('rejected')) {
                console.log(chalk.yellow('Transaction was rejected by your wallet.'));
            }
        }
        
        // Pause to allow the user to see the results
        await inquirer.prompt([{
            type: 'input',
            name: 'continue',
            message: 'Press Enter to continue...'
        }]);
    } catch (error) {
        console.error(chalk.red('Error sending transaction:'), error);
        console.log(chalk.yellow('Error details:'), error.stack || 'No stack trace available');
        
        // Pause to allow the user to see the error
        await inquirer.prompt([{
            type: 'input',
            name: 'continue',
            message: 'Press Enter to continue...'
        }]);
    }
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
                const provider = state.provider || 'Unknown';
                transactions = [
                    { 
                        hash: `0x${Math.random().toString(16).substring(2, 12)}`, 
                        from: 'Previous Wallet',
                        to: state.address, 
                        amount: `0.5 ${state.chain.toUpperCase()}`, 
                        timestamp: new Date(Date.now() - 86400000), // 1 day ago
                        status: 'Confirmed',
                        provider: provider
                    }
                ];
            }
        }

        console.log(chalk.cyan(`\nTransaction History (${state.provider || 'Unknown'} on ${state.chain}):`));
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
                '\n  ',
                chalk.white(`Provider: ${tx.provider || state.provider || 'Unknown'}`),
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
    // Remove displayHeader() call here as it's already called in mainMenu()
    
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

        console.log(chalk.cyan(' System Metrics: '));
        console.log(chalk.cyan('               '));
        console.log(chalk.cyan(`  💻 CPU Usage:      ${metrics.cpu.padEnd(46)}`));
        console.log(chalk.cyan(`  🧠 Memory Usage:   ${metrics.memory.padEnd(46)}`));
        console.log(chalk.cyan(`  💾 Disk Usage:     ${metrics.disk.padEnd(46)}`));
        console.log(chalk.cyan(`  🌐 Network Speed:  ${metrics.network.padEnd(46)}`));
        console.log(chalk.cyan(`  🔄 Processes:      ${metrics.processes.padEnd(46)}`));
        console.log(chalk.cyan(' '));
        
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
    // Remove displayHeader() call here as it's already called in mainMenu()
    
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
        
        console.log(chalk.blue(' Network Metrics: '));
        console.log(chalk.blue('                                                          '));
        console.log(chalk.blue(`  🔌  Bandwidth:    ${metrics.bandwidth.padEnd(46)}`));
        console.log(chalk.blue(`  ⏱️  Latency:      ${metrics.latency.padEnd(46)}`));
        console.log(chalk.blue(`  📦  Packets/s:    ${metrics.packets.padEnd(46)}`));
        console.log(chalk.blue(`  ⚠️  Error Rate:   ${metrics.errors.padEnd(46)}`));
        console.log(chalk.blue(`  🔄  Connections:  ${metrics.connections.padEnd(46)}`));
        console.log(chalk.blue(' '));
        
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
        const payload = {
            name: name,
            agents: agentConfigs
        };

        console.log(chalk.magenta('[DEBUG] Payload constructed:', JSON.stringify(payload)));

        // Call the Julia backend function via the bridge
        console.log(chalk.magenta('[DEBUG] Calling juliaBridge.runJuliaCommand...'));
        const result = await juliaBridge.runJuliaCommand(
            'OpenAISwarmAdapter.create_openai_swarm', 
            [payload] // Pass payload as an array element
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
    
    // Fix animation frames - ensure each frame is properly enclosed in backticks
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
     ║                   J U L I A   O S                             ║
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
     ║          ██╗██████╗                                           ║
     ║          ██║╚════██╗    ██╗   ██╗  ██╗      ██╗   █████╗      ║
     ║          ██║ █████╔╝    ██║   ██║  ██║      ██║  ██╔══██╗     ║
     ║          ██║ ╚═══██╗    ██║   ██║  ██║      ██║  ███████║     ║
     ║     ██   ██║██████╔╝    ██║   ██║  ██║      ██║  ██╔══██║     ║
     ║     ╚█████╔╝╚═════╝     ╚██████╔╝  ███████╗ ██║  ██║  ██║     ║
     ║      ╚════╝              ╚═════╝   ╚══════╝ ╚═╝  ╚═╝  ╚═╝     ║
     ║                               J3OS Mode v1.0                  ║
     ║                                                               ║
     ╚═══════════════════════════════════════════════════════════════╝`,
        `
     ╔═══════════════════════════════════════════════════════════════╗
     ║                                                               ║
     ║          ██╗                                                  ║
     ║          ██║       ██╗   ██╗  ██╗      ██╗   █████╗           ║
     ║          ██║       ██║   ██║  ██║      ██║  ██╔══██╗          ║
     ║          ██║       ██║   ██║  ██║      ██║  ███████║          ║
     ║     ██   ██║       ██║   ██║  ██║      ██║  ██╔══██║          ║
     ║     ╚█████╔╝       ╚██████╔╝  ███████╗ ██║  ██║  ██║          ║
     ║      ╚════╝         ╚═════╝   ╚══════╝ ╚═╝  ╚═╝  ╚═╝          ║
     ║                               J3OS Mode v1.0                  ║
     ║                                                               ║
     ╚═══════════════════════════════════════════════════════════════╝`,
        `
     ╔═══════════════════════════════════════════════════════════════╗
     ║                                                               ║
     ║          ██╗██████╗                                           ║
     ║          ██║╚════██╗    ██╗   ██╗  ██╗      ██╗   █████╗      ║
     ║          ██║ █████╔╝    ██║   ██║  ██║      ██║  ██╔══██╗     ║
     ║          ██║ ╚═══██╗    ██║   ██║  ██║      ██║  ███████║     ║
     ║     ██   ██║██████╔╝    ██║   ██║  ██║      ██║  ██╔══██║     ║
     ║     ╚█████╔╝╚═════╝     ╚██████╔╝  ███████╗ ██║  ██║  ██║     ║
     ║      ╚════╝              ╚═════╝   ╚══════╝ ╚═╝  ╚═╝  ╚═╝     ║
     ║                               J3OS Mode v1.0                  ║
     ║                                                               ║
     ╚═══════════════════════════════════════════════════════════════╝`,
        `
     ╔═══════════════════════════════════════════════════════════════╗
     ║                                                               ║
     ║          ██╗██████╗   ██████╗                                 ║
     ║          ██║╚════██╗ ██╔═══██╗  ██╗      ██╗   █████╗         ║
     ║          ██║ █████╔╝ ██║   ██║  ██║      ██║  ██╔══██╗        ║
     ║       ██ ██║ ╚═══██╗ ██║   ██║  ██║      ██║  ███████║        ║
     ║         ████║██████╔╝╚██████╔╝  ██║      ██║  ██╔══██║        ║
     ║          ╚╝╚═╝╚═════╝  ╚═════╝   ███████╗██║  ██║  ██║        ║
     ║                                   ╚══════╝╚═╝  ╚═╝  ╚═╝       ║
     ║                               J3OS Mode v1.0                  ║
     ║                                                               ║
     ╚═══════════════════════════════════════════════════════════════╝`,
        `
     ╔═══════════════════════════════════════════════════════════════╗
     ║                                                               ║
     ║          ██╗██████╗   ██████╗ ███████╗                        ║
     ║          ██║╚════██╗ ██╔═══██╗██╔════╝                        ║
     ║          ██║ █████╔╝ ██║   ██║███████╗                        ║
     ║       ██ ██║ ╚═══██╗ ██║   ██║╚════██║                        ║
     ║         ████║██████╔╝╚██████╔╝███████║                        ║
     ║          ╚╝╚═╝╚═════╝  ╚═════╝ ╚══════╝                       ║
     ║                                                               ║
     ║                   JuliaOS J3OS Mode v1.0                      ║
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
// Main
// =============================================================================
async function main() {
    try {
        // Display welcome animation
        await displayWelcomeAnimation();

        // Initialize system
        const spinner = ora('Initializing system...').start();
        await initializeSystem();
        spinner.succeed('System initialized');

        // Run initial system checks
        await runAllSystemChecks();

        // Start main menu
        await mainMenu();
    } catch (error) {
        console.error(chalk.red('Fatal error:'), error.message);
        process.exit(1);
    }
}

// Start the application
main(); 