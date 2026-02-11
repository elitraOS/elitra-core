import { Turnkey } from "@turnkey/sdk-server";
import { createAccount } from "@turnkey/viem";
import { createWalletClient, http, Chain } from "viem";
import { sepolia } from "viem/chains";
import * as dotenv from "dotenv";
import * as path from "path";

dotenv.config({ path: path.resolve(__dirname, "../../../.env") });

export class TurnkeySignerClient {
  private client: Turnkey;
  private organizationId: string;
  private signWith: string; // Can be address or UUID

  constructor(organizationId: string, signWith: string) {
    this.organizationId = organizationId;
    this.signWith = signWith;
    
    this.client = new Turnkey({
      apiBaseUrl: "https://api.turnkey.com",
      apiPublicKey: process.env.TURNKEY_API_PUBLIC_KEY || process.env.API_KEY!,
      apiPrivateKey: process.env.TURNKEY_API_PRIVATE_KEY || process.env.API_PRIVATE_KEY!,
      defaultOrganizationId: organizationId,
    });
  }

  async getWalletClient(chain: Chain = sepolia) {
    const turnkeyAccount = await createAccount({
      client: this.client.apiClient(),
      organizationId: this.organizationId,
      signWith: this.signWith,
    });

    return createWalletClient({
      account: turnkeyAccount,
      chain,
      transport: http(process.env.RPC_URL),
    });
  }
}
