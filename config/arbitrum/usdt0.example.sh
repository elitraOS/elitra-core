# Example SubVault configuration for Arbitrum USDT0
# Copy and customize this file after deployment
#
# Usage:
#   cp config/arbitrum/usdt0.example.sh config/arbitrum/usdt0.sh
#   # Update with deployed addresses

# ========== Token Configuration ==========
# USDT0 on Arbitrum
export TOKEN_ADDRESS=0xYourTokenAddress
# USDT0 OFT contract on Arbitrum
export OFT_ADDRESS=0xYourOFTAddress

# ========== LayerZero Configuration ==========
# SEI mainnet LayerZero endpoint ID
export DST_EID=30280
# Main ElitraVault address on SEI (destination)
export DST_VAULT_ADDRESS=0x86406E18C84379d7B6f5D5379128DBad24e8e4Ec

# ========== Deployed Addresses (fill after deployment) ==========
export SUBVAULT_ADDRESS=
export SUBVAULT_IMPL_ADDRESS=
export CROSSCHAIN_STRATEGY_ADAPTER_ADDRESS=
export PROXY_ADMIN_ADDRESS=

# ========== Optional: RolesAuthority ==========
export ROLES_AUTHORITY_ADDRESS=
