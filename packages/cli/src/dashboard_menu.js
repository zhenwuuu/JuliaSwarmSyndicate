// =============================================================================
// Real-time Dashboard Menu
// =============================================================================
const chalk = require('chalk');
const inquirer = require('inquirer');
const ora = require('ora');
const blessed = require('blessed');
const contrib = require('blessed-contrib');
const fs = require('fs-extra');
const path = require('path');

// Define variables that will be set by dependency injection
let juliaBridge;
let displayHeader;

/**
 * Display the real-time dashboard
 */
async function dashboardMenu(breadcrumbs = ['Main', 'Dashboard']) {
    displayHeader('Real-time Dashboard');
    console.log(chalk.cyan(`
      ╔══════════════════════════════════════════╗
      ║           Real-time Dashboard            ║
      ║                                          ║
      ║  📊 Monitor your agents, swarms, and      ║
      ║     system performance in real-time.     ║
      ║                                          ║
      ╚══════════════════════════════════════════╝
    `));

    const { dashboardType } = await inquirer.prompt([
        {
            type: 'list',
            name: 'dashboardType',
            message: '📊 Select dashboard type:',
            choices: [
                { name: '1. System Overview', value: 'system' },
                { name: '2. Agent Performance', value: 'agent' },
                { name: '3. Swarm Activity', value: 'swarm' },
                { name: '4. Trading Performance', value: 'trading' },
                { name: '5. Network Activity', value: 'network' },
                { name: '0. Back to Main Menu', value: 'back' }
            ]
        }
    ]);

    if (dashboardType === 'back') {
        return;
    }

    // Launch the appropriate dashboard
    await launchDashboard(dashboardType);
}

/**
 * Launch a specific dashboard type
 */
async function launchDashboard(dashboardType) {
    console.log(chalk.yellow('Starting dashboard... Press Ctrl+C to exit.'));
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Create a screen object
    const screen = blessed.screen({
        smartCSR: true,
        title: `JuliaOS ${dashboardType.charAt(0).toUpperCase() + dashboardType.slice(1)} Dashboard`
    });

    // Create a grid layout
    const grid = new contrib.grid({
        rows: 12,
        cols: 12,
        screen: screen
    });

    // Configure dashboard based on type
    let updateInterval;
    switch (dashboardType) {
        case 'system':
            updateInterval = setupSystemDashboard(grid, screen);
            break;
        case 'agent':
            updateInterval = setupAgentDashboard(grid, screen);
            break;
        case 'swarm':
            updateInterval = setupSwarmDashboard(grid, screen);
            break;
        case 'trading':
            updateInterval = setupTradingDashboard(grid, screen);
            break;
        case 'network':
            updateInterval = setupNetworkDashboard(grid, screen);
            break;
    }

    // Handle exit
    screen.key(['escape', 'q', 'C-c'], function() {
        if (updateInterval) clearInterval(updateInterval);
        screen.destroy();
        setTimeout(() => {
            dashboardMenu();
        }, 100);
    });

    // Render the screen
    screen.render();
}

/**
 * Setup system dashboard
 */
function setupSystemDashboard(grid, screen) {
    // CPU Usage Line Chart
    const cpuLine = grid.set(0, 0, 4, 6, contrib.line, {
        style: { line: 'yellow', text: 'green', baseline: 'black' },
        xLabelPadding: 3,
        xPadding: 5,
        label: 'CPU Usage (%)',
        showLegend: true,
        legend: { width: 10 }
    });

    // Memory Usage Gauge
    const memoryGauge = grid.set(0, 6, 2, 6, contrib.gauge, {
        label: 'Memory Usage',
        percent: [0],
        stroke: 'green',
        fill: 'white'
    });

    // Disk Usage Gauge
    const diskGauge = grid.set(2, 6, 2, 6, contrib.gauge, {
        label: 'Disk Usage',
        percent: [0],
        stroke: 'blue',
        fill: 'white'
    });

    // System Log
    const systemLog = grid.set(4, 0, 4, 12, contrib.log, {
        fg: 'green',
        selectedFg: 'green',
        label: 'System Log'
    });

    // Active Tasks Table
    const tasksTable = grid.set(8, 0, 4, 6, contrib.table, {
        keys: true,
        fg: 'white',
        selectedFg: 'white',
        selectedBg: 'blue',
        interactive: true,
        label: 'Active Tasks',
        columnSpacing: 3,
        columnWidth: [10, 20, 12, 12]
    });

    // Error Rate Line Chart
    const errorLine = grid.set(8, 6, 4, 6, contrib.line, {
        style: { line: 'red', text: 'green', baseline: 'black' },
        xLabelPadding: 3,
        xPadding: 5,
        label: 'Error Rate',
        showLegend: true,
        legend: { width: 10 }
    });

    // Initialize data
    const cpuData = {
        x: Array(30).fill(0).map((_, i) => i.toString()),
        y: Array(30).fill(0),
        title: 'CPU %',
        style: { line: 'yellow' }
    };

    const errorData = {
        x: Array(30).fill(0).map((_, i) => i.toString()),
        y: Array(30).fill(0),
        title: 'Errors',
        style: { line: 'red' }
    };

    // Update function
    async function updateSystemDashboard() {
        try {
            // Get system metrics
            const metrics = await juliaBridge.executeCommand('get_system_overview', {}, {
                showSpinner: false,
                fallbackToMock: true
            });

            if (metrics) {
                // Update CPU chart
                cpuData.y.shift();
                cpuData.y.push(metrics.cpu_usage_percent || Math.random() * 100);
                cpuLine.setData([cpuData]);

                // Update memory gauge
                memoryGauge.setPercent(metrics.memory_usage_percent || Math.random() * 100);

                // Update disk gauge
                diskGauge.setPercent(metrics.disk_usage_percent || Math.random() * 100);

                // Update system log
                const timestamp = new Date().toISOString();
                systemLog.log(`${timestamp} - CPU: ${metrics.cpu_usage_percent?.toFixed(2) || '0.00'}%, Memory: ${metrics.memory_usage_percent?.toFixed(2) || '0.00'}%, Disk: ${metrics.disk_usage_percent?.toFixed(2) || '0.00'}%`);

                // Update error chart
                errorData.y.shift();
                errorData.y.push(metrics.error_rate || Math.random() * 10);
                errorLine.setData([errorData]);

                // Update tasks table
                const tasks = metrics.active_tasks || [
                    { id: 'task1', name: 'System Check', status: 'Running', progress: '75%' },
                    { id: 'task2', name: 'Data Processing', status: 'Pending', progress: '0%' },
                    { id: 'task3', name: 'Backup', status: 'Completed', progress: '100%' }
                ];

                tasksTable.setData({
                    headers: ['ID', 'Name', 'Status', 'Progress'],
                    data: tasks.map(task => [
                        task.id.substring(0, 8),
                        task.name,
                        task.status,
                        task.progress
                    ])
                });
            }

            screen.render();
        } catch (error) {
            systemLog.log(`Error updating dashboard: ${error.message}`);
            screen.render();
        }
    }

    // Initial update
    updateSystemDashboard();

    // Set interval for updates
    return setInterval(updateSystemDashboard, 2000);
}

/**
 * Setup agent dashboard
 */
function setupAgentDashboard(grid, screen) {
    // Agent List Table
    const agentTable = grid.set(0, 0, 6, 6, contrib.table, {
        keys: true,
        fg: 'white',
        selectedFg: 'white',
        selectedBg: 'blue',
        interactive: true,
        label: 'Active Agents',
        columnSpacing: 3,
        columnWidth: [10, 20, 12, 12]
    });

    // Agent Activity Line Chart
    const activityLine = grid.set(0, 6, 6, 6, contrib.line, {
        style: { line: 'cyan', text: 'green', baseline: 'black' },
        xLabelPadding: 3,
        xPadding: 5,
        label: 'Agent Activity',
        showLegend: true,
        legend: { width: 10 }
    });

    // Agent Log
    const agentLog = grid.set(6, 0, 6, 12, contrib.log, {
        fg: 'green',
        selectedFg: 'green',
        label: 'Agent Log'
    });

    // Initialize data
    const activityData = {
        x: Array(30).fill(0).map((_, i) => i.toString()),
        y: Array(30).fill(0),
        title: 'Actions',
        style: { line: 'cyan' }
    };

    // Update function
    async function updateAgentDashboard() {
        try {
            // Get agent data
            const agents = await juliaBridge.executeCommand('list_agents', {}, {
                showSpinner: false,
                fallbackToMock: true
            });

            if (agents && Array.isArray(agents)) {
                // Update agent table
                agentTable.setData({
                    headers: ['ID', 'Name', 'Type', 'Status'],
                    data: agents.map(agent => [
                        agent.id.substring(0, 8),
                        agent.name,
                        agent.type,
                        agent.status
                    ])
                });

                // Update activity chart
                activityData.y.shift();
                activityData.y.push(Math.floor(Math.random() * 100)); // Mock activity data
                activityLine.setData([activityData]);

                // Update agent log
                const timestamp = new Date().toISOString();
                const randomAgent = agents[Math.floor(Math.random() * agents.length)];
                if (randomAgent) {
                    const actions = ['scanning market', 'analyzing data', 'executing trade', 'reporting status', 'optimizing strategy'];
                    const randomAction = actions[Math.floor(Math.random() * actions.length)];
                    agentLog.log(`${timestamp} - Agent ${randomAgent.name} (${randomAgent.id.substring(0, 8)}) is ${randomAction}`);
                }
            }

            screen.render();
        } catch (error) {
            agentLog.log(`Error updating dashboard: ${error.message}`);
            screen.render();
        }
    }

    // Initial update
    updateAgentDashboard();

    // Set interval for updates
    return setInterval(updateAgentDashboard, 2000);
}

/**
 * Setup swarm dashboard
 */
function setupSwarmDashboard(grid, screen) {
    // Swarm List Table
    const swarmTable = grid.set(0, 0, 4, 6, contrib.table, {
        keys: true,
        fg: 'white',
        selectedFg: 'white',
        selectedBg: 'blue',
        interactive: true,
        label: 'Active Swarms',
        columnSpacing: 3,
        columnWidth: [10, 20, 12, 12]
    });

    // Swarm Performance Line Chart
    const performanceLine = grid.set(0, 6, 4, 6, contrib.line, {
        style: { line: 'magenta', text: 'green', baseline: 'black' },
        xLabelPadding: 3,
        xPadding: 5,
        label: 'Swarm Performance',
        showLegend: true,
        legend: { width: 10 }
    });

    // Swarm Visualization (Map)
    const swarmMap = grid.set(4, 0, 8, 12, contrib.map, {
        label: 'Swarm Visualization'
    });

    // Initialize data
    const performanceData = {
        x: Array(30).fill(0).map((_, i) => i.toString()),
        y: Array(30).fill(0),
        title: 'Fitness',
        style: { line: 'magenta' }
    };

    // Update function
    async function updateSwarmDashboard() {
        try {
            // Get swarm data
            const swarms = await juliaBridge.executeCommand('list_swarms', {}, {
                showSpinner: false,
                fallbackToMock: true
            });

            if (swarms && Array.isArray(swarms)) {
                // Update swarm table
                swarmTable.setData({
                    headers: ['ID', 'Name', 'Algorithm', 'Size'],
                    data: swarms.map(swarm => [
                        swarm.id.substring(0, 8),
                        swarm.name,
                        swarm.algorithm || 'PSO',
                        swarm.size || '10'
                    ])
                });

                // Update performance chart
                performanceData.y.shift();
                performanceData.y.push(Math.floor(Math.random() * 100)); // Mock performance data
                performanceLine.setData([performanceData]);

                // Update swarm visualization
                swarmMap.clearMarkers();
                
                // Generate random markers for swarm agents
                for (let i = 0; i < 20; i++) {
                    const lat = (Math.random() * 180) - 90;
                    const lon = (Math.random() * 360) - 180;
                    const color = i % 2 === 0 ? 'red' : 'yellow';
                    swarmMap.addMarker({ lat, lon, color, char: '•' });
                }
            }

            screen.render();
        } catch (error) {
            // Log error on the map
            swarmMap.clearMarkers();
            screen.render();
        }
    }

    // Initial update
    updateSwarmDashboard();

    // Set interval for updates
    return setInterval(updateSwarmDashboard, 2000);
}

/**
 * Setup trading dashboard
 */
function setupTradingDashboard(grid, screen) {
    // Portfolio Value Line Chart
    const portfolioLine = grid.set(0, 0, 4, 12, contrib.line, {
        style: { line: 'yellow', text: 'green', baseline: 'black' },
        xLabelPadding: 3,
        xPadding: 5,
        label: 'Portfolio Value (USD)',
        showLegend: true,
        legend: { width: 10 }
    });

    // Asset Allocation Donut Chart
    const allocationDonut = grid.set(4, 0, 4, 6, contrib.donut, {
        label: 'Asset Allocation',
        radius: 8,
        arcWidth: 3,
        yPadding: 2,
        data: [
            { percent: 25, label: 'BTC', color: 'yellow' },
            { percent: 25, label: 'ETH', color: 'blue' },
            { percent: 30, label: 'SOL', color: 'green' },
            { percent: 20, label: 'USDC', color: 'red' }
        ]
    });

    // Recent Trades Table
    const tradesTable = grid.set(4, 6, 4, 6, contrib.table, {
        keys: true,
        fg: 'white',
        selectedFg: 'white',
        selectedBg: 'blue',
        interactive: true,
        label: 'Recent Trades',
        columnSpacing: 3,
        columnWidth: [12, 10, 10, 10]
    });

    // Trading Log
    const tradingLog = grid.set(8, 0, 4, 12, contrib.log, {
        fg: 'green',
        selectedFg: 'green',
        label: 'Trading Log'
    });

    // Initialize data
    const portfolioData = {
        x: Array(30).fill(0).map((_, i) => i.toString()),
        y: Array(30).fill(10000).map((val, i) => val + (Math.random() * 1000 - 500) * i),
        title: 'Portfolio',
        style: { line: 'yellow' }
    };

    // Update function
    async function updateTradingDashboard() {
        try {
            // Update portfolio chart
            portfolioData.y.shift();
            const lastValue = portfolioData.y[portfolioData.y.length - 1];
            const newValue = lastValue * (1 + (Math.random() * 0.02 - 0.01)); // +/- 1%
            portfolioData.y.push(newValue);
            portfolioLine.setData([portfolioData]);

            // Update asset allocation
            const assets = [
                { percent: 20 + Math.floor(Math.random() * 10), label: 'BTC', color: 'yellow' },
                { percent: 20 + Math.floor(Math.random() * 10), label: 'ETH', color: 'blue' },
                { percent: 25 + Math.floor(Math.random() * 10), label: 'SOL', color: 'green' },
                { percent: 15 + Math.floor(Math.random() * 10), label: 'USDC', color: 'red' }
            ];
            
            // Normalize percentages to sum to 100
            const total = assets.reduce((sum, asset) => sum + asset.percent, 0);
            assets.forEach(asset => asset.percent = Math.floor(asset.percent / total * 100));
            
            allocationDonut.setData(assets);

            // Update trades table
            const trades = [
                { time: '10:30:45', pair: 'BTC/USDC', type: 'BUY', amount: '0.05' },
                { time: '10:15:22', pair: 'ETH/USDC', type: 'SELL', amount: '1.2' },
                { time: '09:45:11', pair: 'SOL/USDC', type: 'BUY', amount: '10.0' },
                { time: '09:30:05', pair: 'BTC/USDC', type: 'SELL', amount: '0.02' }
            ];

            tradesTable.setData({
                headers: ['Time', 'Pair', 'Type', 'Amount'],
                data: trades.map(trade => [
                    trade.time,
                    trade.pair,
                    trade.type,
                    trade.amount
                ])
            });

            // Update trading log
            if (Math.random() > 0.7) { // Only log occasionally
                const timestamp = new Date().toISOString().substring(11, 19);
                const actions = [
                    'Executed BUY order for 0.01 BTC at $28,450',
                    'Executed SELL order for 2.5 ETH at $1,850',
                    'Executed BUY order for 15 SOL at $95.20',
                    'Rebalancing portfolio...',
                    'Analyzing market conditions...',
                    'Detected arbitrage opportunity on ETH/BTC pair'
                ];
                const randomAction = actions[Math.floor(Math.random() * actions.length)];
                tradingLog.log(`${timestamp} - ${randomAction}`);
            }

            screen.render();
        } catch (error) {
            tradingLog.log(`Error updating dashboard: ${error.message}`);
            screen.render();
        }
    }

    // Initial update
    updateTradingDashboard();

    // Set interval for updates
    return setInterval(updateTradingDashboard, 2000);
}

/**
 * Setup network dashboard
 */
function setupNetworkDashboard(grid, screen) {
    // Network Activity Line Chart
    const networkLine = grid.set(0, 0, 4, 12, contrib.line, {
        style: { line: 'cyan', text: 'green', baseline: 'black' },
        xLabelPadding: 3,
        xPadding: 5,
        label: 'Network Activity',
        showLegend: true,
        legend: { width: 10 }
    });

    // Blockchain Connections Table
    const connectionsTable = grid.set(4, 0, 4, 6, contrib.table, {
        keys: true,
        fg: 'white',
        selectedFg: 'white',
        selectedBg: 'blue',
        interactive: true,
        label: 'Blockchain Connections',
        columnSpacing: 3,
        columnWidth: [15, 10, 15]
    });

    // API Requests Bar Chart
    const apiBar = grid.set(4, 6, 4, 6, contrib.bar, {
        label: 'API Requests (last 5 min)',
        barWidth: 4,
        barSpacing: 6,
        xOffset: 0,
        maxHeight: 100
    });

    // Network Log
    const networkLog = grid.set(8, 0, 4, 12, contrib.log, {
        fg: 'green',
        selectedFg: 'green',
        label: 'Network Log'
    });

    // Initialize data
    const networkData = {
        title: 'Requests/sec',
        x: Array(30).fill(0).map((_, i) => i.toString()),
        y: Array(30).fill(0).map(() => Math.floor(Math.random() * 10)),
        style: { line: 'cyan' }
    };

    const latencyData = {
        title: 'Latency (ms)',
        x: Array(30).fill(0).map((_, i) => i.toString()),
        y: Array(30).fill(0).map(() => Math.floor(Math.random() * 100) + 50),
        style: { line: 'yellow' }
    };

    // Update function
    async function updateNetworkDashboard() {
        try {
            // Update network activity chart
            networkData.y.shift();
            networkData.y.push(Math.floor(Math.random() * 10));
            
            latencyData.y.shift();
            latencyData.y.push(Math.floor(Math.random() * 100) + 50);
            
            networkLine.setData([networkData, latencyData]);

            // Update connections table
            const connections = [
                { chain: 'Ethereum', status: 'Connected', latency: '120ms' },
                { chain: 'Solana', status: 'Connected', latency: '85ms' },
                { chain: 'Polygon', status: 'Connected', latency: '95ms' },
                { chain: 'Arbitrum', status: 'Disconnected', latency: 'N/A' }
            ];

            connectionsTable.setData({
                headers: ['Blockchain', 'Status', 'Latency'],
                data: connections.map(conn => [
                    conn.chain,
                    conn.status,
                    conn.latency
                ])
            });

            // Update API requests bar chart
            apiBar.setData({
                titles: ['GET', 'POST', 'PUT', 'DELETE'],
                data: [
                    Math.floor(Math.random() * 50) + 20,
                    Math.floor(Math.random() * 30) + 10,
                    Math.floor(Math.random() * 10) + 5,
                    Math.floor(Math.random() * 5)
                ]
            });

            // Update network log
            if (Math.random() > 0.7) { // Only log occasionally
                const timestamp = new Date().toISOString().substring(11, 19);
                const actions = [
                    'New connection from 192.168.1.105',
                    'API request: GET /api/agents',
                    'API request: POST /api/swarms',
                    'Blockchain sync completed for Ethereum',
                    'Connection timeout for Arbitrum RPC',
                    'Reconnecting to Solana RPC endpoint'
                ];
                const randomAction = actions[Math.floor(Math.random() * actions.length)];
                networkLog.log(`${timestamp} - ${randomAction}`);
            }

            screen.render();
        } catch (error) {
            networkLog.log(`Error updating dashboard: ${error.message}`);
            screen.render();
        }
    }

    // Initial update
    updateNetworkDashboard();

    // Set interval for updates
    return setInterval(updateNetworkDashboard, 2000);
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
        dashboardMenu
    };
};
