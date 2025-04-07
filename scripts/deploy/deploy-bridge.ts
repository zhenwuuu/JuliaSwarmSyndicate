import { ethers } from "hardhat";
import fs from "fs";
import path from "path";

async function main() {
  console.log("Deploying JuliaBridge contract...");

  // Deploy the JuliaBridge contract
  const JuliaBridge = await ethers.getContractFactory("JuliaBridge");
  const bridge = await JuliaBridge.deploy();
  await bridge.waitForDeployment();

  const bridgeAddress = await bridge.getAddress();
  console.log("JuliaBridge deployed to:", bridgeAddress);

  // Deploy a test token
  console.log("Deploying TestToken contract...");
  const TestToken = await ethers.getContractFactory("TestToken");
  const token = await TestToken.deploy();
  await token.waitForDeployment();

  const tokenAddress = await token.getAddress();
  console.log("TestToken deployed to:", tokenAddress);

  // Set up the bridge configuration
  console.log("Configuring bridge...");
  
  // Enable the test token on the current chain
  const tx1 = await bridge.setSupportedToken(
    84532, // Base Sepolia
    tokenAddress,
    true
  );
  await tx1.wait();
  console.log("TestToken enabled on bridge");

  // Set chain configuration
  const tx2 = await bridge.setChainConfig(
    101, // Solana Devnet
    ethers.parseUnits("0.01", 18), // minAmount
    ethers.parseUnits("1000", 18), // maxAmount
    25, // feePercentage (0.25%)
    ethers.parseUnits("0.001", 18), // fixedFee
    true // enabled
  );
  await tx2.wait();
  console.log("Chain configuration set");

  // Update .env file with deployed addresses
  try {
    const envPath = path.resolve(__dirname, "../.env");
    let envContent = fs.readFileSync(envPath, "utf8");
    
    envContent = envContent.replace(/BASE_SEPOLIA_BRIDGE_ADDRESS=.*/, `BASE_SEPOLIA_BRIDGE_ADDRESS=${bridgeAddress}`);
    envContent = envContent.replace(/BASE_SEPOLIA_TEST_TOKEN_ADDRESS=.*/, `BASE_SEPOLIA_TEST_TOKEN_ADDRESS=${tokenAddress}`);
    
    fs.writeFileSync(envPath, envContent);
    console.log("Updated .env file with deployed contract addresses");
  } catch (error) {
    console.error("Failed to update .env file:", error);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}); 