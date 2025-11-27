## source the env variable

`source env.sei.sh` -> for key and rpc

`source config/sei/..sh` for contract addresses

# Mainnet setup

## Deploying the vault

1.  bash dev-scripts/deploy/vault.sh
2.  bash dev-scripts/deploy/authority.sh
3.  bash dev-scripts/deploy/setup-auth.sh

> Check crosschain env.sh, to see which chain is currently enable 4. bash dev-scripts/deploy-crosschain-adapter.sh

## Deploying the guard

## Strategy setup

1. bash dev-scripts/deploy/crosschain-strategy-adapter.sh
2. bash dev-scripts/crosschain/set-token-config.sh

3. bash dev-scripts/crosschain/set-remote-vault.sh (Setting up the dst receiver vault)

## Deploy subvault

1. bash dev-scripts/deploy/subvault.sh
2. bash dev-scripts/crosschain/send-to-subvault.sh
