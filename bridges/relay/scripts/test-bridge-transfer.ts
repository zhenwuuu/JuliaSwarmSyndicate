import hre from "hardhat";
import dotenv from "dotenv";

dotenv.config();

async function main() {
  console.log("Testing bridge transfer from Base Sepolia to Solana");
  
  // Get signer
  const [signer] = await hre.ethers.getSigners();
  console.log("Using account:", signer.address);
  
  // Get contract addresses from env
  const bridgeAddress = process.env.BASE_BRIDGE_CONTRACT;
  const tokenAddress = process.env.BASE_TEST_TOKEN;
  
  if (!bridgeAddress || !tokenAddress) {
    console.error("Missing contract addresses in .env file");
    process.exit(1);
  }
  
  console.log(`Bridge address: ${bridgeAddress}`);
  console.log(`Token address: ${tokenAddress}`);
  
  // Get contracts
  const bridge = await hre.ethers.getContractAt("JuliaBridge", bridgeAddress);
  const token = await hre.ethers.getContractAt("TestToken", tokenAddress);
  
  // Use an Ethereum address as recipient (will be mapped to Solana address by the relay)
  // For testing, we'll use a simple address
  const recipient = "0x1111111111111111111111111111111111111111";
  console.log(`Recipient: ${recipient}`);
  
  // Get token balance before bridge
  const balanceBefore = await token.balanceOf(signer.address);
  console.log(`Token balance before bridge: ${hre.ethers.formatEther(balanceBefore)}`);
  
  // Transfer amount
  const transferAmount = hre.ethers.parseEther("1.0");
  console.log(`Transfer amount: ${hre.ethers.formatEther(transferAmount)} TEST`);
  
  // Target chain ID for Solana
  const solanaChainId = parseInt(process.env.SOLANA_CHAIN_ID || "101");
  
  console.log("Initiating bridge transfer...");
  
  // First approve token spending if needed
  const allowance = await token.allowance(signer.address, bridgeAddress);
  if (allowance < transferAmount) {
    console.log("Approving token spending...");
    const approveTx = await token.approve(bridgeAddress, transferAmount);
    await approveTx.wait();
    console.log("Approval confirmed");
  }
  
  // Bridge the tokens
  const bridgeTx = await bridge.bridge(
    tokenAddress,
    transferAmount,
    recipient,
    solanaChainId
  );
  
  console.log("Transaction sent:", bridgeTx.hash);
  await bridgeTx.wait();
  console.log("Transaction confirmed!");
  
  // Get token balance after bridge
  const balanceAfter = await token.balanceOf(signer.address);
  console.log(`Token balance after bridge: ${hre.ethers.formatEther(balanceAfter)}`);
  console.log(`Total sent: ${hre.ethers.formatEther(balanceBefore - balanceAfter)}`);
  
  console.log("\nBridge transfer initiated successfully!");
  console.log("The relay service should pick up this event and complete the transfer to Solana.");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error in bridge transfer:", error);
    process.exit(1);
  }); 