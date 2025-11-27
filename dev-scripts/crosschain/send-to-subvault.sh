#!/bin/bash

# Script to send funds from SEI ElitraVault to ARB SubVault via LayerZero
# Usage: bash dev-scripts/crosschain/send-to-subvault.sh <amount>
# Example: bash dev-scripts/crosschain/send-to-subvault.sh 1000000
#
# Before running:
# 1. Source your environment file: source env.sei.sh
# 2. Source your config file: source config/sei/usdt0.sh
#    Config should have:
#    - VAULT_ADDRESS
#    - ASSET_ADDRESS
#    - CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS
#    - ARB_EID
#    - ARB_SUB_VAULT_ADDRESS



SEND_AMOUNT=1000

# Source environment variables
source dev-scripts/crosschain/env.sh

echo "================================================================"
echo "Sending Funds to ARB SubVault via LayerZero"
echo "================================================================"
echo "RPC URL: $RPC_URL"
echo "Vault: $CURRENT_VAULT_ADDRESS"
echo "Asset: $CURRENT_TOKEN_ADDRESS"
echo "Adapter: $CURRENT_CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS"
echo "Destination EID: $CURRENT_DST_EID"
echo "Destination Vault: $CURRENT_DST_VAULT_ADDRESS"
echo "Send Amount: $SEND_AMOUNT"
echo "================================================================"

# Check required environment variables
if [ -z "$PRIVATE_KEY" ]; then
    echo "Error: PRIVATE_KEY not set. Make sure you've sourced your keys file."
    exit 1
fi

if [ -z "$CURRENT_VAULT_ADDRESS" ]; then
    echo "Error: VAULT_ADDRESS not set. Source your config file first."
    exit 1
fi

if [ -z "$CURRENT_CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS" ]; then
    echo "Error: CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS not set."
    exit 1
fi

if [ -z "$CURRENT_DST_EID" ] || [ -z "$CURRENT_DST_VAULT_ADDRESS" ]; then
    echo "Error: CURRENT_DST_EID or CURRENT_DST_VAULT_ADDRESS not set."
    exit 1
fi

# Export the send amount for the forge script
export SEND_AMOUNT=$SEND_AMOUNT

echo ""
echo "Executing cross-chain transfer..."
echo ""

forge script script/crosschain/SendToSubVault.s.sol \
    --rpc-url $RPC_URL \
    --broadcast \
    --compiler-version 0.8.28 \
    --evm-version "cancun" \
    --chain-id 1329 \
    --force \
    -vvvv

echo ""
echo "================================================================"
echo "Cross-chain transfer initiated!"
echo "================================================================"
echo ""
echo "The tokens are being bridged via LayerZero."
echo "Monitor the transfer:"
echo "  - LayerZero Scan: https://layerzeroscan.com"
echo "  - Destination: https://arbiscan.io/address/$ARB_SUB_VAULT_ADDRESS"
echo "================================================================"
