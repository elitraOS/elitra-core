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
const sdk_server_1 = require("@turnkey/sdk-server");
const dotenv = __importStar(require("dotenv"));
const path = __importStar(require("path"));
// Load .env
dotenv.config({ path: path.resolve(__dirname, "../../.env") });
dotenv.config({ path: path.resolve(__dirname, "../../../.env") });
async function main() {
    const apiPublicKey = process.env.TURNKEY_API_PUBLIC_KEY || process.env.API_KEY;
    const apiPrivateKey = process.env.TURNKEY_API_PRIVATE_KEY || process.env.API_PRIVATE_KEY;
    const organizationId = process.env.TURNKEY_ORGANIZATION_ID;
    if (!apiPublicKey || !apiPrivateKey || !organizationId) {
        throw new Error("Missing API keys or Organization ID in .env");
    }
    console.log("Initializing Turnkey Client...");
    console.log(`Organization ID: ${organizationId}`);
    const turnkey = new sdk_server_1.Turnkey({
        apiBaseUrl: "https://api.turnkey.com",
        apiPublicKey: apiPublicKey,
        apiPrivateKey: apiPrivateKey,
        defaultOrganizationId: organizationId,
    });
    const client = turnkey.apiClient();
    try {
        console.log("Fetching Wallets...");
        const walletsResponse = await client.getWallets({
            organizationId,
        });
        console.log("Wallets found:", walletsResponse.wallets.length);
        console.log("Wallets found:", walletsResponse.wallets.length);
        for (const w of walletsResponse.wallets) {
            console.log(`- ID: ${w.walletId}, Name: ${w.walletName}`);
            try {
                const accountsResponse = await client.getWalletAccounts({
                    organizationId,
                    walletId: w.walletId,
                });
                accountsResponse.accounts.forEach((a) => {
                    console.log(`  - Address: ${a.address}, Path: ${a.path}`);
                });
            }
            catch (err) {
                console.log(`  - Error fetching accounts: ${err}`);
            }
        }
        console.log("\nFetching Private Keys...");
        // getPrivateKeys is the method to list standalone private keys
        const privateKeysResponse = await client.getPrivateKeys({
            organizationId,
        });
        console.log("Private Keys found:", privateKeysResponse.privateKeys.length);
        privateKeysResponse.privateKeys.forEach((pk) => {
            console.log(`- ID: ${pk.privateKeyId}, Name: ${pk.privateKeyName}`);
            console.log(`  - Addresses: ${pk.addresses.map(a => a.address).join(", ")}`);
        });
    }
    catch (error) {
        console.error("Error fetching Turnkey resources:", error);
    }
}
main();
