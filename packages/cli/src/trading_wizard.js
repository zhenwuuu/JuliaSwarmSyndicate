/**
 * Trading Setup Wizard for JuliaOS CLI
 * 
 * This module provides a guided setup process for trading,
 * walking users through agent creation, wallet setup, and executing their first trade.
 */

const inquirer = require('inquirer');
const chalk = require('chalk');
const ora = require('ora');
const { validateNotEmpty, validateNumber, validatePositiveNumber, validateJSON } = require('./utils');

/**
 * Trading Wizard Factory
 * @param {Object} deps - Dependencies including juliaBridge and displayHeader
 * @returns {Object} Trading wizard functions
 */
module.exports = function createTradingWizard(deps) {
    const { juliaBridge, displayHeader } = deps;

    /**
     * Start the trading setup wizard
     */
    async function startWizard() {
        displayHeader('Trading Setup Wizard');

        console.log(chalk.cyan('Welcome to the JuliaOS Trading Setup Wizard!'));
        console.log(chalk.cyan('This wizard will guide you through setting up everything you need for trading.'));
        console.log(chalk.cyan('We\'ll create a trading agent, set up a wallet, and execute your first trade.\n'));

        const { startWizard } = await inquirer.prompt([
            {
                type: 'confirm',
                name: 'startWizard',
                message: 'Ready to begin?',
                default: true
            }
        ]);

        if (!startWizard) {
            console.log(chalk.yellow('\nWizard cancelled. You can run it again anytime from the Trading menu.'));
            await promptToContinue();
            return;
        }

        // Step 1: Create a trading agent
        const agent = await createTradingAgent();
        if (!agent) {
            console.log(chalk.red('\nFailed to create trading agent. Wizard cancelled.'));
            await promptToContinue();
            return;
        }

        // Step 2: Set up a wallet
        const wallet = await setupWallet();
        if (!wallet) {
            console.log(chalk.red('\nFailed to set up wallet. Wizard cancelled.'));
            await promptToContinue();
            return;
        }

        // Step 3: Configure trading preferences
        const preferences = await configureTradingPreferences();
        if (!preferences) {
            console.log(chalk.red('\nFailed to configure trading preferences. Wizard cancelled.'));
            await promptToContinue();
            return;
        }

        // Step 4: Execute first trade (optional)
        const { executeFirstTrade } = await inquirer.prompt([
            {
                type: 'confirm',
                name: 'executeFirstTrade',
                message: 'Would you like to execute your first trade now?',
                default: true
            }
        ]);

        if (executeFirstTrade) {
            await executeTradeWithWizard(agent, wallet, preferences);
        }

        // Completion
        console.log(chalk.green('\n✅ Trading setup complete!'));
        console.log(chalk.cyan('\nYou can now use the Trading menu to execute trades, view your trade history, and monitor market data.'));
        console.log(chalk.cyan('You can also use the Agent Management menu to create more trading agents with different strategies.'));

        await promptToContinue();
    }

    /**
     * Create a trading agent
     * @returns {Object|null} Created agent or null if failed
     */
    async function createTradingAgent() {
        displayHeader('Step 1: Create Trading Agent');

        console.log(chalk.cyan('Let\'s create a trading agent that will execute trades based on your preferences.'));
        console.log(chalk.cyan('You can create multiple agents with different strategies later.\n'));

        const { name, strategy, riskLevel, maxTradesPerDay } = await inquirer.prompt([
            {
                type: 'input',
                name: 'name',
                message: 'Enter a name for your trading agent:',
                default: 'MyTradingBot',
                validate: validateNotEmpty
            },
            {
                type: 'list',
                name: 'strategy',
                message: 'Select a trading strategy:',
                choices: [
                    { name: 'Momentum Trading', value: 'momentum' },
                    { name: 'Mean Reversion', value: 'mean_reversion' },
                    { name: 'Dollar Cost Averaging', value: 'dca' },
                    { name: 'Custom Strategy', value: 'custom' }
                ]
            },
            {
                type: 'list',
                name: 'riskLevel',
                message: 'Select risk level:',
                choices: [
                    { name: 'Conservative (lower risk, lower potential returns)', value: 'low' },
                    { name: 'Moderate (balanced risk and returns)', value: 'medium' },
                    { name: 'Aggressive (higher risk, higher potential returns)', value: 'high' }
                ]
            },
            {
                type: 'input',
                name: 'maxTradesPerDay',
                message: 'Maximum trades per day:',
                default: '5',
                validate: validatePositiveNumber
            }
        ]);

        // Prepare agent configuration
        const config = {
            strategy,
            risk_level: riskLevel,
            max_trades_per_day: parseInt(maxTradesPerDay),
            created_by: 'trading_wizard'
        };

        // Create the agent
        const spinner = ora('Creating trading agent...').start();
        
        try {
            const response = await juliaBridge.request('POST', '/api/v1/agents', {
                name,
                type: 'trading',
                config
            });
            
            spinner.succeed('Trading agent created successfully');
            
            console.log(chalk.green('\n✅ Trading agent created!'));
            console.log(chalk.cyan('Agent Name:'), name);
            console.log(chalk.cyan('Agent ID:'), response.id);
            console.log(chalk.cyan('Strategy:'), strategy);
            console.log(chalk.cyan('Risk Level:'), riskLevel);
            
            return response;
        } catch (error) {
            spinner.fail('Failed to create trading agent');
            console.error(chalk.red(`\n❌ Error: ${error.message}`));
            return null;
        }
    }

    /**
     * Set up a wallet
     * @returns {Object|null} Created wallet or null if failed
     */
    async function setupWallet() {
        displayHeader('Step 2: Set Up Wallet');

        console.log(chalk.cyan('Now, let\'s set up a wallet for trading.'));
        console.log(chalk.cyan('You can either create a new wallet or connect an existing one.\n'));

        const { walletOption } = await inquirer.prompt([
            {
                type: 'list',
                name: 'walletOption',
                message: 'How would you like to set up your wallet?',
                choices: [
                    { name: 'Create a new wallet', value: 'create' },
                    { name: 'Connect an existing wallet', value: 'connect' }
                ]
            }
        ]);

        if (walletOption === 'create') {
            return await createNewWallet();
        } else {
            return await connectExistingWallet();
        }
    }

    /**
     * Create a new wallet
     * @returns {Object|null} Created wallet or null if failed
     */
    async function createNewWallet() {
        const { name, type } = await inquirer.prompt([
            {
                type: 'input',
                name: 'name',
                message: 'Enter a name for your wallet:',
                default: 'MyTradingWallet',
                validate: validateNotEmpty
            },
            {
                type: 'list',
                name: 'type',
                message: 'Select blockchain network:',
                choices: [
                    { name: 'Ethereum', value: 'ethereum' },
                    { name: 'Polygon', value: 'polygon' },
                    { name: 'Solana', value: 'solana' },
                    { name: 'Binance Smart Chain', value: 'bsc' }
                ]
            }
        ]);

        const spinner = ora('Creating wallet...').start();
        
        try {
            const response = await juliaBridge.request('POST', '/api/v1/wallets', {
                name,
                type
            });
            
            spinner.succeed('Wallet created successfully');
            
            console.log(chalk.green('\n✅ Wallet created!'));
            console.log(chalk.cyan('Wallet Name:'), name);
            console.log(chalk.cyan('Wallet ID:'), response.id);
            console.log(chalk.cyan('Network:'), type);
            console.log(chalk.cyan('Address:'), response.address);
            
            console.log(chalk.yellow('\n⚠️ Important: In a real environment, you would need to fund this wallet with tokens for trading.'));
            console.log(chalk.yellow('For this demo, we\'ll simulate having funds available.'));
            
            return response;
        } catch (error) {
            spinner.fail('Failed to create wallet');
            console.error(chalk.red(`\n❌ Error: ${error.message}`));
            return null;
        }
    }

    /**
     * Connect an existing wallet
     * @returns {Object|null} Connected wallet or null if failed
     */
    async function connectExistingWallet() {
        const { name, type, address } = await inquirer.prompt([
            {
                type: 'input',
                name: 'name',
                message: 'Enter a name for this wallet connection:',
                default: 'MyConnectedWallet',
                validate: validateNotEmpty
            },
            {
                type: 'list',
                name: 'type',
                message: 'Select blockchain network:',
                choices: [
                    { name: 'Ethereum', value: 'ethereum' },
                    { name: 'Polygon', value: 'polygon' },
                    { name: 'Solana', value: 'solana' },
                    { name: 'Binance Smart Chain', value: 'bsc' }
                ]
            },
            {
                type: 'input',
                name: 'address',
                message: 'Enter wallet address:',
                validate: validateNotEmpty
            }
        ]);

        const spinner = ora('Connecting wallet...').start();
        
        try {
            const response = await juliaBridge.request('POST', '/api/v1/wallets', {
                name,
                type,
                address,
                is_read_only: true
            });
            
            spinner.succeed('Wallet connected successfully');
            
            console.log(chalk.green('\n✅ Wallet connected!'));
            console.log(chalk.cyan('Wallet Name:'), name);
            console.log(chalk.cyan('Wallet ID:'), response.id);
            console.log(chalk.cyan('Network:'), type);
            console.log(chalk.cyan('Address:'), address);
            
            return response;
        } catch (error) {
            spinner.fail('Failed to connect wallet');
            console.error(chalk.red(`\n❌ Error: ${error.message}`));
            return null;
        }
    }

    /**
     * Configure trading preferences
     * @returns {Object|null} Trading preferences or null if failed
     */
    async function configureTradingPreferences() {
        displayHeader('Step 3: Configure Trading Preferences');

        console.log(chalk.cyan('Let\'s configure your trading preferences.'));
        console.log(chalk.cyan('These settings will be used for your trades.\n'));

        try {
            // Get market data
            const spinner = ora('Fetching market data...').start();
            
            let marketDataResponse;
            try {
                marketDataResponse = await juliaBridge.request('GET', '/api/v1/trading/market-data');
                spinner.succeed('Fetched market data');
            } catch (error) {
                spinner.fail('Failed to fetch market data');
                console.error(chalk.red(`\n❌ Error: ${error.message}`));
                return null;
            }
            
            if (!marketDataResponse || !marketDataResponse.data) {
                console.log(chalk.yellow('\nNo market data available.'));
                return null;
            }
            
            // Get user preferences
            const { defaultPair, defaultDex, defaultSlippage, defaultGasMultiplier } = await inquirer.prompt([
                {
                    type: 'list',
                    name: 'defaultPair',
                    message: 'Select default trading pair:',
                    choices: Object.keys(marketDataResponse.data).map(pair => ({
                        name: `${pair} (${marketDataResponse.data[pair].price})`,
                        value: pair
                    })),
                    pageSize: 10
                },
                {
                    type: 'list',
                    name: 'defaultDex',
                    message: 'Select preferred DEX:',
                    choices: [
                        { name: 'Uniswap V3', value: 'uniswap_v3' },
                        { name: 'SushiSwap', value: 'sushiswap' },
                        { name: 'PancakeSwap', value: 'pancakeswap' },
                        { name: 'Raydium', value: 'raydium' },
                        { name: 'Orca', value: 'orca' }
                    ]
                },
                {
                    type: 'input',
                    name: 'defaultSlippage',
                    message: 'Default slippage percentage:',
                    default: '1.0',
                    validate: input => {
                        const num = parseFloat(input);
                        return (!isNaN(num) && num >= 0) ? true : 'Please enter a non-negative number';
                    }
                },
                {
                    type: 'input',
                    name: 'defaultGasMultiplier',
                    message: 'Default gas price multiplier:',
                    default: '1.0',
                    validate: validatePositiveNumber
                }
            ]);
            
            // Save preferences
            const preferences = {
                defaultPair,
                defaultDex,
                defaultSlippage: parseFloat(defaultSlippage),
                defaultGasMultiplier: parseFloat(defaultGasMultiplier)
            };
            
            console.log(chalk.green('\n✅ Trading preferences configured!'));
            console.log(chalk.cyan('Default Pair:'), defaultPair);
            console.log(chalk.cyan('Preferred DEX:'), defaultDex);
            console.log(chalk.cyan('Default Slippage:'), `${defaultSlippage}%`);
            console.log(chalk.cyan('Gas Multiplier:'), `${defaultGasMultiplier}x`);
            
            return preferences;
        } catch (error) {
            console.error(chalk.red(`\n❌ Error: ${error.message}`));
            return null;
        }
    }

    /**
     * Execute a trade with the wizard
     * @param {Object} agent - Trading agent
     * @param {Object} wallet - Wallet
     * @param {Object} preferences - Trading preferences
     */
    async function executeTradeWithWizard(agent, wallet, preferences) {
        displayHeader('Step 4: Execute First Trade');

        console.log(chalk.cyan('Now, let\'s execute your first trade using the agent and wallet you just set up.'));
        console.log(chalk.cyan('We\'ll use your configured preferences as defaults.\n'));

        // Get networks
        const spinner = ora('Fetching available networks...').start();
        
        let networksResponse;
        try {
            networksResponse = await juliaBridge.request('GET', '/api/v1/blockchain/networks');
            spinner.succeed('Fetched available networks');
        } catch (error) {
            spinner.fail('Failed to fetch networks');
            console.error(chalk.red(`\n❌ Error: ${error.message}`));
            await promptToContinue();
            return;
        }
        
        if (!networksResponse || !networksResponse.networks || networksResponse.networks.length === 0) {
            console.log(chalk.yellow('\nNo blockchain networks found.'));
            await promptToContinue();
            return;
        }
        
        // Collect trade parameters
        const tradeParams = {
            agent_id: agent.id,
            wallet_id: wallet.id
        };
        
        // Network selection
        const { network } = await inquirer.prompt([
            {
                type: 'list',
                name: 'network',
                message: 'Select blockchain network:',
                choices: networksResponse.networks.map(network => ({
                    name: `${network.name} (${network.status})`,
                    value: network.id
                })),
                default: wallet.type,
                pageSize: 10
            }
        ]);
        tradeParams.network = network;
        
        // Use default pair from preferences
        tradeParams.pair = preferences.defaultPair;
        
        // Trade type and side
        const { type, side } = await inquirer.prompt([
            {
                type: 'list',
                name: 'type',
                message: 'Select trade type:',
                choices: [
                    { name: 'Market Order', value: 'market' },
                    { name: 'Limit Order', value: 'limit' }
                ]
            },
            {
                type: 'list',
                name: 'side',
                message: 'Select trade side:',
                choices: [
                    { name: 'Buy', value: 'buy' },
                    { name: 'Sell', value: 'sell' }
                ]
            }
        ]);
        tradeParams.type = type;
        tradeParams.side = side;
        
        // Quantity
        const { quantity } = await inquirer.prompt([
            {
                type: 'input',
                name: 'quantity',
                message: 'Enter quantity:',
                validate: validatePositiveNumber
            }
        ]);
        tradeParams.quantity = parseFloat(quantity);
        
        // Price (for limit orders)
        if (tradeParams.type === 'limit') {
            const { price } = await inquirer.prompt([
                {
                    type: 'input',
                    name: 'price',
                    message: 'Enter limit price:',
                    validate: validatePositiveNumber
                }
            ]);
            tradeParams.price = parseFloat(price);
        }
        
        // Use default DEX from preferences
        tradeParams.dex = preferences.defaultDex;
        
        // Use default slippage from preferences
        tradeParams.slippage = preferences.defaultSlippage;
        
        // Use default gas multiplier from preferences
        tradeParams.gas_multiplier = preferences.defaultGasMultiplier;
        
        // Display trade summary
        console.log('\n' + chalk.bold('Trade Summary:'));
        console.log(chalk.cyan('┌─────────────────────────────────────────────────┐'));
        console.log(chalk.cyan(`│ Agent:      ${chalk.white(agent.name)}${' '.repeat(Math.max(0, 38 - agent.name.length))}│`));
        console.log(chalk.cyan(`│ Wallet:     ${chalk.white(wallet.name)}${' '.repeat(Math.max(0, 38 - wallet.name.length))}│`));
        console.log(chalk.cyan(`│ Network:    ${chalk.white(networksResponse.networks.find(n => n.id === tradeParams.network).name)}${' '.repeat(Math.max(0, 38 - networksResponse.networks.find(n => n.id === tradeParams.network).name.length))}│`));
        console.log(chalk.cyan(`│ Pair:       ${chalk.white(tradeParams.pair)}${' '.repeat(Math.max(0, 38 - tradeParams.pair.length))}│`));
        console.log(chalk.cyan(`│ Type:       ${chalk.white(tradeParams.type === 'market' ? 'Market Order' : 'Limit Order')}${' '.repeat(Math.max(0, 38 - (tradeParams.type === 'market' ? 'Market Order' : 'Limit Order').length))}│`));
        console.log(chalk.cyan(`│ Side:       ${chalk.white(tradeParams.side === 'buy' ? 'Buy' : 'Sell')}${' '.repeat(Math.max(0, 38 - (tradeParams.side === 'buy' ? 'Buy' : 'Sell').length))}│`));
        console.log(chalk.cyan(`│ Quantity:   ${chalk.white(tradeParams.quantity)}${' '.repeat(Math.max(0, 38 - String(tradeParams.quantity).length))}│`));
        
        if (tradeParams.type === 'limit') {
            console.log(chalk.cyan(`│ Price:      ${chalk.white(tradeParams.price)}${' '.repeat(Math.max(0, 38 - String(tradeParams.price).length))}│`));
        }
        
        console.log(chalk.cyan(`│ DEX:        ${chalk.white(tradeParams.dex)}${' '.repeat(Math.max(0, 38 - tradeParams.dex.length))}│`));
        console.log(chalk.cyan(`│ Slippage:   ${chalk.white(tradeParams.slippage + '%')}${' '.repeat(Math.max(0, 38 - String(tradeParams.slippage + '%').length))}│`));
        console.log(chalk.cyan(`│ Gas:        ${chalk.white(tradeParams.gas_multiplier + 'x')}${' '.repeat(Math.max(0, 38 - String(tradeParams.gas_multiplier + 'x').length))}│`));
        console.log(chalk.cyan('└─────────────────────────────────────────────────┘'));
        
        // Confirm trade
        const { confirmTrade } = await inquirer.prompt([
            {
                type: 'confirm',
                name: 'confirmTrade',
                message: 'Execute this trade?',
                default: true
            }
        ]);
        
        if (!confirmTrade) {
            console.log(chalk.yellow('\nTrade cancelled.'));
            return;
        }
        
        // Execute trade
        spinner.text = 'Executing trade...';
        spinner.start();
        
        try {
            const tradeResponse = await juliaBridge.request('POST', '/api/v1/trading/execute', tradeParams);
            
            spinner.succeed('Trade executed');
            
            if (tradeResponse && tradeResponse.success) {
                console.log(chalk.green('\n✅ Trade executed successfully!'));
                
                console.log('\n' + chalk.bold('Trade Details:'));
                console.log(chalk.cyan('┌─────────────────────────────────────────────────┐'));
                console.log(chalk.cyan(`│ Transaction ID: ${chalk.white(tradeResponse.transaction_id || 'N/A')}${' '.repeat(Math.max(0, 33 - String(tradeResponse.transaction_id || 'N/A').length))}│`));
                console.log(chalk.cyan(`│ Status:         ${chalk.white(tradeResponse.status || 'Pending')}${' '.repeat(Math.max(0, 33 - String(tradeResponse.status || 'Pending').length))}│`));
                
                if (tradeResponse.executed_price) {
                    console.log(chalk.cyan(`│ Executed Price: ${chalk.white(tradeResponse.executed_price)}${' '.repeat(Math.max(0, 33 - String(tradeResponse.executed_price).length))}│`));
                }
                
                if (tradeResponse.executed_quantity) {
                    console.log(chalk.cyan(`│ Executed Qty:   ${chalk.white(tradeResponse.executed_quantity)}${' '.repeat(Math.max(0, 33 - String(tradeResponse.executed_quantity).length))}│`));
                }
                
                if (tradeResponse.fee) {
                    console.log(chalk.cyan(`│ Fee:            ${chalk.white(tradeResponse.fee)}${' '.repeat(Math.max(0, 33 - String(tradeResponse.fee).length))}│`));
                }
                
                if (tradeResponse.gas_used) {
                    console.log(chalk.cyan(`│ Gas Used:       ${chalk.white(tradeResponse.gas_used)}${' '.repeat(Math.max(0, 33 - String(tradeResponse.gas_used).length))}│`));
                }
                
                console.log(chalk.cyan('└─────────────────────────────────────────────────┘'));
                
                if (tradeResponse.explorer_url) {
                    console.log(chalk.cyan(`\nView transaction: ${chalk.underline(tradeResponse.explorer_url)}`));
                }
            } else {
                console.log(chalk.red(`\n❌ Trade execution failed: ${tradeResponse?.error || 'Unknown error'}`));
            }
        } catch (error) {
            spinner.fail('Trade execution failed');
            console.error(chalk.red(`\n❌ Error: ${error.message}`));
        }
    }

    /**
     * Prompt the user to continue
     */
    async function promptToContinue() {
        await inquirer.prompt([
            {
                type: 'input',
                name: 'continue',
                message: 'Press Enter to continue...'
            }
        ]);
    }

    // Return the public API
    return {
        startWizard
    };
};
