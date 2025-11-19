import { type Address } from 'viem';
/**
 * Encode a function call for use with the manage function
 *
 * @example
 * ```typescript
 * // Encode an ERC20 approve call
 * const data = encodeManageCall(
 *   ['function approve(address spender, uint256 amount) returns (bool)'],
 *   'approve',
 *   [spenderAddress, parseUnits('100', 6)]
 * );
 *
 * // Execute via vault
 * await elitra.manage(tokenAddress, data);
 * ```
 */
export declare function encodeManageCall(abi: string[], functionName: string, args: readonly unknown[]): `0x${string}`;
/**
 * Encode an ERC20 approve call
 */
export declare function encodeApprove(spender: Address, amount: bigint): `0x${string}`;
/**
 * Encode an ERC20 transfer call
 */
export declare function encodeTransfer(to: Address, amount: bigint): `0x${string}`;
/**
 * Encode an ERC4626 deposit call
 */
export declare function encodeERC4626Deposit(assets: bigint, receiver: Address): `0x${string}`;
/**
 * Encode an ERC4626 withdraw call
 */
export declare function encodeERC4626Withdraw(assets: bigint, receiver: Address, owner: Address): `0x${string}`;
/**
 * Calculate the equivalent shares for a given amount of assets
 *
 * @param assets - Amount of assets
 * @param totalAssets - Total assets in the vault
 * @param totalSupply - Total supply of shares
 * @returns Equivalent shares
 */
export declare function convertToShares(assets: bigint, totalAssets: bigint, totalSupply: bigint): bigint;
/**
 * Calculate the equivalent assets for a given amount of shares
 *
 * @param shares - Amount of shares
 * @param totalAssets - Total assets in the vault
 * @param totalSupply - Total supply of shares
 * @returns Equivalent assets
 */
export declare function convertToAssets(shares: bigint, totalAssets: bigint, totalSupply: bigint): bigint;
/**
 * Calculate APY from two price per share values
 *
 * @param oldPPS - Old price per share
 * @param newPPS - New price per share
 * @param timeDelta - Time delta in seconds
 * @returns APY as a percentage (e.g., 5.5 for 5.5%)
 */
export declare function calculateAPY(oldPPS: bigint, newPPS: bigint, timeDelta: bigint): number;
/**
 * Format shares to human-readable string
 *
 * @param shares - Shares amount (in wei)
 * @param decimals - Token decimals (default 18)
 * @param precision - Number of decimal places to show (default 4)
 * @returns Formatted string
 */
export declare function formatShares(shares: bigint, decimals?: number, precision?: number): string;
/**
 * Parse human-readable amount to bigint
 *
 * @param amount - Amount as string (e.g., "100.5")
 * @param decimals - Token decimals (default 18)
 * @returns Amount in wei
 */
export declare function parseAmount(amount: string, decimals?: number): bigint;
//# sourceMappingURL=utils.d.ts.map