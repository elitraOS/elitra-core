/**
 * @elitra/sdk - TypeScript SDK for Elitra Vaults
 *
 * A comprehensive SDK for interacting with Elitra Vaults using Viem.
 * Provides type-safe methods for deposits, withdrawals, redemptions, and vault management.
 *
 * @example
 * ```typescript
 * import { createPublicClient, createWalletClient, http } from 'viem';
 * import { sei } from 'viem/chains';
 * import { privateKeyToAccount } from 'viem/accounts';
 * import { ElitraClient } from '@elitra/sdk';
 *
 * // Setup clients
 * const publicClient = createPublicClient({
 *   chain: sei,
 *   transport: http()
 * });
 *
 * const walletClient = createWalletClient({
 *   chain: sei,
 *   transport: http(),
 *   account: privateKeyToAccount('0x...')
 * });
 *
 * // Create Elitra client
 * const elitra = new ElitraClient({
 *   vaultAddress: '0x...',
 *   publicClient,
 *   walletClient
 * });
 *
 * // Use the client
 * const state = await elitra.getVaultState();
 * console.log('Total Assets:', state.totalAssets);
 *
 * const result = await elitra.deposit(parseUnits('100', 6));
 * console.log('Deposited! Shares received:', result.shares);
 * ```
 *
 * @packageDocumentation
 */
export { ElitraClient } from './client';
export * from './types';
export * from './utils';
export { parseUnits, formatUnits, type Address, type Hash } from 'viem';
//# sourceMappingURL=index.d.ts.map