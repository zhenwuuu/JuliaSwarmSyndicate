import express from 'express';
import bodyParser from 'body-parser';
import cors from 'cors';
import { WormholeBridgeService } from './bridge-service';
import { Logger } from './utils/logger';

const app = express();
const port = process.env.WORMHOLE_BRIDGE_PORT || 3001;
const logger = new Logger('WormholeBridgeAPI');

// Initialize the Wormhole bridge service
const bridgeService = new WormholeBridgeService();

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
app.post('/api/getAvailableChains', async (req, res) => {
  try {
    const chains = bridgeService.getAvailableChains();
    res.json({ success: true, data: { chains } });
  } catch (error) {
    logger.error(`Error getting available chains: ${error}`);
    res.status(500).json({ success: false, error: `Error getting available chains: ${error}` });
  }
});

app.post('/api/getAvailableTokens', async (req, res) => {
  try {
    const { chain } = req.body;
    if (!chain) {
      return res.status(400).json({ success: false, error: 'Missing required parameter: chain' });
    }

    const tokens = bridgeService.getAvailableTokens(chain);
    res.json({ success: true, data: { tokens } });
  } catch (error) {
    logger.error(`Error getting available tokens: ${error}`);
    res.status(500).json({ success: false, error: `Error getting available tokens: ${error}` });
  }
});

app.post('/api/bridgeTokens', async (req, res) => {
  try {
    const { sourceChain, targetChain, token, amount, recipient, wallet, relayerFee } = req.body;

    // Validate required parameters
    const requiredParams = ['sourceChain', 'targetChain', 'token', 'amount', 'recipient', 'wallet'];
    for (const param of requiredParams) {
      if (!req.body[param]) {
        return res.status(400).json({ success: false, error: `Missing required parameter: ${param}` });
      }
    }

    const result = await bridgeService.bridgeTokens({
      sourceChain,
      targetChain,
      token,
      amount,
      recipient,
      wallet,
      relayerFee
    });

    res.json({ success: result.success, data: result, error: result.error });
  } catch (error) {
    logger.error(`Error bridging tokens: ${error}`);
    res.status(500).json({ success: false, error: `Error bridging tokens: ${error}` });
  }
});

app.post('/api/checkTransactionStatus', async (req, res) => {
  try {
    const { sourceChain, transactionHash } = req.body;

    // Validate required parameters
    const requiredParams = ['sourceChain', 'transactionHash'];
    for (const param of requiredParams) {
      if (!req.body[param]) {
        return res.status(400).json({ success: false, error: `Missing required parameter: ${param}` });
      }
    }

    const result = await bridgeService.checkBridgeStatus({
      sourceChain,
      transactionHash
    });

    res.json({ success: result.success, data: result, error: result.error });
  } catch (error) {
    logger.error(`Error checking transaction status: ${error}`);
    res.status(500).json({ success: false, error: `Error checking transaction status: ${error}` });
  }
});

app.post('/api/redeemTokens', async (req, res) => {
  try {
    const { attestation, targetChain, wallet } = req.body;

    // Validate required parameters
    const requiredParams = ['attestation', 'targetChain', 'wallet'];
    for (const param of requiredParams) {
      if (!req.body[param]) {
        return res.status(400).json({ success: false, error: `Missing required parameter: ${param}` });
      }
    }

    const result = await bridgeService.redeemTokens({
      attestation,
      targetChain,
      wallet
    });

    res.json({ success: result.success, data: result, error: result.error });
  } catch (error) {
    logger.error(`Error redeeming tokens: ${error}`);
    res.status(500).json({ success: false, error: `Error redeeming tokens: ${error}` });
  }
});

app.post('/api/getWrappedAssetInfo', async (req, res) => {
  try {
    const { originalChain, originalAsset, targetChain } = req.body;

    // Validate required parameters
    const requiredParams = ['originalChain', 'originalAsset', 'targetChain'];
    for (const param of requiredParams) {
      if (!req.body[param]) {
        return res.status(400).json({ success: false, error: `Missing required parameter: ${param}` });
      }
    }

    const result = await bridgeService.getWrappedAssetInfo({
      originalChain,
      originalAsset,
      targetChain
    });

    res.json({ success: result.success, data: result, error: result.error });
  } catch (error) {
    logger.error(`Error getting wrapped asset info: ${error}`);
    res.status(500).json({ success: false, error: `Error getting wrapped asset info: ${error}` });
  }
});

// Start the server
app.listen(port, () => {
  logger.info(`Wormhole Bridge API server running on port ${port}`);
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
