/**
 * Redemption example for @elitra/sdk
 *
 * This example demonstrates how to:
 * - Preview a redemption to see expected assets
 * - Request a redemption (instant or queued)
 * - Check pending redemptions
 * - Handle both instant and queued redemptions
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
  console.log("=== Redemption Example ===\n");

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

  console.log("User Address:", account.address);
  console.log("");

  // 1. Check current position
  console.log("=== Current Position ===");
  const positionBefore = await elitra.getUserPosition(account.address);
  console.log("Current Shares:", formatUnits(positionBefore.shares, 18));
  console.log("Current Asset Value:", formatUnits(positionBefore.assets, 6), "USDC");
  console.log("Max Redeem:", formatUnits(positionBefore.maxRedeem, 18), "shares");
  console.log("");

  // 2. Define redemption amount
  const redeemShares = parseUnits("0.05", 18); // 50 shares
  console.log("Redeem Amount:", formatUnits(redeemShares, 18), "shares");
  console.log("");

  // 3. Preview redemption
  console.log("=== Preview Redemption ===");
  const expectedAssets = await elitra.previewRedeem(redeemShares);
  console.log("Expected Assets:", formatUnits(expectedAssets, 6), "USDC");
  console.log("");

  // 4. Execute redemption
  console.log("=== Execute Redemption ===");
  try {
    const redeemResult = await elitra.requestRedeem(redeemShares);
    console.log("Redemption requested!");
    console.log("Transaction Hash:", redeemResult.hash);
    console.log("");

    // Handle instant vs queued redemption
    if (redeemResult.isInstant) {
      console.log("✓ Instant Redemption");
      console.log("Assets Received:", formatUnits(redeemResult.value, 6), "USDC");
      console.log("Assets have been transferred to your wallet immediately.");
    } else {
      console.log("⏳ Queued Redemption");
      console.log("Request ID:", redeemResult.value);
      console.log("Your redemption has been queued and will be processed in the next epoch.");
      console.log("");

      // 5. Check pending redemptions
      console.log("=== Pending Redemptions ===");
      const pending = await elitra.getPendingRedeem(account.address);
      console.log("Pending Assets:", formatUnits(pending.assets, 6), "USDC");
      console.log("Pending Shares:", formatUnits(pending.shares, 18));
      console.log("");

      console.log("Note: You can claim your assets after the epoch ends using the claim function.");
    }

    // 6. Verify updated position
    console.log("=== Updated Position ===");
    const positionAfter = await elitra.getUserPosition(account.address);
    console.log("Shares:", formatUnits(positionAfter.shares, 18));
    console.log("Asset Value:", formatUnits(positionAfter.assets, 6), "USDC");
    console.log("Pending Redeem Assets:", formatUnits(positionAfter.pendingRedeem.assets, 6), "USDC");
    console.log("Pending Redeem Shares:", formatUnits(positionAfter.pendingRedeem.shares, 18));
  } catch (error) {
    console.error("Redemption failed:", error);
    console.log("");
    console.log("Possible reasons:");
    console.log("- Insufficient share balance");
    console.log("- Vault is paused");
    console.log("- Requested amount exceeds maximum redeemable");
  }
}

// Run the example
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error:", error);
    process.exit(1);
  });
