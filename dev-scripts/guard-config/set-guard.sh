ETH_TOKEN_GUARD_ADDRESS=$ETH_TOKEN_GUARD_ADDRESS

## Set approve guard for the token address
cast send $CURRENT_VAULT_ADDRESS "setGuard(address,address)" $CURRENT_ASSET_ADDRESS $ETH_TOKEN_GUARD_ADDRESS --rpc-url $RPC_URL --private-key $PRIVATE_KEY