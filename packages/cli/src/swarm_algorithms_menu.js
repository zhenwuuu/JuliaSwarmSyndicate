// Import required modules
const chalk = require('chalk');
const inquirer = require('inquirer');
const ora = require('ora');

// Initialize variables that will be set by the module consumer
let juliaBridge;
let displayHeader;

function swarmAlgorithmsMenuFactory(deps) {
    if (deps) {
        if (deps.juliaBridge) juliaBridge = deps.juliaBridge;
        if (deps.displayHeader) displayHeader = deps.displayHeader;
    }
    return { swarmAlgorithmsMenu };
}

/**
 * Display the swarm algorithms menu
 */
async function swarmAlgorithmsMenu(breadcrumbs = ['Main', 'Swarm Algorithms']) {
    try {
        while (true) {
            console.clear();
            displayHeader('Swarm Algorithms', breadcrumbs);
            const { action } = await inquirer.prompt([
                {
                    type: 'list',
                    name: 'action',
                    message: 'Choose an algorithm action:',
                    choices: [
                        { name: '1. 🧠 List Algorithms', value: 'list_algorithms' },
                        { name: '2. ➕ Add Algorithm', value: 'add_algorithm' },
                        { name: '3. 🔍 View Algorithm Details', value: 'view_algorithm' },
                        { name: '4. ⚙️ Configure Algorithm', value: 'configure_algorithm' },
                        { name: '5. 🗑️ Delete Algorithm', value: 'delete_algorithm' },
                        { name: '0. 🔙 Back to Previous Menu', value: 'back' }
                    ]
                }
            ]);
            switch (action) {
                case 'view_algorithms':
                    await viewAlgorithms(breadcrumbs);
                    break;
                case 'algorithm_details':
                    await algorithmDetails(breadcrumbs);
                    break;
                case 'configure_parameters':
                    await configureParameters(breadcrumbs);
                    break;
                case 'run_benchmark':
                    await runBenchmark(breadcrumbs);
                    break;
                case 'compare_algorithms':
                    await compareAlgorithms(breadcrumbs);
                    break;
                case 'back':
                    return;
            }
            await swarmAlgorithmsMenu(breadcrumbs);
        }
    } catch (error) {
        console.error(chalk.red('An unexpected error occurred in the Swarm Algorithms menu.'));
        console.error(chalk.red('Details:'), error.message);
        await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
    }
}

/**
 * View available swarm algorithms
 */
async function viewAlgorithms(breadcrumbs) {
    try {
        const spinner = ora('Fetching available algorithms...').start();
        let result;
        try {
            result = await juliaBridge.runJuliaCommand('Swarm.get_available_algorithms', []);
            spinner.stop();
        } catch (error) {
            spinner.fail('Failed to fetch algorithms');
            console.error(chalk.red('Could not connect to backend. Please ensure the Julia server is running.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        if (!result.success) {
            console.log(chalk.red(`Error: ${result.error || 'Failed to fetch algorithms'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        const algorithms = result.algorithms || [];
        if (algorithms.length === 0) {
            console.log(chalk.yellow('\nNo algorithms found.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        console.log(chalk.cyan('\nAvailable Swarm Algorithms:'));
        algorithms.forEach((algorithm, index) => {
            console.log(chalk.bold(`\n${index + 1}. ${algorithm.name} (${algorithm.id})`));
            console.log(`   ${algorithm.description}`);
        });
    } catch (error) {
        console.error(chalk.red('An unexpected error occurred while listing algorithms.'));
        console.error(chalk.red('Details:'), error.message);
    }
    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * View details of a specific algorithm
 */
async function algorithmDetails(breadcrumbs) {
    try {
        const spinner = ora('Fetching available algorithms...').start();
        let result;
        try {
            result = await juliaBridge.runJuliaCommand('Swarm.get_available_algorithms', []);
            spinner.stop();
        } catch (error) {
            spinner.fail('Failed to fetch algorithms');
            console.error(chalk.red('Could not connect to backend. Please ensure the Julia server is running.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        if (!result.success) {
            console.log(chalk.red(`Error: ${result.error || 'Failed to fetch algorithms'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        const algorithms = result.algorithms || [];
        if (algorithms.length === 0) {
            console.log(chalk.yellow('\nNo algorithms found.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        // Prompt user to select an algorithm
        const { algorithmId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'algorithmId',
                message: 'Select an algorithm:',
                choices: algorithms.map(algorithm => ({
                    name: algorithm.name,
                    value: algorithm.id
                }))
            }
        ]);
        // Fetch details for the selected algorithm
        const detailsSpinner = ora(`Fetching details for ${algorithmId}...`).start();
        let detailsResult;
        try {
            detailsResult = await juliaBridge.runJuliaCommand('Swarm.get_algorithm_details', [algorithmId]);
            detailsSpinner.stop();
        } catch (error) {
            detailsSpinner.fail('Failed to fetch algorithm details');
            console.error(chalk.red('Could not connect to backend. Please ensure the Julia server is running.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        if (!detailsResult.success) {
            console.log(chalk.red(`Error: ${detailsResult.error || 'Failed to fetch algorithm details'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        const algorithm = detailsResult.algorithm;
        console.log(chalk.cyan(`\nAlgorithm Details: ${algorithm.name}`));
        console.log(chalk.bold('\nOverview:'));
        console.log(`ID: ${algorithm.id}`);
        console.log(`Description: ${algorithm.description}`);
        console.log(`Category: ${algorithm.category || 'General'}`);
        console.log(`Version: ${algorithm.version || '1.0'}`);
        
        if (algorithm.parameters && algorithm.parameters.length > 0) {
            console.log(chalk.bold('\nParameters:'));
            algorithm.parameters.forEach(param => {
                console.log(`  ${param.name}: ${param.description}`);
                console.log(`    Type: ${param.type}`);
                console.log(`    Default: ${param.default}`);
                if (param.range) {
                    console.log(`    Range: ${param.range.min} to ${param.range.max}`);
                }
            });
        }
        
        if (algorithm.use_cases && algorithm.use_cases.length > 0) {
            console.log(chalk.bold('\nUse Cases:'));
            algorithm.use_cases.forEach(useCase => {
                console.log(`  - ${useCase}`);
            });
        }
        
        if (algorithm.performance) {
            console.log(chalk.bold('\nPerformance Characteristics:'));
            console.log(`  Convergence Speed: ${algorithm.performance.convergence_speed || 'Medium'}`);
            console.log(`  Exploration vs. Exploitation: ${algorithm.performance.exploration_exploitation || 'Balanced'}`);
            console.log(`  Parallelization: ${algorithm.performance.parallelization || 'Supported'}`);
            console.log(`  Memory Usage: ${algorithm.performance.memory_usage || 'Medium'}`);
        }
        
        if (algorithm.references && algorithm.references.length > 0) {
            console.log(chalk.bold('\nReferences:'));
            algorithm.references.forEach(ref => {
                console.log(`  - ${ref}`);
            });
        }
    } catch (error) {
        console.error(chalk.red('An unexpected error occurred while viewing algorithm details.'));
        console.error(chalk.red('Details:'), error.message);
    }
    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * Configure algorithm parameters
 */
async function configureParameters(breadcrumbs) {
    try {
        const spinner = ora('Fetching available algorithms...').start();
        let result;
        try {
            result = await juliaBridge.runJuliaCommand('Swarm.get_available_algorithms', []);
            spinner.stop();
        } catch (error) {
            spinner.fail('Failed to fetch algorithms');
            console.error(chalk.red('Could not connect to backend. Please ensure the Julia server is running.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        if (!result.success) {
            console.log(chalk.red(`Error: ${result.error || 'Failed to fetch algorithms'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        const algorithms = result.algorithms || [];
        if (algorithms.length === 0) {
            console.log(chalk.yellow('\nNo algorithms found.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        // Prompt user to select an algorithm
        const { algorithmId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'algorithmId',
                message: 'Select an algorithm:',
                choices: algorithms.map(algorithm => ({
                    name: algorithm.name,
                    value: algorithm.id
                }))
            }
        ]);
        // Fetch details for the selected algorithm
        const detailsSpinner = ora(`Fetching details for ${algorithmId}...`).start();
        let detailsResult;
        try {
            detailsResult = await juliaBridge.runJuliaCommand('Swarm.get_algorithm_details', [algorithmId]);
            detailsSpinner.stop();
        } catch (error) {
            detailsSpinner.fail('Failed to fetch algorithm details');
            console.error(chalk.red('Could not connect to backend. Please ensure the Julia server is running.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        if (!detailsResult.success) {
            console.log(chalk.red(`Error: ${detailsResult.error || 'Failed to fetch algorithm details'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        const algorithm = detailsResult.algorithm;
        if (!algorithm.parameters || algorithm.parameters.length === 0) {
            console.log(chalk.yellow('\nThis algorithm has no configurable parameters.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        // Prompt user for parameter values
        const paramQuestions = algorithm.parameters.map(param => {
            let question = {
                name: param.name,
                message: `${param.name} (${param.description}):`,
                default: param.default
            };
            
            if (param.type === 'number') {
                question.type = 'number';
                if (param.range) {
                    question.validate = input => {
                        if (isNaN(input)) return 'Please enter a number';
                        if (input < param.range.min) return `Minimum value is ${param.range.min}`;
                        if (input > param.range.max) return `Maximum value is ${param.range.max}`;
                        return true;
                    };
                }
            } else if (param.type === 'boolean') {
                question.type = 'confirm';
            } else if (param.type === 'select' && param.options) {
                question.type = 'list';
                question.choices = param.options;
            } else {
                question.type = 'input';
            }
            
            return question;
        });
        
        const paramValues = await inquirer.prompt(paramQuestions);
        
        // Save the configuration
        const saveSpinner = ora('Saving configuration...').start();
        
        try {
            const saveResult = await juliaBridge.runJuliaCommand('Swarm.save_algorithm_configuration', [
                algorithmId,
                paramValues
            ]);
            
            saveSpinner.stop();
            
            if (!saveResult.success) {
                console.log(chalk.red(`Error: ${saveResult.error || 'Failed to save configuration'}`));
                return;
            }
            
            console.log(chalk.green('\nConfiguration saved successfully!'));
            console.log(chalk.cyan(`\nConfiguration ID: ${saveResult.config_id}`));
        } catch (error) {
            saveSpinner.fail('Failed to save configuration');
            console.error(chalk.red('Error:'), error.message);
        }
    } catch (error) {
        console.error(chalk.red('An unexpected error occurred while configuring algorithm parameters.'));
        console.error(chalk.red('Details:'), error.message);
    }
    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * Run a benchmark for a specific algorithm
 */
async function runBenchmark(breadcrumbs) {
    try {
        const spinner = ora('Fetching available algorithms...').start();
        let result;
        try {
            result = await juliaBridge.runJuliaCommand('Swarm.get_available_algorithms', []);
            spinner.stop();
        } catch (error) {
            spinner.fail('Failed to fetch algorithms');
            console.error(chalk.red('Could not connect to backend. Please ensure the Julia server is running.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        if (!result.success) {
            console.log(chalk.red(`Error: ${result.error || 'Failed to fetch algorithms'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        const algorithms = result.algorithms || [];
        if (algorithms.length === 0) {
            console.log(chalk.yellow('\nNo algorithms found.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        // Prompt user to select an algorithm
        const { algorithmId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'algorithmId',
                message: 'Select an algorithm:',
                choices: algorithms.map(algorithm => ({
                    name: algorithm.name,
                    value: algorithm.id
                }))
            }
        ]);
        // Prompt user for benchmark parameters
        const { benchmarkType, problemDimension, numRuns } = await inquirer.prompt([
            {
                type: 'list',
                name: 'benchmarkType',
                message: 'Select benchmark type:',
                choices: [
                    { name: 'Standard Test Functions', value: 'standard' },
                    { name: 'Real-world Problems', value: 'real_world' },
                    { name: 'Custom Problem', value: 'custom' }
                ]
            },
            {
                type: 'number',
                name: 'problemDimension',
                message: 'Enter problem dimension:',
                default: 10,
                validate: input => input > 0 ? true : 'Dimension must be positive'
            },
            {
                type: 'number',
                name: 'numRuns',
                message: 'Enter number of runs:',
                default: 30,
                validate: input => input > 0 ? true : 'Number of runs must be positive'
            }
        ]);
        
        // Additional parameters for custom problem
        let customProblem = null;
        if (benchmarkType === 'custom') {
            const { problemName, problemType } = await inquirer.prompt([
                {
                    type: 'input',
                    name: 'problemName',
                    message: 'Enter problem name:',
                    default: 'Custom Problem',
                    validate: input => input.trim().length > 0 ? true : 'Problem name is required'
                },
                {
                    type: 'list',
                    name: 'problemType',
                    message: 'Select problem type:',
                    choices: [
                        { name: 'Minimization', value: 'min' },
                        { name: 'Maximization', value: 'max' }
                    ]
                }
            ]);
            
            customProblem = { name: problemName, type: problemType };
        }
        
        // Run the benchmark
        const benchmarkSpinner = ora('Running benchmark...').start();
        
        try {
            const benchmarkResult = await juliaBridge.runJuliaCommand('Swarm.run_benchmark', [
                algorithmId,
                {
                    benchmark_type: benchmarkType,
                    problem_dimension: problemDimension,
                    num_runs: numRuns,
                    custom_problem: customProblem
                }
            ]);
            
            benchmarkSpinner.stop();
            
            if (!benchmarkResult.success) {
                console.log(chalk.red(`Error: ${benchmarkResult.error || 'Failed to run benchmark'}`));
                return;
            }
            
            const results = benchmarkResult.results;
            
            console.log(chalk.green('\nBenchmark completed successfully!'));
            console.log(chalk.cyan(`\nBenchmark Results for ${results.algorithm_name}:`));
            console.log(`Benchmark Type: ${results.benchmark_type}`);
            console.log(`Problem Dimension: ${results.problem_dimension}`);
            console.log(`Number of Runs: ${results.num_runs}`);
            
            if (results.metrics) {
                console.log(chalk.bold('\nPerformance Metrics:'));
                console.log(`Best Fitness: ${results.metrics.best_fitness}`);
                console.log(`Average Fitness: ${results.metrics.avg_fitness}`);
                console.log(`Standard Deviation: ${results.metrics.std_dev}`);
                console.log(`Average Convergence Iterations: ${results.metrics.avg_convergence_iterations}`);
                console.log(`Average Execution Time: ${results.metrics.avg_execution_time} ms`);
            }
            
            if (results.problems && results.problems.length > 0) {
                console.log(chalk.bold('\nResults by Problem:'));
                results.problems.forEach(problem => {
                    console.log(`\n  ${problem.name}:`);
                    console.log(`    Best Fitness: ${problem.best_fitness}`);
                    console.log(`    Average Fitness: ${problem.avg_fitness}`);
                    console.log(`    Success Rate: ${problem.success_rate * 100}%`);
                });
            }
        } catch (error) {
            benchmarkSpinner.fail('Failed to run benchmark');
            console.error(chalk.red('Error:'), error.message);
        }
    } catch (error) {
        console.error(chalk.red('An unexpected error occurred while running a benchmark.'));
        console.error(chalk.red('Details:'), error.message);
    }
    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * Compare multiple algorithms
 */
async function compareAlgorithms(breadcrumbs) {
    try {
        const spinner = ora('Fetching available algorithms...').start();
        let result;
        try {
            result = await juliaBridge.runJuliaCommand('Swarm.get_available_algorithms', []);
            spinner.stop();
        } catch (error) {
            spinner.fail('Failed to fetch algorithms');
            console.error(chalk.red('Could not connect to backend. Please ensure the Julia server is running.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        if (!result.success) {
            console.log(chalk.red(`Error: ${result.error || 'Failed to fetch algorithms'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        const algorithms = result.algorithms || [];
        if (algorithms.length === 0) {
            console.log(chalk.yellow('\nNo algorithms found.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        // Prompt user to select algorithms
        const { algorithmIds } = await inquirer.prompt([
            {
                type: 'checkbox',
                name: 'algorithmIds',
                message: 'Select algorithms to compare:',
                choices: algorithms.map(algorithm => ({
                    name: algorithm.name,
                    value: algorithm.id
                })),
                validate: input => input.length >= 2 ? true : 'Please select at least 2 algorithms'
            }
        ]);
        // Prompt user for comparison parameters
        const { benchmarkType, problemDimension, numRuns } = await inquirer.prompt([
            {
                type: 'list',
                name: 'benchmarkType',
                message: 'Select benchmark type:',
                choices: [
                    { name: 'Standard Test Functions', value: 'standard' },
                    { name: 'Real-world Problems', value: 'real_world' }
                ]
            },
            {
                type: 'number',
                name: 'problemDimension',
                message: 'Enter problem dimension:',
                default: 10,
                validate: input => input > 0 ? true : 'Dimension must be positive'
            },
            {
                type: 'number',
                name: 'numRuns',
                message: 'Enter number of runs:',
                default: 30,
                validate: input => input > 0 ? true : 'Number of runs must be positive'
            }
        ]);
        // Run the comparison
        const comparisonSpinner = ora('Running comparison...').start();
        try {
            const comparisonResult = await juliaBridge.runJuliaCommand('Swarm.compare_algorithms', [
                algorithmIds,
                {
                    benchmark_type: benchmarkType,
                    problem_dimension: problemDimension,
                    num_runs: numRuns
                }
            ]);
            comparisonSpinner.stop();
            if (!comparisonResult.success) {
                console.log(chalk.red(`Error: ${comparisonResult.error || 'Failed to run comparison'}`));
                await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
                return;
            }
            const results = comparisonResult.results;
            console.log(chalk.green('\nComparison completed successfully!'));
            console.log(chalk.cyan('\nComparison Results:'));
            console.log(`Benchmark Type: ${results.benchmark_type}`);
            console.log(`Problem Dimension: ${results.problem_dimension}`);
            console.log(`Number of Runs: ${results.num_runs}`);
            if (results.algorithms && results.algorithms.length > 0) {
                console.log(chalk.bold('\nAlgorithm Rankings:'));
                results.algorithms.forEach((algorithm, index) => {
                    console.log(`\n${index + 1}. ${algorithm.name}:`);
                    console.log(`   Average Fitness: ${algorithm.avg_fitness}`);
                    console.log(`   Average Convergence Iterations: ${algorithm.avg_convergence_iterations}`);
                    console.log(`   Average Execution Time: ${algorithm.avg_execution_time} ms`);
                    console.log(`   Success Rate: ${algorithm.success_rate * 100}%`);
                });
            }
            if (results.problems && results.problems.length > 0) {
                console.log(chalk.bold('\nResults by Problem:'));
                results.problems.forEach(problem => {
                    console.log(`\n  ${problem.name}:`);
                    problem.algorithms.forEach(algorithm => {
                        console.log(`    ${algorithm.name}: ${algorithm.best_fitness} (${algorithm.success_rate * 100}% success)`);
                    });
                });
            }
            if (results.statistical_tests) {
                console.log(chalk.bold('\nStatistical Tests:'));
                console.log(`  Friedman Test p-value: ${results.statistical_tests.friedman_p_value}`);
                if (results.statistical_tests.post_hoc_tests) {
                    console.log('  Post-hoc Tests:');
                    results.statistical_tests.post_hoc_tests.forEach(test => {
                        console.log(`    ${test.algorithm1} vs ${test.algorithm2}: p-value = ${test.p_value} (${test.significant ? 'Significant' : 'Not significant'})`);
                    });
                }
            }
        } catch (error) {
            comparisonSpinner.fail('Failed to run comparison');
            console.error(chalk.red('Error:'), error.message);
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
    } catch (error) {
        console.error(chalk.red('An unexpected error occurred while comparing algorithms.'));
        console.error(chalk.red('Details:'), error.message);
    }
    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

module.exports = swarmAlgorithmsMenuFactory;
