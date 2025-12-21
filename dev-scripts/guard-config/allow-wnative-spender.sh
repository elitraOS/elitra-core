SPENDER_ADDRESS=$YEI_POOL

echo "WNATIVE_GUARD_ADDRESS: $WNATIVE_GUARD_ADDRESS"
echo "SPENDER_ADDRESS: $SPENDER_ADDRESS"
echo "RPC_URL: $RPC_URL"

# echo "Setting WNativeGuard for vault $VAULT_ADDRESS, asset $WNATIVE_ADDRESS, WNativeGuard $WNATIVE_GUARD_ADDRESS"
# cast send $VAULT_ADDRESS "setGuard(address,address)" $WNATIVE_ADDRESS $WNATIVE_GUARD_ADDRESS --rpc-url $RPC_URL --private-key $PRIVATE_KEY


echo "Setting WNativeGuard for spender $SPENDER_ADDRESS"
cast send $WNATIVE_GUARD_ADDRESS "setSpender(address,bool)" $SPENDER_ADDRESS true --rpc-url $RPC_URL --private-key $PRIVATE_KEY

