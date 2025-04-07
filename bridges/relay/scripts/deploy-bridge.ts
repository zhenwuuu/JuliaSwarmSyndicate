import hre from "hardhat";

async function main() {
  console.log("Getting signers...");
  const signers = await hre.ethers.getSigners();
  console.log("Signers:", signers.length);
  
  if (signers.length === 0) {
    console.error("No signers available. Check your private key in the .env file.");
    process.exit(1);
  }
  
  const deployer = signers[0];
  console.log("Deployer address:", deployer.address);

  // Deploy JuliaBridge contract
  console.log("Deploying JuliaBridge contract...");
  const JuliaBridge = await hre.ethers.getContractFactory("JuliaBridge");
  const bridge = await JuliaBridge.deploy();
  await bridge.waitForDeployment();

  const bridgeAddress = await bridge.getAddress();
  console.log("JuliaBridge deployed to:", bridgeAddress);

  // Add the contract address to .env
  console.log("\nAdd this line to your .env file:");
  console.log(`BASE_BRIDGE_CONTRACT=${bridgeAddress}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error in deployment:", error);
    process.exit(1);
  }); 