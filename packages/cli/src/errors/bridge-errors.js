/**
 * Custom error classes for the EnhancedJuliaBridge
 */

class JuliaBridgeError extends Error {
  constructor(message, details = {}) {
    super(message);
    this.name = this.constructor.name;
    this.details = details;
    Error.captureStackTrace(this, this.constructor);
  }
}

class ConnectionError extends JuliaBridgeError {
  constructor(message = 'Failed to connect to Julia backend.', details = {}) {
    super(message, details);
  }
}

class CommandError extends JuliaBridgeError {
  constructor(message, command, params, details = {}) {
    super(message, { command, params, ...details });
  }
}

class InitializationError extends JuliaBridgeError {
  constructor(message = 'Failed to initialize Julia bridge.', details = {}) {
    super(message, details);
  }
}

class BackendError extends JuliaBridgeError {
  constructor(message = 'Error reported by Julia backend.', details = {}) {
    super(message, { ...details, backendError: true });
  }
}

class MockImplementationError extends JuliaBridgeError {
  constructor(command, details = {}) {
    super(`Mock implementation not available for command: ${command}`, { command, ...details });
  }
}

module.exports = {
  JuliaBridgeError,
  ConnectionError,
  CommandError,
  InitializationError,
  BackendError,
  MockImplementationError
};
