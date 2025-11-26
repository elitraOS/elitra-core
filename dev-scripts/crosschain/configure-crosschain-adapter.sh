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
source dev-scripts/crosschain/env.sh

echo "================================================================"
echo "Configuring CrosschainStrategyAdapter"
echo "================================================================"
echo "RPC URL: $RPC_URL"
echo "Adapter: $CURRENT_CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS"
echo "Token: $CURRENT_TOKEN_ADDRESS"
echo "OFT: $CURRENT_OFT_ADDRESS"
echo "Destination EID: $CURRENT_DST_EID"
echo "Destination Vault: $CURRENT_DST_VAULT_ADDRESS"
echo "================================================================"

# Check required environment variables
if [ -z "$PRIVATE_KEY" ]; then
    echo "Error: PRIVATE_KEY not set. Make sure you've sourced your keys file."
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
