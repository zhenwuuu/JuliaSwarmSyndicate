// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract JuliaMarketplace is Ownable, ReentrancyGuard {
    struct Module {
        address publisher;
        string name;
        string description;
        uint256 price;
        bool isListed;
    }

    struct Item {
        address seller;
        string name;
        string description;
        uint256 price;
        bool isListed;
    }

    mapping(uint256 => Module) public modules;
    mapping(uint256 => Item) public items;
    uint256 public moduleCount;
    uint256 public itemCount;
    uint256 public platformFee = 25; // 2.5% fee

    event ModulePublished(uint256 indexed moduleId, address indexed publisher, string name, uint256 price);
    event ModulePurchased(uint256 indexed moduleId, address indexed buyer, address indexed seller, uint256 price);
    event ItemListed(uint256 indexed itemId, address indexed seller, string name, uint256 price);
    event PlatformFeeUpdated(uint256 newFee);

    constructor() Ownable(msg.sender) {}

    function publishModule(string memory name, string memory description, uint256 price) external {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(price > 0, "Price must be greater than 0");

        moduleCount++;
        modules[moduleCount] = Module({
            publisher: msg.sender,
            name: name,
            description: description,
            price: price,
            isListed: true
        });

        emit ModulePublished(moduleCount, msg.sender, name, price);
    }

    function purchaseModule(uint256 moduleId) external payable nonReentrant {
        require(moduleId > 0 && moduleId <= moduleCount, "Invalid module ID");
        Module storage module = modules[moduleId];
        require(module.isListed, "Module is not listed");
        require(msg.value >= module.price, "Insufficient payment");

        uint256 fee = (module.price * platformFee) / 1000;
        uint256 payment = module.price - fee;

        (bool success, ) = module.publisher.call{value: payment}("");
        require(success, "Transfer to publisher failed");

        emit ModulePurchased(moduleId, msg.sender, module.publisher, module.price);
    }

    function listItem(string memory name, string memory description, uint256 price) external {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(price > 0, "Price must be greater than 0");

        itemCount++;
        items[itemCount] = Item({
            seller: msg.sender,
            name: name,
            description: description,
            price: price,
            isListed: true
        });

        emit ItemListed(itemCount, msg.sender, name, price);
    }

    function updatePlatformFee(uint256 newFee) external onlyOwner {
        require(newFee <= 100, "Fee cannot exceed 10%");
        platformFee = newFee;
        emit PlatformFeeUpdated(newFee);
    }

    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");
        
        (bool success, ) = owner().call{value: balance}("");
        require(success, "Fee withdrawal failed");
    }
} 