source dev-scripts/current-env.sh

APPROVE_GUARD_ADDRESS=$APPROVE_GUARD_ADDRESS

## Set approve guard for the token address
cast send $CURRENT_VAULT_ADDRESS "setGuard(address,address)" $CURRENT_TOKEN_ADDRESS $APPROVE_GUARD_ADDRESS --rpc-url $RPC_URL --private-key $PRIVATE_KEY