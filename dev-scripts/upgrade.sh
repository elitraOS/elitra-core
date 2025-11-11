#!/bin/bash

# Upgrade script for Elitra Vault
# Usage: bash dev-scripts/upgrade.sh [asset]
# Example: bash dev-scripts/upgrade.sh wsei
# Example: bash dev-scripts/upgrade.sh usdc

set -e

# Determine which asset to upgrade
ASSET=${1:-wsei}

# Source environment variables
source env.sei.sh

# Source authority config
AUTHORITY_CONFIG="config/sei/authority.sh"
if [ -f "$AUTHORITY_CONFIG" ]; then
    source "$AUTHORITY_CONFIG"
else
    echo "Warning: Authority config not found at $AUTHORITY_CONFIG"
fi

# Source asset-specific config
ASSET_CONFIG="config/sei/${ASSET}.sh"
if [ ! -f "$ASSET_CONFIG" ]; then
    echo "Error: Asset config file not found: $ASSET_CONFIG"
    echo "Available assets: wsei, usdc"
    exit 1
fi

# Load asset config to get vault addresses
source "$ASSET_CONFIG"

echo "================================================================"
echo "Upgrading Elitra Vault for asset: $ASSET"
echo "================================================================"
echo "RPC URL: $RPC_URL"
echo "Deployer: $DEPLOYER_ADDRESS"
echo "Current Vault Proxy: $VAULT_ADDRESS"
echo "Verifier: $VERIFIER_URL"
echo "================================================================"

# Check if vault address is set
if [ -z "$VAULT_ADDRESS" ] || [ "$VAULT_ADDRESS" = "0x0000000000000000000000000000000000000000" ]; then
    echo ""
    echo "ERROR: No vault address found in $ASSET_CONFIG"
    echo "Please deploy the vault first using: bash dev-scripts/deploy.sh $ASSET"
    exit 1
fi

echo ""

# Check required environment variables
if [ -z "$PRIVATE_KEY" ]; then
    echo "Error: PRIVATE_KEY not set. Make sure you've sourced your keys file."
    exit 1
fi

# Export required variables for the upgrade script
export ASSET_NAME=$ASSET
export VAULT_PROXY_ADDRESS=$VAULT_ADDRESS

# Prompt for confirmation
echo "⚠️  WARNING: You are about to upgrade the vault implementation!"
echo ""
echo "This will:"
echo "  1. Deploy a new ElitraVault implementation contract"
echo "  2. Upgrade the proxy at $VAULT_ADDRESS to use the new implementation"
echo ""
read -p "Do you want to continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Upgrade cancelled."
    exit 0
fi

echo ""
echo "================================================================"
echo "Step 1: Deploying new ElitraVault implementation..."
echo "================================================================"

# Deploy new implementation
forge script script/Upgrade_ElitraVault.sol \
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
echo "Upgrade complete!"
echo "================================================================"
echo ""
