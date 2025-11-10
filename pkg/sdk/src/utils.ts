import { type Address, encodeFunctionData, parseAbi } from 'viem';

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
export function encodeManageCall(
  abi: string[],
  functionName: string,
  args: readonly unknown[]
): `0x${string}` {
  return encodeFunctionData({
    abi: parseAbi(abi),
    functionName,
    args,
  });
}

/**
 * Encode an ERC20 approve call
 */
export function encodeApprove(spender: Address, amount: bigint): `0x${string}` {
  return encodeManageCall(
    ['function approve(address spender, uint256 amount) returns (bool)'],
    'approve',
    [spender, amount]
  );
}

/**
 * Encode an ERC20 transfer call
 */
export function encodeTransfer(to: Address, amount: bigint): `0x${string}` {
  return encodeManageCall(
    ['function transfer(address to, uint256 amount) returns (bool)'],
    'transfer',
    [to, amount]
  );
}

/**
 * Encode an ERC4626 deposit call
 */
export function encodeERC4626Deposit(assets: bigint, receiver: Address): `0x${string}` {
  return encodeManageCall(
    ['function deposit(uint256 assets, address receiver) returns (uint256)'],
    'deposit',
    [assets, receiver]
  );
}

/**
 * Encode an ERC4626 withdraw call
 */
export function encodeERC4626Withdraw(
  assets: bigint,
  receiver: Address,
  owner: Address
): `0x${string}` {
  return encodeManageCall(
    ['function withdraw(uint256 assets, address receiver, address owner) returns (uint256)'],
    'withdraw',
    [assets, receiver, owner]
  );
}

/**
 * Calculate the equivalent shares for a given amount of assets
 *
 * @param assets - Amount of assets
 * @param totalAssets - Total assets in the vault
 * @param totalSupply - Total supply of shares
 * @returns Equivalent shares
 */
export function convertToShares(
  assets: bigint,
  totalAssets: bigint,
  totalSupply: bigint
): bigint {
  if (totalSupply === 0n) {
    return assets; // 1:1 ratio when vault is empty
  }
  return (assets * totalSupply) / totalAssets;
}

/**
 * Calculate the equivalent assets for a given amount of shares
 *
 * @param shares - Amount of shares
 * @param totalAssets - Total assets in the vault
 * @param totalSupply - Total supply of shares
 * @returns Equivalent assets
 */
export function convertToAssets(
  shares: bigint,
  totalAssets: bigint,
  totalSupply: bigint
): bigint {
  if (totalSupply === 0n) {
    return 0n;
  }
  return (shares * totalAssets) / totalSupply;
}

/**
 * Calculate APY from two price per share values
 *
 * @param oldPPS - Old price per share
 * @param newPPS - New price per share
 * @param timeDelta - Time delta in seconds
 * @returns APY as a percentage (e.g., 5.5 for 5.5%)
 */
export function calculateAPY(oldPPS: bigint, newPPS: bigint, timeDelta: bigint): number {
  if (oldPPS === 0n || timeDelta === 0n) {
    return 0;
  }

  const priceChange = Number(newPPS - oldPPS);
  const oldPrice = Number(oldPPS);
  const secondsPerYear = 365.25 * 24 * 60 * 60;
  const timeInSeconds = Number(timeDelta);

  const periodReturn = priceChange / oldPrice;
  const periodsPerYear = secondsPerYear / timeInSeconds;

  // APY = ((1 + period_return)^periods_per_year - 1) * 100
  const apy = (Math.pow(1 + periodReturn, periodsPerYear) - 1) * 100;

  return apy;
}

/**
 * Format shares to human-readable string
 *
 * @param shares - Shares amount (in wei)
 * @param decimals - Token decimals (default 18)
 * @param precision - Number of decimal places to show (default 4)
 * @returns Formatted string
 */
export function formatShares(shares: bigint, decimals = 18, precision = 4): string {
  const divisor = 10n ** BigInt(decimals);
  const whole = shares / divisor;
  const remainder = shares % divisor;

  const remainderStr = remainder.toString().padStart(decimals, '0');
  const decimalPart = remainderStr.slice(0, precision);

  if (precision === 0 || BigInt(decimalPart) === 0n) {
    return whole.toString();
  }

  return `${whole}.${decimalPart}`;
}

/**
 * Parse human-readable amount to bigint
 *
 * @param amount - Amount as string (e.g., "100.5")
 * @param decimals - Token decimals (default 18)
 * @returns Amount in wei
 */
export function parseAmount(amount: string, decimals = 18): bigint {
  const [whole, fraction = ''] = amount.split('.');
  const paddedFraction = fraction.padEnd(decimals, '0').slice(0, decimals);
  return BigInt(whole + paddedFraction);
}
