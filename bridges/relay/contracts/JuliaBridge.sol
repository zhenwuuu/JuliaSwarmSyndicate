// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract JuliaBridge is Ownable, ReentrancyGuard {
    struct BridgeConfig {
        uint256 minAmount;
        uint256 maxAmount;
        uint256 feePercentage; // In basis points (1/10000)
        uint256 fixedFee;
        bool enabled;
    }

    mapping(uint256 => mapping(address => bool)) public supportedTokens;
    mapping(uint256 => BridgeConfig) public chainConfigs;
    mapping(bytes32 => bool) public processedMessages;
    
    bool public paused = false;
    
    event TokensBridged(
        address indexed token,
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        uint256 targetChainId,
        bytes32 messageHash
    );
    
    event TokensClaimed(
        address indexed token,
        address indexed recipient,
        uint256 amount,
        uint256 sourceChainId,
        bytes32 messageHash
    );
    
    constructor() Ownable(msg.sender) {
        // Initialize with default values
    }
    
    modifier whenNotPaused() {
        require(!paused, "Bridge: paused");
        _;
    }
    
    function pause() external onlyOwner {
        paused = true;
    }
    
    function unpause() external onlyOwner {
        paused = false;
    }

    function setChainConfig(
        uint256 chainId,
        uint256 minAmount,
        uint256 maxAmount,
        uint256 feePercentage,
        uint256 fixedFee,
        bool enabled
    ) external onlyOwner {
        require(minAmount <= maxAmount, "Min amount must be <= max amount");
        require(feePercentage <= 10000, "Fee percentage must be <= 10000");
        
        chainConfigs[chainId] = BridgeConfig({
            minAmount: minAmount,
            maxAmount: maxAmount,
            feePercentage: feePercentage,
            fixedFee: fixedFee,
            enabled: enabled
        });
    }

    function setSupportedToken(
        uint256 chainId,
        address token,
        bool supported
    ) external onlyOwner {
        supportedTokens[chainId][token] = supported;
    }

    function calculateFee(uint256 amount, uint256 targetChainId) public view returns (uint256) {
        BridgeConfig memory config = chainConfigs[targetChainId];
        uint256 percentageFee = (amount * config.feePercentage) / 10000;
        return percentageFee + config.fixedFee;
    }

    function bridge(
        address token,
        uint256 amount,
        address recipient,
        uint256 targetChainId
    ) external nonReentrant whenNotPaused returns (bytes32) {
        BridgeConfig memory config = chainConfigs[targetChainId];
        require(config.enabled, "Target chain not enabled");
        require(supportedTokens[block.chainid][token], "Token not supported");
        require(amount >= config.minAmount, "Amount too small");
        require(amount <= config.maxAmount, "Amount too large");

        uint256 fee = calculateFee(amount, targetChainId);
        uint256 amountAfterFee = amount - fee;
        
        // Transfer tokens to this contract
        require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Token transfer failed");
        
        // Generate unique message hash
        bytes32 messageHash = keccak256(abi.encodePacked(
            token,
            msg.sender,
            recipient,
            amountAfterFee,
            targetChainId,
            block.timestamp,
            block.chainid
        ));
        
        emit TokensBridged(token, msg.sender, recipient, amountAfterFee, targetChainId, messageHash);
        
        return messageHash;
    }

    function claim(
        bytes32 messageHash,
        address recipient,
        uint256 amount,
        address token
    ) external nonReentrant whenNotPaused returns (bool) {
        require(!processedMessages[messageHash], "Message already processed");
        processedMessages[messageHash] = true;
        
        require(IERC20(token).transfer(recipient, amount), "Token transfer failed");
        
        emit TokensClaimed(token, recipient, amount, 0, messageHash);
        
        return true;
    }
    
    function withdraw(
        address token,
        uint256 amount
    ) external onlyOwner {
        require(IERC20(token).transfer(owner(), amount), "Token transfer failed");
    }
    
    function withdrawETH() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
} 