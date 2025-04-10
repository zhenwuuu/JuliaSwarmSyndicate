import express from 'express';
import bodyParser from 'body-parser';
import cors from 'cors';
import { WalletIntegration } from './wallet-integration';
import { Logger } from './bridge-service';

const app = express();
const port = process.env.WALLET_API_PORT || 3002;
const logger = new Logger('WalletAPI');

// Initialize the wallet integration
const walletIntegration = new WalletIntegration();

// Middleware
app.use(cors());
app.use(bodyParser.json());

// Log all requests
app.use((req, res, next) => {
  logger.info(`${req.method} ${req.path}`);
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

// API endpoints
app.post('/api/connectWallet', async (req, res) => {
  try {
    const { address, chain, privateKey } = req.body;
    
    // Validate required parameters
    if (!address || !chain) {
      return res.status(400).json({ success: false, error: 'Missing required parameters: address and chain' });
    }
    
    const result = await walletIntegration.connectWallet(address, chain, privateKey);
    res.json({ success: result.success, error: result.error });
  } catch (error) {
    logger.error(`Error connecting wallet: ${error}`);
    res.status(500).json({ success: false, error: `Error connecting wallet: ${error}` });
  }
});

app.post('/api/isWalletConnected', (req, res) => {
  try {
    const { address, chain } = req.body;
    
    // Validate required parameters
    if (!address || !chain) {
      return res.status(400).json({ success: false, error: 'Missing required parameters: address and chain' });
    }
    
    const isConnected = walletIntegration.isWalletConnected(address, chain);
    res.json({ success: true, isConnected });
  } catch (error) {
    logger.error(`Error checking wallet connection: ${error}`);
    res.status(500).json({ success: false, error: `Error checking wallet connection: ${error}` });
  }
});

app.post('/api/disconnectWallet', async (req, res) => {
  try {
    const { address, chain } = req.body;
    
    // Validate required parameters
    if (!address || !chain) {
      return res.status(400).json({ success: false, error: 'Missing required parameters: address and chain' });
    }
    
    const result = await walletIntegration.disconnectWallet(address, chain);
    res.json({ success: result.success, error: result.error });
  } catch (error) {
    logger.error(`Error disconnecting wallet: ${error}`);
    res.status(500).json({ success: false, error: `Error disconnecting wallet: ${error}` });
  }
});

app.post('/api/getWalletBalance', async (req, res) => {
  try {
    const { address, chain } = req.body;
    
    // Validate required parameters
    if (!address || !chain) {
      return res.status(400).json({ success: false, error: 'Missing required parameters: address and chain' });
    }
    
    const result = await walletIntegration.getWalletBalance(address, chain);
    res.json({ success: result.success, balance: result.balance, error: result.error });
  } catch (error) {
    logger.error(`Error getting wallet balance: ${error}`);
    res.status(500).json({ success: false, error: `Error getting wallet balance: ${error}` });
  }
});

app.post('/api/signMessage', async (req, res) => {
  try {
    const { address, chain, message } = req.body;
    
    // Validate required parameters
    if (!address || !chain || !message) {
      return res.status(400).json({ success: false, error: 'Missing required parameters: address, chain, and message' });
    }
    
    const result = await walletIntegration.signMessage(address, chain, message);
    res.json({ success: result.success, signature: result.signature, error: result.error });
  } catch (error) {
    logger.error(`Error signing message: ${error}`);
    res.status(500).json({ success: false, error: `Error signing message: ${error}` });
  }
});

// Start the server
app.listen(port, () => {
  logger.info(`Wallet API server running on port ${port}`);
});

// Handle graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM signal received: closing HTTP server');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT signal received: closing HTTP server');
  process.exit(0);
});
