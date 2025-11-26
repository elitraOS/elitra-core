#!/bin/bash

# Deployment script for CrosschainStrategyAdapter
# Usage: bash dev-scripts/deploy-crosschain-adapter.sh
#
# Before running:
# 1. Source your environment file (e.g., source env.sei.sh)
# 2. Source your asset config file (e.g., source config/sei/usdt0.sh)

set -e

source dev-scripts/crosschain/env.sh
echo "================================================================"
echo "Deploying CrosschainStrategyAdapter"
echo "================================================================"
echo "RPC URL: $RPC_URL"
echo "Deployer: $DEPLOYER_ADDRESS"
echo "Vault: $CURRENT_VAULT_ADDRESS"
echo "Verifier: $VERIFIER_URL"
echo "================================================================"

# Check required environment variables
if [ -z "$PRIVATE_KEY" ]; then
    echo "Error: PRIVATE_KEY not set. Make sure you've sourced your keys file."
    exit 1
fi

if [ -z "$VAULT_ADDRESS" ]; then
    echo "Error: VAULT_ADDRESS not set. Make sure you've sourced your config file."
    exit 1
fi

# Optional: Set owner (defaults to deployer)
export OWNER=${OWNER:-$DEPLOYER_ADDRESS}
echo "Owner: $OWNER"
echo ""

# Run the deployment script
echo "Deploying CrosschainStrategyAdapter..."
echo ""



forge script script/crosschain/Deploy_CrosschainStrategyAdapter.sol \
    --rpc-url $RPC_URL \
    --broadcast \
    --compiler-version 0.8.28 \
    --evm-version "cancun" \
    --verify \
    --verifier $VERIFIER_TYPE \
    --verifier-url $VERIFIER_URL \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --force \
    -vvvv

echo ""
echo "================================================================"
echo "CrosschainStrategyAdapter deployment complete!"
echo "================================================================"
echo ""
echo "IMPORTANT: Save the deployed address!"
echo ""
echo "Next steps:"
echo "1. Save address to your config file:"
echo "   export CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS=0x..."
echo ""
echo "2. Configure token mapping:"
echo "   cast send \$CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS \\"
echo "     \"setTokenConfig(address,address)\" \$TOKEN_ADDRESS \$OFT_ADDRESS \\"
echo "     --rpc-url \$RPC_URL --private-key \$PRIVATE_KEY"
echo ""
echo "3. Configure remote vault (destination chain):"
echo "   cast send \$CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS \\"
echo "     \"setRemoteVault(uint32,address)\" \$DST_EID \$DST_VAULT_ADDRESS \\"
echo "     --rpc-url \$RPC_URL --private-key \$PRIVATE_KEY"
echo "================================================================"
