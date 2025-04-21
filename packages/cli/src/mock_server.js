#!/usr/bin/env node

/**
 * JuliaOS Mock Server
 *
 * This script provides a mock implementation of the Julia server API
 * for testing and development purposes.
 */

const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const { v4: uuidv4 } = require('uuid');
const chalk = require('chalk');

// Configuration
const PORT = process.env.PORT || 8052;
const HOST = process.env.HOST || 'localhost';

// Create Express app
const app = express();
app.use(express.json());

// In-memory storage for mock data
const db = {
  agents: [],
  swarms: [],
  wallets: [],
  specializations: [],
  transactions: [],
  trades: [],
  market_data: {
    'ETH/USDT': { price: 3500.25, change_24h: 2.5, volume_24h: 1500000000 },
    'BTC/USDT': { price: 65000.75, change_24h: 1.2, volume_24h: 3500000000 },
    'SOL/USDT': { price: 125.50, change_24h: 5.7, volume_24h: 750000000 },
    'MATIC/USDT': { price: 0.85, change_24h: -1.3, volume_24h: 250000000 },
    'AVAX/USDT': { price: 35.20, change_24h: 3.1, volume_24h: 180000000 }
  }
};

// Initialize with some sample data
function initializeMockData() {
  // Add sample agents
  db.agents.push({
    id: uuidv4(),
    name: 'Trading Agent',
    type: 'trading',
    status: 'idle',
    created_at: new Date().toISOString(),
    config: {
      risk_level: 'medium',
      max_trades_per_day: 10
    }
  });

  db.agents.push({
    id: uuidv4(),
    name: 'Monitoring Agent',
    type: 'monitoring',
    status: 'running',
    created_at: new Date().toISOString(),
    config: {
      alert_threshold: 'high',
      check_interval_seconds: 60
    }
  });

  // Add sample swarms
  db.swarms.push({
    id: uuidv4(),
    name: 'Portfolio Optimization Swarm',
    algorithm: 'DE',
    status: 'idle',
    created_at: new Date().toISOString(),
    config: {
      population_size: 50,
      max_iterations: 100
    }
  });

  // Add sample wallets
  db.wallets.push({
    id: uuidv4(),
    name: 'Main Wallet',
    type: 'ethereum',
    address: '0x1234567890abcdef1234567890abcdef12345678',
    created_at: new Date().toISOString()
  });

  // Add sample specializations
  db.specializations.push({
    id: uuidv4(),
    name: 'Trading Specialist',
    description: 'Specialization for advanced trading strategies',
    capabilities: ['trading', 'market_analysis', 'risk_management'],
    skills: [
      {
        name: 'Technical Analysis',
        description: 'Ability to perform technical analysis on market data'
      },
      {
        name: 'Risk Assessment',
        description: 'Ability to assess and manage trading risks'
      }
    ],
    requirements: {
      capabilities: ['basic', 'network', 'data'],
      min_memory: 512
    },
    metadata: {
      created_at: new Date().toISOString(),
      created_by: 'system'
    }
  });
}

// Initialize mock data
initializeMockData();

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
    services: {
      api: 'ok',
      database: 'ok',
      blockchain: 'ok'
    }
  });
});

// API routes
const apiRouter = express.Router();
app.use('/api/v1', apiRouter);

// Agent routes
apiRouter.get('/agents', (req, res) => {
  res.json({ success: true, data: db.agents });
});

apiRouter.post('/agents', (req, res) => {
  const { name, type, config } = req.body;

  if (!name || !type) {
    return res.status(400).json({
      success: false,
      error: 'Name and type are required'
    });
  }

  const newAgent = {
    id: uuidv4(),
    name,
    type,
    status: 'idle',
    created_at: new Date().toISOString(),
    config: config || {}
  };

  db.agents.push(newAgent);

  res.status(201).json({
    success: true,
    id: newAgent.id,
    ...newAgent
  });
});

apiRouter.get('/agents/:id', (req, res) => {
  const agent = db.agents.find(a => a.id === req.params.id);

  if (!agent) {
    return res.status(404).json({
      success: false,
      error: 'Agent not found'
    });
  }

  res.json({
    success: true,
    ...agent
  });
});

apiRouter.delete('/agents/:id', (req, res) => {
  const index = db.agents.findIndex(a => a.id === req.params.id);

  if (index === -1) {
    return res.status(404).json({
      success: false,
      error: 'Agent not found'
    });
  }

  db.agents.splice(index, 1);

  res.json({
    success: true,
    message: 'Agent deleted successfully'
  });
});

// Swarm routes
apiRouter.get('/swarms', (req, res) => {
  res.json({ success: true, swarms: db.swarms });
});

apiRouter.post('/swarms', (req, res) => {
  const { name, algorithm, config } = req.body;

  if (!name || !algorithm) {
    return res.status(400).json({
      success: false,
      error: 'Name and algorithm are required'
    });
  }

  const newSwarm = {
    id: uuidv4(),
    name,
    algorithm,
    status: 'idle',
    created_at: new Date().toISOString(),
    config: config || {}
  };

  db.swarms.push(newSwarm);

  res.status(201).json({
    success: true,
    id: newSwarm.id,
    ...newSwarm
  });
});

apiRouter.get('/swarms/:id', (req, res) => {
  const swarm = db.swarms.find(s => s.id === req.params.id);

  if (!swarm) {
    return res.status(404).json({
      success: false,
      error: 'Swarm not found'
    });
  }

  res.json({
    success: true,
    ...swarm
  });
});

apiRouter.post('/swarms/:id/optimize', (req, res) => {
  const swarm = db.swarms.find(s => s.id === req.params.id);

  if (!swarm) {
    return res.status(404).json({
      success: false,
      error: 'Swarm not found'
    });
  }

  // Mock optimization result
  const result = {
    success: true,
    swarm_id: swarm.id,
    status: 'completed',
    iterations: 100,
    best_fitness: 0.0023,
    best_solution: [0.1, -0.5, 0.8, 0.2],
    execution_time: 1.23,
    timestamp: new Date().toISOString()
  };

  res.json(result);
});

apiRouter.delete('/swarms/:id', (req, res) => {
  const index = db.swarms.findIndex(s => s.id === req.params.id);

  if (index === -1) {
    return res.status(404).json({
      success: false,
      error: 'Swarm not found'
    });
  }

  db.swarms.splice(index, 1);

  res.json({
    success: true,
    message: 'Swarm deleted successfully'
  });
});

// Wallet routes
apiRouter.get('/wallets', (req, res) => {
  res.json({ success: true, wallets: db.wallets });
});

apiRouter.post('/wallets', (req, res) => {
  const { name, type } = req.body;

  if (!name || !type) {
    return res.status(400).json({
      success: false,
      error: 'Name and type are required'
    });
  }

  const newWallet = {
    id: uuidv4(),
    name,
    type,
    address: `0x${Math.random().toString(16).substring(2, 42)}`,
    created_at: new Date().toISOString()
  };

  db.wallets.push(newWallet);

  res.status(201).json({
    success: true,
    id: newWallet.id,
    ...newWallet
  });
});

apiRouter.get('/wallets/:id', (req, res) => {
  const wallet = db.wallets.find(w => w.id === req.params.id);

  if (!wallet) {
    return res.status(404).json({
      success: false,
      error: 'Wallet not found'
    });
  }

  res.json({
    success: true,
    ...wallet
  });
});

apiRouter.delete('/wallets/:id', (req, res) => {
  const index = db.wallets.findIndex(w => w.id === req.params.id);

  if (index === -1) {
    return res.status(404).json({
      success: false,
      error: 'Wallet not found'
    });
  }

  db.wallets.splice(index, 1);

  res.json({
    success: true,
    message: 'Wallet deleted successfully'
  });
});

// Blockchain routes
apiRouter.get('/blockchain/networks', (req, res) => {
  res.json({
    success: true,
    networks: [
      {
        id: 'ethereum',
        name: 'Ethereum',
        type: 'evm',
        status: 'active',
        rpc_url: 'https://mainnet.infura.io/v3/your-api-key'
      },
      {
        id: 'solana',
        name: 'Solana',
        type: 'solana',
        status: 'active',
        rpc_url: 'https://api.mainnet-beta.solana.com'
      },
      {
        id: 'polygon',
        name: 'Polygon',
        type: 'evm',
        status: 'active',
        rpc_url: 'https://polygon-rpc.com'
      }
    ]
  });
});

apiRouter.get('/blockchain/balance', (req, res) => {
  const { network, address } = req.query;

  if (!network || !address) {
    return res.status(400).json({
      success: false,
      error: 'Network and address are required'
    });
  }

  // Mock balance data
  const balance = {
    network,
    address,
    balance: Math.random() * 10,
    token: 'ETH',
    usd_value: Math.random() * 1000,
    timestamp: new Date().toISOString()
  };

  res.json({
    success: true,
    ...balance
  });
});

// Bridge routes
apiRouter.get('/bridge/chains', (req, res) => {
  res.json({
    success: true,
    chains: [
      {
        id: 'ethereum',
        name: 'Ethereum',
        chain_id: 1,
        status: 'active'
      },
      {
        id: 'solana',
        name: 'Solana',
        chain_id: 'mainnet-beta',
        status: 'active'
      },
      {
        id: 'polygon',
        name: 'Polygon',
        chain_id: 137,
        status: 'active'
      },
      {
        id: 'avalanche',
        name: 'Avalanche',
        chain_id: 43114,
        status: 'active'
      }
    ]
  });
});

apiRouter.get('/bridge/fee', (req, res) => {
  const { source_chain, target_chain, token, amount } = req.query;

  if (!source_chain || !target_chain || !token) {
    return res.status(400).json({
      success: false,
      error: 'Source chain, target chain, and token are required'
    });
  }

  // Mock fee data
  const fee = {
    source_chain,
    target_chain,
    token,
    amount: amount || '1.0',
    fee: (Math.random() * 0.01).toFixed(6),
    fee_token: token,
    fee_usd: (Math.random() * 5).toFixed(2),
    estimated_time_seconds: Math.floor(Math.random() * 300) + 60,
    timestamp: new Date().toISOString()
  };

  res.json({
    success: true,
    ...fee
  });
});

// Specialization routes
apiRouter.get('/specialization/list', (req, res) => {
  res.json({
    success: true,
    specializations: db.specializations
  });
});

apiRouter.post('/specialization/create', (req, res) => {
  const { name, description, capabilities, skills, requirements, parameters, metadata } = req.body;

  if (!name || !description || !capabilities) {
    return res.status(400).json({
      success: false,
      error: 'Name, description, and capabilities are required'
    });
  }

  const newSpecialization = {
    id: uuidv4(),
    name,
    description,
    capabilities,
    skills: skills || [],
    requirements: requirements || {},
    parameters: parameters || {},
    metadata: {
      created_at: new Date().toISOString(),
      ...(metadata || {})
    }
  };

  db.specializations.push(newSpecialization);

  res.status(201).json({
    success: true,
    id: newSpecialization.id
  });
});

apiRouter.post('/specialization/get', (req, res) => {
  const { id } = req.body;

  if (!id) {
    return res.status(400).json({
      success: false,
      error: 'Specialization ID is required'
    });
  }

  const specialization = db.specializations.find(s => s.id === id);

  if (!specialization) {
    return res.status(404).json({
      success: false,
      error: 'Specialization not found'
    });
  }

  res.json({
    success: true,
    ...specialization
  });
});

// Trading routes
apiRouter.post('/trading/execute', (req, res) => {
  const { agent_id, wallet_id, network, pair, type, side, quantity, price, dex, slippage, gas_multiplier } = req.body;

  // Validate required fields
  if (!agent_id || !wallet_id || !network || !pair || !type || !side || !quantity) {
    return res.status(400).json({
      success: false,
      error: 'Missing required fields'
    });
  }

  // Check if agent exists
  const agent = db.agents.find(a => a.id === agent_id);
  if (!agent) {
    return res.status(404).json({
      success: false,
      error: 'Agent not found'
    });
  }

  // Check if wallet exists
  const wallet = db.wallets.find(w => w.id === wallet_id);
  if (!wallet) {
    return res.status(404).json({
      success: false,
      error: 'Wallet not found'
    });
  }

  // Check if pair exists in market data
  if (!db.market_data[pair]) {
    return res.status(400).json({
      success: false,
      error: 'Trading pair not supported'
    });
  }

  // Generate mock trade data
  const currentPrice = db.market_data[pair].price;
  const executedPrice = type === 'market'
    ? currentPrice * (1 + (side === 'buy' ? 1 : -1) * (Math.random() * slippage / 100))
    : price;

  const trade = {
    id: uuidv4(),
    agent_id,
    wallet_id,
    network,
    pair,
    type,
    side,
    quantity: parseFloat(quantity),
    price: type === 'limit' ? parseFloat(price) : null,
    executed_price: parseFloat(executedPrice.toFixed(6)),
    executed_quantity: parseFloat(quantity),
    status: 'completed',
    dex,
    slippage: parseFloat(slippage),
    gas_multiplier: parseFloat(gas_multiplier),
    fee: parseFloat((quantity * executedPrice * 0.001).toFixed(6)),
    gas_used: Math.floor(Math.random() * 200000) + 50000,
    transaction_id: `0x${Math.random().toString(16).substring(2, 66)}`,
    timestamp: new Date().toISOString()
  };

  // Add explorer URL based on network
  switch (network) {
    case 'ethereum':
      trade.explorer_url = `https://etherscan.io/tx/${trade.transaction_id}`;
      break;
    case 'polygon':
      trade.explorer_url = `https://polygonscan.com/tx/${trade.transaction_id}`;
      break;
    case 'solana':
      trade.explorer_url = `https://solscan.io/tx/${trade.transaction_id}`;
      break;
    default:
      // No explorer URL for other networks
      break;
  }

  // Save the trade
  db.trades.push(trade);

  // Return success response
  res.json({
    success: true,
    transaction_id: trade.transaction_id,
    status: trade.status,
    executed_price: trade.executed_price,
    executed_quantity: trade.executed_quantity,
    fee: trade.fee,
    gas_used: trade.gas_used,
    explorer_url: trade.explorer_url,
    timestamp: trade.timestamp
  });
});

apiRouter.get('/trading/history', (req, res) => {
  const { agent_id, wallet_id, limit } = req.query;

  let trades = [...db.trades];

  // Filter by agent_id if provided
  if (agent_id) {
    trades = trades.filter(t => t.agent_id === agent_id);
  }

  // Filter by wallet_id if provided
  if (wallet_id) {
    trades = trades.filter(t => t.wallet_id === wallet_id);
  }

  // Sort by timestamp (newest first)
  trades.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp));

  // Limit results if specified
  if (limit) {
    trades = trades.slice(0, parseInt(limit));
  }

  res.json({
    success: true,
    trades
  });
});

apiRouter.get('/trading/market-data', (req, res) => {
  const { pair } = req.query;

  if (pair && !db.market_data[pair]) {
    return res.status(400).json({
      success: false,
      error: 'Trading pair not found'
    });
  }

  const data = pair ? { [pair]: db.market_data[pair] } : db.market_data;

  res.json({
    success: true,
    data
  });
});

// Benchmarking routes
apiRouter.get('/benchmarking/algorithms', (req, res) => {
  res.json({
    algorithms: {
      'DE': 'Differential Evolution',
      'PSO': 'Particle Swarm Optimization',
      'GWO': 'Grey Wolf Optimizer',
      'ACO': 'Ant Colony Optimization',
      'WOA': 'Whale Optimization Algorithm',
      'GA': 'Genetic Algorithm',
      'DEPSO': 'Hybrid DE-PSO Algorithm'
    }
  });
});

apiRouter.get('/benchmarking/functions', (req, res) => {
  const difficulty = req.query.difficulty || 'all';

  const allFunctions = [
    {
      name: 'Sphere',
      bounds: [-100.0, 100.0],
      optimum: 0.0,
      difficulty: 'easy'
    },
    {
      name: 'Rosenbrock',
      bounds: [-30.0, 30.0],
      optimum: 0.0,
      difficulty: 'medium'
    },
    {
      name: 'Rastrigin',
      bounds: [-5.12, 5.12],
      optimum: 0.0,
      difficulty: 'medium'
    },
    {
      name: 'Ackley',
      bounds: [-32.0, 32.0],
      optimum: 0.0,
      difficulty: 'medium'
    },
    {
      name: 'Griewank',
      bounds: [-600.0, 600.0],
      optimum: 0.0,
      difficulty: 'hard'
    },
    {
      name: 'Schwefel',
      bounds: [-500.0, 500.0],
      optimum: 0.0,
      difficulty: 'hard'
    }
  ];

  const functions = difficulty === 'all'
    ? allFunctions
    : allFunctions.filter(f => f.difficulty === difficulty);

  res.json({ functions });
});

// Create HTTP server
const server = http.createServer(app);

// Create WebSocket server
const wss = new WebSocket.Server({ server });

// WebSocket connection handler
wss.on('connection', (ws) => {
  console.log(chalk.green('WebSocket client connected'));

  // Send welcome message
  ws.send(JSON.stringify({
    type: 'system',
    message: 'Connected to JuliaOS Mock Server',
    timestamp: new Date().toISOString()
  }));

  // Handle messages
  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);

      // Echo the message back
      ws.send(JSON.stringify({
        type: 'response',
        request_id: data.id || uuidv4(),
        data: {
          success: true,
          message: 'Message received',
          echo: data
        },
        timestamp: new Date().toISOString()
      }));
    } catch (error) {
      ws.send(JSON.stringify({
        type: 'error',
        error: 'Invalid message format',
        timestamp: new Date().toISOString()
      }));
    }
  });

  // Handle disconnection
  ws.on('close', () => {
    console.log(chalk.yellow('WebSocket client disconnected'));
  });
});

// Start the server
server.listen(PORT, HOST, () => {
  console.log(chalk.bold.green(`JuliaOS Mock Server running at http://${HOST}:${PORT}`));
  console.log(chalk.cyan('Available endpoints:'));
  console.log(chalk.cyan('- GET  /health'));
  console.log(chalk.cyan('- GET  /api/v1/agents'));
  console.log(chalk.cyan('- POST /api/v1/agents'));
  console.log(chalk.cyan('- GET  /api/v1/swarms'));
  console.log(chalk.cyan('- POST /api/v1/swarms'));
  console.log(chalk.cyan('- GET  /api/v1/wallets'));
  console.log(chalk.cyan('- POST /api/v1/wallets'));
  console.log(chalk.cyan('- GET  /api/v1/blockchain/networks'));
  console.log(chalk.cyan('- GET  /api/v1/blockchain/balance'));
  console.log(chalk.cyan('- GET  /api/v1/bridge/chains'));
  console.log(chalk.cyan('- GET  /api/v1/bridge/fee'));
  console.log(chalk.cyan('- GET  /api/v1/benchmarking/algorithms'));
  console.log(chalk.cyan('- GET  /api/v1/benchmarking/functions'));
  console.log(chalk.cyan('WebSocket server available at ws://${HOST}:${PORT}'));
  console.log(chalk.yellow('\nPress Ctrl+C to stop the server'));
});
