echo "Setting supported OFT for $ASSET_ADDRESS and $OFT_ADDRESS"
cast send $LZ_CROSSCHAIN_DEPOSIT_ADAPTER_ADDRESS "setSupportedOFT(address,address,bool)" $ASSET_ADDRESS $OFT_ADDRESS true --rpc-url $RPC_URL --private-key $PRIVATE_KEY
