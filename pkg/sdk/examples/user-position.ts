/**
 * User position example for @elitra/sdk
 *
 * This example demonstrates how to:
 * - Check user's share balance
 * - View asset value of shares
 * - Check pending redemptions
 * - View maximum withdrawal/redemption amounts
 */

import { createPublicClient, createWalletClient, http, formatUnits } from 'viem';
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
  console.log('=== User Position Example ===\n');

  // Setup clients
  const publicClient = createPublicClient({
    chain: sei,
    transport: http(RPC_URL),
  });

  const account = privateKeyToAccount(PRIVATE_KEY);
  const walletClient = createWalletClient({
    chain: sei,
    transport: http(RPC_URL),
    account,
  });

  const elitra = new ElitraClient({
    vaultAddress: VAULT_ADDRESS,
    publicClient,
    walletClient,
  });

  console.log('User Address:', account.address);
  console.log('');

  // Get user position
  console.log('Fetching user position...\n');
  const position = await elitra.getUserPosition(account.address);

  // Display current holdings
  console.log('=== Current Holdings ===');
  console.log('Shares:', formatUnits(position.shares, 18));
  console.log('Asset Value:', formatUnits(position.assets, 6), 'USDC');
  console.log('');

  // Display pending redemptions
  console.log('=== Pending Redemptions ===');
  console.log('Pending Redeem Assets:', formatUnits(position.pendingRedeem.assets, 6), 'USDC');
  console.log('Pending Redeem Shares:', formatUnits(position.pendingRedeem.shares, 18));
  console.log('');

  // Display maximum actions
  console.log('=== Maximum Actions ===');
  console.log('Max Withdraw:', formatUnits(position.maxWithdraw, 6), 'USDC');
  console.log('Max Redeem:', formatUnits(position.maxRedeem, 18), 'shares');
  console.log('');

  // Calculate position metrics
  const sharesNum = Number(formatUnits(position.shares, 18));
  const assetsNum = Number(formatUnits(position.assets, 6));

  if (sharesNum > 0) {
    console.log('=== Position Metrics ===');
    const valuePerShare = assetsNum / sharesNum;
    console.log('Value Per Share:', valuePerShare.toFixed(6), 'USDC');
  }

  // Check if there are pending redemptions
  const pendingAssetsNum = Number(formatUnits(position.pendingRedeem.assets, 6));
  if (pendingAssetsNum > 0) {
    console.log('');
    console.log('⚠️  You have pending redemptions. These will be available after the next epoch.');
  }
}

// Run the example
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Error:', error);
    process.exit(1);
  });
