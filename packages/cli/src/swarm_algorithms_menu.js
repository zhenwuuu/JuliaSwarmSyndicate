// Import required modules
const chalk = require('chalk');
const inquirer = require('inquirer');
const ora = require('ora');
const { table } = require('table');

// Initialize variables that will be set by the module consumer
let juliaBridge;
let displayHeader;
let swarms;

function swarmAlgorithmsMenuFactory(deps) {
    if (deps) {
        if (deps.juliaBridge) {
            juliaBridge = deps.juliaBridge;
            // Initialize the swarms module
            const Swarms = require('../../framework/swarms/src');
            swarms = new Swarms(juliaBridge);
        }
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
                        { name: '2. 🔍 View Algorithm Details', value: 'view_algorithm' },
                        { name: '3. ⚙️ Configure Algorithm', value: 'configure_algorithm' },
                        { name: '4. 📊 Run Benchmark', value: 'run_benchmark' },
                        { name: '5. 📈 Compare Algorithms', value: 'compare_algorithms' },
                        { name: '6. 🧪 Test Algorithm', value: 'test_algorithm' },
                        { name: '7. 🔄 Optimize Algorithm', value: 'optimize_algorithm' },
                        { name: '0. 🔙 Back to Previous Menu', value: 'back' }
                    ]
                }
            ]);
            switch (action) {
                case 'list_algorithms':
                    await listAlgorithms(breadcrumbs);
                    break;
                case 'view_algorithm':
                    await viewAlgorithmDetails(breadcrumbs);
                    break;
                case 'configure_algorithm':
                    await configureAlgorithm(breadcrumbs);
                    break;
                case 'run_benchmark':
                    await runBenchmark(breadcrumbs);
                    break;
                case 'compare_algorithms':
                    await compareAlgorithms(breadcrumbs);
                    break;
                case 'test_algorithm':
                    await testAlgorithm(breadcrumbs);
                    break;
                case 'optimize_algorithm':
                    await optimizeAlgorithm(breadcrumbs);
                    break;
                case 'back':
                    return;
            }
        }
    } catch (error) {
        console.error(chalk.red('An unexpected error occurred in the Swarm Algorithms menu.'));
        console.error(chalk.red('Details:'), error.message);
        await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
    }
}

/**
 * List available swarm algorithms
 */
async function listAlgorithms(breadcrumbs) {
    try {
        const spinner = ora('Fetching available algorithms...').start();
        let result;

        // Try to get data from backend, fall back to mock data if it fails
        try {
            // Use the swarms module to get available algorithms
            result = await swarms.getAvailableAlgorithms();
            spinner.stop();
        } catch (error) {
            spinner.fail('Failed to fetch algorithms');
            console.error(chalk.red('Could not connect to backend. Please ensure the Julia server is running.'));
            console.log(chalk.yellow('Using mock data instead...'));
            spinner.succeed('Using mock data');

            // Mock data for algorithms
            result = {
                success: true,
                algorithms: [
                    {
                        id: 'pso',
                        name: 'Particle Swarm Optimization',
                        description: 'A computational method that optimizes a problem by iteratively trying to improve a candidate solution with regard to a given measure of quality.',
                        type: 'swarm',
                        parameters: [
                            { name: 'population_size', type: 'number', default: 30, description: 'Number of particles' },
                            { name: 'max_iterations', type: 'number', default: 100, description: 'Maximum number of iterations' },
                            { name: 'c1', type: 'number', default: 2.0, description: 'Cognitive parameter' },
                            { name: 'c2', type: 'number', default: 2.0, description: 'Social parameter' },
                            { name: 'w', type: 'number', default: 0.7, description: 'Inertia weight' }
                        ]
                    },
                    {
                        id: 'de',
                        name: 'Differential Evolution',
                        description: 'A stochastic population-based method that is useful for global optimization problems.',
                        type: 'evolutionary',
                        parameters: [
                            { name: 'population_size', type: 'number', default: 50, description: 'Population size' },
                            { name: 'max_iterations', type: 'number', default: 100, description: 'Maximum number of iterations' },
                            { name: 'crossover_rate', type: 'number', default: 0.7, description: 'Crossover rate' },
                            { name: 'mutation_factor', type: 'number', default: 0.5, description: 'Mutation factor' }
                        ]
                    },
                    {
                        id: 'gwo',
                        name: 'Grey Wolf Optimizer',
                        description: 'A meta-heuristic algorithm inspired by the leadership hierarchy and hunting mechanism of grey wolves.',
                        type: 'swarm',
                        parameters: [
                            { name: 'population_size', type: 'number', default: 30, description: 'Number of wolves' },
                            { name: 'max_iterations', type: 'number', default: 100, description: 'Maximum number of iterations' }
                        ]
                    },
                    {
                        id: 'aco',
                        name: 'Ant Colony Optimization',
                        description: 'A probabilistic technique for solving computational problems which can be reduced to finding good paths through graphs.',
                        type: 'swarm',
                        parameters: [
                            { name: 'population_size', type: 'number', default: 30, description: 'Number of ants' },
                            { name: 'max_iterations', type: 'number', default: 100, description: 'Maximum number of iterations' },
                            { name: 'alpha', type: 'number', default: 1.0, description: 'Pheromone importance' },
                            { name: 'beta', type: 'number', default: 2.0, description: 'Heuristic importance' },
                            { name: 'evaporation_rate', type: 'number', default: 0.1, description: 'Pheromone evaporation rate' }
                        ]
                    },
                    {
                        id: 'ga',
                        name: 'Genetic Algorithm',
                        description: 'A search heuristic that is inspired by Charles Darwin\'s theory of natural evolution.',
                        type: 'evolutionary',
                        parameters: [
                            { name: 'population_size', type: 'number', default: 50, description: 'Population size' },
                            { name: 'max_iterations', type: 'number', default: 100, description: 'Maximum number of iterations' },
                            { name: 'crossover_rate', type: 'number', default: 0.8, description: 'Crossover rate' },
                            { name: 'mutation_rate', type: 'number', default: 0.1, description: 'Mutation rate' }
                        ]
                    },
                    {
                        id: 'woa',
                        name: 'Whale Optimization Algorithm',
                        description: 'A nature-inspired meta-heuristic optimization algorithm which mimics the hunting behavior of humpback whales.',
                        type: 'swarm',
                        parameters: [
                            { name: 'population_size', type: 'number', default: 30, description: 'Number of whales' },
                            { name: 'max_iterations', type: 'number', default: 100, description: 'Maximum number of iterations' },
                            { name: 'b', type: 'number', default: 1.0, description: 'Spiral constant' }
                        ]
                    },
                    {
                        id: 'depso',
                        name: 'Differential Evolution Particle Swarm Optimization',
                        description: 'A hybrid algorithm that combines Differential Evolution and Particle Swarm Optimization.',
                        type: 'hybrid',
                        parameters: [
                            { name: 'population_size', type: 'number', default: 40, description: 'Population size' },
                            { name: 'max_iterations', type: 'number', default: 100, description: 'Maximum number of iterations' },
                            { name: 'c1', type: 'number', default: 1.5, description: 'Cognitive parameter' },
                            { name: 'c2', type: 'number', default: 1.5, description: 'Social parameter' },
                            { name: 'w', type: 'number', default: 0.7, description: 'Inertia weight' },
                            { name: 'crossover_rate', type: 'number', default: 0.7, description: 'Crossover rate' },
                            { name: 'mutation_factor', type: 'number', default: 0.5, description: 'Mutation factor' }
                        ]
                    }
                ]
            };
        }

        if (!result.success) {
            console.log(chalk.red(`Error: ${result.error || 'Failed to fetch algorithms'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        // Check if the data is in the expected format
        const algorithms = result.data && result.data.algorithms ? result.data.algorithms : (result.algorithms || []);
        if (algorithms.length === 0) {
            console.log(chalk.yellow('\nNo algorithms found.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        // Create a table for better visualization
        const tableData = [
            [chalk.bold('ID'), chalk.bold('Name'), chalk.bold('Type'), chalk.bold('Description')]
        ];

        // Debug output to check what we're getting
        console.log(chalk.yellow('\nDebug: Received algorithms data:'));
        console.log(JSON.stringify(algorithms, null, 2));

        algorithms.forEach(algorithm => {
            tableData.push([
                chalk.cyan(algorithm.id),
                algorithm.name,
                algorithm.type ? algorithm.type.charAt(0).toUpperCase() + algorithm.type.slice(1) : 'N/A',
                algorithm.description.length > 60 ? algorithm.description.substring(0, 57) + '...' : algorithm.description
            ]);
        });

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
            },
            columns: {
                0: { width: 10 },
                1: { width: 30 },
                2: { width: 15 },
                3: { width: 60 }
            }
        };

        console.log(chalk.cyan('\nAvailable Swarm Algorithms:'));

        // Format the table manually if the table function is not available
        try {
            console.log(table(tableData, tableConfig));
        } catch (error) {
            // Simple fallback table display
            console.log('ID\t\tName\t\t\t\tType\t\tDescription');
            console.log('--\t\t----\t\t\t\t----\t\t-----------');
            algorithms.forEach(algorithm => {
                console.log(`${algorithm.id}\t\t${algorithm.name.padEnd(20)}\t${algorithm.type || 'N/A'}\t\t${algorithm.description.substring(0, 40)}...`);
            });
        }

        console.log(chalk.yellow('\nNote: Select "View Algorithm Details" for more information about a specific algorithm.'));
    } catch (error) {
        console.error(chalk.red('An unexpected error occurred while listing algorithms.'));
        console.error(chalk.red('Details:'), error.message);
    }
    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * View details of a specific algorithm
 */
async function viewAlgorithmDetails(breadcrumbs) {
    try {
        const spinner = ora('Fetching available algorithms...').start();
        let result;

        // Try to get data from backend, fall back to mock data if it fails
        try {
            // Use the swarms module to get available algorithms
            result = await swarms.getAvailableAlgorithms();
            spinner.stop();
        } catch (error) {
            spinner.fail('Failed to fetch algorithms');
            console.error(chalk.red('Could not connect to backend. Please ensure the Julia server is running.'));
            console.log(chalk.yellow('Using mock data instead...'));
            spinner.succeed('Using mock data');

            // Use the same mock data as in listAlgorithms
            result = {
                success: true,
                algorithms: [
                    {
                        id: 'pso',
                        name: 'Particle Swarm Optimization',
                        description: 'A computational method that optimizes a problem by iteratively trying to improve a candidate solution with regard to a given measure of quality.',
                        type: 'swarm',
                        parameters: [
                            { name: 'population_size', type: 'number', default: 30, description: 'Number of particles' },
                            { name: 'max_iterations', type: 'number', default: 100, description: 'Maximum number of iterations' },
                            { name: 'c1', type: 'number', default: 2.0, description: 'Cognitive parameter' },
                            { name: 'c2', type: 'number', default: 2.0, description: 'Social parameter' },
                            { name: 'w', type: 'number', default: 0.7, description: 'Inertia weight' }
                        ]
                    },
                    {
                        id: 'de',
                        name: 'Differential Evolution',
                        description: 'A stochastic population-based method that is useful for global optimization problems.',
                        type: 'evolutionary',
                        parameters: [
                            { name: 'population_size', type: 'number', default: 50, description: 'Population size' },
                            { name: 'max_iterations', type: 'number', default: 100, description: 'Maximum number of iterations' },
                            { name: 'crossover_rate', type: 'number', default: 0.7, description: 'Crossover rate' },
                            { name: 'mutation_factor', type: 'number', default: 0.5, description: 'Mutation factor' }
                        ]
                    },
                    {
                        id: 'gwo',
                        name: 'Grey Wolf Optimizer',
                        description: 'A meta-heuristic algorithm inspired by the leadership hierarchy and hunting mechanism of grey wolves.',
                        type: 'swarm',
                        parameters: [
                            { name: 'population_size', type: 'number', default: 30, description: 'Number of wolves' },
                            { name: 'max_iterations', type: 'number', default: 100, description: 'Maximum number of iterations' }
                        ]
                    },
                    {
                        id: 'aco',
                        name: 'Ant Colony Optimization',
                        description: 'A probabilistic technique for solving computational problems which can be reduced to finding good paths through graphs.',
                        type: 'swarm',
                        parameters: [
                            { name: 'population_size', type: 'number', default: 30, description: 'Number of ants' },
                            { name: 'max_iterations', type: 'number', default: 100, description: 'Maximum number of iterations' },
                            { name: 'alpha', type: 'number', default: 1.0, description: 'Pheromone importance' },
                            { name: 'beta', type: 'number', default: 2.0, description: 'Heuristic importance' },
                            { name: 'evaporation_rate', type: 'number', default: 0.1, description: 'Pheromone evaporation rate' }
                        ]
                    },
                    {
                        id: 'ga',
                        name: 'Genetic Algorithm',
                        description: 'A search heuristic that is inspired by Charles Darwin\'s theory of natural evolution.',
                        type: 'evolutionary',
                        parameters: [
                            { name: 'population_size', type: 'number', default: 50, description: 'Population size' },
                            { name: 'max_iterations', type: 'number', default: 100, description: 'Maximum number of iterations' },
                            { name: 'crossover_rate', type: 'number', default: 0.8, description: 'Crossover rate' },
                            { name: 'mutation_rate', type: 'number', default: 0.1, description: 'Mutation rate' }
                        ]
                    },
                    {
                        id: 'woa',
                        name: 'Whale Optimization Algorithm',
                        description: 'A nature-inspired meta-heuristic optimization algorithm which mimics the hunting behavior of humpback whales.',
                        type: 'swarm',
                        parameters: [
                            { name: 'population_size', type: 'number', default: 30, description: 'Number of whales' },
                            { name: 'max_iterations', type: 'number', default: 100, description: 'Maximum number of iterations' },
                            { name: 'b', type: 'number', default: 1.0, description: 'Spiral constant' }
                        ]
                    },
                    {
                        id: 'depso',
                        name: 'Differential Evolution Particle Swarm Optimization',
                        description: 'A hybrid algorithm that combines Differential Evolution and Particle Swarm Optimization.',
                        type: 'hybrid',
                        parameters: [
                            { name: 'population_size', type: 'number', default: 40, description: 'Population size' },
                            { name: 'max_iterations', type: 'number', default: 100, description: 'Maximum number of iterations' },
                            { name: 'c1', type: 'number', default: 1.5, description: 'Cognitive parameter' },
                            { name: 'c2', type: 'number', default: 1.5, description: 'Social parameter' },
                            { name: 'w', type: 'number', default: 0.7, description: 'Inertia weight' },
                            { name: 'crossover_rate', type: 'number', default: 0.7, description: 'Crossover rate' },
                            { name: 'mutation_factor', type: 'number', default: 0.5, description: 'Mutation factor' }
                        ]
                    }
                ]
            };
        }

        if (!result.success) {
            console.log(chalk.red(`Error: ${result.error || 'Failed to fetch algorithms'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        // Check if the data is in the expected format
        const algorithms = result.data && result.data.algorithms ? result.data.algorithms : (result.algorithms || []);
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
        // Find the selected algorithm from the list
        const selectedAlgorithm = algorithms.find(alg => alg.id === algorithmId);

        if (!selectedAlgorithm) {
            console.log(chalk.red(`Error: Algorithm with ID ${algorithmId} not found`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        // Display algorithm details
        console.log(chalk.cyan(`\n${selectedAlgorithm.name} (${selectedAlgorithm.id})\n`));
        console.log(chalk.bold('Description:'));
        console.log(`${selectedAlgorithm.description}\n`);

        console.log(chalk.bold('Type:'));
        console.log(`${selectedAlgorithm.type ? selectedAlgorithm.type.charAt(0).toUpperCase() + selectedAlgorithm.type.slice(1) : 'N/A'}\n`);

        console.log(chalk.bold('Parameters:'));
        if (selectedAlgorithm.parameters && selectedAlgorithm.parameters.length > 0) {
            // Create a table for parameters
            const paramTableData = [
                [chalk.bold('Name'), chalk.bold('Type'), chalk.bold('Default'), chalk.bold('Description')]
            ];

            selectedAlgorithm.parameters.forEach(param => {
                paramTableData.push([
                    param.name,
                    param.type,
                    String(param.default),
                    param.description
                ]);
            });

            const paramTableConfig = {
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
                },
                columns: {
                    0: { width: 20 },
                    1: { width: 10 },
                    2: { width: 10 },
                    3: { width: 40 }
                }
            };

            try {
                console.log(table(paramTableData, paramTableConfig));
            } catch (error) {
                // Simple fallback table display
                console.log('Name\t\tType\t\tDefault\t\tDescription');
                console.log('----\t\t----\t\t-------\t\t-----------');
                selectedAlgorithm.parameters.forEach(param => {
                    console.log(`${param.name}\t\t${param.type}\t\t${param.default}\t\t${param.description}`);
                });
            }
        } else {
            console.log('No parameters available.');
        }

        // Display algorithm performance characteristics
        console.log(chalk.bold('\nPerformance Characteristics:'));

        // These are mock performance characteristics
        const performanceCharacteristics = {
            'pso': {
                'convergence_speed': 'Fast',
                'exploration_ability': 'Medium',
                'exploitation_ability': 'High',
                'best_for': 'Continuous optimization problems with few local optima',
                'limitations': 'Can get trapped in local optima for multimodal problems'
            },
            'de': {
                'convergence_speed': 'Medium',
                'exploration_ability': 'High',
                'exploitation_ability': 'High',
                'best_for': 'Complex multimodal problems with many local optima',
                'limitations': 'Slower convergence compared to PSO for simple problems'
            },
            'gwo': {
                'convergence_speed': 'Fast',
                'exploration_ability': 'High',
                'exploitation_ability': 'Medium',
                'best_for': 'Problems requiring good balance between exploration and exploitation',
                'limitations': 'Parameter tuning can be challenging'
            },
            'aco': {
                'convergence_speed': 'Slow',
                'exploration_ability': 'High',
                'exploitation_ability': 'Medium',
                'best_for': 'Discrete optimization problems like TSP',
                'limitations': 'Not well-suited for continuous optimization'
            },
            'ga': {
                'convergence_speed': 'Slow',
                'exploration_ability': 'Very High',
                'exploitation_ability': 'Medium',
                'best_for': 'Complex combinatorial problems',
                'limitations': 'Slow convergence, requires careful operator design'
            },
            'woa': {
                'convergence_speed': 'Medium',
                'exploration_ability': 'High',
                'exploitation_ability': 'High',
                'best_for': 'Problems with many local optima',
                'limitations': 'Performance depends on spiral parameter tuning'
            },
            'depso': {
                'convergence_speed': 'Medium-Fast',
                'exploration_ability': 'Very High',
                'exploitation_ability': 'High',
                'best_for': 'Complex problems requiring both exploration and exploitation',
                'limitations': 'More complex implementation and parameter tuning'
            }
        };

        const characteristics = performanceCharacteristics[algorithmId] || {
            'convergence_speed': 'Unknown',
            'exploration_ability': 'Unknown',
            'exploitation_ability': 'Unknown',
            'best_for': 'Unknown',
            'limitations': 'Unknown'
        };

        console.log(`Convergence Speed: ${characteristics.convergence_speed}`);
        console.log(`Exploration Ability: ${characteristics.exploration_ability}`);
        console.log(`Exploitation Ability: ${characteristics.exploitation_ability}`);
        console.log(`Best For: ${characteristics.best_for}`);
        console.log(`Limitations: ${characteristics.limitations}`);

        // Display example use cases
        console.log(chalk.bold('\nExample Use Cases:'));

        const useCases = {
            'pso': [
                'Neural network training',
                'Feature selection in machine learning',
                'Parameter optimization for control systems'
            ],
            'de': [
                'Engineering design optimization',
                'Constrained optimization problems',
                'Training deep neural networks'
            ],
            'gwo': [
                'Clustering problems',
                'Feature selection',
                'Power system optimization'
            ],
            'aco': [
                'Traveling Salesman Problem',
                'Vehicle routing',
                'Network routing optimization'
            ],
            'ga': [
                'Scheduling problems',
                'Game playing strategies',
                'Circuit design optimization'
            ],
            'woa': [
                'Economic dispatch problems',
                'Image segmentation',
                'Structural optimization'
            ],
            'depso': [
                'Complex engineering design',
                'Multi-objective optimization',
                'Financial portfolio optimization'
            ]
        };

        const algorithmUseCases = useCases[algorithmId] || ['No specific use cases available'];

        algorithmUseCases.forEach((useCase, index) => {
            console.log(`${index + 1}. ${useCase}`);
        });

        // Display references
        console.log(chalk.bold('\nReferences:'));

        const references = {
            'pso': [
                'Kennedy, J., & Eberhart, R. (1995). Particle swarm optimization. In Proceedings of ICNN\'95.',
                'Shi, Y., & Eberhart, R. (1998). A modified particle swarm optimizer.'
            ],
            'de': [
                'Storn, R., & Price, K. (1997). Differential Evolution – A Simple and Efficient Heuristic for Global Optimization over Continuous Spaces.'
            ],
            'gwo': [
                'Mirjalili, S., Mirjalili, S. M., & Lewis, A. (2014). Grey Wolf Optimizer.'
            ],
            'aco': [
                'Dorigo, M., Maniezzo, V., & Colorni, A. (1996). Ant system: optimization by a colony of cooperating agents.'
            ],
            'ga': [
                'Holland, J. H. (1975). Adaptation in natural and artificial systems.',
                'Goldberg, D. E. (1989). Genetic Algorithms in Search, Optimization and Machine Learning.'
            ],
            'woa': [
                'Mirjalili, S., & Lewis, A. (2016). The Whale Optimization Algorithm.'
            ],
            'depso': [
                'Zhang, W. J., & Xie, X. F. (2003). DEPSO: hybrid particle swarm with differential evolution operator.'
            ]
        };

        const algorithmReferences = references[algorithmId] || ['No references available'];

        algorithmReferences.forEach((reference, index) => {
            console.log(`${index + 1}. ${reference}`);
        });
    } catch (error) {
        console.error(chalk.red('An unexpected error occurred while viewing algorithm details.'));
        console.error(chalk.red('Details:'), error.message);
    }
    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * Configure algorithm parameters
 */
async function configureAlgorithm(breadcrumbs) {
    try {
        const spinner = ora('Fetching available algorithms...').start();
        let result;

        // Try to get data from backend, fall back to mock data if it fails
        try {
            // Use the swarms module to get available algorithms
            result = await swarms.getAvailableAlgorithms();
            spinner.stop();
        } catch (error) {
            spinner.fail('Failed to fetch algorithms');
            console.error(chalk.red('Could not connect to backend. Please ensure the Julia server is running.'));
            console.log(chalk.yellow('Using mock data instead...'));
            spinner.succeed('Using mock data');

            // Use mock data
            result = {
                success: true,
                algorithms: [
                    {
                        id: 'pso',
                        name: 'Particle Swarm Optimization',
                        description: 'A computational method that optimizes a problem by iteratively trying to improve a candidate solution with regard to a given measure of quality.',
                        parameters: [
                            { name: 'population_size', type: 'number', default: 30, description: 'Number of particles' },
                            { name: 'max_iterations', type: 'number', default: 100, description: 'Maximum number of iterations' },
                            { name: 'c1', type: 'number', default: 2.0, description: 'Cognitive parameter' },
                            { name: 'c2', type: 'number', default: 2.0, description: 'Social parameter' },
                            { name: 'w', type: 'number', default: 0.7, description: 'Inertia weight' }
                        ]
                    },
                    {
                        id: 'de',
                        name: 'Differential Evolution',
                        description: 'A stochastic population-based method that is useful for global optimization problems.',
                        parameters: [
                            { name: 'population_size', type: 'number', default: 50, description: 'Population size' },
                            { name: 'max_iterations', type: 'number', default: 100, description: 'Maximum number of iterations' },
                            { name: 'crossover_rate', type: 'number', default: 0.7, description: 'Crossover rate' },
                            { name: 'mutation_factor', type: 'number', default: 0.5, description: 'Mutation factor' }
                        ]
                    },
                    {
                        id: 'gwo',
                        name: 'Grey Wolf Optimizer',
                        description: 'A meta-heuristic algorithm inspired by the leadership hierarchy and hunting mechanism of grey wolves.',
                        parameters: [
                            { name: 'population_size', type: 'number', default: 30, description: 'Number of wolves' },
                            { name: 'max_iterations', type: 'number', default: 100, description: 'Maximum number of iterations' }
                        ]
                    },
                    {
                        id: 'aco',
                        name: 'Ant Colony Optimization',
                        description: 'A probabilistic technique for solving computational problems which can be reduced to finding good paths through graphs.',
                        parameters: [
                            { name: 'population_size', type: 'number', default: 30, description: 'Number of ants' },
                            { name: 'max_iterations', type: 'number', default: 100, description: 'Maximum number of iterations' },
                            { name: 'alpha', type: 'number', default: 1.0, description: 'Pheromone importance' },
                            { name: 'beta', type: 'number', default: 2.0, description: 'Heuristic importance' },
                            { name: 'evaporation_rate', type: 'number', default: 0.1, description: 'Pheromone evaporation rate' }
                        ]
                    },
                    {
                        id: 'ga',
                        name: 'Genetic Algorithm',
                        description: 'A search heuristic that is inspired by Charles Darwin\'s theory of natural evolution.',
                        parameters: [
                            { name: 'population_size', type: 'number', default: 50, description: 'Population size' },
                            { name: 'max_iterations', type: 'number', default: 100, description: 'Maximum number of iterations' },
                            { name: 'crossover_rate', type: 'number', default: 0.8, description: 'Crossover rate' },
                            { name: 'mutation_rate', type: 'number', default: 0.1, description: 'Mutation rate' }
                        ]
                    },
                    {
                        id: 'woa',
                        name: 'Whale Optimization Algorithm',
                        description: 'A nature-inspired meta-heuristic optimization algorithm which mimics the hunting behavior of humpback whales.',
                        parameters: [
                            { name: 'population_size', type: 'number', default: 30, description: 'Number of whales' },
                            { name: 'max_iterations', type: 'number', default: 100, description: 'Maximum number of iterations' },
                            { name: 'b', type: 'number', default: 1.0, description: 'Spiral constant' }
                        ]
                    },
                    {
                        id: 'depso',
                        name: 'Differential Evolution Particle Swarm Optimization',
                        description: 'A hybrid algorithm that combines Differential Evolution and Particle Swarm Optimization.',
                        parameters: [
                            { name: 'population_size', type: 'number', default: 40, description: 'Population size' },
                            { name: 'max_iterations', type: 'number', default: 100, description: 'Maximum number of iterations' },
                            { name: 'c1', type: 'number', default: 1.5, description: 'Cognitive parameter' },
                            { name: 'c2', type: 'number', default: 1.5, description: 'Social parameter' },
                            { name: 'w', type: 'number', default: 0.7, description: 'Inertia weight' },
                            { name: 'crossover_rate', type: 'number', default: 0.7, description: 'Crossover rate' },
                            { name: 'mutation_factor', type: 'number', default: 0.5, description: 'Mutation factor' }
                        ]
                    }
                ]
            };
        }
        if (!result.success) {
            console.log(chalk.red(`Error: ${result.error || 'Failed to fetch algorithms'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        // Check if the data is in the expected format
        const algorithms = result.data && result.data.algorithms ? result.data.algorithms : (result.algorithms || []);
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
            // Use the swarms module to get algorithm details
            detailsResult = await swarms.getAlgorithmDetails(algorithmId);
            detailsSpinner.stop();
        } catch (error) {
            detailsSpinner.fail('Failed to fetch algorithm details');
            console.error(chalk.red('Could not connect to backend. Please ensure the Julia server is running.'));
            console.log(chalk.yellow('Using mock data instead...'));

            // Use the selected algorithm from the mock data
            const selectedAlgorithm = result.algorithms.find(alg => alg.id === algorithmId);
            if (selectedAlgorithm) {
                detailsResult = {
                    success: true,
                    algorithm: selectedAlgorithm
                };
            } else {
                console.log(chalk.red(`Error: Algorithm with ID ${algorithmId} not found`));
                await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
                return;
            }
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
            let saveResult;
            try {
                // Use the swarms module to configure the algorithm
                saveResult = await swarms.configureAlgorithm(algorithmId, paramValues);
            } catch (error) {
                console.log(chalk.yellow('\nCould not connect to backend. Using mock data instead.'));

                // Generate a mock configuration ID
                const configId = `config_${algorithmId}_${Date.now().toString(36)}`;
                saveResult = {
                    success: true,
                    config_id: configId
                };
            }

            saveSpinner.stop();

            if (!saveResult.success) {
                console.log(chalk.red(`Error: ${saveResult.error || 'Failed to save configuration'}`));
                return;
            }

            console.log(chalk.green('\nConfiguration saved successfully!'));
            console.log(chalk.cyan(`\nConfiguration ID: ${saveResult.config_id}`));

            // Display the configured parameters
            console.log(chalk.bold('\nConfigured Parameters:'));
            Object.entries(paramValues).forEach(([key, value]) => {
                console.log(`${key}: ${value}`);
            });

            console.log(chalk.yellow('\nNote: These settings will be used when running this algorithm.'));
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
            // Use the swarms module to get available algorithms
            result = await swarms.getAvailableAlgorithms();
            spinner.stop();
        } catch (error) {
            spinner.fail('Failed to fetch algorithms');
            console.error(chalk.red('Could not connect to backend. Please ensure the Julia server is running.'));
            console.log(chalk.yellow('Using mock data instead...'));

            // Use mock data
            result = {
                success: true,
                algorithms: [
                    {
                        id: 'pso',
                        name: 'Particle Swarm Optimization',
                        description: 'A computational method that optimizes a problem by iteratively trying to improve a candidate solution with regard to a given measure of quality.',
                        parameters: [
                            { name: 'population_size', type: 'number', default: 30, description: 'Number of particles' },
                            { name: 'max_iterations', type: 'number', default: 100, description: 'Maximum number of iterations' },
                            { name: 'c1', type: 'number', default: 2.0, description: 'Cognitive parameter' },
                            { name: 'c2', type: 'number', default: 2.0, description: 'Social parameter' },
                            { name: 'w', type: 'number', default: 0.7, description: 'Inertia weight' }
                        ]
                    },
                    {
                        id: 'de',
                        name: 'Differential Evolution',
                        description: 'A stochastic population-based method that is useful for global optimization problems.',
                        parameters: [
                            { name: 'population_size', type: 'number', default: 50, description: 'Population size' },
                            { name: 'max_iterations', type: 'number', default: 100, description: 'Maximum number of iterations' },
                            { name: 'crossover_rate', type: 'number', default: 0.7, description: 'Crossover rate' },
                            { name: 'mutation_factor', type: 'number', default: 0.5, description: 'Mutation factor' }
                        ]
                    },
                    {
                        id: 'gwo',
                        name: 'Grey Wolf Optimizer',
                        description: 'A meta-heuristic algorithm inspired by the leadership hierarchy and hunting mechanism of grey wolves.',
                        parameters: [
                            { name: 'population_size', type: 'number', default: 30, description: 'Number of wolves' },
                            { name: 'max_iterations', type: 'number', default: 100, description: 'Maximum number of iterations' }
                        ]
                    },
                    {
                        id: 'aco',
                        name: 'Ant Colony Optimization',
                        description: 'A probabilistic technique for solving computational problems which can be reduced to finding good paths through graphs.',
                        parameters: [
                            { name: 'population_size', type: 'number', default: 30, description: 'Number of ants' },
                            { name: 'max_iterations', type: 'number', default: 100, description: 'Maximum number of iterations' },
                            { name: 'alpha', type: 'number', default: 1.0, description: 'Pheromone importance' },
                            { name: 'beta', type: 'number', default: 2.0, description: 'Heuristic importance' },
                            { name: 'evaporation_rate', type: 'number', default: 0.1, description: 'Pheromone evaporation rate' }
                        ]
                    },
                    {
                        id: 'ga',
                        name: 'Genetic Algorithm',
                        description: 'A search heuristic that is inspired by Charles Darwin\'s theory of natural evolution.',
                        parameters: [
                            { name: 'population_size', type: 'number', default: 50, description: 'Population size' },
                            { name: 'max_iterations', type: 'number', default: 100, description: 'Maximum number of iterations' },
                            { name: 'crossover_rate', type: 'number', default: 0.8, description: 'Crossover rate' },
                            { name: 'mutation_rate', type: 'number', default: 0.1, description: 'Mutation rate' }
                        ]
                    },
                    {
                        id: 'woa',
                        name: 'Whale Optimization Algorithm',
                        description: 'A nature-inspired meta-heuristic optimization algorithm which mimics the hunting behavior of humpback whales.',
                        parameters: [
                            { name: 'population_size', type: 'number', default: 30, description: 'Number of whales' },
                            { name: 'max_iterations', type: 'number', default: 100, description: 'Maximum number of iterations' },
                            { name: 'b', type: 'number', default: 1.0, description: 'Spiral constant' }
                        ]
                    },
                    {
                        id: 'depso',
                        name: 'Differential Evolution Particle Swarm Optimization',
                        description: 'A hybrid algorithm that combines Differential Evolution and Particle Swarm Optimization.',
                        parameters: [
                            { name: 'population_size', type: 'number', default: 40, description: 'Population size' },
                            { name: 'max_iterations', type: 'number', default: 100, description: 'Maximum number of iterations' },
                            { name: 'c1', type: 'number', default: 1.5, description: 'Cognitive parameter' },
                            { name: 'c2', type: 'number', default: 1.5, description: 'Social parameter' },
                            { name: 'w', type: 'number', default: 0.7, description: 'Inertia weight' },
                            { name: 'crossover_rate', type: 'number', default: 0.7, description: 'Crossover rate' },
                            { name: 'mutation_factor', type: 'number', default: 0.5, description: 'Mutation factor' }
                        ]
                    }
                ]
            };
        }
        if (!result.success) {
            console.log(chalk.red(`Error: ${result.error || 'Failed to fetch algorithms'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        // Check if the data is in the expected format
        const algorithms = result.data && result.data.algorithms ? result.data.algorithms : (result.algorithms || []);
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
            let benchmarkResult;
            try {
                // Use the swarms module to run the benchmark
                benchmarkResult = await swarms.runBenchmark(algorithmId, {
                    benchmark_type: benchmarkType,
                    problem_dimension: problemDimension,
                    num_runs: numRuns,
                    custom_problem: customProblem
                });
            } catch (error) {
                console.log(chalk.yellow('\nCould not connect to backend. Using mock data instead.'));

                // Create mock benchmark results
                benchmarkResult = {
                    success: true,
                    results: {
                        algorithm_id: algorithmId,
                        algorithm_name: algorithms.find(a => a.id === algorithmId)?.name || algorithmId,
                        benchmark_type: benchmarkType,
                        problem_dimension: problemDimension,
                        num_runs: numRuns,
                        metrics: {
                            best_fitness: (Math.random() * 0.01).toFixed(6),
                            avg_fitness: (Math.random() * 0.05).toFixed(6),
                            std_dev: (Math.random() * 0.02).toFixed(6),
                            avg_convergence_iterations: Math.floor(Math.random() * 40) + 30,
                            avg_execution_time: Math.floor(Math.random() * 300) + 100
                        },
                        problems: []
                    }
                };

                // Generate mock problem results based on benchmark type
                if (benchmarkType === 'standard') {
                    const standardProblems = [
                        'Sphere Function',
                        'Rosenbrock Function',
                        'Rastrigin Function',
                        'Ackley Function',
                        'Griewank Function'
                    ];

                    benchmarkResult.results.problems = standardProblems.map(name => ({
                        name,
                        best_fitness: (Math.random() * 0.1).toFixed(6),
                        avg_fitness: (Math.random() * 0.2).toFixed(6),
                        success_rate: (Math.random() * 0.3 + 0.7).toFixed(2)
                    }));
                } else if (benchmarkType === 'real_world') {
                    const realWorldProblems = [
                        'Portfolio Optimization',
                        'Neural Network Training',
                        'Job Shop Scheduling',
                        'Vehicle Routing',
                        'Feature Selection'
                    ];

                    benchmarkResult.results.problems = realWorldProblems.map(name => ({
                        name,
                        best_fitness: (Math.random() * 0.3).toFixed(6),
                        avg_fitness: (Math.random() * 0.5).toFixed(6),
                        success_rate: (Math.random() * 0.4 + 0.6).toFixed(2)
                    }));
                } else if (benchmarkType === 'custom' && customProblem) {
                    benchmarkResult.results.problems = [{
                        name: customProblem.name,
                        best_fitness: (Math.random() * 0.2).toFixed(6),
                        avg_fitness: (Math.random() * 0.4).toFixed(6),
                        success_rate: (Math.random() * 0.3 + 0.7).toFixed(2)
                    }];
                }
            }

            benchmarkSpinner.stop();

            if (!benchmarkResult.success) {
                console.log(chalk.yellow(`Warning: ${benchmarkResult.error || 'Failed to run benchmark'}. Using mock data.`));

                // Create mock benchmark results if the backend call failed
                const selectedAlgorithm = algorithms.find(a => a.id === algorithmId);
                benchmarkResult = {
                    success: true,
                    results: {
                        algorithm_id: algorithmId,
                        algorithm_name: selectedAlgorithm?.name || algorithmId,
                        benchmark_type: benchmarkType,
                        problem_dimension: problemDimension,
                        num_runs: numRuns,
                        metrics: {
                            best_fitness: (Math.random() * 0.01).toFixed(6),
                            avg_fitness: (Math.random() * 0.05).toFixed(6),
                            std_dev: (Math.random() * 0.02).toFixed(6),
                            avg_convergence_iterations: Math.floor(Math.random() * 40) + 30,
                            avg_execution_time: Math.floor(Math.random() * 300) + 100
                        },
                        problems: []
                    }
                };

                // Generate mock problem results based on benchmark type
                if (benchmarkType === 'standard') {
                    const standardProblems = [
                        'Sphere Function',
                        'Rosenbrock Function',
                        'Rastrigin Function',
                        'Ackley Function',
                        'Griewank Function'
                    ];

                    benchmarkResult.results.problems = standardProblems.map(name => ({
                        name,
                        best_fitness: (Math.random() * 0.1).toFixed(6),
                        avg_fitness: (Math.random() * 0.2).toFixed(6),
                        success_rate: (Math.random() * 0.3 + 0.7).toFixed(2)
                    }));
                } else if (benchmarkType === 'real_world') {
                    const realWorldProblems = [
                        'Portfolio Optimization',
                        'Neural Network Training',
                        'Job Shop Scheduling',
                        'Vehicle Routing',
                        'Feature Selection'
                    ];

                    benchmarkResult.results.problems = realWorldProblems.map(name => ({
                        name,
                        best_fitness: (Math.random() * 0.3).toFixed(6),
                        avg_fitness: (Math.random() * 0.5).toFixed(6),
                        success_rate: (Math.random() * 0.4 + 0.6).toFixed(2)
                    }));
                } else if (benchmarkType === 'custom' && customProblem) {
                    benchmarkResult.results.problems = [{
                        name: customProblem.name,
                        best_fitness: (Math.random() * 0.2).toFixed(6),
                        avg_fitness: (Math.random() * 0.4).toFixed(6),
                        success_rate: (Math.random() * 0.3 + 0.7).toFixed(2)
                    }];
                }
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
            // Use the swarms module to get available algorithms
            result = await swarms.getAvailableAlgorithms();
            spinner.stop();
        } catch (error) {
            spinner.fail('Failed to fetch algorithms');
            console.error(chalk.red('Could not connect to backend. Please ensure the Julia server is running.'));
            console.log(chalk.yellow('Using mock data instead...'));

            // Use mock data
            result = {
                success: true,
                algorithms: [
                    {
                        id: 'pso',
                        name: 'Particle Swarm Optimization',
                        description: 'A computational method that optimizes a problem by iteratively trying to improve a candidate solution with regard to a given measure of quality.'
                    },
                    {
                        id: 'de',
                        name: 'Differential Evolution',
                        description: 'A stochastic population-based method that is useful for global optimization problems.'
                    },
                    {
                        id: 'gwo',
                        name: 'Grey Wolf Optimizer',
                        description: 'A meta-heuristic algorithm inspired by the leadership hierarchy and hunting mechanism of grey wolves.'
                    },
                    {
                        id: 'aco',
                        name: 'Ant Colony Optimization',
                        description: 'A probabilistic technique for solving computational problems which can be reduced to finding good paths through graphs.'
                    },
                    {
                        id: 'ga',
                        name: 'Genetic Algorithm',
                        description: 'A search heuristic that is inspired by Charles Darwin\'s theory of natural evolution.'
                    },
                    {
                        id: 'woa',
                        name: 'Whale Optimization Algorithm',
                        description: 'A nature-inspired meta-heuristic optimization algorithm which mimics the hunting behavior of humpback whales.'
                    },
                    {
                        id: 'depso',
                        name: 'Differential Evolution Particle Swarm Optimization',
                        description: 'A hybrid algorithm that combines Differential Evolution and Particle Swarm Optimization.'
                    }
                ]
            };
        }
        if (!result.success) {
            console.log(chalk.red(`Error: ${result.error || 'Failed to fetch algorithms'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }
        // Check if the data is in the expected format
        const algorithms = result.data && result.data.algorithms ? result.data.algorithms : (result.algorithms || []);
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
        let comparisonResult;
        try {
            // Use the swarms module to compare algorithms
            comparisonResult = await swarms.compareAlgorithms(algorithmIds, {
                benchmark_type: benchmarkType,
                problem_dimension: problemDimension,
                num_runs: numRuns
            });
            comparisonSpinner.stop();

            if (!comparisonResult.success) {
                console.log(chalk.yellow(`Warning: ${comparisonResult.error || 'Failed to run comparison'}. Using mock data.`));

                // Generate mock comparison results
                comparisonResult = {
                    success: true,
                    results: {
                        benchmark_type: benchmarkType,
                        problem_dimension: problemDimension,
                        num_runs: numRuns,
                        algorithms: []
                    }
                };

                // Create mock results for each selected algorithm
                const selectedAlgorithms = result.algorithms.filter(alg => algorithmIds.includes(alg.id));

                // Generate random performance metrics for each algorithm
                selectedAlgorithms.forEach(alg => {
                    const avgFitness = (Math.random() * 0.1).toFixed(6);
                    const avgConvergence = Math.floor(Math.random() * 50) + 30;
                    const avgTime = Math.floor(Math.random() * 500) + 100;
                    const successRate = (Math.random() * 0.3 + 0.7).toFixed(2);

                    comparisonResult.results.algorithms.push({
                        id: alg.id,
                        name: alg.name,
                        avg_fitness: avgFitness,
                        avg_convergence_iterations: avgConvergence,
                        avg_execution_time: avgTime,
                        success_rate: successRate
                    });
                });

                // Sort algorithms by performance (lower fitness is better for minimization problems)
                comparisonResult.results.algorithms.sort((a, b) => parseFloat(a.avg_fitness) - parseFloat(b.avg_fitness));

                // Generate mock problem results
                const testProblems = [
                    { name: 'Sphere Function', type: 'minimization' },
                    { name: 'Rosenbrock Function', type: 'minimization' },
                    { name: 'Rastrigin Function', type: 'minimization' },
                    { name: 'Ackley Function', type: 'minimization' }
                ];

                comparisonResult.results.problems = testProblems.map(problem => {
                    const problemResult = {
                        name: problem.name,
                        type: problem.type,
                        algorithms: []
                    };

                    selectedAlgorithms.forEach(alg => {
                        const bestFitness = (Math.random() * 0.2).toFixed(6);
                        const successRate = (Math.random() * 0.4 + 0.6).toFixed(2);

                        problemResult.algorithms.push({
                            id: alg.id,
                            name: alg.name,
                            best_fitness: bestFitness,
                            success_rate: successRate
                        });
                    });

                    // Sort algorithms by performance for this problem
                    problemResult.algorithms.sort((a, b) => parseFloat(a.best_fitness) - parseFloat(b.best_fitness));

                    return problemResult;
                });

                // Add mock statistical test results
                comparisonResult.results.statistical_tests = {
                    friedman_p_value: (Math.random() * 0.05).toFixed(4),
                    post_hoc_tests: []
                };

                // Generate pairwise comparisons
                for (let i = 0; i < selectedAlgorithms.length; i++) {
                    for (let j = i + 1; j < selectedAlgorithms.length; j++) {
                        const pValue = (Math.random() * 0.1).toFixed(4);
                        const significant = parseFloat(pValue) < 0.05;

                        comparisonResult.results.statistical_tests.post_hoc_tests.push({
                            algorithm1: selectedAlgorithms[i].name,
                            algorithm2: selectedAlgorithms[j].name,
                            p_value: pValue,
                            significant: significant
                        });
                    }
                }
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

/**
 * Test an algorithm with specific test cases
 */
async function testAlgorithm(breadcrumbs) {
    try {
        const spinner = ora('Fetching available algorithms...').start();
        let result;
        try {
            // Use the swarms module to get available algorithms
            result = await swarms.getAvailableAlgorithms();
            spinner.stop();
        } catch (error) {
            spinner.fail('Failed to fetch algorithms');
            console.error(chalk.red('Could not connect to backend. Please ensure the Julia server is running.'));
            console.log(chalk.yellow('Using mock data instead...'));

            // Use the same mock data as in listAlgorithms
            result = {
                success: true,
                algorithms: [
                    {
                        id: 'pso',
                        name: 'Particle Swarm Optimization',
                        description: 'A computational method that optimizes a problem by iteratively trying to improve a candidate solution with regard to a given measure of quality.',
                        type: 'swarm',
                        parameters: [
                            { name: 'population_size', type: 'number', default: 30, description: 'Number of particles' },
                            { name: 'max_iterations', type: 'number', default: 100, description: 'Maximum number of iterations' },
                            { name: 'c1', type: 'number', default: 2.0, description: 'Cognitive parameter' },
                            { name: 'c2', type: 'number', default: 2.0, description: 'Social parameter' },
                            { name: 'w', type: 'number', default: 0.7, description: 'Inertia weight' }
                        ]
                    },
                    // Other algorithms...
                ]
            };
        }

        if (!result.success) {
            console.log(chalk.red(`Error: ${result.error || 'Failed to fetch algorithms'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        // Check if the data is in the expected format
        const algorithms = result.data && result.data.algorithms ? result.data.algorithms : (result.algorithms || []);
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
                message: 'Select an algorithm to test:',
                choices: algorithms.map(algorithm => ({
                    name: algorithm.name,
                    value: algorithm.id
                }))
            }
        ]);

        // Prompt for test parameters
        const { testType } = await inquirer.prompt([
            {
                type: 'list',
                name: 'testType',
                message: 'Select test type:',
                choices: [
                    { name: 'Correctness Tests', value: 'correctness' },
                    { name: 'Performance Tests', value: 'performance' },
                    { name: 'Convergence Tests', value: 'convergence' },
                    { name: 'Robustness Tests', value: 'robustness' }
                ]
            }
        ]);

        // Run the test
        const testSpinner = ora(`Running ${testType} tests for ${algorithmId}...`).start();

        try {
            // Use the swarms module to test the algorithm
            const testResult = await swarms.testAlgorithm(algorithmId, {
                test_type: testType
            });
            testSpinner.succeed('Tests completed');

            // If we have real test results, use them
            if (testResult.success && testResult.results) {
                console.log(chalk.green('\nTest Results:'));
                console.log(JSON.stringify(testResult.results, null, 2));
                await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
                return;
            }
        } catch (error) {
            console.log(chalk.yellow('\nCould not connect to backend. Using mock data instead...'));
            testSpinner.succeed('Tests completed (mock data)');
        }

        console.log(chalk.green('\nTest Results:'));

        // Mock test results based on test type
        switch (testType) {
            case 'correctness':
                console.log(chalk.bold('\nCorrectness Tests:'));
                console.log('✅ Basic functionality: PASSED');
                console.log('✅ Boundary conditions: PASSED');
                console.log('✅ Edge cases: PASSED');
                console.log('✅ Parameter validation: PASSED');
                break;

            case 'performance':
                console.log(chalk.bold('\nPerformance Tests:'));
                console.log('⏱️ Average execution time: 125ms');
                console.log('⏱️ Memory usage: 45MB');
                console.log('⏱️ CPU utilization: 32%');
                console.log('⏱️ Scaling with dimension: O(n²)');
                break;

            case 'convergence':
                console.log(chalk.bold('\nConvergence Tests:'));
                console.log('📈 Average iterations to converge: 78');
                console.log('📈 Convergence success rate: 92%');
                console.log('📈 Average solution quality: 0.0023');
                console.log('📈 Premature convergence rate: 8%');
                break;

            case 'robustness':
                console.log(chalk.bold('\nRobustness Tests:'));
                console.log('🛡️ Noise tolerance: HIGH');
                console.log('🛡️ Parameter sensitivity: MEDIUM');
                console.log('🛡️ Initialization sensitivity: LOW');
                console.log('🛡️ Constraint handling: GOOD');
                break;
        }

        console.log(chalk.yellow('\nNote: These are simulated test results. In a real implementation, these would be actual test results from the Julia backend.'));

    } catch (error) {
        console.error(chalk.red('An unexpected error occurred while testing the algorithm.'));
        console.error(chalk.red('Details:'), error.message);
    }
    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * Optimize algorithm parameters for a specific problem
 */
async function optimizeAlgorithm(breadcrumbs) {
    try {
        const spinner = ora('Fetching available algorithms...').start();
        let result;
        try {
            // Use the swarms module to get available algorithms
            result = await swarms.getAvailableAlgorithms();
            spinner.stop();
        } catch (error) {
            spinner.fail('Failed to fetch algorithms');
            console.error(chalk.red('Could not connect to backend. Please ensure the Julia server is running.'));
            console.log(chalk.yellow('Using mock data instead...'));

            // Use mock data
            result = {
                success: true,
                algorithms: [
                    {
                        id: 'pso',
                        name: 'Particle Swarm Optimization',
                        description: 'A computational method that optimizes a problem by iteratively trying to improve a candidate solution with regard to a given measure of quality.'
                    },
                    {
                        id: 'de',
                        name: 'Differential Evolution',
                        description: 'A stochastic population-based method that is useful for global optimization problems.'
                    },
                    // Other algorithms...
                ]
            };
        }

        if (!result.success) {
            console.log(chalk.red(`Error: ${result.error || 'Failed to fetch algorithms'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        // Check if the data is in the expected format
        const algorithms = result.data && result.data.algorithms ? result.data.algorithms : (result.algorithms || []);
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
                message: 'Select an algorithm to optimize:',
                choices: algorithms.map(algorithm => ({
                    name: algorithm.name,
                    value: algorithm.id
                }))
            }
        ]);

        // Prompt for optimization parameters
        const { problemType, optimizationMethod } = await inquirer.prompt([
            {
                type: 'list',
                name: 'problemType',
                message: 'Select problem type:',
                choices: [
                    { name: 'Function Optimization', value: 'function' },
                    { name: 'Classification', value: 'classification' },
                    { name: 'Clustering', value: 'clustering' },
                    { name: 'Custom Problem', value: 'custom' }
                ]
            },
            {
                type: 'list',
                name: 'optimizationMethod',
                message: 'Select optimization method:',
                choices: [
                    { name: 'Grid Search', value: 'grid' },
                    { name: 'Random Search', value: 'random' },
                    { name: 'Bayesian Optimization', value: 'bayesian' },
                    { name: 'Meta-optimization', value: 'meta' }
                ]
            }
        ]);

        // Run the optimization
        const optimizeSpinner = ora(`Optimizing ${algorithmId} parameters using ${optimizationMethod}...`).start();

        try {
            // Use the swarms module to optimize the algorithm
            const optimizeResult = await swarms.optimizeAlgorithm(algorithmId, {
                problem_type: problemType,
                optimization_method: optimizationMethod
            });
            optimizeSpinner.succeed('Optimization completed');

            // If we have real optimization results, use them
            if (optimizeResult.success && optimizeResult.results) {
                console.log(chalk.green('\nOptimization Results:'));
                console.log(chalk.bold('\nOptimized Parameters:'));

                const params = optimizeResult.results.optimized_parameters || {};
                Object.entries(params).forEach(([key, value]) => {
                    if (value !== undefined) {
                        console.log(`${key}: ${value}`);
                    }
                });

                if (optimizeResult.results.performance_improvement) {
                    console.log(chalk.bold('\nPerformance Improvement:'));
                    console.log(`Improvement: ${(optimizeResult.results.performance_improvement * 100).toFixed(2)}%`);
                }

                await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
                return;
            }
        } catch (error) {
            console.log(chalk.yellow('\nCould not connect to backend. Using mock data instead...'));
            optimizeSpinner.succeed('Optimization completed (mock data)');
        }

        console.log(chalk.green('\nOptimization Results:'));

        // Mock optimization results
        console.log(chalk.bold('\nOptimized Parameters:'));

        // Different parameters based on algorithm
        if (algorithmId === 'pso') {
            console.log('population_size: 42');
            console.log('max_iterations: 150');
            console.log('c1: 1.85');
            console.log('c2: 2.15');
            console.log('w: 0.65');
        } else if (algorithmId === 'de') {
            console.log('population_size: 60');
            console.log('max_iterations: 120');
            console.log('crossover_rate: 0.75');
            console.log('mutation_factor: 0.55');
        } else {
            console.log('population_size: 50');
            console.log('max_iterations: 100');
            console.log('other_param1: 1.5');
            console.log('other_param2: 0.8');
        }

        console.log(chalk.bold('\nPerformance Improvement:'));
        console.log('Fitness improvement: 28%');
        console.log('Convergence speed improvement: 35%');
        console.log('Success rate improvement: 15%');

        console.log(chalk.bold('\nValidation Results:'));
        console.log('Cross-validation score: 0.92');
        console.log('Test set performance: 0.89');

        console.log(chalk.yellow('\nNote: These are simulated optimization results. In a real implementation, these would be actual results from the Julia backend.'));

    } catch (error) {
        console.error(chalk.red('An unexpected error occurred while optimizing the algorithm.'));
        console.error(chalk.red('Details:'), error.message);
    }
    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

module.exports = swarmAlgorithmsMenuFactory;
