/**
 * Manage function example for @elitra/sdk
 *
 * This example demonstrates how to:
 * - Use the manage function to interact with external contracts
 * - Encode approve calls for ERC20 tokens
 * - Execute arbitrary calls on behalf of the vault
 * - Handle authorization errors and set up target method permissions
 *
 * Note: The manage function requires two levels of authorization:
 * 1. User must have MANAGER_ROLE (role 0) on the vault
 * 2. The specific target method must be authorized via RolesAuthority.setPublicCapability()
 */

import { createPublicClient, createWalletClient, http, parseUnits, encodeFunctionData, Hex } from "viem";
import { sei } from "viem/chains";
import { privateKeyToAccount } from "viem/accounts";
import { ElitraClient, encodeApprove } from "../src";

// Configuration from environment variables
// Set these in your .env file or export them in your shell:
// - VAULT_ADDRESS: Your Elitra Vault address
// - ROLES_AUTHORITY_ADDRESS: RolesAuthority contract address (optional, for authorization setup)
// - RPC_URL: SEI RPC endpoint (defaults to public endpoint)
// - PRIVATE_KEY: Your private key (must have manager role)
const VAULT_ADDRESS = process.env.VAULT_ADDRESS;
const ROLES_AUTHORITY_ADDRESS = process.env.ROLES_AUTHORITY_ADDRESS;
const RPC_URL = process.env.RPC_URL || "https://evm-rpc.sei-apis.com";
const PRIVATE_KEY = process.env.PRIVATE_KEY;

if (!VAULT_ADDRESS || !PRIVATE_KEY) {
  throw new Error("Missing required environment variables: VAULT_ADDRESS and PRIVATE_KEY");
}

/**
 * Helper function to display authorization information
 */
function displayAuthorizationInfo(targetContract: string, callData: Hex) {
  const functionSig = callData.slice(0, 10) as Hex;
  const MANAGER_ROLE = 0;

  console.log("\n=== Authorization Setup ===");
  console.log("Authority Contract:", ROLES_AUTHORITY_ADDRESS || "(set AUTHORITY_ADDRESS env var)");
  console.log("Target Contract:", targetContract);
  console.log("Function Signature:", functionSig);
  console.log("Who Can Call: Vault owner only");

  if (ROLES_AUTHORITY_ADDRESS) {
    console.log("\nCommand:");
    console.log(
      `cast send ${ROLES_AUTHORITY_ADDRESS} "setRoleCapability(uint8,address,bytes4,bool)" ${MANAGER_ROLE} ${targetContract} ${functionSig} true --private-key $PRIVATE_KEY --rpc-url $RPC_URL`,
    );
  }
  console.log("===========================\n");
}

async function main() {
  console.log("=== Manage Function Example ===\n");

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

  console.log("Manager Address:", account.address);
  console.log("Vault Address:", VAULT_ADDRESS);
  const vaultAsset = await elitra.getAsset();
  console.log("");

  // Example 1: Approve tokens to a protocol
  console.log("=== Example 1: Approve Tokens ===");
  const targetToken = vaultAsset;
  const spenderAddress = "0x3f98e41fd95ddb428d5c1d6b8f3838901e788b22"; // Protocol address to approve
  const approveAmount = parseUnits("1000", 6); // 1000 USDC

  // Encode the approve call
  const approveData = encodeApprove(spenderAddress, approveAmount);
  console.log("Target Token:", targetToken);
  console.log("Spender:", spenderAddress);
  console.log("Amount:", approveAmount.toString());
  console.log("Encoded Data:", approveData);

  try {
    console.log("Executing approve...");
    const approveResult = await elitra.manage(targetToken, approveData);
    console.log("✓ Approve successful!");
    console.log("Transaction Hash:", approveResult.hash);
    console.log("");
  } catch (error: any) {
    console.error("✗ Approve failed:", error.message || error);
    console.log("");

    console.log("Use the authorization command shown above.");

    // Display authorization info BEFORE attempting the call
    displayAuthorizationInfo(targetToken, approveData);
  }
}

// Run the example
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error:", error);
    process.exit(1);
  });
