#!/bin/bash

# Deployment script for Elitra Vault
# Usage: bash dev-scripts/deploy.sh [asset]
# Example: bash dev-scripts/deploy.sh wsei
# Example: bash dev-scripts/deploy.sh usdc

set -e



echo "================================================================"
echo "Deploying Elitra Vault for asset: $ASSET_ADDRESS"
echo "================================================================"
echo "RPC URL: $RPC_URL"
echo "Deployer: $DEPLOYER_ADDRESS"
echo "Authority: $AUTHORITY_ADDRESS"
echo "Verifier: $VERIFIER_URL"
echo "================================================================"

# Check required environment variables
if [ -z "$PRIVATE_KEY" ]; then
    echo "Error: PRIVATE_KEY not set. Make sure you've sourced your keys file."
    exit 1
fi


# Run the deployment script
forge script script/deploy/Deploy_ElitraVault.sol \
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
echo "Deployment complete!"
echo "================================================================"
echo ""
echo "Next steps:"
echo "1. Copy the deployed addresses from the output above"
echo "2. Update $ASSET_CONFIG with the deployed addresses"
echo "3. Run: bash dev-scripts/setup-auth.sh $ASSET"
echo "================================================================"
