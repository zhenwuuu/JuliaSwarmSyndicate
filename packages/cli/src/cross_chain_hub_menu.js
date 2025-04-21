// Import required modules
const chalk = require('chalk');
const inquirer = require('inquirer');
const ora = require('ora');

// Initialize variables that will be set by the module consumer
let juliaBridge;
let displayHeader;

/**
 * Display the cross-chain hub menu
 */
async function crossChainHubMenu() {
    try {
        displayHeader('Cross-Chain Hub');

        // Check if the Julia backend is connected
        const isConnected = await juliaBridge.checkConnection();
        if (!isConnected) {
            console.log(chalk.yellow('\nWarning: Not connected to Julia backend. Some features may use mock implementations.'));
        }

        const { action } = await inquirer.prompt([
            {
                type: 'list',
                name: 'action',
                message: 'Choose an action:',
                choices: [
                    { name: '🔄 Bridge Tokens', value: 'bridge_tokens' },
                    { name: '🔍 Check Bridge Status', value: 'check_bridge_status' },
                    { name: '🔑 Redeem Pending Tokens', value: 'redeem_tokens' },
                    { name: '📊 View Cross-Chain Assets', value: 'view_assets' },
                    { name: '📝 Transaction History', value: 'transaction_history' },
                    { name: '⚙️ Bridge Settings', value: 'bridge_settings' },
                    { name: '🔙 Back to Main Menu', value: 'back' }
                ]
            }
        ]);

        switch (action) {
            case 'bridge_tokens':
                await bridgeTokens();
                break;
            case 'check_bridge_status':
                await checkBridgeStatus();
                break;
            case 'redeem_tokens':
                await redeemPendingTokens();
                break;
            case 'view_assets':
                await viewCrossChainAssets();
                break;
            case 'transaction_history':
                await viewTransactionHistory();
                break;
            case 'bridge_settings':
                await configureBridgeSettings();
                break;
            case 'back':
                return;
        }

        // Return to the cross-chain hub menu after completing an action
        await crossChainHubMenu();
    } catch (error) {
        console.error(chalk.red('Error:'), error.message);
        console.error(chalk.yellow('Stack trace:'), error.stack);
        await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
    }
}

/**
 * Bridge tokens between chains
 */
async function bridgeTokens() {
    try {
        console.log(chalk.cyan('\nBridge Tokens'));

        // Get available bridge protocols
        const protocols = [
            { name: 'Wormhole', value: 'wormhole' },
            { name: 'LayerZero', value: 'layerzero' },
            { name: 'Axelar', value: 'axelar' },
            { name: 'Synapse', value: 'synapse' },
            { name: 'Across', value: 'across' }
        ];

        // Prompt for bridge protocol
        const { protocol } = await inquirer.prompt([
            {
                type: 'list',
                name: 'protocol',
                message: 'Select bridge protocol:',
                choices: protocols
            }
        ]);

        // Get available chains for the selected protocol
        const spinner = ora(`Fetching available chains for ${protocol}...`).start();

        try {
            // Use enhanced bridge with proper command mapping
            let chainsResult;
            if (protocol === 'wormhole') {
                chainsResult = await juliaBridge.executeCommand('WormholeBridge.get_available_chains', {}, {
                    showSpinner: false,
                    fallbackToMock: true
                });
            } else if (protocol === 'layerzero') {
                chainsResult = await juliaBridge.executeCommand('get_available_chains_layerzero', {}, {
                    showSpinner: false,
                    fallbackToMock: true
                });
            } else if (protocol === 'axelar') {
                chainsResult = await juliaBridge.executeCommand('get_available_chains_axelar', {}, {
                    showSpinner: false,
                    fallbackToMock: true
                });
            } else if (protocol === 'synapse') {
                chainsResult = await juliaBridge.executeCommand('get_available_chains_synapse', {}, {
                    showSpinner: false,
                    fallbackToMock: true
                });
            } else if (protocol === 'across') {
                chainsResult = await juliaBridge.executeCommand('get_available_chains_across', {}, {
                    showSpinner: false,
                    fallbackToMock: true
                });
            } else if (protocol === 'hop') {
                chainsResult = await juliaBridge.executeCommand('get_available_chains_hop', {}, {
                    showSpinner: false,
                    fallbackToMock: true
                });
            } else if (protocol === 'stargate') {
                chainsResult = await juliaBridge.executeCommand('get_available_chains_stargate', {}, {
                    showSpinner: false,
                    fallbackToMock: true
                });
            } else {
                chainsResult = await juliaBridge.executeCommand('Bridge.get_supported_chains', [protocol], {
                    showSpinner: false,
                    fallbackToMock: true
                });
            }

            spinner.stop();

            if (!chainsResult || chainsResult.error) {
                console.log(chalk.yellow(`Warning: ${chainsResult?.error || 'Failed to fetch supported chains'}. Using default chains.`));
                chainsResult = {
                    chains: [
                        { id: 'ethereum', name: 'Ethereum', chainId: 1 },
                        { id: 'solana', name: 'Solana', chainId: 1 },
                        { id: 'bsc', name: 'Binance Smart Chain', chainId: 56 },
                        { id: 'polygon', name: 'Polygon', chainId: 137 },
                        { id: 'avalanche', name: 'Avalanche', chainId: 43114 }
                    ]
                };
            }

            // Format chains for display
            const chains = (chainsResult?.chains || []).map(chain => ({
                name: chain.name || formatChainName(chain.id),
                value: chain.id || chain.value
            }));

            // Prompt for source and target chains
            const { sourceChain, targetChain } = await inquirer.prompt([
                {
                    type: 'list',
                    name: 'sourceChain',
                    message: 'Select source chain:',
                    choices: chains
                },
                {
                    type: 'list',
                    name: 'targetChain',
                    message: 'Select target chain:',
                    choices: (answers) => chains.filter(chain => chain.value !== answers.sourceChain)
                }
            ]);

            // Get available tokens for the source chain
            const tokensSpinner = ora(`Fetching available tokens for ${sourceChain}...`).start();

            try {
                // Use enhanced bridge with proper command mapping
                let tokensResult;
                if (protocol === 'wormhole') {
                    try {
                        tokensResult = await juliaBridge.executeCommand('WormholeBridge.get_available_tokens', { chain: sourceChain }, {
                            showSpinner: false,
                            fallbackToMock: false
                        });
                    } catch (error) {
                        tokenSpinner.fail('Failed to fetch tokens');
                        console.error(chalk.red('Error:'), error.message);
                        console.log(chalk.yellow('\nWormhole Bridge is not available. Please check if the Julia backend is running and the WormholeBridge module is loaded.'));
                        await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to return to the previous menu...'}]);
                        return;
                    }
                } else if (protocol === 'layerzero') {
                    tokensResult = await juliaBridge.executeCommand('get_available_tokens_layerzero', { chain: sourceChain }, {
                        showSpinner: false,
                        fallbackToMock: true
                    });
                } else if (protocol === 'axelar') {
                    tokensResult = await juliaBridge.executeCommand('get_available_tokens_axelar', { chain: sourceChain }, {
                        showSpinner: false,
                        fallbackToMock: true
                    });
                } else if (protocol === 'synapse') {
                    tokensResult = await juliaBridge.executeCommand('get_available_tokens_synapse', { chain: sourceChain }, {
                        showSpinner: false,
                        fallbackToMock: true
                    });
                } else if (protocol === 'across') {
                    tokensResult = await juliaBridge.executeCommand('get_available_tokens_across', { chain: sourceChain }, {
                        showSpinner: false,
                        fallbackToMock: true
                    });
                } else if (protocol === 'hop') {
                    tokensResult = await juliaBridge.executeCommand('get_available_tokens_hop', { chain: sourceChain }, {
                        showSpinner: false,
                        fallbackToMock: true
                    });
                } else if (protocol === 'stargate') {
                    tokensResult = await juliaBridge.executeCommand('get_available_tokens_stargate', { chain: sourceChain }, {
                        showSpinner: false,
                        fallbackToMock: true
                    });
                } else {
                    tokensResult = await juliaBridge.executeCommand('Bridge.get_supported_tokens', [protocol, sourceChain], {
                        showSpinner: false,
                        fallbackToMock: true
                    });
                }

                tokensSpinner.stop();

                if (!tokensResult || tokensResult.error) {
                    console.log(chalk.yellow(`Warning: ${tokensResult?.error || 'Failed to fetch supported tokens'}. Using default tokens.`));
                    tokensResult = {
                        tokens: [
                            { symbol: 'USDC', name: 'USD Coin', address: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', decimals: 6 },
                            { symbol: 'USDT', name: 'Tether USD', address: '0xdAC17F958D2ee523a2206206994597C13D831ec7', decimals: 6 },
                            { symbol: 'ETH', name: 'Ethereum', address: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2', decimals: 18 },
                            { symbol: 'MATIC', name: 'Polygon', address: '0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270', decimals: 18 },
                            { symbol: 'SOL', name: 'Solana', address: 'So11111111111111111111111111111111111111112', decimals: 9 }
                        ]
                    };
                }

                // Format tokens for display
                const tokens = (tokensResult?.tokens || []).map(token => ({
                    name: `${token.name || token.symbol} (${token.symbol})`,
                    value: token.address || token.value,
                    symbol: token.symbol,
                    decimals: token.decimals
                }));

                // Prompt for token and amount
                const { token, amount, recipient } = await inquirer.prompt([
                    {
                        type: 'list',
                        name: 'token',
                        message: 'Select token to bridge:',
                        choices: tokens.map(t => ({ name: t.name, value: t.value }))
                    },
                    {
                        type: 'input',
                        name: 'amount',
                        message: 'Enter amount to bridge:',
                        validate: input => !isNaN(parseFloat(input)) && parseFloat(input) > 0 ? true : 'Please enter a valid amount'
                    },
                    {
                        type: 'input',
                        name: 'recipient',
                        message: `Enter recipient address on ${targetChain}:`,
                        validate: input => input.trim().length > 0 ? true : 'Recipient address is required'
                    }
                ]);

                // Get the selected token details
                const selectedToken = tokens.find(t => t.value === token) || {
                    name: 'Unknown',
                    symbol: 'Unknown',
                    value: token
                };

                // Confirm the bridge operation
                console.log(chalk.cyan('\nBridge Operation Summary:'));
                console.log(`Protocol: ${protocol}`);
                console.log(`Source Chain: ${formatChainName(sourceChain)}`);
                console.log(`Target Chain: ${formatChainName(targetChain)}`);
                console.log(`Token: ${selectedToken.name}`);
                console.log(`Amount: ${amount} ${selectedToken.symbol}`);
                console.log(`Recipient: ${recipient}`);

                const { confirm } = await inquirer.prompt([
                    {
                        type: 'confirm',
                        name: 'confirm',
                        message: 'Do you want to proceed with this bridge operation?',
                        default: false
                    }
                ]);

                if (!confirm) {
                    console.log(chalk.yellow('Bridge operation cancelled.'));
                    return;
                }

                // Execute the bridge operation
                const bridgeSpinner = ora('Initiating bridge operation...').start();

                try {
                    // Use enhanced bridge with proper command mapping
                    let bridgeResult;
                    // Prepare common bridge parameters
                    const bridgeParams = {
                        sourceChain: sourceChain,
                        targetChain: targetChain,
                        token: token,
                        amount: amount,
                        recipient: recipient,
                        wallet: 'default' // Use default wallet for now
                    };

                    if (protocol === 'wormhole') {
                        try {
                            bridgeResult = await juliaBridge.executeCommand('WormholeBridge.bridge_tokens', bridgeParams, {
                                showSpinner: false,
                                fallbackToMock: false
                            });
                        } catch (error) {
                            bridgeSpinner.fail('Failed to initiate bridge operation');
                            console.error(chalk.red('Error:'), error.message);
                            console.log(chalk.yellow('\nWormhole Bridge is not available. Please check if the Julia backend is running and the WormholeBridge module is loaded.'));
                            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to return to the previous menu...'}]);
                            return;
                        }
                    } else if (protocol === 'layerzero') {
                        bridgeResult = await juliaBridge.executeCommand('bridge_tokens_layerzero', bridgeParams, {
                            showSpinner: false,
                            fallbackToMock: true
                        });
                    } else if (protocol === 'axelar') {
                        // For Axelar, we might want to get the gas fee first
                        const gasFeeResult = await juliaBridge.executeCommand('get_gas_fee_axelar', bridgeParams, {
                            showSpinner: false,
                            fallbackToMock: true
                        });

                        if (gasFeeResult && gasFeeResult.success) {
                            console.log(chalk.cyan('\nEstimated Gas Fee:'));
                            console.log(`Amount: ${gasFeeResult.fee.amount} ${gasFeeResult.fee.token}`);
                            console.log(`USD Value: $${gasFeeResult.fee.usd_value}`);
                            console.log(`Estimated Time: ${gasFeeResult.estimated_time} minutes`);

                            const { confirmFee } = await inquirer.prompt([
                                {
                                    type: 'confirm',
                                    name: 'confirmFee',
                                    message: 'Do you accept this gas fee?',
                                    default: true
                                }
                            ]);

                            if (!confirmFee) {
                                console.log(chalk.yellow('Bridge operation cancelled.'));
                                return;
                            }
                        }

                        bridgeResult = await juliaBridge.executeCommand('bridge_tokens_axelar', bridgeParams, {
                            showSpinner: false,
                            fallbackToMock: true
                        });
                    } else if (protocol === 'synapse') {
                        // For Synapse, we might want to get the bridge fee first
                        const bridgeFeeResult = await juliaBridge.executeCommand('get_bridge_fee_synapse', bridgeParams, {
                            showSpinner: false,
                            fallbackToMock: true
                        });

                        if (bridgeFeeResult && bridgeFeeResult.success) {
                            console.log(chalk.cyan('\nEstimated Bridge Fee:'));
                            console.log(`Amount: ${bridgeFeeResult.fee.amount} ${bridgeFeeResult.fee.token}`);
                            console.log(`USD Value: $${bridgeFeeResult.fee.usd_value}`);
                            console.log(`Estimated Time: ${bridgeFeeResult.estimated_time} minutes`);

                            const { confirmFee } = await inquirer.prompt([
                                {
                                    type: 'confirm',
                                    name: 'confirmFee',
                                    message: 'Do you accept this bridge fee?',
                                    default: true
                                }
                            ]);

                            if (!confirmFee) {
                                console.log(chalk.yellow('Bridge operation cancelled.'));
                                return;
                            }
                        }

                        bridgeResult = await juliaBridge.executeCommand('bridge_tokens_synapse', bridgeParams, {
                            showSpinner: false,
                            fallbackToMock: true
                        });
                    } else if (protocol === 'across') {
                        // For Across, we might want to get the relay fee first
                        const relayFeeResult = await juliaBridge.executeCommand('get_relay_fee_across', bridgeParams, {
                            showSpinner: false,
                            fallbackToMock: true
                        });

                        if (relayFeeResult && relayFeeResult.success) {
                            console.log(chalk.cyan('\nEstimated Relay Fee:'));
                            console.log(`Amount: ${relayFeeResult.fee.amount} ${relayFeeResult.fee.token}`);
                            console.log(`USD Value: $${relayFeeResult.fee.usd_value}`);
                            console.log(`Estimated Relay Time: ${relayFeeResult.relay_time_minutes} minutes`);

                            const { confirmFee } = await inquirer.prompt([
                                {
                                    type: 'confirm',
                                    name: 'confirmFee',
                                    message: 'Do you accept this relay fee?',
                                    default: true
                                }
                            ]);

                            if (!confirmFee) {
                                console.log(chalk.yellow('Bridge operation cancelled.'));
                                return;
                            }
                        }

                        bridgeResult = await juliaBridge.executeCommand('bridge_tokens_across', bridgeParams, {
                            showSpinner: false,
                            fallbackToMock: true
                        });
                    } else if (protocol === 'hop') {
                        // For Hop, we might want to get the bridge fee first
                        const bridgeFeeResult = await juliaBridge.executeCommand('get_bridge_fee_hop', bridgeParams, {
                            showSpinner: false,
                            fallbackToMock: true
                        });

                        if (bridgeFeeResult && bridgeFeeResult.success) {
                            console.log(chalk.cyan('\nEstimated Bridge Fee:'));
                            console.log(`Amount: ${bridgeFeeResult.fee.amount} ${bridgeFeeResult.fee.token}`);
                            console.log(`USD Value: $${bridgeFeeResult.fee.usd_value}`);
                            console.log(`Estimated Time: ${bridgeFeeResult.estimated_time_minutes} minutes`);

                            const { confirmFee } = await inquirer.prompt([
                                {
                                    type: 'confirm',
                                    name: 'confirmFee',
                                    message: 'Do you accept this bridge fee?',
                                    default: true
                                }
                            ]);

                            if (!confirmFee) {
                                console.log(chalk.yellow('Bridge operation cancelled.'));
                                return;
                            }
                        }

                        bridgeResult = await juliaBridge.executeCommand('bridge_tokens_hop', bridgeParams, {
                            showSpinner: false,
                            fallbackToMock: true
                        });
                    } else if (protocol === 'stargate') {
                        // For Stargate, we might want to get the bridge fee first
                        const bridgeFeeResult = await juliaBridge.executeCommand('get_bridge_fee_stargate', bridgeParams, {
                            showSpinner: false,
                            fallbackToMock: true
                        });

                        if (bridgeFeeResult && bridgeFeeResult.success) {
                            console.log(chalk.cyan('\nEstimated Bridge Fee:'));
                            console.log(`Amount: ${bridgeFeeResult.fee.amount} ${bridgeFeeResult.fee.token}`);
                            console.log(`USD Value: $${bridgeFeeResult.fee.usd_value}`);
                            console.log(`Estimated Time: ${bridgeFeeResult.estimated_time_minutes} minutes`);

                            const { confirmFee } = await inquirer.prompt([
                                {
                                    type: 'confirm',
                                    name: 'confirmFee',
                                    message: 'Do you accept this bridge fee?',
                                    default: true
                                }
                            ]);

                            if (!confirmFee) {
                                console.log(chalk.yellow('Bridge operation cancelled.'));
                                return;
                            }
                        }

                        bridgeResult = await juliaBridge.executeCommand('bridge_tokens_stargate', bridgeParams, {
                            showSpinner: false,
                            fallbackToMock: true
                        });
                    } else {
                        bridgeResult = await juliaBridge.executeCommand('Bridge.bridge_tokens', [
                            protocol,
                            sourceChain,
                            targetChain,
                            token,
                            amount,
                            recipient
                        ], {
                            showSpinner: false,
                            fallbackToMock: true
                        });
                    }

                    bridgeSpinner.stop();

                    if (!bridgeResult || bridgeResult.error) {
                        console.log(chalk.red(`Error: ${bridgeResult?.error || 'Failed to initiate bridge operation'}`));
                        return;
                    }

                    console.log(chalk.green('\nBridge operation initiated successfully!'));
                    console.log(chalk.cyan('\nTransaction Details:'));
                    console.log(`Transaction Hash: ${bridgeResult.transactionHash || bridgeResult.tx_hash || 'N/A'}`);
                    console.log(`Status: ${bridgeResult.status || 'pending'}`);
                    console.log(`Estimated Completion Time: ${bridgeResult.estimated_time || 'Approximately 15 minutes'}`);

                    if (bridgeResult.attestation || bridgeResult.tracking_id) {
                        console.log(`Tracking ID: ${bridgeResult.attestation || bridgeResult.tracking_id}`);
                        console.log(chalk.yellow('\nUse the "Check Bridge Status" option to monitor your transaction.'));
                    }
                } catch (error) {
                    bridgeSpinner.fail('Failed to initiate bridge operation');
                    console.error(chalk.red('Error:'), error.message);
                    console.error(chalk.yellow('Stack trace:'), error.stack);
                }
            } catch (error) {
                tokensSpinner.fail('Failed to fetch supported tokens');
                console.error(chalk.red('Error:'), error.message);
                console.error(chalk.yellow('Stack trace:'), error.stack);
            }
        } catch (error) {
            spinner.fail('Failed to fetch supported chains');
            console.error(chalk.red('Error:'), error.message);
            console.error(chalk.yellow('Stack trace:'), error.stack);
        }
    } catch (error) {
        console.error(chalk.red('Error:'), error.message);
        console.error(chalk.yellow('Stack trace:'), error.stack);
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * Check bridge transaction status
 */
async function checkBridgeStatus() {
    try {
        console.log(chalk.cyan('\nCheck Bridge Status'));

        // Check if the Julia backend is connected
        const isConnected = await juliaBridge.checkConnection();
        if (!isConnected) {
            console.log(chalk.yellow('\nWarning: Not connected to Julia backend. Using mock implementations.'));
        }

        // Prompt for tracking method
        const { trackingMethod } = await inquirer.prompt([
            {
                type: 'list',
                name: 'trackingMethod',
                message: 'How would you like to track your transaction?',
                choices: [
                    { name: 'By Tracking ID', value: 'tracking_id' },
                    { name: 'By Transaction Hash', value: 'tx_hash' },
                    { name: 'View Recent Transactions', value: 'recent' },
                    { name: 'Redeem Pending Tokens', value: 'redeem' }
                ]
            }
        ]);

        if (trackingMethod === 'tracking_id') {
            // Prompt for tracking ID
            const { trackingId, protocol } = await inquirer.prompt([
                {
                    type: 'input',
                    name: 'trackingId',
                    message: 'Enter tracking ID:',
                    validate: input => input.trim().length > 0 ? true : 'Tracking ID is required'
                },
                {
                    type: 'list',
                    name: 'protocol',
                    message: 'Select bridge protocol:',
                    choices: [
                        { name: 'Wormhole', value: 'wormhole' },
                        { name: 'LayerZero', value: 'layerzero' },
                        { name: 'Axelar', value: 'axelar' },
                        { name: 'Synapse', value: 'synapse' },
                        { name: 'Across', value: 'across' }
                    ]
                }
            ]);

            // Check status by tracking ID
            await checkStatusByTrackingId(trackingId, protocol);
        } else if (trackingMethod === 'tx_hash') {
            // Get available chains
            const spinner = ora('Fetching available chains...').start();

            let chainsResult;
            try {
                chainsResult = await juliaBridge.executeCommand('WormholeBridge.get_available_chains', {}, {
                    showSpinner: false,
                    fallbackToMock: false
                });
                spinner.stop();
            } catch (error) {
                spinner.fail('Failed to fetch chains');
                console.error(chalk.red('Error:'), error.message);
                console.log(chalk.yellow('\nWormhole Bridge is not available. Please check if the Julia backend is running and the WormholeBridge module is loaded.'));
                await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to return to the previous menu...'}]);
                return;
            }

            // Format chains for display
            const chains = chainsResult?.chains?.map(chain => ({
                name: chain.name || formatChainName(chain.id),
                value: chain.id || chain.value
            })) || [
                { name: 'Ethereum', value: 'ethereum' },
                { name: 'Polygon', value: 'polygon' },
                { name: 'Solana', value: 'solana' },
                { name: 'Avalanche', value: 'avalanche' },
                { name: 'Binance Smart Chain', value: 'bsc' }
            ];

            // Prompt for transaction hash and chain
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
                    message: 'Select source chain:',
                    choices: chains
                }
            ]);

            // Check status by transaction hash
            await checkStatusByTxHash(txHash, chain);
        } else if (trackingMethod === 'recent') {
            // View recent transactions
            await viewRecentTransactions();
        } else if (trackingMethod === 'redeem') {
            // Redeem pending tokens
            await redeemPendingTokens();
        }
    } catch (error) {
        console.error(chalk.red('Error:'), error.message);
        console.error(chalk.yellow('Stack trace:'), error.stack);
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * Check bridge status by tracking ID
 */
async function checkStatusByTrackingId(trackingId, protocol) {
    const spinner = ora(`Checking status for tracking ID ${trackingId}...`).start();

    try {
        let result;
        if (protocol === 'wormhole') {
            try {
                result = await juliaBridge.executeCommand('WormholeBridge.check_bridge_status', {
                    attestation: trackingId,
                    sourceChain: 'unknown' // We don't know the source chain from just the tracking ID
                }, {
                    showSpinner: false,
                    fallbackToMock: false
                });
            } catch (error) {
                console.error(chalk.red('Error:'), error.message);
                console.log(chalk.yellow('\nWormhole Bridge is not available. Please check if the Julia backend is running and the WormholeBridge module is loaded.'));
                await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to return to the previous menu...'}]);
                return;
            }
        } else if (protocol === 'layerzero') {
            result = await juliaBridge.executeCommand('check_bridge_status_layerzero', {
                messageId: trackingId
            }, {
                showSpinner: false,
                fallbackToMock: true
            });
        } else if (protocol === 'axelar') {
            result = await juliaBridge.executeCommand('check_bridge_status_axelar', {
                transferId: trackingId
            }, {
                showSpinner: false,
                fallbackToMock: true
            });
        } else if (protocol === 'synapse') {
            result = await juliaBridge.executeCommand('check_bridge_status_synapse', {
                bridgeId: trackingId
            }, {
                showSpinner: false,
                fallbackToMock: true
            });
        } else if (protocol === 'across') {
            result = await juliaBridge.executeCommand('check_bridge_status_across', {
                depositId: trackingId
            }, {
                showSpinner: false,
                fallbackToMock: true
            });
        } else if (protocol === 'hop') {
            result = await juliaBridge.executeCommand('check_bridge_status_hop', {
                transferId: trackingId
            }, {
                showSpinner: false,
                fallbackToMock: true
            });
        } else if (protocol === 'stargate') {
            result = await juliaBridge.executeCommand('check_bridge_status_stargate', {
                transferId: trackingId
            }, {
                showSpinner: false,
                fallbackToMock: true
            });
        } else {
            result = await juliaBridge.executeCommand('Bridge.check_status_by_tracking_id', [trackingId, protocol], {
                showSpinner: false,
                fallbackToMock: true
            });
        }

        spinner.stop();

        if (!result || result.error) {
            console.log(chalk.red(`Error: ${result?.error || 'Failed to check status'}`));
            // Generate mock status for demonstration
            const mockStatus = generateMockBridgeStatus(protocol, trackingId);
            console.log(chalk.yellow('\nShowing mock status for demonstration:'));
            displayBridgeStatus(mockStatus);
            return;
        }

        displayBridgeStatus(result.status || result);
    } catch (error) {
        spinner.fail('Failed to check status');
        console.error(chalk.red('Error:'), error.message);
        console.error(chalk.yellow('Stack trace:'), error.stack);

        // Generate mock status for demonstration
        const mockStatus = generateMockBridgeStatus(protocol, trackingId);
        console.log(chalk.yellow('\nShowing mock status for demonstration:'));
        displayBridgeStatus(mockStatus);
    }
}

/**
 * Check bridge status by transaction hash
 */
async function checkStatusByTxHash(txHash, chain) {
    const spinner = ora(`Checking status for transaction ${txHash}...`).start();

    try {
        let result;
        // Try all bridge protocols
        let wormholeResult;
        try {
            wormholeResult = await juliaBridge.executeCommand('WormholeBridge.check_bridge_status', {
                sourceChain: chain,
                transaction_hash: txHash
            }, {
                showSpinner: false,
                fallbackToMock: false
            });
        } catch (error) {
            spinner.fail('Failed to check bridge status');
            console.error(chalk.red('Error:'), error.message);
            console.log(chalk.yellow('\nWormhole Bridge is not available. Please check if the Julia backend is running and the WormholeBridge module is loaded.'));
            await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to return to the previous menu...'}]);
            return;
        }

        if (wormholeResult && wormholeResult.success) {
            result = wormholeResult;
            result.protocol = 'wormhole';
        } else {
            // Try LayerZero
            let layerzeroResult = await juliaBridge.executeCommand('check_bridge_status_layerzero', {
                sourceChain: chain,
                transactionHash: txHash
            }, {
                showSpinner: false,
                fallbackToMock: true
            });

            if (layerzeroResult && layerzeroResult.success) {
                result = layerzeroResult;
                result.protocol = 'layerzero';
            } else {
                // Try Axelar
                let axelarResult = await juliaBridge.executeCommand('check_bridge_status_axelar', {
                    sourceChain: chain,
                    transactionHash: txHash
                }, {
                    showSpinner: false,
                    fallbackToMock: true
                });

                if (axelarResult && axelarResult.success) {
                    result = axelarResult;
                    result.protocol = 'axelar';
                } else {
                    // Try Synapse
                    let synapseResult = await juliaBridge.executeCommand('check_bridge_status_synapse', {
                        sourceChain: chain,
                        transactionHash: txHash
                    }, {
                        showSpinner: false,
                        fallbackToMock: true
                    });

                    if (synapseResult && synapseResult.success) {
                        result = synapseResult;
                        result.protocol = 'synapse';
                    } else {
                        // Try Across
                        let acrossResult = await juliaBridge.executeCommand('check_bridge_status_across', {
                            sourceChain: chain,
                            transactionHash: txHash
                        }, {
                            showSpinner: false,
                            fallbackToMock: true
                        });

                        if (acrossResult && acrossResult.success) {
                            result = acrossResult;
                            result.protocol = 'across';
                        } else {
                            // Try Hop
                            let hopResult = await juliaBridge.executeCommand('check_bridge_status_hop', {
                                sourceChain: chain,
                                transactionHash: txHash
                            }, {
                                showSpinner: false,
                                fallbackToMock: true
                            });

                            if (hopResult && hopResult.success) {
                                result = hopResult;
                                result.protocol = 'hop';
                            } else {
                                // Try Stargate
                                let stargateResult = await juliaBridge.executeCommand('check_bridge_status_stargate', {
                                    sourceChain: chain,
                                    transactionHash: txHash
                                }, {
                                    showSpinner: false,
                                    fallbackToMock: true
                                });

                                if (stargateResult && stargateResult.success) {
                                    result = stargateResult;
                                    result.protocol = 'stargate';
                                } else {
                                    // Try generic bridge
                                    result = await juliaBridge.executeCommand('Bridge.check_status_by_tx_hash', [txHash, chain], {
                                        showSpinner: false,
                                        fallbackToMock: true
                                    });
                                }
                            }
                        }
                    }
                }
            }
        }

        spinner.stop();

        if (!result || result.error) {
            console.log(chalk.red(`Error: ${result?.error || 'Failed to check status'}`));
            // Generate mock status for demonstration
            const mockStatus = generateMockBridgeStatus('wormhole', txHash, chain);
            console.log(chalk.yellow('\nShowing mock status for demonstration:'));
            displayBridgeStatus(mockStatus);
            return;
        }

        displayBridgeStatus(result.status || result);
    } catch (error) {
        spinner.fail('Failed to check status');
        console.error(chalk.red('Error:'), error.message);
        console.error(chalk.yellow('Stack trace:'), error.stack);

        // Generate mock status for demonstration
        const mockStatus = generateMockBridgeStatus('wormhole', txHash, chain);
        console.log(chalk.yellow('\nShowing mock status for demonstration:'));
        displayBridgeStatus(mockStatus);
    }
}

/**
 * View recent bridge transactions
 */
async function viewRecentTransactions() {
    const spinner = ora('Fetching recent transactions...').start();

    try {
        // Use enhanced bridge with proper command mapping
        const result = await juliaBridge.executeCommand('Bridge.get_recent_transactions', [], {
            showSpinner: false,
            fallbackToMock: true
        });

        spinner.stop();

        if (!result || result.error) {
            console.log(chalk.yellow(`Warning: ${result?.error || 'Failed to fetch recent transactions'}. Using mock data.`));

            // Generate mock transactions for demonstration
            const mockTransactions = generateMockTransactions(5);
            displayTransactions(mockTransactions);
            return;
        }

        const transactions = result.transactions || [];

        if (transactions.length === 0) {
            console.log(chalk.yellow('\nNo recent transactions found.'));
            return;
        }

        displayTransactions(transactions);
    } catch (error) {
        spinner.fail('Failed to fetch recent transactions');
        console.error(chalk.red('Error:'), error.message);
        console.error(chalk.yellow('Stack trace:'), error.stack);

        // Generate mock transactions for demonstration
        const mockTransactions = generateMockTransactions(5);
        console.log(chalk.yellow('\nShowing mock transactions for demonstration:'));
        displayTransactions(mockTransactions);
    }
}

/**
 * Display a list of transactions
 */
function displayTransactions(transactions) {
    console.log(chalk.cyan('\nRecent Bridge Transactions:'));

    transactions.forEach((tx, index) => {
        console.log(chalk.bold(`\n${index + 1}. ${tx.protocol} Bridge - ${formatChainName(tx.source_chain)} to ${formatChainName(tx.target_chain)}`));
        console.log(`   Token: ${tx.token_symbol} (${tx.amount} ${tx.token_symbol})`);
        console.log(`   Status: ${getStatusDisplay(tx.status)}`);
        console.log(`   Transaction Hash: ${tx.source_tx_hash || tx.tx_hash}`);
        console.log(`   Tracking ID: ${tx.tracking_id || tx.attestation || 'N/A'}`);
        console.log(`   Time: ${tx.timestamp || tx.initiated_at}`);
    });

    // Prompt to check status of a specific transaction
    inquirer.prompt([
        {
            type: 'confirm',
            name: 'checkSpecific',
            message: 'Would you like to check the status of a specific transaction?',
            default: false
        }
    ]).then(({ checkSpecific }) => {
        if (checkSpecific) {
            inquirer.prompt([
                {
                    type: 'number',
                    name: 'txIndex',
                    message: 'Enter the number of the transaction:',
                    validate: input => input > 0 && input <= transactions.length ? true : `Please enter a number between 1 and ${transactions.length}`
                }
            ]).then(({ txIndex }) => {
                const selectedTx = transactions[txIndex - 1];

                if (selectedTx.tracking_id || selectedTx.attestation) {
                    checkStatusByTrackingId(selectedTx.tracking_id || selectedTx.attestation, selectedTx.protocol || 'wormhole');
                } else {
                    checkStatusByTxHash(selectedTx.source_tx_hash || selectedTx.tx_hash, selectedTx.source_chain);
                }
            });
        }
    });
}

/**
 * Display bridge status information
 */
function displayBridgeStatus(status) {
    if (!status) {
        console.log(chalk.red('\nError: No status information available'));
        return;
    }

    console.log(chalk.cyan('\nBridge Transaction Status:'));

    // Display status with appropriate color
    console.log(`Status: ${getStatusDisplay(status.status)}`);

    // Display transaction details
    console.log(chalk.bold('\nTransaction Details:'));
    console.log(`Protocol: ${status.protocol || 'Unknown'}`);
    console.log(`Source Chain: ${status.source_chain ? formatChainName(status.source_chain) : 'Unknown'}`);
    console.log(`Target Chain: ${status.target_chain ? formatChainName(status.target_chain) : 'Unknown'}`);
    console.log(`Token: ${status.token_symbol || 'Unknown'}`);
    console.log(`Amount: ${status.amount || 'Unknown'} ${status.token_symbol || ''}`);
    console.log(`Source Transaction Hash: ${status.source_tx_hash || status.tx_hash || 'Unknown'}`);

    if (status.target_tx_hash) {
        console.log(`Target Transaction Hash: ${status.target_tx_hash}`);
    }

    // Display timestamps
    console.log(chalk.bold('\nTimestamps:'));
    console.log(`Initiated: ${status.initiated_at || 'Unknown'}`);

    if (status.completed_at) {
        console.log(`Completed: ${status.completed_at}`);
    } else if (status.estimated_completion_time) {
        console.log(`Estimated Completion: ${status.estimated_completion_time}`);
    }

    // Display progress information
    if (status.progress) {
        console.log(chalk.bold('\nProgress:'));
        console.log(`Current Step: ${status.progress.current_step} of ${status.progress.total_steps}`);
        console.log(`Description: ${status.progress.description}`);

        if (status.progress.percentage) {
            console.log(`Percentage: ${status.progress.percentage}%`);
        }
    }

    // Display any errors or warnings
    if (status.errors && status.errors.length > 0) {
        console.log(chalk.bold.red('\nErrors:'));
        status.errors.forEach(error => {
            console.log(`- ${error}`);
        });
    }

    if (status.warnings && status.warnings.length > 0) {
        console.log(chalk.bold.yellow('\nWarnings:'));
        status.warnings.forEach(warning => {
            console.log(`- ${warning}`);
        });
    }

    // Display next steps if available
    if (status.next_steps) {
        console.log(chalk.bold('\nNext Steps:'));
        console.log(status.next_steps);
    }
}

/**
 * Get formatted status display with color
 */
function getStatusDisplay(status) {
    if (!status) return chalk.gray('Unknown');

    switch (status.toLowerCase()) {
        case 'pending':
        case 'in_progress':
            return chalk.yellow(status);
        case 'completed':
        case 'success':
            return chalk.green(status);
        case 'failed':
        case 'error':
            return chalk.red(status);
        default:
            return chalk.gray(status);
    }
}

/**
 * View cross-chain assets
 */
async function viewCrossChainAssets() {
    try {
        console.log(chalk.cyan('\nView Cross-Chain Assets'));

        // Prompt for view type
        const { viewType } = await inquirer.prompt([
            {
                type: 'list',
                name: 'viewType',
                message: 'How would you like to view your assets?',
                choices: [
                    { name: 'By Chain', value: 'by_chain' },
                    { name: 'By Token', value: 'by_token' },
                    { name: 'Portfolio Overview', value: 'portfolio' }
                ]
            }
        ]);

        if (viewType === 'by_chain') {
            await viewAssetsByChain();
        } else if (viewType === 'by_token') {
            await viewAssetsByToken();
        } else if (viewType === 'portfolio') {
            await viewPortfolioOverview();
        }
    } catch (error) {
        console.error(chalk.red('Error:'), error.message);
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * Redeem pending tokens
 */
async function redeemPendingTokens() {
    try {
        console.log(chalk.cyan('\nRedeem Pending Tokens'));

        // Check if the Julia backend is connected
        const isConnected = await juliaBridge.checkConnection();
        if (!isConnected) {
            console.log(chalk.yellow('\nWarning: Not connected to Julia backend. Using mock implementations.'));
        }

        // Prompt for protocol
        const { protocol } = await inquirer.prompt([
            {
                type: 'list',
                name: 'protocol',
                message: 'Select bridge protocol:',
                choices: [
                    { name: 'Wormhole', value: 'wormhole' },
                    { name: 'LayerZero', value: 'layerzero' },
                    { name: 'Axelar', value: 'axelar' },
                    { name: 'Synapse', value: 'synapse' },
                    { name: 'Across', value: 'across' }
                ]
            }
        ]);

        // Get available chains
        const spinner = ora('Fetching available chains...').start();

        let chainsResult;
        try {
            if (protocol === 'wormhole') {
                try {
                    chainsResult = await juliaBridge.executeCommand('WormholeBridge.get_available_chains', {}, {
                        showSpinner: false,
                        fallbackToMock: false
                    });
                } catch (error) {
                    spinner.fail('Failed to fetch chains');
                    console.error(chalk.red('Error:'), error.message);
                    console.log(chalk.yellow('\nWormhole Bridge is not available. Please check if the Julia backend is running and the WormholeBridge module is loaded.'));
                    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to return to the previous menu...'}]);
                    return;
                }
            } else {
                chainsResult = await juliaBridge.executeCommand(`get_available_chains_${protocol}`, {}, {
                    showSpinner: false,
                    fallbackToMock: true
                });
            }
            spinner.stop();
        } catch (error) {
            spinner.fail('Failed to fetch chains');
            console.error(chalk.red('Error:'), error.message);
        }

        // Format chains for display
        const chains = chainsResult?.chains?.map(chain => ({
            name: chain.name || formatChainName(chain.id),
            value: chain.id || chain.value
        })) || [
            { name: 'Ethereum', value: 'ethereum' },
            { name: 'Polygon', value: 'polygon' },
            { name: 'Solana', value: 'solana' },
            { name: 'Avalanche', value: 'avalanche' },
            { name: 'Binance Smart Chain', value: 'bsc' }
        ];

        // Prompt for redemption method
        const { redeemMethod } = await inquirer.prompt([
            {
                type: 'list',
                name: 'redeemMethod',
                message: 'How would you like to redeem tokens?',
                choices: [
                    { name: 'By Transaction Hash', value: 'tx_hash' },
                    { name: 'By Tracking ID', value: 'tracking_id' }
                ]
            }
        ]);

        let redeemParams = {};

        if (redeemMethod === 'tx_hash') {
            // Prompt for transaction hash and target chain
            const { txHash, targetChain } = await inquirer.prompt([
                {
                    type: 'input',
                    name: 'txHash',
                    message: 'Enter source transaction hash:',
                    validate: input => input.trim().length > 0 ? true : 'Transaction hash is required'
                },
                {
                    type: 'list',
                    name: 'targetChain',
                    message: 'Select target chain:',
                    choices: chains
                }
            ]);

            redeemParams = {
                transaction_hash: txHash,
                targetChain: targetChain,
                wallet: 'default' // Use default wallet for now
            };
        } else {
            // Prompt for tracking ID and target chain
            const { trackingId, targetChain } = await inquirer.prompt([
                {
                    type: 'input',
                    name: 'trackingId',
                    message: 'Enter tracking ID:',
                    validate: input => input.trim().length > 0 ? true : 'Tracking ID is required'
                },
                {
                    type: 'list',
                    name: 'targetChain',
                    message: 'Select target chain:',
                    choices: chains
                }
            ]);

            redeemParams = {
                attestation: trackingId,
                targetChain: targetChain,
                wallet: 'default' // Use default wallet for now
            };
        }

        // Confirm the redemption operation
        console.log(chalk.cyan('\nRedemption Operation Summary:'));
        console.log(`Protocol: ${protocol}`);
        console.log(`Target Chain: ${formatChainName(redeemParams.targetChain)}`);
        if (redeemParams.transaction_hash) {
            console.log(`Transaction Hash: ${redeemParams.transaction_hash}`);
        } else {
            console.log(`Tracking ID: ${redeemParams.attestation}`);
        }

        const { confirm } = await inquirer.prompt([
            {
                type: 'confirm',
                name: 'confirm',
                message: 'Do you want to proceed with this redemption operation?',
                default: false
            }
        ]);

        if (!confirm) {
            console.log(chalk.yellow('Redemption operation cancelled.'));
            return;
        }

        // Execute the redemption operation
        const redeemSpinner = ora('Initiating redemption operation...').start();

        try {
            let redeemResult;
            if (protocol === 'wormhole') {
                try {
                    redeemResult = await juliaBridge.executeCommand('WormholeBridge.redeem_tokens', redeemParams, {
                        showSpinner: false,
                        fallbackToMock: false
                    });
                } catch (error) {
                    redeemSpinner.fail('Failed to initiate redemption operation');
                    console.error(chalk.red('Error:'), error.message);
                    console.log(chalk.yellow('\nWormhole Bridge is not available. Please check if the Julia backend is running and the WormholeBridge module is loaded.'));
                    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to return to the previous menu...'}]);
                    return;
                }
            } else {
                redeemResult = await juliaBridge.executeCommand(`redeem_tokens_${protocol}`, redeemParams, {
                    showSpinner: false,
                    fallbackToMock: true
                });
            }

            redeemSpinner.stop();

            if (!redeemResult || redeemResult.error) {
                console.log(chalk.red(`Error: ${redeemResult?.error || 'Failed to initiate redemption operation'}`));
                return;
            }

            console.log(chalk.green('\nRedemption operation initiated successfully!'));
            console.log(chalk.cyan('\nTransaction Details:'));
            console.log(`Redeem Transaction Hash: ${redeemResult.redeem_transaction_hash || redeemResult.redeemTransactionHash || 'N/A'}`);
            console.log(`Status: ${redeemResult.status || 'pending'}`);
            console.log(`Estimated Completion Time: ${redeemResult.estimated_time || 'Approximately 5 minutes'}`);

            console.log(chalk.yellow('\nUse the "Check Bridge Status" option to monitor your transaction.'));
        } catch (error) {
            redeemSpinner.fail('Failed to initiate redemption operation');
            console.error(chalk.red('Error:'), error.message);
            console.error(chalk.yellow('Stack trace:'), error.stack);
        }
    } catch (error) {
        console.error(chalk.red('Error:'), error.message);
        console.error(chalk.yellow('Stack trace:'), error.stack);
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * View assets organized by chain
 */
async function viewAssetsByChain() {
    // Get available chains
    const spinner = ora('Fetching chain data...').start();

    try {
        // Use enhanced bridge with proper command mapping
        const result = await juliaBridge.executeCommand('Bridge.get_assets_by_chain', [], {
            showSpinner: false,
            fallbackToMock: true
        });

        spinner.stop();

        if (!result || result.error) {
            console.log(chalk.yellow(`Warning: ${result?.error || 'Failed to fetch assets'}. Using mock data.`));

            // Generate mock assets for demonstration
            const mockAssets = {
                ethereum: [
                    { symbol: 'ETH', name: 'Ethereum', balance: '1.5', usd_value: 3000 },
                    { symbol: 'USDC', name: 'USD Coin', balance: '500', usd_value: 500 }
                ],
                polygon: [
                    { symbol: 'MATIC', name: 'Polygon', balance: '1000', usd_value: 800 },
                    { symbol: 'USDT', name: 'Tether', balance: '200', usd_value: 200 }
                ],
                solana: [
                    { symbol: 'SOL', name: 'Solana', balance: '20', usd_value: 1600 }
                ]
            };

            displayAssetsByChain(mockAssets);
            return;
        }

        const chainAssets = result.assets || {};
        displayAssetsByChain(chainAssets);
    } catch (error) {
        spinner.fail('Failed to fetch assets');
        console.error(chalk.red('Error:'), error.message);
        console.error(chalk.yellow('Stack trace:'), error.stack);

        // Generate mock assets for demonstration
        const mockAssets = {
            ethereum: [
                { symbol: 'ETH', name: 'Ethereum', balance: '1.5', usd_value: 3000 },
                { symbol: 'USDC', name: 'USD Coin', balance: '500', usd_value: 500 }
            ],
            polygon: [
                { symbol: 'MATIC', name: 'Polygon', balance: '1000', usd_value: 800 },
                { symbol: 'USDT', name: 'Tether', balance: '200', usd_value: 200 }
            ],
            solana: [
                { symbol: 'SOL', name: 'Solana', balance: '20', usd_value: 1600 }
            ]
        };

        console.log(chalk.yellow('\nShowing mock assets for demonstration:'));
        displayAssetsByChain(mockAssets);
    }
}

/**
 * Display assets organized by chain
 */
function displayAssetsByChain(chainAssets) {
    // Display assets by chain
    console.log(chalk.cyan('\nAssets by Chain:'));

    let totalUsdValue = 0;

    for (const [chain, assets] of Object.entries(chainAssets)) {
        if (assets.length === 0) continue;

        let chainUsdValue = 0;
        assets.forEach(asset => {
            chainUsdValue += asset.usd_value;
            totalUsdValue += asset.usd_value;
        });

        console.log(chalk.bold(`\n${formatChainName(chain)} ($${chainUsdValue.toFixed(2)})`));

        assets.forEach(asset => {
            console.log(`   ${asset.symbol}: ${asset.balance} (${asset.name}) - $${asset.usd_value.toFixed(2)}`);
        });
    }

    console.log(chalk.bold.green(`\nTotal Portfolio Value: $${totalUsdValue.toFixed(2)}`));
}

/**
 * View assets organized by token
 */
async function viewAssetsByToken() {
    // Get available tokens
    const spinner = ora('Fetching token data...').start();

    try {
        // Use enhanced bridge with proper command mapping
        const result = await juliaBridge.executeCommand('Bridge.get_assets_by_token', [], {
            showSpinner: false,
            fallbackToMock: true
        });

        spinner.stop();

        if (!result || result.error) {
            console.log(chalk.yellow(`Warning: ${result?.error || 'Failed to fetch assets'}. Using mock data.`));

            // Generate mock assets for demonstration
            const mockAssets = {
                ETH: [
                    { chain: 'ethereum', balance: '1.5', usd_value: 3000 }
                ],
                USDC: [
                    { chain: 'ethereum', balance: '500', usd_value: 500 },
                    { chain: 'polygon', balance: '100', usd_value: 100 }
                ],
                MATIC: [
                    { chain: 'polygon', balance: '1000', usd_value: 800 }
                ],
                USDT: [
                    { chain: 'polygon', balance: '200', usd_value: 200 }
                ],
                SOL: [
                    { chain: 'solana', balance: '20', usd_value: 1600 }
                ]
            };

            displayAssetsByToken(mockAssets);
            return;
        }

        const tokenAssets = result.assets || {};
        displayAssetsByToken(tokenAssets);
    } catch (error) {
        spinner.fail('Failed to fetch assets');
        console.error(chalk.red('Error:'), error.message);
        console.error(chalk.yellow('Stack trace:'), error.stack);

        // Generate mock assets for demonstration
        const mockAssets = {
            ETH: [
                { chain: 'ethereum', balance: '1.5', usd_value: 3000 }
            ],
            USDC: [
                { chain: 'ethereum', balance: '500', usd_value: 500 },
                { chain: 'polygon', balance: '100', usd_value: 100 }
            ],
            MATIC: [
                { chain: 'polygon', balance: '1000', usd_value: 800 }
            ],
            USDT: [
                { chain: 'polygon', balance: '200', usd_value: 200 }
            ],
            SOL: [
                { chain: 'solana', balance: '20', usd_value: 1600 }
            ]
        };

        console.log(chalk.yellow('\nShowing mock assets for demonstration:'));
        displayAssetsByToken(mockAssets);
    }
}

/**
 * Display assets organized by token
 */
function displayAssetsByToken(tokenAssets) {
    // Display assets by token
    console.log(chalk.cyan('\nAssets by Token:'));

    let totalUsdValue = 0;

    for (const [token, assets] of Object.entries(tokenAssets)) {
        if (assets.length === 0) continue;

        let tokenUsdValue = 0;
        let totalTokenBalance = 0;

        assets.forEach(asset => {
            tokenUsdValue += asset.usd_value;
            totalUsdValue += asset.usd_value;
            totalTokenBalance += parseFloat(asset.balance);
        });

        console.log(chalk.bold(`\n${token} (Total: ${totalTokenBalance} - $${tokenUsdValue.toFixed(2)})`));

        assets.forEach(asset => {
            console.log(`   ${formatChainName(asset.chain)}: ${asset.balance} - $${asset.usd_value.toFixed(2)}`);
        });
    }

    console.log(chalk.bold.green(`\nTotal Portfolio Value: $${totalUsdValue.toFixed(2)}`));
}

/**
 * View portfolio overview
 */
async function viewPortfolioOverview() {
    // Get portfolio overview
    const spinner = ora('Fetching portfolio data...').start();

    try {
        // Use enhanced bridge with proper command mapping
        const result = await juliaBridge.executeCommand('Bridge.get_portfolio_overview', [], {
            showSpinner: false,
            fallbackToMock: true
        });

        spinner.stop();

        if (!result || result.error) {
            console.log(chalk.yellow(`Warning: ${result?.error || 'Failed to fetch portfolio overview'}. Using mock data.`));

            // Generate mock portfolio for demonstration
            const mockPortfolio = {
                total_value: 6200,
                assets_by_chain: {
                    ethereum: 3500,
                    polygon: 1100,
                    solana: 1600
                },
                assets_by_token: {
                    ETH: 3000,
                    USDC: 600,
                    MATIC: 800,
                    USDT: 200,
                    SOL: 1600
                },
                assets_by_type: {
                    native: 5400,
                    stablecoin: 800
                },
                metrics: {
                    change_24h: 2.5,
                    change_7d: -1.2,
                    change_30d: 15.8,
                    volatility: 12.4
                }
            };

            displayPortfolioOverview(mockPortfolio);
            return;
        }

        const portfolio = result.portfolio || {};
        displayPortfolioOverview(portfolio);
    } catch (error) {
        spinner.fail('Failed to fetch portfolio overview');
        console.error(chalk.red('Error:'), error.message);
        console.error(chalk.yellow('Stack trace:'), error.stack);

        // Generate mock portfolio for demonstration
        const mockPortfolio = {
            total_value: 6200,
            assets_by_chain: {
                ethereum: 3500,
                polygon: 1100,
                solana: 1600
            },
            assets_by_token: {
                ETH: 3000,
                USDC: 600,
                MATIC: 800,
                USDT: 200,
                SOL: 1600
            },
            assets_by_type: {
                native: 5400,
                stablecoin: 800
            },
            metrics: {
                change_24h: 2.5,
                change_7d: -1.2,
                change_30d: 15.8,
                volatility: 12.4
            }
        };

        console.log(chalk.yellow('\nShowing mock portfolio for demonstration:'));
        displayPortfolioOverview(mockPortfolio);
    }
}

/**
 * Display portfolio overview
 */
function displayPortfolioOverview(portfolio) {
    // Display portfolio overview
    console.log(chalk.cyan('\nPortfolio Overview:'));
    console.log(chalk.bold.green(`\nTotal Portfolio Value: $${portfolio.total_value.toFixed(2)}`));

    // Display assets by chain
    console.log(chalk.bold('\nAssets by Chain:'));
    for (const [chain, value] of Object.entries(portfolio.assets_by_chain || {})) {
        const percentage = (value / portfolio.total_value * 100).toFixed(2);
        console.log(`   ${formatChainName(chain)}: $${value.toFixed(2)} (${percentage}%)`);
    }

    // Display assets by token
    console.log(chalk.bold('\nAssets by Token:'));
    for (const [token, value] of Object.entries(portfolio.assets_by_token || {})) {
        const percentage = (value / portfolio.total_value * 100).toFixed(2);
        console.log(`   ${token}: $${value.toFixed(2)} (${percentage}%)`);
    }

    // Display assets by type
    console.log(chalk.bold('\nAssets by Type:'));
    for (const [type, value] of Object.entries(portfolio.assets_by_type || {})) {
        const percentage = (value / portfolio.total_value * 100).toFixed(2);
        console.log(`   ${type.charAt(0).toUpperCase() + type.slice(1)}: $${value.toFixed(2)} (${percentage}%)`);
    }

    // Display portfolio metrics if available
    if (portfolio.metrics) {
        console.log(chalk.bold('\nPortfolio Metrics:'));
        console.log(`   24h Change: ${formatPercentageChange(portfolio.metrics.change_24h)}`);
        console.log(`   7d Change: ${formatPercentageChange(portfolio.metrics.change_7d)}`);
        console.log(`   30d Change: ${formatPercentageChange(portfolio.metrics.change_30d)}`);
        console.log(`   Volatility: ${portfolio.metrics.volatility.toFixed(2)}%`);
    }
}

/**
 * Format chain name for display
 */
function formatChainName(chain) {
    if (!chain) return 'Unknown';

    const chainNames = {
        ethereum: 'Ethereum',
        polygon: 'Polygon',
        solana: 'Solana',
        avalanche: 'Avalanche',
        bsc: 'Binance Smart Chain',
        arbitrum: 'Arbitrum',
        optimism: 'Optimism',
        fantom: 'Fantom'
    };

    return chainNames[chain.toLowerCase()] || chain;
}

/**
 * Format percentage change with color
 */
function formatPercentageChange(change) {
    if (change > 0) {
        return chalk.green(`+${change.toFixed(2)}%`);
    } else if (change < 0) {
        return chalk.red(`${change.toFixed(2)}%`);
    } else {
        return `${change.toFixed(2)}%`;
    }
}

/**
 * Generate a mock bridge status for demonstration purposes
 */
function generateMockBridgeStatus(protocol, identifier, sourceChain = 'ethereum') {
    // Generate random status
    const statuses = ['pending', 'confirmed', 'completed'];
    const status = statuses[Math.floor(Math.random() * statuses.length)];

    // Generate random timestamps
    const now = new Date();
    const initiated = new Date(now.getTime() - Math.floor(Math.random() * 3600000)); // Up to 1 hour ago
    const completed = status === 'completed' ? new Date(initiated.getTime() + Math.floor(Math.random() * 1800000)) : null; // Up to 30 minutes after initiated

    // Generate random transaction hashes
    const sourceTxHash = identifier.startsWith('0x') ? identifier : `0x${Math.random().toString(16).substring(2, 10)}${Math.random().toString(16).substring(2, 10)}`;
    const targetTxHash = status === 'completed' ? `0x${Math.random().toString(16).substring(2, 10)}${Math.random().toString(16).substring(2, 10)}` : null;

    // Determine target chain
    const targetChain = sourceChain === 'ethereum' ? 'solana' : 'ethereum';

    // Generate mock status object
    return {
        protocol,
        status,
        source_chain: sourceChain,
        target_chain: targetChain,
        token_symbol: 'USDC',
        amount: (Math.random() * 1000).toFixed(2),
        source_tx_hash: sourceTxHash,
        target_tx_hash: targetTxHash,
        initiated_at: initiated.toISOString(),
        completed_at: completed?.toISOString(),
        estimated_completion_time: status === 'pending' ? new Date(now.getTime() + 900000).toISOString() : null, // 15 minutes from now
        progress: status === 'pending' ? {
            current_step: 1,
            total_steps: 3,
            description: 'Waiting for source chain confirmation',
            percentage: 33
        } : (status === 'confirmed' ? {
            current_step: 2,
            total_steps: 3,
            description: 'Waiting for target chain confirmation',
            percentage: 66
        } : null),
        errors: [],
        warnings: status === 'pending' ? ['Transaction may take longer than usual due to network congestion'] : [],
        next_steps: status === 'pending' ? 'Wait for source chain confirmation' : (status === 'confirmed' ? 'Wait for target chain confirmation' : 'Transaction completed successfully')
    };
}

/**
 * Generate mock transactions for demonstration purposes
 */
function generateMockTransactions(count = 5, filters = {}) {
    const transactions = [];
    const protocols = ['wormhole', 'layerzero', 'axelar', 'synapse', 'across'];
    const sourceChains = ['ethereum', 'polygon', 'solana', 'avalanche', 'bsc'];
    const targetChains = ['ethereum', 'polygon', 'solana', 'avalanche', 'bsc'];
    const tokens = ['ETH', 'USDC', 'USDT', 'MATIC', 'SOL', 'AVAX', 'BNB'];
    const statuses = ['pending', 'confirmed', 'completed', 'failed'];
    const types = ['Bridge', 'Swap', 'Transfer'];

    // Apply filters
    const filteredSourceChains = filters.chain ? [filters.chain] : sourceChains;
    const filteredTokens = filters.token ? [filters.token.toUpperCase()] : tokens;
    const filteredStatuses = filters.status ? [filters.status] : statuses;

    // Generate random transactions
    for (let i = 0; i < count; i++) {
        // Generate random values
        const protocol = protocols[Math.floor(Math.random() * protocols.length)];
        const sourceChain = filteredSourceChains[Math.floor(Math.random() * filteredSourceChains.length)];
        let targetChain;
        do {
            targetChain = targetChains[Math.floor(Math.random() * targetChains.length)];
        } while (targetChain === sourceChain);

        const token = filteredTokens[Math.floor(Math.random() * filteredTokens.length)];
        const status = filteredStatuses[Math.floor(Math.random() * filteredStatuses.length)];
        const type = types[Math.floor(Math.random() * types.length)];

        // Generate random timestamps
        const now = new Date();
        const timestamp = new Date(now.getTime() - Math.floor(Math.random() * 604800000)); // Up to 1 week ago

        // Apply date filters if specified
        if (filters.start_date && filters.end_date) {
            const startDate = new Date(filters.start_date);
            const endDate = new Date(filters.end_date);
            if (timestamp < startDate || timestamp > endDate) {
                // Skip this transaction if it doesn't match the date filter
                i--;
                continue;
            }
        }

        // Generate random transaction hash
        const txHash = `0x${Math.random().toString(16).substring(2, 10)}${Math.random().toString(16).substring(2, 10)}`;

        // Generate random amount
        const amount = (Math.random() * 1000).toFixed(2);
        const usdValue = token === 'USDC' || token === 'USDT' ? parseFloat(amount) : parseFloat(amount) * (Math.random() * 1000 + 100);

        // Generate random fee
        const fee = {
            amount: (Math.random() * 10).toFixed(4),
            token: sourceChain === 'ethereum' ? 'ETH' : (sourceChain === 'polygon' ? 'MATIC' : (sourceChain === 'solana' ? 'SOL' : 'GAS')),
            usd_value: Math.random() * 50
        };

        // Create transaction object
        transactions.push({
            type,
            protocol,
            status,
            source_chain: sourceChain,
            target_chain: targetChain,
            token_symbol: token,
            amount,
            usd_value: usdValue,
            tx_hash: txHash,
            timestamp: timestamp.toISOString(),
            fee
        });
    }

    return transactions;
}

/**
 * View transaction history
 */
async function viewTransactionHistory() {
    try {
        console.log(chalk.cyan('\nTransaction History'));

        // Check if the Julia backend is connected
        const isConnected = await juliaBridge.checkConnection();
        if (!isConnected) {
            console.log(chalk.yellow('\nWarning: Not connected to Julia backend. Using mock implementations.'));
        }

        // Prompt for filter options
        const { filterType } = await inquirer.prompt([
            {
                type: 'list',
                name: 'filterType',
                message: 'Filter transactions by:',
                choices: [
                    { name: 'All Transactions', value: 'all' },
                    { name: 'By Chain', value: 'chain' },
                    { name: 'By Token', value: 'token' },
                    { name: 'By Status', value: 'status' },
                    { name: 'By Date Range', value: 'date' }
                ]
            }
        ]);

        let filters = {};

        if (filterType === 'chain') {
            // Get available chains
            const spinner = ora('Fetching available chains...').start();

            let chainsResult;
            try {
                chainsResult = await juliaBridge.executeCommand('get_available_chains', {}, {
                    showSpinner: false,
                    fallbackToMock: true
                });
                spinner.stop();
            } catch (error) {
                spinner.fail('Failed to fetch chains');
                console.error(chalk.yellow('Using default chain list...'));
            }

            // Format chains for display
            const chains = chainsResult?.chains?.map(chain => ({
                name: chain.name || formatChainName(chain.id),
                value: chain.id || chain.value
            })) || [
                { name: 'Ethereum', value: 'ethereum' },
                { name: 'Polygon', value: 'polygon' },
                { name: 'Solana', value: 'solana' },
                { name: 'Avalanche', value: 'avalanche' },
                { name: 'Binance Smart Chain', value: 'bsc' }
            ];

            const { chain } = await inquirer.prompt([
                {
                    type: 'list',
                    name: 'chain',
                    message: 'Select chain:',
                    choices: chains
                }
            ]);

            filters.chain = chain;
        } else if (filterType === 'token') {
            // Get available tokens
            const spinner = ora('Fetching available tokens...').start();

            let tokensResult;
            try {
                tokensResult = await juliaBridge.executeCommand('get_available_tokens', { chain: 'ethereum' }, {
                    showSpinner: false,
                    fallbackToMock: true
                });
                spinner.stop();
            } catch (error) {
                spinner.fail('Failed to fetch tokens');
                console.error(chalk.yellow('Using default token list...'));
            }

            // Format tokens for display
            const tokens = tokensResult?.tokens?.map(token => ({
                name: token.symbol,
                value: token.symbol.toLowerCase()
            })) || [
                { name: 'ETH', value: 'eth' },
                { name: 'USDC', value: 'usdc' },
                { name: 'USDT', value: 'usdt' },
                { name: 'MATIC', value: 'matic' },
                { name: 'SOL', value: 'sol' }
            ];

            const { token } = await inquirer.prompt([
                {
                    type: 'list',
                    name: 'token',
                    message: 'Select token:',
                    choices: tokens
                }
            ]);

            filters.token = token;
        } else if (filterType === 'status') {
            const { status } = await inquirer.prompt([
                {
                    type: 'list',
                    name: 'status',
                    message: 'Select status:',
                    choices: [
                        { name: 'Completed', value: 'completed' },
                        { name: 'Pending', value: 'pending' },
                        { name: 'Failed', value: 'failed' }
                    ]
                }
            ]);

            filters.status = status;
        } else if (filterType === 'date') {
            const { startDate, endDate } = await inquirer.prompt([
                {
                    type: 'input',
                    name: 'startDate',
                    message: 'Enter start date (YYYY-MM-DD):',
                    validate: input => {
                        const regex = /^\d{4}-\d{2}-\d{2}$/;
                        return regex.test(input) ? true : 'Please enter a valid date in YYYY-MM-DD format';
                    }
                },
                {
                    type: 'input',
                    name: 'endDate',
                    message: 'Enter end date (YYYY-MM-DD):',
                    validate: input => {
                        const regex = /^\d{4}-\d{2}-\d{2}$/;
                        return regex.test(input) ? true : 'Please enter a valid date in YYYY-MM-DD format';
                    }
                }
            ]);

            filters.start_date = startDate;
            filters.end_date = endDate;
        }

        // Prompt for limit
        const { limit } = await inquirer.prompt([
            {
                type: 'number',
                name: 'limit',
                message: 'Number of transactions to display:',
                default: 10,
                validate: input => input > 0 ? true : 'Number must be positive'
            }
        ]);

        filters.limit = limit;

        // Fetch transaction history
        const spinner = ora('Fetching transaction history...').start();

        try {
            // Use enhanced bridge with proper command mapping
            const result = await juliaBridge.executeCommand('Bridge.get_transaction_history', [filters], {
                showSpinner: false,
                fallbackToMock: true
            });

            spinner.stop();

            if (!result || result.error) {
                console.log(chalk.yellow(`Warning: ${result?.error || 'Failed to fetch transaction history'}. Using mock data.`));

                // Generate mock transactions for demonstration
                const mockTransactions = generateMockTransactions(limit, filters);
                displayTransactionHistory(mockTransactions);
                return;
            }

            const transactions = result.transactions || [];

            if (transactions.length === 0) {
                console.log(chalk.yellow('\nNo transactions found matching the specified filters.'));
                return;
            }

            displayTransactionHistory(transactions);
        } catch (error) {
            spinner.fail('Failed to fetch transaction history');
            console.error(chalk.red('Error:'), error.message);
            console.error(chalk.yellow('Stack trace:'), error.stack);

            // Generate mock transactions for demonstration
            const mockTransactions = generateMockTransactions(limit, filters);
            console.log(chalk.yellow('\nShowing mock transactions for demonstration:'));
            displayTransactionHistory(mockTransactions);
        }
    } catch (error) {
        console.error(chalk.red('Error:'), error.message);
        console.error(chalk.yellow('Stack trace:'), error.stack);
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * Display transaction history
 */
function displayTransactionHistory(transactions) {
    // Display transaction history
    console.log(chalk.cyan(`\nTransaction History (${transactions.length} transactions):`));

    transactions.forEach((tx, index) => {
        const statusColor = getStatusColor(tx.status);

        console.log(chalk.bold(`\n${index + 1}. ${tx.type || 'Bridge'} - ${formatDate(tx.timestamp || tx.initiated_at)}`));
        console.log(`   From: ${formatChainName(tx.source_chain)}`);

        if (tx.target_chain) {
            console.log(`   To: ${formatChainName(tx.target_chain)}`);
        }

        console.log(`   Token: ${tx.token_symbol}`);
        console.log(`   Amount: ${tx.amount} ${tx.token_symbol}`);
        console.log(`   Status: ${statusColor(tx.status)}`);
        console.log(`   Transaction Hash: ${tx.tx_hash || tx.source_tx_hash}`);

        if (tx.fee) {
            console.log(`   Fee: ${tx.fee.amount} ${tx.fee.token} ($${tx.fee.usd_value.toFixed(2)})`);
        }

        if (tx.usd_value) {
            console.log(`   USD Value: $${tx.usd_value.toFixed(2)}`);
        }
    });

    // Prompt to view transaction details
    inquirer.prompt([
        {
            type: 'confirm',
            name: 'viewDetails',
            message: 'Would you like to view details of a specific transaction?',
            default: false
        }
    ]).then(({ viewDetails }) => {
        if (viewDetails) {
            inquirer.prompt([
                {
                    type: 'number',
                    name: 'txIndex',
                    message: 'Enter the number of the transaction:',
                    validate: input => input > 0 && input <= transactions.length ? true : `Please enter a number between 1 and ${transactions.length}`
                }
            ]).then(({ txIndex }) => {
                const selectedTx = transactions[txIndex - 1];
                viewTransactionDetails(selectedTx.tx_hash || selectedTx.source_tx_hash, selectedTx.source_chain);
            });
        }
    });
}

/**
 * View details of a specific transaction
 */
async function viewTransactionDetails(txHash, chain) {
    const spinner = ora(`Fetching details for transaction ${txHash}...`).start();

    try {
        // Use enhanced bridge with proper command mapping
        const result = await juliaBridge.executeCommand('Bridge.get_transaction_details', [txHash, chain], {
            showSpinner: false,
            fallbackToMock: true
        });

        spinner.stop();

        if (!result || result.error) {
            console.log(chalk.yellow(`Warning: ${result?.error || 'Failed to fetch transaction details'}. Using mock data.`));

            // Generate mock transaction details for demonstration
            const mockTx = generateMockTransactionDetails(txHash, chain);
            displayTransactionDetails(mockTx);
            return;
        }

        const tx = result.transaction;
        displayTransactionDetails(tx);
    } catch (error) {
        spinner.fail('Failed to fetch transaction details');
        console.error(chalk.red('Error:'), error.message);
        console.error(chalk.yellow('Stack trace:'), error.stack);

        // Generate mock transaction details for demonstration
        const mockTx = generateMockTransactionDetails(txHash, chain);
        console.log(chalk.yellow('\nShowing mock transaction details for demonstration:'));
        displayTransactionDetails(mockTx);
    }
}

/**
 * Display transaction details
 */
function displayTransactionDetails(tx) {
    console.log(chalk.cyan('\nTransaction Details:'));

    // Basic information
    console.log(chalk.bold('\nBasic Information:'));
    console.log(`Type: ${tx.type || 'Bridge'}`);
    console.log(`Status: ${getStatusColor(tx.status)(tx.status)}`);
    console.log(`Timestamp: ${formatDate(tx.timestamp || tx.initiated_at)}`);

    // Chain information
    console.log(chalk.bold('\nChain Information:'));
    console.log(`Source Chain: ${formatChainName(tx.source_chain)}`);

    if (tx.target_chain) {
        console.log(`Target Chain: ${formatChainName(tx.target_chain)}`);
    }

    // Token information
    console.log(chalk.bold('\nToken Information:'));
    console.log(`Token: ${tx.token_symbol} ${tx.token_name ? `(${tx.token_name})` : ''}`);
    console.log(`Amount: ${tx.amount} ${tx.token_symbol}`);

    if (tx.usd_value) {
        console.log(`USD Value: $${tx.usd_value.toFixed(2)}`);
    }

    // Transaction details
    console.log(chalk.bold('\nTransaction Details:'));
    console.log(`Source Transaction Hash: ${tx.tx_hash || tx.source_tx_hash}`);

    if (tx.target_tx_hash) {
        console.log(`Target Transaction Hash: ${tx.target_tx_hash}`);
    }

    if (tx.from_address) {
        console.log(`From Address: ${tx.from_address}`);
    }

    if (tx.to_address) {
        console.log(`To Address: ${tx.to_address}`);
    }

    // Fee information
    if (tx.fee) {
        console.log(chalk.bold('\nFee Information:'));
        console.log(`Fee Amount: ${tx.fee.amount} ${tx.fee.token}`);
        console.log(`Fee USD Value: $${tx.fee.usd_value.toFixed(2)}`);

        if (tx.fee.gas_used) {
            console.log(`Gas Used: ${tx.fee.gas_used}`);
        }

        if (tx.fee.gas_price) {
            console.log(`Gas Price: ${tx.fee.gas_price}`);
        }
    }

    // Bridge information (if applicable)
    if (tx.bridge_info) {
        console.log(chalk.bold('\nBridge Information:'));
        console.log(`Bridge Protocol: ${tx.bridge_info.protocol}`);
        console.log(`Tracking ID: ${tx.bridge_info.tracking_id || tx.bridge_info.attestation || 'N/A'}`);

        if (tx.bridge_info.estimated_time) {
            console.log(`Estimated Completion Time: ${tx.bridge_info.estimated_time}`);
        }

        if (tx.bridge_info.progress) {
            console.log(`Progress: ${tx.bridge_info.progress.current_step} of ${tx.bridge_info.progress.total_steps} (${tx.bridge_info.progress.percentage}%)`);
            console.log(`Current Step: ${tx.bridge_info.progress.description}`);
        }
    } else if (tx.progress) {
        // Handle case where progress is at the top level
        console.log(chalk.bold('\nBridge Information:'));
        console.log(`Bridge Protocol: ${tx.protocol || 'Unknown'}`);
        console.log(`Tracking ID: ${tx.tracking_id || tx.attestation || 'N/A'}`);

        if (tx.estimated_completion_time) {
            console.log(`Estimated Completion Time: ${tx.estimated_completion_time}`);
        }

        console.log(`Progress: ${tx.progress.current_step} of ${tx.progress.total_steps} (${tx.progress.percentage}%)`);
        console.log(`Current Step: ${tx.progress.description}`);
    }

    // Additional information
    if (tx.additional_info && Object.keys(tx.additional_info).length > 0) {
        console.log(chalk.bold('\nAdditional Information:'));

        for (const [key, value] of Object.entries(tx.additional_info)) {
            console.log(`${key}: ${value}`);
        }
    }

    // Explorer links
    if (tx.explorer_links && tx.explorer_links.length > 0) {
        console.log(chalk.bold('\nExplorer Links:'));

        tx.explorer_links.forEach(link => {
            console.log(`${link.name}: ${link.url}`);
        });
    }
}

/**
 * Generate mock transaction details for demonstration purposes
 */
function generateMockTransactionDetails(txHash, chain) {
    // Generate random values
    const protocols = ['wormhole', 'layerzero', 'axelar', 'synapse', 'across'];
    const protocol = protocols[Math.floor(Math.random() * protocols.length)];

    const statuses = ['pending', 'confirmed', 'completed'];
    const status = statuses[Math.floor(Math.random() * statuses.length)];

    const tokens = ['ETH', 'USDC', 'USDT', 'MATIC', 'SOL', 'AVAX', 'BNB'];
    const token = tokens[Math.floor(Math.random() * tokens.length)];

    const tokenNames = {
        'ETH': 'Ethereum',
        'USDC': 'USD Coin',
        'USDT': 'Tether USD',
        'MATIC': 'Polygon',
        'SOL': 'Solana',
        'AVAX': 'Avalanche',
        'BNB': 'Binance Coin'
    };

    // Generate random timestamps
    const now = new Date();
    const timestamp = new Date(now.getTime() - Math.floor(Math.random() * 604800000)); // Up to 1 week ago

    // Determine target chain
    const targetChain = chain === 'ethereum' ? 'solana' : 'ethereum';

    // Generate random addresses
    const fromAddress = `0x${Math.random().toString(16).substring(2, 42)}`;
    const toAddress = `0x${Math.random().toString(16).substring(2, 42)}`;

    // Generate random amount
    const amount = (Math.random() * 1000).toFixed(2);
    const usdValue = token === 'USDC' || token === 'USDT' ? parseFloat(amount) : parseFloat(amount) * (Math.random() * 1000 + 100);

    // Generate random fee
    const fee = {
        amount: (Math.random() * 10).toFixed(4),
        token: chain === 'ethereum' ? 'ETH' : (chain === 'polygon' ? 'MATIC' : (chain === 'solana' ? 'SOL' : 'GAS')),
        usd_value: Math.random() * 50,
        gas_used: Math.floor(Math.random() * 1000000),
        gas_price: `${(Math.random() * 100).toFixed(2)} Gwei`
    };

    // Generate bridge information
    const bridgeInfo = {
        protocol,
        tracking_id: `0x${Math.random().toString(16).substring(2, 66)}`,
        estimated_time: status === 'pending' ? new Date(now.getTime() + 900000).toISOString() : null,
        progress: status === 'pending' ? {
            current_step: 1,
            total_steps: 3,
            description: 'Waiting for source chain confirmation',
            percentage: 33
        } : (status === 'confirmed' ? {
            current_step: 2,
            total_steps: 3,
            description: 'Waiting for target chain confirmation',
            percentage: 66
        } : null)
    };

    // Generate explorer links
    const explorerLinks = [
        {
            name: `${formatChainName(chain)} Explorer`,
            url: `https://${chain === 'ethereum' ? 'etherscan.io' : (chain === 'polygon' ? 'polygonscan.com' : 'explorer.solana.com')}/tx/${txHash}`
        }
    ];

    if (status === 'completed') {
        explorerLinks.push({
            name: `${formatChainName(targetChain)} Explorer`,
            url: `https://${targetChain === 'ethereum' ? 'etherscan.io' : (targetChain === 'polygon' ? 'polygonscan.com' : 'explorer.solana.com')}/tx/0x${Math.random().toString(16).substring(2, 66)}`
        });
    }

    // Generate additional information
    const additionalInfo = {
        'Network Fee': `${(Math.random() * 10).toFixed(2)} Gwei`,
        'Confirmation Blocks': Math.floor(Math.random() * 50),
        'Bridge Fee': `${(Math.random() * 0.5).toFixed(2)}%`
    };

    // Create transaction object
    return {
        type: 'Bridge',
        status,
        timestamp: timestamp.toISOString(),
        source_chain: chain,
        target_chain: targetChain,
        token_symbol: token,
        token_name: tokenNames[token],
        amount,
        usd_value,
        tx_hash: txHash,
        target_tx_hash: status === 'completed' ? `0x${Math.random().toString(16).substring(2, 66)}` : null,
        from_address: fromAddress,
        to_address: toAddress,
        fee,
        bridge_info: bridgeInfo,
        explorer_links: explorerLinks,
        additional_info: additionalInfo
    };
}

/**
 * Format date for display
 */
function formatDate(timestamp) {
    const date = new Date(timestamp);
    return date.toLocaleString();
}

/**
 * Get status color function
 */
function getStatusColor(status) {
    switch (status.toLowerCase()) {
        case 'pending':
        case 'in_progress':
            return chalk.yellow;
        case 'completed':
        case 'success':
            return chalk.green;
        case 'failed':
        case 'error':
            return chalk.red;
        default:
            return chalk.white;
    }
}

/**
 * Configure bridge settings
 */
async function configureBridgeSettings() {
    try {
        console.log(chalk.cyan('\nBridge Settings'));

        // Check if the Julia backend is connected
        const isConnected = await juliaBridge.checkConnection();
        if (!isConnected) {
            console.log(chalk.yellow('\nWarning: Not connected to Julia backend. Using mock implementations.'));
        }

        // Get current settings
        const spinner = ora('Fetching current bridge settings...').start();

        try {
            // Use enhanced bridge with proper command mapping
            const result = await juliaBridge.executeCommand('Bridge.get_bridge_settings', [], {
                showSpinner: false,
                fallbackToMock: true
            });

            spinner.stop();

            if (!result || result.error) {
                console.log(chalk.yellow(`Warning: ${result?.error || 'Failed to fetch bridge settings'}. Using default settings.`));

                // Use default settings for demonstration
                const defaultSettings = {
                    default_protocol: 'wormhole',
                    gas_settings: {
                        ethereum: {
                            gas_price_strategy: 'medium',
                            max_gas_price: 100
                        },
                        polygon: {
                            gas_price_strategy: 'medium',
                            max_gas_price: 300
                        }
                    },
                    slippage_tolerance: 0.5,
                    auto_approve: false,
                    preferred_chains: ['ethereum', 'polygon', 'solana'],
                    preferred_tokens: ['usdc', 'eth', 'sol'],
                    security: {
                        require_confirmation: true,
                        max_transaction_value: 1000
                    }
                };

                displayBridgeSettings(defaultSettings);
                await configureBridgeSettingsMenu(defaultSettings);
                return;
            }

            const settings = result.settings || {};
            displayBridgeSettings(settings);
            await configureBridgeSettingsMenu(settings);
        } catch (error) {
            spinner.fail('Failed to fetch bridge settings');
            console.error(chalk.red('Error:'), error.message);
            console.error(chalk.yellow('Stack trace:'), error.stack);

            // Use default settings for demonstration
            const defaultSettings = {
                default_protocol: 'wormhole',
                gas_settings: {
                    ethereum: {
                        gas_price_strategy: 'medium',
                        max_gas_price: 100
                    },
                    polygon: {
                        gas_price_strategy: 'medium',
                        max_gas_price: 300
                    }
                },
                slippage_tolerance: 0.5,
                auto_approve: false,
                preferred_chains: ['ethereum', 'polygon', 'solana'],
                preferred_tokens: ['usdc', 'eth', 'sol'],
                security: {
                    require_confirmation: true,
                    max_transaction_value: 1000
                }
            };

            console.log(chalk.yellow('\nShowing default settings for demonstration:'));
            displayBridgeSettings(defaultSettings);
            await configureBridgeSettingsMenu(defaultSettings);
        }
    } catch (error) {
        console.error(chalk.red('Error:'), error.message);
        console.error(chalk.yellow('Stack trace:'), error.stack);
    }

    await inquirer.prompt([{type: 'input', name: 'continue', message: 'Press Enter to continue...'}]);
}

/**
 * Display bridge settings
 */
function displayBridgeSettings(settings) {
    // Display current settings
    console.log(chalk.cyan('\nCurrent Bridge Settings:'));

    console.log(chalk.bold('\nGeneral Settings:'));
    console.log(`Default Protocol: ${settings.default_protocol || 'Not set'}`);
    console.log(`Slippage Tolerance: ${settings.slippage_tolerance || 0}%`);
    console.log(`Auto Approve: ${settings.auto_approve ? 'Enabled' : 'Disabled'}`);

    console.log(chalk.bold('\nPreferred Chains:'));
    if (settings.preferred_chains && Array.isArray(settings.preferred_chains)) {
        settings.preferred_chains.forEach(chain => {
            console.log(`- ${formatChainName(chain)}`);
        });
    } else {
        console.log('No preferred chains set');
    }

    console.log(chalk.bold('\nPreferred Tokens:'));
    if (settings.preferred_tokens && Array.isArray(settings.preferred_tokens)) {
        settings.preferred_tokens.forEach(token => {
            console.log(`- ${token.toUpperCase()}`);
        });
    } else {
        console.log('No preferred tokens set');
    }

    console.log(chalk.bold('\nGas Settings:'));
    if (settings.gas_settings && typeof settings.gas_settings === 'object') {
        for (const [chain, gasSettings] of Object.entries(settings.gas_settings)) {
            console.log(`${formatChainName(chain)}:`);
            console.log(`  - Gas Price Strategy: ${gasSettings.gas_price_strategy}`);
            console.log(`  - Max Gas Price: ${gasSettings.max_gas_price} Gwei`);
        }
    } else {
        console.log('No gas settings configured');
    }

    console.log(chalk.bold('\nSecurity Settings:'));
    if (settings.security && typeof settings.security === 'object') {
        console.log(`Require Confirmation: ${settings.security.require_confirmation ? 'Yes' : 'No'}`);
        console.log(`Max Transaction Value: $${settings.security.max_transaction_value}`);
    } else {
        console.log('No security settings configured');
    }
}

/**
 * Configure bridge settings menu
 */
async function configureBridgeSettingsMenu(settings) {
    // Prompt for what to configure
    const { configOption } = await inquirer.prompt([
        {
            type: 'list',
            name: 'configOption',
            message: 'What would you like to configure?',
            choices: [
                { name: 'General Settings', value: 'general' },
                { name: 'Gas Settings', value: 'gas' },
                { name: 'Preferred Chains', value: 'chains' },
                { name: 'Preferred Tokens', value: 'tokens' },
                { name: 'Security Settings', value: 'security' },
                { name: 'Reset to Default', value: 'reset' },
                { name: 'Cancel', value: 'cancel' }
            ]
        }
    ]);

    if (configOption === 'cancel') {
        return;
    }

    let updatedSettings = { ...settings };

    switch (configOption) {
        case 'general':
            await configureGeneralSettings(updatedSettings);
            break;
        case 'gas':
            await configureGasSettings(updatedSettings);
            break;
        case 'chains':
            await configurePreferredChains(updatedSettings);
            break;
        case 'tokens':
            await configurePreferredTokens(updatedSettings);
            break;
        case 'security':
            await configureSecuritySettings(updatedSettings);
            break;
        case 'reset':
            await resetBridgeSettings();
            return;
    }
}

/**
 * Configure general bridge settings
 */
async function configureGeneralSettings(currentSettings) {
    try {
        // Prompt for general settings
        const { defaultProtocol, slippageTolerance, autoApprove } = await inquirer.prompt([
            {
                type: 'list',
                name: 'defaultProtocol',
                message: 'Select default bridge protocol:',
                choices: [
                    { name: 'Wormhole', value: 'wormhole' },
                    { name: 'LayerZero', value: 'layerzero' },
                    { name: 'Axelar', value: 'axelar' },
                    { name: 'Synapse', value: 'synapse' },
                    { name: 'Across', value: 'across' }
                ],
                default: currentSettings.default_protocol
            },
            {
                type: 'number',
                name: 'slippageTolerance',
                message: 'Enter slippage tolerance (%):',
                default: currentSettings.slippage_tolerance,
                validate: input => input >= 0 && input <= 100 ? true : 'Slippage tolerance must be between 0 and 100'
            },
            {
                type: 'confirm',
                name: 'autoApprove',
                message: 'Enable auto approve for token transfers?',
                default: currentSettings.auto_approve
            }
        ]);

        // Update settings
        const updatedSettings = {
            ...currentSettings,
            default_protocol: defaultProtocol,
            slippage_tolerance: slippageTolerance,
            auto_approve: autoApprove
        };

        // Save settings
        await saveBridgeSettings(updatedSettings);
    } catch (error) {
        console.error(chalk.red('Error:'), error.message);
        console.error(chalk.yellow('Stack trace:'), error.stack);
    }
}

/**
 * Configure gas settings
 */
async function configureGasSettings(currentSettings) {
    try {
        // Prompt for chain to configure
        const { chain } = await inquirer.prompt([
            {
                type: 'list',
                name: 'chain',
                message: 'Select chain to configure gas settings:',
                choices: [
                    { name: 'Ethereum', value: 'ethereum' },
                    { name: 'Polygon', value: 'polygon' },
                    { name: 'Avalanche', value: 'avalanche' },
                    { name: 'Binance Smart Chain', value: 'bsc' }
                ]
            }
        ]);

        // Get current gas settings for the selected chain
        const currentGasSettings = currentSettings.gas_settings[chain] || {
            gas_price_strategy: 'medium',
            max_gas_price: 100
        };

        // Prompt for gas settings
        const { gasPriceStrategy, maxGasPrice } = await inquirer.prompt([
            {
                type: 'list',
                name: 'gasPriceStrategy',
                message: 'Select gas price strategy:',
                choices: [
                    { name: 'Low', value: 'low' },
                    { name: 'Medium', value: 'medium' },
                    { name: 'High', value: 'high' },
                    { name: 'Custom', value: 'custom' }
                ],
                default: currentGasSettings.gas_price_strategy
            },
            {
                type: 'number',
                name: 'maxGasPrice',
                message: 'Enter maximum gas price (Gwei):',
                default: currentGasSettings.max_gas_price,
                validate: input => input > 0 ? true : 'Maximum gas price must be positive'
            }
        ]);

        // Update settings
        const updatedSettings = {
            ...currentSettings,
            gas_settings: {
                ...currentSettings.gas_settings,
                [chain]: {
                    gas_price_strategy: gasPriceStrategy,
                    max_gas_price: maxGasPrice
                }
            }
        };

        // Save settings
        await saveBridgeSettings(updatedSettings);
    } catch (error) {
        console.error(chalk.red('Error:'), error.message);
        console.error(chalk.yellow('Stack trace:'), error.stack);
    }
}

/**
 * Configure preferred chains
 */
async function configurePreferredChains(currentSettings) {
    try {
        // Get available chains
        const spinner = ora('Fetching available chains...').start();

        let chainsResult;
        try {
            chainsResult = await juliaBridge.executeCommand('get_available_chains', {}, {
                showSpinner: false,
                fallbackToMock: true
            });
            spinner.stop();
        } catch (error) {
            spinner.fail('Failed to fetch chains');
            console.error(chalk.yellow('Using default chain list...'));
        }

        // Format chains for display or use default list
        const availableChains = chainsResult?.chains?.map(chain => ({
            name: chain.name || formatChainName(chain.id),
            value: chain.id || chain.value
        })) || [
            { name: 'Ethereum', value: 'ethereum' },
            { name: 'Polygon', value: 'polygon' },
            { name: 'Solana', value: 'solana' },
            { name: 'Avalanche', value: 'avalanche' },
            { name: 'Binance Smart Chain', value: 'bsc' },
            { name: 'Arbitrum', value: 'arbitrum' },
            { name: 'Optimism', value: 'optimism' },
            { name: 'Fantom', value: 'fantom' }
        ];

        // Prompt for preferred chains
        const { preferredChains } = await inquirer.prompt([
            {
                type: 'checkbox',
                name: 'preferredChains',
                message: 'Select preferred chains:',
                choices: availableChains,
                default: currentSettings.preferred_chains
            }
        ]);

        // Update settings
        const updatedSettings = {
            ...currentSettings,
            preferred_chains: preferredChains
        };

        // Save settings
        await saveBridgeSettings(updatedSettings);
    } catch (error) {
        console.error(chalk.red('Error:'), error.message);
        console.error(chalk.yellow('Stack trace:'), error.stack);
    }
}

/**
 * Configure preferred tokens
 */
async function configurePreferredTokens(currentSettings) {
    try {
        // Get available tokens
        const spinner = ora('Fetching available tokens...').start();

        let tokensResult;
        try {
            tokensResult = await juliaBridge.executeCommand('get_available_tokens', { chain: 'ethereum' }, {
                showSpinner: false,
                fallbackToMock: true
            });
            spinner.stop();
        } catch (error) {
            spinner.fail('Failed to fetch tokens');
            console.error(chalk.yellow('Using default token list...'));
        }

        // Format tokens for display or use default list
        const availableTokens = tokensResult?.tokens?.map(token => ({
            name: token.symbol,
            value: token.symbol.toLowerCase()
        })) || [
            { name: 'USDC', value: 'usdc' },
            { name: 'USDT', value: 'usdt' },
            { name: 'ETH', value: 'eth' },
            { name: 'MATIC', value: 'matic' },
            { name: 'SOL', value: 'sol' },
            { name: 'AVAX', value: 'avax' },
            { name: 'BNB', value: 'bnb' },
            { name: 'DAI', value: 'dai' }
        ];

        // Prompt for preferred tokens
        const { preferredTokens } = await inquirer.prompt([
            {
                type: 'checkbox',
                name: 'preferredTokens',
                message: 'Select preferred tokens:',
                choices: availableTokens,
                default: currentSettings.preferred_tokens
            }
        ]);

        // Update settings
        const updatedSettings = {
            ...currentSettings,
            preferred_tokens: preferredTokens
        };

        // Save settings
        await saveBridgeSettings(updatedSettings);
    } catch (error) {
        console.error(chalk.red('Error:'), error.message);
        console.error(chalk.yellow('Stack trace:'), error.stack);
    }
}

/**
 * Configure security settings
 */
async function configureSecuritySettings(currentSettings) {
    try {
        // Prompt for security settings
        const { requireConfirmation, maxTransactionValue } = await inquirer.prompt([
            {
                type: 'confirm',
                name: 'requireConfirmation',
                message: 'Require confirmation for all bridge transactions?',
                default: currentSettings.security.require_confirmation
            },
            {
                type: 'number',
                name: 'maxTransactionValue',
                message: 'Enter maximum transaction value ($):',
                default: currentSettings.security.max_transaction_value,
                validate: input => input > 0 ? true : 'Maximum transaction value must be positive'
            }
        ]);

        // Update settings
        const updatedSettings = {
            ...currentSettings,
            security: {
                require_confirmation: requireConfirmation,
                max_transaction_value: maxTransactionValue
            }
        };

        // Save settings
        await saveBridgeSettings(updatedSettings);
    } catch (error) {
        console.error(chalk.red('Error:'), error.message);
        console.error(chalk.yellow('Stack trace:'), error.stack);
    }
}

/**
 * Reset bridge settings to default
 */
async function resetBridgeSettings() {
    try {
        // Confirm reset
        const { confirmReset } = await inquirer.prompt([
            {
                type: 'confirm',
                name: 'confirmReset',
                message: 'Are you sure you want to reset all bridge settings to default? This action cannot be undone.',
                default: false
            }
        ]);

        if (!confirmReset) {
            console.log(chalk.yellow('Reset cancelled.'));
            return;
        }

        // Reset settings
        const spinner = ora('Resetting bridge settings...').start();

        try {
            // Use enhanced bridge with proper command mapping
            const result = await juliaBridge.executeCommand('Bridge.reset_bridge_settings', [], {
                showSpinner: false,
                fallbackToMock: true
            });

            spinner.stop();

            if (!result || result.error) {
                console.log(chalk.yellow(`Warning: ${result?.error || 'Failed to reset bridge settings'}. Using mock implementation.`));
                console.log(chalk.green('\nBridge settings reset to default for this session!'));
                return;
            }

            console.log(chalk.green('\nBridge settings reset to default successfully!'));
        } catch (error) {
            spinner.fail('Failed to reset bridge settings');
            console.error(chalk.red('Error:'), error.message);
            console.error(chalk.yellow('Stack trace:'), error.stack);
            console.log(chalk.yellow('\nSettings will be reset for this session only.'));
        }
    } catch (error) {
        console.error(chalk.red('Error:'), error.message);
        console.error(chalk.yellow('Stack trace:'), error.stack);
    }
}

/**
 * Save bridge settings
 */
async function saveBridgeSettings(settings) {
    const spinner = ora('Saving bridge settings...').start();

    try {
        // Use enhanced bridge with proper command mapping
        const result = await juliaBridge.executeCommand('Bridge.update_bridge_settings', [settings], {
            showSpinner: false,
            fallbackToMock: true
        });

        spinner.stop();

        if (!result || result.error) {
            console.log(chalk.yellow(`Warning: ${result?.error || 'Failed to save bridge settings'}. Settings will be applied for this session only.`));
            console.log(chalk.green('\nBridge settings updated for this session!'));
            return;
        }

        console.log(chalk.green('\nBridge settings saved successfully!'));
    } catch (error) {
        spinner.fail('Failed to save bridge settings');
        console.error(chalk.red('Error:'), error.message);
        console.error(chalk.yellow('Stack trace:'), error.stack);
        console.log(chalk.yellow('\nSettings will be applied for this session only.'));
    }
}

/**
 * Format chain name for display
 */
function formatChainName(chain) {
    if (!chain) return 'Unknown';

    const chainNames = {
        'ethereum': 'Ethereum',
        'eth': 'Ethereum',
        'polygon': 'Polygon',
        'matic': 'Polygon',
        'solana': 'Solana',
        'sol': 'Solana',
        'avalanche': 'Avalanche',
        'avax': 'Avalanche',
        'bsc': 'Binance Smart Chain',
        'binance': 'Binance Smart Chain',
        'arbitrum': 'Arbitrum',
        'optimism': 'Optimism',
        'fantom': 'Fantom',
        'ftm': 'Fantom'
    };

    return chainNames[chain.toLowerCase()] || chain;
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
        crossChainHubMenu,
        bridgeTokens,
        checkBridgeStatus,
        redeemPendingTokens,
        viewCrossChainAssets,
        viewTransactionHistory,
        configureBridgeSettings
    };
};
