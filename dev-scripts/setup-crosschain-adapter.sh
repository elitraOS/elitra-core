#!/bin/bash

# Setup script for CrosschainStrategyAdapter
# Usage: bash dev-scripts/setup-crosschain-adapter.sh <env-file> <config-file>
# Example: bash dev-scripts/setup-crosschain-adapter.sh env.arbitrum.sh config/arbitrum/usdt0.sh

set -e

# Check arguments
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: bash dev-scripts/setup-crosschain-adapter.sh <env-file> <config-file>"
    echo "Example: bash dev-scripts/setup-crosschain-adapter.sh env.arbitrum.sh config/arbitrum/usdt0.sh"
    exit 1
fi

ENV_FILE=$1
CONFIG_FILE=$2

# Source files
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: Environment file '$ENV_FILE' not found"
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file '$CONFIG_FILE' not found"
    exit 1
fi

source "$ENV_FILE"
source "$CONFIG_FILE"

echo "================================================================"
echo "Setting up CrosschainStrategyAdapter"
echo "================================================================"
echo "RPC URL: $RPC_URL"
echo "Adapter: $CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS"
echo "Token: $TOKEN_ADDRESS"
echo "OFT: $OFT_ADDRESS"
echo "Destination EID: $DST_EID"
echo "Destination Vault: $DST_VAULT_ADDRESS"
echo "================================================================"

# Validate required variables
if [ -z "$PRIVATE_KEY" ]; then
    echo "Error: PRIVATE_KEY not set"
    exit 1
fi

if [ -z "$CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS" ]; then
    echo "Error: CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS not set"
    exit 1
fi

if [ -z "$TOKEN_ADDRESS" ] || [ -z "$OFT_ADDRESS" ]; then
    echo "Error: TOKEN_ADDRESS or OFT_ADDRESS not set"
    exit 1
fi

if [ -z "$DST_EID" ] || [ -z "$DST_VAULT_ADDRESS" ]; then
    echo "Error: DST_EID or DST_VAULT_ADDRESS not set"
    exit 1
fi

echo ""
echo "Step 1: Setting token configuration..."
cast send $CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS \
    "setTokenConfig(address,address)" \
    $TOKEN_ADDRESS \
    $OFT_ADDRESS \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY

echo "Token config set successfully!"

echo ""
echo "Step 2: Setting remote vault..."
cast send $CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS \
    "setRemoteVault(uint32,address)" \
    $DST_EID \
    $DST_VAULT_ADDRESS \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY

echo "Remote vault set successfully!"

echo ""
echo "================================================================"
echo "CrosschainStrategyAdapter setup complete!"
echo "================================================================"
echo ""
echo "Verification:"
echo "  Token config: cast call $CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS \"tokenToOft(address)\" $TOKEN_ADDRESS --rpc-url $RPC_URL"
echo "  Remote vault: cast call $CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS \"dstEidToVault(uint32)\" $DST_EID --rpc-url $RPC_URL"
echo "================================================================"
