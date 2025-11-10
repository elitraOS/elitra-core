# @elitra/sdk

TypeScript SDK for interacting with Elitra Vaults using [Viem](https://viem.sh).

## Features

- 🔒 **Type-safe** - Full TypeScript support with comprehensive types
- 📦 **ERC-4626 Compliant** - Standard vault operations (deposit, mint, redeem)
- 🎯 **Elitra-specific** - Support for queued redemptions, manage function, and balance updates
- 🚀 **Modern** - Built on Viem for optimal performance
- 📖 **Well-documented** - Extensive JSDoc comments and examples

## Installation

```bash
npm install @elitra/sdk viem
# or
yarn add @elitra/sdk viem
# or
pnpm add @elitra/sdk viem
```

## Quick Start

```typescript
import { createPublicClient, createWalletClient, http, parseUnits } from 'viem';
import { sei } from 'viem/chains';
import { privateKeyToAccount } from 'viem/accounts';
import { ElitraClient } from '@elitra/sdk';

// 1. Setup Viem clients
const publicClient = createPublicClient({
  chain: sei,
  transport: http('https://evm-rpc.sei-apis.com')
});

const account = privateKeyToAccount('0x...');
const walletClient = createWalletClient({
  chain: sei,
  transport: http('https://evm-rpc.sei-apis.com'),
  account
});

// 2. Create Elitra client
const elitra = new ElitraClient({
  vaultAddress: '0x...', // Your vault address
  publicClient,
  walletClient
});

// 3. Interact with the vault
const vaultState = await elitra.getVaultState();
console.log('Total Assets:', vaultState.totalAssets);
console.log('Price Per Share:', vaultState.pricePerShare);

// Deposit 100 USDC (6 decimals)
const depositResult = await elitra.deposit(parseUnits('100', 6));
console.log('Transaction:', depositResult.hash);
console.log('Shares received:', depositResult.shares);
```

## Core Features

### Read Operations

#### Get Vault State

```typescript
const state = await elitra.getVaultState();
console.log('Total Assets:', state.totalAssets);
console.log('Total Supply:', state.totalSupply);
console.log('Price Per Share:', state.pricePerShare);
console.log('Available Balance:', state.availableBalance);
console.log('Is Paused:', state.isPaused);
```

#### Get User Position

```typescript
const position = await elitra.getUserPosition('0x...');
console.log('Shares:', position.shares);
console.log('Asset Value:', position.assets);
console.log('Pending Redemption:', position.pendingRedeem);
console.log('Max Withdraw:', position.maxWithdraw);
```

#### Preview Operations

```typescript
// Preview deposit
const shares = await elitra.previewDeposit(parseUnits('100', 6));

// Preview redemption
const assets = await elitra.previewRedeem(shares);
```

### Write Operations

#### Deposit Assets

```typescript
// Simple deposit
const result = await elitra.deposit(parseUnits('100', 6));

// Deposit for another address
const result = await elitra.deposit(parseUnits('100', 6), {
  receiver: '0x...'
});
```

#### Mint Shares

```typescript
// Mint specific amount of shares
const result = await elitra.mint(parseUnits('100', 18));
```

#### Request Redemption

Elitra Vaults support both instant and queued redemptions:

```typescript
const result = await elitra.requestRedeem(shares);

if (result.isInstant) {
  console.log('Instant redemption! Assets received:', result.value);
} else {
  console.log('Queued redemption. Request ID:', result.value);

  // Check pending redemption
  const pending = await elitra.getPendingRedeem(userAddress);
  console.log('Pending assets:', pending.assets);
  console.log('Pending shares:', pending.shares);
}
```

### Management Operations

The `manage` function allows authorized users to make arbitrary contract calls from the vault:

```typescript
import { encodeApprove, encodeERC4626Deposit } from '@elitra/sdk';

// Approve tokens
const approveData = encodeApprove(
  spenderAddress,
  parseUnits('1000', 6)
);
await elitra.manage(tokenAddress, approveData);

// Deposit into another ERC4626 vault
const depositData = encodeERC4626Deposit(
  parseUnits('100', 6),
  vaultAddress
);
await elitra.manage(targetVaultAddress, depositData);

// Custom contract interaction
import { encodeFunctionData, parseAbi } from 'viem';

const customData = encodeFunctionData({
  abi: parseAbi(['function stake(uint256 amount)']),
  functionName: 'stake',
  args: [parseUnits('100', 18)]
});
await elitra.manage(stakingContract, customData);
```

### Admin Operations

```typescript
// Update vault balance (requires authorization)
await elitra.updateBalance(newAggregatedBalance);

// Pause vault
await elitra.pause();

// Unpause vault
await elitra.unpause();
```

## Utility Functions

### Encoding Helpers

```typescript
import {
  encodeApprove,
  encodeTransfer,
  encodeERC4626Deposit,
  encodeERC4626Withdraw,
  encodeManageCall
} from '@elitra/sdk';

// Encode ERC20 approve
const data = encodeApprove(spenderAddress, amount);

// Encode custom function call
const customData = encodeManageCall(
  ['function myFunction(uint256 x, address y)'],
  'myFunction',
  [123n, '0x...']
);
```

### Conversion Helpers

```typescript
import { convertToShares, convertToAssets } from '@elitra/sdk';

const shares = convertToShares(assets, totalAssets, totalSupply);
const assets = convertToAssets(shares, totalAssets, totalSupply);
```

### Formatting Helpers

```typescript
import { formatShares, parseAmount } from '@elitra/sdk';

// Format for display
const formatted = formatShares(1234567890000000000n, 18, 4);
// "1.2345"

// Parse user input
const amount = parseAmount("100.5", 6);
// 100500000n
```

### APY Calculation

```typescript
import { calculateAPY } from '@elitra/sdk';

const apy = calculateAPY(
  oldPricePerShare,
  newPricePerShare,
  timeDeltaInSeconds
);
console.log(`APY: ${apy.toFixed(2)}%`);
```

## Advanced Usage

### Custom RPC Configuration

```typescript
import { createPublicClient, http } from 'viem';
import { sei } from 'viem/chains';

const publicClient = createPublicClient({
  chain: sei,
  transport: http('https://your-custom-rpc.com', {
    timeout: 30_000,
    retryCount: 3,
  }),
  batch: {
    multicall: true,
  },
});
```

### Read-Only Client

If you only need to read data, you can create a client without a wallet:

```typescript
const elitra = new ElitraClient({
  vaultAddress: '0x...',
  publicClient,
  // No walletClient
});

// Read operations work fine
const state = await elitra.getVaultState();

// Write operations will throw
await elitra.deposit(amount); // Error: WalletClient is required
```

### Adding Wallet Later

```typescript
const elitra = new ElitraClient({
  vaultAddress: '0x...',
  publicClient,
});

// Later, add a wallet
elitra.setWalletClient(walletClient);

// Now write operations work
await elitra.deposit(amount);
```

### Error Handling

```typescript
try {
  const result = await elitra.deposit(amount);
  console.log('Success:', result.hash);
} catch (error) {
  if (error instanceof Error) {
    if (error.message.includes('User rejected')) {
      console.log('Transaction was rejected');
    } else if (error.message.includes('insufficient funds')) {
      console.log('Insufficient balance');
    } else {
      console.error('Transaction failed:', error.message);
    }
  }
}
```

## Type Definitions

The SDK exports comprehensive TypeScript types:

```typescript
import type {
  ElitraConfig,
  VaultState,
  UserPosition,
  PendingRedeem,
  DepositResult,
  RedeemResult,
  ManageResult,
  DepositOptions,
  MintOptions,
  RedeemOptions,
  ManageOptions,
} from '@elitra/sdk';
```

## Examples

### Complete Deposit Flow

```typescript
import { parseUnits, formatUnits } from 'viem';

// 1. Check vault state
const state = await elitra.getVaultState();
if (state.isPaused) {
  throw new Error('Vault is paused');
}

// 2. Preview deposit
const depositAmount = parseUnits('100', 6); // 100 USDC
const expectedShares = await elitra.previewDeposit(depositAmount);
console.log('Expected shares:', formatUnits(expectedShares, 18));

// 3. Approve token (if needed)
const assetAddress = await elitra.getAsset();
// Use your ERC20 client to approve

// 4. Execute deposit
const result = await elitra.deposit(depositAmount);
console.log('Transaction:', result.hash);
console.log('Shares received:', formatUnits(result.shares, 18));

// 5. Verify position
const position = await elitra.getUserPosition(account.address);
console.log('New balance:', formatUnits(position.shares, 18));
```

### Complete Redemption Flow

```typescript
// 1. Get user position
const position = await elitra.getUserPosition(account.address);
console.log('Current shares:', position.shares);
console.log('Max redeemable:', position.maxRedeem);

// 2. Preview redemption
const redeemShares = position.shares / 2n; // Redeem half
const expectedAssets = await elitra.previewRedeem(redeemShares);
console.log('Expected assets:', expectedAssets);

// 3. Request redemption
const result = await elitra.requestRedeem(redeemShares);

if (result.isInstant) {
  console.log('Redeemed instantly!');
  console.log('Assets received:', result.value);
} else {
  console.log('Redemption queued');

  // 4. Check pending redemption
  const pending = await elitra.getPendingRedeem(account.address);
  console.log('Pending assets:', pending.assets);
  console.log('Pending shares:', pending.shares);
}
```

### Strategy Management Example

```typescript
import { encodeApprove, encodeERC4626Deposit } from '@elitra/sdk';

const STRATEGY_VAULT = '0x...';
const USDC = '0x...';

// 1. Approve USDC to strategy vault
const approveData = encodeApprove(
  STRATEGY_VAULT,
  parseUnits('1000', 6)
);
await elitra.manage(USDC, approveData);

// 2. Deposit into strategy
const depositData = encodeERC4626Deposit(
  parseUnits('1000', 6),
  elitra.getVaultAddress() // Vault receives the shares
);
await elitra.manage(STRATEGY_VAULT, depositData);

// 3. Update vault's aggregated balance
const newBalance = parseUnits('1000', 6); // Balance in the strategy
await elitra.updateBalance(newBalance);
```

## API Reference

See the [full API documentation](./docs/api.md) for detailed information about all methods and types.

## License

MIT

## Support

For issues and questions:
- GitHub Issues: [Create an issue](https://github.com/elitra/elitra-core/issues)
- Documentation: [View docs](https://docs.elitra.finance)
