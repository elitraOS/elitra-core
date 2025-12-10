echo "================================================================"
echo "Setting Takara Guard for vault $VAULT_ADDRESS"
echo "================================================================"

cast send $VAULT_ADDRESS "setGuard(address,address)" $TAKARA_POOL $TAKARA_POOL_GUARD_ADDRESS --rpc-url $RPC_URL --private-key $PRIVATE_KEY > /dev/null
cast send $VAULT_ADDRESS "setGuard(address,address)" $TAKARA_CONTROLLER $TAKARA_CONTROLLER_GUARD_ADDRESS --rpc-url $RPC_URL --private-key $PRIVATE_KEY > /dev/null

echo "--------------------------------"
echo "Validating Takara Guard for vault $VAULT_ADDRESS"
echo "Current Takara Pool Guard: "
cast call $VAULT_ADDRESS "guards(address)" $TAKARA_POOL --rpc-url $RPC_URL
echo "Current Takara Controller Guard: "
cast call $VAULT_ADDRESS "guards(address)" $TAKARA_CONTROLLER --rpc-url $RPC_URL

