# Yo Protocol Guard (Base)

## Target Contract
- **Vault**: `0x0000000f2eB9f69274678c76222B35eEc7588a65`
- **Chain**: Base Mainnet (chainId: 8453)
- **Protocol ID**: `base-yo`
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
| 1 | USDC (`0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`) | `approve(address,uint256)` | `spender` = Yo Vault, `amount` = deposit amount |
| 2 | Yo Vault (`0x0000000f2eB9f69274678c76222B35eEc7588a65`) | `deposit(uint256,address)` | `assets` = amount, `receiver` = vault |

### Withdraw
| Step | Target | Function | Args |
|------|--------|----------|------|
| 1 | Yo Vault (`0x0000000f2eB9f69274678c76222B35eEc7588a65`) | `withdraw(uint256,address,address)` | `assets` = amount, `receiver` = vault, `owner` = vault |

---

## Notes
- Same ERC-4626 interface as Morpho — uses shared `ERC4626Adapter`.
- `previewWithdraw(assets)` returns `assets` 1:1.
- No rewards claim flow for this vault.
