import {
  type Address,
  type Hash,
  type PublicClient,
  type WalletClient,
  parseEventLogs,
} from 'viem';
import type {
  ElitraConfig,
  DepositResult,
  RedeemResult,
  ManageResult,
  ManageBatchResult,
  VaultState,
  UserPosition,
  DepositOptions,
  MintOptions,
  RedeemOptions,
  ManageOptions,
  ManageBatchOptions,
  PendingRedeem,
} from './types';
import ElitraVaultAbi from './abis/ElitraVault.json';

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
export class ElitraClient {
  private vaultAddress: Address;
  private publicClient: PublicClient;
  private walletClient?: WalletClient;

  constructor(config: ElitraConfig) {
    this.vaultAddress = config.vaultAddress;
    this.publicClient = config.publicClient;
    this.walletClient = config.walletClient;
  }

  // ========================================= READ OPERATIONS =========================================

  /**
   * Get the vault's underlying asset address
   */
  async getAsset(): Promise<Address> {
    const asset = await this.publicClient.readContract({
      address: this.vaultAddress,
      abi: ElitraVaultAbi,
      functionName: 'asset',
    });
    return asset as Address;
  }

  /**
   * Get the total assets managed by the vault
   */
  async getTotalAssets(): Promise<bigint> {
    const totalAssets = await this.publicClient.readContract({
      address: this.vaultAddress,
      abi: ElitraVaultAbi,
      functionName: 'totalAssets',
    });
    return totalAssets as bigint;
  }

  /**
   * Get the total supply of vault shares
   */
  async getTotalSupply(): Promise<bigint> {
    const totalSupply = await this.publicClient.readContract({
      address: this.vaultAddress,
      abi: ElitraVaultAbi,
      functionName: 'totalSupply',
    });
    return totalSupply as bigint;
  }

  /**
   * Get the current price per share (in asset units)
   */
  async getPricePerShare(): Promise<bigint> {
    const [totalAssets, totalSupply] = await Promise.all([
      this.getTotalAssets(),
      this.getTotalSupply(),
    ]);

    if (totalSupply === 0n) {
      return 10n ** 18n; // 1:1 ratio when vault is empty
    }

    return (totalAssets * 10n ** 18n) / totalSupply;
  }

  /**
   * Preview the amount of shares received for a deposit
   */
  async previewDeposit(assets: bigint): Promise<bigint> {
    const shares = await this.publicClient.readContract({
      address: this.vaultAddress,
      abi: ElitraVaultAbi,
      functionName: 'previewDeposit',
      args: [assets],
    });
    return shares as bigint;
  }

  /**
   * Preview the amount of assets required to mint shares
   */
  async previewMint(shares: bigint): Promise<bigint> {
    const assets = await this.publicClient.readContract({
      address: this.vaultAddress,
      abi: ElitraVaultAbi,
      functionName: 'previewMint',
      args: [shares],
    });
    return assets as bigint;
  }

  /**
   * Preview the amount of assets received for redeeming shares
   */
  async previewRedeem(shares: bigint): Promise<bigint> {
    const assets = await this.publicClient.readContract({
      address: this.vaultAddress,
      abi: ElitraVaultAbi,
      functionName: 'previewRedeem',
      args: [shares],
    });
    return assets as bigint;
  }

  /**
   * Get available balance for withdrawals (excluding pending redemptions)
   */
  async getAvailableBalance(): Promise<bigint> {
    const balance = await this.publicClient.readContract({
      address: this.vaultAddress,
      abi: ElitraVaultAbi,
      functionName: 'getAvailableBalance',
    });
    return balance as bigint;
  }

  /**
   * Get pending redemption request for a user
   */
  async getPendingRedeem(user: Address): Promise<PendingRedeem> {
    const result = await this.publicClient.readContract({
      address: this.vaultAddress,
      abi: ElitraVaultAbi,
      functionName: 'pendingRedeemRequest',
      args: [user],
    }) as [bigint, bigint];

    return {
      assets: result[0],
      shares: result[1],
    };
  }

  /**
   * Get complete vault state
   */
  async getVaultState(): Promise<VaultState> {
    const [
      totalAssets,
      totalSupply,
      aggregatedUnderlyingBalances,
      totalPendingAssets,
      availableBalance,
      isPaused,
      lastBlockUpdated,
      lastPricePerShare,
    ] = await Promise.all([
      this.getTotalAssets(),
      this.getTotalSupply(),
      this.publicClient.readContract({
        address: this.vaultAddress,
        abi: ElitraVaultAbi,
        functionName: 'aggregatedUnderlyingBalances',
      }) as Promise<bigint>,
      this.publicClient.readContract({
        address: this.vaultAddress,
        abi: ElitraVaultAbi,
        functionName: 'totalPendingAssets',
      }) as Promise<bigint>,
      this.getAvailableBalance(),
      this.publicClient.readContract({
        address: this.vaultAddress,
        abi: ElitraVaultAbi,
        functionName: 'paused',
      }) as Promise<boolean>,
      this.publicClient.readContract({
        address: this.vaultAddress,
        abi: ElitraVaultAbi,
        functionName: 'lastBlockUpdated',
      }) as Promise<bigint>,
      this.publicClient.readContract({
        address: this.vaultAddress,
        abi: ElitraVaultAbi,
        functionName: 'lastPricePerShare',
      }) as Promise<bigint>,
    ]);

    const pricePerShare = totalSupply === 0n ? 10n ** 18n : (totalAssets * 10n ** 18n) / totalSupply;

    return {
      totalAssets,
      totalSupply,
      pricePerShare,
      aggregatedUnderlyingBalances,
      totalPendingAssets,
      availableBalance,
      isPaused,
      lastBlockUpdated,
      lastPricePerShare,
    };
  }

  /**
   * Get user's position in the vault
   */
  async getUserPosition(user: Address): Promise<UserPosition> {
    const [shares, pendingRedeem, maxWithdraw, maxRedeem] = await Promise.all([
      this.publicClient.readContract({
        address: this.vaultAddress,
        abi: ElitraVaultAbi,
        functionName: 'balanceOf',
        args: [user],
      }) as Promise<bigint>,
      this.getPendingRedeem(user),
      this.publicClient.readContract({
        address: this.vaultAddress,
        abi: ElitraVaultAbi,
        functionName: 'maxWithdraw',
        args: [user],
      }) as Promise<bigint>,
      this.publicClient.readContract({
        address: this.vaultAddress,
        abi: ElitraVaultAbi,
        functionName: 'maxRedeem',
        args: [user],
      }) as Promise<bigint>,
    ]);

    const assets = shares === 0n ? 0n : await this.previewRedeem(shares);

    return {
      shares,
      assets,
      pendingRedeem,
      maxWithdraw,
      maxRedeem,
    };
  }

  // ========================================= WRITE OPERATIONS =========================================

  /**
   * Deposit assets into the vault
   *
   * @param assets - Amount of assets to deposit
   * @param options - Deposit options
   * @returns Transaction hash and shares received
   */
  async deposit(assets: bigint, options: DepositOptions = {}): Promise<DepositResult> {
    if (!this.walletClient) {
      throw new Error('WalletClient is required for write operations');
    }

    const account = this.walletClient.account;
    if (!account) {
      throw new Error('WalletClient must have an account');
    }

    const receiver = options.receiver ?? account.address;

    // Simulate to get expected shares
    const expectedShares = await this.previewDeposit(assets);

    const hash = await this.walletClient.writeContract({
      address: this.vaultAddress,
      abi: ElitraVaultAbi,
      functionName: 'deposit',
      args: [assets, receiver],
      account,
      chain: this.walletClient.chain,
    });

    return {
      hash,
      shares: expectedShares,
    };
  }

  /**
   * Mint vault shares
   *
   * @param shares - Amount of shares to mint
   * @param options - Mint options
   * @returns Transaction hash and assets deposited
   */
  async mint(shares: bigint, options: MintOptions = {}): Promise<DepositResult> {
    if (!this.walletClient) {
      throw new Error('WalletClient is required for write operations');
    }

    const account = this.walletClient.account;
    if (!account) {
      throw new Error('WalletClient must have an account');
    }

    const receiver = options.receiver ?? account.address;

    const hash = await this.walletClient.writeContract({
      address: this.vaultAddress,
      abi: ElitraVaultAbi,
      functionName: 'mint',
      args: [shares, receiver],
      account,
      chain: this.walletClient.chain,
    });

    return {
      hash,
      shares,
    };
  }

  /**
   * Request redemption of vault shares
   *
   * @param shares - Amount of shares to redeem
   * @param options - Redeem options
   * @returns Transaction hash and redemption details
   */
  async requestRedeem(shares: bigint, options: RedeemOptions = {}): Promise<RedeemResult> {
    if (!this.walletClient) {
      throw new Error('WalletClient is required for write operations');
    }

    const account = this.walletClient.account;
    if (!account) {
      throw new Error('WalletClient must have an account');
    }

    const receiver = options.receiver ?? account.address;
    const owner = options.owner ?? account.address;

    const hash = await this.walletClient.writeContract({
      address: this.vaultAddress,
      abi: ElitraVaultAbi,
      functionName: 'requestRedeem',
      args: [shares, receiver, owner],
      account,
      chain: this.walletClient.chain,
    });

    // Wait for transaction to get the event
    const receipt = await this.publicClient.waitForTransactionReceipt({ hash });

    // Parse RedeemRequest event to determine if instant or queued
    const logs = parseEventLogs({
      abi: ElitraVaultAbi,
      logs: receipt.logs,
      eventName: 'RedeemRequest',
    });

    if (logs.length > 0) {
      const event = logs[0];
      const isInstant = (event as any).args.instant as boolean;
      const assets = (event as any).args.assets as bigint;

      return {
        hash,
        value: isInstant ? assets : 0n, // 0 is the REQUEST_ID for queued
        isInstant,
      };
    }

    // Fallback
    const expectedAssets = await this.previewRedeem(shares);
    return {
      hash,
      value: expectedAssets,
      isInstant: true,
    };
  }

  /**
   * Call the manage function to execute arbitrary calls from the vault
   *
   * @param target - Target contract address
   * @param data - Encoded function call data
   * @param options - Manage options
   * @returns Transaction hash and return data
   */
  async manage(target: Address, data: `0x${string}`, options: ManageOptions = {}): Promise<ManageResult> {
    if (!this.walletClient) {
      throw new Error('WalletClient is required for write operations');
    }

    const account = this.walletClient.account;
    if (!account) {
      throw new Error('WalletClient must have an account');
    }

    const value = options.value ?? 0n;

    const hash = await this.walletClient.writeContract({
      address: this.vaultAddress,
      abi: ElitraVaultAbi,
      functionName: 'manage',
      args: [target, data, value],
      account,
      gas: options.gasLimit,
      chain: this.walletClient.chain,
    });

    return {
      hash,
      data,
    };
  }

  /**
   * Call the manageBatch function to execute multiple arbitrary calls sequentially from the vault
   *
   * @param targets - Array of target contract addresses
   * @param data - Array of encoded function call data
   * @param values - Array of ETH values to send with each call
   * @param options - ManageBatch options
   * @returns Transaction hash
   */
  async manageBatch(
    targets: Address[],
    data: `0x${string}`[],
    values: bigint[],
    options: ManageBatchOptions = {}
  ): Promise<ManageBatchResult> {
    if (!this.walletClient) {
      throw new Error('WalletClient is required for write operations');
    }

    const account = this.walletClient.account;
    if (!account) {
      throw new Error('WalletClient must have an account');
    }

    const hash = await this.walletClient.writeContract({
      address: this.vaultAddress,
      abi: ElitraVaultAbi,
      functionName: 'manageBatch',
      args: [targets, data, values],
      account,
      gas: options.gasLimit,
      chain: this.walletClient.chain,
    });

    return {
      hash,
    };
  }

  /**
   * Update the vault's balance with new aggregated balance
   * Requires authorization
   *
   * @param newAggregatedBalance - New total balance across all protocols
   * @returns Transaction hash
   */
  async updateBalance(newAggregatedBalance: bigint): Promise<Hash> {
    if (!this.walletClient) {
      throw new Error('WalletClient is required for write operations');
    }

    const account = this.walletClient.account;
    if (!account) {
      throw new Error('WalletClient must have an account');
    }

    const hash = await this.walletClient.writeContract({
      address: this.vaultAddress,
      abi: ElitraVaultAbi,
      functionName: 'updateBalance',
      args: [newAggregatedBalance],
      account,
      chain: this.walletClient.chain,
    });

    return hash;
  }

  /**
   * Pause the vault (requires authorization)
   */
  async pause(): Promise<Hash> {
    if (!this.walletClient) {
      throw new Error('WalletClient is required for write operations');
    }

    const account = this.walletClient.account;
    if (!account) {
      throw new Error('WalletClient must have an account');
    }

    const hash = await this.walletClient.writeContract({
      address: this.vaultAddress,
      abi: ElitraVaultAbi,
      functionName: 'pause',
      account,
      chain: this.walletClient.chain,
    });

    return hash;
  }

  /**
   * Unpause the vault (requires authorization)
   */
  async unpause(): Promise<Hash> {
    if (!this.walletClient) {
      throw new Error('WalletClient is required for write operations');
    }

    const account = this.walletClient.account;
    if (!account) {
      throw new Error('WalletClient must have an account');
    }

    const hash = await this.walletClient.writeContract({
      address: this.vaultAddress,
      abi: ElitraVaultAbi,
      functionName: 'unpause',
      account,
      chain: this.walletClient.chain,
    });

    return hash;
  }

  // ========================================= UTILITY METHODS =========================================

  /**
   * Get the vault address
   */
  getVaultAddress(): Address {
    return this.vaultAddress;
  }

  /**
   * Set a new wallet client
   */
  setWalletClient(walletClient: WalletClient): void {
    this.walletClient = walletClient;
  }
}
