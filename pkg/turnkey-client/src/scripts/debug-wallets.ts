
import { Turnkey } from "@turnkey/sdk-server";
import * as dotenv from "dotenv";
import * as path from "path";

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

  const turnkey = new Turnkey({
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
      } catch (err) {
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

  } catch (error) {
    console.error("Error fetching Turnkey resources:", error);
  }
}

main();
