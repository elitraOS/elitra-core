/**
 * Setup example for @elitra/sdk
 *
 * This example demonstrates how to:
 * - Create Viem public and wallet clients
 * - Initialize the Elitra client
 * - Verify the setup
 */

import { createPublicClient, createWalletClient, http } from 'viem';
import { sei } from 'viem/chains';
import { privateKeyToAccount } from 'viem/accounts';
import { ElitraClient } from '../src';

// Configuration from environment variables
// Set these in your .env file or export them in your shell:
// - VAULT_ADDRESS: Your Elitra Vault address
// - RPC_URL: SEI RPC endpoint (defaults to public endpoint)
// - PRIVATE_KEY: Your private key (with 0x prefix)
const VAULT_ADDRESS = process.env.VAULT_ADDRESS;
const RPC_URL = process.env.RPC_URL || 'https://evm-rpc.sei-apis.com';
const PRIVATE_KEY = process.env.PRIVATE_KEY;

if (!VAULT_ADDRESS || !PRIVATE_KEY) {
  throw new Error('Missing required environment variables: VAULT_ADDRESS and PRIVATE_KEY');
}

async function main() {
  console.log('=== Elitra SDK Setup Example ===\n');

  // 1. Setup Viem clients
  console.log('Setting up clients...');

  // Create a public client for reading blockchain data
  const publicClient = createPublicClient({
    chain: sei,
    transport: http(RPC_URL),
  });

  // Create an account from your private key
  const account = privateKeyToAccount(PRIVATE_KEY);

  // Create a wallet client for sending transactions
  const walletClient = createWalletClient({
    chain: sei,
    transport: http(RPC_URL),
    account,
  });

  // 2. Create Elitra client
  const elitra = new ElitraClient({
    vaultAddress: VAULT_ADDRESS,
    publicClient,
    walletClient,
  });

  // 3. Verify setup
  console.log('Setup complete!');
  console.log('Vault Address:', elitra.getVaultAddress());
  console.log('User Address:', account.address);
  console.log('');

  console.log('You can now use the elitra client to interact with the vault.');
}

// Run the example
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Error:', error);
    process.exit(1);
  });
