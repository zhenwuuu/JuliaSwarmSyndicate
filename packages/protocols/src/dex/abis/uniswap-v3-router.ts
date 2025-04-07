export const IUniswapV3RouterABI = [
  'function exactInputSingle(tuple(address tokenIn, address tokenOut, uint24 fee, address recipient, uint256 deadline, uint256 amountIn, uint256 amountOutMinimum, uint160 sqrtPriceLimitX96) params) external payable returns (uint256 amountOut)',
  'function exactInput(tuple(bytes path, address recipient, uint256 deadline, uint256 amountIn, uint256 amountOutMinimum) params) external payable returns (uint256 amountOut)',
  'function exactOutputSingle(tuple(address tokenIn, address tokenOut, uint24 fee, address recipient, uint256 deadline, uint256 amountOut, uint256 amountInMaximum, uint160 sqrtPriceLimitX96) params) external payable returns (uint256 amountIn)',
  'function exactOutput(tuple(bytes path, address recipient, uint256 deadline, uint256 amountOut, uint256 amountInMaximum) params) external payable returns (uint256 amountIn)',
  'function quoteExactInputSingle(address tokenIn, address tokenOut, uint24 fee, uint256 amountIn, uint160 sqrtPriceLimitX96) external returns (uint256 amountOut)',
  'function quoteExactInput(bytes path, uint256 amountIn) external returns (uint256 amountOut)',
  'function quoteExactOutputSingle(address tokenIn, address tokenOut, uint24 fee, uint256 amountOut, uint160 sqrtPriceLimitX96) external returns (uint256 amountIn)',
  'function quoteExactOutput(bytes path, uint256 amountOut) external returns (uint256 amountIn)',
  'event ExactInputSingle(address indexed tokenIn, address indexed tokenOut, uint24 indexed fee, uint256 amountIn, uint256 amountOut)',
  'event ExactInput(bytes path, uint256 amountIn, uint256 amountOut)',
  'event ExactOutputSingle(address indexed tokenIn, address indexed tokenOut, uint24 indexed fee, uint256 amountOut, uint256 amountIn)',
  'event ExactOutput(bytes path, uint256 amountOut, uint256 amountIn)'
]; 