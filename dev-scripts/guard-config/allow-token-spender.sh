SPENDER_ADDRESS=$YEI_POOL

echo "TOKEN_GUARD_ADDRESS: $TOKEN_GUARD_ADDRESS"
echo "SPENDER_ADDRESS: $SPENDER_ADDRESS"
echo "RPC_URL: $RPC_URL"


echo "Setting TokenGuard for spender $SPENDER_ADDRESS"
cast send $TOKEN_GUARD_ADDRESS "setSpender(address,bool)" $SPENDER_ADDRESS true --rpc-url $RPC_URL --private-key $PRIVATE_KEY

