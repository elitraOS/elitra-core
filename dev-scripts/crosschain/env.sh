## need to source this to switch vault addresses when interacting crosschain (at the last steps)

echo "================================================================"
echo "Setting up crosschain environment"
echo "================================================================"

export CURRENT_VAULT_ADDRESS=$VAULT_ADDRESS

export CURRENT_CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS=$CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS
export CURRENT_TOKEN_ADDRESS=$ASSET_ADDRESS
export CURRENT_OFT_ADDRESS=$OFT_ADDRESS

export CURRENT_DST_EID=$ARB_EID
export CURRENT_DST_VAULT_ADDRESS=$ARB_SUB_VAULT_ADDRESS




# export CURRENT_VAULT_ADDRESS=$ARB_SUB_VAULT_ADDRESS

# export CURRENT_CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS=$ARB_CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS
# export CURRENT_TOKEN_ADDRESS=$ASSET_ADDRESS
# export CURRENT_OFT_ADDRESS=$OFT_ADDRESS

# export CURRENT_DST_EID=$ARB_EID
# export CURRENT_DST_VAULT_ADDRESS=$ARB_SUB_VAULT_ADDRESS

echo "Current Vault Address: $CURRENT_VAULT_ADDRESS"
echo "Current Crosschain Strategy Adapter Address: $CURRENT_CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS"
echo "Current Token Address: $CURRENT_TOKEN_ADDRESS"
echo "Current OFT Address: $CURRENT_OFT_ADDRESS"
echo "Current Destination EID: $CURRENT_DST_EID"
echo "Current Destination Vault Address: $CURRENT_DST_VAULT_ADDRESS"
echo "================================================================"