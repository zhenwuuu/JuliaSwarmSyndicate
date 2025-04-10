import express from 'express';
import cors from 'cors';
import bodyParser from 'body-parser';
import { WormholeBridgeService } from './wormhole-bridge-service';
import { Logger } from './utils/logger';

// Create Express app
const app = express();
const port = process.env.PORT || 3001;
const logger = new Logger('WormholeBridgeAPI');

// Create bridge service
const bridgeService = new WormholeBridgeService();

// Middleware
app.use(cors());
app.use(bodyParser.json());

// Logging middleware
app.use((req, res, next) => {
  logger.info(`${req.method} ${req.path}`);
  next();
});

// API routes
app.post('/api/getAvailableChains', async (req, res) => {
  try {
    const chains = await bridgeService.getAvailableChains();
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
      return res.status(400).json({ success: false, error: 'Missing chain parameter' });
    }
    
    const tokens = await bridgeService.getAvailableTokens(chain);
    res.json({ success: true, data: { tokens } });
  } catch (error) {
    logger.error(`Error getting available tokens: ${error}`);
    res.status(500).json({ success: false, error: `Error getting available tokens: ${error}` });
  }
});

app.post('/api/bridgeTokens', async (req, res) => {
  try {
    const params = req.body;
    const result = await bridgeService.bridgeTokens(params);
    res.json({ success: true, data: result });
  } catch (error) {
    logger.error(`Error bridging tokens: ${error}`);
    res.status(500).json({ success: false, error: `Error bridging tokens: ${error}` });
  }
});

app.post('/api/checkTransactionStatus', async (req, res) => {
  try {
    const { sourceChain, transactionHash } = req.body;
    if (!sourceChain || !transactionHash) {
      return res.status(400).json({ success: false, error: 'Missing sourceChain or transactionHash parameter' });
    }
    
    const status = await bridgeService.checkTransactionStatus(sourceChain, transactionHash);
    res.json({ success: true, data: status });
  } catch (error) {
    logger.error(`Error checking transaction status: ${error}`);
    res.status(500).json({ success: false, error: `Error checking transaction status: ${error}` });
  }
});

app.post('/api/redeemTokens', async (req, res) => {
  try {
    const { attestation, targetChain, privateKey } = req.body;
    if (!attestation || !targetChain || !privateKey) {
      return res.status(400).json({ success: false, error: 'Missing attestation, targetChain, or privateKey parameter' });
    }
    
    const result = await bridgeService.redeemTokens(attestation, targetChain, privateKey);
    res.json({ success: true, data: result });
  } catch (error) {
    logger.error(`Error redeeming tokens: ${error}`);
    res.status(500).json({ success: false, error: `Error redeeming tokens: ${error}` });
  }
});

app.post('/api/getWrappedAssetInfo', async (req, res) => {
  try {
    const { originalChain, originalAsset, targetChain } = req.body;
    if (!originalChain || !originalAsset || !targetChain) {
      return res.status(400).json({ success: false, error: 'Missing originalChain, originalAsset, or targetChain parameter' });
    }
    
    const info = await bridgeService.getWrappedAssetInfo(originalChain, originalAsset, targetChain);
    res.json({ success: true, data: info });
  } catch (error) {
    logger.error(`Error getting wrapped asset info: ${error}`);
    res.status(500).json({ success: false, error: `Error getting wrapped asset info: ${error}` });
  }
});

// Start server
app.listen(port, () => {
  logger.info(`Wormhole Bridge API server listening on port ${port}`);
});
