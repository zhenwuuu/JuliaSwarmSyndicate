/**
 * Basic usage example for JuliaBridge
 */

import { JuliaBridge } from '../src/index';
import path from 'path';

async function main() {
  console.log('Starting JuliaBridge example...');
  
  // Create a new JuliaBridge instance
  const bridge = new JuliaBridge({
    debug: true,
    projectPath: path.resolve(process.cwd(), '../../julia'),
    serverPort: 8052
  });
  
  // Register event handlers
  bridge.on('initialized', () => {
    console.log('JuliaBridge initialized');
  });
  
  bridge.on('server-started', () => {
    console.log('Julia server started');
  });
  
  bridge.on('ws-connected', () => {
    console.log('WebSocket connected');
  });
  
  bridge.on('ws-closed', () => {
    console.log('WebSocket closed');
  });
  
  bridge.on('error', (error) => {
    console.error('JuliaBridge error:', error);
  });
  
  try {
    // Initialize the bridge
    console.log('Initializing JuliaBridge...');
    await bridge.initialize();
    
    // Get system health
    console.log('Getting system health...');
    const health = await bridge.getHealth();
    console.log('System health:', health);
    
    // Create a swarm
    console.log('Creating a swarm...');
    const swarmId = await bridge.createSwarm({
      name: 'Example Swarm',
      type: 'Trading',
      config: {
        size: 10,
        strategy: 'Momentum'
      }
    });
    console.log('Swarm created with ID:', swarmId);
    
    // Optimize the swarm
    console.log('Optimizing swarm...');
    const optimizationResult = await bridge.optimizeSwarm(swarmId, {
      data: [
        { timestamp: Date.now(), value: Math.random() * 100 }
      ],
      options: {
        iterations: 100,
        populationSize: 10
      }
    });
    console.log('Optimization result:', optimizationResult);
    
    // Analyze a route
    console.log('Analyzing route...');
    const routeAnalysis = await bridge.analyzeRoute({
      source: 'ethereum',
      destination: 'solana',
      token: 'USDC',
      amount: '1000'
    });
    console.log('Route analysis:', routeAnalysis);
    
    // Shutdown the bridge
    console.log('Shutting down JuliaBridge...');
    await bridge.shutdown();
    console.log('JuliaBridge shutdown complete');
  } catch (error) {
    console.error('Error:', error);
  }
}

// Run the example
main().catch(console.error); 