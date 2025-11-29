#!/bin/bash

# Deployment script for WNativeGuard
# Usage: bash dev-scripts/guard-deploy/wnative-guard.sh
#
# Before running:
# 1. Source your environment file (e.g., source env.sei.sh)

set -e

# Source environment variables
echo "================================================================"
echo "Deploying WNativeGuard"
echo "================================================================"
echo "RPC URL: $RPC_URL"
echo "Deployer: $DEPLOYER_ADDRESS"
echo "Verifier: $VERIFIER_URL"
echo "================================================================"

# Check required environment variables
if [ -z "$PRIVATE_KEY" ]; then
    echo "Error: PRIVATE_KEY not set. Make sure you've sourced your keys file."
    exit 1
fi


echo ""
echo "Deploying WNativeGuard..."
echo ""

forge script script/guard-deploy/Deploy_WNativeGuard.s.sol \
    --rpc-url $RPC_URL \
    --broadcast \
    --compiler-version 0.8.28 \
    --evm-version "cancun" \
    --verify \
    --verifier $VERIFIER_TYPE \
    --verifier-url $VERIFIER_URL \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --chain-id $CHAIN_ID \
    --force \
    -vvvv

echo ""
echo "================================================================"
echo "WNativeGuard deployment complete!"
echo "================================================================"
echo ""
echo "IMPORTANT: Save the deployed address!"
echo ""
echo "Next steps:"
echo "1. Save address to your config file:"
echo "   export WNATIVE_GUARD_ADDRESS=0x..."
echo ""
echo "2. Set the guard on your vault for the WSEI/WETH address:"
echo "   cast send \$VAULT_ADDRESS \\"
echo "     \"setGuard(address,address)\" \$WNATIVE_ADDRESS \$WNATIVE_GUARD_ADDRESS \\"
echo "     --rpc-url \$RPC_URL --private-key \$PRIVATE_KEY"
echo ""
echo "3. Whitelist spenders as needed:"
echo "   cast send \$WNATIVE_GUARD_ADDRESS \\"
echo "     \"setSpender(address,bool)\" \$SPENDER_ADDRESS true \\"
echo "     --rpc-url \$RPC_URL --private-key \$PRIVATE_KEY"
echo "================================================================"
