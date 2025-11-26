#!/bin/bash

# Configuration script for CrosschainStrategyAdapter
# Usage: bash dev-scripts/configure-crosschain-adapter.sh
#
# Before running:
# 1. Source your environment file (e.g., source env.sei.sh)
# 2. Source your asset config file (e.g., source config/sei/usdt0.sh)
#    Config file should have:
#    - CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS
#    - TOKEN_ADDRESS (or ASSET_ADDRESS)
#    - OFT_ADDRESS
#    - DST_EID
#    - DST_VAULT_ADDRESS

set -e

# Source environment variables
source env.sei.sh

echo "================================================================"
echo "Configuring CrosschainStrategyAdapter"
echo "================================================================"
echo "RPC URL: $RPC_URL"
echo "Adapter: $CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS"
echo "Token: ${TOKEN_ADDRESS:-$ASSET_ADDRESS}"
echo "OFT: $OFT_ADDRESS"
echo "Destination EID: $DST_EID"
echo "Destination Vault: $DST_VAULT_ADDRESS"
echo "================================================================"

# Check required environment variables
if [ -z "$PRIVATE_KEY" ]; then
    echo "Error: PRIVATE_KEY not set. Make sure you've sourced your keys file."
    exit 1
fi

if [ -z "$CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS" ]; then
    echo "Error: CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS not set."
    exit 1
fi

# Use TOKEN_ADDRESS if set, otherwise fall back to ASSET_ADDRESS
export TOKEN_ADDRESS=${TOKEN_ADDRESS:-$ASSET_ADDRESS}

if [ -z "$TOKEN_ADDRESS" ] || [ -z "$OFT_ADDRESS" ]; then
    echo "Error: TOKEN_ADDRESS/ASSET_ADDRESS or OFT_ADDRESS not set."
    exit 1
fi

if [ -z "$DST_EID" ] || [ -z "$DST_VAULT_ADDRESS" ]; then
    echo "Error: DST_EID or DST_VAULT_ADDRESS not set."
    exit 1
fi

echo ""
echo "Running configuration script..."
echo ""

forge script script/crosschain/ConfigureCrosschainAdapter.s.sol \
    --rpc-url $RPC_URL \
    --broadcast \
    --compiler-version 0.8.28 \
    --evm-version "cancun" \
    --chain-id 1329 \
    --force \
    -vvvv

echo ""
echo "================================================================"
echo "CrosschainStrategyAdapter configuration complete!"
echo "================================================================"
