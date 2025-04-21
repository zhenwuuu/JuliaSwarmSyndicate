// Import required modules
const chalk = require('chalk');
const inquirer = require('inquirer');
const ora = require('ora');

// Factory function that accepts dependencies and returns menu functions
module.exports = function performanceMetricsMenuModule({ juliaBridge, displayHeader }) {
    // Menu functions
    async function performanceMetricsMenu(breadcrumbs = ['Main', 'Performance Metrics']) {
        displayHeader(breadcrumbs.join(' > '));
        
        const choices = [
            { name: '1. 📊 View System Metrics', value: 'metrics' },
            { name: '2. 🔍 View Metric Details', value: 'details' },
            { name: '3. ⚙️ Configure Metrics', value: 'configure' },
            { name: '4. 🧪 Run Performance Tests', value: 'test' },
            { name: '0. 🔙 Back to Main Menu', value: 'back' }
        ];

        const { action } = await inquirer.prompt([{
            type: 'list',
            name: 'action',
            message: 'Choose a performance metrics action:',
            choices
        }]);

        switch (action) {
            case 'metrics':
                return showSystemOverview([...breadcrumbs, 'System Metrics']);
            case 'details':
                return showMetricDetails([...breadcrumbs, 'Metric Details']);
            case 'configure':
                return configureMetrics([...breadcrumbs, 'Configure']);
            case 'test':
                return runPerformanceTests([...breadcrumbs, 'Tests']);
            case 'back':
                return;
        }
    }

    async function showSystemOverview(breadcrumbs) {
        displayHeader(breadcrumbs.join(' > '));
        const spinner = ora('Fetching system metrics...').start();
        
        try {
            const metrics = await juliaBridge.call('metrics.get_system_overview');
            spinner.succeed('System metrics retrieved');
            console.log('\nSystem Overview:');
            console.table(metrics);
        } catch (err) {
            spinner.fail('Failed to fetch system metrics');
            console.error('Error:', err.message);
            if (err.message.includes('JuliaBridge not initialized')) {
                console.log(chalk.yellow('Please ensure the Julia backend is running.'));
            }
        }
        
        await inquirer.prompt([{
            type: 'input',
            name: 'continue',
            message: 'Press Enter to continue...'
        }]);
        
        return performanceMetricsMenu(breadcrumbs.slice(0, -1));
    }

    async function showMetricDetails(breadcrumbs) {
        displayHeader(breadcrumbs.join(' > '));
        const spinner = ora('Fetching realtime metrics...').start();
        
        try {
            const metrics = await juliaBridge.call('metrics.get_realtime_metrics');
            spinner.succeed('Realtime metrics retrieved');
            
            console.log(chalk.cyan('\nRealtime Metrics:'));
            console.log(chalk.white('Active Agents:'), metrics.active_agents);
            console.log(chalk.white('Active Swarms:'), metrics.active_swarms);
            console.log(chalk.white('Operations/sec:'), metrics.operations_per_second);
            console.log(chalk.white('Response Time:'), `${metrics.avg_response_time}ms`);
            
        } catch (error) {
            spinner.fail('Failed to fetch realtime metrics');
            console.error(chalk.red('Error:'), error.message);
            if (error.message.includes('JuliaBridge not initialized')) {
                console.log(chalk.yellow('Please ensure the Julia backend is running.'));
            }
        }
        
        await inquirer.prompt([{
            type: 'input',
            name: 'continue',
            message: 'Press Enter to continue...'
        }]);
        
        return performanceMetricsMenu(breadcrumbs.slice(0, -1));
    }

    async function configureMetrics(breadcrumbs) {
        displayHeader(breadcrumbs.join(' > '));
        const spinner = ora('Fetching resource usage...').start();
        
        try {
            const metrics = await juliaBridge.call('metrics.get_resource_usage');
            spinner.succeed('Resource usage metrics retrieved');
            
            console.log(chalk.cyan('\nResource Usage:'));
            console.log(chalk.white('Memory Allocation:'), metrics.memory_allocation);
            console.log(chalk.white('Thread Count:'), metrics.thread_count);
            console.log(chalk.white('Open Files:'), metrics.open_files);
            console.log(chalk.white('Network Connections:'), metrics.network_connections);
            
        } catch (error) {
            spinner.fail('Failed to fetch resource usage');
            console.error(chalk.red('Error:'), error.message);
            if (error.message.includes('JuliaBridge not initialized')) {
                console.log(chalk.yellow('Please ensure the Julia backend is running.'));
            }
        }
        
        await inquirer.prompt([{
            type: 'input',
            name: 'continue',
            message: 'Press Enter to continue...'
        }]);
        
        return performanceMetricsMenu(breadcrumbs.slice(0, -1));
    }

    async function runPerformanceTests(breadcrumbs) {
        displayHeader(breadcrumbs.join(' > '));
        const spinner = ora('Running performance test...').start();
        
        try {
            const metrics = await juliaBridge.call('metrics.run_performance_test');
            spinner.succeed('Performance test completed');
            
            console.log(chalk.cyan('\nPerformance Test Results:'));
            console.log(chalk.white('Latency:'), `${metrics.latency}ms`);
            console.log(chalk.white('Throughput:'), `${metrics.throughput} ops/sec`);
            console.log(chalk.white('Error Rate:'), `${metrics.error_rate}%`);
            console.log(chalk.white('Success Rate:'), `${metrics.success_rate}%`);
            
        } catch (error) {
            spinner.fail('Performance test failed');
            console.error(chalk.red('Error:'), error.message);
            if (error.message.includes('JuliaBridge not initialized')) {
                console.log(chalk.yellow('Please ensure the Julia backend is running.'));
            }
        }
        
        await inquirer.prompt([{
            type: 'input',
            name: 'continue',
            message: 'Press Enter to continue...'
        }]);
        
        return performanceMetricsMenu(breadcrumbs.slice(0, -1));
    }

    // Return the menu functions
    return {
        performanceMetricsMenu,
        showSystemOverview,
        showMetricDetails,
        configureMetrics,
        runPerformanceTests
    };
};