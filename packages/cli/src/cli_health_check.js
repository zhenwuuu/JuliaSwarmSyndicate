#!/usr/bin/env node

/**
 * JuliaOS CLI Health Check
 * 
 * This script performs a comprehensive health check of the JuliaOS CLI
 * and its integration with the Julia backend. It tests all major functionality
 * and reports any issues found.
 */

const fs = require('fs');
const path = require('path');
const chalk = require('chalk');
const ora = require('ora');
const { JuliaBridge } = require('../../julia-bridge');

// Configuration
const OUTPUT_DIR = path.join(__dirname, '../logs');
const OUTPUT_FILE = path.join(OUTPUT_DIR, `cli_health_check_${new Date().toISOString().replace(/:/g, '-')}.json`);

// Ensure output directory exists
if (!fs.existsSync(OUTPUT_DIR)) {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
}

// Health check results
const results = {
  timestamp: new Date().toISOString(),
  overall_status: 'pending',
  components: {},
  issues: [],
  recommendations: []
};

// Test functions
async function testServerConnection(bridge) {
  const spinner = ora('Testing server connection...').start();
  
  try {
    const health = await bridge.getHealth();
    
    if (health && health.status === 'ok') {
      spinner.succeed('Server connection successful');
      return {
        status: 'ok',
        details: health
      };
    } else {
      spinner.fail('Server returned unexpected health status');
      return {
        status: 'warning',
        details: health,
        message: 'Server health check returned unexpected status'
      };
    }
  } catch (error) {
    spinner.fail(`Server connection failed: ${error.message}`);
    return {
      status: 'error',
      details: null,
      message: `Connection error: ${error.message}`
    };
  }
}

async function testAgentSystem(bridge) {
  const spinner = ora('Testing agent system...').start();
  
  try {
    // Test agent creation
    const createResponse = await bridge.request('POST', '/api/v1/agents', {
      name: 'TestAgent',
      type: 'trading',
      config: {}
    });
    
    if (!createResponse || !createResponse.id) {
      spinner.fail('Failed to create test agent');
      return {
        status: 'error',
        details: createResponse,
        message: 'Agent creation failed'
      };
    }
    
    const agentId = createResponse.id;
    
    // Test agent listing
    const listResponse = await bridge.request('GET', '/api/v1/agents');
    
    if (!listResponse || !Array.isArray(listResponse.agents)) {
      spinner.fail('Failed to list agents');
      return {
        status: 'error',
        details: listResponse,
        message: 'Agent listing failed'
      };
    }
    
    // Test agent retrieval
    const getResponse = await bridge.request('GET', `/api/v1/agents/${agentId}`);
    
    if (!getResponse || getResponse.id !== agentId) {
      spinner.fail('Failed to retrieve agent');
      return {
        status: 'error',
        details: getResponse,
        message: 'Agent retrieval failed'
      };
    }
    
    // Test agent deletion
    const deleteResponse = await bridge.request('DELETE', `/api/v1/agents/${agentId}`);
    
    if (!deleteResponse || !deleteResponse.success) {
      spinner.warn('Failed to delete test agent');
      return {
        status: 'warning',
        details: deleteResponse,
        message: 'Agent deletion failed'
      };
    }
    
    spinner.succeed('Agent system tests passed');
    return {
      status: 'ok',
      details: {
        create: createResponse,
        list: listResponse,
        get: getResponse,
        delete: deleteResponse
      }
    };
  } catch (error) {
    spinner.fail(`Agent system tests failed: ${error.message}`);
    return {
      status: 'error',
      details: null,
      message: `Agent system error: ${error.message}`
    };
  }
}

async function testSwarmSystem(bridge) {
  const spinner = ora('Testing swarm system...').start();
  
  try {
    // Test swarm creation
    const createResponse = await bridge.request('POST', '/api/v1/swarms', {
      name: 'TestSwarm',
      algorithm: 'DE',
      config: {}
    });
    
    if (!createResponse || !createResponse.id) {
      spinner.fail('Failed to create test swarm');
      return {
        status: 'error',
        details: createResponse,
        message: 'Swarm creation failed'
      };
    }
    
    const swarmId = createResponse.id;
    
    // Test swarm listing
    const listResponse = await bridge.request('GET', '/api/v1/swarms');
    
    if (!listResponse || !Array.isArray(listResponse.swarms)) {
      spinner.fail('Failed to list swarms');
      return {
        status: 'error',
        details: listResponse,
        message: 'Swarm listing failed'
      };
    }
    
    // Test swarm retrieval
    const getResponse = await bridge.request('GET', `/api/v1/swarms/${swarmId}`);
    
    if (!getResponse || getResponse.id !== swarmId) {
      spinner.fail('Failed to retrieve swarm');
      return {
        status: 'error',
        details: getResponse,
        message: 'Swarm retrieval failed'
      };
    }
    
    // Test simple optimization
    const optimizeResponse = await bridge.request('POST', `/api/v1/swarms/${swarmId}/optimize`, {
      objective_function: 'function(x) return sum(x.^2) end',
      bounds: [[-10, 10], [-10, 10]],
      max_iterations: 10,
      population_size: 10
    });
    
    if (!optimizeResponse || !optimizeResponse.best_solution) {
      spinner.warn('Optimization test returned unexpected result');
      return {
        status: 'warning',
        details: optimizeResponse,
        message: 'Swarm optimization returned unexpected result'
      };
    }
    
    // Test swarm deletion
    const deleteResponse = await bridge.request('DELETE', `/api/v1/swarms/${swarmId}`);
    
    if (!deleteResponse || !deleteResponse.success) {
      spinner.warn('Failed to delete test swarm');
      return {
        status: 'warning',
        details: deleteResponse,
        message: 'Swarm deletion failed'
      };
    }
    
    spinner.succeed('Swarm system tests passed');
    return {
      status: 'ok',
      details: {
        create: createResponse,
        list: listResponse,
        get: getResponse,
        optimize: optimizeResponse,
        delete: deleteResponse
      }
    };
  } catch (error) {
    spinner.fail(`Swarm system tests failed: ${error.message}`);
    return {
      status: 'error',
      details: null,
      message: `Swarm system error: ${error.message}`
    };
  }
}

async function testBlockchainSystem(bridge) {
  const spinner = ora('Testing blockchain system...').start();
  
  try {
    // Test network status
    const networkResponse = await bridge.request('GET', '/api/v1/blockchain/networks');
    
    if (!networkResponse || !Array.isArray(networkResponse.networks)) {
      spinner.fail('Failed to get blockchain networks');
      return {
        status: 'error',
        details: networkResponse,
        message: 'Blockchain network listing failed'
      };
    }
    
    // Test balance check (this might use mock data if no wallet is configured)
    const balanceResponse = await bridge.request('GET', '/api/v1/blockchain/balance', {
      network: 'ethereum',
      address: '0x0000000000000000000000000000000000000000'
    });
    
    if (!balanceResponse || balanceResponse.balance === undefined) {
      spinner.warn('Balance check returned unexpected result');
      return {
        status: 'warning',
        details: balanceResponse,
        message: 'Blockchain balance check returned unexpected result'
      };
    }
    
    spinner.succeed('Blockchain system tests passed');
    return {
      status: 'ok',
      details: {
        networks: networkResponse,
        balance: balanceResponse
      }
    };
  } catch (error) {
    spinner.fail(`Blockchain system tests failed: ${error.message}`);
    return {
      status: 'error',
      details: null,
      message: `Blockchain system error: ${error.message}`
    };
  }
}

async function testWalletSystem(bridge) {
  const spinner = ora('Testing wallet system...').start();
  
  try {
    // Test wallet listing
    const listResponse = await bridge.request('GET', '/api/v1/wallets');
    
    if (!listResponse || !Array.isArray(listResponse.wallets)) {
      spinner.fail('Failed to list wallets');
      return {
        status: 'error',
        details: listResponse,
        message: 'Wallet listing failed'
      };
    }
    
    // Test wallet creation (with a random name to avoid conflicts)
    const walletName = `test_wallet_${Math.floor(Math.random() * 10000)}`;
    const createResponse = await bridge.request('POST', '/api/v1/wallets', {
      name: walletName,
      type: 'ethereum'
    });
    
    if (!createResponse || !createResponse.id) {
      spinner.warn('Failed to create test wallet');
      return {
        status: 'warning',
        details: createResponse,
        message: 'Wallet creation failed'
      };
    }
    
    const walletId = createResponse.id;
    
    // Test wallet retrieval
    const getResponse = await bridge.request('GET', `/api/v1/wallets/${walletId}`);
    
    if (!getResponse || getResponse.id !== walletId) {
      spinner.warn('Failed to retrieve wallet');
      return {
        status: 'warning',
        details: getResponse,
        message: 'Wallet retrieval failed'
      };
    }
    
    // Test wallet deletion
    const deleteResponse = await bridge.request('DELETE', `/api/v1/wallets/${walletId}`);
    
    if (!deleteResponse || !deleteResponse.success) {
      spinner.warn('Failed to delete test wallet');
      return {
        status: 'warning',
        details: deleteResponse,
        message: 'Wallet deletion failed'
      };
    }
    
    spinner.succeed('Wallet system tests passed');
    return {
      status: 'ok',
      details: {
        list: listResponse,
        create: createResponse,
        get: getResponse,
        delete: deleteResponse
      }
    };
  } catch (error) {
    spinner.fail(`Wallet system tests failed: ${error.message}`);
    return {
      status: 'error',
      details: null,
      message: `Wallet system error: ${error.message}`
    };
  }
}

async function testBridgeSystem(bridge) {
  const spinner = ora('Testing bridge system...').start();
  
  try {
    // Test supported chains
    const chainsResponse = await bridge.request('GET', '/api/v1/bridge/chains');
    
    if (!chainsResponse || !Array.isArray(chainsResponse.chains)) {
      spinner.fail('Failed to get supported chains');
      return {
        status: 'error',
        details: chainsResponse,
        message: 'Bridge chains listing failed'
      };
    }
    
    // Test fee estimation
    const feeResponse = await bridge.request('GET', '/api/v1/bridge/fee', {
      source_chain: 'ethereum',
      target_chain: 'solana',
      token: 'USDC',
      amount: '100'
    });
    
    if (!feeResponse || feeResponse.fee === undefined) {
      spinner.warn('Fee estimation returned unexpected result');
      return {
        status: 'warning',
        details: feeResponse,
        message: 'Bridge fee estimation returned unexpected result'
      };
    }
    
    spinner.succeed('Bridge system tests passed');
    return {
      status: 'ok',
      details: {
        chains: chainsResponse,
        fee: feeResponse
      }
    };
  } catch (error) {
    spinner.fail(`Bridge system tests failed: ${error.message}`);
    return {
      status: 'error',
      details: null,
      message: `Bridge system error: ${error.message}`
    };
  }
}

async function testCLIDependencies() {
  const spinner = ora('Testing CLI dependencies...').start();
  
  const dependencies = [
    { name: 'utils.js', path: path.join(__dirname, 'utils.js') },
    { name: 'interactive.cjs', path: path.join(__dirname, 'interactive.cjs') },
    { name: 'commands/benchmark.js', path: path.join(__dirname, 'commands/benchmark.js') },
    { name: 'agent_specialization_menu.js', path: path.join(__dirname, 'agent_specialization_menu.js') }
  ];
  
  const missingDependencies = [];
  
  for (const dep of dependencies) {
    if (!fs.existsSync(dep.path)) {
      missingDependencies.push(dep.name);
    }
  }
  
  if (missingDependencies.length > 0) {
    spinner.fail(`Missing CLI dependencies: ${missingDependencies.join(', ')}`);
    return {
      status: 'error',
      details: { missing: missingDependencies },
      message: `Missing CLI dependencies: ${missingDependencies.join(', ')}`
    };
  }
  
  spinner.succeed('All CLI dependencies found');
  return {
    status: 'ok',
    details: { dependencies }
  };
}

async function testMenuOptions() {
  const spinner = ora('Testing CLI menu options...').start();
  
  try {
    // Read the interactive.cjs file
    const cliPath = path.join(__dirname, 'interactive.cjs');
    const cliContent = fs.readFileSync(cliPath, 'utf8');
    
    // Extract menu options using regex
    const menuRegex = /const mainMenuOptions\s*=\s*\[([\s\S]*?)\];/;
    const menuMatch = cliContent.match(menuRegex);
    
    if (!menuMatch) {
      spinner.fail('Could not find main menu options in interactive.cjs');
      return {
        status: 'error',
        details: null,
        message: 'Could not find main menu options in interactive.cjs'
      };
    }
    
    // Extract option handlers
    const handlerRegex = /case\s+['"](\d+)['"]\s*:\s*(?:await\s+)?(\w+)\(/g;
    const handlers = [];
    let match;
    
    while ((match = handlerRegex.exec(cliContent)) !== null) {
      handlers.push({
        option: match[1],
        handler: match[2]
      });
    }
    
    // Check if handlers are defined
    const definedHandlers = [];
    const undefinedHandlers = [];
    
    for (const handler of handlers) {
      const handlerRegex = new RegExp(`(async\\s+)?function\\s+${handler.handler}\\s*\\(`, 'g');
      if (handlerRegex.test(cliContent)) {
        definedHandlers.push(handler);
      } else {
        undefinedHandlers.push(handler);
      }
    }
    
    if (undefinedHandlers.length > 0) {
      spinner.warn(`Some menu option handlers are not defined: ${undefinedHandlers.map(h => h.handler).join(', ')}`);
      return {
        status: 'warning',
        details: { defined: definedHandlers, undefined: undefinedHandlers },
        message: `Some menu option handlers are not defined: ${undefinedHandlers.map(h => h.handler).join(', ')}`
      };
    }
    
    spinner.succeed('All menu option handlers are defined');
    return {
      status: 'ok',
      details: { handlers: definedHandlers }
    };
  } catch (error) {
    spinner.fail(`Menu options test failed: ${error.message}`);
    return {
      status: 'error',
      details: null,
      message: `Menu options test error: ${error.message}`
    };
  }
}

// Main function
async function main() {
  console.log(chalk.bold.blue('JuliaOS CLI Health Check'));
  console.log(chalk.blue('=========================\n'));
  
  // Test CLI dependencies
  results.components.cli_dependencies = await testCLIDependencies();
  
  // Test menu options
  results.components.menu_options = await testMenuOptions();
  
  // Initialize Julia bridge
  const bridge = new JuliaBridge({
    useExistingServer: true,
    serverPort: 8052,
    apiUrl: 'http://localhost:8052/api/v1',
    healthUrl: 'http://localhost:8052/health',
    wsUrl: 'ws://localhost:8052',
    debug: false
  });
  
  // Test server connection
  results.components.server_connection = await testServerConnection(bridge);
  
  // Only proceed with other tests if server connection is successful
  if (results.components.server_connection.status === 'ok') {
    // Test agent system
    results.components.agent_system = await testAgentSystem(bridge);
    
    // Test swarm system
    results.components.swarm_system = await testSwarmSystem(bridge);
    
    // Test blockchain system
    results.components.blockchain_system = await testBlockchainSystem(bridge);
    
    // Test wallet system
    results.components.wallet_system = await testWalletSystem(bridge);
    
    // Test bridge system
    results.components.bridge_system = await testBridgeSystem(bridge);
  } else {
    console.log(chalk.yellow('\nSkipping component tests due to server connection issues'));
  }
  
  // Analyze results and generate recommendations
  analyzeResults();
  
  // Save results to file
  fs.writeFileSync(OUTPUT_FILE, JSON.stringify(results, null, 2));
  console.log(chalk.green(`\nHealth check results saved to ${OUTPUT_FILE}`));
  
  // Print summary
  printSummary();
}

// Analyze results and generate recommendations
function analyzeResults() {
  // Count status types
  const statusCounts = {
    ok: 0,
    warning: 0,
    error: 0,
    pending: 0
  };
  
  for (const component in results.components) {
    const status = results.components[component].status;
    statusCounts[status]++;
    
    // Add issues for non-ok components
    if (status !== 'ok') {
      results.issues.push({
        component,
        status,
        message: results.components[component].message
      });
    }
  }
  
  // Set overall status
  if (statusCounts.error > 0) {
    results.overall_status = 'error';
  } else if (statusCounts.warning > 0) {
    results.overall_status = 'warning';
  } else if (statusCounts.pending > 0) {
    results.overall_status = 'pending';
  } else {
    results.overall_status = 'ok';
  }
  
  // Generate recommendations
  if (results.components.server_connection.status !== 'ok') {
    results.recommendations.push({
      priority: 'high',
      component: 'server_connection',
      recommendation: 'Fix the Julia server connection issues. Make sure the server is running and accessible on port 8052.'
    });
  }
  
  if (results.components.cli_dependencies.status !== 'ok') {
    results.recommendations.push({
      priority: 'high',
      component: 'cli_dependencies',
      recommendation: 'Create the missing CLI dependency files to ensure the CLI can run properly.'
    });
  }
  
  if (results.components.menu_options.status !== 'ok') {
    results.recommendations.push({
      priority: 'medium',
      component: 'menu_options',
      recommendation: 'Define all menu option handlers in the interactive.cjs file to ensure all menu options work properly.'
    });
  }
  
  if (results.components.agent_system && results.components.agent_system.status !== 'ok') {
    results.recommendations.push({
      priority: 'high',
      component: 'agent_system',
      recommendation: 'Fix the agent system to ensure agents can be created, listed, and managed properly.'
    });
  }
  
  if (results.components.swarm_system && results.components.swarm_system.status !== 'ok') {
    results.recommendations.push({
      priority: 'high',
      component: 'swarm_system',
      recommendation: 'Fix the swarm system to ensure swarms can be created, listed, and used for optimization.'
    });
  }
  
  if (results.components.blockchain_system && results.components.blockchain_system.status !== 'ok') {
    results.recommendations.push({
      priority: 'medium',
      component: 'blockchain_system',
      recommendation: 'Fix the blockchain system to ensure blockchain operations work properly.'
    });
  }
  
  if (results.components.wallet_system && results.components.wallet_system.status !== 'ok') {
    results.recommendations.push({
      priority: 'medium',
      component: 'wallet_system',
      recommendation: 'Fix the wallet system to ensure wallets can be created, listed, and managed properly.'
    });
  }
  
  if (results.components.bridge_system && results.components.bridge_system.status !== 'ok') {
    results.recommendations.push({
      priority: 'medium',
      component: 'bridge_system',
      recommendation: 'Fix the bridge system to ensure cross-chain operations work properly.'
    });
  }
  
  // Add general recommendations
  if (results.overall_status !== 'ok') {
    results.recommendations.push({
      priority: 'high',
      component: 'general',
      recommendation: 'Run the setup_environment.jl script to ensure all Julia dependencies are installed and the environment is properly configured.'
    });
    
    results.recommendations.push({
      priority: 'medium',
      component: 'general',
      recommendation: 'Check the Julia server logs for errors and fix any issues found.'
    });
    
    results.recommendations.push({
      priority: 'low',
      component: 'general',
      recommendation: 'Consider implementing mock implementations for components that are not yet fully implemented to improve user experience.'
    });
  }
}

// Print summary
function printSummary() {
  console.log('\n');
  console.log(chalk.bold('Health Check Summary:'));
  console.log(chalk.bold(`Overall Status: ${getStatusColor(results.overall_status)(results.overall_status.toUpperCase())}`));
  console.log('\n');
  
  console.log(chalk.bold('Component Status:'));
  for (const component in results.components) {
    const status = results.components[component].status;
    console.log(`${formatComponentName(component)}: ${getStatusColor(status)(status.toUpperCase())}`);
  }
  
  if (results.issues.length > 0) {
    console.log('\n');
    console.log(chalk.bold('Issues Found:'));
    for (const issue of results.issues) {
      console.log(`${getStatusColor(issue.status)('•')} ${formatComponentName(issue.component)}: ${issue.message}`);
    }
  }
  
  if (results.recommendations.length > 0) {
    console.log('\n');
    console.log(chalk.bold('Recommendations:'));
    
    // Group recommendations by priority
    const priorityOrder = ['high', 'medium', 'low'];
    const priorityLabels = {
      high: chalk.red('HIGH'),
      medium: chalk.yellow('MEDIUM'),
      low: chalk.blue('LOW')
    };
    
    for (const priority of priorityOrder) {
      const priorityRecs = results.recommendations.filter(r => r.priority === priority);
      if (priorityRecs.length > 0) {
        console.log(`\n${priorityLabels[priority]} Priority:`);
        for (const rec of priorityRecs) {
          console.log(`• ${rec.recommendation}`);
        }
      }
    }
  }
}

// Helper functions
function getStatusColor(status) {
  switch (status) {
    case 'ok':
      return chalk.green;
    case 'warning':
      return chalk.yellow;
    case 'error':
      return chalk.red;
    case 'pending':
      return chalk.blue;
    default:
      return chalk.white;
  }
}

function formatComponentName(component) {
  return component
    .split('_')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
}

// Run the main function
main().catch(error => {
  console.error(chalk.red(`Error: ${error.message}`));
  console.error(chalk.red(error.stack));
  process.exit(1);
});
