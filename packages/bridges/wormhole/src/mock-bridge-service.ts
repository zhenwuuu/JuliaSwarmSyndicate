import express from 'express';
import bodyParser from 'body-parser';
import cors from 'cors';

// Create Express app
const app = express();
const port = 3001;

// Middleware
app.use(bodyParser.json());
app.use(cors());

// Logging middleware
app.use((req, res, next) => {
  console.log(`${req.method} ${req.url}`);
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

// Mock data
const availableChains = [
  { id: 'ethereum', name: 'Ethereum', chainId: 1 },
  { id: 'solana', name: 'Solana', chainId: 1399811149 },
  { id: 'bsc', name: 'Binance Smart Chain', chainId: 56 },
  { id: 'avalanche', name: 'Avalanche', chainId: 43114 },
  { id: 'fantom', name: 'Fantom', chainId: 250 },
  { id: 'arbitrum', name: 'Arbitrum', chainId: 42161 },
  { id: 'base', name: 'Base', chainId: 8453 }
];

const tokensByChain: Record<string, any[]> = {
  ethereum: [
    { symbol: 'USDC', address: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', decimals: 6 },
    { symbol: 'USDT', address: '0xdAC17F958D2ee523a2206206994597C13D831ec7', decimals: 6 },
    { symbol: 'WETH', address: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2', decimals: 18 }
  ],
  solana: [
    { symbol: 'USDC', address: 'EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v', decimals: 6 },
    { symbol: 'USDT', address: 'Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB', decimals: 6 },
    { symbol: 'SOL', address: 'So11111111111111111111111111111111111111112', decimals: 9 }
  ],
  bsc: [
    { symbol: 'USDC', address: '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d', decimals: 18 },
    { symbol: 'USDT', address: '0x55d398326f99059fF775485246999027B3197955', decimals: 18 },
    { symbol: 'WBNB', address: '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c', decimals: 18 }
  ],
  avalanche: [
    { symbol: 'USDC', address: '0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E', decimals: 6 },
    { symbol: 'USDT', address: '0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7', decimals: 6 },
    { symbol: 'WAVAX', address: '0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7', decimals: 18 }
  ],
  fantom: [
    { symbol: 'USDC', address: '0x04068DA6C83AFCFA0e13ba15A6696662335D5B75', decimals: 6 },
    { symbol: 'WFTM', address: '0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83', decimals: 18 }
  ],
  arbitrum: [
    { symbol: 'USDC', address: '0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8', decimals: 6 },
    { symbol: 'USDT', address: '0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9', decimals: 6 },
    { symbol: 'WETH', address: '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1', decimals: 18 }
  ],
  base: [
    { symbol: 'USDC', address: '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913', decimals: 6 },
    { symbol: 'WETH', address: '0x4200000000000000000000000000000000000006', decimals: 18 }
  ]
};

// API endpoints
app.post('/api/getAvailableChains', async (req, res) => {
  try {
    res.json({
      success: true,
      data: {
        chains: availableChains
      }
    });
  } catch (error: any) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

app.post('/api/getAvailableTokens', async (req, res) => {
  try {
    const { chain } = req.body;
    
    if (!chain) {
      return res.status(400).json({
        success: false,
        error: 'Chain parameter is required'
      });
    }
    
    const tokens = tokensByChain[chain] || [];
    
    res.json({
      success: true,
      data: {
        tokens
      }
    });
  } catch (error: any) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

app.post('/api/bridgeTokens', async (req, res) => {
  try {
    const { sourceChain, targetChain, token, amount, recipient } = req.body;
    
    // Validate required parameters
    if (!sourceChain || !targetChain || !token || !amount || !recipient) {
      return res.status(400).json({
        success: false,
        error: 'Missing required parameters'
      });
    }
    
    // Mock transaction hash
    const transactionHash = `0x${Math.random().toString(16).substring(2, 42)}`;
    
    // Mock attestation
    const attestation = `0x${Math.random().toString(16).substring(2, 130)}`;
    
    res.json({
      success: true,
      data: {
        transactionHash,
        status: 'pending',
        attestation,
        sourceChain,
        targetChain
      }
    });
  } catch (error: any) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

app.post('/api/checkTransactionStatus', async (req, res) => {
  try {
    const { sourceChain, transactionHash } = req.body;
    
    // Validate required parameters
    if (!sourceChain || !transactionHash) {
      return res.status(400).json({
        success: false,
        error: 'Missing required parameters'
      });
    }
    
    // Mock attestation
    const attestation = `0x${Math.random().toString(16).substring(2, 130)}`;
    
    res.json({
      success: true,
      data: {
        status: 'confirmed',
        attestation,
        targetChain: sourceChain === 'ethereum' ? 'solana' : 'ethereum'
      }
    });
  } catch (error: any) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

app.post('/api/redeemTokens', async (req, res) => {
  try {
    const { attestation, targetChain, wallet } = req.body;
    
    // Validate required parameters
    if (!attestation || !targetChain || !wallet) {
      return res.status(400).json({
        success: false,
        error: 'Missing required parameters'
      });
    }
    
    // Mock transaction hash
    const transactionHash = `0x${Math.random().toString(16).substring(2, 42)}`;
    
    res.json({
      success: true,
      data: {
        transactionHash,
        status: 'confirmed'
      }
    });
  } catch (error: any) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

app.post('/api/getWrappedAssetInfo', async (req, res) => {
  try {
    const { originalChain, originalAsset, targetChain } = req.body;
    
    // Validate required parameters
    if (!originalChain || !originalAsset || !targetChain) {
      return res.status(400).json({
        success: false,
        error: 'Missing required parameters'
      });
    }
    
    // Mock wrapped asset info
    const wrappedAsset = {
      address: `0x${Math.random().toString(16).substring(2, 42)}`,
      chainId: targetChain === 'solana' ? 1399811149 : 1,
      decimals: 8,
      symbol: `w${originalAsset.substring(0, 4).toUpperCase()}`,
      name: `Wrapped ${originalAsset.substring(0, 4).toUpperCase()}`,
      isNative: false
    };
    
    res.json({
      success: true,
      data: wrappedAsset
    });
  } catch (error: any) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Start server
export function startServer() {
  return app.listen(port, () => {
    console.log(`Wormhole Bridge Service running on http://localhost:${port}`);
  });
}

// If this file is run directly, start the server
if (require.main === module) {
  startServer();
}

export default app;
