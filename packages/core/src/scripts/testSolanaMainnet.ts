import { Connection, PublicKey, Transaction } from '@solana/web3.js';
import { ChainId, Token, TokenAmount } from '../types';
import { CHAIN_CONFIG } from '../config/chains';
import { WalletManager } from '../security/WalletManager';
import { DexManager } from '../dex/DexManager';
import { RiskManager } from '../security/RiskManager';
import { TransactionMonitor, TransactionStatus } from '../monitoring/TransactionMonitor';
import { MarketDataService } from '../dex/market-data';
import { logger } from '../utils/logger';

async function main() {
  try {
    // Initialize Solana connection with QuickNode
    const connection = new Connection(CHAIN_CONFIG.RPC_URLS[ChainId.SOLANA], 'confirmed');
    
    // Initialize wallet
    const privateKey = process.env.PRIVATE_KEY;
    if (!privateKey) {
      throw new Error('Private key not found in environment variables');
    }

    const walletManager = WalletManager.getInstance();
    await walletManager.initializeWallet(ChainId.SOLANA, privateKey, connection);

    // Initialize DEX router (Jupiter for best routing)
    const dexManager = DexManager.getInstance();
    await dexManager.initializeRouter(
      ChainId.SOLANA,
      CHAIN_CONFIG.DEX_ROUTERS[ChainId.SOLANA].JUPITER,
      connection
    );

    // Initialize market data service with Chainlink feeds
    const marketDataConfig = {
      chainlinkFeeds: {
        [CHAIN_CONFIG.COMMON_TOKENS[ChainId.SOLANA].SOL]: '0x4ffC43a60e009B55185A93d1B8E91e6D2B6c7B2E', // SOL/USD
        [CHAIN_CONFIG.COMMON_TOKENS[ChainId.SOLANA].USDC]: '0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6', // USDC/USD
        [CHAIN_CONFIG.COMMON_TOKENS[ChainId.SOLANA].USDT]: '0x3E7d1eAB13ad0104d2750B8863b489D65364e32D', // USDT/USD
        [CHAIN_CONFIG.COMMON_TOKENS[ChainId.SOLANA].BONK]: '0x2465CefD3b488BE410b941b1d4b2767083e2AB95'  // BONK/USD
      },
      updateInterval: 30000, // 30 seconds
      minConfidence: 0.8
    };

    const marketData = new MarketDataService(connection, marketDataConfig);

    // Initialize transaction monitor
    const monitor = TransactionMonitor.getInstance();
    monitor.setConnection(ChainId.SOLANA, connection);

    // Set up risk management
    const riskManager = RiskManager.getInstance();
    riskManager.setConfig(ChainId.SOLANA, {
      maxTransactionValue: TokenAmount.fromRaw('0.1', 9), // 0.1 SOL max
      maxDailyVolume: TokenAmount.fromRaw('1', 9), // 1 SOL daily max
      maxSlippage: 1, // 1% max slippage
      minLiquidity: TokenAmount.fromRaw('1000', 9), // 1000 SOL min liquidity
      maxGasPrice: TokenAmount.fromRaw('100', 9), // 100 lamports max
      circuitBreakerThreshold: 0.5 // 50% price movement threshold
    });

    // Get wallet address and balance
    const address = walletManager.getAddress(ChainId.SOLANA);
    const balance = await walletManager.getBalance(ChainId.SOLANA);
    logger.info(`Wallet address: ${address}`);
    logger.info(`Balance: ${balance.toNumber()} SOL`);

    // Test market data
    const solToken: Token = {
      address: CHAIN_CONFIG.COMMON_TOKENS[ChainId.SOLANA].SOL,
      decimals: 9,
      symbol: 'SOL'
    };
    const usdcToken: Token = {
      address: CHAIN_CONFIG.COMMON_TOKENS[ChainId.SOLANA].USDC,
      decimals: 6,
      symbol: 'USDC'
    };

    const solPrice = await marketData.getMarketData(solToken, usdcToken);
    logger.info(`SOL/USDC Price: ${solPrice.price}`);
    logger.info(`Price Source: ${solPrice.source}`);
    logger.info(`Confidence: ${solPrice.confidence}`);

    // Test small swap: 0.01 SOL to USDC
    const amountIn = TokenAmount.fromRaw('0.01', 9);
    const inputMint = new PublicKey(CHAIN_CONFIG.COMMON_TOKENS[ChainId.SOLANA].SOL);
    const outputMint = new PublicKey(CHAIN_CONFIG.COMMON_TOKENS[ChainId.SOLANA].USDC);

    // Get expected output
    const amountOut = await dexManager.getAmountOut(ChainId.SOLANA, amountIn, [inputMint.toString(), outputMint.toString()]);
    const amountOutMin = amountOut.mul(TokenAmount.fromRaw('95', 0)).div(TokenAmount.fromRaw('100', 0)); // 5% slippage tolerance

    logger.info(`Expected USDC output: ${amountOut.toNumber()} USDC`);
    logger.info(`Minimum USDC output: ${amountOutMin.toNumber()} USDC`);

    // Execute swap
    const deadline = Math.floor(Date.now() / 1000) + 300; // 5 minutes
    const receipt = await dexManager.swapExactTokensForTokens(
      ChainId.SOLANA,
      amountIn,
      amountOutMin,
      [inputMint.toString(), outputMint.toString()],
      deadline
    );

    // Monitor transaction
    const status: TransactionStatus = await monitor.waitForConfirmation(ChainId.SOLANA, receipt.signature);

    if (status.status === 'confirmed') {
      logger.info('Swap successful!');
      logger.info(`Transaction signature: ${status.signature}`);
    } else {
      logger.error('Swap failed!');
      logger.error(`Error: ${status.error}`);
    }

  } catch (error) {
    logger.error('Error executing test:', error);
  }
}

// Run the script
main().catch(console.error); 