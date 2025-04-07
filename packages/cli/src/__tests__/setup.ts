import { jest, afterEach, afterAll } from '@jest/globals';
import type { SpyInstance } from 'jest-mock';
import type { Ora } from 'ora';

// Mock console methods
const consoleMock = {
  log: jest.fn(),
  error: jest.fn(),
  warn: jest.fn(),
  info: jest.fn(),
  debug: jest.fn()
};

Object.assign(global.console, consoleMock);

// Mock process.exit
const mockExit = jest.spyOn(process, 'exit').mockImplementation((code?: string | number | null | undefined) => {
  throw new Error(`process.exit(${code})`);
}) as SpyInstance;

// Mock fs-extra
jest.mock('fs-extra', () => {
  const actual = jest.requireActual('fs-extra');
  return Object.assign({}, actual, {
    existsSync: jest.fn(),
    mkdirSync: jest.fn(),
    writeFileSync: jest.fn(),
    readFileSync: jest.fn(),
    readJson: jest.fn(),
    writeJson: jest.fn(),
    copy: jest.fn(),
    ensureDir: jest.fn()
  });
});

// Mock inquirer
jest.mock('inquirer', () => ({
  prompt: jest.fn()
}));

// Mock ora
jest.mock('ora', () => {
  const mockSpinner = {
    start: jest.fn().mockReturnThis(),
    succeed: jest.fn().mockReturnThis(),
    fail: jest.fn().mockReturnThis(),
    info: jest.fn().mockReturnThis(),
    text: jest.fn().mockReturnThis()
  } as unknown as Ora;
  return jest.fn((opts?: string) => mockSpinner);
});

// Mock conf
jest.mock('conf', () => {
  return jest.fn().mockImplementation(() => ({
    get: jest.fn(),
    set: jest.fn(),
    store: {}
  }));
});

// Clean up mocks after each test
afterEach(() => {
  jest.clearAllMocks();
  mockExit.mockClear();
});

// Restore mocks after all tests
afterAll(() => {
  jest.restoreAllMocks();
  mockExit.mockRestore();
}); 