# Yei Protocol Guards

## Yei Pool Guard

### Target Contract
- **Address**: `0x4a4d9abD36F923cBA0Af62A39C01dEC2944fb638`
- **Supported Assets**: SEI, USDC

### Allowed Functions

#### supply
```solidity
supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode)
```
**Selector**: `0x617ba037`

| Parameter | Validation |
|-----------|------------|
| `asset` | Must be whitelisted |
| `amount` | - |
| `onBehalfOf` | Must be vault address |
| `referralCode` | - |

#### withdraw
```solidity
withdraw(address asset, uint256 amount, address to)
```
**Selector**: `0x69328dec`

| Parameter | Validation |
|-----------|------------|
| `asset` | Must be whitelisted |
| `amount` | - |
| `to` | Must be vault address |

---

## Yei Incentives Controller Guard

### Target Contract
- **Address**: `0x60485C5E5E3D535B16CC1bd2C9243C7877374259`
- **Supported Assets**: SEI, USDC

### Allowed Functions

#### claimAllRewardsToSelf
```solidity
claimAllRewardsToSelf(address[] assets)
```
**Selector**: `0xbf90f63a`

| Parameter | Validation |
|-----------|------------|
| `assets` | All assets must be whitelisted |
