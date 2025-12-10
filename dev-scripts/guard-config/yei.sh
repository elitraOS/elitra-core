
YEI_POOL=0x4a4d9abD36F923cBA0Af62A39C01dEC2944fb638
YEI_INCENTIVE_CONTROLLER=0x60485C5E5E3D535B16CC1bd2C9243C7877374259

echo "--------------------------------"
echo "Setting YEI Guard for vault $VAULT_ADDRESS"
cast send $VAULT_ADDRESS "setGuard(address,address)" $YEI_POOL $YEI_POOL_GUARD_ADDRESS --rpc-url $RPC_URL --private-key $PRIVATE_KEY > /dev/null

sleep 1

cast send $VAULT_ADDRESS "setGuard(address,address)" $YEI_INCENTIVE_CONTROLLER $YEI_INCENTIVES_GUARD_ADDRESS --rpc-url $RPC_URL --private-key $PRIVATE_KEY > /dev/null

echo "--------------------------------"
echo "Validating YEI Guard for vault $VAULT_ADDRESS"

echo "Current YEI Pool Guard: "
cast call $VAULT_ADDRESS "guards(address)" $YEI_POOL --rpc-url $RPC_URL

echo "Current YEI Incentive Controller Guard: "
cast call $VAULT_ADDRESS "guards(address)" $YEI_INCENTIVE_CONTROLLER --rpc-url $RPC_URL



echo "================================================================"

echo "Yei Pool Guard Address: $YEI_POOL_GUARD_ADDRESS"

echo "Updating Yei Pool Guard, for asset: $ASSET_ADDRESS"
cast send $YEI_POOL_GUARD_ADDRESS "setAsset(address,bool)" $ASSET_ADDRESS true --rpc-url $RPC_URL --private-key $PRIVATE_KEY > /dev/null


## validating

echo "--------------------------------"
echo "Validating Yei Pool Guard, for asset: $ASSET_ADDRESS is whitelisted"
cast call $YEI_POOL_GUARD_ADDRESS "whitelistedAssets(address)" $ASSET_ADDRESS --rpc-url $RPC_URL


echo "--------------------------------"
echo "Yei Incentives Guard Address: $YEI_INCENTIVES_GUARD_ADDRESS"
echo "Setting Yei Incentives Guard, for asset: $ASSET_ADDRESS"
cast send $YEI_INCENTIVES_GUARD_ADDRESS "setAsset(address,bool)" $ASSET_ADDRESS true --rpc-url $RPC_URL --private-key $PRIVATE_KEY > /dev/null

echo "--------------------------------"
echo "Validating Yei Incentives Guard, for asset: $ASSET_ADDRESS is whitelisted"
cast call $YEI_INCENTIVES_GUARD_ADDRESS "whitelistedAssets(address)" $ASSET_ADDRESS --rpc-url $RPC_URL