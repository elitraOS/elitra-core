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
exports.TurnkeySignerClient = void 0;
const sdk_server_1 = require("@turnkey/sdk-server");
const viem_1 = require("@turnkey/viem");
const viem_2 = require("viem");
const chains_1 = require("viem/chains");
const dotenv = __importStar(require("dotenv"));
const path = __importStar(require("path"));
dotenv.config({ path: path.resolve(__dirname, "../../../.env") });
class TurnkeySignerClient {
    client;
    organizationId;
    signWith; // Can be address or UUID
    constructor(organizationId, signWith) {
        this.organizationId = organizationId;
        this.signWith = signWith;
        this.client = new sdk_server_1.Turnkey({
            apiBaseUrl: "https://api.turnkey.com",
            apiPublicKey: process.env.TURNKEY_API_PUBLIC_KEY || process.env.API_KEY,
            apiPrivateKey: process.env.TURNKEY_API_PRIVATE_KEY || process.env.API_PRIVATE_KEY,
            defaultOrganizationId: organizationId,
        });
    }
    async getWalletClient(chain = chains_1.sepolia) {
        const turnkeyAccount = await (0, viem_1.createAccount)({
            client: this.client.apiClient(),
            organizationId: this.organizationId,
            signWith: this.signWith,
        });
        return (0, viem_2.createWalletClient)({
            account: turnkeyAccount,
            chain,
            transport: (0, viem_2.http)(process.env.RPC_URL),
        });
    }
}
exports.TurnkeySignerClient = TurnkeySignerClient;
