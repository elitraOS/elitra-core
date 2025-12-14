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

## Merkl Distributor Guard

### Target Contract
- **Address**: `0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae`
- **Supported Assets**: SEI, USDC
 - **Implementation**: `src/guards/sei/MerklDistributorGuard.sol`

### Allowed Functions

#### claim
```solidity
claim(address[] users,address[] tokens,uint256[] amounts,bytes32[][] proofs)
```
**Selector**: `0x71ee95c0`

| Parameter | Validation |
|-----------|------------|
| `users` | All users must be the vault address |
| `tokens` | Not validated |
| `amounts` | Not validated |
| `proofs` | Not validated |

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

### Claim Rewards
| Step | Target | Function | Args |
|------|--------|----------|------|
| 1 | Merkl Distributor | `claim(address[],address[],uint256[],bytes32[][])` | `address` = [vault addresses], `tokens` = [token addresses], `amounts` = [claimable amounts], `proofs` = [merkl proof] |

