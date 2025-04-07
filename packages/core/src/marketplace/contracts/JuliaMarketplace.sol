// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract JuliaMarketplace is ERC721, ReentrancyGuard, Ownable {
    struct Module {
        string name;
        string moduleType;    // AI, Platform, Action, UI
        string metadataURI;  // IPFS URI containing module metadata
        address creator;
        uint256 price;
        bool isActive;
    }

    struct ModuleLicense {
        uint256 moduleId;
        address licensee;
        uint256 expiryTime;  // 0 for perpetual
    }

    mapping(uint256 => Module) public modules;
    mapping(uint256 => ModuleLicense) public licenses;
    
    uint256 private _moduleCounter;
    uint256 private _licenseCounter;
    
    uint256 public platformFee = 25;  // 2.5%
    
    event ModulePublished(uint256 indexed moduleId, address creator, string name);
    event ModulePurchased(uint256 indexed moduleId, address buyer, uint256 licenseId);
    event ModuleUpdated(uint256 indexed moduleId, string metadataURI);
    event PlatformFeeUpdated(uint256 newFee);

    constructor() ERC721("Julia Modules", "JULIA") Ownable(msg.sender) {}

    function publishModule(
        string memory name,
        string memory moduleType,
        string memory metadataURI,
        uint256 price
    ) external returns (uint256) {
        _moduleCounter++;
        
        modules[_moduleCounter] = Module(
            name,
            moduleType,
            metadataURI,
            msg.sender,
            price,
            true
        );

        _mint(msg.sender, _moduleCounter);
        
        emit ModulePublished(_moduleCounter, msg.sender, name);
        return _moduleCounter;
    }

    function purchaseModule(uint256 moduleId) external payable nonReentrant {
        Module storage module = modules[moduleId];
        require(module.isActive, "Module not available");
        require(msg.value >= module.price, "Insufficient payment");

        // Calculate platform fee
        uint256 fee = (msg.value * platformFee) / 1000;
        uint256 creatorPayment = msg.value - fee;

        // Create license
        _licenseCounter++;
        licenses[_licenseCounter] = ModuleLicense(
            moduleId,
            msg.sender,
            0  // Perpetual license
        );

        // Transfer payments
        (bool feeSuccess, ) = owner().call{value: fee}("");
        require(feeSuccess, "Fee transfer failed");
        
        (bool paymentSuccess, ) = module.creator.call{value: creatorPayment}("");
        require(paymentSuccess, "Creator payment failed");

        emit ModulePurchased(moduleId, msg.sender, _licenseCounter);
    }

    function updateModule(
        uint256 moduleId,
        string memory newMetadataURI
    ) external {
        require(ownerOf(moduleId) == msg.sender, "Not module owner");
        modules[moduleId].metadataURI = newMetadataURI;
        emit ModuleUpdated(moduleId, newMetadataURI);
    }

    function setPlatformFee(uint256 newFee) external onlyOwner {
        require(newFee <= 100, "Fee too high"); // Max 10%
        platformFee = newFee;
        emit PlatformFeeUpdated(newFee);
    }

    function validateLicense(
        uint256 licenseId,
        address licensee
    ) external view returns (bool) {
        ModuleLicense memory license = licenses[licenseId];
        return license.licensee == licensee &&
            (license.expiryTime == 0 || license.expiryTime > block.timestamp);
    }

    function getModule(uint256 moduleId) external view returns (
        string memory name,
        string memory moduleType,
        string memory metadataURI,
        address creator,
        uint256 price,
        bool isActive
    ) {
        Module memory module = modules[moduleId];
        return (
            module.name,
            module.moduleType,
            module.metadataURI,
            module.creator,
            module.price,
            module.isActive
        );
    }
} 