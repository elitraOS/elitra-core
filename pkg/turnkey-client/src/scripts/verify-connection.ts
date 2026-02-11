
import { TurnkeySignerClient } from "../turnkey-client";
import * as dotenv from "dotenv";
import * as path from "path";
import { formatEther, createPublicClient, http } from "viem";
import { sei } from "viem/chains";

// Load .env from current directory first, then root
dotenv.config({ path: path.resolve(__dirname, "../../.env") }); 
dotenv.config({ path: path.resolve(__dirname, "../../../.env") });

async function main() {
  // Map standard keys or user-provided keys
  const apiPublicKey = process.env.TURNKEY_API_PUBLIC_KEY || process.env.API_KEY;
  const apiPrivateKey = process.env.TURNKEY_API_PRIVATE_KEY || process.env.API_PRIVATE_KEY;
  const organizationId = process.env.TURNKEY_ORGANIZATION_ID;
  const signerAddress = process.env.TURNKEY_WALLET_ADDRESS || "0xD4B5314E9412dBC1c772093535dF451a1E2Af1A4";
  const signerId = process.env.TURNKEY_PRIVATE_KEY_ID || signerAddress; // Fallback to address if ID not set

  if (!apiPublicKey || !apiPrivateKey) {
    throw new Error("API keys not found in .env. Please set TURNKEY_API_PUBLIC_KEY and TURNKEY_API_PRIVATE_KEY (or API_KEY/API_PRIVATE_KEY).");
  }

  if (!organizationId) {
    console.error("Error: TURNKEY_ORGANIZATION_ID is not set in .env");
    process.exit(1);
  }

  // Set env vars for the client to pick up if it relies on process.env
  process.env.TURNKEY_API_PUBLIC_KEY = apiPublicKey;
  process.env.TURNKEY_API_PRIVATE_KEY = apiPrivateKey;

  console.log("Initializing Turnkey Client...");
  console.log(`Organization ID: ${organizationId}`);
  console.log(`Signer ID: ${signerId}`);
  console.log(`Address (for verification): ${signerAddress}`);

  // Pass the ID (UUID) for signing, but we still need the address for verification
  const client = new TurnkeySignerClient(organizationId, signerId);

  try {
    const walletClient = await client.getWalletClient();
    
    // Create a public client to read data (balance)
    const publicClient = createPublicClient({
      chain: sei, // Using Sei network
      transport: http(process.env.RPC_URL)
    });

    const balance = await publicClient.getBalance({
      address: signerAddress as `0x${string}`,
    });

    console.log("--------------------------------------------------");
    console.log("Successfully connected to Turnkey!");
    console.log(`Wallet Address: ${walletClient.account.address}`);
    console.log(`Balance: ${formatEther(balance)} ETH`);
    console.log("--------------------------------------------------");

    // Optional: Sign a message to prove control
    const message = "Hello from Turnkey!";
    const signature = await walletClient.signMessage({
      message,
    });
    console.log(`Signed Message: "${message}"`);
    console.log(`Signature: ${signature}`);

  } catch (error) {
    console.error("Error connecting to Turnkey:", error);
  }
}

main();
