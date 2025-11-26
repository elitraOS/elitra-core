#!/bin/bash

# Deployment script for SubVault and CrosschainStrategyAdapter
# Usage: bash dev-scripts/deploy-subvault.sh
#
# This deploys:
# 1. SubVault (upgradeable proxy) - holds assets on source chain
# 2. CrosschainStrategyAdapter - sends tokens cross-chain via LayerZero OFT
#
# Before running:
# 1. Create your env file (e.g., env.arbitrum.sh) with RPC_URL, DEPLOYER_ADDRESS, etc.
# 2. Create your config file (e.g., config/arbitrum/usdt0.sh) with token configs
# 3. Source both files before running this script

set -e

# Check if env file argument is provided
if [ -z "$1" ]; then
    echo "Usage: bash dev-scripts/deploy-subvault.sh <env-file>"
    echo "Example: bash dev-scripts/deploy-subvault.sh env.arbitrum.sh"
    exit 1
fi

ENV_FILE=$1

# Source environment variables
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: Environment file '$ENV_FILE' not found"
    exit 1
fi

source "$ENV_FILE"

echo "================================================================"
echo "Deploying SubVault and CrosschainStrategyAdapter"
echo "================================================================"
echo "RPC URL: $RPC_URL"
echo "Deployer: $DEPLOYER_ADDRESS"
echo "Chain ID: $CHAIN_ID"
echo "Verifier: $VERIFIER_URL"
echo "================================================================"

# Check required environment variables
if [ -z "$PRIVATE_KEY" ]; then
    echo "Error: PRIVATE_KEY not set. Make sure you've sourced your keys file."
    exit 1
fi

if [ -z "$RPC_URL" ]; then
    echo "Error: RPC_URL not set in environment file."
    exit 1
fi

if [ -z "$CHAIN_ID" ]; then
    echo "Error: CHAIN_ID not set in environment file."
    exit 1
fi

# Optional: Set owner (defaults to deployer)
export OWNER=${OWNER:-$DEPLOYER_ADDRESS}
export PROXY_ADMIN=${PROXY_ADMIN:-$DEPLOYER_ADDRESS}

echo "Owner: $OWNER"
echo "Proxy Admin: $PROXY_ADMIN"
echo ""

# Run the deployment script
echo "Deploying SubVault and CrosschainStrategyAdapter..."
echo ""

# Build forge command
FORGE_CMD="forge script script/Deploy_SubVault.sol \
    --rpc-url $RPC_URL \
    --broadcast \
    --compiler-version 0.8.28 \
    --evm-version \"cancun\" \
    --chain-id $CHAIN_ID \
    --force \
    -vvvv"

# Add verification if VERIFIER_URL is set
if [ -n "$VERIFIER_URL" ]; then
    FORGE_CMD="$FORGE_CMD \
    --verify \
    --verifier blockscout \
    --verifier-url $VERIFIER_URL \
    --etherscan-api-key dummy"
fi

eval $FORGE_CMD

echo ""
echo "================================================================"
echo "SubVault deployment complete!"
echo "================================================================"
echo ""
echo "IMPORTANT: Save the deployed addresses!"
echo ""
echo "Next steps:"
echo "1. Save addresses to your config file (e.g., config/<chain>/subvault.sh):"
echo "   export SUBVAULT_ADDRESS=0x..."
echo "   export SUBVAULT_IMPL_ADDRESS=0x..."
echo "   export CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS=0x..."
echo ""
echo "2. Configure CrosschainStrategyAdapter:"
echo "   cast send \$CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS \\"
echo "     \"setTokenConfig(address,address)\" \$TOKEN_ADDRESS \$OFT_ADDRESS \\"
echo "     --rpc-url \$RPC_URL --private-key \$PRIVATE_KEY"
echo ""
echo "   cast send \$CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS \\"
echo "     \"setRemoteVault(uint32,address)\" \$DST_EID \$DST_VAULT_ADDRESS \\"
echo "     --rpc-url \$RPC_URL --private-key \$PRIVATE_KEY"
echo ""
echo "3. (Optional) Deploy RolesAuthority and set up roles on SubVault"
echo "================================================================"
