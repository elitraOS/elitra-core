# USDC Token Guard (Base)

## Target Contract
- **Address**: `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`
- **Chain**: Base Mainnet (chainId: 8453)
- **Symbol**: USDC
- **Decimals**: 6

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
- Morpho Gauntlet USDC Prime Vault: `0xeE8F4eC5672F09119b96Ab6fB59C27E1b7e44b61`
- Yo Vault: `0x0000000f2eB9f69274678c76222B35eEc7588a65`
- Aave V3 Pool: `0xA238Dd80C259a72e81d7e4664a9801593F98d1c5`
