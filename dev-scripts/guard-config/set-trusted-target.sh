TARGET_ADDRESS=$CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS

cast send $VAULT_ADDRESS "setTrustedTarget(address,bool)" $TARGET_ADDRESS true --rpc-url $RPC_URL --private-key $PRIVATE_KEY