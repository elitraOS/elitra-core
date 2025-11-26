# Example environment file for deploying to a source chain
# Copy this file and customize for your target chain
#
# Usage:
#   cp env.example.sh env.arbitrum.sh
#   # Edit env.arbitrum.sh with your values
#   source env.arbitrum.sh
#   bash dev-scripts/deploy-subvault.sh env.arbitrum.sh

# Source your private key (DO NOT commit this file!)
# source ~/.keys/your-keys.sh

# Deployer address (derived from PRIVATE_KEY)
export DEPLOYER_ADDRESS=0xD4B5314E9412dBC1c772093535dF451a1E2Af1A4

# Chain configuration
export RPC_URL=https://arbitrum.drpc.org
export CHAIN_ID=42161

# Block explorer verification (optional, comment out if not needed)
export VERIFIER_URL=https://api.arbiscan.io/api

