import { JuliaBridge } from '../bridge/JuliaBridge';
import * as path from 'path';

describe('JuliaBridge Integration Tests', () => {
  let juliaBridge: JuliaBridge;

  beforeAll(() => {
    juliaBridge = new JuliaBridge({
      juliaPath: 'julia',
      scriptPath: path.join(__dirname, '../../julia/src'),
      port: 8000,
      options: {
        debug: true,
        timeout: 30000,
        maxRetries: 3
      }
    });
  });

  beforeEach(async () => {
    await juliaBridge.initialize();
  });

  afterEach(async () => {
    await juliaBridge.stop();
  });

  test('should initialize bridge successfully', async () => {
    expect(juliaBridge.getConnectionStatus()).toBe(true);
  });

  test('should handle optimization requests', async () => {
    const params = {
      algorithm: 'pso',
      dimensions: 2,
      populationSize: 10,
      iterations: 100,
      bounds: {
        min: [0, 0],
        max: [100, 100]
      },
      objectiveFunction: 'maximize_profit'
    };

    const result = await juliaBridge.optimize(params);
    expect(result).toBeDefined();
    expect(Array.isArray(result)).toBe(true);
    expect(result.length).toBe(params.dimensions);
  });

  test('should handle network disconnection', async () => {
    // Simulate network disconnection
    await juliaBridge.stop();
    
    // Try to send a request
    const params = {
      algorithm: 'pso',
      dimensions: 2,
      populationSize: 10,
      iterations: 100,
      bounds: {
        min: [0, 0],
        max: [100, 100]
      },
      objectiveFunction: 'maximize_profit'
    };

    // Should attempt to reconnect and retry
    const result = await juliaBridge.optimize(params);
    expect(result).toBeDefined();
    expect(Array.isArray(result)).toBe(true);
  });

  test('should handle high latency', async () => {
    // Simulate high latency by adding delay to Julia process
    const highLatencyBridge = new JuliaBridge({
      juliaPath: 'julia',
      scriptPath: path.join(__dirname, '../../julia/src'),
      port: 8001,
      options: {
        debug: true,
        timeout: 60000, // Increase timeout for high latency
        maxRetries: 5,
        artificialDelay: 2000 // Add 2s artificial delay
      }
    });

    await highLatencyBridge.initialize();

    const params = {
      algorithm: 'pso',
      dimensions: 2,
      populationSize: 10,
      iterations: 100,
      bounds: {
        min: [0, 0],
        max: [100, 100]
      },
      objectiveFunction: 'maximize_profit'
    };

    const result = await highLatencyBridge.optimize(params);
    expect(result).toBeDefined();
    expect(Array.isArray(result)).toBe(true);

    await highLatencyBridge.stop();
  });

  test('should handle message queue under load', async () => {
    // Send multiple requests simultaneously
    const requests = Array(10).fill(null).map(() => ({
      algorithm: 'pso',
      dimensions: 2,
      populationSize: 10,
      iterations: 100,
      bounds: {
        min: [0, 0],
        max: [100, 100]
      },
      objectiveFunction: 'maximize_profit'
    }));

    const results = await Promise.all(
      requests.map(params => juliaBridge.optimize(params))
    );

    expect(results).toHaveLength(requests.length);
    results.forEach(result => {
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
    });
  });

  test('should handle invalid parameters', async () => {
    const invalidParams = {
      algorithm: 'invalid_algorithm',
      dimensions: -1,
      populationSize: 0,
      iterations: -100,
      bounds: {
        min: [100, 100],
        max: [0, 0]
      },
      objectiveFunction: 'invalid_function'
    };

    await expect(juliaBridge.optimize(invalidParams)).rejects.toThrow();
  });

  test('should handle Julia process crash', async () => {
    // Simulate Julia process crash
    await juliaBridge.stop();
    
    // Try to send a request
    const params = {
      algorithm: 'pso',
      dimensions: 2,
      populationSize: 10,
      iterations: 100,
      bounds: {
        min: [0, 0],
        max: [100, 100]
      },
      objectiveFunction: 'maximize_profit'
    };

    // Should restart Julia process and retry
    const result = await juliaBridge.optimize(params);
    expect(result).toBeDefined();
    expect(Array.isArray(result)).toBe(true);
  });

  test('should handle concurrent optimization requests', async () => {
    const params = {
      algorithm: 'pso',
      dimensions: 2,
      populationSize: 10,
      iterations: 100,
      bounds: {
        min: [0, 0],
        max: [100, 100]
      },
      objectiveFunction: 'maximize_profit'
    };

    // Send concurrent requests with different parameters
    const results = await Promise.all([
      juliaBridge.optimize({ ...params, dimensions: 2 }),
      juliaBridge.optimize({ ...params, dimensions: 3 }),
      juliaBridge.optimize({ ...params, dimensions: 4 })
    ]);

    expect(results).toHaveLength(3);
    results.forEach((result, index) => {
      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      expect(result.length).toBe(index + 2); // Check dimensions match
    });
  });

  test('should handle long-running optimization tasks', async () => {
    const params = {
      algorithm: 'pso',
      dimensions: 10,
      populationSize: 100,
      iterations: 1000,
      bounds: {
        min: Array(10).fill(0),
        max: Array(10).fill(100)
      },
      objectiveFunction: 'maximize_profit'
    };

    const result = await juliaBridge.optimize(params);
    expect(result).toBeDefined();
    expect(Array.isArray(result)).toBe(true);
    expect(result.length).toBe(params.dimensions);
  });
}); 