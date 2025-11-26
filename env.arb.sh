# Example environment file for deploying to a source chain
# Copy this file and customize for your target chain
#
# Usage:
#   cp env.example.sh env.arbitrum.sh
#   # Edit env.arbitrum.sh with your values
#   source env.arbitrum.sh
#   bash dev-scripts/deploy-subvault.sh env.arbitrum.sh

# Source your private key (DO NOT commit this file!)
source ~/.keys/sei-mainnet.sh // currently using sei wallet for testing 

# Deployer address (derived from PRIVATE_KEY)
export DEPLOYER_ADDRESS=0xD4B5314E9412dBC1c772093535dF451a1E2Af1A4

# Chain configuration
export RPC_URL=https://arbitrum.drpc.org
export CHAIN_ID=42161

# Block explorer verification
# Using Etherscan V2 API standard
export VERIFIER_URL="https://api.etherscan.io/v2/api"
export VERIFIER_TYPE=etherscan
# You must provide a valid Etherscan API key here