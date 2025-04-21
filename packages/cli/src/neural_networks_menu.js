// =============================================================================
// Neural Networks Menu
// =============================================================================
const chalk = require('chalk');
const inquirer = require('inquirer');
const ora = require('ora');

// Remove the try/catch and let displayHeader be set by dependency injection
let juliaBridge;
let displayHeader;

function neuralNetworksMenuFactory(deps) {
    if (deps) {
        if (deps.juliaBridge) juliaBridge = deps.juliaBridge;
        if (deps.displayHeader) displayHeader = deps.displayHeader;
    }
    return { neuralNetworksMenu };
}

async function neuralNetworksMenu() {
    while (true) {
        console.clear();
        displayHeader('Neural Networks');

        console.log(chalk.cyan(`
      ╔══════════════════════════════════════════╗
      ║           Neural Networks                ║
      ║                                          ║
      ║  🤖 Create, train, and manage neural      ║
      ║     networks for your agents.            ║
      ║                                          ║
      ╚══════════════════════════════════════════╝
    `));

        const { action } = await inquirer.prompt([
            {
                type: 'list',
                name: 'action',
                message: '🤖 Choose an action:',
                choices: [
                    'Create Neural Network',
                    'Train Neural Network',
                    'List Agent Models',
                    'Make Predictions',
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
            case 'Create Neural Network':
                await createNeuralNetwork();
                break;
            case 'Train Neural Network':
                await trainNeuralNetwork();
                break;
            case 'List Agent Models':
                await listAgentModels();
                break;
            case 'Make Predictions':
                await makePredictions();
                break;
            case 'Back to Main Menu':
                return;
        }
    }
}

async function createNeuralNetwork() {
    try {
        // Get list of agents
        const agentsResult = await juliaBridge.runJuliaCommand('AgentSystem.list_agents', []);

        if (!agentsResult.success || !agentsResult.agents || agentsResult.agents.length === 0) {
            console.log(chalk.yellow('No agents found. Please create an agent first.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        // Select an agent
        const { agentId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'agentId',
                message: 'Select an agent:',
                choices: agentsResult.agents.map(agent => ({
                    name: `${agent.name} (${agent.id})`,
                    value: agent.id
                }))
            }
        ]);

        // Select network type
        const { networkType } = await inquirer.prompt([
            {
                type: 'list',
                name: 'networkType',
                message: 'Select neural network type:',
                choices: [
                    { name: 'Dense (Fully Connected)', value: 'dense' },
                    { name: 'Recurrent (LSTM)', value: 'recurrent' },
                    { name: 'Convolutional (CNN)', value: 'convolutional' }
                ]
            }
        ]);

        // Get network name
        const { modelName } = await inquirer.prompt([
            {
                type: 'input',
                name: 'modelName',
                message: 'Enter a name for this neural network:',
                validate: input => input.length > 0 ? true : 'Name is required'
            }
        ]);

        // Get network configuration
        let networkConfig = {};

        if (networkType === 'dense') {
            const { layers, inputSize, hiddenSize } = await inquirer.prompt([
                {
                    type: 'number',
                    name: 'layers',
                    message: 'Number of hidden layers:',
                    default: 2,
                    validate: input => input > 0 ? true : 'Must have at least 1 layer'
                },
                {
                    type: 'number',
                    name: 'inputSize',
                    message: 'Input size:',
                    default: 10,
                    validate: input => input > 0 ? true : 'Input size must be positive'
                },
                {
                    type: 'number',
                    name: 'hiddenSize',
                    message: 'Hidden layer size:',
                    default: 32,
                    validate: input => input > 0 ? true : 'Hidden size must be positive'
                }
            ]);

            networkConfig = {
                type: 'dense',
                layers: layers,
                input_size: inputSize,
                hidden_size: hiddenSize,
                output_size: 1  // Default to 1, can be changed later
            };
        } else if (networkType === 'recurrent') {
            const { inputSize, hiddenSize, sequenceLength } = await inquirer.prompt([
                {
                    type: 'number',
                    name: 'inputSize',
                    message: 'Input size:',
                    default: 10,
                    validate: input => input > 0 ? true : 'Input size must be positive'
                },
                {
                    type: 'number',
                    name: 'hiddenSize',
                    message: 'Hidden state size:',
                    default: 32,
                    validate: input => input > 0 ? true : 'Hidden size must be positive'
                },
                {
                    type: 'number',
                    name: 'sequenceLength',
                    message: 'Sequence length:',
                    default: 10,
                    validate: input => input > 0 ? true : 'Sequence length must be positive'
                }
            ]);

            networkConfig = {
                type: 'recurrent',
                input_size: inputSize,
                hidden_size: hiddenSize,
                sequence_length: sequenceLength,
                output_size: 1  // Default to 1, can be changed later
            };
        } else if (networkType === 'convolutional') {
            const { inputChannels, kernelSize, filters } = await inquirer.prompt([
                {
                    type: 'number',
                    name: 'inputChannels',
                    message: 'Input channels:',
                    default: 1,
                    validate: input => input > 0 ? true : 'Input channels must be positive'
                },
                {
                    type: 'number',
                    name: 'kernelSize',
                    message: 'Kernel size:',
                    default: 3,
                    validate: input => input > 0 ? true : 'Kernel size must be positive'
                },
                {
                    type: 'number',
                    name: 'filters',
                    message: 'Number of filters:',
                    default: 16,
                    validate: input => input > 0 ? true : 'Number of filters must be positive'
                }
            ]);

            networkConfig = {
                type: 'convolutional',
                input_channels: inputChannels,
                kernel_size: kernelSize,
                filters: filters,
                output_size: 1  // Default to 1, can be changed later
            };
        }

        const spinner = ora('Creating neural network...').start();

        // Create the neural network
        const createResult = await juliaBridge.runJuliaCommand('NeuralNetworks.create_agent_model', [
            agentId,
            modelName,
            networkConfig
        ]);

        spinner.stop();

        if (!createResult.success) {
            console.log(chalk.red(`Error: ${createResult.error || 'Failed to create neural network'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        console.log(chalk.green('Neural network created successfully!'));
        console.log(chalk.cyan(`\nModel Information:`));
        console.log(`Name: ${modelName}`);
        console.log(`Type: ${networkType}`);
        console.log(`ID: ${createResult.model_id}`);

    } catch (error) {
        console.error(chalk.red(`Error: ${error.message}`));
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

async function trainNeuralNetwork() {
    try {
        // Get list of agents
        const agentsResult = await juliaBridge.runJuliaCommand('AgentSystem.list_agents', []);

        if (!agentsResult.success || !agentsResult.agents || agentsResult.agents.length === 0) {
            console.log(chalk.yellow('No agents found. Please create an agent first.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        // Select an agent
        const { agentId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'agentId',
                message: 'Select an agent:',
                choices: agentsResult.agents.map(agent => ({
                    name: `${agent.name} (${agent.id})`,
                    value: agent.id
                }))
            }
        ]);

        // Get agent models
        const modelsResult = await juliaBridge.runJuliaCommand('NeuralNetworks.list_agent_models', [agentId]);

        if (!modelsResult.success || modelsResult.models.length === 0) {
            console.log(chalk.yellow('This agent has no neural networks. Please create one first.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        // Select a model to train
        const { modelId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'modelId',
                message: 'Select a neural network to train:',
                choices: modelsResult.models.map(model => ({
                    name: `${model.name} (${model.type})`,
                    value: model.id
                }))
            }
        ]);

        // Get training parameters
        const { epochs, learningRate, batchSize, dataSource } = await inquirer.prompt([
            {
                type: 'number',
                name: 'epochs',
                message: 'Number of training epochs:',
                default: 10,
                validate: input => input > 0 ? true : 'Epochs must be positive'
            },
            {
                type: 'number',
                name: 'learningRate',
                message: 'Learning rate:',
                default: 0.01,
                validate: input => input > 0 ? true : 'Learning rate must be positive'
            },
            {
                type: 'number',
                name: 'batchSize',
                message: 'Batch size:',
                default: 32,
                validate: input => input > 0 ? true : 'Batch size must be positive'
            },
            {
                type: 'list',
                name: 'dataSource',
                message: 'Select data source:',
                choices: [
                    { name: 'Synthetic Data', value: 'synthetic' },
                    { name: 'Historical Market Data', value: 'market' },
                    { name: 'Custom Dataset', value: 'custom' }
                ]
            }
        ]);

        const spinner = ora('Training neural network...').start();

        // Train the neural network
        const trainingResult = await juliaBridge.runJuliaCommand('NeuralNetworks.train_agent_model', [
            agentId,
            modelId,
            {
                epochs: epochs,
                learning_rate: learningRate,
                batch_size: batchSize,
                data_source: dataSource
            }
        ]);

        spinner.stop();

        if (!trainingResult.success) {
            console.log(chalk.red(`Error: ${trainingResult.error || 'Failed to train neural network'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        console.log(chalk.green('Neural network trained successfully!'));
        console.log(chalk.cyan(`\nTraining Results:`));
        console.log(`Final Loss: ${trainingResult.final_loss.toFixed(6)}`);
        console.log(`Accuracy: ${(trainingResult.accuracy * 100).toFixed(2)}%`);
        console.log(`Training Time: ${trainingResult.training_time.toFixed(2)} seconds`);

    } catch (error) {
        console.error(chalk.red(`Error: ${error.message}`));
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

async function listAgentModels() {
    try {
        // Get list of agents
        const agentsResult = await juliaBridge.runJuliaCommand('AgentSystem.list_agents', []);

        if (!agentsResult.success || !agentsResult.agents || agentsResult.agents.length === 0) {
            console.log(chalk.yellow('No agents found. Please create an agent first.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        // Select an agent
        const { agentId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'agentId',
                message: 'Select an agent:',
                choices: agentsResult.agents.map(agent => ({
                    name: `${agent.name} (${agent.id})`,
                    value: agent.id
                }))
            }
        ]);

        const spinner = ora('Fetching neural networks...').start();

        // Get agent models
        const modelsResult = await juliaBridge.runJuliaCommand('NeuralNetworks.list_agent_models', [agentId]);

        spinner.stop();

        if (!modelsResult.success) {
            console.log(chalk.red(`Error: ${modelsResult.error || 'Failed to fetch neural networks'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        console.log(chalk.cyan('\nNeural Networks:'));

        if (modelsResult.models.length === 0) {
            console.log(chalk.yellow('This agent has no neural networks.'));
        } else {
            // Group models by type
            const modelsByType = {};

            for (const model of modelsResult.models) {
                if (!modelsByType[model.type]) {
                    modelsByType[model.type] = [];
                }
                modelsByType[model.type].push(model);
            }

            // Display models by type
            for (const [type, models] of Object.entries(modelsByType)) {
                console.log(chalk.bold(`\n${type.toUpperCase()} NETWORKS`));

                for (const model of models) {
                    console.log(`  ${model.name} (ID: ${model.id})`);
                    console.log(`    Created: ${new Date(model.created_at).toLocaleString()}`);
                    console.log(`    Last Trained: ${model.last_trained_at ? new Date(model.last_trained_at).toLocaleString() : 'Never'}`);
                    console.log(`    Accuracy: ${model.accuracy ? (model.accuracy * 100).toFixed(2) + '%' : 'N/A'}`);

                    // Display architecture details based on type
                    if (model.type === 'dense') {
                        console.log(`    Architecture: Input(${model.input_size}) → ${model.layers} Hidden(${model.hidden_size}) → Output(${model.output_size})`);
                    } else if (model.type === 'recurrent') {
                        console.log(`    Architecture: LSTM(${model.hidden_size}) with sequence length ${model.sequence_length}`);
                    } else if (model.type === 'convolutional') {
                        console.log(`    Architecture: ${model.filters} filters with ${model.kernel_size}x${model.kernel_size} kernels`);
                    }
                }
            }
        }
    } catch (error) {
        console.error(chalk.red(`Error: ${error.message}`));
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

async function makePredictions() {
    try {
        // Get list of agents
        const agentsResult = await juliaBridge.runJuliaCommand('AgentSystem.list_agents', []);

        if (!agentsResult.success || !agentsResult.agents || agentsResult.agents.length === 0) {
            console.log(chalk.yellow('No agents found. Please create an agent first.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        // Select an agent
        const { agentId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'agentId',
                message: 'Select an agent:',
                choices: agentsResult.agents.map(agent => ({
                    name: `${agent.name} (${agent.id})`,
                    value: agent.id
                }))
            }
        ]);

        // Get agent models
        const modelsResult = await juliaBridge.runJuliaCommand('NeuralNetworks.list_agent_models', [agentId]);

        if (!modelsResult.success || modelsResult.models.length === 0) {
            console.log(chalk.yellow('This agent has no neural networks. Please create and train one first.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        // Select a model for prediction
        const { modelId } = await inquirer.prompt([
            {
                type: 'list',
                name: 'modelId',
                message: 'Select a neural network for prediction:',
                choices: modelsResult.models.map(model => ({
                    name: `${model.name} (${model.type})`,
                    value: model.id
                }))
            }
        ]);

        // Get the selected model
        const model = modelsResult.models.find(m => m.id === modelId);

        // Get input data based on model type
        let inputData;

        if (model.type === 'dense') {
            const { inputValues } = await inquirer.prompt([
                {
                    type: 'input',
                    name: 'inputValues',
                    message: `Enter ${model.input_size} input values (comma-separated):`,
                    validate: input => {
                        const values = input.split(',').map(v => parseFloat(v.trim()));
                        return values.length === model.input_size && values.every(v => !isNaN(v))
                            ? true
                            : `Please enter exactly ${model.input_size} numeric values`;
                    }
                }
            ]);

            inputData = inputValues.split(',').map(v => parseFloat(v.trim()));
        } else if (model.type === 'recurrent') {
            const { inputSequence } = await inquirer.prompt([
                {
                    type: 'input',
                    name: 'inputSequence',
                    message: `Enter a sequence of ${model.sequence_length} values (comma-separated):`,
                    validate: input => {
                        const values = input.split(',').map(v => parseFloat(v.trim()));
                        return values.length === model.sequence_length && values.every(v => !isNaN(v))
                            ? true
                            : `Please enter exactly ${model.sequence_length} numeric values`;
                    }
                }
            ]);

            inputData = inputSequence.split(',').map(v => parseFloat(v.trim()));
        } else if (model.type === 'convolutional') {
            console.log(chalk.yellow('For CNN models, we\'ll use a random test image from the dataset.'));
            inputData = 'random_test_image';
        }

        const spinner = ora('Making prediction...').start();

        // Make prediction
        const predictionResult = await juliaBridge.runJuliaCommand('NeuralNetworks.predict_with_agent_model', [
            agentId,
            modelId,
            inputData
        ]);

        spinner.stop();

        if (!predictionResult.success) {
            console.log(chalk.red(`Error: ${predictionResult.error || 'Failed to make prediction'}`));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        console.log(chalk.green('Prediction completed successfully!'));
        console.log(chalk.cyan(`\nPrediction Results:`));

        if (Array.isArray(predictionResult.prediction)) {
            console.log('Prediction values:');
            predictionResult.prediction.forEach((value, index) => {
                console.log(`  Output ${index + 1}: ${value.toFixed(6)}`);
            });
        } else {
            console.log(`Prediction: ${predictionResult.prediction.toFixed(6)}`);
        }

        if (predictionResult.confidence) {
            console.log(`Confidence: ${(predictionResult.confidence * 100).toFixed(2)}%`);
        }

    } catch (error) {
        console.error(chalk.red(`Error: ${error.message}`));
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

module.exports = neuralNetworksMenuFactory;
