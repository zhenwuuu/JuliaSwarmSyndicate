// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract JuliaBridge is Ownable, ReentrancyGuard, Pausable {
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

    constructor() Ownable(msg.sender) {}

    function bridge(
        address token,
        uint256 amount,
        address recipient,
        uint256 targetChainId
    ) external payable nonReentrant whenNotPaused returns (bytes32) {
        require(supportedTokens[targetChainId][token], "Token not supported");
        require(chainConfigs[targetChainId].enabled, "Chain not supported");
        require(amount >= chainConfigs[targetChainId].minAmount, "Amount below minimum");
        require(amount <= chainConfigs[targetChainId].maxAmount, "Amount above maximum");
        require(recipient != address(0), "Invalid recipient");

        // Calculate fees
        uint256 feeAmount = (amount * chainConfigs[targetChainId].feePercentage) / 10000;
        feeAmount += chainConfigs[targetChainId].fixedFee;
        uint256 netAmount = amount - feeAmount;

        // Transfer tokens to this contract
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        // Generate message hash
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                msg.sender,
                recipient,
                netAmount,
                block.chainid,
                targetChainId,
                token
            )
        );

        emit TokensBridged(
            token,
            msg.sender,
            recipient,
            netAmount,
            targetChainId,
            messageHash
        );

        return messageHash;
    }

    function claim(
        bytes32 messageHash,
        address recipient,
        uint256 amount,
        address token
    ) external nonReentrant whenNotPaused returns (bool) {
        require(!processedMessages[messageHash], "Message already processed");
        require(supportedTokens[block.chainid][token], "Token not supported");

        processedMessages[messageHash] = true;

        // Transfer tokens to recipient
        IERC20(token).transfer(recipient, amount);

        emit TokensClaimed(
            token,
            recipient,
            amount,
            block.chainid,
            messageHash
        );

        return true;
    }

    function setSupportedToken(
        uint256 chainId,
        address token,
        bool supported
    ) external onlyOwner {
        supportedTokens[chainId][token] = supported;
    }

    function setChainConfig(
        uint256 chainId,
        uint256 minAmount,
        uint256 maxAmount,
        uint256 feePercentage,
        uint256 fixedFee,
        bool enabled
    ) external onlyOwner {
        require(feePercentage <= 1000, "Fee too high"); // Max 10%
        chainConfigs[chainId] = BridgeConfig({
            minAmount: minAmount,
            maxAmount: maxAmount,
            feePercentage: feePercentage,
            fixedFee: fixedFee,
            enabled: enabled
        });
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function withdrawFees(
        address token,
        address recipient,
        uint256 amount
    ) external onlyOwner {
        IERC20(token).transfer(recipient, amount);
    }
} 