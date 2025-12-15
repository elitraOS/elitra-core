# WSEI Token Guard

## Target Contract
- **Address**: `0xE30feDd158A2e3b13e9badaeABaFc5516e95e8C7`

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

### deposit (wrap native → WSEI)
```solidity
deposit()
```
**Selector**: `0xd0e30db0`

| Parameter | Validation |
|-----------|------------|
| - | No parameters |

### withdraw (unwrap WSEI → native)
```solidity
withdraw(uint256 amount)
```
**Selector**: `0x2e1a7d4d`

| Parameter | Validation |
|-----------|------------|
| `amount` | - |

### Whitelisted Spenders
- Yei Pool: `0x4a4d9abD36F923cBA0Af62A39C01dEC2944fb638`
- Takara SEI Pool: `0xA26b9BFe606d29F16B5Aecf30F9233934452c4E2`
- Morpho SEI Vault: `0x948FcC6b7f68f4830Cd69dB1481a9e1A142A4923`
