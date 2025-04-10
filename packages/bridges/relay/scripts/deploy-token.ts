import hre from "hardhat";

async function main() {
  console.log("Getting signers...");
  const signers = await hre.ethers.getSigners();
  
  if (signers.length === 0) {
    console.error("No signers available. Check your private key in the .env file.");
    process.exit(1);
  }
  
  const deployer = signers[0];
  console.log("Deployer address:", deployer.address);

  // Deploy TestToken contract
  console.log("Deploying TestToken contract...");
  const TestToken = await hre.ethers.getContractFactory("TestToken");
  const token = await TestToken.deploy();
  await token.waitForDeployment();

  const tokenAddress = await token.getAddress();
  console.log("TestToken deployed to:", tokenAddress);
  
  // Mint some tokens to the deployer
  console.log("Minting tokens to deployer...");
  const mintAmount = hre.ethers.parseEther("1000");
  const mintTx = await token.mint(deployer.address, mintAmount);
  await mintTx.wait();
  
  console.log(`Minted ${hre.ethers.formatEther(mintAmount)} tokens to ${deployer.address}`);
  
  // Add the token address to .env
  console.log("\nAdd this line to your .env file:");
  console.log(`BASE_TEST_TOKEN=${tokenAddress}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error in deployment:", error);
    process.exit(1);
  }); 