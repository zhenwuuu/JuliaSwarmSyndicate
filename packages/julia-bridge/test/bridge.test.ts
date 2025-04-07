import { JuliaBridge } from '../src/index';
import path from 'path';
import { jest } from '@jest/globals';

// Mock WebSocket
jest.mock('ws', () => {
  return jest.fn().mockImplementation(() => {
    return {
      on: jest.fn(),
      send: jest.fn(),
      close: jest.fn(),
      terminate: jest.fn()
    };
  });
});

// Mock child_process
jest.mock('child_process', () => {
  return {
    spawn: jest.fn().mockReturnValue({
      stdout: {
        on: jest.fn()
      },
      stderr: {
        on: jest.fn()
      },
      on: jest.fn(),
      kill: jest.fn()
    }),
    spawnSync: jest.fn().mockReturnValue({
      status: 0,
      stdout: '/usr/bin/julia'
    })
  };
});

// Mock fs
jest.mock('fs', () => {
  return {
    existsSync: jest.fn().mockReturnValue(true),
    mkdirSync: jest.fn()
  };
});

describe('JuliaBridge', () => {
  let bridge: JuliaBridge;
  
  beforeEach(() => {
    // Reset mocks
    jest.clearAllMocks();
    
    // Create a new bridge instance
    bridge = new JuliaBridge({
      debug: true,
      projectPath: path.resolve(process.cwd(), 'julia'),
      serverPort: 8052
    });
  });
  
  test('should initialize correctly', async () => {
    // Mock WebSocket connection
    const mockWs = require('ws');
    const wsInstance = mockWs.mock.results[0].value;
    
    // Simulate WebSocket connection
    wsInstance.on.mockImplementation((event, callback) => {
      if (event === 'open') {
        setTimeout(() => callback(), 0);
      }
    });
    
    // Initialize the bridge
    await bridge.initialize();
    
    // Check that the bridge was initialized
    expect(mockWs).toHaveBeenCalled();
  });
  
  test('should run Julia commands', async () => {
    // Mock WebSocket connection
    const mockWs = require('ws');
    const wsInstance = mockWs.mock.results[0].value;
    
    // Simulate WebSocket connection
    wsInstance.on.mockImplementation((event, callback) => {
      if (event === 'open') {
        setTimeout(() => callback(), 0);
      } else if (event === 'message') {
        setTimeout(() => {
          callback(Buffer.from(JSON.stringify({
            id: 'test-id',
            result: { status: 'ok' }
          })));
        }, 0);
      }
    });
    
    // Initialize the bridge
    await bridge.initialize();
    
    // Run a Julia command
    const result = await bridge.runJuliaCommand('test.function', { param: 'value' });
    
    // Check that the command was sent
    expect(wsInstance.send).toHaveBeenCalled();
    
    // Check that the result was returned
    expect(result).toEqual({ status: 'ok' });
  });
  
  test('should handle errors', async () => {
    // Mock WebSocket connection
    const mockWs = require('ws');
    const wsInstance = mockWs.mock.results[0].value;
    
    // Simulate WebSocket connection
    wsInstance.on.mockImplementation((event, callback) => {
      if (event === 'open') {
        setTimeout(() => callback(), 0);
      } else if (event === 'message') {
        setTimeout(() => {
          callback(Buffer.from(JSON.stringify({
            id: 'test-id',
            error: 'Test error'
          })));
        }, 0);
      }
    });
    
    // Initialize the bridge
    await bridge.initialize();
    
    // Run a Julia command
    try {
      await bridge.runJuliaCommand('test.function', { param: 'value' });
      fail('Expected an error to be thrown');
    } catch (error) {
      expect(error.message).toBe('Test error');
    }
  });
}); 