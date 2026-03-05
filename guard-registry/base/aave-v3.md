# Aave V3 USDC Guard (Base)

## Target Contracts
- **Pool**: `0xA238Dd80C259a72e81d7e4664a9801593F98d1c5`
- **aToken (aBasUSDC)**: `0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB`
- **Chain**: Base Mainnet (chainId: 8453)
- **Protocol ID**: `base-aave-v3-usdc`
- **Adapter**: `AaveV3OperationAdapter` (`packages/protocol-adapters/src/operation/aave-v3-operation-adapter.ts`)

## Allowed Functions

### supply
```solidity
supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode)
```
**Selector**: `0x617ba037`

| Parameter | Validation |
|-----------|------------|
| `asset` | Must be USDC (`0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`) |
| `amount` | - |
| `onBehalfOf` | Must be vault address |
| `referralCode` | - |

### withdraw
```solidity
withdraw(address asset, uint256 amount, address to)
```
**Selector**: `0x69328dec`

| Parameter | Validation |
|-----------|------------|
| `asset` | Must be USDC (`0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`) |
| `amount` | - |
| `to` | Must be vault address |

---

## Action Flows

### Deposit (Supply)
| Step | Target | Function | Args |
|------|--------|----------|------|
| 1 | USDC (`0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`) | `approve(address,uint256)` | `spender` = Aave V3 Pool, `amount` = deposit amount |
| 2 | Aave V3 Pool (`0xA238Dd80C259a72e81d7e4664a9801593F98d1c5`) | `supply(address,uint256,address,uint16)` | `asset` = USDC, `amount` = deposit amount, `onBehalfOf` = vault, `referralCode` = 0 |

### Withdraw
| Step | Target | Function | Args |
|------|--------|----------|------|
| 1 | Aave V3 Pool (`0xA238Dd80C259a72e81d7e4664a9801593F98d1c5`) | `withdraw(address,uint256,address)` | `asset` = USDC, `amount` = withdraw amount, `to` = vault |

---

## Notes
- Balance tracked via aToken (`0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB`) — `AaveATokenBalanceAdapter`.
- No rewards claim flow configured for Base Aave V3 in current adapter.
- `referralCode` is always `0`.
