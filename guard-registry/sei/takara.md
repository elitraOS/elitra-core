# Takara Protocol Guards

## Takara Pool Guard

### Target Contracts
- **SEI Pool**: `0xA26b9BFe606d29F16B5Aecf30F9233934452c4E2`
- **USDC Pool**: `0xd1E6a6F58A29F64ab2365947ACb53EfEB6Cc05e0`

### Allowed Functions

#### mint
```solidity
mint(uint256 mintAmount)
```
**Selector**: `0xa0712d68`

| Parameter | Validation |
|-----------|------------|
| `mintAmount` | - |

#### redeem
```solidity
redeem(uint256 redeemAmount)
```
**Selector**: `0xdb006a75`

| Parameter | Validation |
|-----------|------------|
| `redeemAmount` | - |

---

## Takara Controller Guard

### Target Contract
- **Address**: `0x71034bf5eC0FAd7aEE81a213403c8892F3d8CAeE`
- **Supported Assets**: SEI, USDC

### Allowed Functions

#### claimReward
```solidity
claimReward()
```
**Selector**: `0xb88a802f`

| Parameter | Validation |
|-----------|------------|
| - | No parameters |

---

## Action Flows

### Deposit (Invest/Mint)
| Step | Target | Function | Args |
|------|--------|----------|------|
| 1 | Asset Token (WSEI/USDC) | `approve(address,uint256)` | `spender` = Takara Pool, `amount` = mint amount |
| 2 | Takara Pool | `mint(uint256)` | `mintAmount` = amount |

### Withdraw (Redeem)
| Step | Target | Function | Args |
|------|--------|----------|------|
| 1 | Takara Pool | `redeem(uint256)` | `redeemAmount` = amount |

### Claim Rewards
| Step | Target | Function | Args |
|------|--------|----------|------|
| 1 | Takara Controller | `claimReward()` | - |
