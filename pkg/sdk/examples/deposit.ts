/**
 * Deposit example for @elitra/sdk
 *
 * This example demonstrates how to:
 * - Preview a deposit to see expected shares
 * - Approve USDC for the vault
 * - Deposit assets into the vault
 * - Verify the deposit result
 */

import { createPublicClient, createWalletClient, http, parseUnits, formatUnits } from "viem";
import { sei } from "viem/chains";
import { privateKeyToAccount } from "viem/accounts";
import { ElitraClient } from "../src";

// Configuration from environment variables
// Set these in your .env file or export them in your shell:
// - VAULT_ADDRESS: Your Elitra Vault address
// - RPC_URL: SEI RPC endpoint (defaults to public endpoint)
// - PRIVATE_KEY: Your private key (with 0x prefix)
const VAULT_ADDRESS = process.env.VAULT_ADDRESS;
const RPC_URL = process.env.RPC_URL || "https://evm-rpc.sei-apis.com";
const PRIVATE_KEY = process.env.PRIVATE_KEY;

if (!VAULT_ADDRESS || !PRIVATE_KEY) {
  throw new Error("Missing required environment variables: VAULT_ADDRESS and PRIVATE_KEY");
}

async function main() {
  console.log("=== Deposit Example ===\n");

  // Setup clients
  const publicClient = createPublicClient({
    chain: sei,
    transport: http(RPC_URL),
  });

  const account = privateKeyToAccount(PRIVATE_KEY);
  const walletClient = createWalletClient({
    chain: sei,
    transport: http(RPC_URL),
    account,
  });

  const elitra = new ElitraClient({
    vaultAddress: VAULT_ADDRESS,
    publicClient,
    walletClient,
  });

  // Define deposit amount
  const depositAmount = parseUnits("0.1", 18);
  console.log("Deposit Amount:", formatUnits(depositAmount, 18), "WSEI");
  console.log("");

  // 1. Preview deposit
  console.log("=== Preview Deposit ===");
  const expectedShares = await elitra.previewDeposit(depositAmount);
  console.log("Expected Shares:", formatUnits(expectedShares, 18));
  console.log("");

  // 2. Get asset address and approve
  console.log("=== Approval Step ===");
  const assetAddress = await elitra.getAsset();
  console.log("Asset Address:", assetAddress);
  console.log("");

  console.log("Note: You need to approve USDC before depositing.");
  console.log("You can use a tool like cast or ethers to approve:");
  console.log(`  cast send ${assetAddress} "approve(address,uint256)" ${VAULT_ADDRESS} ${depositAmount.toString()}`);
  console.log("");

  // Uncomment the following to approve programmatically:

  console.log("Approving USDC...");
  const approveTx = await walletClient.writeContract({
    address: assetAddress,
    abi: [
      {
        name: "approve",
        type: "function",
        stateMutability: "nonpayable",
        inputs: [
          { name: "spender", type: "address" },
          { name: "amount", type: "uint256" },
        ],
        outputs: [{ type: "bool" }],
      },
    ],
    functionName: "approve",
    args: [VAULT_ADDRESS, depositAmount],
  });
  await publicClient.waitForTransactionReceipt({ hash: approveTx });
  console.log("Approval successful!");
  console.log("");

  // 3. Execute deposit
  console.log("=== Execute Deposit ===");
  try {
    const depositResult = await elitra.deposit(depositAmount);
    console.log("Deposit successful!");
    console.log("Transaction Hash:", depositResult.hash);
    console.log("Shares Received:", formatUnits(depositResult.shares, 18));
    console.log("");

    // 4. Verify new position
    console.log("=== Updated Position ===");
    const position = await elitra.getUserPosition(account.address);
    console.log("Total Shares:", formatUnits(position.shares, 18));
    console.log("Total Asset Value:", formatUnits(position.assets, 6), "USDC");
  } catch (error) {
    console.error("Deposit failed:", error);
    console.log("");
    console.log("This is expected if you have not approved USDC yet.");
    console.log("Please approve USDC first and try again.");
  }
}

// Run the example
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error:", error);
    process.exit(1);
  });
