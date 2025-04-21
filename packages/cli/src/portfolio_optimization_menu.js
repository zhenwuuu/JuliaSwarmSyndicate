// =============================================================================
// Portfolio Optimization Menu
// =============================================================================
const chalk = require('chalk');
const inquirer = require('inquirer');
const ora = require('ora');

let juliaBridge;
let displayHeader;

function portfolioOptimizationMenuFactory(deps) {
    if (deps) {
        if (deps.juliaBridge) juliaBridge = deps.juliaBridge;
        if (deps.displayHeader) displayHeader = deps.displayHeader;
    }
    return { portfolioOptimizationMenu };
}

async function portfolioOptimizationMenu() {
    while (true) {
        console.clear();
        displayHeader('Portfolio Optimization');

        console.log(chalk.cyan(`
      ╔══════════════════════════════════════════╗
      ║        Portfolio Optimization            ║
      ║                                          ║
      ║  💼 Optimize and rebalance investment     ║
      ║     portfolios using swarm intelligence. ║
      ║                                          ║
      ╚══════════════════════════════════════════╝
    `));

        const { action } = await inquirer.prompt([
            {
                type: 'list',
                name: 'action',
                message: '💼 Choose an action:',
                choices: [
                    'Create Portfolio',
                    'View Portfolio',
                    'Rebalance Portfolio',
                    'View Efficient Frontier',
                    'Compare Strategies',
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
            case 'Create Portfolio':
                await createPortfolio();
                break;
            case 'View Portfolio':
                await viewPortfolio();
                break;
            case 'Rebalance Portfolio':
                await rebalancePortfolio();
                break;
            case 'View Efficient Frontier':
                await viewEfficientFrontier();
                break;
            case 'Compare Strategies':
                await compareStrategies();
                break;
            case 'Back to Main Menu':
                return;
        }
    }
}

async function createPortfolio() {
    try {
        // Get portfolio name
        const { portfolioName } = await inquirer.prompt([
            {
                type: 'input',
                name: 'portfolioName',
                message: 'Enter portfolio name:',
                validate: input => input.length > 0 ? true : 'Portfolio name is required'
            }
        ]);

        // Get number of assets
        const { numAssets } = await inquirer.prompt([
            {
                type: 'number',
                name: 'numAssets',
                message: 'How many assets in the portfolio?',
                default: 5,
                validate: input => input > 0 ? true : 'Number of assets must be positive'
            }
        ]);

        // Get cash amount
        const { cash } = await inquirer.prompt([
            {
                type: 'number',
                name: 'cash',
                message: 'Enter cash amount:',
                default: 10000,
                validate: input => input >= 0 ? true : 'Cash amount must be non-negative'
            }
        ]);

        // Create assets
        const assets = [];

        for (let i = 1; i <= numAssets; i++) {
            const { assetSymbol, assetName, assetType, currentPrice, currentWeight, minWeight, maxWeight } = await inquirer.prompt([
                {
                    type: 'input',
                    name: 'assetSymbol',
                    message: `Enter symbol for asset ${i}:`,
                    default: `ASSET${i}`,
                    validate: input => input.length > 0 ? true : 'Asset symbol is required'
                },
                {
                    type: 'input',
                    name: 'assetName',
                    message: `Enter name for asset ${i}:`,
                    default: `Asset ${i}`,
                    validate: input => input.length > 0 ? true : 'Asset name is required'
                },
                {
                    type: 'list',
                    name: 'assetType',
                    message: `Select type for asset ${i}:`,
                    choices: ['stock', 'bond', 'crypto', 'commodity', 'real_estate'],
                    default: 'stock'
                },
                {
                    type: 'number',
                    name: 'currentPrice',
                    message: `Enter current price for asset ${i}:`,
                    default: 100,
                    validate: input => input > 0 ? true : 'Price must be positive'
                },
                {
                    type: 'number',
                    name: 'currentWeight',
                    message: `Enter current weight (%) for asset ${i}:`,
                    default: 100 / numAssets,
                    validate: input => input >= 0 && input <= 100 ? true : 'Weight must be between 0 and 100'
                },
                {
                    type: 'number',
                    name: 'minWeight',
                    message: `Enter minimum weight (%) for asset ${i}:`,
                    default: 5,
                    validate: input => input >= 0 && input <= 100 ? true : 'Weight must be between 0 and 100'
                },
                {
                    type: 'number',
                    name: 'maxWeight',
                    message: `Enter maximum weight (%) for asset ${i}:`,
                    default: 50,
                    validate: input => input >= 0 && input <= 100 ? true : 'Weight must be between 0 and 100'
                }
            ]);

            assets.push({
                id: `asset-${i}`,
                symbol: assetSymbol,
                name: assetName,
                asset_type: assetType,
                current_price: currentPrice,
                current_weight: currentWeight / 100, // Convert from percentage to decimal
                min_weight: minWeight / 100, // Convert from percentage to decimal
                max_weight: maxWeight / 100 // Convert from percentage to decimal
            });
        }

        // Normalize weights to sum to 1
        const totalWeight = assets.reduce((sum, asset) => sum + asset.current_weight, 0);
        assets.forEach(asset => asset.current_weight = asset.current_weight / totalWeight);

        const spinner = ora('Creating portfolio...').start();

        // Create the portfolio
        const portfolioResult = await juliaBridge.runJuliaCommand('Finance.create_portfolio', [
            `portfolio-${Date.now()}`,
            portfolioName,
            assets,
            cash
        ]);

        spinner.stop();

        if (!portfolioResult.success) {
            console.log(chalk.red(`Error: ${portfolioResult.error || 'Failed to create portfolio'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        console.log(chalk.green('Portfolio created successfully!'));
        console.log(chalk.cyan(`\nPortfolio Information:`));
        console.log(`Name: ${portfolioName}`);
        console.log(`ID: ${portfolioResult.portfolio_id}`);
        console.log(`Assets: ${numAssets}`);
        console.log(`Cash: $${cash.toFixed(2)}`);

    } catch (error) {
        console.error(chalk.red(`Error: ${error.message}`));
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

async function viewPortfolio() {
    try {
        // Get list of portfolios
        const portfoliosResult = await juliaBridge.runJuliaCommand('Finance.list_portfolios', []);

        if (!portfoliosResult.success || !portfoliosResult.portfolios || portfoliosResult.portfolios.length === 0) {
            console.log(chalk.yellow('No portfolios found. Please create a portfolio first.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        // Select a portfolio
        const { portfolioId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'portfolioId',
                message: 'Select a portfolio:',
                choices: portfoliosResult.portfolios.map(portfolio => ({
                    name: `${portfolio.name} (${portfolio.id})`,
                    value: portfolio.id
                }))
            }
        ]);

        const spinner = ora('Fetching portfolio details...').start();

        // Get portfolio details
        const portfolioResult = await juliaBridge.runJuliaCommand('Finance.get_portfolio', [portfolioId]);

        spinner.stop();

        if (!portfolioResult.success) {
            console.log(chalk.red(`Error: ${portfolioResult.error || 'Failed to fetch portfolio details'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        const portfolio = portfolioResult.portfolio;

        // Calculate portfolio metrics
        const metricsResult = await juliaBridge.runJuliaCommand('Finance.calculate_portfolio_metrics', [
            portfolio.assets,
            portfolio.assets.map(asset => asset.current_weight)
        ]);

        // Display portfolio information
        console.log(chalk.cyan(`\nPortfolio: ${portfolio.name} (${portfolio.id})`));
        console.log(`Total Value: $${portfolio.total_value.toFixed(2)}`);
        console.log(`Cash: $${portfolio.cash.toFixed(2)}`);
        console.log(`Assets: ${portfolio.assets.length}`);

        if (metricsResult.success) {
            console.log(`Expected Return: ${(metricsResult.metrics.expected_return * 100).toFixed(2)}%`);
            console.log(`Risk: ${(metricsResult.metrics.risk * 100).toFixed(2)}%`);
            console.log(`Sharpe Ratio: ${metricsResult.metrics.sharpe_ratio.toFixed(2)}`);
        }

        console.log(chalk.cyan('\nAsset Allocations:'));

        // Sort assets by weight (descending)
        const sortedAssets = [...portfolio.assets].sort((a, b) => b.current_weight - a.current_weight);

        for (const asset of sortedAssets) {
            console.log(`  ${asset.name} (${asset.symbol}): ${(asset.current_weight * 100).toFixed(2)}%`);
            console.log(`    Type: ${asset.asset_type}`);
            console.log(`    Price: $${asset.current_price.toFixed(2)}`);
            console.log(`    Min Weight: ${(asset.min_weight * 100).toFixed(2)}%`);
            console.log(`    Max Weight: ${(asset.max_weight * 100).toFixed(2)}%`);
        }

    } catch (error) {
        console.error(chalk.red(`Error: ${error.message}`));
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

async function rebalancePortfolio() {
    try {
        // Get list of portfolios
        const portfoliosResult = await juliaBridge.runJuliaCommand('Finance.list_portfolios', []);

        if (!portfoliosResult.success || !portfoliosResult.portfolios || portfoliosResult.portfolios.length === 0) {
            console.log(chalk.yellow('No portfolios found. Please create a portfolio first.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        // Select a portfolio
        const { portfolioId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'portfolioId',
                message: 'Select a portfolio:',
                choices: portfoliosResult.portfolios.map(portfolio => ({
                    name: `${portfolio.name} (${portfolio.id})`,
                    value: portfolio.id
                }))
            }
        ]);

        // Select a rebalancing strategy
        const { strategy } = await inquirer.prompt([
            {
                type: 'list',
                name: 'strategy',
                message: 'Select a rebalancing strategy:',
                choices: [
                    { name: 'Equal Weight', value: 'EQUAL_WEIGHT' },
                    { name: 'Minimum Variance', value: 'MINIMUM_VARIANCE' },
                    { name: 'Maximum Sharpe Ratio', value: 'MAXIMUM_SHARPE' },
                    { name: 'Risk Parity', value: 'RISK_PARITY' },
                    { name: 'Maximum Return', value: 'MAXIMUM_RETURN' },
                    { name: 'Multi-Objective Optimization', value: 'MULTI_OBJECTIVE' }
                ]
            }
        ]);

        // Get strategy-specific parameters
        let params = {};

        if (strategy === 'MINIMUM_VARIANCE') {
            const { targetReturn } = await inquirer.prompt([
                {
                    type: 'number',
                    name: 'targetReturn',
                    message: 'Enter target return (% per year):',
                    default: 10,
                    validate: input => !isNaN(input) ? true : 'Target return must be a number'
                }
            ]);

            params.target_return = targetReturn / 100; // Convert from percentage to decimal
        } else if (strategy === 'MAXIMUM_RETURN') {
            const { targetRisk } = await inquirer.prompt([
                {
                    type: 'number',
                    name: 'targetRisk',
                    message: 'Enter maximum risk (% per year):',
                    default: 20,
                    validate: input => input > 0 ? true : 'Maximum risk must be positive'
                }
            ]);

            params.target_risk = targetRisk / 100; // Convert from percentage to decimal
        } else if (strategy === 'MULTI_OBJECTIVE') {
            const { populationSize, maxIterations, paretoFrontSize } = await inquirer.prompt([
                {
                    type: 'number',
                    name: 'populationSize',
                    message: 'Enter population size:',
                    default: 100,
                    validate: input => input > 0 ? true : 'Population size must be positive'
                },
                {
                    type: 'number',
                    name: 'maxIterations',
                    message: 'Enter maximum iterations:',
                    default: 100,
                    validate: input => input > 0 ? true : 'Maximum iterations must be positive'
                },
                {
                    type: 'number',
                    name: 'paretoFrontSize',
                    message: 'Enter Pareto front size:',
                    default: 50,
                    validate: input => input > 0 ? true : 'Pareto front size must be positive'
                }
            ]);

            params = {
                population_size: populationSize,
                max_iterations: maxIterations,
                pareto_front_size: paretoFrontSize
            };
        }

        const spinner = ora('Rebalancing portfolio...').start();

        // Rebalance the portfolio
        const rebalanceResult = await juliaBridge.runJuliaCommand('Finance.rebalance_portfolio', [
            portfolioId,
            strategy,
            params
        ]);

        spinner.stop();

        if (!rebalanceResult.success) {
            console.log(chalk.red(`Error: ${rebalanceResult.error || 'Failed to rebalance portfolio'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        const result = rebalanceResult.result;

        // Display rebalance results
        console.log(chalk.green('Portfolio rebalanced successfully!'));
        console.log(chalk.cyan('\nRebalance Results:'));
        console.log(`Strategy: ${result.strategy}`);
        console.log(`Expected Return: ${(result.expected_return * 100).toFixed(2)}%`);
        console.log(`Expected Risk: ${(result.expected_risk * 100).toFixed(2)}%`);
        console.log(`Sharpe Ratio: ${result.sharpe_ratio.toFixed(2)}`);

        console.log(chalk.cyan('\nNew Asset Allocations:'));

        // Get the portfolio
        const portfolioResult = await juliaBridge.runJuliaCommand('Finance.get_portfolio', [portfolioId]);

        if (portfolioResult.success) {
            const portfolio = portfolioResult.portfolio;

            for (let i = 0; i < portfolio.assets.length; i++) {
                const asset = portfolio.assets[i];
                const newWeight = result.new_weights[i];
                const oldWeight = asset.current_weight;
                const change = newWeight - oldWeight;

                console.log(`  ${asset.name} (${asset.symbol}): ${(newWeight * 100).toFixed(2)}% ` +
                            `(${change >= 0 ? "+" : ""}${(change * 100).toFixed(2)}%)`);
            }
        }

        // Ask if user wants to apply the rebalance
        const { applyRebalance } = await inquirer.prompt([
            {
                type: 'confirm',
                name: 'applyRebalance',
                message: 'Do you want to apply this rebalance?',
                default: false
            }
        ]);

        if (applyRebalance) {
            const applySpinner = ora('Applying rebalance...').start();

            // Apply the rebalance
            const applyResult = await juliaBridge.runJuliaCommand('Finance.apply_rebalance', [
                portfolioId,
                result
            ]);

            applySpinner.stop();

            if (!applyResult.success) {
                console.log(chalk.red(`Error: ${applyResult.error || 'Failed to apply rebalance'}`));
            } else {
                console.log(chalk.green('Rebalance applied successfully!'));
            }
        }

    } catch (error) {
        console.error(chalk.red(`Error: ${error.message}`));
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

async function viewEfficientFrontier() {
    try {
        // Get list of portfolios
        const portfoliosResult = await juliaBridge.runJuliaCommand('Finance.list_portfolios', []);

        if (!portfoliosResult.success || !portfoliosResult.portfolios || portfoliosResult.portfolios.length === 0) {
            console.log(chalk.yellow('No portfolios found. Please create a portfolio first.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        // Select a portfolio
        const { portfolioId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'portfolioId',
                message: 'Select a portfolio:',
                choices: portfoliosResult.portfolios.map(portfolio => ({
                    name: `${portfolio.name} (${portfolio.id})`,
                    value: portfolio.id
                }))
            }
        ]);

        // Get number of points
        const { numPoints } = await inquirer.prompt([
            {
                type: 'number',
                name: 'numPoints',
                message: 'Enter number of points on the efficient frontier:',
                default: 50,
                validate: input => input > 0 ? true : 'Number of points must be positive'
            }
        ]);

        const spinner = ora('Generating efficient frontier...').start();

        // Generate the efficient frontier
        const frontierResult = await juliaBridge.runJuliaCommand('Finance.generate_efficient_frontier', [
            portfolioId,
            numPoints
        ]);

        spinner.stop();

        if (!frontierResult.success) {
            console.log(chalk.red(`Error: ${frontierResult.error || 'Failed to generate efficient frontier'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        const frontier = frontierResult.frontier;

        console.log(chalk.green('Efficient frontier generated successfully!'));
        console.log(chalk.cyan('\nEfficient Frontier Points:'));

        // Display a sample of points
        const sampleSize = Math.min(10, frontier.length);
        const step = Math.floor(frontier.length / sampleSize);

        for (let i = 0; i < frontier.length; i += step) {
            const point = frontier[i];
            console.log(`  Risk: ${(point.risk * 100).toFixed(2)}%, Return: ${(point.return * 100).toFixed(2)}%, Sharpe: ${point.sharpe.toFixed(2)}`);
        }

        // Generate and save the plot
        const plotResult = await juliaBridge.runJuliaCommand('Finance.plot_efficient_frontier', [
            portfolioId,
            numPoints,
            "efficient_frontier.png"
        ]);

        if (plotResult.success) {
            console.log(chalk.green('\nEfficient frontier plot saved to efficient_frontier.png'));
        }

    } catch (error) {
        console.error(chalk.red(`Error: ${error.message}`));
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

async function compareStrategies() {
    try {
        // Get list of portfolios
        const portfoliosResult = await juliaBridge.runJuliaCommand('Finance.list_portfolios', []);

        if (!portfoliosResult.success || !portfoliosResult.portfolios || portfoliosResult.portfolios.length === 0) {
            console.log(chalk.yellow('No portfolios found. Please create a portfolio first.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        // Select a portfolio
        const { portfolioId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'portfolioId',
                message: 'Select a portfolio:',
                choices: portfoliosResult.portfolios.map(portfolio => ({
                    name: `${portfolio.name} (${portfolio.id})`,
                    value: portfolio.id
                }))
            }
        ]);

        const spinner = ora('Comparing strategies...').start();

        // Define strategies to compare
        const strategies = [
            "EQUAL_WEIGHT",
            "MINIMUM_VARIANCE",
            "MAXIMUM_SHARPE",
            "RISK_PARITY",
            "MAXIMUM_RETURN"
        ];

        const strategyNames = [
            "Equal Weight",
            "Minimum Variance",
            "Maximum Sharpe",
            "Risk Parity",
            "Maximum Return"
        ];

        // Run each strategy
        const results = [];

        for (let i = 0; i < strategies.length; i++) {
            const strategy = strategies[i];
            const name = strategyNames[i];

            // Rebalance with this strategy
            const rebalanceResult = await juliaBridge.runJuliaCommand('Finance.rebalance_portfolio', [
                portfolioId,
                strategy,
                {}
            ]);

            if (rebalanceResult.success) {
                results.push({
                    name: name,
                    strategy: strategy,
                    result: rebalanceResult.result
                });
            }
        }

        spinner.stop();

        if (results.length === 0) {
            console.log(chalk.red('Failed to run any strategies.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        console.log(chalk.green('Strategy comparison completed!'));
        console.log(chalk.cyan('\nStrategy Comparison:'));

        // Create a table of results
        console.log('┌─────────────────────┬────────────┬──────────┬─────────────┐');
        console.log('│ Strategy            │ Return (%) │ Risk (%) │ Sharpe     │');
        console.log('├─────────────────────┼────────────┼──────────┼─────────────┤');

        for (const result of results) {
            const returnStr = (result.result.expected_return * 100).toFixed(2).padStart(8);
            const riskStr = (result.result.expected_risk * 100).toFixed(2).padStart(6);
            const sharpeStr = result.result.sharpe_ratio.toFixed(2).padStart(9);

            console.log(`│ ${result.name.padEnd(19)} │ ${returnStr} │ ${riskStr} │ ${sharpeStr} │`);
        }

        console.log('└─────────────────────┴────────────┴──────────┴─────────────┘');

        // Generate and save the comparison plot
        const plotResult = await juliaBridge.runJuliaCommand('Finance.plot_strategy_comparison', [
            portfolioId,
            "strategy_comparison.png"
        ]);

        if (plotResult.success) {
            console.log(chalk.green('\nStrategy comparison plot saved to strategy_comparison.png'));
        }

    } catch (error) {
        console.error(chalk.red(`Error: ${error.message}`));
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

module.exports = portfolioOptimizationMenuFactory;
