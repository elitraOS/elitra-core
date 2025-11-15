#!/bin/bash

# Cross-Chain SEI Deposit to WSEI Vault Script
# This script bridges SEI from Ethereum to SEI chain, wraps it to WSEI, and deposits into WSEI vault

set -e

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Cross-Chain SEI Deposit to WSEI Vault ===${NC}\n"

# Required environment variables
if [ -z "$ADAPTER_ADDRESS" ]; then
    echo -e "${RED}Error: ADAPTER_ADDRESS must be set${NC}"
    echo "export ADAPTER_ADDRESS=<MultichainDepositAdapter address on SEI>"
    exit 1
fi

if [ -z "$PRIVATE_KEY" ] && [ -z "$MNEMONIC" ]; then
    echo -e "${RED}Error: PRIVATE_KEY or MNEMONIC must be set${NC}"
    exit 1
fi

# Default values
SEI_OFT_ADDRESS="${SEI_OFT_ADDRESS:-0xbdF43ecAdC5ceF51B7D1772F722E40596BC1788B}"
WSEI_ADDRESS="${WSEI_ADDRESS:-0xE30feDd158A2e3b13e9badaeABaFc5516e95e8C7}"
WSEI_VAULT_ADDRESS="${WSEI_VAULT_ADDRESS:-0x397e97798D2b2BBe17FaD2228D84C200c9F0554D}"
AMOUNT="${AMOUNT:-1000000000000000000}" # 1 SEI in wei
DST_EID="${DST_EID:-30280}" # SEI chain endpoint ID

# RPC URLs
SOURCE_RPC="${SOURCE_RPC:-${RPC_URL:-https://eth.llamarpc.com}}"

# Display configuration
echo -e "${YELLOW}Configuration:${NC}"
echo "  Source RPC: $SOURCE_RPC"
echo "  SEI OFT (source): $SEI_OFT_ADDRESS"
echo "  Adapter (SEI): $ADAPTER_ADDRESS"
echo "  WSEI (SEI): $WSEI_ADDRESS"
echo "  WSEI Vault (SEI): $WSEI_VAULT_ADDRESS"
echo "  Amount: $AMOUNT wei"
echo "  Destination EID: $DST_EID"
echo ""

# Confirmation
read -p "Continue with transaction? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted"
    exit 1
fi

# Determine dry run mode
DRY_RUN="${DRY_RUN:-true}"
if [ "$DRY_RUN" = "false" ]; then
    echo -e "${YELLOW}Running in LIVE mode (broadcasting transaction)${NC}\n"
    BROADCAST_FLAG="--broadcast"
else
    echo -e "${YELLOW}Running in DRY RUN mode (simulation only)${NC}\n"
    BROADCAST_FLAG=""
fi

# Build forge command
FORGE_CMD="forge script script/CrossChainDeposit_SEI_WSEI.s.sol:CrossChainDeposit_SEI_WSEI \
    --rpc-url $SOURCE_RPC \
    $BROADCAST_FLAG \
    -vvv"

# Export environment variables for the script
export SEI_OFT_ADDRESS
export ADAPTER_ADDRESS
export WSEI_ADDRESS
export WSEI_VAULT_ADDRESS
export AMOUNT
export DST_EID

# Execute
echo -e "${GREEN}Executing cross-chain deposit...${NC}\n"
eval $FORGE_CMD

echo -e "\n${GREEN}=== Script Complete ===${NC}"

if [ "$DRY_RUN" = "false" ]; then
    echo -e "${YELLOW}Transaction broadcasted. Monitor the adapter on SEI chain for deposit completion.${NC}"
    echo -e "${YELLOW}Check deposit status: cast call $ADAPTER_ADDRESS \"totalDeposits()\" --rpc-url <SEI_RPC>${NC}"
else
    echo -e "${YELLOW}Dry run complete. Set DRY_RUN=false to broadcast transaction.${NC}"
fi
