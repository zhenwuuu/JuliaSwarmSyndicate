/**
 * Example of using JuliaBridge for optimization tasks
 * 
 * This example demonstrates how to:
 * 1. Initialize the JuliaBridge
 * 2. Run different optimization algorithms
 * 3. Handle results and errors
 */

import { JuliaBridge } from '../src/bridge/JuliaBridge';
import { OptimizationParams } from '../src/types/JuliaTypes';
import { ConfigManager } from '../src/config/ConfigManager';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config();

// Define an objective function (this will be sent to Julia)
const objectiveFunction = `
function objective(x)
    # Rosenbrock function (minimum at x = [1, 1, ..., 1])
    sum = 0.0
    for i in 1:length(x)-1
        sum += 100 * (x[i+1] - x[i]^2)^2 + (x[i] - 1)^2
    end
    return sum
end
`;

async function runExample() {
  console.log('Starting optimization example...');

  // Create Julia bridge instance
  const bridge = new JuliaBridge();

  try {
    // Initialize bridge
    console.log('Initializing Julia bridge...');
    await bridge.initialize();
    console.log('Bridge initialized successfully');

    // First, define the objective function in Julia
    console.log('Sending objective function to Julia...');
    await bridge.executeCode(objectiveFunction);
    console.log('Objective function sent successfully');

    // Run PSO optimization
    const psoParams: OptimizationParams = {
      algorithm: 'pso',
      dimensions: 5,
      populationSize: 30,
      iterations: 100,
      inertiaWeight: 0.7,
      cognitiveWeight: 1.5,
      socialWeight: 1.5,
      bounds: {
        min: [-5, -5, -5, -5, -5],
        max: [5, 5, 5, 5, 5]
      },
      objectiveFunction: 'objective'
    };

    console.log('Running PSO optimization...');
    const psoResult = await bridge.optimize(psoParams);
    console.log('PSO optimization result:', psoResult.data);
    console.log('Execution time:', psoResult.metadata?.executionTime, 'ms');

    // Run ACO optimization
    const acoParams: OptimizationParams = {
      algorithm: 'aco',
      dimensions: 5,
      antCount: 30,
      iterations: 100,
      evaporationRate: 0.1,
      alpha: 1.0,
      beta: 2.0,
      bounds: {
        min: [-5, -5, -5, -5, -5],
        max: [5, 5, 5, 5, 5]
      },
      objectiveFunction: 'objective'
    };

    console.log('Running ACO optimization...');
    const acoResult = await bridge.optimize(acoParams);
    console.log('ACO optimization result:', acoResult.data);
    console.log('Execution time:', acoResult.metadata?.executionTime, 'ms');

    // Compare the results
    console.log('\n--- Comparison of optimization results ---');
    console.log(`PSO best value: ${psoResult.data.bestValue}`);
    console.log(`ACO best value: ${acoResult.data.bestValue}`);
    console.log(`PSO best solution: [${psoResult.data.bestSolution}]`);
    console.log(`ACO best solution: [${acoResult.data.bestSolution}]`);

    // Check bridge status
    const status = await bridge.getStatus();
    console.log('\nBridge status:', status.data);
    
  } catch (error) {
    console.error('Error in optimization example:', error);
  } finally {
    // Stop the bridge
    console.log('Stopping Julia bridge...');
    await bridge.stop();
    console.log('Bridge stopped');
  }
}

// Run the example
runExample().catch(console.error); 