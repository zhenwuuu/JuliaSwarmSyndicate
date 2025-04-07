import { jest, describe, it, expect, beforeEach, afterEach } from '@jest/globals';
import { Command } from 'commander';
import { init } from '../commands/init';
import { create } from '../commands/create';
import { deploy } from '../commands/deploy';
import { test } from '../commands/test';
import { marketplace } from '../commands/marketplace';
import { config } from '../commands/config';

jest.mock('commander');
jest.mock('../commands/init');
jest.mock('../commands/create');
jest.mock('../commands/deploy');
jest.mock('../commands/test');
jest.mock('../commands/marketplace');
jest.mock('../commands/config');

type MockCommandAction = {
  action: (...args: any[]) => void;
};

interface MockCommand {
  command: jest.Mock;
  action: jest.Mock;
  name: jest.Mock;
  description: jest.Mock;
  version: jest.Mock;
  argument: jest.Mock;
  option: jest.Mock;
  parse: jest.Mock;
}

describe('CLI', () => {
  let program: MockCommand;

  beforeEach(() => {
    program = {
      command: jest.fn().mockReturnThis(),
      action: jest.fn().mockReturnThis(),
      name: jest.fn().mockReturnThis(),
      description: jest.fn().mockReturnThis(),
      version: jest.fn().mockReturnThis(),
      argument: jest.fn().mockReturnThis(),
      option: jest.fn().mockReturnThis(),
      parse: jest.fn().mockReturnThis()
    };
    (Command as jest.Mock).mockImplementation(() => program);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('should register all commands', () => {
    require('../index');
    
    expect(program.command).toHaveBeenCalledTimes(6);
    expect(program.command).toHaveBeenCalledWith('init');
    expect(program.command).toHaveBeenCalledWith('create');
    expect(program.command).toHaveBeenCalledWith('deploy');
    expect(program.command).toHaveBeenCalledWith('test');
    expect(program.command).toHaveBeenCalledWith('marketplace');
    expect(program.command).toHaveBeenCalledWith('config');
  });

  it('should handle init command', async () => {
    require('../index');
    
    const initCommand = program.command.mock.calls.find(call => call[0] === 'init');
    const commandAction = initCommand?.[1] as MockCommandAction;
    if (commandAction) {
      await commandAction.action();
      expect(init).toHaveBeenCalled();
    }
  });

  it('should handle create command', async () => {
    require('../index');
    
    const createCommand = program.command.mock.calls.find(call => call[0] === 'create');
    const commandAction = createCommand?.[1] as MockCommandAction;
    if (commandAction) {
      await commandAction.action('agent');
      expect(create).toHaveBeenCalledWith('agent');
    }
  });

  it('should handle deploy command', async () => {
    require('../index');
    
    const deployCommand = program.command.mock.calls.find(call => call[0] === 'deploy');
    const commandAction = deployCommand?.[1] as MockCommandAction;
    if (commandAction) {
      await commandAction.action('agent', { env: 'development' });
      expect(deploy).toHaveBeenCalledWith('agent', { env: 'development' });
    }
  });

  it('should handle test command', async () => {
    require('../index');
    
    const testCommand = program.command.mock.calls.find(call => call[0] === 'test');
    const commandAction = testCommand?.[1] as MockCommandAction;
    if (commandAction) {
      await commandAction.action('agent', { watch: true });
      expect(test).toHaveBeenCalledWith('agent', { watch: true });
    }
  });

  it('should handle marketplace command', async () => {
    require('../index');
    
    const marketplaceCommand = program.command.mock.calls.find(call => call[0] === 'marketplace');
    const commandAction = marketplaceCommand?.[1] as MockCommandAction;
    if (commandAction) {
      await commandAction.action('list');
      expect(marketplace).toHaveBeenCalledWith('list');
    }
  });

  it('should handle config command', async () => {
    require('../index');
    
    const configCommand = program.command.mock.calls.find(call => call[0] === 'config');
    const commandAction = configCommand?.[1] as MockCommandAction;
    if (commandAction) {
      await commandAction.action('list');
      expect(config).toHaveBeenCalledWith('list');
    }
  });
}); 