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
const chains_1 = require("viem/chains");
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
    const client = new turnkey_client_1.TurnkeySignerClient(organizationId, signerId);
    try {
        const walletClient = await client.getWalletClient();
        // Create a public client to read data (balance)
        const publicClient = (0, viem_1.createPublicClient)({
            chain: chains_1.sei, // Using Sei network
            transport: (0, viem_1.http)(process.env.RPC_URL)
        });
        const balance = await publicClient.getBalance({
            address: signerAddress,
        });
        console.log("--------------------------------------------------");
        console.log("Successfully connected to Turnkey!");
        console.log(`Wallet Address: ${walletClient.account.address}`);
        console.log(`Balance: ${(0, viem_1.formatEther)(balance)} ETH`);
        console.log("--------------------------------------------------");
        // Optional: Sign a message to prove control
        const message = "Hello from Turnkey!";
        const signature = await walletClient.signMessage({
            message,
        });
        console.log(`Signed Message: "${message}"`);
        console.log(`Signature: ${signature}`);
    }
    catch (error) {
        console.error("Error connecting to Turnkey:", error);
    }
}
main();
