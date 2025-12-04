#!/bin/bash

# Setup script for Elitra Vault authorization and configuration
# Usage: bash dev-scripts/setup-auth.sh [asset]
# Example: bash dev-scripts/setup-auth.sh wsei
# Example: bash dev-scripts/setup-auth.sh usdc

set -e


# Check required environment variables
if [ -z "$PRIVATE_KEY" ]; then
    echo "Error: PRIVATE_KEY not set. Make sure you've sourced your keys file."
    exit 1
fi

# Validate addresses are set
if [ "$REMOTE_SUB_VAULT_ADDRESS" = "0x0000000000000000000000000000000000000000" ]; then
    echo "Error: REMOTE_SUB_VAULT_ADDRESS not set in $ASSET_CONFIG"
    echo "Please deploy the vault first using: bash dev-scripts/deploy.sh $ASSET"
    exit 1
fi


# Check if RolesAuthority is set
if [ -z "$REMOTE_AUTHORITY_ADDRESS" ] || [ "$REMOTE_AUTHORITY_ADDRESS" = "0x0000000000000000000000000000000000000000" ]; then
    echo "Error: REMOTE_AUTHORITY_ADDRESS not set in $ASSET_CONFIG"
    echo "Please deploy RolesAuthority first using: bash dev-scripts/deploy-authority.sh"
    echo "Then update $ASSET_CONFIG with the deployed address"
    exit 1
fi

# Run the setup script
forge script script/deploy/SetupSubVaultRoles.sol \
    --rpc-url $RPC_URL \
    --broadcast \
    -vvvv
