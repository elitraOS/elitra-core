
import { createWalletClient, http, parseEther, isAddress, defineChain } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import * as dotenv from "dotenv";
import * as path from "path";

// Load .env from various possible locations
dotenv.config({ path: path.resolve(__dirname, "../../.env") });       // pkg/turnkey-client/.env
dotenv.config({ path: path.resolve(__dirname, "../../../.env") });    // pkg/.env
dotenv.config({ path: path.resolve(__dirname, "../../../../.env") }); // elitra-core/.env

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
    default: { name: "Seitrace", url: "https://seitrace.com" },
  },
});

async function main() {
  const targetAddress = "0x9F26BdE9D227e378d9511a059454112283E05Af4"; // The Turnkey Wallet Address we verified
  const amount = process.env.FUNDING_AMOUNT || "0.1"; 
  const rpcUrl = process.env.RPC_URL || "https://evm-rpc.sei-apis.com";
  const privateKey = process.env.PRIVATE_KEY;

  if (!privateKey) {
    throw new Error("PRIVATE_KEY environment variable is not set. Please add it to your .env file.");
  }

  if (!isAddress(targetAddress)) {
    throw new Error(`Invalid target address: ${targetAddress}`);
  }

  const account = privateKeyToAccount(privateKey as `0x${string}`);

  const client = createWalletClient({
    account,
    transport: http(rpcUrl),
    chain: sei
  });

  console.log(`Funding Turnkey Wallet: ${targetAddress}`);
  console.log(`From Account: ${account.address}`);
  console.log(`Amount: ${amount} SEI`);
  console.log(`RPC: ${rpcUrl}`);

  try {
    const hash = await client.sendTransaction({
      to: targetAddress,
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
