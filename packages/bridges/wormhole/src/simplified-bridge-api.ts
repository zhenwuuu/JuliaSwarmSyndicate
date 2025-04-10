import express from 'express';
import bodyParser from 'body-parser';
import cors from 'cors';
import { WormholeBridgeService } from './simplified-bridge-service';
import { Logger } from './utils/logger';

// Create Express app
const app = express();
const port = process.env.WORMHOLE_BRIDGE_PORT || 3001;
const logger = new Logger('WormholeBridgeAPI');

// Initialize the Wormhole bridge service
const bridgeService = new WormholeBridgeService();

// Middleware
app.use(cors());
app.use(bodyParser.json());

// Log all requests
app.use(function(req, res, next) {
  logger.info(`${req.method} ${req.path}`);
  next();
});

// Health check endpoint
app.get('/health', function(req, res) {
  res.json({ status: 'ok' });
});

// API endpoints
app.post('/api/getAvailableChains', function(req, res) {
  try {
    const chains = bridgeService.getAvailableChains();
    res.json({ success: true, data: { chains } });
  } catch (error: any) {
    logger.error(`Error getting available chains: ${error.message}`);
    res.status(500).json({ success: false, error: `Error getting available chains: ${error.message}` });
  }
});

app.post('/api/getAvailableTokens', function(req, res) {
  try {
    const { chain } = req.body;
    if (!chain) {
      return res.status(400).json({ success: false, error: 'Missing required parameter: chain' });
    }

    const tokens = bridgeService.getAvailableTokens(chain);
    res.json({ success: true, data: { tokens } });
  } catch (error: any) {
    logger.error(`Error getting available tokens: ${error.message}`);
    res.status(500).json({ success: false, error: `Error getting available tokens: ${error.message}` });
  }
});

app.post('/api/bridgeTokens', async function(req, res) {
  try {
    const { sourceChain, targetChain, token, amount, recipient, wallet, relayerFee, privateKey } = req.body;

    // Validate required parameters
    if (!sourceChain || !targetChain || !token || !amount || !recipient || !wallet) {
      return res.status(400).json({
        success: false,
        error: 'Missing required parameters. Required: sourceChain, targetChain, token, amount, recipient, wallet'
      });
    }

    const result = await bridgeService.bridgeTokens(
      sourceChain,
      targetChain,
      token,
      amount,
      recipient,
      wallet,
      relayerFee,
      privateKey
    );

    res.json({ success: true, data: result });
  } catch (error: any) {
    logger.error(`Error bridging tokens: ${error.message}`);
    res.status(500).json({ success: false, error: `Error bridging tokens: ${error.message}` });
  }
});

app.post('/api/checkTransactionStatus', async function(req, res) {
  try {
    const { sourceChain, transactionHash } = req.body;

    // Validate required parameters
    if (!sourceChain || !transactionHash) {
      return res.status(400).json({
        success: false,
        error: 'Missing required parameters. Required: sourceChain, transactionHash'
      });
    }

    const result = await bridgeService.checkTransactionStatus(sourceChain, transactionHash);
    res.json({ success: true, data: result });
  } catch (error: any) {
    logger.error(`Error checking transaction status: ${error.message}`);
    res.status(500).json({ success: false, error: `Error checking transaction status: ${error.message}` });
  }
});

app.post('/api/redeemTokens', async function(req, res) {
  try {
    const { attestation, targetChain, wallet, privateKey } = req.body;

    // Validate required parameters
    if (!attestation || !targetChain || !wallet) {
      return res.status(400).json({
        success: false,
        error: 'Missing required parameters. Required: attestation, targetChain, wallet'
      });
    }

    const result = await bridgeService.redeemTokens(attestation, targetChain, wallet, privateKey);
    res.json({ success: true, data: result });
  } catch (error: any) {
    logger.error(`Error redeeming tokens: ${error.message}`);
    res.status(500).json({ success: false, error: `Error redeeming tokens: ${error.message}` });
  }
});

app.post('/api/getWrappedAssetInfo', async function(req, res) {
  try {
    const { originalChain, originalAsset, targetChain } = req.body;

    // Validate required parameters
    if (!originalChain || !originalAsset || !targetChain) {
      return res.status(400).json({
        success: false,
        error: 'Missing required parameters. Required: originalChain, originalAsset, targetChain'
      });
    }

    const result = await bridgeService.getWrappedAssetInfo(originalChain, originalAsset, targetChain);
    res.json({ success: true, data: result });
  } catch (error: any) {
    logger.error(`Error getting wrapped asset info: ${error.message}`);
    res.status(500).json({ success: false, error: `Error getting wrapped asset info: ${error.message}` });
  }
});

// Start server if this file is run directly
if (require.main === module) {
  app.listen(port, () => {
    logger.info(`Wormhole Bridge API running on http://localhost:${port}`);
  });
}

export default app;
