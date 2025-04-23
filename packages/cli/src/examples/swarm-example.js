/**
 * Example of using the EnhancedJuliaBridge to manage swarms
 */

const EnhancedJuliaBridge = require('../enhanced-bridge');

// Mock JuliaBridge for the example
class MockJuliaBridge {
  constructor(config = {}) {
    this.config = {
      apiUrl: config.apiUrl || 'http://localhost:8052/api',
      ...config
    };
    this.initialized = false;
  }

  async initialize() {
    this.initialized = true;
    return true;
  }

  async getHealth() {
    // Simulate a health check response
    return { status: 'healthy' };
  }

  async runJuliaCommand(command, params) {
    // Simulate a command execution
    console.log(`[MockJuliaBridge] Running command: ${command}`);
    console.log(`[MockJuliaBridge] With params:`, params);
    
    // Simulate a delay
    await new Promise(resolve => setTimeout(resolve, 500));
    
    // Return a mock response
    return {
      success: true,
      data: {
        command,
        params,
        timestamp: new Date().toISOString(),
        mock: true
      }
    };
  }
}

// Create a mock JuliaBridge
const mockJuliaBridge = new MockJuliaBridge();

// Create an enhanced bridge with custom configuration
const bridge = new EnhancedJuliaBridge(mockJuliaBridge, {
  logging: {
    level: 'info',
    prefix: 'SwarmExample'
  },
  ui: {
    showSpinners: true,
    spinnerColor: 'magenta'
  }
});

// Listen for events
bridge.on('initialized', () => {
  console.log('Bridge initialized event received');
});

bridge.on('connected', () => {
  console.log('Bridge connected event received');
});

bridge.on('disconnected', () => {
  console.log('Bridge disconnected event received');
});

bridge.on('command_start', (data) => {
  console.log(`Command started: ${data.command}`);
});

bridge.on('command_success', (data) => {
  console.log(`Command succeeded: ${data.command} (source: ${data.source})`);
});

bridge.on('command_error', (data) => {
  console.log(`Command failed: ${data.command}, Error: ${data.error.message}`);
});

// Example swarm management workflow
async function manageSwarms() {
  try {
    console.log('Starting swarm management example...');
    
    // Check connection
    const connected = await bridge.checkConnection();
    console.log(`Connection status: ${connected}`);
    console.log(bridge.getConnectionStatusString());
    
    // List available swarm algorithms
    console.log('\n--- Listing available swarm algorithms ---');
    const algorithms = await bridge.executeCommand('list_algorithms', {});
    console.log('Available algorithms:', algorithms);
    
    // List existing swarms
    console.log('\n--- Listing existing swarms ---');
    const swarms = await bridge.executeCommand('list_swarms', {});
    console.log('Existing swarms:', swarms);
    
    // Create agents for the swarm
    console.log('\n--- Creating agents for the swarm ---');
    const agent1 = await bridge.executeCommand('create_agent', {
      name: 'Swarm Agent 1',
      type: 'trading',
      abilities: ['ping', 'trade']
    });
    console.log('Agent 1 created:', agent1);
    
    const agent2 = await bridge.executeCommand('create_agent', {
      name: 'Swarm Agent 2',
      type: 'trading',
      abilities: ['ping', 'trade']
    });
    console.log('Agent 2 created:', agent2);
    
    const agent3 = await bridge.executeCommand('create_agent', {
      name: 'Swarm Agent 3',
      type: 'trading',
      abilities: ['ping', 'trade']
    });
    console.log('Agent 3 created:', agent3);
    
    // Get agent IDs
    const agent1Id = agent1.id || 'agent1';
    const agent2Id = agent2.id || 'agent2';
    const agent3Id = agent3.id || 'agent3';
    
    // Create a new swarm
    console.log('\n--- Creating a new swarm ---');
    const newSwarm = await bridge.executeCommand('create_swarm', {
      name: 'Example Swarm',
      algorithm: 'SwarmPSO',
      agent_ids: [agent1Id, agent2Id, agent3Id],
      config: {
        algorithm_params: {
          particles: 3,
          iterations: 100,
          cognitive_coefficient: 1.5,
          social_coefficient: 1.5,
          inertia_weight: 0.7
        },
        objective_function: 'maximize_profit',
        constraints: {
          max_risk: 0.2,
          min_return: 0.05
        }
      }
    });
    console.log('New swarm created:', newSwarm);
    
    // Get the swarm details
    console.log('\n--- Getting swarm details ---');
    const swarmId = newSwarm.id || newSwarm.swarm?.id || 'swarm1'; // Fallback if no ID returned
    const swarmDetails = await bridge.executeCommand('get_swarm', { id: swarmId });
    console.log('Swarm details:', swarmDetails);
    
    // Start the swarm
    console.log('\n--- Starting the swarm ---');
    const startResult = await bridge.executeCommand('start_swarm', { id: swarmId });
    console.log('Swarm started:', startResult);
    
    // Connect another agent to the swarm
    console.log('\n--- Creating another agent ---');
    const agent4 = await bridge.executeCommand('create_agent', {
      name: 'Swarm Agent 4',
      type: 'trading',
      abilities: ['ping', 'trade']
    });
    console.log('Agent 4 created:', agent4);
    const agent4Id = agent4.id || 'agent4';
    
    console.log('\n--- Connecting agent to swarm ---');
    const connectResult = await bridge.executeCommand('connect_swarm', { 
      agent_id: agent4Id,
      swarm_id: swarmId
    });
    console.log('Agent connected to swarm:', connectResult);
    
    // Publish a message to the swarm
    console.log('\n--- Publishing message to swarm ---');
    const publishResult = await bridge.executeCommand('publish_to_swarm', { 
      swarm_id: swarmId,
      message: {
        type: 'command',
        action: 'analyze_market',
        params: {
          symbol: 'BTC-USD',
          timeframe: '1h'
        }
      }
    });
    console.log('Message published:', publishResult);
    
    // Disconnect an agent from the swarm
    console.log('\n--- Disconnecting agent from swarm ---');
    const disconnectResult = await bridge.executeCommand('disconnect_swarm', { 
      agent_id: agent4Id,
      swarm_id: swarmId
    });
    console.log('Agent disconnected from swarm:', disconnectResult);
    
    // Stop the swarm
    console.log('\n--- Stopping the swarm ---');
    const stopResult = await bridge.executeCommand('stop_swarm', { id: swarmId });
    console.log('Swarm stopped:', stopResult);
    
    // Delete the swarm
    console.log('\n--- Deleting the swarm ---');
    const deleteResult = await bridge.executeCommand('delete_swarm', { id: swarmId });
    console.log('Swarm deleted:', deleteResult);
    
    // Clean up agents
    console.log('\n--- Cleaning up agents ---');
    await bridge.executeCommand('delete_agent', { id: agent1Id });
    await bridge.executeCommand('delete_agent', { id: agent2Id });
    await bridge.executeCommand('delete_agent', { id: agent3Id });
    await bridge.executeCommand('delete_agent', { id: agent4Id });
    console.log('Agents deleted');
    
    // Verify the swarm is gone
    console.log('\n--- Verifying swarm deletion ---');
    const finalSwarms = await bridge.executeCommand('list_swarms', {});
    console.log('Final swarm list:', finalSwarms);
    
    console.log('\nSwarm management example completed successfully!');
    
    // Shutdown the bridge
    await bridge.shutdown();
  } catch (error) {
    console.error('Error in swarm management example:', error);
    
    // Check if it's a specific error type
    if (error.name === 'BackendError') {
      console.error('Backend error details:', error.details);
    }
  }
}

// Run the example
manageSwarms();
