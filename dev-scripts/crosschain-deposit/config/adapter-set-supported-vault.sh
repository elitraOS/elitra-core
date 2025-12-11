cast send $CCTP_ADAPTER_ADDRESS "setSupportedVault(address,bool)" $VAULT_ADDRESS true --rpc-url $RPC_URL --private-key $PRIVATE_KEY


echo "Checking if $VAULT_ADDRESS is supported..." 
cast call $CCTP_ADAPTER_ADDRESS "isVaultSupported(address)" $VAULT_ADDRESS --rpc-url $RPC_URL