/**
 * Vault state example for @elitra/sdk
 *
 * This example demonstrates how to:
 * - Read vault total assets and supply
 * - Check vault price per share
 * - View available balance
 * - Check if vault is paused
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
  console.log('=== Vault State Example ===\n');

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

  // Get vault state
  console.log('Fetching vault state...\n');
  const state = await elitra.getVaultState();

  // Display vault information
  console.log('=== Vault Information ===');
  console.log('Total Assets:', formatUnits(state.totalAssets, 6), 'USDC');
  console.log('Total Supply:', formatUnits(state.totalSupply, 18), 'shares');
  console.log('Price Per Share:', formatUnits(state.pricePerShare, 18));
  console.log('Available Balance:', formatUnits(state.availableBalance, 6), 'USDC');
  console.log('Is Paused:', state.isPaused);
  console.log('');

  // Calculate vault metrics
  const totalAssetsNum = Number(formatUnits(state.totalAssets, 6));
  const totalSupplyNum = Number(formatUnits(state.totalSupply, 18));
  const availableBalanceNum = Number(formatUnits(state.availableBalance, 6));

  console.log('=== Calculated Metrics ===');
  if (totalSupplyNum > 0) {
    const averageShareValue = totalAssetsNum / totalSupplyNum;
    console.log('Average Share Value:', averageShareValue.toFixed(6), 'USDC per share');
  }
  if (totalAssetsNum > 0) {
    const availablePercentage = (availableBalanceNum / totalAssetsNum) * 100;
    console.log('Available Balance:', availablePercentage.toFixed(2), '% of total assets');
  }
}

// Run the example
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Error:', error);
    process.exit(1);
  });
