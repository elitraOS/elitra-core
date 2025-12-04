cast send $LZ_CROSSCHAIN_ADAPTER_ADDRESS "setSupportedOFT(address,address,bool)" $ASSET_ADDRESS $OFT_ADDRESS true --rpc-url $RPC_URL --private-key $PRIVATE_KEY


cast send $LZ_CROSSCHAIN_ADAPTER_ADDRESS "setSupportedVault(address,bool)" $VAULT_ADDRESS true --rpc-url $RPC_URL --private-key $PRIVATE_KEY