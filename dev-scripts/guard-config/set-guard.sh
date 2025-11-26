

## Set approve guard for the token address
cast send $VAULT_ADDRESS "setGuard(address,address)" $ASSET_ADDRESS $APPROVE_GUARD_ADDRESS --rpc-url $RPC_URL --private-key $PRIVATE_KEY