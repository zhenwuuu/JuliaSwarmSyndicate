// Import required modules
const chalk = require('chalk');
const inquirer = require('inquirer');
const ora = require('ora');
const fs = require('fs-extra');
const path = require('path');
const os = require('os');

// Import error handler
const errorHandler = require('./utils/error-handler');

// Initialize variables that will be set by the module consumer
let juliaBridge;
let displayHeader;

/**
 * Display the system configuration menu
 */
async function systemConfigMenu() {
    try {
        displayHeader('System Configuration');

        const { action } = await inquirer.prompt([
            {
                type: 'list',
                name: 'action',
                message: 'Choose an action:',
                choices: [
                    { name: '📋 View Current Configuration', value: 'view_config' },
                    { name: '⚙️ General Settings', value: 'general_settings' },
                    { name: '🔌 Network Settings', value: 'network_settings' },
                    { name: '💾 Storage Settings', value: 'storage_settings' },
                    { name: '🔒 Security Settings', value: 'security_settings' },
                    { name: '📊 Error Log Management', value: 'error_logs' },
                    { name: '🔄 Reset to Default', value: 'reset_default' },
                    { name: '🔙 Back to Main Menu', value: 'back' }
                ]
            }
        ]);

        switch (action) {
            case 'view_config':
                await viewCurrentConfig();
                break;
            case 'general_settings':
                await configureGeneralSettings();
                break;
            case 'network_settings':
                await configureNetworkSettings();
                break;
            case 'storage_settings':
                await configureStorageSettings();
                break;
            case 'security_settings':
                await configureSecuritySettings();
                break;
            case 'error_logs':
                await manageErrorLogs();
                break;
            case 'reset_default':
                await resetToDefault();
                break;
            case 'back':
                return;
        }

        // Return to the system configuration menu after completing an action
        await systemConfigMenu();
    } catch (error) {
        errorHandler.handleError(error, 'System Configuration Menu', process.env.NODE_ENV === 'development');
        await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
    }
}

/**
 * View current system configuration
 */
async function viewCurrentConfig() {
    try {
        const spinner = ora('Fetching current configuration...').start();

        try {
            const result = await juliaBridge.runJuliaCommand('Config.get_system_config', []);

            spinner.stop();

            if (!result.success) {
                console.log(chalk.red(`Error: ${result.error || 'Failed to fetch system configuration'}`));
                return;
            }

            const config = result.config || {};

            console.log(chalk.cyan('\nCurrent System Configuration:'));

            // General settings
            console.log(chalk.bold('\nGeneral Settings:'));
            console.log(`System Name: ${config.general?.system_name || 'JuliaOS'}`);
            console.log(`Log Level: ${config.general?.log_level || 'INFO'}`);
            console.log(`Auto Update: ${config.general?.auto_update ? 'Enabled' : 'Disabled'}`);
            console.log(`Default Chain: ${config.general?.default_chain || 'ethereum'}`);

            // Network settings
            console.log(chalk.bold('\nNetwork Settings:'));
            console.log(`Julia Server Port: ${config.network?.julia_server_port || 8052}`);
            console.log(`Julia Server Host: ${config.network?.julia_server_host || 'localhost'}`);
            console.log(`Use HTTPS: ${config.network?.use_https ? 'Yes' : 'No'}`);
            console.log(`Timeout (ms): ${config.network?.timeout_ms || 30000}`);

            // Storage settings
            console.log(chalk.bold('\nStorage Settings:'));
            console.log(`Storage Type: ${config.storage?.storage_type || 'local'}`);
            console.log(`Database Path: ${config.storage?.db_path || './data/juliaos.db'}`);
            console.log(`Use Arweave: ${config.storage?.use_arweave ? 'Yes' : 'No'}`);

            // Security settings
            console.log(chalk.bold('\nSecurity Settings:'));
            console.log(`Encryption Enabled: ${config.security?.encryption_enabled ? 'Yes' : 'No'}`);
            console.log(`API Key Required: ${config.security?.api_key_required ? 'Yes' : 'No'}`);
            console.log(`Max Login Attempts: ${config.security?.max_login_attempts || 5}`);

        } catch (error) {
            spinner.fail('Failed to fetch system configuration');
            errorHandler.handleError(error, 'View System Configuration');
        }
    } catch (error) {
        errorHandler.handleError(error, 'View System Configuration');
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * Configure general settings
 */
async function configureGeneralSettings() {
    try {
        // First, get current configuration
        const spinner = ora('Fetching current configuration...').start();

        let currentConfig = {};
        try {
            const result = await juliaBridge.runJuliaCommand('Config.get_system_config', []);

            spinner.stop();

            if (result.success) {
                currentConfig = result.config || {};
            }
        } catch (error) {
            spinner.fail('Failed to fetch current configuration');
            console.error(chalk.red('Error:'), error.message);
        }

        const generalConfig = currentConfig.general || {};

        // Prompt for general settings
        const { systemName, logLevel, autoUpdate, defaultChain } = await inquirer.prompt([
            {
                type: 'input',
                name: 'systemName',
                message: 'System Name:',
                default: generalConfig.system_name || 'JuliaOS'
            },
            {
                type: 'list',
                name: 'logLevel',
                message: 'Log Level:',
                choices: ['DEBUG', 'INFO', 'WARNING', 'ERROR'],
                default: generalConfig.log_level || 'INFO'
            },
            {
                type: 'confirm',
                name: 'autoUpdate',
                message: 'Enable Auto Update:',
                default: generalConfig.auto_update !== undefined ? generalConfig.auto_update : true
            },
            {
                type: 'list',
                name: 'defaultChain',
                message: 'Default Blockchain:',
                choices: ['ethereum', 'polygon', 'solana', 'avalanche', 'binance'],
                default: generalConfig.default_chain || 'ethereum'
            }
        ]);

        // Save the configuration
        const saveSpinner = ora('Saving general settings...').start();

        try {
            const saveResult = await juliaBridge.runJuliaCommand('Config.update_system_config', [
                {
                    general: {
                        system_name: systemName,
                        log_level: logLevel,
                        auto_update: autoUpdate,
                        default_chain: defaultChain
                    }
                }
            ]);

            saveSpinner.stop();

            if (!saveResult.success) {
                console.log(chalk.red(`Error: ${saveResult.error || 'Failed to save general settings'}`));
                return;
            }

            console.log(chalk.green('\nGeneral settings saved successfully!'));
        } catch (error) {
            saveSpinner.fail('Failed to save general settings');
            console.error(chalk.red('Error:'), error.message);
        }
    } catch (error) {
        console.error(chalk.red('Error:'), error.message);
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * Configure network settings
 */
async function configureNetworkSettings() {
    try {
        // First, get current configuration
        const spinner = ora('Fetching current configuration...').start();

        let currentConfig = {};
        try {
            const result = await juliaBridge.runJuliaCommand('Config.get_system_config', []);

            spinner.stop();

            if (result.success) {
                currentConfig = result.config || {};
            }
        } catch (error) {
            spinner.fail('Failed to fetch current configuration');
            console.error(chalk.red('Error:'), error.message);
        }

        const networkConfig = currentConfig.network || {};

        // Prompt for network settings
        const { juliaServerPort, juliaServerHost, useHttps, timeoutMs } = await inquirer.prompt([
            {
                type: 'number',
                name: 'juliaServerPort',
                message: 'Julia Server Port:',
                default: networkConfig.julia_server_port || 8052,
                validate: input => input > 0 && input < 65536 ? true : 'Port must be between 1 and 65535'
            },
            {
                type: 'input',
                name: 'juliaServerHost',
                message: 'Julia Server Host:',
                default: networkConfig.julia_server_host || 'localhost'
            },
            {
                type: 'confirm',
                name: 'useHttps',
                message: 'Use HTTPS:',
                default: networkConfig.use_https !== undefined ? networkConfig.use_https : false
            },
            {
                type: 'number',
                name: 'timeoutMs',
                message: 'Network Timeout (ms):',
                default: networkConfig.timeout_ms || 30000,
                validate: input => input > 0 ? true : 'Timeout must be positive'
            }
        ]);

        // Save the configuration
        const saveSpinner = ora('Saving network settings...').start();

        try {
            const saveResult = await juliaBridge.runJuliaCommand('Config.update_system_config', [
                {
                    network: {
                        julia_server_port: juliaServerPort,
                        julia_server_host: juliaServerHost,
                        use_https: useHttps,
                        timeout_ms: timeoutMs
                    }
                }
            ]);

            saveSpinner.stop();

            if (!saveResult.success) {
                console.log(chalk.red(`Error: ${saveResult.error || 'Failed to save network settings'}`));
                return;
            }

            console.log(chalk.green('\nNetwork settings saved successfully!'));
            console.log(chalk.yellow('\nNote: Some settings may require a system restart to take effect.'));
        } catch (error) {
            saveSpinner.fail('Failed to save network settings');
            console.error(chalk.red('Error:'), error.message);
        }
    } catch (error) {
        console.error(chalk.red('Error:'), error.message);
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * Configure storage settings
 */
async function configureStorageSettings() {
    try {
        // First, get current configuration
        const spinner = ora('Fetching current configuration...').start();

        let currentConfig = {};
        try {
            const result = await juliaBridge.runJuliaCommand('Config.get_system_config', []);

            spinner.stop();

            if (result.success) {
                currentConfig = result.config || {};
            }
        } catch (error) {
            spinner.fail('Failed to fetch current configuration');
            console.error(chalk.red('Error:'), error.message);
        }

        const storageConfig = currentConfig.storage || {};

        // Prompt for storage settings
        const { storageType, dbPath, useArweave, useDocumentStorage } = await inquirer.prompt([
            {
                type: 'list',
                name: 'storageType',
                message: 'Primary Storage Type:',
                choices: [
                    { name: 'Local (SQLite)', value: 'local' },
                    { name: 'Arweave (Decentralized)', value: 'arweave' },
                    { name: 'Document Storage', value: 'document' },
                    { name: 'Hybrid (Local + Arweave)', value: 'hybrid' }
                ],
                default: storageConfig.storage_type || 'local'
            },
            {
                type: 'input',
                name: 'dbPath',
                message: 'Local Database Path:',
                default: storageConfig.db_path || './data/juliaos.db',
                when: (answers) => answers.storageType === 'local' || answers.storageType === 'hybrid'
            },
            {
                type: 'confirm',
                name: 'useArweave',
                message: 'Enable Arweave for Decentralized Storage:',
                default: storageConfig.use_arweave !== undefined ? storageConfig.use_arweave : false,
                when: (answers) => answers.storageType !== 'arweave'
            },
            {
                type: 'confirm',
                name: 'useDocumentStorage',
                message: 'Enable Document Storage with Search:',
                default: storageConfig.use_document_storage !== undefined ? storageConfig.use_document_storage : false
            }
        ]);

        // If Arweave is enabled or selected as primary, prompt for Arweave settings
        let arweaveConfig = {};
        if (useArweave || storageType === 'arweave' || storageType === 'hybrid') {
            const { arweaveWalletPath, arweaveApiUrl, arweaveCacheEnabled } = await inquirer.prompt([
                {
                    type: 'input',
                    name: 'arweaveWalletPath',
                    message: 'Arweave Wallet Path:',
                    default: storageConfig.arweave_wallet_path || './arweave-keyfile.json'
                },
                {
                    type: 'input',
                    name: 'arweaveApiUrl',
                    message: 'Arweave API URL:',
                    default: storageConfig.arweave_api_url || 'https://arweave.net'
                },
                {
                    type: 'confirm',
                    name: 'arweaveCacheEnabled',
                    message: 'Enable Local Cache for Arweave:',
                    default: storageConfig.arweave_cache_enabled !== undefined ? storageConfig.arweave_cache_enabled : true
                }
            ]);

            arweaveConfig = {
                arweave_wallet_path: arweaveWalletPath,
                arweave_api_url: arweaveApiUrl,
                arweave_cache_enabled: arweaveCacheEnabled
            };
        }

        // If document storage is enabled, prompt for document storage settings
        let documentConfig = {};
        if (useDocumentStorage || storageType === 'document') {
            const { indexEnabled, searchEnabled } = await inquirer.prompt([
                {
                    type: 'confirm',
                    name: 'indexEnabled',
                    message: 'Enable Document Indexing:',
                    default: storageConfig.document_index_enabled !== undefined ? storageConfig.document_index_enabled : true
                },
                {
                    type: 'confirm',
                    name: 'searchEnabled',
                    message: 'Enable Document Search:',
                    default: storageConfig.document_search_enabled !== undefined ? storageConfig.document_search_enabled : true
                }
            ]);

            documentConfig = {
                document_index_enabled: indexEnabled,
                document_search_enabled: searchEnabled
            };
        }

        // Save the configuration
        const saveSpinner = ora('Saving storage settings...').start();

        try {
            const saveResult = await juliaBridge.runJuliaCommand('Config.update_system_config', [
                {
                    storage: {
                        storage_type: storageType,
                        db_path: dbPath,
                        use_arweave: useArweave || storageType === 'arweave' || storageType === 'hybrid',
                        use_document_storage: useDocumentStorage || storageType === 'document',
                        ...arweaveConfig,
                        ...documentConfig
                    }
                }
            ]);

            saveSpinner.stop();

            if (!saveResult.success) {
                console.log(chalk.red(`Error: ${saveResult.error || 'Failed to save storage settings'}`));
                return;
            }

            console.log(chalk.green('\nStorage settings saved successfully!'));
        } catch (error) {
            saveSpinner.fail('Failed to save storage settings');
            console.error(chalk.red('Error:'), error.message);
        }
    } catch (error) {
        console.error(chalk.red('Error:'), error.message);
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * Configure security settings
 */
async function configureSecuritySettings() {
    try {
        // First, get current configuration
        const spinner = ora('Fetching current configuration...').start();

        let currentConfig = {};
        try {
            const result = await juliaBridge.runJuliaCommand('Config.get_system_config', []);

            spinner.stop();

            if (result.success) {
                currentConfig = result.config || {};
            }
        } catch (error) {
            spinner.fail('Failed to fetch current configuration');
            console.error(chalk.red('Error:'), error.message);
        }

        const securityConfig = currentConfig.security || {};

        // Prompt for security settings
        const { encryptionEnabled, apiKeyRequired, maxLoginAttempts } = await inquirer.prompt([
            {
                type: 'confirm',
                name: 'encryptionEnabled',
                message: 'Enable Data Encryption:',
                default: securityConfig.encryption_enabled !== undefined ? securityConfig.encryption_enabled : true
            },
            {
                type: 'confirm',
                name: 'apiKeyRequired',
                message: 'Require API Key for External Access:',
                default: securityConfig.api_key_required !== undefined ? securityConfig.api_key_required : true
            },
            {
                type: 'number',
                name: 'maxLoginAttempts',
                message: 'Maximum Login Attempts:',
                default: securityConfig.max_login_attempts || 5,
                validate: input => input > 0 ? true : 'Maximum login attempts must be positive'
            }
        ]);

        // Save the configuration
        const saveSpinner = ora('Saving security settings...').start();

        try {
            const saveResult = await juliaBridge.runJuliaCommand('Config.update_system_config', [
                {
                    security: {
                        encryption_enabled: encryptionEnabled,
                        api_key_required: apiKeyRequired,
                        max_login_attempts: maxLoginAttempts
                    }
                }
            ]);

            saveSpinner.stop();

            if (!saveResult.success) {
                console.log(chalk.red(`Error: ${saveResult.error || 'Failed to save security settings'}`));
                return;
            }

            console.log(chalk.green('\nSecurity settings saved successfully!'));
        } catch (error) {
            saveSpinner.fail('Failed to save security settings');
            console.error(chalk.red('Error:'), error.message);
        }
    } catch (error) {
        console.error(chalk.red('Error:'), error.message);
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * Reset configuration to default
 */
async function resetToDefault() {
    try {
        // Confirm reset
        const { confirmReset } = await inquirer.prompt([
            {
                type: 'confirm',
                name: 'confirmReset',
                message: 'Are you sure you want to reset all settings to default? This action cannot be undone.',
                default: false
            }
        ]);

        if (!confirmReset) {
            console.log(chalk.yellow('Reset cancelled.'));
            return;
        }

        // Reset the configuration
        const resetSpinner = ora('Resetting to default configuration...').start();

        try {
            const resetResult = await juliaBridge.runJuliaCommand('Config.reset_system_config', []);

            resetSpinner.stop();

            if (!resetResult.success) {
                console.log(chalk.red(`Error: ${resetResult.error || 'Failed to reset configuration'}`));
                return;
            }

            console.log(chalk.green('\nConfiguration reset to default successfully!'));
        } catch (error) {
            resetSpinner.fail('Failed to reset configuration');
            console.error(chalk.red('Error:'), error.message);
        }
    } catch (error) {
        console.error(chalk.red('Error:'), error.message);
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * Manage error logs
 */
async function manageErrorLogs() {
    try {
        displayHeader('Error Log Management');
        console.log(chalk.cyan(`
      ╔══════════════════════════════════════════╗
      ║           Error Log Management           ║
      ║                                          ║
      ║  📊 View and manage system error logs.    ║
      ║     Helps with troubleshooting issues.    ║
      ║                                          ║
      ╚══════════════════════════════════════════╝
    `));

        const { action } = await inquirer.prompt([
            {
                type: 'list',
                name: 'action',
                message: 'Choose an action:',
                choices: [
                    { name: '📄 View Recent Errors', value: 'view_errors' },
                    { name: '💾 Export Error Logs', value: 'export_logs' },
                    { name: '🚮 Clear Error Logs', value: 'clear_logs' },
                    { name: '🔙 Back', value: 'back' }
                ]
            }
        ]);

        if (action === 'back') {
            return;
        }

        switch (action) {
            case 'view_errors':
                await viewRecentErrors();
                break;
            case 'export_logs':
                await exportErrorLogs();
                break;
            case 'clear_logs':
                await clearErrorLogs();
                break;
        }

        // Return to the error log management menu
        await manageErrorLogs();
    } catch (error) {
        errorHandler.handleError(error, 'Error Log Management');
        await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
    }
}

/**
 * View recent error logs
 */
async function viewRecentErrors() {
    try {
        const spinner = ora('Loading recent errors...').start();

        try {
            // Get recent error logs
            const logs = await errorHandler.getRecentErrorLogs(20);
            spinner.stop();

            if (logs.length === 0) {
                console.log(chalk.green('\nNo error logs found. That\'s good news!'));
                await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
                return;
            }

            // Display error logs
            console.log(chalk.cyan('\nRecent Error Logs:'));
            console.log(chalk.cyan('\n┌─ Error Logs ───────────────────────────────────────────────┐'));

            logs.forEach((log, index) => {
                // Determine error category color
                let categoryColor;
                let icon;
                switch(log.category) {
                    case 'Connection Error':
                        categoryColor = chalk.red;
                        icon = '🔌';
                        break;
                    case 'Authentication Error':
                        categoryColor = chalk.yellow;
                        icon = '🔒';
                        break;
                    case 'Validation Error':
                        categoryColor = chalk.yellow;
                        icon = '⚠️';
                        break;
                    case 'Backend Error':
                        categoryColor = chalk.red;
                        icon = '⚙️';
                        break;
                    case 'Blockchain Error':
                        categoryColor = chalk.magenta;
                        icon = '⛓️';
                        break;
                    case 'Data Error':
                        categoryColor = chalk.blue;
                        icon = '📊';
                        break;
                    default:
                        categoryColor = chalk.gray;
                        icon = '❓';
                }

                // Format timestamp
                const timestamp = new Date(log.timestamp).toLocaleString();

                console.log(chalk.cyan('│                                                              │'));
                console.log(chalk.cyan(`│  ${chalk.bold(`${index + 1}. ${timestamp}`)}${' '.repeat(Math.max(0, 45 - timestamp.length - String(index + 1).length))}│`));
                console.log(chalk.cyan(`│     Category: ${icon} ${categoryColor(log.category)}${' '.repeat(Math.max(0, 40 - log.category.length))}│`));
                console.log(chalk.cyan(`│     Context: ${chalk.blue(log.context || 'Unknown')}${' '.repeat(Math.max(0, 40 - (log.context || 'Unknown').length))}│`));

                // Truncate message if too long
                const message = log.message || 'Unknown error';
                const truncatedMessage = message.length > 40 ? message.substring(0, 37) + '...' : message;
                console.log(chalk.cyan(`│     Message: ${chalk.red(truncatedMessage)}${' '.repeat(Math.max(0, 40 - truncatedMessage.length))}│`));

                if (index < logs.length - 1) {
                    console.log(chalk.cyan('│     ────────────────────────────────────────────────────     │'));
                }
            });

            console.log(chalk.cyan('│                                                              │'));
            console.log(chalk.cyan('└──────────────────────────────────────────────────────────────┘'));

            // Ask if user wants to see details of a specific error
            const { viewDetails } = await inquirer.prompt([
                {
                    type: 'confirm',
                    name: 'viewDetails',
                    message: 'Would you like to view details of a specific error?',
                    default: false
                }
            ]);

            if (viewDetails) {
                const { errorIndex } = await inquirer.prompt([
                    {
                        type: 'number',
                        name: 'errorIndex',
                        message: `Enter error number (1-${logs.length}):`,
                        validate: input => {
                            const num = parseInt(input);
                            return !isNaN(num) && num >= 1 && num <= logs.length ? true : `Please enter a number between 1 and ${logs.length}`;
                        },
                        filter: input => parseInt(input)
                    }
                ]);

                const selectedLog = logs[errorIndex - 1];

                console.log(chalk.cyan('\nError Details:'));
                console.log(chalk.bold('Timestamp:'), new Date(selectedLog.timestamp).toLocaleString());
                console.log(chalk.bold('Category:'), selectedLog.category);
                console.log(chalk.bold('Context:'), selectedLog.context || 'Unknown');
                console.log(chalk.bold('Message:'), chalk.red(selectedLog.message || 'Unknown error'));

                if (selectedLog.stack) {
                    console.log(chalk.bold('\nStack Trace:'));
                    console.log(chalk.gray(selectedLog.stack));
                }

                console.log(chalk.bold('\nSystem Info:'));
                console.log(`OS: ${selectedLog.os?.platform || 'Unknown'} ${selectedLog.os?.release || ''}`);
                console.log(`Node Version: ${selectedLog.node || 'Unknown'}`);

                // Show troubleshooting tips based on category
                const category = errorHandler.categorizeError(selectedLog.message);
                console.log(chalk.cyan('\nTroubleshooting Tips:'));
                category.tips.forEach((tip, index) => {
                    console.log(chalk.white(`${index + 1}. ${tip}`));
                });
            }

        } catch (error) {
            spinner.fail('Failed to load error logs');
            console.error(chalk.red('Error:'), error.message);
        }
    } catch (error) {
        console.error(chalk.red('Error:'), error.message);
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * Export error logs to a file
 */
async function exportErrorLogs() {
    try {
        const spinner = ora('Preparing error logs for export...').start();

        try {
            // Get error log path
            const logPath = errorHandler.getErrorLogPath();

            // Check if log file exists
            if (!await fs.pathExists(logPath)) {
                spinner.fail('No error logs found to export');
                await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
                return;
            }

            // Read logs
            const logs = await fs.readJson(logPath);

            if (logs.length === 0) {
                spinner.fail('No error logs found to export');
                await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
                return;
            }

            // Create export directory if it doesn't exist
            const exportDir = path.join(os.homedir(), 'JuliaOS_Exports');
            await fs.ensureDir(exportDir);

            // Generate export filename with timestamp
            const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
            const exportPath = path.join(exportDir, `juliaos_error_logs_${timestamp}.json`);

            // Write logs to export file
            await fs.writeJson(exportPath, logs, { spaces: 2 });

            spinner.succeed(`Error logs exported successfully to ${exportPath}`);
            console.log(chalk.green(`\nExported ${logs.length} error logs to:`))
            console.log(chalk.cyan(exportPath));

        } catch (error) {
            spinner.fail('Failed to export error logs');
            console.error(chalk.red('Error:'), error.message);
        }
    } catch (error) {
        console.error(chalk.red('Error:'), error.message);
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * Clear error logs
 */
async function clearErrorLogs() {
    try {
        // Confirm clearing logs
        const { confirmClear } = await inquirer.prompt([
            {
                type: 'confirm',
                name: 'confirmClear',
                message: 'Are you sure you want to clear all error logs? This action cannot be undone.',
                default: false
            }
        ]);

        if (!confirmClear) {
            console.log(chalk.yellow('Operation cancelled.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
            return;
        }

        const spinner = ora('Clearing error logs...').start();

        try {
            // Clear error logs
            const success = await errorHandler.clearErrorLogs();

            if (success) {
                spinner.succeed('Error logs cleared successfully');
            } else {
                spinner.fail('Failed to clear error logs');
            }

        } catch (error) {
            spinner.fail('Failed to clear error logs');
            console.error(chalk.red('Error:'), error.message);
        }
    } catch (error) {
        console.error(chalk.red('Error:'), error.message);
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

// Export the module with a function that takes the required dependencies
module.exports = function(deps) {
    // Assign dependencies to local variables if they're passed in
    if (deps) {
        if (deps.juliaBridge) juliaBridge = deps.juliaBridge;
        if (deps.displayHeader) displayHeader = deps.displayHeader;
    }

    // Return an object with all the functions
    return {
        systemConfigMenu,
        viewCurrentConfig,
        configureGeneralSettings,
        configureNetworkSettings,
        configureStorageSettings,
        configureSecuritySettings,
        manageErrorLogs,
        viewRecentErrors,
        exportErrorLogs,
        clearErrorLogs,
        resetToDefault
    };
};
