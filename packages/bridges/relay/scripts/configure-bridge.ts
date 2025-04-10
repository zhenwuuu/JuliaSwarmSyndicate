import hre from "hardhat";
import dotenv from "dotenv";

dotenv.config();

async function main() {
  console.log("Getting signers...");
  const signers = await hre.ethers.getSigners();
  
  if (signers.length === 0) {
    console.error("No signers available. Check your private key in the .env file.");
    process.exit(1);
  }
  
  const deployer = signers[0];
  console.log("Configuring bridge with account:", deployer.address);

  // Get contract addresses from env
  const bridgeAddress = process.env.BASE_BRIDGE_CONTRACT;
  const tokenAddress = process.env.BASE_TEST_TOKEN;
  
  if (!bridgeAddress) {
    console.error("Missing BASE_BRIDGE_CONTRACT in .env file");
    process.exit(1);
  }
  
  if (!tokenAddress) {
    console.error("Missing BASE_TEST_TOKEN in .env file");
    process.exit(1);
  }

  console.log(`Bridge address: ${bridgeAddress}`);
  console.log(`Token address: ${tokenAddress}`);

  // Get contracts
  const bridge = await hre.ethers.getContractAt("JuliaBridge", bridgeAddress);
  const token = await hre.ethers.getContractAt("TestToken", tokenAddress);

  // Configure bridge to support our token
  console.log("Setting token as supported...");
  const chainId = parseInt(process.env.BASE_CHAIN_ID || "84532");
  const setSupportedTx = await bridge.setSupportedToken(chainId, tokenAddress, true);
  await setSupportedTx.wait();
  console.log(`Set token ${tokenAddress} as supported for chain ${chainId}`);

  // Approve the bridge to spend tokens
  console.log("Approving bridge to spend tokens...");
  const approveAmount = hre.ethers.parseEther("1000");
  const approveTx = await token.approve(bridgeAddress, approveAmount);
  await approveTx.wait();
  console.log(`Approved bridge to spend ${hre.ethers.formatEther(approveAmount)} tokens`);

  console.log("Bridge configuration complete!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error in configuration:", error);
    process.exit(1);
  }); 