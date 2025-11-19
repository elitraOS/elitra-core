import { type Address, type Hash, type WalletClient } from 'viem';
import type { ElitraConfig, DepositResult, RedeemResult, ManageResult, ManageBatchResult, VaultState, UserPosition, DepositOptions, MintOptions, RedeemOptions, ManageOptions, ManageBatchOptions, PendingRedeem } from './types';
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
export declare class ElitraClient {
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
//# sourceMappingURL=client.d.ts.map