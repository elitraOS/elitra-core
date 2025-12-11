cast send $CROSSCHAIN_DEPOSIT_QUEUE_ADDRESS "setAdapterRegistration(address,bool)" $CCTP_ADAPTER_ADDRESS true --rpc-url $RPC_URL --private-key $PRIVATE_KEY

echo "Checking if adapter is registered..."
cast call $CROSSCHAIN_DEPOSIT_QUEUE_ADDRESS "isAdapterRegistered(address)" $CCTP_ADAPTER_ADDRESS --rpc-url $RPC_URL

