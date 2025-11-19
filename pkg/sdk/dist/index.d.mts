import { Address, PublicClient, WalletClient, Hash } from 'viem';
export { Address, Hash, formatUnits, parseUnits } from 'viem';

/**
 * Configuration for the Elitra SDK
 */
interface ElitraConfig {
    /** The address of the deployed ElitraVault contract */
    vaultAddress: Address;
    /** Public client for reading blockchain state */
    publicClient: PublicClient;
    /** Optional wallet client for write operations */
    walletClient?: WalletClient;
}
/**
 * Pending redemption request details
 */
interface PendingRedeem {
    /** Amount of assets pending redemption */
    assets: bigint;
    /** Amount of shares pending redemption */
    shares: bigint;
}
/**
 * Result of a deposit operation
 */
interface DepositResult {
    /** Transaction hash */
    hash: Hash;
    /** Amount of shares received */
    shares: bigint;
}
/**
 * Result of a redemption request
 */
interface RedeemResult {
    /** Transaction hash */
    hash: Hash;
    /** Amount of assets to be received (for instant) or request ID (for queued) */
    value: bigint;
    /** Whether the redemption was instant or queued */
    isInstant: boolean;
}
/**
 * Result of a manage operation
 */
interface ManageResult {
    /** Transaction hash */
    hash: Hash;
    /** Return data from the called function */
    data: `0x${string}`;
}
/**
 * Vault state information
 */
interface VaultState {
    /** Total assets managed by the vault */
    totalAssets: bigint;
    /** Total shares issued by the vault */
    totalSupply: bigint;
    /** Current price per share (assets per share) */
    pricePerShare: bigint;
    /** Assets aggregated in external protocols */
    aggregatedUnderlyingBalances: bigint;
    /** Total assets pending redemption */
    totalPendingAssets: bigint;
    /** Available balance for withdrawals */
    availableBalance: bigint;
    /** Whether the vault is paused */
    isPaused: boolean;
    /** Last block when balance was updated */
    lastBlockUpdated: bigint;
    /** Last price per share recorded */
    lastPricePerShare: bigint;
}
/**
 * User position in the vault
 */
interface UserPosition {
    /** User's share balance */
    shares: bigint;
    /** User's asset value (shares * pricePerShare) */
    assets: bigint;
    /** User's pending redemption */
    pendingRedeem: PendingRedeem;
    /** Maximum assets the user can withdraw */
    maxWithdraw: bigint;
    /** Maximum shares the user can redeem */
    maxRedeem: bigint;
}
/**
 * Options for deposit operations
 */
interface DepositOptions {
    /** Recipient address (defaults to sender) */
    receiver?: Address;
    /** Maximum amount of assets to deposit (for slippage protection) */
    maxAssets?: bigint;
}
/**
 * Options for mint operations
 */
interface MintOptions {
    /** Recipient address (defaults to sender) */
    receiver?: Address;
    /** Maximum amount of shares to mint (for slippage protection) */
    maxShares?: bigint;
}
/**
 * Options for redeem operations
 */
interface RedeemOptions {
    /** Recipient address (defaults to sender) */
    receiver?: Address;
    /** Owner of shares (defaults to sender) */
    owner?: Address;
    /** Minimum amount of assets to receive (for slippage protection) */
    minAssets?: bigint;
}
/**
 * Options for manage operations
 */
interface ManageOptions {
    /** Amount of ETH to send with the call */
    value?: bigint;
    /** Gas limit for the transaction */
    gasLimit?: bigint;
}
/**
 * Options for manageBatch operations
 */
interface ManageBatchOptions {
    /** Gas limit for the transaction */
    gasLimit?: bigint;
}
/**
 * Result of a manageBatch operation
 */
interface ManageBatchResult {
    /** Transaction hash */
    hash: Hash;
}

/**
 * Elitra Vault SDK Client
 *
 * Provides a typed interface for interacting with Elitra Vaults using Viem.
 *
 * @example
 * ```typescript
 * import { createPublicClient, createWalletClient, http } from 'viem';
 * import { ElitraClient } from '@elitra/sdk';
 *
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
 * const elitra = new ElitraClient({
 *   vaultAddress: '0x...',
 *   publicClient,
 *   walletClient
 * });
 *
 * // Deposit assets
 * const result = await elitra.deposit(parseUnits('100', 6));
 * ```
 */
declare class ElitraClient {
    private vaultAddress;
    private publicClient;
    private walletClient?;
    constructor(config: ElitraConfig);
    /**
     * Get the vault's underlying asset address
     */
    getAsset(): Promise<Address>;
    /**
     * Get the total assets managed by the vault
     */
    getTotalAssets(): Promise<bigint>;
    /**
     * Get the total supply of vault shares
     */
    getTotalSupply(): Promise<bigint>;
    /**
     * Get the current price per share (in asset units)
     */
    getPricePerShare(): Promise<bigint>;
    /**
     * Preview the amount of shares received for a deposit
     */
    previewDeposit(assets: bigint): Promise<bigint>;
    /**
     * Preview the amount of assets required to mint shares
     */
    previewMint(shares: bigint): Promise<bigint>;
    /**
     * Preview the amount of assets received for redeeming shares
     */
    previewRedeem(shares: bigint): Promise<bigint>;
    /**
     * Get available balance for withdrawals (excluding pending redemptions)
     */
    getAvailableBalance(): Promise<bigint>;
    /**
     * Get pending redemption request for a user
     */
    getPendingRedeem(user: Address): Promise<PendingRedeem>;
    /**
     * Get complete vault state
     */
    getVaultState(): Promise<VaultState>;
    /**
     * Get user's position in the vault
     */
    getUserPosition(user: Address): Promise<UserPosition>;
    /**
     * Deposit assets into the vault
     *
     * @param assets - Amount of assets to deposit
     * @param options - Deposit options
     * @returns Transaction hash and shares received
     */
    deposit(assets: bigint, options?: DepositOptions): Promise<DepositResult>;
    /**
     * Mint vault shares
     *
     * @param shares - Amount of shares to mint
     * @param options - Mint options
     * @returns Transaction hash and assets deposited
     */
    mint(shares: bigint, options?: MintOptions): Promise<DepositResult>;
    /**
     * Request redemption of vault shares
     *
     * @param shares - Amount of shares to redeem
     * @param options - Redeem options
     * @returns Transaction hash and redemption details
     */
    requestRedeem(shares: bigint, options?: RedeemOptions): Promise<RedeemResult>;
    /**
     * Call the manage function to execute arbitrary calls from the vault
     *
     * @param target - Target contract address
     * @param data - Encoded function call data
     * @param options - Manage options
     * @returns Transaction hash and return data
     */
    manage(target: Address, data: `0x${string}`, options?: ManageOptions): Promise<ManageResult>;
    /**
     * Call the manageBatch function to execute multiple arbitrary calls sequentially from the vault
     *
     * @param targets - Array of target contract addresses
     * @param data - Array of encoded function call data
     * @param values - Array of ETH values to send with each call
     * @param options - ManageBatch options
     * @returns Transaction hash
     */
    manageBatch(targets: Address[], data: `0x${string}`[], values: bigint[], options?: ManageBatchOptions): Promise<ManageBatchResult>;
    /**
     * Update the vault's balance with new aggregated balance
     * Requires authorization
     *
     * @param newAggregatedBalance - New total balance across all protocols
     * @returns Transaction hash
     */
    updateBalance(newAggregatedBalance: bigint): Promise<Hash>;
    /**
     * Pause the vault (requires authorization)
     */
    pause(): Promise<Hash>;
    /**
     * Unpause the vault (requires authorization)
     */
    unpause(): Promise<Hash>;
    /**
     * Fulfill a pending redemption request
     *
     * @param receiver - Address to receive the assets
     * @param shares - Amount of shares to fulfill
     * @param assets - Amount of assets to redeem
     * @returns Transaction hash
     */
    fulfillRedeem(receiver: Address, shares: bigint, assets: bigint): Promise<Hash>;
    /**
     * Get the vault address
     */
    getVaultAddress(): Address;
    /**
     * Set a new wallet client
     */
    setWalletClient(walletClient: WalletClient): void;
}

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
declare function encodeManageCall(abi: string[], functionName: string, args: readonly unknown[]): `0x${string}`;
/**
 * Encode an ERC20 approve call
 */
declare function encodeApprove(spender: Address, amount: bigint): `0x${string}`;
/**
 * Encode an ERC20 transfer call
 */
declare function encodeTransfer(to: Address, amount: bigint): `0x${string}`;
/**
 * Encode an ERC4626 deposit call
 */
declare function encodeERC4626Deposit(assets: bigint, receiver: Address): `0x${string}`;
/**
 * Encode an ERC4626 withdraw call
 */
declare function encodeERC4626Withdraw(assets: bigint, receiver: Address, owner: Address): `0x${string}`;
/**
 * Calculate the equivalent shares for a given amount of assets
 *
 * @param assets - Amount of assets
 * @param totalAssets - Total assets in the vault
 * @param totalSupply - Total supply of shares
 * @returns Equivalent shares
 */
declare function convertToShares(assets: bigint, totalAssets: bigint, totalSupply: bigint): bigint;
/**
 * Calculate the equivalent assets for a given amount of shares
 *
 * @param shares - Amount of shares
 * @param totalAssets - Total assets in the vault
 * @param totalSupply - Total supply of shares
 * @returns Equivalent assets
 */
declare function convertToAssets(shares: bigint, totalAssets: bigint, totalSupply: bigint): bigint;
/**
 * Calculate APY from two price per share values
 *
 * @param oldPPS - Old price per share
 * @param newPPS - New price per share
 * @param timeDelta - Time delta in seconds
 * @returns APY as a percentage (e.g., 5.5 for 5.5%)
 */
declare function calculateAPY(oldPPS: bigint, newPPS: bigint, timeDelta: bigint): number;
/**
 * Format shares to human-readable string
 *
 * @param shares - Shares amount (in wei)
 * @param decimals - Token decimals (default 18)
 * @param precision - Number of decimal places to show (default 4)
 * @returns Formatted string
 */
declare function formatShares(shares: bigint, decimals?: number, precision?: number): string;
/**
 * Parse human-readable amount to bigint
 *
 * @param amount - Amount as string (e.g., "100.5")
 * @param decimals - Token decimals (default 18)
 * @returns Amount in wei
 */
declare function parseAmount(amount: string, decimals?: number): bigint;

export { type DepositOptions, type DepositResult, ElitraClient, type ElitraConfig, type ManageBatchOptions, type ManageBatchResult, type ManageOptions, type ManageResult, type MintOptions, type PendingRedeem, type RedeemOptions, type RedeemResult, type UserPosition, type VaultState, calculateAPY, convertToAssets, convertToShares, encodeApprove, encodeERC4626Deposit, encodeERC4626Withdraw, encodeManageCall, encodeTransfer, formatShares, parseAmount };
