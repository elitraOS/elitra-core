/**
 * Basic usage example for @elitra/sdk
 *
 * This example demonstrates:
 * - Setting up the Elitra client
 * - Reading vault state
 * - Depositing assets
 * - Requesting redemptions
 * - Using the manage function
 */

import { createPublicClient, createWalletClient, http, parseUnits, formatUnits } from 'viem';
import { sei } from 'viem/chains';
import { privateKeyToAccount } from 'viem/accounts';
import { ElitraClient, encodeApprove, encodeERC4626Deposit } from '../src';

// Configuration
const VAULT_ADDRESS = '0x...'; // Your Elitra Vault address
const RPC_URL = 'https://evm-rpc.sei-apis.com';
const PRIVATE_KEY = '0x...'; // Your private key

async function main() {
  console.log('=== Elitra SDK Example ===\n');

  // 1. Setup Viem clients
  console.log('Setting up clients...');
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

  // 2. Create Elitra client
  const elitra = new ElitraClient({
    vaultAddress: VAULT_ADDRESS,
    publicClient,
    walletClient,
  });

  console.log('Vault Address:', elitra.getVaultAddress());
  console.log('User Address:', account.address);
  console.log('');

  // 3. Get vault state
  console.log('=== Vault State ===');
  const state = await elitra.getVaultState();
  console.log('Total Assets:', formatUnits(state.totalAssets, 6), 'USDC');
  console.log('Total Supply:', formatUnits(state.totalSupply, 18), 'shares');
  console.log('Price Per Share:', formatUnits(state.pricePerShare, 18));
  console.log('Available Balance:', formatUnits(state.availableBalance, 6), 'USDC');
  console.log('Is Paused:', state.isPaused);
  console.log('');

  // 4. Get user position
  console.log('=== User Position ===');
  const position = await elitra.getUserPosition(account.address);
  console.log('Shares:', formatUnits(position.shares, 18));
  console.log('Asset Value:', formatUnits(position.assets, 6), 'USDC');
  console.log('Pending Redeem Assets:', formatUnits(position.pendingRedeem.assets, 6), 'USDC');
  console.log('Pending Redeem Shares:', formatUnits(position.pendingRedeem.shares, 18));
  console.log('Max Withdraw:', formatUnits(position.maxWithdraw, 6), 'USDC');
  console.log('Max Redeem:', formatUnits(position.maxRedeem, 18), 'shares');
  console.log('');

  // 5. Preview and execute deposit
  console.log('=== Deposit Example ===');
  const depositAmount = parseUnits('100', 6); // 100 USDC
  const expectedShares = await elitra.previewDeposit(depositAmount);
  console.log('Depositing:', formatUnits(depositAmount, 6), 'USDC');
  console.log('Expected shares:', formatUnits(expectedShares, 18));

  // Note: You need to approve USDC first
  // const assetAddress = await elitra.getAsset();
  // await approveERC20(assetAddress, VAULT_ADDRESS, depositAmount);

  try {
    const depositResult = await elitra.deposit(depositAmount);
    console.log('Deposit successful!');
    console.log('Transaction:', depositResult.hash);
    console.log('Shares received:', formatUnits(depositResult.shares, 18));
  } catch (error) {
    console.log('Deposit failed (this is expected if not approved):', error);
  }
  console.log('');

  // 6. Preview and execute redemption
  console.log('=== Redemption Example ===');
  const redeemShares = parseUnits('50', 18); // 50 shares
  const expectedAssets = await elitra.previewRedeem(redeemShares);
  console.log('Redeeming:', formatUnits(redeemShares, 18), 'shares');
  console.log('Expected assets:', formatUnits(expectedAssets, 6), 'USDC');

  try {
    const redeemResult = await elitra.requestRedeem(redeemShares);
    console.log('Redemption requested!');
    console.log('Transaction:', redeemResult.hash);

    if (redeemResult.isInstant) {
      console.log('Instant redemption!');
      console.log('Assets received:', formatUnits(redeemResult.value, 6), 'USDC');
    } else {
      console.log('Queued redemption');
      console.log('Request ID:', redeemResult.value);

      // Check pending
      const pending = await elitra.getPendingRedeem(account.address);
      console.log('Pending assets:', formatUnits(pending.assets, 6), 'USDC');
      console.log('Pending shares:', formatUnits(pending.shares, 18));
    }
  } catch (error) {
    console.log('Redemption failed:', error);
  }
  console.log('');

  // 7. Manage function example
  console.log('=== Manage Function Example ===');
  const targetToken = '0x...'; // Some ERC20 token
  const spenderAddress = '0x...'; // Some protocol

  // Encode an approve call
  const approveData = encodeApprove(spenderAddress, parseUnits('1000', 6));
  console.log('Encoded approve data:', approveData);

  try {
    const manageResult = await elitra.manage(targetToken, approveData);
    console.log('Manage call successful!');
    console.log('Transaction:', manageResult.hash);
  } catch (error) {
    console.log('Manage call failed (requires authorization):', error);
  }
  console.log('');

  // 8. Example: Depositing vault funds into another protocol
  console.log('=== Strategy Management Example ===');
  const strategyVault = '0x...'; // Another ERC4626 vault
  const depositIntoStrategy = parseUnits('1000', 6);

  // First approve
  const approveStrategyData = encodeApprove(strategyVault, depositIntoStrategy);

  // Then deposit
  const depositStrategyData = encodeERC4626Deposit(
    depositIntoStrategy,
    VAULT_ADDRESS // Vault receives the shares
  );

  console.log('This would:');
  console.log('1. Approve tokens to strategy vault');
  console.log('2. Deposit tokens into strategy vault');
  console.log('3. Update aggregated balance');
  console.log('');

  console.log('=== Example Complete ===');
}

// Run the example
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Error:', error);
    process.exit(1);
  });
