# Quick Start Guide

Get started with the Elitra SDK in 5 minutes.

## Installation

```bash
npm install @elitra/sdk viem
```

## Setup

```typescript
import { createPublicClient, createWalletClient, http } from 'viem';
import { sei } from 'viem/chains';
import { privateKeyToAccount } from 'viem/accounts';
import { ElitraClient } from '@elitra/sdk';

// 1. Create clients
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
```

## Common Operations

### Read Vault Info

```typescript
// Get full vault state
const state = await elitra.getVaultState();

// Get user position
const position = await elitra.getUserPosition(userAddress);

// Get price per share
const pps = await elitra.getPricePerShare();
```

### Deposit

```typescript
import { parseUnits } from 'viem';

// Deposit 100 USDC (6 decimals)
const result = await elitra.deposit(parseUnits('100', 6));
console.log('Shares received:', result.shares);
```

### Redeem

```typescript
// Redeem all shares
const position = await elitra.getUserPosition(account.address);
const result = await elitra.requestRedeem(position.shares);

if (result.isInstant) {
  console.log('Instant redemption! Assets:', result.value);
} else {
  console.log('Queued for later fulfillment');
}
```

### Manage Vault (Admin)

```typescript
import { encodeApprove } from '@elitra/sdk';

// Approve token from vault
const data = encodeApprove(spenderAddress, amount);
await elitra.manage(tokenAddress, data);
```

## Configuration per Network

### SEI Mainnet

```typescript
import { sei } from 'viem/chains';

const publicClient = createPublicClient({
  chain: sei,
  transport: http('https://evm-rpc.sei-apis.com')
});
```

### SEI Testnet

```typescript
import { seiTestnet } from 'viem/chains';

const publicClient = createPublicClient({
  chain: seiTestnet,
  transport: http('https://evm-rpc-testnet.sei-apis.com')
});
```

## Vault Addresses

Update these with your deployed vault addresses:

```typescript
const VAULTS = {
  WSEI: '0x...', // From config/sei/wsei.sh
  USDC: '0x...', // From config/sei/usdc.sh
};

// Use the appropriate vault
const elitra = new ElitraClient({
  vaultAddress: VAULTS.WSEI,
  publicClient,
  walletClient
});
```

## Error Handling

```typescript
try {
  const result = await elitra.deposit(amount);
  console.log('Success:', result.hash);
} catch (error) {
  if (error.message.includes('User rejected')) {
    console.log('User cancelled transaction');
  } else if (error.message.includes('insufficient')) {
    console.log('Insufficient balance or allowance');
  } else {
    console.error('Transaction failed:', error);
  }
}
```

## Full Example

```typescript
import { createPublicClient, createWalletClient, http, parseUnits, formatUnits } from 'viem';
import { sei } from 'viem/chains';
import { privateKeyToAccount } from 'viem/accounts';
import { ElitraClient } from '@elitra/sdk';

async function depositToVault() {
  // Setup
  const publicClient = createPublicClient({
    chain: sei,
    transport: http('https://evm-rpc.sei-apis.com')
  });

  const account = privateKeyToAccount(process.env.PRIVATE_KEY);
  const walletClient = createWalletClient({
    chain: sei,
    transport: http('https://evm-rpc.sei-apis.com'),
    account
  });

  const elitra = new ElitraClient({
    vaultAddress: process.env.VAULT_ADDRESS,
    publicClient,
    walletClient
  });

  // Check vault state
  const state = await elitra.getVaultState();
  if (state.isPaused) {
    throw new Error('Vault is paused');
  }

  console.log('Vault TVL:', formatUnits(state.totalAssets, 6), 'USDC');
  console.log('Price per share:', formatUnits(state.pricePerShare, 18));

  // Preview deposit
  const depositAmount = parseUnits('100', 6);
  const expectedShares = await elitra.previewDeposit(depositAmount);
  console.log('Depositing 100 USDC');
  console.log('Expected shares:', formatUnits(expectedShares, 18));

  // Execute deposit
  const result = await elitra.deposit(depositAmount);
  console.log('Transaction:', result.hash);
  console.log('Shares received:', formatUnits(result.shares, 18));

  // Verify
  const position = await elitra.getUserPosition(account.address);
  console.log('Total shares:', formatUnits(position.shares, 18));
  console.log('Total value:', formatUnits(position.assets, 6), 'USDC');
}

depositToVault()
  .then(() => console.log('Done!'))
  .catch(console.error);
```

## Next Steps

- Read the [full README](./README.md) for comprehensive documentation
- Check the [examples](./examples/) directory
- Review the [type definitions](./src/types.ts)

## Support

- Issues: [GitHub Issues](https://github.com/elitra/elitra-core/issues)
- Docs: [Full Documentation](https://docs.elitra.finance)
