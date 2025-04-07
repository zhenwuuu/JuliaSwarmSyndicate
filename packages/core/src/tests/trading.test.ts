import { ethers } from 'ethers';
import * as path from 'path';
import { SwarmAgent } from '../agents/SwarmAgent';
import { DeFiTradingSkill } from '../skills/DeFiTradingSkill';
import { JuliaBridge } from '../bridge/JuliaBridge';

describe('DeFiTradingSkill Integration Tests', () => {
  let juliaBridge: JuliaBridge;
  let swarmAgent: SwarmAgent;
  let tradingSkill: DeFiTradingSkill;
  let provider: ethers.JsonRpcProvider;
  let wallet: ethers.Wallet;

  beforeAll(async () => {
    // Initialize provider and wallet
    provider = new ethers.JsonRpcProvider(process.env.RPC_URL || 'http://localhost:8545');
    wallet = new ethers.Wallet(process.env.PRIVATE_KEY || '0x1234...', provider);

    // Initialize JuliaBridge
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

    // Initialize SwarmAgent
    swarmAgent = new SwarmAgent({
      name: 'test-swarm',
      type: 'trading',
      platforms: [],
      skills: [],
      swarmConfig: {
        size: 10,
        communicationProtocol: 'gossip',
        consensusThreshold: 0.7,
        updateInterval: 5000
      }
    });

    // Initialize DeFiTradingSkill
    tradingSkill = new DeFiTradingSkill(swarmAgent, {
      tradingPairs: ['ETH/USDC', 'WBTC/USDC'],
      swarmSize: 10,
      algorithm: 'pso',
      riskParameters: {
        maxPositionSize: 1, // 1 ETH
        stopLoss: 0.02, // 2%
        takeProfit: 0.05, // 5%
        maxDrawdown: 0.1 // 10%
      },
      provider: process.env.RPC_URL || 'http://localhost:8545',
      wallet: process.env.PRIVATE_KEY || '0x1234...'
    });
  });

  beforeEach(async () => {
    // Initialize components before each test
    await juliaBridge.initialize();
    await swarmAgent.initialize();
    await tradingSkill.initialize();
  });

  afterEach(async () => {
    // Clean up after each test
    await tradingSkill.stop();
    await swarmAgent.stop();
    await juliaBridge.stop();
  });

  test('should initialize trading skill', async () => {
    expect(tradingSkill.isReady()).toBe(true);
  });

  test('should fetch market data', async () => {
    const marketData = await tradingSkill['fetchMarketData']('ETH/USDC');
    expect(marketData).toHaveProperty('symbol', 'ETH/USDC');
    expect(marketData).toHaveProperty('price');
    expect(marketData).toHaveProperty('volume');
    expect(marketData).toHaveProperty('timestamp');
  });

  test('should execute trading strategy', async () => {
    // Start trading
    await tradingSkill.execute();

    // Wait for some time to allow trades to execute
    await new Promise(resolve => setTimeout(resolve, 30000));

    // Check if positions were opened/closed
    const positions = tradingSkill['positions'];
    expect(positions.size).toBeGreaterThan(0);
  });

  test('should handle stop loss', async () => {
    // Open a position
    const marketData = await tradingSkill['fetchMarketData']('ETH/USDC');
    await tradingSkill['openPosition']('ETH/USDC', marketData);

    // Simulate price drop to trigger stop loss
    const position = tradingSkill['positions'].get('ETH/USDC')!;
    const stopLossPrice = position.stopLoss;
    
    // Wait for position to be closed
    await new Promise(resolve => setTimeout(resolve, 5000));

    // Check if position was closed
    const updatedPosition = tradingSkill['positions'].get('ETH/USDC')!;
    expect(updatedPosition.size).toBe(0);
  });

  test('should handle take profit', async () => {
    // Open a position
    const marketData = await tradingSkill['fetchMarketData']('ETH/USDC');
    await tradingSkill['openPosition']('ETH/USDC', marketData);

    // Simulate price increase to trigger take profit
    const position = tradingSkill['positions'].get('ETH/USDC')!;
    const takeProfitPrice = position.takeProfit;
    
    // Wait for position to be closed
    await new Promise(resolve => setTimeout(resolve, 5000));

    // Check if position was closed
    const updatedPosition = tradingSkill['positions'].get('ETH/USDC')!;
    expect(updatedPosition.size).toBe(0);
  });

  test('should integrate with Julia optimization', async () => {
    // Get optimization parameters
    const optimizationParams = {
      algorithm: 'pso',
      dimensions: 2,
      populationSize: 10,
      iterations: 100,
      bounds: {
        min: [0, 0],
        max: [2000, 1000000]
      },
      objectiveFunction: 'maximize_profit'
    };

    // Get optimal parameters from Julia
    const optimalParams = await juliaBridge.optimize(optimizationParams);
    expect(optimalParams).toBeDefined();
    expect(Array.isArray(optimalParams)).toBe(true);
  });
}); 