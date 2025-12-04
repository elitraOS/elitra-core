#!/bin/bash

# Deployment script for TokenGuard
# Usage: bash dev-scripts/guard-deploy/token-guard.sh
#
# Before running:
# 1. Source your environment file (e.g., source env.sei.sh)
# 2. Set WHITELISTED_SPENDERS env var with comma-separated addresses

set -e

# Source environment variables
echo "================================================================"
echo "Deploying TokenGuard"
echo "================================================================"
echo "RPC URL: $RPC_URL"
echo "Deployer: $DEPLOYER_ADDRESS"
echo "Whitelisted Spenders: $WHITELISTED_SPENDERS"
echo "Verifier: $VERIFIER_URL"
echo "================================================================"

# Check required environment variables
if [ -z "$PRIVATE_KEY" ]; then
    echo "Error: PRIVATE_KEY not set. Make sure you've sourced your keys file."
    exit 1
fi


echo ""
echo "Deploying TokenGuard..."
echo ""

forge script script/guard-deploy/Deploy_TokenGuard.s.sol \
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
echo "TokenGuard deployment complete!"
echo "================================================================"
echo ""
echo "IMPORTANT: Save the deployed address!"
echo ""
echo "Next steps:"
echo "1. Save address to your config file:"
echo "   export TOKEN_GUARD_ADDRESS=0x..."
echo ""
echo "2. Set the guard on your vault for the token address:"
echo "   cast send \$VAULT_ADDRESS \\"
echo "     \"setGuard(address,address)\" \$ASSET_ADDRESS \$TOKEN_GUARD_ADDRESS \\"
echo "     --rpc-url \$RPC_URL --private-key \$PRIVATE_KEY"
echo "================================================================"
