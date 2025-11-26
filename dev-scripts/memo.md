## this is use to verify contract

```bash
forge verify-contract \
    --verifier etherscan --chain-id=42161 \
    --verifier-url "https://api.etherscan.io/v2/api" \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    0xF6352a0F96641E6a85f195d69046761a725c1a43 \
    src/vault/SubVault.sol:SubVault
```
