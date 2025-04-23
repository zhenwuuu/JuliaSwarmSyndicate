/**
 * Example of using the EnhancedJuliaBridge to manage agents
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
    prefix: 'AgentExample'
  },
  ui: {
    showSpinners: true,
    spinnerColor: 'cyan'
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

// Example agent management workflow
async function manageAgents() {
  try {
    console.log('Starting agent management example...');
    
    // Check connection
    const connected = await bridge.checkConnection();
    console.log(`Connection status: ${connected}`);
    console.log(bridge.getConnectionStatusString());
    
    // List existing agents
    console.log('\n--- Listing existing agents ---');
    const agents = await bridge.executeCommand('list_agents', {});
    console.log('Existing agents:', agents);
    
    // Create a new agent
    console.log('\n--- Creating a new agent ---');
    const newAgent = await bridge.executeCommand('create_agent', {
      name: 'Example Agent',
      type: 'trading',
      abilities: ['ping', 'trade'],
      chains: ['ethereum', 'polygon'],
      llm_config: {
        provider: 'openai',
        model: 'gpt-4o',
        temperature: 0.5
      }
    });
    console.log('New agent created:', newAgent);
    
    // Get the agent details
    console.log('\n--- Getting agent details ---');
    const agentId = newAgent.id || 'agent1'; // Fallback if no ID returned
    const agentDetails = await bridge.executeCommand('get_agent', { id: agentId });
    console.log('Agent details:', agentDetails);
    
    // Start the agent
    console.log('\n--- Starting the agent ---');
    const startResult = await bridge.executeCommand('start_agent', { id: agentId });
    console.log('Agent started:', startResult);
    
    // Execute a task
    console.log('\n--- Executing a task ---');
    const taskResult = await bridge.executeCommand('execute_agent_task', { 
      id: agentId,
      task: 'ping',
      params: { message: 'Hello, agent!' }
    });
    console.log('Task executed:', taskResult);
    
    // Pause the agent
    console.log('\n--- Pausing the agent ---');
    const pauseResult = await bridge.executeCommand('pause_agent', { id: agentId });
    console.log('Agent paused:', pauseResult);
    
    // Resume the agent
    console.log('\n--- Resuming the agent ---');
    const resumeResult = await bridge.executeCommand('resume_agent', { id: agentId });
    console.log('Agent resumed:', resumeResult);
    
    // Stop the agent
    console.log('\n--- Stopping the agent ---');
    const stopResult = await bridge.executeCommand('stop_agent', { id: agentId });
    console.log('Agent stopped:', stopResult);
    
    // Delete the agent
    console.log('\n--- Deleting the agent ---');
    const deleteResult = await bridge.executeCommand('delete_agent', { id: agentId });
    console.log('Agent deleted:', deleteResult);
    
    // Verify the agent is gone
    console.log('\n--- Verifying agent deletion ---');
    const finalAgents = await bridge.executeCommand('list_agents', {});
    console.log('Final agent list:', finalAgents);
    
    console.log('\nAgent management example completed successfully!');
    
    // Shutdown the bridge
    await bridge.shutdown();
  } catch (error) {
    console.error('Error in agent management example:', error);
    
    // Check if it's a specific error type
    if (error.name === 'BackendError') {
      console.error('Backend error details:', error.details);
    }
  }
}

// Run the example
manageAgents();
