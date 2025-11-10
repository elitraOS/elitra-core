#!/bin/bash

# Deployment script for RolesAuthority
# Usage: bash dev-scripts/deploy-authority.sh
# This should be run BEFORE deploying vaults

set -e

# Source environment variables
source env.sei.sh

echo "================================================================"
echo "Deploying RolesAuthority"
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

# Optional: Set owner (defaults to deployer)
export OWNER=${OWNER:-$DEPLOYER_ADDRESS}
echo "Authority Owner: $OWNER"
echo ""

# Run the deployment script
echo "Deploying RolesAuthority..."
echo ""

forge script script/DeployAuthority.s.sol \
    --rpc-url $RPC_URL \
    --broadcast \
    --compiler-version 0.8.28 \
    --evm-version "cancun" \
    --verify \
    --verifier blockscout \
    --verifier-url https://seitrace.com/pacific-1/api \
    --etherscan-api-key dummy \
    --chain-id 1329 \
    --force \
    -vvvv

echo ""
echo "================================================================"
echo "RolesAuthority deployment complete!"
echo "================================================================"
echo ""
echo "IMPORTANT: Save the deployed RolesAuthority address!"
echo ""
echo "Next steps:"
echo "1. Copy the RolesAuthority address from the output above"
echo "2. Create/update config/sei/authority.sh with:"
echo "   export AUTHORITY_ADDRESS=0x..."
echo "3. Deploy vaults using this authority:"
echo "   bash dev-scripts/deploy.sh wsei"
echo "4. Configure roles and permissions:"
echo "   bash dev-scripts/setup-auth.sh wsei"
echo "================================================================"
