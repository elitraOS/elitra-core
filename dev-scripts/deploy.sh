#!/bin/bash

# Deployment script for Elitra Vault
# Usage: bash dev-scripts/deploy.sh [asset]
# Example: bash dev-scripts/deploy.sh wsei
# Example: bash dev-scripts/deploy.sh usdc

set -e

# Determine which asset to deploy
ASSET=${1:-wsei}

# Source environment variables
source env.sei.sh

# Source authority config
AUTHORITY_CONFIG="config/sei/authority.sh"
if [ -f "$AUTHORITY_CONFIG" ]; then
    source "$AUTHORITY_CONFIG"
else
    echo "Warning: Authority config not found at $AUTHORITY_CONFIG"
    echo "Creating default config file..."
    echo 'export AUTHORITY_ADDRESS=0x0000000000000000000000000000000000000000' > "$AUTHORITY_CONFIG"
fi

# Source asset-specific config
ASSET_CONFIG="config/sei/${ASSET}.sh"
if [ ! -f "$ASSET_CONFIG" ]; then
    echo "Error: Asset config file not found: $ASSET_CONFIG"
    echo "Available assets: wsei, usdc"
    exit 1
fi

echo "================================================================"
echo "Deploying Elitra Vault for asset: $ASSET"
echo "================================================================"
echo "RPC URL: $RPC_URL"
echo "Deployer: $DEPLOYER_ADDRESS"
echo "Authority: $AUTHORITY_ADDRESS"
echo "Verifier: $VERIFIER_URL"
echo "================================================================"

# Check if authority is deployed
if [ "$AUTHORITY_ADDRESS" = "0x0000000000000000000000000000000000000000" ]; then
    echo ""
    echo "WARNING: No RolesAuthority deployed!"
    echo "It's recommended to deploy RolesAuthority first:"
    echo "  bash dev-scripts/deploy-authority.sh"
    echo ""
    read -p "Continue without authority? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi
echo ""

# Check required environment variables
if [ -z "$PRIVATE_KEY" ]; then
    echo "Error: PRIVATE_KEY not set. Make sure you've sourced your keys file."
    exit 1
fi

# Export asset-specific variables
export ASSET_NAME=$ASSET
export AUTHORITY_ADDRESS

# Run the deployment script
forge script script/Deploy_ElitraVault.sol \
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
