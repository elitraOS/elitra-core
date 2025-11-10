#!/bin/bash

# Setup script for Elitra Vault authorization and configuration
# Usage: bash dev-scripts/setup-auth.sh [asset]
# Example: bash dev-scripts/setup-auth.sh wsei
# Example: bash dev-scripts/setup-auth.sh usdc

set -e


echo "================================================================"
echo "Setting up authorization for asset: $ASSET_ADDRESS"
echo "================================================================"
echo "RPC URL: $RPC_URL"
echo "Deployer: $DEPLOYER_ADDRESS"
echo "================================================================"
echo "Vault Address: $VAULT_ADDRESS"
echo "Oracle Hook Address: $ORACLE_HOOK_ADDRESS"
echo "Redemption Hook Address: $REDEMPTION_HOOK_ADDRESS"
echo "RolesAuthority Address: $ROLES_AUTHORITY_ADDRESS"
echo "================================================================"

# Check required environment variables
if [ -z "$PRIVATE_KEY" ]; then
    echo "Error: PRIVATE_KEY not set. Make sure you've sourced your keys file."
    exit 1
fi

# Validate addresses are set
if [ "$VAULT_ADDRESS" = "0x0000000000000000000000000000000000000000" ]; then
    echo "Error: VAULT_ADDRESS not set in $ASSET_CONFIG"
    echo "Please deploy the vault first using: bash dev-scripts/deploy.sh $ASSET"
    exit 1
fi

if [ "$ORACLE_HOOK_ADDRESS" = "0x0000000000000000000000000000000000000000" ]; then
    echo "Warning: ORACLE_HOOK_ADDRESS not set in $ASSET_CONFIG"
    echo "You may need to deploy the oracle hook first"
fi

if [ "$REDEMPTION_HOOK_ADDRESS" = "0x0000000000000000000000000000000000000000" ]; then
    echo "Warning: REDEMPTION_HOOK_ADDRESS not set in $ASSET_CONFIG"
    echo "You may need to deploy the redemption hook first"
fi

# Check if RolesAuthority is set
if [ -z "$ROLES_AUTHORITY_ADDRESS" ] || [ "$ROLES_AUTHORITY_ADDRESS" = "0x0000000000000000000000000000000000000000" ]; then
    echo "Error: ROLES_AUTHORITY_ADDRESS not set in $ASSET_CONFIG"
    echo "Please deploy RolesAuthority first using: bash dev-scripts/deploy-authority.sh"
    echo "Then update $ASSET_CONFIG with the deployed address"
    exit 1
fi

# Run the setup script
forge script script/SetupRoles.sol \
    --rpc-url $RPC_URL \
    --broadcast \
    -vvvv

echo ""
echo "================================================================"
echo "Setup complete!"
echo "================================================================"
echo ""
echo "Vault is now configured and ready to use."
echo ""
echo "Quick reference commands:"
echo "  - Deploy vault:     bash dev-scripts/deploy.sh $ASSET"
echo "  - Deploy hooks:     bash dev-scripts/deploy-hook.sh $ASSET all"
echo "  - Setup auth:       bash dev-scripts/setup-auth.sh $ASSET"
echo "  - Switch to USDC:   bash dev-scripts/setup-auth.sh usdc"
echo "  - Switch to WSEI:   bash dev-scripts/setup-auth.sh wsei"
echo "================================================================"
