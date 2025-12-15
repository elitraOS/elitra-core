CONTRACT=0xf12f61813aF878Cb54E336244f55Cfb1e848E399
CONTRACT_NAME=src/adapters/CrosschainDepositQueue.sol:CrosschainDepositQueue

echo $CHAIN_ID
forge verify-contract \
    --chain-id $CHAIN_ID \
    --verifier etherscan \
    --verifier-url https://seiscan.io/api \
    --etherscan-api-key ZMIEESP4645JNMP3PQJFS1GB1EHUB3H95I \
    --compiler-version 0.8.28 \
    --evm-version "cancun" \
    $CONTRACT \
    $CONTRACT_NAME \
    --force \
    -vvvv