# USDC Token Guard

## Target Contract
- **Address**: `0x3894085Ef7Ff0f0aeDf52E2A2704928d1Ec074F1`

## Allowed Functions

### approve
```solidity
approve(address spender, uint256 amount)
```
**Selector**: `0x095ea7b3`

| Parameter | Validation |
|-----------|------------|
| `spender` | Must be whitelisted |
| `amount` | - |

### Whitelisted Spenders
- Yei Pool: `0x4a4d9abD36F923cBA0Af62A39C01dEC2944fb638`
- Takara USDC Pool: `0xd1E6a6F58A29F64ab2365947ACb53EfEB6Cc05e0`
- Morpho USDC Vault: `0x015F10a56e97e02437D294815D8e079e1903E41C`
