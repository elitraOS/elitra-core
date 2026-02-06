CONTRACT=0xd38995EC59D4ff2bdccd908C3Da4484397394F7B
CONTRACT_NAME=src/ElitraVault.sol:ElitraVault

echo $CHAIN_ID
forge verify-contract \
    --watch \
    --compiler-version "0.8.28" \
    --evm-version "cancun" \
    --verifier blockscout \
    --verifier-url https://seitrace.com/pacific-1/api \
    --etherscan-api-key dummy \
    --chain-id $CHAIN_ID \
    --force \
    $CONTRACT \
    $CONTRACT_NAME