import { ethers } from 'ethers';
import { DEXInterface, DEXConfig, SwapParams, SwapResult } from './interface';
import { Token, TokenPair } from '../tokens/types';
import { IUniswapV3PoolABI } from './abis/uniswap-v3-pool';
import { IUniswapV3RouterABI } from './abis/uniswap-v3-router';
import { ERC20ABI } from './abis/erc20';
import { DEXMonitor } from './monitoring';
import { PriceFeed, PriceFeedConfig } from './price-feed';

declare global {
  function setTimeout(callback: () => void, ms: number): number;
}

export class UniswapV3DEX implements DEXInterface {
  private provider: ethers.JsonRpcProvider;
  private signer: ethers.Wallet;
  private router: ethers.Contract;
  private chainId: number;
  private isEmergencyStopped: boolean = false;
  private maxPositionSize: bigint;
  private minLiquidity: bigint;
  private maxSlippage: number;
  private circuitBreaker: boolean = false;
  private monitor: DEXMonitor;
  private priceFeed: PriceFeed;

  constructor(config: DEXConfig) {
    this.chainId = config.chainId;
    this.provider = new ethers.JsonRpcProvider(config.rpcUrl);
    this.signer = new ethers.Wallet(config.privateKey, this.provider);
    
    // Security parameters
    this.maxPositionSize = ethers.parseEther('100'); // 100 ETH max position
    this.minLiquidity = ethers.parseEther('1000'); // 1000 ETH min liquidity
    this.maxSlippage = config.slippageTolerance || 0.5; // 0.5% default
    
    // Initialize monitor
    this.monitor = new DEXMonitor();
    
    // Initialize price feed
    const priceFeedConfig: PriceFeedConfig = {
      updateInterval: 30000, // 30 seconds
      maxPriceDeviation: 1.0, // 1% max deviation
      minConfidence: 0.8, // 80% minimum confidence
      sources: ['uniswap-v3', 'chainlink', 'coingecko']
    };
    this.priceFeed = new PriceFeed(priceFeedConfig);
    
    // Uniswap V3 Router address (mainnet)
    const routerAddress = '0xE592427A0AEce92De3Edee1F18E0157C05861564';
    this.router = new ethers.Contract(
      routerAddress,
      IUniswapV3RouterABI,
      this.signer
    );
  }

  // Emergency stop functionality
  public emergencyStop(): void {
    this.isEmergencyStopped = true;
    this.circuitBreaker = true;
  }

  public emergencyResume(): void {
    this.isEmergencyStopped = false;
    this.circuitBreaker = false;
  }

  // Security checks
  private async validateTrade(params: SwapParams): Promise<void> {
    if (this.isEmergencyStopped) {
      throw new Error('Trading is emergency stopped');
    }

    if (this.circuitBreaker) {
      throw new Error('Circuit breaker is active');
    }

    // Check position size
    const amountIn = BigInt(params.amountIn);
    if (amountIn > this.maxPositionSize) {
      throw new Error('Position size exceeds maximum limit');
    }

    // Check liquidity
    const liquidity = await this.getLiquidity(params.tokenIn, params.tokenOut);
    const reserveB = BigInt(liquidity.reserveB);
    if (reserveB < this.minLiquidity) {
      throw new Error('Insufficient liquidity');
    }

    // Check slippage
    if (params.slippageTolerance && params.slippageTolerance > this.maxSlippage) {
      throw new Error('Slippage tolerance exceeds maximum allowed');
    }
  }

  async getQuote(params: SwapParams): Promise<{
    amountOut: string;
    priceImpact: number;
    gasEstimate: number;
  }> {
    const { tokenIn, tokenOut, amountIn } = params;
    
    // Get pool address
    const poolAddress = await this.getPoolAddress(tokenIn, tokenOut);
    const pool = new ethers.Contract(poolAddress, IUniswapV3PoolABI, this.provider);
    
    // Get current sqrt price
    const slot0 = await pool.slot0();
    const sqrtPriceX96 = slot0[0];
    
    // Calculate price impact
    const priceImpact = await this.calculatePriceImpact(
      pool,
      tokenIn,
      tokenOut,
      amountIn
    );
    
    // Get quote
    const quote = await this.router.callStatic.exactInputSingle({
      tokenIn: tokenIn.address,
      tokenOut: tokenOut.address,
      fee: await this.getPoolFee(pool),
      recipient: await this.signer.getAddress(),
      deadline: Math.floor(Date.now() / 1000) + 60 * 20, // 20 minutes
      amountIn: amountIn,
      amountOutMinimum: '0',
      sqrtPriceLimitX96: '0'
    });
    
    // Estimate gas
    const gasEstimate = await this.estimateGas(params);
    
    return {
      amountOut: quote.amountOut.toString(),
      priceImpact,
      gasEstimate
    };
  }

  /**
   * Get quote for multi-hop swap
   */
  async getMultiHopQuote(params: {
    path: Token[];
    amountIn: string;
  }): Promise<{
    amountOut: string;
    priceImpact: number;
    gasEstimate: number;
  }> {
    const { path, amountIn } = params;
    
    if (path.length < 2) {
      throw new Error('Path must contain at least 2 tokens');
    }

    // Encode path
    const encodedPath = this.encodePath(path);
    
    // Get quote
    const quote = await this.router.callStatic.exactInput({
      path: encodedPath,
      recipient: await this.signer.getAddress(),
      deadline: Math.floor(Date.now() / 1000) + 60 * 20, // 20 minutes
      amountIn: amountIn,
      amountOutMinimum: '0'
    });
    
    // Calculate total price impact across all hops
    let totalPriceImpact = 0;
    for (let i = 0; i < path.length - 1; i++) {
      const poolAddress = await this.getPoolAddress(path[i], path[i + 1]);
      const pool = new ethers.Contract(poolAddress, IUniswapV3PoolABI, this.provider);
      const hopImpact = await this.calculatePriceImpact(
        pool,
        path[i],
        path[i + 1],
        amountIn
      );
      totalPriceImpact += hopImpact;
    }
    
    // Estimate gas for multi-hop
    const gasEstimate = await this.estimateMultiHopGas(path, amountIn);
    
    return {
      amountOut: quote.amountOut.toString(),
      priceImpact: totalPriceImpact,
      gasEstimate
    };
  }

  /**
   * Execute multi-hop swap
   */
  private async waitForTransaction(tx: ethers.ContractTransactionResponse, timeout: number = 300000): Promise<ethers.ContractReceipt> {
    return Promise.race([
      tx.wait(),
      new Promise((_, reject) => 
        setTimeout(() => reject(new Error('Transaction timeout')), timeout)
      )
    ]);
  }

  async executeMultiHopSwap(params: {
    path: Token[];
    amountIn: string;
    minAmountOut: string;
  }): Promise<SwapResult> {
    const { path, amountIn, minAmountOut } = params;
    const startTime = Date.now();
    
    try {
      // Validate path
      if (path.length < 2) {
        throw new Error('Path must contain at least 2 tokens');
      }

      // Encode path
      const encodedPath = this.encodePath(path);
      
      // Approve first token if needed
      await this.approveToken(path[0], amountIn);
      
      // Execute multi-hop swap
      const tx = await this.router.exactInput({
        path: encodedPath,
        recipient: await this.signer.getAddress(),
        deadline: Math.floor(Date.now() / 1000) + 60 * 20, // 20 minutes
        amountIn: amountIn,
        amountOutMinimum: minAmountOut
      });
      
      // Wait for transaction with timeout
      const receipt = await this.waitForTransaction(tx);
      
      // Get amount out from event logs
      const amountOut = this.getAmountOutFromLogs(receipt.logs);
      
      // Calculate total price impact
      let totalPriceImpact = 0;
      for (let i = 0; i < path.length - 1; i++) {
        const poolAddress = await this.getPoolAddress(path[i], path[i + 1]);
        const hopImpact = await this.calculatePriceImpact(
          poolAddress,
          path[i],
          path[i + 1],
          amountIn
        );
        totalPriceImpact += hopImpact;
      }
      
      const result: SwapResult = {
        transactionHash: receipt.transactionHash,
        amountOut,
        priceImpact: totalPriceImpact,
        gasUsed: receipt.gasUsed.toNumber(),
        gasPrice: receipt.effectiveGasPrice.toString(),
        executionTime: Date.now() - startTime
      };

      // Record trade in monitor
      this.monitor.recordTrade(result);

      return result;
    } catch (error) {
      // Record failed trade
      this.monitor.recordTrade({
        transactionHash: '',
        amountOut: '0',
        priceImpact: 0,
        gasUsed: 0,
        gasPrice: '0',
        executionTime: Date.now() - startTime
      });

      throw error;
    }
  }

  /**
   * Encode path for multi-hop swap
   */
  private encodePath(path: Token[]): string {
    let encodedPath = '';
    
    for (let i = 0; i < path.length - 1; i++) {
      const tokenIn = path[i];
      const tokenOut = path[i + 1];
      const fee = this.getPoolFee(tokenIn, tokenOut);
      
      // Encode each hop: tokenIn + fee + tokenOut
      encodedPath += tokenIn.address.slice(2) + // Remove '0x' prefix
                     fee.toString(16).padStart(6, '0') +
                     tokenOut.address.slice(2);
    }
    
    return '0x' + encodedPath;
  }

  /**
   * Estimate gas for multi-hop swap
   */
  private async estimateMultiHopGas(path: Token[], amountIn: string): Promise<number> {
    const encodedPath = this.encodePath(path);
    
    const gasEstimate = await this.router.estimateGas.exactInput({
      path: encodedPath,
      recipient: await this.signer.getAddress(),
      deadline: Math.floor(Date.now() / 1000) + 60 * 20,
      amountIn: amountIn,
      amountOutMinimum: '0'
    });
    
    return gasEstimate.toNumber();
  }

  async executeSwap(params: SwapParams): Promise<SwapResult> {
    // Add security validation
    await this.validateTrade(params);

    const { tokenIn, tokenOut, amountIn } = params;
    const startTime = Date.now();
    
    try {
      // Get and validate price
      const price = await this.getPrice(tokenIn, tokenOut);
      const isValidPrice = await this.priceFeed.validatePrice(
        tokenIn,
        tokenOut,
        price
      );

      if (!isValidPrice) {
        throw new Error('Invalid price data');
      }

      // Approve token if needed
      await this.approveToken(tokenIn, amountIn);
      
      // Execute swap with additional security checks
      const tx = await this.router.exactInputSingle({
        tokenIn: tokenIn.address,
        tokenOut: tokenOut.address,
        fee: await this.getPoolFee(await this.getPoolAddress(tokenIn, tokenOut)),
        recipient: await this.signer.getAddress(),
        deadline: Math.floor(Date.now() / 1000) + 60 * 20,
        amountIn: amountIn,
        amountOutMinimum: '0',
        sqrtPriceLimitX96: '0'
      });
      
      // Wait for transaction with timeout
      const receipt = await Promise.race([
        tx.wait(),
        new Promise((_, reject) => 
          setTimeout(() => reject(new Error('Transaction timeout')), 300000)
        )
      ]);
      
      // Get amount out from event logs
      const amountOut = this.getAmountOutFromLogs(receipt.logs);
      
      const result: SwapResult = {
        transactionHash: receipt.transactionHash,
        amountOut,
        priceImpact: await this.calculatePriceImpact(
          await this.getPoolAddress(tokenIn, tokenOut),
          tokenIn,
          tokenOut,
          amountIn
        ),
        gasUsed: receipt.gasUsed.toNumber(),
        gasPrice: receipt.effectiveGasPrice.toString(),
        executionTime: Date.now() - startTime
      };

      // Record trade in monitor
      this.monitor.recordTrade(result, tokenIn, tokenOut);

      // Update price feed
      await this.priceFeed.updatePrice(
        tokenIn,
        tokenOut,
        price,
        'uniswap-v3',
        0.9 // 90% confidence for on-chain prices
      );

      return result;
    } catch (error) {
      // Record failed trade
      this.monitor.recordTrade({
        transactionHash: '',
        amountOut: '0',
        priceImpact: 0,
        gasUsed: 0,
        gasPrice: '0',
        executionTime: Date.now() - startTime
      }, tokenIn, tokenOut);

      throw error;
    }
  }

  async getLiquidity(tokenA: Token, tokenB: Token): Promise<{
    reserveA: string;
    reserveB: string;
    totalSupply: string;
  }> {
    const poolAddress = await this.getPoolAddress(tokenA, tokenB);
    const pool = new ethers.Contract(poolAddress, IUniswapV3PoolABI, this.provider);
    
    const [token0, token1] = tokenA.address.toLowerCase() < tokenB.address.toLowerCase()
      ? [tokenA, tokenB]
      : [tokenB, tokenA];
    
    const liquidity = await pool.liquidity();
    const slot0 = await pool.slot0();
    const sqrtPriceX96 = slot0[0];
    
    // Calculate reserves from liquidity and price
    const reserves = await this.calculateReserves(
      pool,
      liquidity,
      sqrtPriceX96,
      token0,
      token1
    );
    
    return {
      reserveA: reserves[0].toString(),
      reserveB: reserves[1].toString(),
      totalSupply: liquidity.toString()
    };
  }

  async getPrice(tokenA: Token, tokenB: Token): Promise<string> {
    const poolAddress = await this.getPoolAddress(tokenA, tokenB);
    const pool = new ethers.Contract(poolAddress, IUniswapV3PoolABI, this.provider);
    
    const slot0 = await pool.slot0();
    const sqrtPriceX96 = slot0[0];
    
    return this.calculatePrice(sqrtPriceX96, tokenA, tokenB);
  }

  async getPool(tokenA: Token, tokenB: Token): Promise<{
    address: string;
    fee: number;
    tickSpacing: number;
  }> {
    const poolAddress = await this.getPoolAddress(tokenA, tokenB);
    const pool = new ethers.Contract(poolAddress, IUniswapV3PoolABI, this.provider);
    
    const fee = await this.getPoolFee(pool);
    const tickSpacing = await pool.tickSpacing();
    
    return {
      address: poolAddress,
      fee,
      tickSpacing
    };
  }

  async getTokenBalance(token: Token, address: string): Promise<string> {
    const contract = new ethers.Contract(token.address, ERC20ABI, this.provider);
    return (await contract.balanceOf(address)).toString();
  }

  async approveToken(token: Token, amount: string): Promise<string> {
    const contract = new ethers.Contract(token.address, ERC20ABI, this.signer);
    const routerAddress = this.router.address;
    
    const allowance = await contract.allowance(
      await this.signer.getAddress(),
      routerAddress
    );
    
    if (allowance.lt(amount)) {
      const tx = await contract.approve(routerAddress, amount);
      return tx.hash;
    }
    
    return '';
  }

  async estimateGas(params: SwapParams): Promise<number> {
    const { tokenIn, tokenOut, amountIn } = params;
    
    const gasEstimate = await this.router.estimateGas.exactInputSingle({
      tokenIn: tokenIn.address,
      tokenOut: tokenOut.address,
      fee: await this.getPoolFee(await this.getPoolAddress(tokenIn, tokenOut)),
      recipient: await this.signer.getAddress(),
      deadline: Math.floor(Date.now() / 1000) + 60 * 20,
      amountIn: amountIn,
      amountOutMinimum: '0',
      sqrtPriceLimitX96: '0'
    });
    
    return gasEstimate.toNumber();
  }

  async getGasPrice(): Promise<string> {
    return (await this.provider.getGasPrice()).toString();
  }

  getChainId(): number {
    return this.chainId;
  }

  getProvider(): ethers.JsonRpcProvider {
    return this.provider;
  }

  getSigner(): ethers.Wallet {
    return this.signer;
  }

  // Helper methods
  private async getPoolAddress(tokenA: Token, tokenB: Token): Promise<string> {
    const factoryAddress = '0x1F98431c8aD98523631AE4a59f267346ea31F984';
    const factory = new ethers.Contract(
      factoryAddress,
      ['function getPool(address,address,uint24) view returns (address)'],
      this.provider
    );
    
    return factory.getPool(tokenA.address, tokenB.address, 3000); // Using 0.3% fee tier
  }

  private async getPoolFee(pool: ethers.Contract): Promise<number> {
    return pool.fee();
  }

  private async calculatePriceImpact(
    pool: ethers.Contract,
    tokenIn: Token,
    tokenOut: Token,
    amountIn: string
  ): Promise<number> {
    const slot0 = await pool.slot0();
    const sqrtPriceX96 = slot0[0];
    const currentPrice = this.calculatePrice(sqrtPriceX96, tokenIn, tokenOut);
    
    const quote = await this.getQuote({
      tokenIn,
      tokenOut,
      amountIn
    });
    
    const executionPrice = parseFloat(quote.amountOut) / parseFloat(amountIn);
    return Math.abs((executionPrice - parseFloat(currentPrice)) / parseFloat(currentPrice)) * 100;
  }

  private calculatePrice(
    sqrtPriceX96: ethers.BigNumber,
    tokenA: Token,
    tokenB: Token
  ): string {
    const price = sqrtPriceX96.mul(sqrtPriceX96).mul(ethers.BigNumber.from(10).pow(tokenA.decimals))
      .div(ethers.BigNumber.from(2).pow(192))
      .div(ethers.BigNumber.from(10).pow(tokenB.decimals));
    
    return price.toString();
  }

  private async calculateReserves(
    pool: ethers.Contract,
    liquidity: ethers.BigNumber,
    sqrtPriceX96: ethers.BigNumber,
    token0: Token,
    token1: Token
  ): Promise<[ethers.BigNumber, ethers.BigNumber]> {
    // This is a simplified calculation. In reality, you'd need to use the full
    // Uniswap V3 math to calculate reserves from liquidity and price
    const price = this.calculatePrice(sqrtPriceX96, token0, token1);
    const sqrtPrice = ethers.utils.parseUnits(price, token1.decimals);
    
    const reserve0 = liquidity.mul(sqrtPrice).div(ethers.BigNumber.from(2).pow(96));
    const reserve1 = liquidity.div(sqrtPrice);
    
    return [reserve0, reserve1];
  }

  private getAmountOutFromLogs(logs: ethers.providers.Log[]): string {
    // Find the Swap event and extract amountOut
    const swapEvent = logs.find(log => {
      try {
        return this.router.interface.parseLog(log).name === 'ExactInputSingle';
      } catch {
        return false;
      }
    });
    
    if (!swapEvent) {
      throw new Error('Swap event not found in logs');
    }
    
    const parsedLog = this.router.interface.parseLog(swapEvent);
    return parsedLog.args.amountOut.toString();
  }

  // Add monitoring methods
  public getMetrics() {
    return this.monitor.getMetrics();
  }

  public getHealth() {
    return this.monitor.getHealth();
  }

  public clearErrors() {
    this.monitor.clearErrors();
  }

  public clearWarnings() {
    this.monitor.clearWarnings();
  }

  // Add price feed methods
  public async getLatestPrice(tokenA: Token, tokenB: Token) {
    return this.priceFeed.getLatestPrice(tokenA, tokenB);
  }

  public async getPriceHistory(tokenA: Token, tokenB: Token, limit?: number) {
    return this.priceFeed.getPriceHistory(tokenA, tokenB, limit);
  }

  public isPriceFeedStale() {
    return this.priceFeed.isStale();
  }
} 