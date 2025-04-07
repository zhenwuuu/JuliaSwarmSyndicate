import { ethers } from 'ethers';
import config from '../src/config/config';

interface TransactionError extends Error {
  transaction?: ethers.providers.TransactionResponse;
  receipt?: ethers.providers.TransactionReceipt;
}

async function main() {
  try {
    // Initialize provider and wallet
    const provider = new ethers.providers.StaticJsonRpcProvider(config.base.rpcUrl, {
      name: 'base-sepolia',
      chainId: 84532
    });

    // Wait for provider to be ready and get network info
    const network = await provider.getNetwork();
    console.log('Connected to network:', {
      name: network.name,
      chainId: network.chainId
    });

    // Create wallet directly with private key
    const wallet = new ethers.Wallet(config.base.privateKey).connect(provider);
    console.log('Wallet address:', await wallet.getAddress());

    // ERC20 interface
    const erc20Abi = [
      "function approve(address spender, uint256 amount) returns (bool)",
      "function allowance(address owner, address spender) view returns (uint256)",
      "function balanceOf(address account) view returns (uint256)"
    ];

    // Initialize ERC20 contract
    const testToken = "0x6C718AE972a65C2B7725599390Ffa625945355F5";
    const tokenContract = new ethers.Contract(testToken, erc20Abi, wallet);

    // Check balance
    const balance = await tokenContract.balanceOf(await wallet.getAddress());
    console.log('Token balance:', ethers.utils.formatEther(balance), 'TEST');

    // Bridge contract interface
    const bridgeAbi = [
      "event TokensBridged(address indexed token, address indexed sender, address indexed recipient, uint256 amount, uint256 targetChainId, bytes32 messageHash)",
      "event TokensClaimed(address indexed token, address indexed recipient, uint256 amount, uint256 sourceChainId, bytes32 messageHash)",
      "function bridge(address token, uint256 amount, address recipient, uint256 targetChainId) returns (bytes32)",
      "function claim(bytes32 messageHash, address recipient, uint256 amount, address token) returns (bool)",
      "function setSupportedToken(uint256 chainId, address token, bool supported)",
      "function setChainConfig(uint256 chainId, uint256 minAmount, uint256 maxAmount, uint256 feePercentage, uint256 fixedFee, bool enabled)",
      "function supportedTokens(uint256, address) view returns (bool)",
      "function chainConfigs(uint256) view returns (uint256 minAmount, uint256 maxAmount, uint256 feePercentage, uint256 fixedFee, bool enabled)"
    ];

    // Initialize bridge contract
    const bridgeContract = new ethers.Contract(
      config.base.bridgeContract,
      bridgeAbi,
      wallet
    );

    console.log('Bridge contract address:', bridgeContract.address);

    // Check if token is supported
    const chainId = 84532; // Base Sepolia
    const isSupported = await bridgeContract.supportedTokens(chainId, testToken);
    if (!isSupported) {
      console.log('Token not supported, enabling it...');
      const supportTx = await bridgeContract.setSupportedToken(chainId, testToken, true);
      await supportTx.wait();
      console.log('Token enabled successfully');
    }

    // Check chain configuration
    const chainConfig = await bridgeContract.chainConfigs(chainId);
    if (!chainConfig.enabled) {
      console.log('Chain not configured, setting up configuration...');
      const configTx = await bridgeContract.setChainConfig(
        chainId,
        ethers.utils.parseEther('0.01'), // minAmount
        ethers.utils.parseEther('1000'), // maxAmount
        25, // feePercentage (0.25%)
        ethers.utils.parseEther('0.001'), // fixedFee
        true // enabled
      );
      await configTx.wait();
      console.log('Chain configuration set successfully');
    }

    const amount = ethers.utils.parseEther("1.0"); // 1 token
    
    // Convert Solana program ID to a valid Ethereum address format
    const recipient = "0x" + "0".repeat(24) + config.solana.programId.slice(0, 16);

    // Check allowance
    const allowance = await tokenContract.allowance(await wallet.getAddress(), bridgeContract.address);
    if (allowance.lt(amount)) {
      console.log('Approving bridge contract to spend tokens...');
      const approveTx = await tokenContract.approve(bridgeContract.address, amount);
      console.log('Approval transaction sent:', approveTx.hash);
      await approveTx.wait();
      console.log('Approval transaction confirmed');
    } else {
      console.log('Bridge contract already has sufficient allowance');
    }
    
    // Send transaction
    console.log('Sending transaction with params:', {
      token: testToken,
      amount: amount.toString(),
      recipient,
      targetChainId: chainId
    });

    const tx = await bridgeContract.bridge(testToken, amount, recipient, chainId, {
      gasLimit: 500000 // Set a reasonable gas limit
    });
    console.log('Transaction sent:', tx.hash);

    // Wait for transaction to be mined
    console.log('Waiting for transaction to be mined...');
    const receipt = await tx.wait();
    if (!receipt) {
      throw new Error('Transaction receipt not found');
    }

    console.log('Transaction mined:', receipt.transactionHash);
    console.log('Block number:', receipt.blockNumber);
    console.log('Gas used:', receipt.gasUsed.toString());
    console.log('Status:', receipt.status === 1 ? 'Success' : 'Failed');

    // Check for TokensBridged event
    if (receipt.logs && receipt.logs.length > 0) {
      console.log('Transaction logs:', receipt.logs);
      
      const eventInterface = new ethers.utils.Interface([
        "event TokensBridged(address indexed token, address indexed sender, address indexed recipient, uint256 amount, uint256 targetChainId, bytes32 messageHash)"
      ]);

      for (const log of receipt.logs) {
        try {
          const parsedLog = eventInterface.parseLog(log);
          if (parsedLog && parsedLog.name === 'TokensBridged') {
            console.log('Event decoded:', {
              token: parsedLog.args.token,
              sender: parsedLog.args.sender,
              recipient: parsedLog.args.recipient,
              amount: parsedLog.args.amount.toString(),
              targetChainId: parsedLog.args.targetChainId.toString(),
              messageHash: parsedLog.args.messageHash
            });
            break;
          }
        } catch (e) {
          // Skip logs that don't match our event
          continue;
        }
      }
    } else {
      console.log('No logs found in transaction');
    }
  } catch (error) {
    console.error('Error:', error);
    const txError = error as TransactionError;
    if (txError.transaction) {
      console.error('Transaction details:', txError.transaction);
    }
    if (txError.receipt) {
      console.error('Transaction receipt:', txError.receipt);
    }
  }
}

main().catch(console.error); 