# Morpho / ERC4626 Vault Guard

## Target Contracts
- **SEI Vault**: `0x948FcC6b7f68f4830Cd69dB1481a9e1A142A4923`
- **USDC Vault**: `0x015F10a56e97e02437D294815D8e079e1903E41C`

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
| 1 | Asset Token (WSEI/USDC) | `approve(address,uint256)` | `spender` = Morpho Vault, `amount` = deposit amount |
| 2 | Morpho Vault | `deposit(uint256,address)` | `assets` = amount, `receiver` = vault |

### Withdraw
| Step | Target | Function | Args |
|------|--------|----------|------|
| 1 | Morpho Vault | `withdraw(uint256,address,address)` | `assets` = amount, `receiver` = vault, `owner` = vault |

### Rewards
- **Not implemented yet**
