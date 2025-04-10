import hre from "hardhat";
import dotenv from "dotenv";

dotenv.config();

async function main() {
  console.log("Configuring Solana chain on the bridge");
  
  // Get signer
  const [signer] = await hre.ethers.getSigners();
  console.log("Using account:", signer.address);
  
  // Get bridge address from env
  const bridgeAddress = process.env.BASE_BRIDGE_CONTRACT;
  
  if (!bridgeAddress) {
    console.error("Missing BASE_BRIDGE_CONTRACT in .env file");
    process.exit(1);
  }
  
  console.log(`Bridge address: ${bridgeAddress}`);

  // Get bridge contract
  const bridge = await hre.ethers.getContractAt("JuliaBridge", bridgeAddress);
  
  // Configuration parameters for Solana
  const solanaChainId = parseInt(process.env.SOLANA_CHAIN_ID || "101");
  const minAmount = hre.ethers.parseEther("0.01");  // 0.01 tokens minimum
  const maxAmount = hre.ethers.parseEther("1000");  // 1000 tokens maximum
  const feePercentage = 25;  // 0.25% fee
  const fixedFee = hre.ethers.parseEther("0.001");  // 0.001 tokens fixed fee
  const enabled = true;
  
  console.log(`Configuring Solana chain (ID: ${solanaChainId})`);
  console.log(`Min amount: ${hre.ethers.formatEther(minAmount)}`);
  console.log(`Max amount: ${hre.ethers.formatEther(maxAmount)}`);
  console.log(`Fee percentage: ${feePercentage / 100}%`);
  console.log(`Fixed fee: ${hre.ethers.formatEther(fixedFee)}`);
  console.log(`Enabled: ${enabled}`);
  
  // Set chain configuration
  const tx = await bridge.setChainConfig(
    solanaChainId,
    minAmount,
    maxAmount,
    feePercentage,
    fixedFee,
    enabled
  );
  
  console.log("Transaction sent:", tx.hash);
  await tx.wait();
  console.log("Transaction confirmed!");
  
  console.log("Solana chain configuration complete!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error configuring Solana chain:", error);
    process.exit(1);
  }); 