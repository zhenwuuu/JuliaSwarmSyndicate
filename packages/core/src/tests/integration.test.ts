import { SwarmAgent, SwarmAgentConfig } from '../agents/SwarmAgent';
import { DeFiTradingSkill } from '../skills/DeFiTradingSkill';
import { JuliaBridge, JuliaBridgeConfig, SwarmOptimizationParams } from '../bridge/JuliaBridge';
import { ethers } from 'ethers';
import * as path from 'path';

describe('Integration Tests', () => {
  let juliaBridge: JuliaBridge;
  let tradingSkill: DeFiTradingSkill;
  let swarmAgent: SwarmAgent;

  const juliaConfig: JuliaBridgeConfig = {
    juliaPath: process.env.JULIA_PATH || 'julia',
    scriptPath: path.join(__dirname, '../../julia'),
    port: 8000,
    options: {
      debug: true,
      timeout: 5000,
      maxRetries: 3
    }
  };

  const swarmConfig: SwarmAgentConfig = {
    name: 'test-swarm',
    type: 'trading',
    platforms: [],
    skills: [],
    swarmConfig: {
      size: 3,
      communicationProtocol: 'gossip',
      consensusThreshold: 0.7,
      updateInterval: 1000
    }
  };

  const tradingConfig = {
    parameters: {
      tradingPairs: ['ETH/USDC', 'BTC/USDC'],
      swarmSize: 3,
      algorithm: 'pso' as const,
      riskParameters: {
        maxPositionSize: 1.0,
        stopLoss: 0.05,
        takeProfit: 0.1,
        maxDrawdown: 0.15
      },
      provider: process.env.PROVIDER_URL || 'http://localhost:8545',
      wallet: process.env.PRIVATE_KEY || '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'
    }
  };

  beforeAll(async () => {
    // Initialize JuliaBridge
    juliaBridge = new JuliaBridge(juliaConfig);
    await juliaBridge.initialize();

    // Initialize SwarmAgent
    swarmAgent = new SwarmAgent(swarmConfig);
    await swarmAgent.initialize();

    // Initialize DeFiTradingSkill
    tradingSkill = new DeFiTradingSkill(swarmAgent, tradingConfig.parameters);
    await tradingSkill.initialize();
  });

  afterAll(async () => {
    // Clean up
    await tradingSkill.stop();
    await swarmAgent.stop();
    await juliaBridge.stop();
  });

  test('SwarmAgent can add peers', async () => {
    const peer1 = new SwarmAgent({
      ...swarmConfig,
      name: 'peer1'
    });
    const peer2 = new SwarmAgent({
      ...swarmConfig,
      name: 'peer2'
    });

    await peer1.initialize();
    await peer2.initialize();

    await swarmAgent.addPeer(peer1);
    await swarmAgent.addPeer(peer2);

    // Verify peers were added
    expect(swarmAgent['peers'].size).toBe(2);
  });

  test('JuliaBridge can perform optimization', async () => {
    const params: SwarmOptimizationParams = {
      algorithm: 'pso',
      dimensions: 2,
      populationSize: 10,
      iterations: 100,
      bounds: {
        min: [-1, -1],
        max: [1, 1]
      },
      objectiveFunction: 'x[1]^2 + x[2]^2'
    };

    const result = await juliaBridge.optimize(params);
    expect(result).toBeDefined();
    expect(result.solution).toBeDefined();
    expect(result.solution.length).toBe(2);
  });

  test('DeFiTradingSkill can execute trading logic', async () => {
    await tradingSkill.execute();

    // Wait for some time to let the trading logic execute
    await new Promise(resolve => setTimeout(resolve, 5000));

    // Verify trading skill is running
    expect(tradingSkill.isReady()).toBe(true);
  });

  test('SwarmAgent can reach consensus', async () => {
    const topic = 'trading-strategy';
    const value = 0.5;

    const consensusReached = await swarmAgent.reachConsensus(topic, value);
    expect(consensusReached).toBeDefined();
  });

  test('Integration between components works', async () => {
    // Start all components
    await swarmAgent.start();
    await tradingSkill.execute();

    // Wait for some time to let the system operate
    await new Promise(resolve => setTimeout(resolve, 10000));

    // Verify system state
    expect(swarmAgent.isReady()).toBe(true);
    expect(tradingSkill.isReady()).toBe(true);
  });
}); 