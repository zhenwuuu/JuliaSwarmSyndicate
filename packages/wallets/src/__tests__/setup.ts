// Define a minimal environment for tests

// Mock TextEncoder
if (typeof TextEncoder === 'undefined') {
  const TextEncodingPolyfill = require('text-encoding');
  Object.assign(global, {
    TextEncoder: TextEncodingPolyfill.TextEncoder,
  });
}

// Mock Buffer
if (typeof Buffer === 'undefined') {
  const buffer = require('buffer');
  Object.assign(global, {
    Buffer: buffer.Buffer,
  });
}

// Create a minimal window mock with necessary functionality
if (typeof window === 'undefined') {
  Object.assign(global, {
    window: {
      ethereum: {
        // Add minimal ethereum interface
        on: jest.fn(),
        removeListener: jest.fn(),
        request: jest.fn()
      },
      solana: {
        // Add minimal solana interface
        isPhantom: true,
        on: jest.fn(),
        removeListener: jest.fn(),
        connect: jest.fn().mockResolvedValue({ publicKey: { toString: () => '0x123' } }),
        disconnect: jest.fn().mockResolvedValue(undefined)
      }
    }
  });
}

// Reset mocks before each test
beforeEach(() => {
  jest.clearAllMocks();
});

// Clean up after tests
afterEach(() => {
  // Just clear the mock functions, don't try to call them
  if (global.window.ethereum) {
    global.window.ethereum.on.mockClear();
    global.window.ethereum.removeListener.mockClear();
  }
  
  if (global.window.solana) {
    global.window.solana.on.mockClear();
    global.window.solana.removeListener.mockClear();
  }
}); 