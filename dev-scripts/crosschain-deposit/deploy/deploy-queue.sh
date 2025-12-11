# Run the deployment script
forge script script/crosschain-deposit/deploy/Deploy_CrosschainDepositQueue.s.sol \
    --rpc-url $RPC_URL \
    --broadcast \
    --compiler-version 0.8.28 \
    --evm-version "cancun" \
    --verify \
    --verifier $VERIFIER_TYPE \
    --verifier-url $VERIFIER_URL \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --chain-id $CHAIN_ID \
    --force \
    -vvvv