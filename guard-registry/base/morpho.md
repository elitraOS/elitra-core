# Morpho Gauntlet USDC Prime Guard (Base)

## Target Contract
- **Vault**: `0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61`
- **Chain**: Base Mainnet (chainId: 8453)
- **Protocol ID**: `base-morpho-gauntlet-usdc-prime`
- **Standard**: ERC-4626
- **Adapter**: `ERC4626Adapter` (`packages/protocol-adapters/src/operation/erc4626-operation-adapter.ts`)

## Allowed Functions

### deposit
```solidity
deposit(uint256 assets, address receiver)
```
**Selector**: `0x6e553f65`

| Parameter | Validation |
|-----------|------------|
| `assets` | - |
| `receiver` | Must be vault address |

### withdraw
```solidity
withdraw(uint256 assets, address receiver, address owner)
```
**Selector**: `0xb460af94`

| Parameter | Validation |
|-----------|------------|
| `assets` | - |
| `receiver` | Must be vault address |
| `owner` | Must be vault address |

---

## Action Flows

### Deposit (Invest)
| Step | Target | Function | Args |
|------|--------|----------|------|
| 1 | USDC (`0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`) | `approve(address,uint256)` | `spender` = Morpho Vault, `amount` = deposit amount |
| 2 | Morpho Vault (`0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61`) | `deposit(uint256,address)` | `assets` = amount, `receiver` = vault |

### Withdraw
| Step | Target | Function | Args |
|------|--------|----------|------|
| 1 | Morpho Vault (`0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61`) | `withdraw(uint256,address,address)` | `assets` = amount, `receiver` = vault, `owner` = vault |

---

## Notes
- `previewWithdraw(assets)` returns `assets` 1:1 — ERC-4626 `withdraw` takes underlying asset amount directly, not shares.
- No rewards claim flow for this vault.
