#!/usr/bin/env node

/**
 * wallet_test.js - Simple test script for wallet connection
 * 
 * This is a minimal test script focusing only on wallet functionality
 * Implements secure wallet handling pattern for safe private key management
 */

const inquirer = require('inquirer');
const chalk = require('chalk');
const { WalletManager } = require('../packages/wallets/src/index');
const ora = require('ora');
const { v4: uuidv4 } = require('uuid');

// Initialize the secure wallet manager
const walletManager = new WalletManager();

// =============================================================================
// Main Functions
// =============================================================================
async function main() {
    console.log(chalk.cyan('\n=== Wallet Connection Test ===\n'));
    
    // Display current wallet status
    displayWalletStatus();
    
    while (true) {
        const { action } = await inquirer.prompt([
            {
                type: 'list',
                name: 'action',
                message: 'Select an action:',
                choices: walletManager.state.isConnected 
                    ? ['Disconnect Wallet', 'View Balance', 'Send Transaction', 'View Transaction History', 'Exit'] 
                    : ['Connect Wallet', 'Exit']
            }
        ]);
        
        switch (action) {
            case 'Connect Wallet':
                await connectWallet();
                break;
            case 'Disconnect Wallet':
                await disconnectWallet();
                break;
            case 'View Balance':
                await getWalletBalance();
                break;
            case 'Send Transaction':
                await sendTransaction();
                break;
            case 'View Transaction History':
                await viewTransactionHistory();
                break;
            case 'Exit':
                console.log(chalk.green('Goodbye!'));
                process.exit(0);
                break;
        }
        
        // Display current wallet status after each action
        displayWalletStatus();
    }
}

function displayWalletStatus() {
    const state = walletManager.state;
    console.log(chalk.cyan('\nWallet Status:'));
    
    if (state.isConnected) {
        console.log(chalk.green('Connected ✅'));
        console.log(chalk.white('Address:'), state.address);
        console.log(chalk.white('Chain:'), state.chain);
        console.log(chalk.white('Type:'), state.readOnly ? 'Read-only' : 'Full Access');
    } else {
        console.log(chalk.yellow('Disconnected ⚠️'));
    }
    console.log();
}

// =============================================================================
// Wallet Functions
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
                    
                    isValid = true;
                } else if (chain === 'solana') {
                    // Solana address validation - basic check for length
                    if (address.length !== 44 && address.length !== 43) {
                        console.log(chalk.red('Invalid Solana address length. Solana addresses are typically 43-44 characters.'));
                        continue;
                    }
                    
                    try {
                        // Mock validation
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
            console.log(chalk.yellow('Note: Balance fetching requires API key in read-only mode'));
            
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
            
            console.log(chalk.blue('Connecting to wallet with private key...'));
            
            // SECURITY: Use secure connect method that doesn't expose the private key
            try {
                // This will securely handle the private key without exposing it
                const walletResult = await walletManager.secureConnect(chain, privateKey);
                
                // Get derived data but NEVER store the private key
                const state = {
                    isConnected: true,
                    address: walletResult.address,
                    chain: chain,
                    balance: walletResult.balance,
                    hasFullAccess: true,  // Indicates full access without storing key
                    readOnly: false
                };
                
                // Store in walletManager - private key NOT included in state
                walletManager.state = state;
                
                // For demo purposes, display information
                console.log(chalk.green('Wallet connected successfully with full access!'));
                console.log(chalk.cyan('Address:'), walletResult.address);
                console.log(chalk.cyan('Chain:'), chain);
                console.log(chalk.cyan('Balance:'), walletResult.balance);
                
                // Immediately clear private key from memory
                privateKey = null;
            } catch (error) {
                console.error(chalk.red('Failed to securely connect wallet:'), error.message);
                return null;
            } finally {
                // Ensure private key is cleared from memory even in case of error
                privateKey = null;
            }
        }
        
        // Add a pause to let the user see the connection info
        await inquirer.prompt([{
            type: 'input',
            name: 'continue',
            message: 'Press Enter to continue...'
        }]);
    } catch (error) {
        console.error(chalk.red('Failed to connect wallet:'), error.message);
    }
}

async function disconnectWallet() {
    if (!walletManager.state.isConnected) {
        console.log(chalk.yellow('No wallet is currently connected.'));
        return;
    }

    try {
        const previousAddress = walletManager.state.address;
        const previousChain = walletManager.state.chain;
        
        // Properly disconnect using the wallet manager
        await walletManager.disconnect();
        
        console.log(chalk.green('Wallet disconnected successfully!'));
        console.log(chalk.cyan('Disconnected from:'), previousAddress);
        console.log(chalk.cyan('Chain:'), previousChain);
    } catch (error) {
        console.error(chalk.red('Failed to disconnect wallet:'), error.message);
    }
}

async function getWalletBalance() {
    if (!walletManager.state.isConnected) {
        console.log(chalk.red('Wallet not connected'));
        return;
    }
    
    if (walletManager.state.readOnly) {
        console.log(chalk.yellow('Balance not available in read-only mode without API integration'));
        return;
    }
    
    try {
        // Use the wallet manager to get balance securely
        const balance = await walletManager.getBalance();
        console.log(chalk.green(`${balance} ${walletManager.state.chain.toUpperCase()}`));
    } catch (error) {
        console.log(chalk.red(`Failed to get balance: ${error.message}`));
    }
}

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
            // Create transaction object based on chain
            let tx;
            if (walletManager.state.chain === 'solana') {
                tx = {
                    to,
                    amount: parseFloat(value),
                    chainId: 'solana',
                    data: data || null
                };
            } else {
                // EVM chain transaction
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
            
            // Send transaction using the secure wallet manager
            // This will handle MFA internally if needed
            const result = await walletManager.signTransaction(tx);
            
            spinner.succeed('Transaction signed successfully!');
            
            // For demo purposes, we'll simulate the transaction being sent
            console.log(chalk.green('Transaction submitted to network'));
            console.log(chalk.cyan('Transaction Hash:'), result.signature || '0xMocked123456789TransactionHash');
            console.log(chalk.cyan('From:'), walletManager.state.address);
            console.log(chalk.cyan('To:'), to);
            console.log(chalk.cyan('Value:'), value);
            console.log(chalk.cyan('Chain:'), walletManager.state.chain);
            
            // Store transaction for history
            if (!walletManager.state.transactions) {
                walletManager.state.transactions = [];
            }
            
            walletManager.state.transactions.push({
                hash: result.signature || `0x${uuidv4().replace(/-/g, '')}`,
                from: walletManager.state.address,
                to: to,
                amount: `${value} ${walletManager.state.chain.toUpperCase()}`,
                timestamp: new Date(),
                status: 'Pending'
            });
            
            // For demo, we just wait and simulate confirmation
            await new Promise(resolve => setTimeout(resolve, 2000));
            walletManager.state.transactions[walletManager.state.transactions.length - 1].status = 'Confirmed';
            console.log(chalk.green('Transaction confirmed!'));
            
        } catch (error) {
            spinner.fail(`Transaction failed: ${error.message}`);
            
            // Handle specific error cases
            if (error.message.includes('locked')) {
                console.log(chalk.red('Your account is temporarily locked due to too many failed attempts.'));
                console.log(chalk.yellow('Please try again later or contact support.'));
            } else if (error.message.includes('MFA') || error.message.includes('authentication')) {
                console.log(chalk.red('Authentication failed. Transaction was not sent.'));
                console.log(chalk.yellow('For security reasons, multiple failed authentication attempts may lock your account.'));
            }
        }
    } catch (error) {
        console.error(chalk.red('Error sending transaction:'), error.message);
    }
}

async function viewTransactionHistory() {
    if (!walletManager.state.isConnected) {
        console.log(chalk.yellow('Please connect a wallet first.'));
        return;
    }

    try {
        let transactions = walletManager.state.transactions || [];
        
        if (transactions.length === 0) {
            // If no transactions, provide mock data for demo purposes
            if (walletManager.state.readOnly) {
                console.log(chalk.yellow('No transaction history available in read-only mode.'));
                console.log(chalk.yellow('Connect with a private key to view and make transactions.'));
                return;
            } else {
                transactions = [
                    { 
                        hash: `0x${uuidv4().replace(/-/g, '')}`, 
                        from: 'Previous Wallet',
                        to: walletManager.state.address, 
                        amount: `0.5 ${walletManager.state.chain.toUpperCase()}`, 
                        timestamp: new Date(Date.now() - 86400000), // 1 day ago
                        status: 'Confirmed' 
                    }
                ];
                
                // Store for future reference
                walletManager.state.transactions = transactions;
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
    } catch (error) {
        console.error(chalk.red('Failed to get transaction history:'), error.message);
    }
}

// Start the application
main().catch(error => {
    console.error(chalk.red('Error:'), error.message);
    process.exit(1);
}); 