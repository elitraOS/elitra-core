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
const viem_1 = require("viem");
const accounts_1 = require("viem/accounts");
const dotenv = __importStar(require("dotenv"));
const path = __importStar(require("path"));
// Load .env from various possible locations
dotenv.config({ path: path.resolve(__dirname, "../../.env") }); // pkg/turnkey-client/.env
dotenv.config({ path: path.resolve(__dirname, "../../../.env") }); // pkg/.env
dotenv.config({ path: path.resolve(__dirname, "../../../../.env") }); // elitra-core/.env
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
    if (!(0, viem_1.isAddress)(targetAddress)) {
        throw new Error(`Invalid target address: ${targetAddress}`);
    }
    const account = (0, accounts_1.privateKeyToAccount)(privateKey);
    const client = (0, viem_1.createWalletClient)({
        account,
        transport: (0, viem_1.http)(rpcUrl),
        chain: sei
    });
    console.log(`Funding Turnkey Wallet: ${targetAddress}`);
    console.log(`From Account: ${account.address}`);
    console.log(`Amount: ${amount} SEI`);
    console.log(`RPC: ${rpcUrl}`);
    try {
        const hash = await client.sendTransaction({
            to: targetAddress,
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
