/**
 * Example of using SwarmAgent with DeFiTradingSkill and JuliaBridge
 * 
 * This example demonstrates how to:
 * 1. Create a SwarmAgent with DeFiTradingSkill
 * 2. Use Julia optimization for trading strategy parameters
 * 3. Fetch market data and execute trades
 */

import { SwarmAgent } from '../src/agent/SwarmAgent';
import { DeFiTradingSkill } from '../src/skills/DeFiTradingSkill';
import { JuliaBridge } from '../src/bridge/JuliaBridge';
import { AgentStorage } from '../src/storage/AgentStorage';
import { ConfigManager } from '../src/config/ConfigManager';
import * as dotenv from 'dotenv';

// Load environment variables
dotenv.config();

// Trading strategy optimization function (this will be sent to Julia)
const strategyOptimizationFunction = `
function optimize_trading_strategy(historical_data)
    # Parse historical data
    prices = historical_data["prices"]
    volumes = historical_data["volumes"]
    
    # Define parameter ranges to optimize
    param_ranges = Dict(
        "sma_short" => [5, 50],
        "sma_long" => [20, 200],
        "volume_threshold" => [0.5, 3.0],
        "take_profit" => [0.01, 0.1],
        "stop_loss" => [0.01, 0.1]
    )
    
    # Define objective function for optimization
    function objective(params)
        sma_short = round(Int, params[1])
        sma_long = round(Int, params[2])
        volume_threshold = params[3]
        take_profit = params[4]
        stop_loss = params[5]
        
        # Ensure sma_short < sma_long
        if sma_short >= sma_long
            return -999999.0  # Invalid configuration
        end
        
        # Calculate SMA indicators
        sma_short_values = [mean(prices[max(1, i-sma_short+1):i]) for i in sma_short:length(prices)]
        sma_long_values = [mean(prices[max(1, i-sma_long+1):i]) for i in sma_long:length(prices)]
        
        # Align data - we can only compare from the point where both SMAs are available
        start_idx = sma_long
        aligned_short = sma_short_values[(start_idx-sma_short+1):end]
        aligned_long = sma_long_values
        aligned_prices = prices[start_idx:end]
        aligned_volumes = volumes[start_idx:end]
        
        # Simulate trading
        cash = 1000.0
        position = 0.0
        in_position = false
        trades = 0
        wins = 0
        
        for i in 2:length(aligned_prices)
            # Trading signals
            price = aligned_prices[i]
            prev_price = aligned_prices[i-1]
            volume = aligned_volumes[i]
            avg_volume = mean(aligned_volumes[max(1, i-10):i])
            volume_signal = volume > volume_threshold * avg_volume
            
            # Check for crossover (short SMA crosses above long SMA)
            crossover_up = aligned_short[i-1] <= aligned_long[i-1] && aligned_short[i] > aligned_long[i]
            
            # Check for crossover (short SMA crosses below long SMA)
            crossover_down = aligned_short[i-1] >= aligned_long[i-1] && aligned_short[i] < aligned_long[i]
            
            # Entry logic
            if !in_position && crossover_up && volume_signal
                # Buy
                position = cash / price
                cash = 0.0
                in_position = true
                entry_price = price
            end
            
            # Exit logic
            if in_position
                # Check take profit
                if price >= entry_price * (1 + take_profit)
                    # Sell with profit
                    cash = position * price
                    position = 0.0
                    in_position = false
                    trades += 1
                    wins += 1
                # Check stop loss
                elseif price <= entry_price * (1 - stop_loss) || crossover_down
                    # Sell with loss or signal
                    cash = position * price
                    position = 0.0
                    in_position = false
                    trades += 1
                    if price > entry_price
                        wins += 1
                    end
                end
            end
        end
        
        # Calculate final portfolio value
        final_value = cash + position * aligned_prices[end]
        
        # Calculate performance metrics
        roi = (final_value - 1000.0) / 1000.0
        win_rate = trades > 0 ? wins / trades : 0.0
        
        # Objective is a combination of ROI and win rate
        score = roi * 0.7 + win_rate * 0.3
        
        return score
    end
    
    # Run PSO optimization
    n_particles = 30
    max_iterations = 50
    dimensions = 5
    
    # Initialize particles
    particles = []
    velocities = []
    best_positions = []
    best_scores = []
    
    # Create initial particles
    for i in 1:n_particles
        position = []
        for (param, range) in param_ranges
            push!(position, range[1] + (range[2] - range[1]) * rand())
        end
        push!(particles, position)
        push!(velocities, [(range[2] - range[1]) * (rand() * 0.1 - 0.05) for (param, range) in param_ranges])
        push!(best_positions, copy(position))
        push!(best_scores, objective(position))
    end
    
    # Find global best
    global_best_idx = argmax(best_scores)
    global_best_position = copy(best_positions[global_best_idx])
    global_best_score = best_scores[global_best_idx]
    
    # PSO constants
    w = 0.7  # Inertia
    c1 = 1.5  # Cognitive weight
    c2 = 1.5  # Social weight
    
    # Optimization loop
    for iter in 1:max_iterations
        for i in 1:n_particles
            # Update velocity and position
            for d in 1:dimensions
                # Calculate velocity update
                cognitive = c1 * rand() * (best_positions[i][d] - particles[i][d])
                social = c2 * rand() * (global_best_position[d] - particles[i][d])
                velocities[i][d] = w * velocities[i][d] + cognitive + social
                
                # Update position
                particles[i][d] += velocities[i][d]
                
                # Ensure within bounds
                param_key = collect(keys(param_ranges))[d]
                range = param_ranges[param_key]
                particles[i][d] = max(range[1], min(range[2], particles[i][d]))
            end
            
            # Evaluate new position
            score = objective(particles[i])
            
            # Update personal best
            if score > best_scores[i]
                best_scores[i] = score
                best_positions[i] = copy(particles[i])
                
                # Update global best
                if score > global_best_score
                    global_best_score = score
                    global_best_position = copy(particles[i])
                end
            end
        end
    end
    
    # Return optimized parameters
    optimized_params = Dict(
        "sma_short" => round(Int, global_best_position[1]),
        "sma_long" => round(Int, global_best_position[2]),
        "volume_threshold" => global_best_position[3],
        "take_profit" => global_best_position[4],
        "stop_loss" => global_best_position[5],
        "expected_roi" => global_best_score
    )
    
    return optimized_params
end
`;

// Sample historical price and volume data
const sampleData = {
  prices: Array.from({ length: 200 }, (_, i) => 
    100 + 10 * Math.sin(i / 10) + 5 * Math.sin(i / 5) + Math.random() * 3
  ),
  volumes: Array.from({ length: 200 }, () => 
    500 + Math.random() * 500
  )
};

async function runExample() {
  console.log('Starting DeFi SwarmAgent example...');

  // Get configuration
  const configManager = ConfigManager.getInstance();
  const storageConfig = configManager.getStorageConfig();

  // Initialize storage
  const storage = new AgentStorage(storageConfig);
  await storage.initialize();

  // Create Julia bridge instance
  const bridge = new JuliaBridge();

  try {
    // Initialize bridge
    console.log('Initializing Julia bridge...');
    await bridge.initialize();
    console.log('Bridge initialized successfully');

    // Send strategy optimization function to Julia
    console.log('Sending strategy optimization function to Julia...');
    await bridge.executeCode(strategyOptimizationFunction);
    console.log('Strategy optimization function sent successfully');

    // Create DeFi trading skill
    const tradingSkill = new DeFiTradingSkill({
      name: 'UniswapTrading',
      platforms: ['ethereum', 'polygon'],
      supportedTokens: ['ETH', 'MATIC', 'USDC', 'USDT'],
      bridge
    });

    // Create swarm agent
    const agent = new SwarmAgent({
      name: 'DeFiTradingAgent',
      type: 'trading',
      platforms: ['ethereum', 'polygon'],
      skills: [tradingSkill],
      swarmConfig: {
        size: 5,
        communicationProtocol: 'p2p',
        consensusThreshold: 0.7,
        updateInterval: 5000
      }
    });

    // Initialize the agent
    await agent.initialize();
    console.log('SwarmAgent initialized successfully');

    // Optimize trading strategy parameters
    console.log('Optimizing trading strategy parameters...');
    const result = await bridge.executeCode(`
      historical_data = ${JSON.stringify(sampleData)}
      optimize_trading_strategy(historical_data)
    `);
    
    const optimizedParams = result.data;
    console.log('Optimized strategy parameters:', optimizedParams);

    // Configure trading strategy with optimized parameters
    await tradingSkill.configureStrategy({
      name: 'SMA-Crossover',
      params: optimizedParams
    });

    // Fetch market data
    console.log('Fetching market data...');
    const marketData = await tradingSkill.fetchMarketData('ethereum', 'ETH/USDC');
    console.log('Market data:', marketData);

    // Determine if we should open a position
    const shouldOpen = await tradingSkill.shouldOpenPosition('ethereum', 'ETH/USDC', 'long');
    console.log('Should open position:', shouldOpen);

    if (shouldOpen) {
      console.log('Opening a position...');
      // Simulate opening a position
      const positionResult = await tradingSkill.openPosition({
        platform: 'ethereum',
        pair: 'ETH/USDC',
        direction: 'long',
        amount: 1000,
        leverage: 1
      });
      console.log('Position opened:', positionResult);
    } else {
      console.log('No trading signal, skipping position opening');
    }

    // Save agent state
    const agentState = {
      id: agent.name,
      type: agent.type,
      status: 'active',
      lastUpdate: Date.now(),
      data: {
        platforms: agent.platforms,
        skills: agent.skills.map(skill => skill.name),
        strategy: {
          name: 'SMA-Crossover',
          params: optimizedParams
        },
        positions: []
      },
      metadata: {
        version: '0.1.0',
        createdAt: Date.now(),
        updatedAt: Date.now()
      }
    };

    await storage.saveState(agentState);
    console.log('Agent state saved successfully');

  } catch (error) {
    console.error('Error in DeFi example:', error);
  } finally {
    // Stop the bridge
    console.log('Stopping Julia bridge and cleaning up...');
    await bridge.stop();
    await storage.stop();
    console.log('Bridge and storage stopped');
  }
}

// Run the example
runExample().catch(console.error); 