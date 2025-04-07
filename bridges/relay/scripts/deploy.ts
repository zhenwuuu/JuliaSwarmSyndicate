import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  const TestToken = await ethers.getContractFactory("TestToken");
  console.log("Deploying TestToken...");
  const token = await TestToken.deploy();
  console.log("TestToken deployed to:", await token.getAddress());

  // Mint some tokens to the deployer
  const mintAmount = "1000000000000000000000"; // 1000 tokens
  console.log("Minting tokens...");
  const mintTx = await token.mint(deployer.address, mintAmount);
  console.log("Waiting for minting transaction to be mined...");
  await mintTx.wait();
  console.log("Minted 1000 tokens to", deployer.address);

  // Get balance
  const balance = await token.balanceOf(deployer.address);
  console.log("Current balance:", balance.toString(), "TEST");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 