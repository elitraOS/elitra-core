import type { Address, Hash, PublicClient, WalletClient } from 'viem';

/**
 * Configuration for the Elitra SDK
 */
export interface ElitraConfig {
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
export interface PendingRedeem {
  /** Amount of assets pending redemption */
  assets: bigint;
}

/**
 * Result of a deposit operation
 */
export interface DepositResult {
  /** Transaction hash */
  hash: Hash;
  /** Amount of shares received */
  shares: bigint;
}

/**
 * Result of a redemption request
 */
export interface RedeemResult {
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
export interface ManageResult {
  /** Transaction hash */
  hash: Hash;
  /** Return data from the called function */
  data: `0x${string}`;
}

/**
 * Vault state information
 */
export interface VaultState {
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
export interface UserPosition {
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
export interface DepositOptions {
  /** Recipient address (defaults to sender) */
  receiver?: Address;
  /** Maximum amount of assets to deposit (for slippage protection) */
  maxAssets?: bigint;
}

/**
 * Options for mint operations
 */
export interface MintOptions {
  /** Recipient address (defaults to sender) */
  receiver?: Address;
  /** Maximum amount of shares to mint (for slippage protection) */
  maxShares?: bigint;
}

/**
 * Options for redeem operations
 */
export interface RedeemOptions {
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
export interface ManageOptions {
  /** Amount of ETH to send with the call */
  value?: bigint;
  /** Gas limit for the transaction */
  gasLimit?: bigint;
}

/**
 * Options for manageBatch operations
 */
export interface ManageBatchOptions {
  /** Gas limit for the transaction */
  gasLimit?: bigint;
}

/**
 * Result of a manageBatch operation
 */
export interface ManageBatchResult {
  /** Transaction hash */
  hash: Hash;
}
