TARGET_ADDRESS=$ASSET_ADDRESS
GUARD_ADDRESS=$TOKEN_GUARD_ADDRESS

## Set approve guard for the token address
cast send $VAULT_ADDRESS "setGuard(address,address)" $TARGET_ADDRESS $TOKEN_GUARD_ADDRESS --rpc-url $RPC_URL --private-key $PRIVATE_KEY