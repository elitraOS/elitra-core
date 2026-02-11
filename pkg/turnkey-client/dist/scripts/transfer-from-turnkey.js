"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
const turnkey_client_1 = require("../turnkey-client");
const dotenv = __importStar(require("dotenv"));
const path = __importStar(require("path"));
const viem_1 = require("viem");
// Load .env
dotenv.config({ path: path.resolve(__dirname, "../../.env") });
dotenv.config({ path: path.resolve(__dirname, "../../../.env") });
// Define Sei Mainnet Chain
const sei = (0, viem_1.defineChain)({
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
    const client = new turnkey_client_1.TurnkeySignerClient(organizationId, signerId);
    try {
        // 1. Get Wallet Client (Signer)
        const walletClient = await client.getWalletClient(sei);
        const myAddress = walletClient.account.address;
        console.log(`My Turnkey Address: ${myAddress}`);
        // 2. Check Balance
        const publicClient = (0, viem_1.createPublicClient)({
            chain: sei,
            transport: (0, viem_1.http)(rpcUrl)
        });
        const balance = await publicClient.getBalance({ address: myAddress });
        console.log(`Current Balance: ${(0, viem_1.formatEther)(balance)} SEI`);
        if (balance < (0, viem_1.parseEther)(amount)) {
            console.error("❌ Insufficient balance! Please fund the Turnkey wallet first.");
            return;
        }
        // 3. Send Transaction
        console.log("Sending transaction...");
        const hash = await walletClient.sendTransaction({
            to: destinationAddress,
            value: (0, viem_1.parseEther)(amount),
        });
        console.log("--------------------------------------------------");
        console.log(`Transaction Sent!`);
        console.log(`Hash: ${hash}`);
        console.log(`Explorer: https://seitrace.com/tx/${hash}`);
        console.log("--------------------------------------------------");
    }
    catch (error) {
        console.error("Error sending transaction:", error);
    }
}
main();
