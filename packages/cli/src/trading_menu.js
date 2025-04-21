/**
 * Trading Menu Module for JuliaOS CLI
 *
 * This module provides functionality for executing trades using agents.
 */

const inquirer = require('inquirer');
const chalk = require('chalk');
const ora = require('ora');
const { table } = require('table');
const { validateNotEmpty, validateNumber, validatePositiveNumber } = require('./utils');
const createTradingWizard = require('./trading_wizard');

/**
 * Trading Menu Factory
 * @param {Object} deps - Dependencies including juliaBridge and displayHeader
 * @returns {Object} Trading menu functions
 */
module.exports = function createTradingMenu(deps) {
    const { juliaBridge, displayHeader } = deps;

    // Create trading wizard
    const tradingWizard = createTradingWizard(deps);

    /**
     * Display the trading menu
     * @param {string} selectedAgentId - Optional agent ID to use for trading
     */
    async function showTradingMenu(selectedAgentId = null) {
        displayHeader('Trading Menu');

        // If an agent was selected from Agent Management, show a message
        if (selectedAgentId) {
            console.log(chalk.green(`\nUsing selected agent with ID: ${selectedAgentId}\n`));
        }

        const { option } = await inquirer.prompt([
            {
                type: 'list',
                name: 'option',
                message: 'Select an option:',
                choices: [
                    { name: '🧙 Trading Setup Wizard', value: 'wizard' },
                    { name: '💰 Execute Trade', value: 'execute' },
                    { name: '⚡ Quick Trade', value: 'quick' },
                    { name: '📜 View Trade History', value: 'history' },
                    { name: '📊 View Market Data', value: 'market' },
                    { name: '⬅️ Back to Main Menu', value: 'back' }
                ]
            }
        ]);

        switch (option) {
            case 'wizard':
                await tradingWizard.startWizard();
                break;
            case 'execute':
                await executeTrade(selectedAgentId);
                break;
            case 'quick':
                await quickTrade(selectedAgentId);
                break;
            case 'history':
                await viewTradeHistory();
                break;
            case 'market':
                await viewMarketData();
                break;
            case 'back':
                return;
        }

        // Return to trading menu after action completes
        await showTradingMenu(selectedAgentId);
    }

    /**
     * Execute a trade
     * @param {string} selectedAgentId - Optional agent ID to use for trading
     */
    async function executeTrade(selectedAgentId = null) {
        displayHeader('Execute Trade');

        // Get available agents
        const spinner = ora('Fetching available agents...').start();

        let agentsResponse;
        try {
            agentsResponse = await juliaBridge.executeCommand('list_agents', {});
            spinner.succeed('Fetched available agents');
        } catch (error) {
            spinner.fail('Failed to fetch agents');
            console.error(chalk.red(`Error: ${error.message}`));
            await promptToContinue();
            return;
        }

        if (!agentsResponse || !agentsResponse.data || agentsResponse.data.length === 0) {
            console.log(chalk.yellow('\nNo agents found. Please create an agent first.'));
            await promptToContinue();
            return;
        }

        // Filter for trading agents
        const tradingAgents = agentsResponse.data.filter(agent =>
            agent.type === 'trading' || agent.capabilities?.includes('trading')
        );

        if (tradingAgents.length === 0) {
            console.log(chalk.yellow('\nNo trading agents found. Please create a trading agent first.'));
            await promptToContinue();
            return;
        }

        // Get available wallets
        spinner.text = 'Fetching available wallets...';
        spinner.start();

        let walletsResponse;
        try {
            walletsResponse = await juliaBridge.executeCommand('list_wallets', {});
            spinner.succeed('Fetched available wallets');
        } catch (error) {
            spinner.fail('Failed to fetch wallets');
            console.error(chalk.red(`Error: ${error.message}`));
            await promptToContinue();
            return;
        }

        if (!walletsResponse || !walletsResponse.wallets || walletsResponse.wallets.length === 0) {
            console.log(chalk.yellow('\nNo wallets found. Please create a wallet first.'));
            await promptToContinue();
            return;
        }

        // Get available networks
        spinner.text = 'Fetching available networks...';
        spinner.start();

        let networksResponse;
        try {
            networksResponse = await juliaBridge.executeCommand('get_available_chains', {});
            spinner.succeed('Fetched available networks');
        } catch (error) {
            spinner.fail('Failed to fetch networks');
            console.error(chalk.red(`Error: ${error.message}`));
            await promptToContinue();
            return;
        }

        if (!networksResponse || !networksResponse.networks || networksResponse.networks.length === 0) {
            console.log(chalk.yellow('\nNo blockchain networks found.'));
            await promptToContinue();
            return;
        }

        // Get market data
        spinner.text = 'Fetching market data...';
        spinner.start();

        let marketDataResponse;
        try {
            marketDataResponse = await juliaBridge.executeCommand('get_dex_pairs', {});
            spinner.succeed('Fetched market data');
        } catch (error) {
            spinner.fail('Failed to fetch market data');
            console.error(chalk.red(`Error: ${error.message}`));
            await promptToContinue();
            return;
        }

        if (!marketDataResponse || !marketDataResponse.data) {
            console.log(chalk.yellow('\nNo market data available.'));
            await promptToContinue();
            return;
        }

        // Collect trade parameters
        const tradeParams = {};

        // Agent selection
        let agentId;

        if (selectedAgentId) {
            // Check if the selected agent exists in the trading agents list
            const selectedAgent = tradingAgents.find(agent => agent.id === selectedAgentId);

            if (selectedAgent) {
                console.log(chalk.green(`Using selected agent: ${selectedAgent.name} (${selectedAgent.status})`));
                agentId = selectedAgentId;
            } else {
                console.log(chalk.yellow(`Selected agent ID ${selectedAgentId} not found or is not a trading agent.`));
                console.log(chalk.yellow(`Please select a trading agent from the list.`));

                // Prompt for agent selection
                const response = await inquirer.prompt([
                    {
                        type: 'list',
                        name: 'agentId',
                        message: 'Select a trading agent:',
                        choices: tradingAgents.map(agent => ({
                            name: `${agent.name} (${agent.status})`,
                            value: agent.id
                        })),
                        pageSize: 10
                    }
                ]);
                agentId = response.agentId;
            }
        } else {
            // No agent selected, prompt for selection
            const response = await inquirer.prompt([
                {
                    type: 'list',
                    name: 'agentId',
                    message: 'Select a trading agent:',
                    choices: tradingAgents.map(agent => ({
                        name: `${agent.name} (${agent.status})`,
                        value: agent.id
                    })),
                    pageSize: 10
                }
            ]);
            agentId = response.agentId;
        }

        tradeParams.agent_id = agentId;

        // Wallet selection
        const { walletId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'walletId',
                message: 'Select a wallet:',
                choices: walletsResponse.wallets.map(wallet => ({
                    name: `${wallet.name} (${wallet.type})`,
                    value: wallet.id
                })),
                pageSize: 10
            }
        ]);
        tradeParams.wallet_id = walletId;

        // Network selection
        const { networkId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'networkId',
                message: 'Select a blockchain network:',
                choices: networksResponse.networks.map(network => ({
                    name: `${network.name} (${network.status})`,
                    value: network.id
                })),
                pageSize: 10
            }
        ]);
        tradeParams.network = networkId;

        // Trading pair
        const { pair } = await inquirer.prompt([
            {
                type: 'list',
                name: 'pair',
                message: 'Select trading pair:',
                choices: Object.keys(marketDataResponse.data).map(pair => ({
                    name: `${pair} (${marketDataResponse.data[pair].price})`,
                    value: pair
                })),
                pageSize: 10
            }
        ]);
        tradeParams.pair = pair;

        // Trade type
        const { type } = await inquirer.prompt([
            {
                type: 'list',
                name: 'type',
                message: 'Select trade type:',
                choices: [
                    { name: 'Market Order', value: 'market' },
                    { name: 'Limit Order', value: 'limit' }
                ]
            }
        ]);
        tradeParams.type = type;

        // Trade side
        const { side } = await inquirer.prompt([
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

        // DEX selection
        const { dex } = await inquirer.prompt([
            {
                type: 'list',
                name: 'dex',
                message: 'Select DEX:',
                choices: [
                    { name: 'Uniswap V3', value: 'uniswap_v3' },
                    { name: 'SushiSwap', value: 'sushiswap' },
                    { name: 'PancakeSwap', value: 'pancakeswap' },
                    { name: 'Raydium', value: 'raydium' },
                    { name: 'Orca', value: 'orca' }
                ]
            }
        ]);
        tradeParams.dex = dex;

        // Slippage
        const { slippage } = await inquirer.prompt([
            {
                type: 'input',
                name: 'slippage',
                message: 'Enter maximum slippage percentage:',
                default: '1.0',
                validate: input => {
                    const num = parseFloat(input);
                    return (!isNaN(num) && num >= 0) ? true : 'Please enter a non-negative number';
                }
            }
        ]);
        tradeParams.slippage = parseFloat(slippage);

        // Gas multiplier
        const { gasMultiplier } = await inquirer.prompt([
            {
                type: 'input',
                name: 'gasMultiplier',
                message: 'Enter gas price multiplier:',
                default: '1.0',
                validate: validatePositiveNumber
            }
        ]);
        tradeParams.gas_multiplier = parseFloat(gasMultiplier);

        // Display trade summary
        console.log('\n' + chalk.bold('Trade Summary:'));
        console.log(chalk.cyan('┌─────────────────────────────────────────────────┐'));
        console.log(chalk.cyan(`│ Agent:      ${chalk.white(tradingAgents.find(a => a.id === tradeParams.agent_id).name)}${' '.repeat(Math.max(0, 38 - tradingAgents.find(a => a.id === tradeParams.agent_id).name.length))}│`));
        console.log(chalk.cyan(`│ Wallet:     ${chalk.white(walletsResponse.wallets.find(w => w.id === tradeParams.wallet_id).name)}${' '.repeat(Math.max(0, 38 - walletsResponse.wallets.find(w => w.id === tradeParams.wallet_id).name.length))}│`));
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
                default: false
            }
        ]);

        if (!confirmTrade) {
            console.log(chalk.yellow('\nTrade cancelled.'));
            await promptToContinue();
            return;
        }

        // Execute trade
        spinner.text = 'Executing trade...';
        spinner.start();

        try {
            const tradeResponse = await juliaBridge.executeCommand('execute_trade', {
                chain_id: tradeParams.network,
                token_in: tradeParams.pair.split('/')[0],
                token_out: tradeParams.pair.split('/')[1],
                amount: tradeParams.quantity.toString(),
                wallet_address: walletsResponse.wallets.find(w => w.id === tradeParams.wallet_id).address,
                slippage: tradeParams.slippage,
                dex_id: tradeParams.dex
            });

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

        await promptToContinue();
    }

    /**
     * View trade history
     */
    async function viewTradeHistory() {
        displayHeader('Trade History');

        // Get available agents
        const spinner = ora('Fetching trade history...').start();

        try {
            const historyResponse = await juliaBridge.executeCommand('get_trade_history', {});

            spinner.succeed('Fetched trade history');

            if (!historyResponse || !historyResponse.trades || historyResponse.trades.length === 0) {
                console.log(chalk.yellow('\nNo trade history found.'));
                await promptToContinue();
                return;
            }

            // Sort trades by timestamp (newest first)
            const trades = historyResponse.trades.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

            // Display trades in a table
            const tableData = [
                [
                    chalk.bold('Date'),
                    chalk.bold('Pair'),
                    chalk.bold('Type'),
                    chalk.bold('Side'),
                    chalk.bold('Quantity'),
                    chalk.bold('Price'),
                    chalk.bold('Status')
                ],
                ...trades.map(trade => [
                    new Date(trade.timestamp).toLocaleString(),
                    trade.pair,
                    trade.type === 'market' ? 'Market' : 'Limit',
                    trade.side === 'buy' ? chalk.green('Buy') : chalk.red('Sell'),
                    trade.executed_quantity,
                    trade.executed_price,
                    trade.status === 'completed' ? chalk.green('Completed') : chalk.yellow(trade.status)
                ])
            ];

            const tableConfig = {
                border: {
                    topBody: '─',
                    topJoin: '┬',
                    topLeft: '┌',
                    topRight: '┐',
                    bottomBody: '─',
                    bottomJoin: '┴',
                    bottomLeft: '└',
                    bottomRight: '┘',
                    bodyLeft: '│',
                    bodyRight: '│',
                    bodyJoin: '│',
                    joinBody: '─',
                    joinLeft: '├',
                    joinRight: '┤',
                    joinJoin: '┼'
                }
            };

            console.log(table(tableData, tableConfig));

        } catch (error) {
            spinner.fail('Failed to fetch trade history');
            console.error(chalk.red(`\n❌ Error: ${error.message}`));
        }

        await promptToContinue();
    }

    /**
     * View market data
     */
    async function viewMarketData() {
        displayHeader('Market Data');

        // Get market data
        const spinner = ora('Fetching market data...').start();

        try {
            const marketDataResponse = await juliaBridge.executeCommand('get_dex_pairs', {});

            spinner.succeed('Fetched market data');

            if (!marketDataResponse || !marketDataResponse.data) {
                console.log(chalk.yellow('\nNo market data available.'));
                await promptToContinue();
                return;
            }

            // Display market data in a table
            const tableData = [
                [
                    chalk.bold('Pair'),
                    chalk.bold('Price'),
                    chalk.bold('24h Change'),
                    chalk.bold('24h Volume')
                ],
                ...Object.entries(marketDataResponse.data).map(([pair, data]) => [
                    pair,
                    data.price.toFixed(2),
                    data.change_24h >= 0 ? chalk.green(`+${data.change_24h}%`) : chalk.red(`${data.change_24h}%`),
                    formatLargeNumber(data.volume_24h)
                ])
            ];

            const tableConfig = {
                border: {
                    topBody: '─',
                    topJoin: '┬',
                    topLeft: '┌',
                    topRight: '┐',
                    bottomBody: '─',
                    bottomJoin: '┴',
                    bottomLeft: '└',
                    bottomRight: '┘',
                    bodyLeft: '│',
                    bodyRight: '│',
                    bodyJoin: '│',
                    joinBody: '─',
                    joinLeft: '├',
                    joinRight: '┤',
                    joinJoin: '┼'
                }
            };

            console.log(table(tableData, tableConfig));

        } catch (error) {
            spinner.fail('Failed to fetch market data');
            console.error(chalk.red(`\n❌ Error: ${error.message}`));
        }

        await promptToContinue();
    }

    /**
     * Format large numbers for display
     * @param {number} num - Number to format
     * @returns {string} Formatted number
     */
    function formatLargeNumber(num) {
        if (num >= 1e9) {
            return (num / 1e9).toFixed(2) + 'B';
        } else if (num >= 1e6) {
            return (num / 1e6).toFixed(2) + 'M';
        } else if (num >= 1e3) {
            return (num / 1e3).toFixed(2) + 'K';
        } else {
            return num.toString();
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

    /**
     * Execute a quick trade with minimal steps
     * @param {string} preselectedAgentId - Optional agent ID to use for trading
     */
    async function quickTrade(preselectedAgentId) {
        displayHeader('Quick Trade');

        console.log(chalk.cyan('Quick Trade allows you to execute a trade with minimal steps.'));
        console.log(chalk.cyan('We\'ll use your existing agents and wallets to execute a trade quickly.\n'));

        // Get available agents
        const spinner = ora('Fetching available agents...').start();

        let agentsResponse;
        try {
            agentsResponse = await juliaBridge.executeCommand('list_agents', {});
            spinner.succeed('Fetched available agents');
        } catch (error) {
            spinner.fail('Failed to fetch agents');
            console.error(chalk.red(`Error: ${error.message}`));
            await promptToContinue();
            return;
        }

        if (!agentsResponse || !agentsResponse.data || agentsResponse.data.length === 0) {
            console.log(chalk.yellow('\nNo agents found. Please create an agent first.'));
            await promptToContinue();
            return;
        }

        // Filter for trading agents
        const tradingAgents = agentsResponse.data.filter(agent =>
            agent.type === 'trading' || agent.capabilities?.includes('trading')
        );

        if (tradingAgents.length === 0) {
            console.log(chalk.yellow('\nNo trading agents found. Please create a trading agent first.'));
            await promptToContinue();
            return;
        }

        // Get available wallets
        spinner.text = 'Fetching available wallets...';
        spinner.start();

        let walletsResponse;
        try {
            walletsResponse = await juliaBridge.executeCommand('list_wallets', {});
            spinner.succeed('Fetched available wallets');
        } catch (error) {
            spinner.fail('Failed to fetch wallets');
            console.error(chalk.red(`Error: ${error.message}`));
            await promptToContinue();
            return;
        }

        if (!walletsResponse || !walletsResponse.wallets || walletsResponse.wallets.length === 0) {
            console.log(chalk.yellow('\nNo wallets found. Please create a wallet first.'));
            await promptToContinue();
            return;
        }

        // Get market data
        spinner.text = 'Fetching market data...';
        spinner.start();

        let marketDataResponse;
        try {
            marketDataResponse = await juliaBridge.executeCommand('get_dex_pairs', {});
            spinner.succeed('Fetched market data');
        } catch (error) {
            spinner.fail('Failed to fetch market data');
            console.error(chalk.red(`Error: ${error.message}`));
            await promptToContinue();
            return;
        }

        if (!marketDataResponse || !marketDataResponse.data) {
            console.log(chalk.yellow('\nNo market data available.'));
            await promptToContinue();
            return;
        }

        // Quick selection
        let agentId = preselectedAgentId;
        let promptQuestions = [];

        // Only prompt for agent if not preselected
        if (!agentId) {
            promptQuestions.push({
                type: 'list',
                name: 'agentId',
                message: 'Select a trading agent:',
                choices: tradingAgents.map(agent => ({
                    name: `${agent.name} (${agent.status})`,
                    value: agent.id
                })),
                pageSize: 10
            });
        }

        // Add other prompt questions
        promptQuestions = promptQuestions.concat([
            {
                type: 'list',
                name: 'walletId',
                message: 'Select a wallet:',
                choices: walletsResponse.wallets.map(wallet => ({
                    name: `${wallet.name} (${wallet.type})`,
                    value: wallet.id
                })),
                pageSize: 10
            },
            {
                type: 'list',
                name: 'pair',
                message: 'Select trading pair:',
                choices: Object.keys(marketDataResponse.data).map(pair => ({
                    name: `${pair} (${marketDataResponse.data[pair].price})`,
                    value: pair
                })),
                pageSize: 10
            },
            {
                type: 'list',
                name: 'side',
                message: 'Buy or sell?',
                choices: [
                    { name: 'Buy', value: 'buy' },
                    { name: 'Sell', value: 'sell' }
                ]
            },
            {
                type: 'input',
                name: 'quantity',
                message: 'Enter quantity:',
                validate: validatePositiveNumber
            }
        ]);

        // Prompt for trade parameters
        const answers = await inquirer.prompt(promptQuestions);

        // If agent was preselected, use it; otherwise use the one from the prompt
        if (!agentId) {
            agentId = answers.agentId;
        }

        const { walletId, pair, side, quantity } = answers;

        // Prepare trade parameters with sensible defaults
        const tradeParams = {
            agent_id: agentId,
            wallet_id: walletId,
            network: walletsResponse.wallets.find(w => w.id === walletId).type,
            pair,
            type: 'market', // Default to market order for quick trade
            side,
            quantity: parseFloat(quantity),
            dex: 'uniswap_v3', // Default DEX
            slippage: 1.0, // Default slippage
            gas_multiplier: 1.0 // Default gas multiplier
        };

        // Display trade summary
        console.log('\n' + chalk.bold('Trade Summary:'));
        console.log(chalk.cyan('┌─────────────────────────────────────────────────┐'));
        console.log(chalk.cyan(`│ Agent:      ${chalk.white(tradingAgents.find(a => a.id === tradeParams.agent_id).name)}${' '.repeat(Math.max(0, 38 - tradingAgents.find(a => a.id === tradeParams.agent_id).name.length))}│`));
        console.log(chalk.cyan(`│ Wallet:     ${chalk.white(walletsResponse.wallets.find(w => w.id === tradeParams.wallet_id).name)}${' '.repeat(Math.max(0, 38 - walletsResponse.wallets.find(w => w.id === tradeParams.wallet_id).name.length))}│`));
        console.log(chalk.cyan(`│ Network:    ${chalk.white(tradeParams.network)}${' '.repeat(Math.max(0, 38 - tradeParams.network.length))}│`));
        console.log(chalk.cyan(`│ Pair:       ${chalk.white(tradeParams.pair)}${' '.repeat(Math.max(0, 38 - tradeParams.pair.length))}│`));
        console.log(chalk.cyan(`│ Type:       ${chalk.white('Market Order')}${' '.repeat(Math.max(0, 38 - 'Market Order'.length))}│`));
        console.log(chalk.cyan(`│ Side:       ${chalk.white(tradeParams.side === 'buy' ? 'Buy' : 'Sell')}${' '.repeat(Math.max(0, 38 - (tradeParams.side === 'buy' ? 'Buy' : 'Sell').length))}│`));
        console.log(chalk.cyan(`│ Quantity:   ${chalk.white(tradeParams.quantity)}${' '.repeat(Math.max(0, 38 - String(tradeParams.quantity).length))}│`));
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
            await promptToContinue();
            return;
        }

        // Execute trade
        spinner.text = 'Executing trade...';
        spinner.start();

        try {
            const tradeResponse = await juliaBridge.executeCommand('execute_trade', {
                chain_id: tradeParams.network,
                token_in: tradeParams.pair.split('/')[0],
                token_out: tradeParams.pair.split('/')[1],
                amount: tradeParams.quantity.toString(),
                wallet_address: walletsResponse.wallets.find(w => w.id === tradeParams.wallet_id).address,
                slippage: tradeParams.slippage,
                dex_id: tradeParams.dex
            });

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

        await promptToContinue();
    }

    // Return the public API
    return {
        showTradingMenu,
        executeTrade,
        quickTrade,
        viewTradeHistory,
        viewMarketData
    };
};
