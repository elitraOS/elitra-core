

# Validate required variables
if [ -z "$PRIVATE_KEY" ]; then
    echo "Error: PRIVATE_KEY not set"
    exit 1
fi

if [ -z "$LZ_CROSSCHAIN_ADAPTER_ADDRESS" ]; then
    echo "Error: LZ_CROSSCHAIN_ADAPTER_ADDRESS not set"
    exit 1
fi

if [ -z "$ASSET_ADDRESS" ] || [ -z "$OFT_ADDRESS" ]; then
    echo "Error: TOKEN_ADDRESS or OFT_ADDRESS not set"
    exit 1
fi

if [ -z "$DST_EID" ] || [ -z "$DST_VAULT_ADDRESS" ]; then
    echo "Error: DST_EID or DST_VAULT_ADDRESS not set"
    exit 1
fi

echo ""
echo "Step 1: Setting token configuration..."
cast send $CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS \
    "setTokenConfig(address,address)" \
    $TOKEN_ADDRESS \
    $OFT_ADDRESS \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY

echo "Token config set successfully!"

echo ""
echo "Step 2: Setting remote vault..."
cast send $CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS \
    "setRemoteVault(uint32,address)" \
    $DST_EID \
    $DST_VAULT_ADDRESS \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY

echo "Remote vault set successfully!"

echo ""
echo "================================================================"
echo "CrosschainStrategyAdapter setup complete!"
echo "================================================================"
echo ""
echo "Verification:"
echo "  Token config: cast call $CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS \"tokenToOft(address)\" $TOKEN_ADDRESS --rpc-url $RPC_URL"
echo "  Remote vault: cast call $CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS \"dstEidToVault(uint32)\" $DST_EID --rpc-url $RPC_URL"
echo "================================================================"
