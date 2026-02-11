
import { TurnkeySignerClient } from "../turnkey-client";
import * as dotenv from "dotenv";
import * as path from "path";
import { parseEther, defineChain, formatEther, createPublicClient, http } from "viem";

// Load .env
dotenv.config({ path: path.resolve(__dirname, "../../.env") });
dotenv.config({ path: path.resolve(__dirname, "../../../.env") });

// Define Sei Mainnet Chain
const sei = defineChain({
  id: 1329,
  name: "Sei",
  network: "sei",
  nativeCurrency: {
    decimals: 18,
    name: "Sei",
    symbol: "SEI",
  },
  rpcUrls: {
    default: { http: ["https://evm-rpc.sei-apis.com"] },
    public: { http: ["https://evm-rpc.sei-apis.com"] },
  },
  blockExplorers: {
    default: { 
        name: "Seitrace", 
        url: "https://seitrace.com",
        apiUrl: "https://seitrace.com/pacific-1/api"
    },
  },
});

async function main() {
  const apiPublicKey = process.env.TURNKEY_API_PUBLIC_KEY || process.env.API_KEY;
  const apiPrivateKey = process.env.TURNKEY_API_PRIVATE_KEY || process.env.API_PRIVATE_KEY;
  const organizationId = process.env.TURNKEY_ORGANIZATION_ID;
  const signerId = process.env.TURNKEY_PRIVATE_KEY_ID;
  
  // The address we want to send TO
  const destinationAddress = "0xD4B5314E9412dBC1c772093535dF451a1E2Af1A4";
  const amount = "0.1";
  const rpcUrl = process.env.RPC_URL || "https://evm-rpc.sei-apis.com";

  if (!apiPublicKey || !apiPrivateKey || !organizationId || !signerId) {
    throw new Error("Missing Turnkey credentials in .env (need KEY, SECRET, ORG_ID, PRIVATE_KEY_ID)");
  }

  // Set env vars for the client
  process.env.TURNKEY_API_PUBLIC_KEY = apiPublicKey;
  process.env.TURNKEY_API_PRIVATE_KEY = apiPrivateKey;

  console.log("Initializing Turnkey Client...");
  console.log(`Signer ID: ${signerId}`);
  console.log(`Destination: ${destinationAddress}`);
  console.log(`Amount: ${amount} SEI`);

  const client = new TurnkeySignerClient(organizationId, signerId);

  try {
    // 1. Get Wallet Client (Signer)
    const walletClient = await client.getWalletClient(sei);
    const myAddress = walletClient.account.address;
    
    console.log(`My Turnkey Address: ${myAddress}`);

    // 2. Check Balance
    const publicClient = createPublicClient({
        chain: sei,
        transport: http(rpcUrl)
    });
    const balance = await publicClient.getBalance({ address: myAddress });
    console.log(`Current Balance: ${formatEther(balance)} SEI`);

    if (balance < parseEther(amount)) {
        console.error("❌ Insufficient balance! Please fund the Turnkey wallet first.");
        return;
    }

    // 3. Send Transaction
    console.log("Sending transaction...");
    const hash = await walletClient.sendTransaction({
      to: destinationAddress,
      value: parseEther(amount),
    });

    console.log("--------------------------------------------------");
    console.log(`Transaction Sent!`);
    console.log(`Hash: ${hash}`);
    console.log(`Explorer: https://seitrace.com/tx/${hash}`);
    console.log("--------------------------------------------------");

  } catch (error) {
    console.error("Error sending transaction:", error);
  }
}

main();
