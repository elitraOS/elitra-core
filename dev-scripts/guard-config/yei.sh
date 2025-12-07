echo "Yei Pool Guard Address: $YEI_POOL_GUARD_ADDRESS"

echo "Updating Yei Pool Guard, for asset: $ASSET_ADDRESS"
cast send $YEI_POOL_GUARD_ADDRESS "setAsset(address,bool)" $ASSET_ADDRESS true --rpc-url $RPC_URL --private-key $PRIVATE_KEY


## validating

echo "--------------------------------"
echo "Validating Yei Pool Guard, for asset: $ASSET_ADDRESS is whitelisted"
cast call $YEI_POOL_GUARD_ADDRESS "whitelistedAssets(address)" $ASSET_ADDRESS --rpc-url $RPC_URL


echo "--------------------------------"
echo "Yei Incentives Guard Address: $YEI_INCENTIVES_GUARD_ADDRESS"
echo "Setting Yei Incentives Guard, for asset: $ASSET_ADDRESS"
cast send $YEI_INCENTIVES_GUARD_ADDRESS "setAsset(address,bool)" $ASSET_ADDRESS true --rpc-url $RPC_URL --private-key $PRIVATE_KEY


echo "--------------------------------"
echo "Validating Yei Incentives Guard, for asset: $ASSET_ADDRESS is whitelisted"
cast call $YEI_INCENTIVES_GUARD_ADDRESS "whitelistedAssets(address)" $ASSET_ADDRESS --rpc-url $RPC_URL
